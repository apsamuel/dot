import * as vscode from 'vscode';
import * as path from 'path';
import type { SBOMDocument, SBOMComponent, OSVVulnerability } from '../types';

// ---------------------------------------------------------------------------
// Base tree item
// ---------------------------------------------------------------------------

export class SBOMTreeItem extends vscode.TreeItem {
  constructor(
    label: string,
    public readonly itemKind: string,
    collapsibleState: vscode.TreeItemCollapsibleState
  ) {
    super(label, collapsibleState);
    this.contextValue = itemKind;
  }
}

// ---------------------------------------------------------------------------
// Document-level item (one per generated SBOM file)
// ---------------------------------------------------------------------------

export class SBOMDocumentItem extends SBOMTreeItem {
  constructor(public readonly document: SBOMDocument) {
    const vulnCount = document.vulnerabilityCount ?? 0;
    const label =
      `${path.basename(document.filePath)}` +
      ` (${document.components.length} components` +
      `${vulnCount > 0 ? `, ${vulnCount} vulns` : ''})`;

    super(label, 'sbomDocument', vscode.TreeItemCollapsibleState.Collapsed);

    this.tooltip = document.filePath;
    this.description = document.format.toUpperCase();
    this.iconPath = new vscode.ThemeIcon(vulnCount > 0 ? 'shield-x' : 'shield');
    this.command = {
      command: 'sbom.view',
      title: 'View SBOM',
      arguments: [document]
    };
  }
}

// ---------------------------------------------------------------------------
// Component-level item
// ---------------------------------------------------------------------------

export class SBOMComponentItem extends SBOMTreeItem {
  constructor(public readonly component: SBOMComponent) {
    const vulnCount = component.vulnerabilities?.length ?? 0;
    const label = component.version
      ? `${component.name}@${component.version}`
      : component.name;

    super(
      label,
      'sbomComponent',
      vulnCount > 0
        ? vscode.TreeItemCollapsibleState.Collapsed
        : vscode.TreeItemCollapsibleState.None
    );

    this.description = component.license;
    this.tooltip = component.purl ?? component.name;
    this.iconPath = new vscode.ThemeIcon(vulnCount > 0 ? 'warning' : 'package');
  }
}

// ---------------------------------------------------------------------------
// Vulnerability-level item
// ---------------------------------------------------------------------------

export class SBOMVulnItem extends SBOMTreeItem {
  constructor(public readonly vuln: OSVVulnerability) {
    super(vuln.id, 'sbomVuln', vscode.TreeItemCollapsibleState.None);

    const severity =
      vuln.database_specific?.severity ?? vuln.severity?.[0]?.score ?? '';

    this.description = vuln.summary ?? '';
    this.tooltip = [vuln.id, severity, vuln.details]
      .filter(Boolean)
      .join('\n\n');
    this.iconPath = new vscode.ThemeIcon('bug');
    this.command = {
      command: 'vscode.open',
      title: 'Open in OSV',
      arguments: [vscode.Uri.parse(`https://osv.dev/vulnerability/${vuln.id}`)]
    };
  }
}

// ---------------------------------------------------------------------------
// Tree data provider
// ---------------------------------------------------------------------------

export class SBOMTreeProvider implements vscode.TreeDataProvider<SBOMTreeItem> {
  private readonly _onDidChangeTreeData = new vscode.EventEmitter<
    SBOMTreeItem | undefined | null | void
  >();
  readonly onDidChangeTreeData = this._onDidChangeTreeData.event;

  constructor(private readonly documents: Map<string, SBOMDocument>) {}

  refresh(): void {
    this._onDidChangeTreeData.fire();
  }

  getTreeItem(element: SBOMTreeItem): vscode.TreeItem {
    return element;
  }

  getChildren(element?: SBOMTreeItem): SBOMTreeItem[] {
    // Root — list all loaded SBOM documents
    if (!element) {
      const docs = Array.from(this.documents.values());
      if (docs.length === 0) {
        const placeholder = new SBOMTreeItem(
          'No SBOMs generated yet — run SBOM: Generate',
          'message',
          vscode.TreeItemCollapsibleState.None
        );
        placeholder.iconPath = new vscode.ThemeIcon('info');
        return [placeholder];
      }
      return docs.map((doc) => new SBOMDocumentItem(doc));
    }

    // Document → components (cap at 500 for tree performance)
    if (element instanceof SBOMDocumentItem) {
      return element.document.components
        .slice(0, 500)
        .map((c) => new SBOMComponentItem(c));
    }

    // Component → vulnerabilities
    if (
      element instanceof SBOMComponentItem &&
      element.component.vulnerabilities?.length
    ) {
      return element.component.vulnerabilities.map((v) => new SBOMVulnItem(v));
    }

    return [];
  }
}
