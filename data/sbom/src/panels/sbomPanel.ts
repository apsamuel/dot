import * as vscode from 'vscode';
import type { SBOMDocument } from '../types';

export class SBOMPanel {
  static currentPanel: SBOMPanel | undefined;

  private readonly _panel: vscode.WebviewPanel;
  private _disposables: vscode.Disposable[] = [];

  static show(document: SBOMDocument): void {
    const column =
      vscode.window.activeTextEditor?.viewColumn ?? vscode.ViewColumn.One;

    if (SBOMPanel.currentPanel) {
      SBOMPanel.currentPanel._panel.reveal(column);
      SBOMPanel.currentPanel._update(document);
      return;
    }

    const panel = vscode.window.createWebviewPanel(
      'sbomView',
      `SBOM: ${document.name}`,
      column,
      {
        enableScripts: false,
        retainContextWhenHidden: true
      }
    );

    SBOMPanel.currentPanel = new SBOMPanel(panel, document);
  }

  private constructor(panel: vscode.WebviewPanel, document: SBOMDocument) {
    this._panel = panel;
    this._update(document);
    this._panel.onDidDispose(() => this.dispose(), null, this._disposables);
  }

  private _update(document: SBOMDocument): void {
    this._panel.title = `SBOM: ${document.name}`;
    this._panel.webview.html = this._buildHtml(document);
  }

  dispose(): void {
    SBOMPanel.currentPanel = undefined;
    this._panel.dispose();
    this._disposables.forEach((d) => d.dispose());
    this._disposables = [];
  }

  // -------------------------------------------------------------------------
  // HTML rendering
  // -------------------------------------------------------------------------

