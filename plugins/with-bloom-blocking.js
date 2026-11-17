const { withAndroidManifest, withDangerousMod, withEntitlementsPlist, withInfoPlist, withXcodeProject } = require('@expo/config-plugins');
const fs = require('fs');
const path = require('path');

const ANDROID_SERVICE = 'expo.modules.bloomblocking.BloomAccessibilityService';
const ANDROID_BLOCKED_ACTIVITY = 'expo.modules.bloomblocking.BloomBlockedActivity';

function withBloomAndroidBlocking(config) {
  return withAndroidManifest(config, (mod) => {
    const manifest = mod.modResults.manifest;
    const queries = manifest.queries ?? (manifest.queries = [{}]);
    const firstQueries = queries[0];
    firstQueries.intent ??= [];
    const hasLauncherQuery = firstQueries.intent.some((entry) =>
      entry.action?.some((item) => item.$?.['android:name'] === 'android.intent.action.MAIN')
      && entry.category?.some((item) => item.$?.['android:name'] === 'android.intent.category.LAUNCHER'));
    if (!hasLauncherQuery) {
      firstQueries.intent.push({
        action: [{ $: { 'android:name': 'android.intent.action.MAIN' } }],
        category: [{ $: { 'android:name': 'android.intent.category.LAUNCHER' } }],
      });
    }

    const application = manifest.application?.[0];
    if (!application) throw new Error('Bloom requires an Android application manifest.');
    application.service ??= [];
    if (!application.service.some((service) => service.$?.['android:name'] === ANDROID_SERVICE)) {
      application.service.push({
        $: {
          'android:name': ANDROID_SERVICE,
          'android:permission': 'android.permission.BIND_ACCESSIBILITY_SERVICE',
          'android:exported': 'true',
          'android:label': 'Bloom app blocking',
        },
        'intent-filter': [{ action: [{ $: { 'android:name': 'android.accessibilityservice.AccessibilityService' } }] }],
        'meta-data': [{
          $: {
            'android:name': 'android.accessibilityservice',
            'android:resource': '@xml/bloom_blocking_accessibility_service',
          },
        }],
      });
    }
    application.activity ??= [];
    if (!application.activity.some((activity) => activity.$?.['android:name'] === ANDROID_BLOCKED_ACTIVITY)) {
      application.activity.push({
        $: {
          'android:name': ANDROID_BLOCKED_ACTIVITY,
          'android:exported': 'false',
          'android:excludeFromRecents': 'true',
        },
      });
    }
    return mod;
  });
}

