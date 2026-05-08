import * as vscode from 'vscode';
import * as path from 'path';
import * as fs from 'fs/promises';

import { checkSyft, generateSBOM } from './services/syft';
import type { SyftOutputFormat } from './services/syft';
import { scanComponents } from './services/osv';
import { SBOMTreeProvider } from './providers/sbomTreeProvider';
import { SBOMPanel } from './panels/sbomPanel';
import type {
  SBOMDocument,
  SBOMComponent,
  CycloneDXBom,
  SPDXDocument
} from './types';

// ---------------------------------------------------------------------------
// Extension state
// ---------------------------------------------------------------------------

const sbomDocuments = new Map<string, SBOMDocument>();
let treeProvider: SBOMTreeProvider;

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

export function activate(context: vscode.ExtensionContext): void {
  treeProvider = new SBOMTreeProvider(sbomDocuments);

  context.subscriptions.push(
    vscode.window.createTreeView('sbomExplorer', {
      treeDataProvider: treeProvider,
      showCollapseAll: true
    })
  );

  context.subscriptions.push(
    vscode.commands.registerCommand('sbom.checkSyft', cmdCheckSyft),
    vscode.commands.registerCommand('sbom.generate', cmdGenerate),
    vscode.commands.registerCommand(
      'sbom.generateForFile',
      (uri?: vscode.Uri) => cmdGenerateForFile(uri)
    ),
    vscode.commands.registerCommand('sbom.scan', (doc?: SBOMDocument) =>
      cmdScan(doc)
    ),
    vscode.commands.registerCommand('sbom.view', (doc?: SBOMDocument) =>
      cmdView(doc)
    ),
    vscode.commands.registerCommand('sbom.refresh', () =>
      treeProvider.refresh()
    )
  );
}

export function deactivate(): void {
  /* nothing to clean up */
}

// ---------------------------------------------------------------------------
// Commands
// ---------------------------------------------------------------------------

async function cmdCheckSyft(): Promise<void> {
  try {
    const output = await checkSyft();
    const match = output.match(/Version[:\s]+([\d.]+)/i);
    const version = match?.[1] ?? 'installed';
    vscode.window.showInformationMessage(`syft v${version} is available.`);
  } catch {
    const choice = await vscode.window.showErrorMessage(
      'syft not found. Install with: brew install syft',
      'Open Install Guide'
    );
    if (choice === 'Open Install Guide') {
      void vscode.env.openExternal(
        vscode.Uri.parse('https://github.com/anchore/syft#installation')
      );
    }
  }
}

async function cmdGenerate(): Promise<void> {
  const workspaceFolders = vscode.workspace.workspaceFolders;
  if (!workspaceFolders?.length) {
    vscode.window.showWarningMessage('No workspace folder open.');
    return;
  }
  await runGenerate(workspaceFolders[0].uri.fsPath);
}

async function cmdGenerateForFile(uri?: vscode.Uri): Promise<void> {
  let targetPath: string | undefined;

  if (uri) {
    targetPath = uri.fsPath;
  } else {
    const picked = await vscode.window.showOpenDialog({
      canSelectFolders: true,
      canSelectFiles: false,
      openLabel: 'Select folder to scan'
    });
    targetPath = picked?.[0]?.fsPath;
  }

  if (!targetPath) {
    return;
  }
  await runGenerate(targetPath);
}

async function cmdScan(existingDoc?: SBOMDocument): Promise<void> {
  const doc = existingDoc ?? (await pickDocument());
  if (!doc) {
    return;
  }

  await vscode.window.withProgress(
    {
      location: vscode.ProgressLocation.Notification,
      title: 'Scanning for vulnerabilities…',
      cancellable: false
    },
    async () => {
      const config = vscode.workspace.getConfiguration('sbom');
      const batchSize = config.get<number>('osvBatchSize', 50);
      await applyVulnerabilities(doc, batchSize);
      treeProvider.refresh();

      const count = doc.vulnerabilityCount ?? 0;
      vscode.window.showInformationMessage(
        count > 0
          ? `Found ${count} vulnerabilit${count === 1 ? 'y' : 'ies'} in ${doc.name}.`
          : `No vulnerabilities found in ${doc.name}.`
      );
    }
  );
}

async function cmdView(doc?: SBOMDocument): Promise<void> {
  const target = doc ?? (await pickDocument());
  if (!target) {
    return;
  }
  SBOMPanel.show(target);
}

// ---------------------------------------------------------------------------
// Core generation workflow
// ---------------------------------------------------------------------------