  private _buildHtml(doc: SBOMDocument): string {
    const criticalCount = this._countBySeverity(doc, 'CRITICAL');
    const highCount = this._countBySeverity(doc, 'HIGH');
    const mediumCount = this._countBySeverity(doc, 'MEDIUM');
    const lowCount = this._countBySeverity(doc, 'LOW');
    const totalVulns = doc.vulnerabilityCount ?? 0;

    const vulnComponents = doc.components.filter(
      (c) => (c.vulnerabilities?.length ?? 0) > 0
    );

    const vulnRows = vulnComponents
      .flatMap((c) =>
        (c.vulnerabilities ?? []).map((v) => {
          const sev = (v.database_specific?.severity ?? '—').toUpperCase();
          const sevClass = sev.toLowerCase();
          return `<tr>
            <td><a href="https://osv.dev/vulnerability/${this._esc(v.id)}">${this._esc(v.id)}</a></td>
            <td>${this._esc(c.name)}${c.version ? `@${this._esc(c.version)}` : ''}</td>
            <td><span class="sev ${sevClass}">${this._esc(sev)}</span></td>
            <td>${this._esc(v.summary ?? '—')}</td>
          </tr>`;
        })
      )
      .join('');

    const componentRows = doc.components
      .map((c) => {
        const count = c.vulnerabilities?.length ?? 0;
        const badge =
          count > 0
            ? `<span class="badge-vuln">${count} vuln${count > 1 ? 's' : ''}</span>`
            : `<span class="badge-ok">✓</span>`;
        return `<tr>
          <td>${this._esc(c.name)}</td>
          <td>${this._esc(c.version ?? '—')}</td>
          <td>${this._esc(c.type ?? '—')}</td>
          <td>${this._esc(c.license ?? '—')}</td>
          <td>${badge}</td>
        </tr>`;
      })
      .join('');

    const scannedNote =
      totalVulns === 0 && vulnComponents.length === 0
        ? `<p class="all-clear">&#10003; No vulnerabilities found across ${doc.components.length} components.</p>`
        : '';

    return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; img-src 'none';">
<title>SBOM Viewer</title>
<style>
  :root {
    --font: var(--vscode-font-family, sans-serif);
    --fg: var(--vscode-foreground, #ccc);
    --bg: var(--vscode-editor-background, #1e1e1e);
    --desc: var(--vscode-descriptionForeground, #888);
    --panel-border: var(--vscode-panel-border, #333);
    --hover-bg: var(--vscode-list-hoverBackground, #2a2d2e);
    --selection-bg: var(--vscode-editor-inactiveSelectionBackground, #3a3d41);
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    font-family: var(--font);
    font-size: var(--vscode-font-size, 13px);
    color: var(--fg);
    background: var(--bg);
    padding: 20px 24px;
    line-height: 1.5;
  }
  h1 { font-size: 1.25em; margin-bottom: 4px; }
  .meta { color: var(--desc); font-size: 0.875em; margin-bottom: 20px; }
  .meta span { margin-right: 16px; }

  /* Summary cards */
  .summary { display: flex; gap: 10px; flex-wrap: wrap; margin-bottom: 24px; }
  .card {
    background: var(--selection-bg);
    border-radius: 4px;
    padding: 10px 18px;
    min-width: 90px;
    text-align: center;
  }
  .card .num { font-size: 1.75em; font-weight: 700; line-height: 1.2; }
  .card .lbl { font-size: 0.75em; color: var(--desc); margin-top: 2px; }
  .card.critical .num { color: #f14c4c; }
  .card.high .num    { color: #fc6d26; }
  .card.medium .num  { color: #e2a64e; }
  .card.low .num     { color: #73c991; }

  /* Tables */
  h2 { font-size: 1em; margin: 22px 0 8px; border-bottom: 1px solid var(--panel-border); padding-bottom: 4px; }
  table { border-collapse: collapse; width: 100%; }
  th, td {
    text-align: left;
    padding: 5px 10px;
    border-bottom: 1px solid var(--panel-border);
    font-size: 0.875em;
  }
  th { color: var(--desc); font-weight: 600; }
  tr:hover td { background: var(--hover-bg); }

  /* Badges */
  .badge-vuln {
    background: rgba(252, 109, 38, 0.15);
    color: #fc6d26;
    padding: 1px 7px;
    border-radius: 3px;
    font-size: 0.8em;
  }
  .badge-ok { color: #73c991; }

  /* Severity labels */
  .sev {
    padding: 1px 7px;
    border-radius: 3px;
    font-size: 0.8em;
    font-weight: 700;
  }
  .sev.critical { background: rgba(241, 76, 76,  0.15); color: #f14c4c; }
  .sev.high     { background: rgba(252, 109, 38, 0.15); color: #fc6d26; }
  .sev.medium   { background: rgba(226, 166, 78, 0.15); color: #e2a64e; }
  .sev.low      { background: rgba(115, 201, 145, 0.15); color: #73c991; }
  .sev.—        { color: var(--desc); background: none; }

  /* Links */
  a { color: var(--vscode-textLink-foreground, #4daafc); text-decoration: none; }
  a:hover { text-decoration: underline; }

  /* All-clear message */
  .all-clear { color: #73c991; margin: 8px 0 16px; }
</style>
</head>
<body>

<h1>${this._esc(doc.name)}</h1>
<div class="meta">
  <span>Format: <strong>${doc.format.toUpperCase()}</strong></span>
  <span>Generated: ${this._esc(doc.generatedAt)}</span>
  <span>Components: <strong>${doc.components.length}</strong></span>
</div>

<div class="summary">
  <div class="card">
    <div class="num">${doc.components.length}</div>
    <div class="lbl">Total</div>
  </div>
  <div class="card critical">
    <div class="num">${criticalCount}</div>
    <div class="lbl">Critical</div>
  </div>
  <div class="card high">
    <div class="num">${highCount}</div>
    <div class="lbl">High</div>
  </div>
  <div class="card medium">
    <div class="num">${mediumCount}</div>
    <div class="lbl">Medium</div>
  </div>
  <div class="card low">
    <div class="num">${lowCount}</div>
    <div class="lbl">Low</div>
  </div>
</div>

${scannedNote}

${
  vulnRows
    ? `<h2>Vulnerabilities (${totalVulns})</h2>
<table>
  <thead><tr><th>ID</th><th>Component</th><th>Severity</th><th>Summary</th></tr></thead>
  <tbody>${vulnRows}</tbody>
</table>`
    : ''
}

<h2>Components (${doc.components.length})</h2>
<table>
  <thead><tr><th>Name</th><th>Version</th><th>Type</th><th>License</th><th>Vulns</th></tr></thead>
  <tbody>${componentRows}</tbody>
</table>

</body>
</html>`;
  }

  /** Count vulnerabilities matching a specific severity string. */
  private _countBySeverity(doc: SBOMDocument, severity: string): number {
    return doc.components.reduce((acc, c) => {
      return (
        acc +
        (c.vulnerabilities ?? []).filter(
          (v) =>
            (v.database_specific?.severity ?? '').toUpperCase() === severity
        ).length
      );
    }, 0);
  }

  /** HTML-escape a string to prevent XSS from SBOM data. */
  private _esc(s: string): string {
    return s
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }
}
