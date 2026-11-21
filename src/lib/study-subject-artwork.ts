import AsyncStorage from '@react-native-async-storage/async-storage';
import { supabase } from './supabase';
import { studySubjectArtworkIds } from './study-subject-artworks';

const legacyStoragePrefix = 'bloom:study-subject-artwork:v1:';
type SubjectArtworkItem = { id: string; artwork_id: string | null };

export async function loadStudySubjectArtworkPreferences(
  profileId: string | null,
  items: SubjectArtworkItem[],
): Promise<Record<string, string>> {
  const preferences = Object.fromEntries(items.flatMap((item) => item.artwork_id ? [[item.id, item.artwork_id]] : []));
  if (!profileId) return preferences;

  const storageKey = legacyStoragePrefix + profileId;
  let stored: string | null;
  try { stored = await AsyncStorage.getItem(storageKey); }
  catch { return preferences; }
  if (!stored) return preferences;

  let parsed: unknown;
  try { parsed = JSON.parse(stored); }
  catch {
    await AsyncStorage.removeItem(storageKey).catch(() => undefined);
    return preferences;
  }
  if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
    await AsyncStorage.removeItem(storageKey).catch(() => undefined);
    return preferences;
  }

  const knownItems = new Set(items.map((item) => item.id));
  const legacy = Object.entries(parsed).filter(([itemId, artworkId]) => knownItems.has(itemId)
    && !preferences[itemId] && typeof artworkId === 'string' && studySubjectArtworkIds.has(artworkId));
  let migrationPending = false;

  for (const [itemId, artworkId] of legacy) {
    preferences[itemId] = artworkId;
    if (!supabase) { migrationPending = true; continue; }
    try {
      const { data, error } = await supabase.rpc('bloom_set_study_subject_artwork', {
        p_item_id: itemId, p_artwork_id: artworkId, p_only_if_unset: true,
      });
      if (error || typeof data !== 'string') { migrationPending = true; continue; }
      preferences[itemId] = data;
    } catch { migrationPending = true; }
  }

  if (!migrationPending) await AsyncStorage.removeItem(storageKey).catch(() => undefined);
  return preferences;
}

export async function saveStudySubjectArtworkPreference(itemId: string, artworkId: string) {
  if (!studySubjectArtworkIds.has(artworkId)) throw new Error('Choose a valid Study subject artwork.');
  if (!supabase) throw new Error('Bloom is not configured.');
  const { data, error } = await supabase.rpc('bloom_set_study_subject_artwork', {
    p_item_id: itemId, p_artwork_id: artworkId, p_only_if_unset: false,
  });
  if (error) throw error;
  if (data !== artworkId) throw new Error('Study subject artwork was not saved.');
}
