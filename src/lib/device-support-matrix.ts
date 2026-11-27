export type SupportedEnforcementPlatform = 'macos' | 'ios' | 'android' | 'web' | 'windows';

export type PlatformSupportEntry = {
  platform: SupportedEnforcementPlatform;
  label: string;
  appBlocking: 'supported' | 'unsupported';
  websiteBlocking: 'supported' | 'unsupported';
  physicalVerification: 'verified' | 'open_device_verification' | 'not_applicable';
  limitations: string[];
};

/**
 * Single source of truth for Focus/Screen Time enforcement capabilities and
 * open physical-device verification gates. Native enforcement issues remain
 * open until verified on the relevant physical device and signed build.
 */
export const deviceSupportMatrix: Record<SupportedEnforcementPlatform, PlatformSupportEntry> = {
  macos: {
    platform: 'macos',
    label: 'macOS',
    appBlocking: 'supported',
    websiteBlocking: 'supported',
    physicalVerification: 'open_device_verification',
    limitations: [
      'Signed-build acceptance remains open for Brave Private target blocking, Calculator relaunch hiding, and Easy early finish settlement.',
      'Requires Accessibility and System Extension / Login Items approval.',
    ],
  },
  ios: {
    platform: 'ios',
    label: 'iOS',
    appBlocking: 'supported',
    websiteBlocking: 'supported',
    physicalVerification: 'open_device_verification',
    limitations: [
      'Requires Family Controls Screen Time authorization on a signed physical iPhone/iPad.',
      'Countdown expiry, app restart, permission revocation, and reconnect verification remain open on physical device.',
    ],
  },
  android: {
    platform: 'android',
    label: 'Android',
    appBlocking: 'supported',
    websiteBlocking: 'supported',
    physicalVerification: 'open_device_verification',
    limitations: [
      'Requires Accessibility Service permission on Android.',
      'Physical-device verification for countdown expiry, app restart, permission changes, and reconnect remains open (no authorized device connected).',
    ],
  },
  web: {
    platform: 'web',
    label: 'Web',
    appBlocking: 'unsupported',
    websiteBlocking: 'unsupported',
    physicalVerification: 'not_applicable',
    limitations: [
      'No packaged browser extension is shipped; browser blocking is not enforced on standalone web.',
    ],
  },
  windows: {
    platform: 'windows',
    label: 'Windows',
    appBlocking: 'unsupported',
    websiteBlocking: 'unsupported',
    physicalVerification: 'not_applicable',
    limitations: [
      'Windows enforcement is separate feature work and is currently unsupported.',
    ],
  },
};
