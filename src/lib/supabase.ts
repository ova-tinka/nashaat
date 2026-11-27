import 'react-native-url-polyfill/auto';
import { createClient } from '@supabase/supabase-js';
import type { Database } from './database.types';
import { createBloomAuthStorage } from './protected-storage';

export type { Database };

const url = process.env.EXPO_PUBLIC_SUPABASE_URL;
const key = process.env.EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
const authStorage = createBloomAuthStorage();

export const supabase = url && key
  ? createClient(url, key, {
      auth: {
        ...(authStorage ? { storage: authStorage } : {}),
        autoRefreshToken: true,
        persistSession: true,
        detectSessionInUrl: false,
      },
    })
  : null;

export const typedSupabase = supabase as ReturnType<typeof createClient<Database>> | null;

// Account linking must not replace the currently active session before the
// new email account is verified and attached to the existing child profile.
export function createTransientSupabaseClient() {
  if (!url || !key) throw new Error('Bloom is not configured.');
  return createClient(url, key, { auth: { autoRefreshToken: false, persistSession: false, detectSessionInUrl: false } });
}
