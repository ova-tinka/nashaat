import type { ComponentProps } from 'react';
import { router } from 'expo-router';
import { Body, Button } from './bloom-ui';
import { useBilling } from '../lib/billing-context';
import type { BillingFeature } from '../lib/billing';
import { useLocale } from '../lib/locale-context';

export function UsageButton({ feature, onPress, disabled, replay = false, ...props }: ComponentProps<typeof Button> & {
  feature: BillingFeature; replay?: boolean;
}) {
  const { summary, refresh } = useBilling();
  const { language, locale } = useLocale();
  const arabic = language === 'ar';
  const cost = summary?.feature_costs[feature];
  const short = Boolean(summary?.metered && cost && summary.remaining < cost);
  const needsCredits = summary?.can_access === false || short;
  return <>
    {summary?.metered && cost && <Body>
      {new Intl.NumberFormat(locale).format(cost)} {arabic ? 'من رصيد الاستخدام' : 'usage credits'}
    </Body>}
    {needsCredits && <>
      {short && summary?.next_refill_at && <Body>{arabic ? 'التجديد القادم' : 'Next refill'} · {
        new Date(summary.next_refill_at).toLocaleString(locale, { dateStyle: 'medium', timeStyle: 'short' })
      }</Body>}
      <Button label={arabic ? 'عرض الاشتراك ورصيد الاستخدام' : 'View subscription and credits'}
        variant="tertiary" onPress={() => router.push('/subscription')} />
    </>}
    <Button {...props} disabled={disabled || (!replay && needsCredits)} onPress={() => {
      void Promise.resolve(onPress()).finally(refresh);
    }} />
  </>;
}
