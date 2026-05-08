import * as https from 'https';
import type {
  SBOMComponent,
  OSVBatchRequest,
  OSVBatchResponse,
  OSVVulnerability
} from '../types';

const OSV_HOST = 'api.osv.dev';
const OSV_PATH = '/v1/querybatch';

/**
 * Query OSV.dev for vulnerabilities affecting the given components.
 * Only components with a purl are queried (syft always produces purls).
 *
 * Returns a map of `name@version` → vulnerabilities.
 */
export async function scanComponents(
  components: SBOMComponent[],
  batchSize = 50
): Promise<Map<string, OSVVulnerability[]>> {
  const results = new Map<string, OSVVulnerability[]>();
  const queryable = components.filter((c) => !!c.purl);

  for (let i = 0; i < queryable.length; i += batchSize) {
    const batch = queryable.slice(i, i + batchSize);
    const body: OSVBatchRequest = {
      queries: batch.map((c) => ({ package: { purl: c.purl! } }))
    };

    const response = await postOSV(body);

    response.results.forEach((result, idx) => {
      const comp = batch[idx];
      results.set(`${comp.name}@${comp.version ?? ''}`, result.vulns ?? []);
    });
  }

  return results;
}

function postOSV(body: OSVBatchRequest): Promise<OSVBatchResponse> {
  return new Promise((resolve, reject) => {
    const payload = JSON.stringify(body);
    const options: https.RequestOptions = {
      hostname: OSV_HOST,
      path: OSV_PATH,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(payload),
        Accept: 'application/json'
      }
    };

    const req = https.request(options, (res) => {
      const chunks: Buffer[] = [];
      res.on('data', (chunk: Buffer) => chunks.push(chunk));
      res.on('end', () => {
        if (res.statusCode !== 200) {
          reject(
            new Error(`OSV API returned HTTP ${res.statusCode ?? 'unknown'}`)
          );
          return;
        }
        try {
          resolve(
            JSON.parse(Buffer.concat(chunks).toString()) as OSVBatchResponse
          );
        } catch {
          reject(new Error('Failed to parse OSV.dev response'));
        }
      });
    });

    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}
