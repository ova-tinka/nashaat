import { Platform } from 'react-native';
import Purchases, { INTRO_ELIGIBILITY_STATUS, STORE_REPLACEMENT_MODE, type PurchasesPackage } from 'react-native-purchases';
import type { StoreOffer, StorePlan } from './store-billing';

const key = Platform.OS === 'ios'
  ? process.env.EXPO_PUBLIC_REVENUECAT_IOS_KEY
  : process.env.EXPO_PUBLIC_REVENUECAT_ANDROID_KEY;
export const storeBillingAvailable = Boolean(key);
let activeProfile: string | undefined;
let queue = Promise.resolve();

function withAccount<T>(profile: string, operation: () => Promise<T>): Promise<T> {
  const result = queue.then(async () => {
    if (!key) throw new Error('Store billing is unavailable.');
    if (!(await Purchases.isConfigured())) {
      Purchases.configure({ apiKey: key, appUserID: profile });
      activeProfile = profile;
    } else if (activeProfile !== profile) {
      await Purchases.logIn(profile);
      activeProfile = profile;
    }
    return operation();
  });
  queue = result.then(() => undefined, () => undefined);
  return result;
}

async function packages() {
  const offerings = await Purchases.getOfferings();
  return Object.values(offerings.all).flatMap(offering => offering.availablePackages);
}

function packageBySku(all: PurchasesPackage[], sku: string) {
  const pack = all.find(item => item.product.identifier === sku);
  if (!pack) throw new Error('The selected store plan is unavailable.');
  return pack;
}

function playOffer(pack: PurchasesPackage, offerId: string): StoreOffer | null {
  const option = pack.product.subscriptionOptions?.find(candidate => candidate.id === offerId
    || candidate.tags.includes(offerId));
  const phase = option?.introPhase;
  if (!option || !phase || option.freePhase || phase.price.amountMicros <= 0) return null;
  return { id: option.id, price: phase.price.formatted, duration: phase.billingPeriod.iso8601 + ' × ' + (phase.billingCycleCount ?? 1) };
}

export async function storePlans(profile: string): Promise<StorePlan[]> {
  return withAccount(profile, async () => {
    const unique = [...new Map((await packages()).map(pack => [pack.product.identifier, pack])).values()];
    const eligibility = Platform.OS === 'ios'
      ? await Purchases.checkTrialOrIntroductoryPriceEligibility(unique.map(pack => pack.product.identifier)) : {};
    return Promise.all(unique.map(async (pack): Promise<StorePlan> => {
      const { identifier, priceString, introPrice, subscriptionOptions } = pack.product;
      const item: StorePlan = { sku: identifier, price: priceString };
      if (Platform.OS === 'android') {
        const intro = subscriptionOptions?.find(option => option.tags.includes('bloom-intro'));
        if (intro) item.intro = playOffer(pack, intro.id) ?? undefined;
      } else {
        if (introPrice && introPrice.price > 0
          && eligibility[identifier]?.status === INTRO_ELIGIBILITY_STATUS.INTRO_ELIGIBILITY_STATUS_ELIGIBLE) {
          item.intro = { id: 'apple-intro', price: introPrice.priceString, duration: introPrice.period + ' × ' + introPrice.cycles };
        }
        const eligible = await Purchases.getEligibleWinBackOffersForPackage(pack).catch(() => undefined);
        const winBack = eligible?.find(offer => offer.price > 0);
        if (winBack) item.winBack = { id: winBack.identifier, price: winBack.priceString, duration: winBack.period + ' × ' + winBack.cycles };
      }
      return item;
    }));
  });
}

export async function storeOffer(profile: string, sku: string, offer: string): Promise<StoreOffer | null> {
  return withAccount(profile, async () => playOffer(packageBySku(await packages(), sku), offer));
}

export async function purchaseStorePlan(profile: string, sku: string, offer?: string, winBack?: boolean): Promise<void> {
  return withAccount(profile, async () => {
    const pack = packageBySku(await packages(), sku);
    if (Platform.OS === 'android') {
      const selected = offer ? playOffer(pack, offer) : null;
      const option = pack.product.subscriptionOptions?.find(candidate =>
        selected ? candidate.id === selected.id : candidate.isBasePlan);
      if (!option || (offer && !selected)) throw new Error('The selected store offer is unavailable.');
      const info = await Purchases.getCustomerInfo();
      const previous = info.activeSubscriptions.find(item => item !== sku);
      const previousProduct = previous?.split(':', 1)[0];
      const changesProduct = previousProduct && previousProduct !== option.productId;
      await Purchases.purchaseSubscriptionOption(option, changesProduct ? {
        oldProductIdentifier: previousProduct,
        replacementMode: STORE_REPLACEMENT_MODE.WITH_TIME_PRORATION,
      } : undefined);
    } else if (winBack && offer) {
      const eligible = await Purchases.getEligibleWinBackOffersForPackage(pack);
      const choice = eligible?.find(item => item.identifier === offer);
      if (!choice) throw new Error('The selected store offer is unavailable.');
      await Purchases.purchasePackageWithWinBackOffer(pack, choice);
    } else {
      await Purchases.purchasePackage(pack);
    }
  });
}

export async function restoreStorePurchases(profile: string) {
  await withAccount(profile, () => Purchases.restorePurchases());
}

export async function redeemAppleCode(profile: string) {
  await withAccount(profile, () => Purchases.presentCodeRedemptionSheet());
}
