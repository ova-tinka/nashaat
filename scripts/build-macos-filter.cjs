const fs = require('node:fs');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const { bloomFilterVersion: filterVersion } = require('../package.json');

if (process.platform !== 'darwin') throw new Error('The macOS filter must be built on macOS.');
const team = process.env.BLOOM_TEAM_ID || process.env.APPLE_TEAM_ID || '0000000000';
const bundleId = 'com.focusflow.focusFlowFlutter';
const extensionId = `${bundleId}.filter`;
const monitorId = `${bundleId}.monitor`;
const brokerId = `${bundleId}.policy-broker`;
if (process.env.APPLE_SIGNING_IDENTITY && !process.env.BLOOM_TEAM_ID && !process.env.APPLE_TEAM_ID) {
  throw new Error('Set BLOOM_TEAM_ID or APPLE_TEAM_ID when preparing a signed macOS build.');
}
if (!/^[A-Z0-9]{10}$/.test(team)) throw new Error('BLOOM_TEAM_ID must be a 10-character Apple team identifier.');
if (typeof filterVersion !== 'string' || !/^\d+(?:\.\d+){0,2}$/.test(filterVersion)) {
  throw new Error('bloomFilterVersion must be a numeric one-to-three-part system-extension version.');
}
const root = path.resolve(__dirname, '..', 'src-tauri', 'macos');
const source = path.join(root, 'filter');
const output = path.join(root, 'build', `${extensionId}.systemextension`, 'Contents');
const architecture = process.arch === 'arm64' ? 'arm64' : process.arch === 'x64' ? 'x86_64' : null;
if (!architecture) throw new Error('Unsupported macOS architecture.');
const target = `${architecture}-apple-macos13.0`;
const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL;
const supabasePublishableKey = process.env.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
const escapePlistString = (value) => value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
const isPublicSupabaseKey = (key) => {
  if (key?.startsWith('sb_publishable_')) return true;
  try {
    const payload = JSON.parse(Buffer.from(key.split('.')[1], 'base64url').toString('utf8'));
    return payload.role === 'anon';
  } catch { return false; }
};
if (Boolean(supabaseUrl) !== Boolean(supabasePublishableKey)) {
  throw new Error('Set both EXPO_PUBLIC_SUPABASE_URL and EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY for native countdown authorization.');
}
let supabaseInfo = '';
if (supabaseUrl && supabasePublishableKey) {
  let parsed;
  try { parsed = new URL(supabaseUrl); } catch { throw new Error('EXPO_PUBLIC_SUPABASE_URL must be a valid URL.'); }
  const localHost = ['127.0.0.1', 'localhost', '[::1]'].includes(parsed.hostname);
  if (!((parsed.protocol === 'https:' && !parsed.port)
    || (parsed.protocol === 'http:' && localHost && Boolean(parsed.port)))) {
    throw new Error('Native countdown authorization requires HTTPS (HTTP is allowed only for a loopback development server).');
  }
  if (parsed.username || parsed.password || parsed.search || parsed.hash || (parsed.pathname !== '' && parsed.pathname !== '/')) {
    throw new Error('EXPO_PUBLIC_SUPABASE_URL must identify the API origin without credentials, path, or query.');
  }
  if (!isPublicSupabaseKey(supabasePublishableKey)) {
    throw new Error('Native countdown authorization accepts only a Supabase publishable key or anon key.');
  }
  supabaseInfo = `<key>BloomSupabaseURL</key><string>${escapePlistString(parsed.origin)}</string><key>BloomSupabasePublishableKey</key><string>${escapePlistString(supabasePublishableKey)}</string>`;
}
fs.mkdirSync(path.join(output, 'MacOS'), { recursive: true });
const command = spawnSync('xcrun', ['swiftc', '-O', '-target', target, '-module-name', 'BloomFilter',
  path.join(root, 'BloomAppGroup.swift'), path.join(source, 'WebsiteRules.swift'), path.join(source, 'TLSHostname.swift'), path.join(source, 'FilterCreditClock.swift'), path.join(root, 'MacPolicyBroker.swift'), path.join(root, 'MacPolicyBrokerClient.swift'), path.join(root, 'MacUsageStore.swift'), path.join(root, 'MacWebsiteUsageAccess.swift'), path.join(source, 'BloomFilterDataProvider.swift'),
  path.join(source, 'MacFlowSource.swift'),
  path.join(source, 'main.swift'), '-lbsm', '-o', path.join(output, 'MacOS', 'BloomFilter')], { stdio: 'inherit' });