function withBloomBlocking(config) {
  config = withBloomAndroidBlocking(config);
  const bundleId = config.ios?.bundleIdentifier;
  if (!bundleId) throw new Error('Bloom requires an iOS bundle identifier.');
  const appGroup = 'group.com.focusflow.focusFlowFlutter.shared';
  config = withEntitlementsPlist(config, (mod) => {
    mod.modResults['com.apple.developer.family-controls'] = true;
    mod.modResults['com.apple.developer.family-controls.app-and-website-usage'] = true;
    const groups = mod.modResults['com.apple.security.application-groups'] ?? [];
    mod.modResults['com.apple.security.application-groups'] = [...new Set([...groups, appGroup])];
    return mod;
  });
  config = withInfoPlist(config, (mod) => {
    mod.modResults.BloomAppGroup = appGroup;
    return mod;
  });
  config = withDangerousMod(config, ['ios', async (mod) => {
    const source = path.join(mod.modRequest.projectRoot, 'native', 'ios', 'BloomDeviceActivity');
    const destination = path.join(mod.modRequest.platformProjectRoot, 'BloomDeviceActivity');
    fs.mkdirSync(destination, { recursive: true });
    for (const file of ['BloomDeviceActivityMonitor.swift', 'BloomDeviceActivity-Info.plist', 'BloomDeviceActivity.entitlements']) {
      let contents = fs.readFileSync(path.join(source, file), 'utf8').replaceAll('$(BLOOM_APP_GROUP)', appGroup);
      if (file === 'BloomDeviceActivity-Info.plist') {
        contents = contents.replace(
          '<key>CFBundleShortVersionString</key><string>1.0</string>',
          `<key>CFBundleShortVersionString</key><string>${config.version || '1.0'}</string>`,
        );
      }
      fs.writeFileSync(path.join(destination, file), contents);
    }
    // The monitor and Expo module compile the same locked usage store.
    fs.appendFileSync(path.join(destination, 'BloomDeviceActivityMonitor.swift'), `\n${fs.readFileSync(path.join(mod.modRequest.projectRoot, 'modules', 'bloom-blocking', 'ios', 'BloomUsageState.swift'), 'utf8')}`);

    const safariSource = path.join(mod.modRequest.projectRoot, 'native', 'ios', 'BloomSafariContentBlocker');
    const safariDestination = path.join(mod.modRequest.platformProjectRoot, 'BloomSafariContentBlocker');
    fs.mkdirSync(safariDestination, { recursive: true });
    for (const file of ['BloomSafariContentBlockerRequestHandler.swift', 'BloomSafariContentBlocker-Info.plist', 'BloomSafariContentBlocker.entitlements']) {
      let contents = fs.readFileSync(path.join(safariSource, file), 'utf8').replaceAll('$(BLOOM_APP_GROUP)', appGroup);
      if (file === 'BloomSafariContentBlocker-Info.plist') {
        contents = contents.replace(
          '<key>CFBundleShortVersionString</key><string>1.0</string>',
          `<key>CFBundleShortVersionString</key><string>${config.version || '1.0'}</string>`,
        );
      }
      fs.writeFileSync(path.join(safariDestination, file), contents);
    }
    return mod;
  }]);
  return withXcodeProject(config, (mod) => {
    const project = mod.modResults;
    const targets = project.pbxNativeTargetSection();
    let target = Object.entries(targets).find(([, item]) => item && typeof item === 'object' && String(item.name).replaceAll('"', '') === 'BloomDeviceActivity');
    if (!target) {
      const created = project.addTarget('BloomDeviceActivity', 'app_extension', 'BloomDeviceActivity', `${bundleId}.DeviceActivityMonitorExtension`);
      project.addBuildPhase(['BloomDeviceActivity/BloomDeviceActivityMonitor.swift'], 'PBXSourcesBuildPhase', 'Sources', created.uuid);
      project.addBuildPhase([], 'PBXFrameworksBuildPhase', 'Frameworks', created.uuid);
      project.addBuildPhase([], 'PBXResourcesBuildPhase', 'Resources', created.uuid);
      target = [created.uuid, created.pbxNativeTarget];
    }
    const targetConfigurationList = target[1].buildConfigurationList;
    const list = project.pbxXCConfigurationList()[targetConfigurationList];
    const configurations = project.pbxXCBuildConfigurationSection();
    for (const item of list.buildConfigurations) {
      const settings = configurations[item.value].buildSettings;
      settings.PRODUCT_BUNDLE_IDENTIFIER = `${bundleId}.DeviceActivityMonitorExtension`;
      settings.CODE_SIGN_ENTITLEMENTS = '"BloomDeviceActivity/BloomDeviceActivity.entitlements"';
      if (config.ios?.appleTeamId) settings.DEVELOPMENT_TEAM = config.ios.appleTeamId;
      settings.IPHONEOS_DEPLOYMENT_TARGET = '16.4';
      settings.SWIFT_VERSION = '5.0';
      settings.TARGETED_DEVICE_FAMILY = '"1,2"';
      settings.CLANG_ENABLE_MODULES = 'YES';
      settings.DEFINES_MODULE = 'YES';
    }

    let safariTarget = Object.entries(targets).find(([, item]) => item && typeof item === 'object' && String(item.name).replaceAll('"', '') === 'BloomSafariContentBlocker');
    if (!safariTarget) {
      const created = project.addTarget('BloomSafariContentBlocker', 'app_extension', 'BloomSafariContentBlocker', `${bundleId}.SafariContentBlocker`);
      project.addBuildPhase(['BloomSafariContentBlocker/BloomSafariContentBlockerRequestHandler.swift'], 'PBXSourcesBuildPhase', 'Sources', created.uuid);
      project.addBuildPhase([], 'PBXFrameworksBuildPhase', 'Frameworks', created.uuid);
      project.addBuildPhase([], 'PBXResourcesBuildPhase', 'Resources', created.uuid);
      safariTarget = [created.uuid, created.pbxNativeTarget];
    }
    const safariConfigurationList = project.pbxXCConfigurationList()[safariTarget[1].buildConfigurationList];
    for (const item of safariConfigurationList.buildConfigurations) {
      const settings = configurations[item.value].buildSettings;
      settings.PRODUCT_BUNDLE_IDENTIFIER = `"${bundleId}.SafariContentBlocker"`;
      settings.PRODUCT_NAME = '"BloomSafariContentBlocker"';
      settings.CODE_SIGN_ENTITLEMENTS = '"BloomSafariContentBlocker/BloomSafariContentBlocker.entitlements"';
      settings.INFOPLIST_FILE = '"BloomSafariContentBlocker/BloomSafariContentBlocker-Info.plist"';
      settings.GENERATE_INFOPLIST_FILE = 'NO';
      settings.APPLICATION_EXTENSION_API_ONLY = 'YES';
      if (config.ios?.appleTeamId) settings.DEVELOPMENT_TEAM = config.ios.appleTeamId;
      settings.IPHONEOS_DEPLOYMENT_TARGET = '16.4';
      settings.SWIFT_VERSION = '5.0';
      settings.TARGETED_DEVICE_FAMILY = '"1,2"';
      settings.CLANG_ENABLE_MODULES = 'YES';
      settings.DEFINES_MODULE = 'YES';
      settings.SKIP_INSTALL = 'YES';
    }

    const projectAttributes = project.pbxProjectSection()[project.getFirstProject().uuid].attributes;
    projectAttributes.TargetAttributes ??= {};
    for (const [targetId, nativeTarget] of Object.entries(targets)) {
      if (!nativeTarget || typeof nativeTarget !== 'object') continue;
      const productType = String(nativeTarget.productType).replaceAll('"', '');
      const targetName = String(nativeTarget.name).replaceAll('"', '');
      if (productType !== 'com.apple.product-type.application' && targetName !== 'BloomDeviceActivity' && targetName !== 'BloomSafariContentBlocker') continue;

      if (productType === 'com.apple.product-type.application') {
        const appConfigurationList = project.pbxXCConfigurationList()[nativeTarget.buildConfigurationList];
        for (const appConfiguration of appConfigurationList.buildConfigurations) {
          configurations[appConfiguration.value].buildSettings.ENABLE_USER_SCRIPT_SANDBOXING = 'NO';
        }
      }

      const targetAttributes = projectAttributes.TargetAttributes[targetId] ?? (projectAttributes.TargetAttributes[targetId] = {});
      targetAttributes.ProvisioningStyle = 'Automatic';
      if (config.ios?.appleTeamId) targetAttributes.DevelopmentTeam = config.ios.appleTeamId;
      targetAttributes.SystemCapabilities ??= {};
      targetAttributes.SystemCapabilities['com.apple.ApplicationGroups.iOS'] = { enabled: 1 };
    }
    return mod;
  });
}

module.exports = withBloomBlocking;
