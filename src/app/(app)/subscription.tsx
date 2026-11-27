import { useCallback, useEffect, useState } from 'react';
import { router, useLocalSearchParams } from 'expo-router';
import { Linking, Platform } from 'react-native';
import { Body, Button, ErrorText, Field, Heading, Label, Panel, Screen } from '../../components/bloom-ui';
import { useAuth } from '../../lib/auth';
import { billingAccount, money, syncStoreBilling, tapBilling, type BillingCatalog, type BillingFeature, type BillingHistory,
  type BillingProduct, type BillingQuote, type BillingSeatList, type Checkout, type RefundReview } from '../../lib/billing';
import { useBilling } from '../../lib/billing-context';
import { useLocale } from '../../lib/locale-context';
import { isMacDesktop } from '../../lib/macos-blocking';
import { purchaseStorePlan, redeemAppleCode, restoreStorePurchases, storeBillingAvailable, storeOffer,
  storePlans, type StoreOffer, type StorePlan } from '../../lib/store-billing';

const periodLabels = { week: 'Weekly', month: 'Monthly', year: 'Yearly' };
const providers = { app_store: 'App Store', play_store: 'Google Play', tap: 'Bloom website' };
const paymentStates: Record<string, readonly [string, string]> = {
  ready: ['Awaiting payment', 'في انتظار الدفع'],
  pending: ['Processing', 'قيد المعالجة'],
  captured: ['Paid', 'مدفوعة'],
  declined: ['Declined', 'مرفوض'],
  review: ['Under review', 'قيد المراجعة'],
  requested: ['Requested', 'تم تقديم الطلب'],
  approved: ['Approved', 'تمت الموافقة'],
  refunded: ['Refunded', 'تم الاسترداد'],
  failed: ['Failed', 'تعذّر إتمام العملية'],
};
const featureLabels: Record<BillingFeature, readonly [string, string]> = {
  coach_chat: ['Exercise coaching', 'مدرب التمارين'],
  coach_weekly: ['Weekly exercise plan', 'خطة التمارين الأسبوعية'],
  study_tutor: ['Study tutoring', 'مدرّس الدراسة'],
  document_help: ['Document help', 'المساعدة في المستندات'],
  mock_exam_assess: ['Exam assessment', 'تقييم الاختبار'],
  read_reflection: ['Reading reflection', 'تأمل القراءة'],
  task_breakdown: ['Task breakdown', 'تقسيم المهام'],
};

function cleanMinorAmount(value: string) {
  return value.trim().replace(/[٠-٩۰-۹]/g, digit => String(digit.charCodeAt(0) & 0xf));
}