if (command.error) throw command.error;
if (command.status !== 0) process.exit(command.status || 1);
const host = spawnSync('xcrun', ['swiftc', '-O', '-target', target, '-parse-as-library', '-emit-library', '-module-name', 'BloomFilterHost',
  path.join(root, 'BloomAppGroup.swift'), path.join(source, 'WebsiteRules.swift'), path.join(source, 'FilterCreditClock.swift'), path.join(source, 'MacFlowSource.swift'), path.join(root, 'MacPolicyBroker.swift'), path.join(root, 'MacPolicyBrokerClient.swift'), path.join(root, 'MacHostsAuthorization.swift'), path.join(root, 'MacAppRules.swift'), path.join(root, 'MacInstalledApps.swift'), path.join(root, 'MacBrowserURL.swift'), path.join(root, 'MacBrowserAddress.swift'), path.join(root, 'MacServiceRegistrationPolicy.swift'), path.join(root, 'MacUsageStore.swift'), path.join(root, 'BloomAppController.swift'), path.join(root, 'BloomFilterController.swift'),
  path.join(root, 'BloomPolicyBrokerController.swift'), path.join(root, 'BloomPolicyBrokerReadiness.swift'), path.join(root, 'MacSharedPreferences.swift'), path.join(root, 'SupabaseCreditGrant.swift'), path.join(root, 'SupabaseUsageGrant.swift'), path.join(root, 'BloomFilterActivationPolicy.swift'),
  path.join(root, 'BloomWebsiteCleanupPolicy.swift'), path.join(root, 'MacHostsLifecycle.swift'), path.join(root, 'BloomFilterHost.swift'), '-lbsm', '-o', path.join(root, 'build', 'libBloomFilterHost.dylib')], { stdio: 'inherit' });
if (host.error) throw host.error;
if (host.status !== 0) process.exit(host.status || 1);
const agent = spawnSync('xcrun', ['swiftc', '-O', '-target', target, '-parse-as-library', '-module-name', 'BloomAppMonitor',
  path.join(root, 'BloomAppGroup.swift'), path.join(source, 'WebsiteRules.swift'), path.join(source, 'FilterCreditClock.swift'), path.join(source, 'MacFlowSource.swift'), path.join(root, 'MacPolicyBroker.swift'), path.join(root, 'MacPolicyBrokerClient.swift'), path.join(root, 'MacAppRules.swift'), path.join(root, 'MacAppEnforcement.swift'), path.join(root, 'MacMonitorRules.swift'), path.join(root, 'MacBrowserURL.swift'), path.join(root, 'MacBrowserAddress.swift'), path.join(root, 'MacUsageStore.swift'), path.join(root, 'MacSharedPreferences.swift'), path.join(root, 'BloomAppMonitor.swift'),
  '-lbsm', '-o', path.join(root, 'build', 'BloomAppMonitor')], { stdio: 'inherit' });
