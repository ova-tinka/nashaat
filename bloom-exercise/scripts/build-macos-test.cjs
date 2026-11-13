// Build a separate, explicitly configured test app for notarization.
// Expo does not load dotenv files; only the two test settings below are read locally.
const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

if (process.platform !== 'darwin') throw new Error('The macOS test build must run on macOS.');
const root = path.resolve(__dirname, '..');
const testConfig = {};
const configPath = path.join(root, '.env.notary-test.local');
if (fs.existsSync(configPath)) {
  for (const line of fs.readFileSync(configPath, 'utf8').split(/\r?\n/)) {
    const match = line.match(/^\s*(BLOOM_TEST_PROJECT_REF|BLOOM_TEST_SUPABASE_PUBLISHABLE_KEY)\s*=\s*([^#]*?)\s*$/);
    if (match) testConfig[match[1]] = match[2].replace(/^(?:"([^"]*)"|'([^']*)')$/, (_, double, single) => double ?? single);
  }
}
const ref = process.env.BLOOM_TEST_PROJECT_REF || testConfig.BLOOM_TEST_PROJECT_REF;
let key = process.env.BLOOM_TEST_SUPABASE_PUBLISHABLE_KEY || testConfig.BLOOM_TEST_SUPABASE_PUBLISHABLE_KEY;
if (!key && process.env.BLOOM_TEST_PUBLISHABLE_KEY_FILE) {
  key = fs.readFileSync(process.env.BLOOM_TEST_PUBLISHABLE_KEY_FILE, 'utf8').trim();
}
if (!key && process.env.BLOOM_TEST_FETCH_CLI === '1' && ref && /^[a-z0-9]{20}$/.test(ref)) {
  const result = spawnSync('supabase', ['projects', 'api-keys', '--project-ref', ref, '--output', 'json'], { encoding: 'utf8' });
  if (result.status !== 0) throw new Error('Supabase CLI could not access the test project. Check the signed-in account and project access.');
  const response = JSON.parse(result.stdout);
  const entries = Array.isArray(response) ? response : response.keys;
  if (!Array.isArray(entries)) throw new Error('Supabase CLI returned an unexpected key list.');
  const item = entries.find((entry) => entry && !entry.disabled && Object.values(entry).some((value) => typeof value === 'string' && value.startsWith('sb_publishable_')));
  key = item && Object.values(item).find((value) => typeof value === 'string' && value.startsWith('sb_publishable_'));
}

if (!ref || !/^[a-z0-9]{20}$/.test(ref)) throw new Error('Set BLOOM_TEST_PROJECT_REF to the non-production Supabase project reference.');
if (!key || !key.startsWith('sb_publishable_')) throw new Error('Set BLOOM_TEST_SUPABASE_PUBLISHABLE_KEY to the test project’s publishable key (sb_publishable_...). Never use a secret or service-role key.');
if (!process.env.BLOOM_TEAM_ID || !process.env.APPLE_SIGNING_IDENTITY) throw new Error('Set BLOOM_TEAM_ID and APPLE_SIGNING_IDENTITY for the signing pass.');
const url = `https://${ref}.supabase.co`;
const target = path.join(root, 'src-tauri', 'target', 'notary-test');
const app = path.join(target, 'release', 'bundle', 'macos', 'Bloom Exercise.app');
const env = { ...process.env };
for (const name of Object.keys(env)) if (name.startsWith('EXPO_PUBLIC_')) delete env[name];
Object.assign(env, {
  EXPO_NO_DOTENV: '1', EXPO_PUBLIC_SUPABASE_URL: url,
  EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY: key, CARGO_TARGET_DIR: target,
  BLOOM_APP_BUNDLE: app,
});
function run(command, args) {
  const result = spawnSync(command, args, { cwd: root, env, stdio: 'inherit' });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${command} failed; the test build was not submitted.`);
}
run('node', ['scripts/desktop-tauri.cjs', 'build', '--bundles', 'app']);
// Check the exported frontend before treating the archive as reviewable.
const distFiles = [];
function collect(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const file = path.join(dir, entry.name);
    if (entry.isDirectory()) collect(file);
    else if (/\.(js|html|json)$/.test(entry.name)) distFiles.push(fs.readFileSync(file, 'utf8'));
  }
}
collect(path.join(root, 'dist'));
const exported = distFiles.join('\n');
if (!exported.includes(url) || !exported.includes(key)) throw new Error('The exported app does not contain the selected test configuration.');
if (exported.includes('http://127.0.0.1:54321') || exported.includes('http://localhost:54321')) throw new Error('The exported app still contains the local Supabase URL.');
run('npm', ['run', 'desktop:sign']);
if (!fs.existsSync(app)) throw new Error('The signed test app was not created at the expected path.');
const zip = path.join(target, 'Bloom Exercise test.zip');
run('/usr/bin/ditto', ['-c', '-k', '--sequesterRsrc', '--keepParent', app, zip]);
const listing = spawnSync('/usr/bin/unzip', ['-Z1', zip], { encoding: 'utf8' });
if (listing.status !== 0 || listing.stdout.split('\n').some((name) => path.posix.basename(name).startsWith('.env'))) {
  fs.rmSync(zip, { force: true });
  throw new Error('Archive inspection failed or found an environment file; the archive was removed.');
}
process.stdout.write(`Signed test app and archive are ready in ${target}. Nothing was submitted.\n`);