async function runGenerate(targetPath: string): Promise<void> {
  // Verify syft before showing progress UI
  try {
    await checkSyft();
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    const choice = await vscode.window.showErrorMessage(
      msg,
      'Open Install Guide'
    );
    if (choice === 'Open Install Guide') {
      void vscode.env.openExternal(
        vscode.Uri.parse('https://github.com/anchore/syft#installation')
      );
    }
    return;
  }

  const config = vscode.workspace.getConfiguration('sbom');
  const outputDirSetting = config.get<string>('outputDir', '.sbom');
  const formatSetting = config.get<string>('outputFormat', 'cyclonedx-json');
  const autoScan = config.get<boolean>('autoScanOnGenerate', true);
  const batchSize = config.get<number>('osvBatchSize', 50);

  const resolvedOutputDir = path.isAbsolute(outputDirSetting)
    ? outputDirSetting
    : path.join(targetPath, outputDirSetting);

  await fs.mkdir(resolvedOutputDir, { recursive: true });

  const formats: SyftOutputFormat[] =
    formatSetting === 'both'
      ? ['cyclonedx-json', 'spdx-json']
      : [formatSetting as SyftOutputFormat];

  await vscode.window.withProgress(
    {
      location: vscode.ProgressLocation.Notification,
      title: 'SBOM',
      cancellable: false
    },
    async (progress) => {
      const generated: SBOMDocument[] = [];

      for (const fmt of formats) {
        const ext = fmt.includes('cyclonedx') ? 'cdx.json' : 'spdx.json';
        const outputFile = path.join(resolvedOutputDir, `sbom.${ext}`);

        progress.report({ message: `Running syft (${fmt})…` });

        try {
          await generateSBOM(targetPath, outputFile, fmt);
        } catch (err: unknown) {
          const msg = err instanceof Error ? err.message : String(err);
          vscode.window.showErrorMessage(`SBOM generation failed: ${msg}`);
          continue;
        }

        progress.report({ message: `Parsing ${fmt}…` });
        const doc = await parseSBOMFile(outputFile, fmt);
        if (doc) {
          sbomDocuments.set(outputFile, doc);
          generated.push(doc);
        }
      }

      if (generated.length === 0) {
        return;
      }

      treeProvider.refresh();

      if (autoScan) {
        progress.report({ message: 'Scanning via OSV.dev…' });
        for (const doc of generated) {
          await applyVulnerabilities(doc, batchSize);
        }
        treeProvider.refresh();
      }

      const first = generated[0];
      const totalVulns = generated.reduce(
        (a, d) => a + (d.vulnerabilityCount ?? 0),
        0
      );
      const summary =
        `SBOM ready: ${first.components.length} components` +
        (totalVulns > 0
          ? `, ${totalVulns} vulnerabilit${totalVulns === 1 ? 'y' : 'ies'} found`
          : ', no vulnerabilities found');

      const choice = await vscode.window.showInformationMessage(
        summary,
        'View SBOM'
      );
      if (choice === 'View SBOM') {
        SBOMPanel.show(first);
      }
    }
  );
}

// ---------------------------------------------------------------------------
// Parsing helpers
// ---------------------------------------------------------------------------

async function parseSBOMFile(
  filePath: string,
  format: SyftOutputFormat
): Promise<SBOMDocument | undefined> {
  try {
    const raw = await fs.readFile(filePath, 'utf-8');
    const json: unknown = JSON.parse(raw);

    return format === 'cyclonedx-json'
      ? parseCycloneDX(json as CycloneDXBom, filePath)
      : parseSPDX(json as SPDXDocument, filePath);
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    vscode.window.showErrorMessage(`Failed to parse SBOM: ${msg}`);
    return undefined;
  }
}

function parseCycloneDX(bom: CycloneDXBom, filePath: string): SBOMDocument {
  const components: SBOMComponent[] = (bom.components ?? []).map((c) => ({
    name: c.name,
    version: c.version,
    purl: c.purl,
    type: c.type,
    license:
      c.licenses?.[0]?.license?.id ??
      c.licenses?.[0]?.license?.name ??
      c.licenses?.[0]?.expression
  }));

  return {
    format: 'cyclonedx',
    name: path.basename(filePath),
    filePath,
    components,
    generatedAt: bom.metadata?.timestamp ?? new Date().toISOString()
  };
}

function parseSPDX(spdx: SPDXDocument, filePath: string): SBOMDocument {
  const components: SBOMComponent[] = (spdx.packages ?? []).map((p) => {
    const purl = p.externalRefs?.find(
      (r) => r.referenceType === 'purl'
    )?.referenceLocator;
    const license =
      p.licenseConcluded !== 'NOASSERTION' && p.licenseConcluded !== 'NONE'
        ? p.licenseConcluded
        : p.licenseDeclared !== 'NOASSERTION' && p.licenseDeclared !== 'NONE'
          ? p.licenseDeclared
          : undefined;

    return { name: p.name, version: p.versionInfo, purl, license };
  });

  return {
    format: 'spdx',
    name: path.basename(filePath),
    filePath,
    components,
    generatedAt: spdx.creationInfo?.created ?? new Date().toISOString()
  };
}

// ---------------------------------------------------------------------------
// Vulnerability scanning
// ---------------------------------------------------------------------------

async function applyVulnerabilities(
  doc: SBOMDocument,
  batchSize: number
): Promise<void> {
  const vulnMap = await scanComponents(doc.components, batchSize);

  for (const component of doc.components) {
    const key = `${component.name}@${component.version ?? ''}`;
    component.vulnerabilities = vulnMap.get(key) ?? [];
  }

  doc.vulnerabilityCount = doc.components.reduce(
    (acc, c) => acc + (c.vulnerabilities?.length ?? 0),
    0
  );
}

// ---------------------------------------------------------------------------
// UI helpers
// ---------------------------------------------------------------------------

async function pickDocument(): Promise<SBOMDocument | undefined> {
  const docs = Array.from(sbomDocuments.values());

  if (docs.length === 0) {
    vscode.window.showWarningMessage(
      'No SBOMs loaded. Run SBOM: Generate first.'
    );
    return undefined;
  }

  if (docs.length === 1) {
    return docs[0];
  }

  const picked = await vscode.window.showQuickPick(
    docs.map((d) => ({
      label: d.name,
      description: d.filePath,
      detail: `${d.components.length} components · ${d.format.toUpperCase()}`,
      doc: d
    })),
    { placeHolder: 'Select an SBOM' }
  );

  return picked?.doc;
}
