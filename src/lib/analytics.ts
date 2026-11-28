function runtimePlatform(): string {
  if (typeof navigator !== 'undefined' && navigator.product === 'ReactNative') {
    const ua = typeof navigator.userAgent === 'string' ? navigator.userAgent : '';
    return /android/i.test(ua) ? 'android' : 'ios';
  }
  if (typeof document !== 'undefined') return 'web';
  return 'node';
}

export type AnalyticsEventName =
  | 'app_opened'
  | 'signup_started'
  | 'signup_completed'
  | 'email_verified'
  | 'onboarding_started'
  | 'onboarding_step_completed'
  | 'onboarding_completed'
  | 'permission_setup_started'
  | 'permission_setup_completed'
  | 'permission_setup_failed'
  | 'first_value_completed'
  | 'paywall_viewed'
  | 'subscription_option_selected'
  | 'purchase_started'
  | 'purchase_completed'
  | 'purchase_failed'
  | 'purchase_cancelled'
  | 'restore_purchase_started'
  | 'restore_purchase_completed'
  | 'entitlement_activated'
  | 'blocking_activated'
  | 'blocking_completed'
  | 'blocking_interrupted'
  | 'activity_started'
  | 'activity_completed'
  | 'credits_earned'
  | 'credits_consumed'
  | 'pillar_opened'
  | 'login_completed'
  | 'logout_completed'
  | 'account_deletion_requested'
  | 'critical_workflow_failed';

export type AnalyticsProperties = {
  pillar?: 'exercise' | 'study' | 'read' | 'tasks';
  blocking_mode?: string;
  onboarding_step?: string;
  product_id?: string;
  error_category?: string;
  source?: string;
};

let currentUserId: string | null = null;
let trackingSuppressedForChild = false;
const emittedOnceKeys = new Set<string>();

export function setAnalyticsIdentity(profileId: string | null, options?: { childProfile?: boolean }) {
  if (options?.childProfile) {
    currentUserId = null;
    trackingSuppressedForChild = true;
    return;
  }
  trackingSuppressedForChild = false;
  currentUserId = profileId;
}

export function resetAnalytics() {
  currentUserId = null;
  trackingSuppressedForChild = false;
  emittedOnceKeys.clear();
}

export function sanitizeAnalyticsProperties(props?: AnalyticsProperties): Record<string, string> {
  const base: Record<string, string> = {
    platform: runtimePlatform(),
    app_version: '0.1.1',
    environment: process.env.EXPO_PUBLIC_APP_ENV?.trim() || (typeof __DEV__ !== 'undefined' && __DEV__ ? 'development' : 'production'),
  };
  if (!props) return base;
  if (props.pillar) base.pillar = props.pillar;
  if (props.blocking_mode) base.blocking_mode = props.blocking_mode.slice(0, 64);
  if (props.onboarding_step) base.onboarding_step = props.onboarding_step.slice(0, 64);
  if (props.product_id) base.product_id = props.product_id.slice(0, 100);
  if (props.error_category) base.error_category = props.error_category.slice(0, 64);
  if (props.source) base.source = props.source.slice(0, 64);
  return base;
}

export function isAnalyticsTrackingAllowed(): boolean {
  return !trackingSuppressedForChild;
}

export async function trackEvent(
  eventType: AnalyticsEventName,
  properties?: AnalyticsProperties,
  options?: { onceKey?: string },
): Promise<boolean> {
  if (trackingSuppressedForChild) return false;
  if (options?.onceKey) {
    if (emittedOnceKeys.has(options.onceKey)) return false;
    emittedOnceKeys.add(options.onceKey);
  }

  const apiKey = process.env.EXPO_PUBLIC_AMPLITUDE_API_KEY?.trim();
  if (!apiKey || typeof fetch !== 'function') return false;

  const endpoint = process.env.EXPO_PUBLIC_AMPLITUDE_ENDPOINT?.trim() || 'https://api2.amplitude.com/2/httpapi';
  const event: Record<string, unknown> = {
    event_type: eventType,
    time: Date.now(),
    platform: runtimePlatform(),
    app_version: '0.1.1',
    event_properties: sanitizeAnalyticsProperties(properties),
  };
  if (currentUserId) {
    event.user_id = currentUserId;
  } else {
    event.device_id = `bloom-${runtimePlatform()}-anon`;
  }

  const controller = typeof AbortController !== 'undefined' ? new AbortController() : null;
  const timeout = controller ? setTimeout(() => controller.abort(), 3500) : null;
  try {
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Accept: '*/*' },
      body: JSON.stringify({ api_key: apiKey, events: [event] }),
      signal: controller?.signal,
    });
    return response.ok;
  } catch {
    return false;
  } finally {
    if (timeout) clearTimeout(timeout);
  }
}
