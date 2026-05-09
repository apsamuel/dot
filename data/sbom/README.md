# 🛡️ data/sbom/

A self-contained **VS Code extension** (`apsamuel.vscode-sbom`) that generates Software Bill of Materials (SBOM) documents and scans them for known vulnerabilities — without leaving the editor.

> 🔬 Powered by [Syft](https://github.com/anchore/syft) for SBOM generation and the [OSV.dev](https://osv.dev) public vulnerability database for scanning.

---

## ✨ What It Does

| 🎯 Capability                                     | 🛠️ How                                                 |
| ------------------------------------------------- | ------------------------------------------------------ |
| 📦 Generate CycloneDX / SPDX SBOM for a workspace | Runs `syft` against the workspace root                 |
| 📁 Generate SBOM for a single file or folder      | Runs `syft` against an arbitrary path                  |
| 🔍 Scan SBOM components against OSV.dev           | Batched HTTPS POST to the OSV vulnerabilities endpoint |
| 👁️ View / browse SBOM contents                    | Tree view in the **SBOM** activity bar                 |
| 🩺 Verify Syft is installed                       | One-click readiness check                              |

---

## 🧭 Commands

| Command ID             | Title                         |
| ---------------------- | ----------------------------- |
| `sbom.checkSyft`       | Check syft Installation       |
| `sbom.generate`        | Generate SBOM for Workspace   |
| `sbom.generateForFile` | Generate SBOM for File/Folder |
| `sbom.scan`            | Scan SBOM for Vulnerabilities |
| `sbom.view`            | View SBOM                     |
| `sbom.refresh`         | Refresh                       |

All commands are exposed under the **SBOM** category in the command palette and through the SBOM activity-bar view.

---

## ⚙️ Configuration

| Setting                   | Default          | Effect                                                    |
| ------------------------- | ---------------- | --------------------------------------------------------- |
| `sbom.syftPath`           | `syft`           | Path to the `syft` binary (override if not on `$PATH`)    |
| `sbom.outputFormat`       | `cyclonedx-json` | One of `cyclonedx-json`, `spdx-json`, `both`              |
| `sbom.outputDir`          | `.sbom`          | Workspace-relative directory where SBOM files are written |
| `sbom.autoScanOnGenerate` | `false`          | Automatically run vulnerability scan after each generate  |
| `sbom.osvBatchSize`       | `100`            | Number of components per OSV.dev batch request            |

---

## 🧪 Local Development

```bash
cd ~/.dot/data/sbom
npm install
npm run compile          # tsc → out/
# In VS Code: F5 to launch the Extension Development Host
```

The compiled extension lives under `out/`; package metadata is in [`package.json`](package.json), TypeScript config in [`tsconfig.json`](tsconfig.json).

---

## 📦 Prerequisites

- 🦾 [Syft](https://github.com/anchore/syft) — `brew install syft`
- 🟢 Node.js (only needed for local development)
- 🌐 Outbound HTTPS to `https://api.osv.dev` for vulnerability scanning

---

## 🔗 Related

| Doc                                | Purpose               |
| ---------------------------------- | --------------------- |
| [`data/README.md`](../README.md)   | Static-data overview  |
| [`docs/FAQ.md`](../../docs/FAQ.md) | Common SBOM questions |
