const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');

if (process.platform !== 'darwin') throw new Error('The macOS app must be signed on macOS.');

const team = process.env.BLOOM_TEAM_ID || process.env.APPLE_TEAM_ID;
const identity = process.env.APPLE_SIGNING_IDENTITY;
const bundleId = 'com.focusflow.focusFlowFlutter';
const filterId = `${bundleId}.filter`;
const brokerId = `${bundleId}.policy-broker`;
const appPath = path.resolve(process.env.BLOOM_APP_BUNDLE || path.join(__dirname, '..', 'src-tauri', 'target', 'release', 'bundle', 'macos', 'Bloom Exercise.app'));
const hostProfile = path.resolve(process.env.BLOOM_HOST_PROFILE || path.join(os.homedir(), 'Downloads', 'Bloom_macOS_Host.provisionprofile'));
const filterProfile = path.resolve(process.env.BLOOM_FILTER_PROFILE || path.join(os.homedir(), 'Downloads', 'Bloom_macOS_Filter.provisionprofile'));
const macosDir = path.join(__dirname, '..', 'src-tauri', 'macos');
const generatedDir = path.join(macosDir, 'build');

function run(command, args, options = {}) {
  const result = spawnSync(command, args, { encoding: 'utf8', ...options });
  if (result.error) throw result.error;
  if (result.status !== 0) {
    const details = [result.stdout, result.stderr].filter(Boolean).join('\n').trim();
    throw new Error(`${path.basename(command)} failed${details ? `:\n${details}` : '.'}`);
  }
  return result.stdout || '';
}

function profileValue(profilePath, plistPath) {
  const result = run('/usr/libexec/PlistBuddy', ['-c', `Print ${plistPath}`, profilePath]);
  return result.trim();
}

function verifyProfile(profilePath, expectedAppId, needsInstallEntitlement) {
  if (!fs.existsSync(profilePath)) throw new Error(`Provisioning profile not found: ${profilePath}`);
  const tempDir = fs.mkdtempSync(path.join(os.tmpdir(), 'bloom-profile-'));
  const decoded = path.join(tempDir, 'profile.plist');
  try {
    const output = run('/usr/bin/security', ['cms', '-D', '-i', profilePath]);
    fs.writeFileSync(decoded, output);
    const appId = profileValue(decoded, ':Entitlements:com.apple.application-identifier');
    const profileTeam = profileValue(decoded, ':TeamIdentifier:0');
    const network = profileValue(decoded, ':Entitlements:com.apple.developer.networking.networkextension');
    if (appId !== `${team}.${expectedAppId}`) throw new Error(`${path.basename(profilePath)} is for ${appId}; expected ${team}.${expectedAppId}.`);
    if (profileTeam !== team) throw new Error(`${path.basename(profilePath)} belongs to team ${profileTeam}; expected ${team}.`);
    if (!network.includes('content-filter-provider-systemextension')) throw new Error(`${path.basename(profilePath)} does not authorize the content filter system extension.`);
    if (needsInstallEntitlement && profileValue(decoded, ':Entitlements:com.apple.developer.system-extension.install') !== 'true') {
      throw new Error(`${path.basename(profilePath)} does not authorize system extension installation.`);
    }
  } finally {
    fs.rmSync(tempDir, { recursive: true, force: true });
  }
}

function sign(target, identifier, entitlements) {
  const args = ['--force', '--sign', identity, '--options', 'runtime', '--timestamp', '--identifier', identifier];
  if (entitlements) args.push('--entitlements', entitlements, '--generate-entitlement-der');
  run('/usr/bin/codesign', [...args, target], { stdio: 'inherit' });
  const result = spawnSync('/usr/bin/codesign', ['-dv', '--verbose=4', target], { encoding: 'utf8' });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`Could not inspect signature for ${target}.`);
  const details = `${result.stdout || ''}\n${result.stderr || ''}`;
  if (!details.includes(`TeamIdentifier=${team}`)) throw new Error(`Signed code has no matching Team ID: ${target}`);
}

if (!team || !/^[A-Z0-9]{10}$/.test(team)) throw new Error('Set BLOOM_TEAM_ID (or APPLE_TEAM_ID) to the 10-character Apple Team ID.');
if (!identity) throw new Error('Set APPLE_SIGNING_IDENTITY to the exact Developer ID Application identity from `security find-identity -v -p codesigning`.');
if (!fs.existsSync(appPath)) throw new Error(`Build the macOS app first; not found: ${appPath}`);
if (!fs.existsSync(path.join(generatedDir, 'Host.entitlements')) || !fs.existsSync(path.join(generatedDir, 'Filter.entitlements'))) {
  throw new Error('Generated entitlements are missing. Rebuild with BLOOM_TEAM_ID set before signing.');
}
for (const generated of ['Host.entitlements', 'Agent.entitlements', 'Filter.entitlements', 'BloomInfo.plist', `${filterId}.systemextension/Contents/Info.plist`, `${brokerId}.plist`]) {
  const generatedPath = path.join(generatedDir, generated);
  if (!fs.existsSync(generatedPath)) throw new Error(`Generated macOS signing input is missing: ${generatedPath}`);
  const contents = fs.readFileSync(generatedPath, 'utf8');
  if (!contents.includes(`${team}.`) || contents.includes('0000000000.')) {
    throw new Error(`Generated macOS signing input ${generated} does not use team ${team}. Rebuild with BLOOM_TEAM_ID set.`);
  }
}

