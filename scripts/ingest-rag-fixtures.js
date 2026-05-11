const fs = require('node:fs');
const path = require('node:path');

const rootDir = path.resolve(__dirname, '..');
const fixturesDir = path.join(rootDir, 'backend', 'ai-gateway', 'dev-fixtures');
const manifestPath = path.join(fixturesDir, 'manifest.json');

const gatewayBaseUrl = process.env.AI_GATEWAY_URL || 'http://localhost:8000';
const ingestUrl = `${gatewayBaseUrl.replace(/\/$/, '')}/ingest`;
const devRole = process.env.DEV_INGEST_ROLE || 'super_admin';

function loadManifest() {
  if (!fs.existsSync(manifestPath)) {
    throw new Error(`Manifest not found: ${manifestPath}`);
  }

  const raw = fs.readFileSync(manifestPath, 'utf8');
  const parsed = JSON.parse(raw);
  if (!Array.isArray(parsed) || parsed.length === 0) {
    throw new Error('Manifest must be a non-empty array');
  }
  return parsed;
}

async function ingestOne(entry) {
  const requiredFields = ['file', 'subject', 'grade_level', 'country'];
  for (const field of requiredFields) {
    if (!entry[field]) {
      throw new Error(`Missing field "${field}" in manifest entry: ${JSON.stringify(entry)}`);
    }
  }

  const filePath = path.join(fixturesDir, entry.file);
  if (!fs.existsSync(filePath)) {
    throw new Error(`Fixture file not found: ${filePath}`);
  }

  const fileBuffer = fs.readFileSync(filePath);
  const form = new FormData();
  form.append(
    'file',
    new Blob([fileBuffer], {
      type: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    }),
    entry.file,
  );
  form.append('subject', entry.subject);
  form.append('grade_level', entry.grade_level);
  form.append('country', entry.country);

  const response = await fetch(ingestUrl, {
    method: 'POST',
    headers: {
      'X-Dev-Role': devRole,
    },
    body: form,
  });

  const bodyText = await response.text();
  if (!response.ok) {
    throw new Error(`Ingest failed for ${entry.file}: ${response.status} ${response.statusText} - ${bodyText}`);
  }

  let json;
  try {
    json = JSON.parse(bodyText);
  } catch {
    throw new Error(`Ingest returned non-JSON response for ${entry.file}: ${bodyText}`);
  }

  return {
    file: entry.file,
    docId: json.docId,
    chunksIngested: json.chunksIngested,
  };
}

async function main() {
  const manifest = loadManifest();

  console.log(`Ingesting ${manifest.length} fixture(s) to ${ingestUrl}`);
  console.log(`Using dev role: ${devRole}`);

  const results = [];
  for (const entry of manifest) {
    const result = await ingestOne(entry);
    results.push(result);
    console.log(`OK ${result.file} -> docId=${result.docId}, chunks=${result.chunksIngested}`);
  }

  console.log('Done.');
  console.log(JSON.stringify(results, null, 2));
}

main().catch((error) => {
  console.error('Batch ingestion failed.');
  console.error(error.message || error);
  process.exit(1);
});
