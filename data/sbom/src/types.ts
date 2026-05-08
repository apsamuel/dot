// ---------------------------------------------------------------------------
// CycloneDX v1.5+ types (subset used by this extension)
// ---------------------------------------------------------------------------

export interface CycloneDXBom {
  bomFormat: 'CycloneDX';
  specVersion: string;
  version: number;
  serialNumber?: string;
  metadata?: CycloneDXMetadata;
  components: CycloneDXComponent[];
}

export interface CycloneDXMetadata {
  timestamp?: string;
  tools?: CycloneDXTool[];
  component?: CycloneDXComponent;
}

export interface CycloneDXTool {
  vendor?: string;
  name: string;
  version?: string;
}

export interface CycloneDXComponent {
  type: string;
  'bom-ref'?: string;
  name: string;
  version?: string;
  purl?: string;
  description?: string;
  licenses?: CycloneDXLicenseChoice[];
}

export interface CycloneDXLicenseChoice {
  license?: { id?: string; name?: string };
  expression?: string;
}

// ---------------------------------------------------------------------------
// SPDX v2.3 types (subset used by this extension)
// ---------------------------------------------------------------------------

export interface SPDXDocument {
  spdxVersion: string;
  SPDXID: string;
  name: string;
  documentNamespace: string;
  creationInfo?: { created: string; creators: string[] };
  packages: SPDXPackage[];
}

export interface SPDXPackage {
  SPDXID: string;
  name: string;
  versionInfo?: string;
  downloadLocation?: string;
  filesAnalyzed?: boolean;
  licenseConcluded?: string;
  licenseDeclared?: string;
  externalRefs?: SPDXExternalRef[];
}

export interface SPDXExternalRef {
  referenceCategory: string;
  referenceType: string;
  referenceLocator: string;
}

// ---------------------------------------------------------------------------
// OSV.dev API types
// ---------------------------------------------------------------------------

export interface OSVBatchRequest {
  queries: OSVPackageQuery[];
}

export interface OSVPackageQuery {
  package: { purl: string };
}

export interface OSVBatchResponse {
  results: OSVResult[];
}

export interface OSVResult {
  vulns?: OSVVulnerability[];
}

export interface OSVVulnerability {
  id: string;
  summary?: string;
  details?: string;
  aliases?: string[];
  published: string;
  modified: string;
  severity?: { type: string; score: string }[];
  database_specific?: { severity?: string };
  affected?: { package: { name: string; ecosystem: string } }[];
}

// ---------------------------------------------------------------------------
// Internal / unified model
// ---------------------------------------------------------------------------

export interface SBOMComponent {
  name: string;
  version?: string;
  purl?: string;
  license?: string;
  type?: string;
  vulnerabilities?: OSVVulnerability[];
}

export interface SBOMDocument {
  format: 'cyclonedx' | 'spdx';
  name: string;
  filePath: string;
  components: SBOMComponent[];
  generatedAt: string;
  vulnerabilityCount?: number;
}