const identityList = run('/usr/bin/security', ['find-identity', '-v', '-p', 'codesigning']);
if (!identityList.includes(`"${identity}"`) || !identity.includes(`(${team})`)) {
  throw new Error(`The signing identity must be an installed Developer ID Application certificate for team ${team}.`);
}
verifyProfile(hostProfile, bundleId, true);
verifyProfile(filterProfile, filterId, false);
for (const [name, identifier] of [['Host.entitlements', bundleId], ['Filter.entitlements', filterId]]) {
  const entitlements = path.join(generatedDir, name);
  if (profileValue(entitlements, ':com.apple.application-identifier') !== `${team}.${identifier}`
      || profileValue(entitlements, ':com.apple.developer.team-identifier') !== team) {
    throw new Error(`${name} does not identify the matching team and app. Rebuild the macOS signing inputs.`);
  }
}

const infoPlist = path.join(appPath, 'Contents', 'Info.plist');
const appIdentifier = run('/usr/libexec/PlistBuddy', ['-c', 'Print :CFBundleIdentifier', infoPlist]).trim();
if (appIdentifier !== bundleId) throw new Error(`Built app has identifier ${appIdentifier}; expected ${bundleId}.`);
const supabaseUrl = run('/usr/libexec/PlistBuddy', ['-c', 'Print :BloomSupabaseURL', infoPlist]).trim();
const supabaseKey = run('/usr/libexec/PlistBuddy', ['-c', 'Print :BloomSupabasePublishableKey', infoPlist]).trim();
if (!supabaseUrl || !supabaseKey || /service[_ -]?role|secret/i.test(supabaseKey)) {
  throw new Error('The app must embed its public Supabase endpoint and publishable key; secret keys are forbidden.');
}
const extensionUsage = run('/usr/libexec/PlistBuddy', ['-c', 'Print :NSSystemExtensionUsageDescription', infoPlist]).trim();
if (!extensionUsage) throw new Error('The app is missing a system extension usage description.');
const appGroup = run('/usr/libexec/PlistBuddy', ['-c', 'Print :BloomAppGroup', infoPlist]).trim();
if (!appGroup.startsWith(`${team}.`)) throw new Error(`Built app uses app group ${appGroup}; rebuild with BLOOM_TEAM_ID=${team}.`);

const filterBundle = path.join(appPath, 'Contents', 'Library', 'SystemExtensions', `${filterId}.systemextension`);
const filterContents = path.join(filterBundle, 'Contents');
const filterUsage = run('/usr/libexec/PlistBuddy', ['-c', 'Print :NSSystemExtensionUsageDescription', path.join(filterContents, 'Info.plist')]).trim();
if (!filterUsage) throw new Error('The system extension is missing its usage description.');
const machService = run('/usr/libexec/PlistBuddy', ['-c', 'Print :NetworkExtension:NEMachServiceName', path.join(filterContents, 'Info.plist')]).trim();
if (!machService.startsWith(`${appGroup}.`)) throw new Error('The system extension Mach service must be prefixed with the app group.');
const brokerPlist = path.join(appPath, 'Contents', 'Library', 'LaunchDaemons', `${brokerId}.plist`);
const brokerExecutable = path.join(appPath, 'Contents', 'MacOS', 'BloomPolicyBroker');
const brokerLabel = run('/usr/libexec/PlistBuddy', ['-c', 'Print :Label', brokerPlist]).trim();
const expectedBrokerService = `${appGroup}.policy`;
const brokerService = run('/usr/libexec/PlistBuddy', ['-c', `Print :MachServices:${expectedBrokerService}`, brokerPlist]).trim();
if (brokerLabel !== brokerId || brokerService !== 'true') throw new Error('The website policy broker LaunchDaemon is misconfigured.');
const hostExecutable = path.join(appPath, 'Contents', 'MacOS', 'libBloomFilterHost.dylib');
const monitorExecutable = path.join(appPath, 'Contents', 'MacOS', 'BloomAppMonitor');
for (const required of [filterBundle, path.join(filterContents, 'MacOS', 'BloomFilter'), hostExecutable, monitorExecutable, brokerExecutable]) {
  if (!fs.existsSync(required)) throw new Error(`Required macOS component is missing from the app bundle: ${required}`);
}

fs.copyFileSync(hostProfile, path.join(appPath, 'Contents', 'embedded.provisionprofile'));
fs.copyFileSync(filterProfile, path.join(filterContents, 'embedded.provisionprofile'));

// Sign nested code first. Tauri signs the outer app during bundling; this pass
// replaces that signature after embedding the Developer ID profiles.
sign(filterBundle, filterId, path.join(generatedDir, 'Filter.entitlements'));
sign(hostExecutable, `${bundleId}.host-library`);
sign(monitorExecutable, `${bundleId}.monitor`, path.join(generatedDir, 'Agent.entitlements'));
sign(brokerExecutable, brokerId);
sign(appPath, bundleId, path.join(generatedDir, 'Host.entitlements'));
run('/usr/bin/codesign', ['--verify', '--deep', '--strict', '--verbose=2', appPath], { stdio: 'inherit' });
process.stdout.write(`Signed and verified ${appPath}\n`);