export default function SubscriptionScreen() {
  const { profileId, childProfile } = useAuth();
  const { locale, language } = useLocale();
  const { summary, error: summaryError, refresh } = useBilling();
  const { attempt, tap_id: tapId } = useLocalSearchParams<{ attempt?: string; tap_id?: string }>();
  const provider = Platform.OS === 'ios' ? 'app_store' : Platform.OS === 'android' ? 'play_store' : 'tap';
  const native = provider !== 'tap';
  const browser = provider === 'tap' && !isMacDesktop();
  const [catalog, setCatalog] = useState<BillingCatalog | null>(null);
  const [store, setStore] = useState<StorePlan[]>([]);
  const [history, setHistory] = useState<BillingHistory | null>(null);
  const [seats, setSeats] = useState<BillingSeatList | null>(null);
  const [reviews, setReviews] = useState<RefundReview[] | null>(null);
  const [householdId, setHouseholdId] = useState('');
  const [selected, setSelected] = useState<BillingProduct | null>(null);
  const [webQuote, setWebQuote] = useState<BillingQuote | null>(null);
  const [customOffer, setCustomOffer] = useState<StoreOffer | null>(null);
  const [code, setCode] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [status, setStatus] = useState('');
  const [refundCharge, setRefundCharge] = useState<string | null>(null);
  const [reason, setReason] = useState('');
  const [review, setReview] = useState<RefundReview | null>(null);
  const [reviewAmount, setReviewAmount] = useState('');
  const [reviewNote, setReviewNote] = useState('');
  const [updateCard, setUpdateCard] = useState(false);
  const plan = summary?.plan;
  const product = selected && store.find(entry => entry.sku === selected.store_product);
  const local = (en: string, ar: string) => language === 'ar' ? ar : en;
  const stateLabel = (value: string) => local(...(paymentStates[value] ?? ['Unknown status', 'حالة غير معروفة']));
  const date = (value: string) => new Date(value).toLocaleString(locale, { dateStyle: 'medium', timeStyle: 'short' });
  const number = (value: number) => new Intl.NumberFormat(locale).format(value);
  const label = (item: Pick<BillingProduct, 'tier' | 'scope' | 'period'>) =>
    local(item.tier === 'basic' ? 'Basic' : 'Premium', item.tier === 'basic' ? 'أساسي' : 'مميز') + ' · ' +
    local(item.scope === 'individual' ? 'Individual' : 'Household', item.scope === 'individual' ? 'فردي' : 'عائلي') + ' · ' +
    local(periodLabels[item.period], { week: 'أسبوعي', month: 'شهري', year: 'سنوي' }[item.period]);

  const load = useCallback(async () => {
    if (!profileId || childProfile) return;
    const nextCatalog = await billingAccount<BillingCatalog>('catalog');
    setCatalog(nextCatalog);
    setHouseholdId(current => current || nextCatalog.households[0]?.id || '');
    if (native && storeBillingAvailable) setStore(await storePlans(profileId));
    if (browser) setHistory(await tapBilling<BillingHistory>('history'));
  }, [browser, childProfile, native, profileId]);

  useEffect(() => {
    void Promise.resolve().then(load).catch(() => setError('Billing is temporarily unavailable.'));
  }, [load]);

  useEffect(() => {
    if (!browser || !attempt || childProfile) return;
    let cancelled = false;
    let timer: ReturnType<typeof setTimeout>;
    async function check(tries: number) {
      try {
        const result = await tapBilling<Pick<Checkout, 'state'>>('checkout_status', { id: attempt, tap_id: tapId });
        if (cancelled) return;
        setStatus(result.state);
        if (result.state === 'captured' || result.state === 'declined') {
          await refresh();
          await load();
        } else if (tries < 8) timer = setTimeout(() => void check(tries + 1), 2500);
      } catch {
        if (!cancelled && tries < 8) timer = setTimeout(() => void check(tries + 1), 3000);
      }
    }
    void check(0);
    return () => { cancelled = true; clearTimeout(timer); };
  }, [attempt, browser, childProfile, load, refresh, tapId]);

  async function run(operation: () => Promise<void>) {
    setBusy(true);
    setError('');
    try { await operation(); }
    catch (failure) {
      if (!failure || typeof failure !== 'object' || !('userCancelled' in failure) || !failure.userCancelled) {
        setError(failure instanceof Error ? failure.message : 'Billing is temporarily unavailable.');
      }
    } finally { setBusy(false); }
  }

  function choose(value: BillingProduct) {
    setSelected(value);
    setWebQuote(null);
    setCustomOffer(null);
    setStatus('');
  }

  async function pay(offer?: StoreOffer, winBack?: boolean) {
    if (!selected || !profileId) return;
    if (native) {
      await billingAccount('prepare_mobile', { product_id: selected.id, household_id: householdId || null });
      await purchaseStorePlan(profileId, selected.store_product, offer?.id, winBack);
      setStatus('pending');
      await syncStoreBilling();
      await refresh();
      setStatus('');
    } else if (webQuote) {
      const result = await tapBilling<Checkout>('checkout', {
        product_id: selected.id, household_id: householdId || null, code, accepted: true, ...webQuote,
      });
      await openCheckout(result);
    }
  }

  async function openCheckout(result: Checkout) {
    if (result.checkout_url && result.state === 'pending') {
      await Linking.openURL(result.checkout_url);
    } else {
      router.replace({ pathname: '/subscription', params: { attempt: result.id } });
    }
  }

  async function fetchSeats() {
    if (plan) setSeats(await billingAccount<BillingSeatList>('seats', { subscription_id: plan.subscription_id }));
  }

  function manageStore() {
    if (plan?.provider === 'tap') return;
    return Linking.openURL(plan?.provider === 'app_store'
      ? 'https://apps.apple.com/account/subscriptions' : 'https://play.google.com/store/account/subscriptions');
  }

  const planChoices = (catalog?.products ?? []).filter(entry => entry.provider === provider
    && (!native || store.some(pack => pack.sku === entry.store_product))
    && (entry.scope === 'individual' || Boolean(catalog?.households.length)));
  const minorRefund = cleanMinorAmount(reviewAmount);
  const validRefund = /^\d+$/.test(minorRefund) && Number(minorRefund) > 0
    && Number(minorRefund) <= (review?.refundable_minor ?? 0);
  const mayChoose = catalog?.enabled && !childProfile && (browser || (native && storeBillingAvailable))
    && (!plan || (plan.is_payer && plan.provider === provider));

  return <Screen>
    <Heading>{local('Subscription and usage credits', 'الاشتراك ورصيد الاستخدام')}</Heading>
    <Panel>
      <Label>{plan ? label(plan) : local('Your Bloom plan', 'خطة بلوم الخاصة بك')}</Label>
      {plan && <Body>{plan.provider === 'tap' ? local(providers.tap, 'موقع بلوم') : providers[plan.provider]} · {local(plan.cancel_at_end ? 'Ends' : 'Renews', plan.cancel_at_end ? 'ينتهي' : 'يتجدد')} {date(plan.period_end)}</Body>}
      {plan?.status === 'grace_period' && <Body>{local('Your payment needs attention.', 'تحتاج دفعتك إلى مراجعة.')}</Body>}
      {summary?.metered && <Body>{number(summary.remaining)} / {number(summary.allowance)} {local('weekly usage credits', 'من رصيد الاستخدام الأسبوعي')}</Body>}
      {summary?.next_refill_at && <Body>{local('Next refill', 'التجديد القادم')} · {date(summary.next_refill_at)}</Body>}
      {!plan && summary?.metered && summary.can_access && summary.enforcement_at &&
        <Body>{local('Your transition access ends', 'ينتهي وصولك الانتقالي في')} {date(summary.enforcement_at)}</Body>}
      {childProfile && <Body>{local('Your household payer manages billing.', 'يتولى وليّ الأمر إدارة الفوترة.')}</Body>}
      {summaryError && <ErrorText>{local('Your balance is temporarily unavailable.', 'رصيدك غير متاح مؤقتًا.')}</ErrorText>}
      <Button label={local('Refresh subscription', 'تحديث الاشتراك')} secondary disabled={busy} onPress={() => void run(async () => {
        if (native && storeBillingAvailable && !childProfile) await syncStoreBilling();
        await refresh(); await load();
      })} />
    </Panel>
    {status && <Panel><Body>{status === 'captured' ? local('Payment confirmed.', 'تم تأكيد الدفعة.')
      : status === 'declined' ? local('The payment was not completed.', 'لم تكتمل عملية الدفع.')
      : local('Payment verification in progress.', 'جارٍ التحقق من الدفعة.')}</Body></Panel>}
    {error && <ErrorText>{error}</ErrorText>}

    {plan?.is_payer && !childProfile && <Panel>
      {plan.provider !== 'tap' && <>
        <Button label={local('Manage store subscription', 'إدارة الاشتراك في المتجر')} onPress={() => void run(async () => { await manageStore(); })} />
        <Button label={local('View store purchases', 'عرض مشتريات المتجر')} secondary onPress={() => void run(async () => {
          await Linking.openURL(plan.provider === 'app_store' ? 'https://reportaproblem.apple.com/' : 'https://play.google.com/store/account/orderhistory');
        })} />
        <Button label={local('Request a store refund', 'طلب استرداد من المتجر')} secondary onPress={() => void run(async () => {
          await Linking.openURL(plan.provider === 'app_store' ? 'https://reportaproblem.apple.com/' : 'https://support.google.com/googleplay/answer/15574897');
        })} />
      </>}
      {plan.provider === 'tap' && browser && <>
        <Button label={plan.cancel_at_end ? local('Resume renewal', 'استئناف التجديد') : local('Cancel at period end', 'الإلغاء عند نهاية الفترة')} secondary disabled={busy}
          onPress={() => void run(async () => { await tapBilling(plan.cancel_at_end ? 'resume' : 'cancel', { subscription_id: plan.subscription_id }); await refresh(); })} />
        <Button label={local('Update payment card', 'تحديث بطاقة الدفع')} secondary disabled={busy} onPress={() => setUpdateCard(!updateCard)} />
        {updateCard && <><Body>{local('Tap may place a temporary verification hold. Your new card will be used for future renewals.',
          'قد يضع تاب حجزًا مؤقتًا للتحقق. ستُستخدم بطاقتك الجديدة للتجديدات المقبلة.')}</Body>
        <Button label={local('Confirm card update', 'تأكيد تحديث البطاقة')} disabled={busy}
          onPress={() => void run(async () => openCheckout(await tapBilling<Checkout>('card_update', { subscription_id: plan.subscription_id, accepted: true })))} /></>}
      </>}
      {plan.provider === 'tap' && !browser && <Body>{local('Manage this subscription on the Bloom website.', 'يمكنك إدارة الاشتراك من موقع بلوم.')}</Body>}
      {plan.scope === 'household' && (plan.has_household
        ? <Button label={local('Manage household seats', 'إدارة مقاعد العائلة')} secondary disabled={busy} onPress={() => void run(fetchSeats)} />
        : <><Body>{local('Choose the household for your subscription.', 'اختر العائلة التي سيغطيها اشتراكك.')}</Body>
          {catalog?.households.map(household => <Button key={household.id} label={household.name} secondary disabled={busy}
            onPress={() => void run(async () => {
              await billingAccount('link_household', { subscription_id: plan.subscription_id, household_id: household.id });
              await refresh();
            })} />)}</>)}
    </Panel>}
    {seats && plan?.is_payer && <Panel>
      <Label>{local('Household seats', 'مقاعد العائلة')} · {number(seats.members.filter(item => item.enabled).length)} / {number(seats.seat_limit)}</Label>
      {seats.members.filter(item => item.profile_id !== profileId).map((member, index) =>
        <Button key={member.profile_id} secondary disabled={busy}
          label={member.enabled
            ? `${local('Remove seat', 'إزالة المقعد')} · ${member.name || number(index + 1)}`
            : `${local('Assign seat', 'تعيين المقعد')} · ${member.name || number(index + 1)}`}
          onPress={() => void run(async () => {
            setSeats(await billingAccount<BillingSeatList>('update_seat', {
              subscription_id: plan.subscription_id, profile_id: member.profile_id, enabled: !member.enabled,
            }));
          })} />)}
    </Panel>}
    {mayChoose && <Panel>
      <Label>{local('Choose a plan', 'اختر خطة')}</Label>
      <Body>{local('Every plan includes Exercise, Education, Reading, and Tasks.', 'تشمل كل خطة التمارين والتعليم والقراءة والمهام.')}</Body>
      {planChoices.map(item => {
        const price = store.find(entry => entry.sku === item.store_product)?.price
          ?? (item.price_minor && item.currency ? money(item.price_minor, item.currency, locale) : '');
        return <Button key={item.id} variant={item.id === selected?.id ? 'primary' : 'secondary'} disabled={busy}
          label={`${label(item)} · ${price} · ${number(item.weekly_credits)} ${local('credits weekly', 'رصيد أسبوعيًا')}`}
          onPress={() => choose(item)} />;
      })}
    </Panel>}
    {mayChoose && selected && <Panel>
      <Label>{label(selected)}</Label>
      {selected.scope === 'household' && catalog?.households.map(household =>
        <Button key={household.id} label={household.name} variant={householdId === household.id ? 'primary' : 'secondary'}
          disabled={busy} onPress={() => { setHouseholdId(household.id); setWebQuote(null); }} />)}
      {(browser || provider === 'play_store') && <Field label={local('Offer code', 'رمز العرض')} value={code}
        maxLength={40} autoCapitalize="characters" onChangeText={value => { setCode(value); setWebQuote(null); setCustomOffer(null); }} />}
      {browser ? <>
        <Button label={local('Review payment', 'مراجعة الدفع')} disabled={busy} onPress={() => void run(async () => {
          setWebQuote(await tapBilling<BillingQuote>('quote', { product_id: selected.id, household_id: householdId || null, code }));
        })} />
        {webQuote && <><Body>{local('Due now', 'المستحق الآن')} · {money(webQuote.amount_minor, webQuote.currency, locale)}</Body>
          {webQuote.kind === 'initial' && webQuote.amount_minor < webQuote.recurring_minor &&
            <Body>{local('The discounted price applies to the first billing period.', 'يسري السعر المخفّض خلال فترة الفوترة الأولى.')}</Body>}
          <Body>{local('Automatic renewal', 'التجديد التلقائي')} · {money(webQuote.recurring_minor, webQuote.currency, locale)} · {label(selected)}</Body>
          <Button label={local('Accept recurring terms and continue to Tap', 'قبول شروط التجديد والمتابعة إلى تاب')} disabled={busy}
            onPress={() => void run(() => pay())} /></>}
        {plan?.provider === 'tap' && plan.scope === selected.scope && <Button label={local('Switch at the end of this term', 'التبديل عند نهاية هذه الفترة')}
          secondary disabled={busy} onPress={() => void run(async () => {
            await tapBilling('schedule', { subscription_id: plan.subscription_id, product_id: selected.id }); await load();
          })} />}
      </> : <>
        {product && <Body>{local('Regular renewal price', 'سعر التجديد المعتاد')} · {product.price} · {label(selected)}</Body>}
        {product?.intro && <Body>{local('Eligible introductory offer', 'عرض تمهيدي مؤهل')} · {product.intro.price} · {product.intro.duration}</Body>}
        {provider === 'play_store' && code.trim() && <Button label={local('Check offer', 'التحقق من العرض')} secondary disabled={busy}
          onPress={() => void run(async () => {
            if (!profileId) return;
            const offer = await tapBilling<{ option_id: string }>('play_offer', { product_id: selected.id, code });
            const verified = await storeOffer(profileId, selected.store_product, offer.option_id);
            if (!verified) throw new Error('The selected store offer is unavailable.');
            setCustomOffer(verified);
          })} />}
        {customOffer && <Body>{local('Offer', 'العرض')} · {customOffer.price} · {customOffer.duration}</Body>}
        <Button label={local('Continue to store', 'المتابعة إلى المتجر')} disabled={busy} onPress={() => void run(() => pay(customOffer ?? product?.intro))} />
        {product?.winBack && <Button secondary disabled={busy}
          label={local('Use returning member offer', 'استخدام عرض العودة') + ` · ${product.winBack.price} · ${product.winBack.duration}`}
          onPress={() => void run(() => pay(product.winBack, true))} />}
      </>}
    </Panel>}
    {native && !childProfile && profileId && storeBillingAvailable && <Panel>
      <Button label={local('Restore purchases', 'استعادة المشتريات')} secondary disabled={busy} onPress={() => void run(async () => {
        await restoreStorePurchases(profileId); await syncStoreBilling(); await refresh();
      })} />
      {provider === 'app_store' && catalog?.enabled && (!plan || (plan.is_payer && plan.provider === 'app_store')) &&
        <Button label={local('Redeem an App Store offer code', 'استرداد رمز عرض من متجر التطبيقات')} secondary disabled={busy}
          onPress={() => void run(async () => { await redeemAppleCode(profileId); await syncStoreBilling(); await refresh(); })} />}
    </Panel>}
    {browser && history && <Panel>
      <Label>{local('Payments and refunds', 'المدفوعات والاستردادات')}</Label>
      {history.scheduled && <Body>{local('Your planned change is due', 'موعد تغيير الخطة')} · {date(history.scheduled.period_end)}{
        plan?.status === 'grace_period' ? local(' · Review the scheduled plan to authorize your next payment.', ' · راجع الخطة المجدولة لتفويض دفعتك التالية.') : ''
      }</Body>}
      {history.charges.map(charge => <Panel key={charge.id}>
        <Body>{money(charge.amount_minor, charge.currency, locale)} · {date(charge.created_at)} · {stateLabel(charge.state)}</Body>
        {charge.receipt_url && <Button label={local('Open receipt', 'فتح الإيصال')} secondary onPress={() => void run(async () => { await Linking.openURL(charge.receipt_url!); })} />}
        {charge.state === 'captured' && <Button label={local('Request a refund', 'طلب استرداد')} secondary disabled={busy}
          onPress={() => { setRefundCharge(charge.id); setReason(''); }} />}
        {history.refunds.filter(item => item.charge_id === charge.id).map(item =>
          <Body key={item.id}>{local('Refund', 'الاسترداد')} · {stateLabel(item.state)}
            {item.amount_minor !== null ? ` · ${money(item.amount_minor, charge.currency, locale)}` : ''} {item.review_note}</Body>)}
        {refundCharge === charge.id && <><Field label={local('Refund reason', 'سبب الاسترداد')} value={reason} onChangeText={setReason} maxLength={600} multiline />
          <Button label={local('Send refund request', 'إرسال طلب الاسترداد')} disabled={busy || !reason.trim()} onPress={() => void run(async () => {
            await tapBilling('refund_request', { charge_id: charge.id, reason });
            setRefundCharge(null); await load();
          })} /></>}
      </Panel>)}
      {history.is_staff && <Button label={local('Review refund requests', 'مراجعة طلبات الاسترداد')} secondary disabled={busy}
        onPress={() => void run(async () => setReviews(await tapBilling<RefundReview[]>('refund_queue')))} />}
    </Panel>}
    {reviews && <Panel>
      <Label>{local('Refund review', 'مراجعة الاسترداد')}</Label>
      {reviews.map(item => <Button key={item.id} secondary disabled={busy} label={`${date(item.created_at)} · ${money(item.refundable_minor, item.currency, locale)}`}
        onPress={() => { setReview(item); setReviewAmount(String(item.refundable_minor)); setReviewNote(''); }} />)}
      {review && <>
        <Body>{review.reason}</Body>
        <Field label={local('Amount in minor currency units', 'المبلغ بأصغر وحدة للعملة')} value={reviewAmount} onChangeText={setReviewAmount} keyboardType="number-pad" />
        <Field label={local('Decision reason', 'سبب القرار')} value={reviewNote} onChangeText={setReviewNote} maxLength={600} />
        {(['approved', 'declined'] as const).map(state => <Button key={state} secondary={state === 'declined'} disabled={busy || !reviewNote.trim() || (state === 'approved' && !validRefund)}
          label={state === 'approved' ? local('Approve refund', 'الموافقة على الاسترداد') : local('Decline refund', 'رفض الاسترداد')}
          onPress={() => void run(async () => {
            await tapBilling('refund_decision', { id: review.id, state, note: reviewNote, amount_minor: state === 'approved' ? Number(minorRefund) : null });
            setReview(null); setReviews(await tapBilling<RefundReview[]>('refund_queue'));
          })} />)}
      </>}
    </Panel>}
    {Boolean(summary?.recent_usage.length) && <Panel>
      <Label>{local('Recent usage', 'الاستخدام الأخير')}</Label>
      {summary?.recent_usage.map(item => <Body key={`${item.feature}:${item.created_at}`}>
        {local(...(featureLabels[item.feature] ?? ['Usage', 'استخدام']))} · {number(item.credits)} · {date(item.created_at)}</Body>)}
    </Panel>}
  </Screen>;
}
