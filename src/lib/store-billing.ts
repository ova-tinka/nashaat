export type StoreOffer = { id: string; price: string; duration: string };
export type StorePlan = { sku: string; price: string; intro?: StoreOffer; winBack?: StoreOffer };
export const storeBillingAvailable = false;
function unavailable(): never { throw new Error('Store billing is unavailable.'); }
export async function storePlans(_profile: string): Promise<StorePlan[]> { return []; }
export async function storeOffer(_profile: string, _sku: string, _offer: string): Promise<StoreOffer | null> { return null; }
export async function purchaseStorePlan(_profile: string, _sku: string, _offer?: string, _winBack?: boolean) { unavailable(); }
export async function restoreStorePurchases(_profile: string) { unavailable(); }
export async function redeemAppleCode(_profile: string) { unavailable(); }
