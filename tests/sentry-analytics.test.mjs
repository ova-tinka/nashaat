import assert from 'node:assert/strict';
import test from 'node:test';
import {
  isAnalyticsTrackingAllowed,
  resetAnalytics,
  sanitizeAnalyticsProperties,
  setAnalyticsIdentity,
  trackEvent,
} from '../src/lib/analytics.ts';
import { parseSentryDsn, scrubSensitiveData, scrubString } from '../src/lib/sentry.ts';

test('parseSentryDsn parses valid DSNs and rejects malformed ones', () => {
  const parsed = parseSentryDsn('https://abc123@o12345.ingest.sentry.io/67890');
  assert.deepEqual(parsed, {
    endpoint: 'https://o12345.ingest.sentry.io/api/67890/envelope/',
    publicKey: 'abc123',
    projectId: '67890',
  });
  assert.equal(parseSentryDsn(''), null);
  assert.equal(parseSentryDsn('not-a-url'), null);
  assert.equal(parseSentryDsn('https://abc@sentry.io/not-numeric'), null);
});

test('scrubSensitiveData removes credentials, tokens, prompts, and emails', () => {
  const scrubbed = scrubSensitiveData({
    password: 'secret',
    accessToken: 'tok_123',
    prompt: 'private ai text',
    email: 'user@example.com',
    flow: 'subscription_sync',
    note: 'Contact user@example.com with Bearer secret_abc',
  });
  assert.equal(scrubbed.password, '[REDACTED]');
  assert.equal(scrubbed.accessToken, '[REDACTED]');
  assert.equal(scrubbed.prompt, '[REDACTED]');
  assert.equal(scrubbed.email, '[REDACTED]');
  assert.equal(scrubbed.flow, 'subscription_sync');
  assert.equal(scrubbed.note, 'Contact [REDACTED_EMAIL] with Bearer [REDACTED]');
  assert.equal(scrubString('Bearer xyz123'), 'Bearer [REDACTED]');
});

test('analytics suppresses all events for child accounts and strips disallowed fields', async () => {
  resetAnalytics();
  setAnalyticsIdentity('child-1', { childProfile: true });
  assert.equal(isAnalyticsTrackingAllowed(), false);
  const emitted = await trackEvent('app_opened');
  assert.equal(emitted, false);

  setAnalyticsIdentity('adult-1', { childProfile: false });
  assert.equal(isAnalyticsTrackingAllowed(), true);

  const sanitized = sanitizeAnalyticsProperties({
    pillar: 'study',
    onboarding_step: 'goals',
    // @ts-expect-error runtime guard test
    prompt: 'should be ignored',
  });
  assert.equal(sanitized.pillar, 'study');
  assert.equal(sanitized.onboarding_step, 'goals');
  assert.equal('prompt' in sanitized, false);
  resetAnalytics();
});
