import * as vscode from 'vscode';
import { execFile } from 'child_process';
import { promisify } from 'util';

const execFileAsync = promisify(execFile);

export type SyftOutputFormat = 'cyclonedx-json' | 'spdx-json';

function getSyftPath(): string {
  return vscode.workspace
    .getConfiguration('sbom')
    .get<string>('syftPath', 'syft');
}

/**
 * Verify syft is reachable and return its version output.
 * Throws if syft cannot be found or executed.
 */
export async function checkSyft(): Promise<string> {
  const syftPath = getSyftPath();
  try {
    const { stdout } = await execFileAsync(syftPath, ['version']);
    return stdout;
  } catch {
    throw new Error(
      `syft not found at "${syftPath}". Install via: brew install syft\n` +
        `Or set sbom.syftPath to the full binary path.`
    );
  }
}

/**
 * Run `syft scan <targetPath> -o <format>=<outputPath>`.
 * Uses execFile (no shell) to prevent injection.
 */
export async function generateSBOM(
  targetPath: string,
  outputPath: string,
  format: SyftOutputFormat
): Promise<void> {
  const syftPath = getSyftPath();
  try {
    await execFileAsync(syftPath, [
      'scan',
      targetPath,
      '-o',
      `${format}=${outputPath}`
    ]);
  } catch (err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    throw new Error(`syft scan failed: ${msg}`);
  }
}