if (agent.error) throw agent.error;
if (agent.status !== 0) process.exit(agent.status || 1);
const brokerIdentity = path.join(root, 'build', 'BloomPolicyBrokerBuildIdentity.swift');
fs.writeFileSync(brokerIdentity, `enum BloomPolicyBrokerBuildIdentity { static let teamIdentifier = "${team}" }\n`);
const broker = spawnSync('xcrun', ['swiftc', '-O', '-target', target, '-parse-as-library', '-module-name', 'BloomPolicyBroker',
  path.join(source, 'WebsiteRules.swift'), path.join(source, 'FilterCreditClock.swift'), path.join(source, 'MacFlowSource.swift'), path.join(root, 'MacPolicyBroker.swift'), path.join(root, 'MacPolicyBrokerIdentity.swift'), path.join(root, 'MacHostsPolicy.swift'), path.join(root, 'MacHostsTransaction.swift'), path.join(root, 'MacHostsAuthorization.swift'), path.join(root, 'MacHostsHelper.swift'), path.join(root, 'MacHostsRecovery.swift'), path.join(root, 'MacHostsRecoveryCoordinator.swift'), path.join(root, 'SupabaseUsageGrant.swift'), path.join(root, 'SupabaseExistingUsageGrant.swift'), path.join(root, 'MacHostsVerifiedUsage.swift'), path.join(root, 'MacHostsEnrollment.swift'), brokerIdentity, path.join(root, 'BloomPolicyBroker.swift'),
  '-lbsm', '-o', path.join(root, 'build', 'BloomPolicyBroker')], { stdio: 'inherit' });
if (broker.error) throw broker.error;
if (broker.status !== 0) process.exit(broker.status || 1);
const plist = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>${extensionId}</string>
<key>CFBundleName</key><string>BloomFilter</string>
<key>CFBundleExecutable</key><string>BloomFilter</string>
<key>CFBundlePackageType</key><string>SYSX</string>
<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
<key>CFBundleShortVersionString</key><string>${filterVersion}</string>
<key>CFBundleVersion</key><string>${filterVersion}</string>
<key>NSSystemExtensionUsageDescription</key><string>Bloom uses a system extension to block the websites you choose during focus time.</string>
<key>BloomAppGroup</key><string>${team}.com.nashaat.bloomexercise</string>
<key>NetworkExtension</key><dict>
<key>NEMachServiceName</key><string>${team}.com.nashaat.bloomexercise.filter</string>
<key>NEProviderClasses</key><dict><key>com.apple.networkextension.filter-data</key><string>BloomFilter.BloomFilterDataProvider</string></dict>
</dict></dict></plist>`;
fs.writeFileSync(path.join(output, 'Info.plist'), plist);
for (const [input, name] of [[path.join(root, 'Host.entitlements'), 'Host.entitlements'], [path.join(root, 'Agent.entitlements'), 'Agent.entitlements'], [path.join(source, 'filter.entitlements'), 'Filter.entitlements']]) {
  const template = fs.readFileSync(input, 'utf8');
  fs.writeFileSync(path.join(root, 'build', name), template.replaceAll('$(TeamIdentifierPrefix)', `${team}.`).replaceAll('$(TeamTeamIdentifier)', team));
}
fs.writeFileSync(path.join(root, 'build', 'BloomInfo.plist'), `<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>BloomAppGroup</key><string>${team}.com.nashaat.bloomexercise</string>${supabaseInfo}<key>NSSystemExtensionUsageDescription</key><string>Bloom uses a system extension to block the websites you choose during focus time.</string><key>NSAppleEventsUsageDescription</key><string>Bloom reads the active tab address in supported browsers on this Mac to enforce your website rules and measure screen time. Addresses stay on this Mac.</string></dict></plist>`);
fs.writeFileSync(path.join(root, 'build', `${monitorId}.plist`), `<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>Label</key><string>${monitorId}</string><key>BundleProgram</key><string>Contents/MacOS/BloomAppMonitor</string><key>RunAtLoad</key><true/><key>KeepAlive</key><dict><key>SuccessfulExit</key><false/></dict></dict></plist>`);
fs.writeFileSync(path.join(root, 'build', `${brokerId}.plist`), `<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>Label</key><string>${brokerId}</string><key>BundleProgram</key><string>Contents/MacOS/BloomPolicyBroker</string><key>MachServices</key><dict><key>${team}.com.nashaat.bloomexercise.policy</key><true/></dict><key>RunAtLoad</key><true/><key>KeepAlive</key><true/><key>ProcessType</key><string>Background</string></dict></plist>`);
process.stdout.write('Built an unsigned macOS system extension. Signing and provisioning are still required.\n');
