import { randomUUID } from 'expo-crypto';
import { useRef, useState } from 'react';
import { supabase } from './supabase';

export async function usageRequestFailed(requestId: string): Promise<boolean> {
  if (!supabase) return false;
  try {
    const { data, error } = await supabase.rpc('bloom_usage_request_status', { p_request: requestId });
    return !error && data === 'failed';
  } catch {
    return false;
  }
}

export function useUsageRequest() {
  const request = useRef<{ key: string; id: string } | null>(null);
  const [retrying, setRetrying] = useState(false);
  async function run<T>(inputs: readonly string[], perform: (id: string) => Promise<T>): Promise<T> {
    const key = JSON.stringify(inputs);
    if (!request.current || request.current.key !== key) request.current = { key, id: randomUUID() };
    const id = request.current.id;
    try {
      const result = await perform(id);
      if (request.current?.id === id) {
        request.current = null;
        setRetrying(false);
      }
      return result;
    } catch (error) {
      const failed = await usageRequestFailed(id);
      if (request.current?.id === id) {
        if (failed) request.current = null;
        setRetrying(!failed);
      }
      throw error;
    }
  }
  return { run, retrying };
}
