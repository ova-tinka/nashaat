const { spawnSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const bloomDir = path.resolve(__dirname, '..');
const projectDir = path.resolve(bloomDir, '..');
const team = process.env.BLOOM_TEAM_ID || 'SSYR69RTPK';
const identity = process.env.APPLE_SIGNING_IDENTITY || 'Developer ID Application: Ayham Dwairy (SSYR69RTPK)';

function run(command, args, options = {}) {
  const result = spawnSync(command, args, { encoding: 'utf8', ...options });
  if (result.error) throw result.error;
  if (result.status !== 0) {
    const details = `${result.stdout || ''}\n${result.stderr || ''}`
      .split(/\r?\n/)
      .filter(line => !/(?:publishable[_ ]key|anon[_ ]key|service[_ ]role[_ ]key|secret|token|password|jwt)/i.test(line))
      .map(line => line.replace(/eyJ[A-Za-z0-9_.-]{20,}/g, '[redacted token]')
        .replace(/postgres(?:ql)?:\/\/[^\s"']+/gi, '[local db url]'))
      .join('\n');
    throw new Error(`${path.basename(command)} failed (${result.status}).${details.trim() ? `\n${details.trim()}` : ''}`);
  }
  return result.stdout || '';
}

const status = JSON.parse(run('supabase', ['status', '-o', 'json'], { cwd: projectDir }));
const apiUrl = status.API_URL;
const publishableKey = status.PUBLISHABLE_KEY || status.ANON_KEY;
if (!apiUrl || !publishableKey) throw new Error('Local Supabase is not running. Start it with `supabase start` from the Nashaat repository root.');
const api = new URL(apiUrl);
if (!['127.0.0.1', 'localhost', '[::1]'].includes(api.hostname)) {
  throw new Error(`Refusing to build with a non-local Supabase API host: ${api.hostname}`);
}

const env = {
  ...process.env,
  EXPO_PUBLIC_SUPABASE_URL: apiUrl,
  EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY: publishableKey,
  BLOOM_TEAM_ID: team,
  APPLE_TEAM_ID: team,
  APPLE_SIGNING_IDENTITY: identity,
};

// The signing pass runs after bundling, so build only the app; a DMG made
// beforehand would contain the wrong signature and provisioning profiles.
run('node', ['scripts/desktop-tauri.cjs', 'build', '--bundles', 'app'], { cwd: bloomDir, env, stdio: 'inherit' });
run('npm', ['run', 'desktop:sign'], { cwd: bloomDir, env, stdio: 'inherit' });

const dist = path.join(bloomDir, 'dist');
const bundles = [];
function walk(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const file = path.join(directory, entry.name);
    if (entry.isDirectory()) walk(file);
    else if (/\.(js|html|json)$/.test(entry.name)) bundles.push(fs.readFileSync(file, 'utf8'));
  }
}
walk(dist);
const exportedApp = bundles.join('\n');
if (!exportedApp.includes(apiUrl) || !exportedApp.includes(publishableKey)) {
  throw new Error('The exported app is missing the local Supabase settings.');
}
process.stdout.write(`Built and signed Bloom for local Supabase at ${api.origin}.\n`);
