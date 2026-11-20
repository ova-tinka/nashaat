import { supabase } from './supabase';

export type GrowthMemoryDomain = 'exercise' | 'study' | 'read' | 'tasks';
export type GrowthMemory = {
  profile_id: string; enabled: boolean; shared_domains: GrowthMemoryDomain[]; summaries: Partial<Record<GrowthMemoryDomain, string>>;
  updated_at: string | null;
};
const emptySummaries: Record<GrowthMemoryDomain, string> = { exercise: '', study: '', read: '', tasks: '' };

function client() {
  if (!supabase) throw new Error('Bloom is not configured.');
  return supabase;
}

export async function loadGrowthMemory(profileId: string): Promise<GrowthMemory> {
  const { data, error } = await client().from('bloom_growth_memory')
    .select('profile_id,enabled,shared_domains,summaries,updated_at').eq('profile_id', profileId).maybeSingle();
  if (error) throw error;
  return data ? { ...data, shared_domains: data.shared_domains as GrowthMemoryDomain[],
    summaries: { ...emptySummaries, ...(data.summaries as Partial<Record<GrowthMemoryDomain, string>>) } }
    : { profile_id: profileId, enabled: false, shared_domains: [], summaries: emptySummaries, updated_at: null };
}

export async function saveGrowthMemory(memory: Pick<GrowthMemory, 'enabled' | 'shared_domains' | 'summaries'>) {
  const { error } = await client().rpc('bloom_save_growth_memory', {
    p_enabled: memory.enabled, p_shared_domains: memory.shared_domains, p_summaries: memory.summaries,
  });
  if (error) throw error;
}

export async function deleteGrowthMemory() {
  const { error } = await client().rpc('bloom_delete_growth_memory');
  if (error) throw error;
}
