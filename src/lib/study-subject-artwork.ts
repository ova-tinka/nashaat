import AsyncStorage from '@react-native-async-storage/async-storage';

const storagePrefix = 'bloom:study-subject-artwork:v1:';

export async function loadStudySubjectArtworkPreferences(profileId: string | null): Promise<Record<string, string>> {
  if (!profileId) return {};
  const stored = await AsyncStorage.getItem(storagePrefix + profileId);
  if (!stored) return {};
  try {
    const parsed: unknown = JSON.parse(stored);
    if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) return {};
    return Object.fromEntries(Object.entries(parsed).filter(([itemId, artworkId]) => itemId.length > 0 && typeof artworkId === 'string'));
  } catch { return {}; }
}

export async function saveStudySubjectArtworkPreferences(profileId: string, preferences: Record<string, string>) {
  await AsyncStorage.setItem(storagePrefix + profileId, JSON.stringify(preferences));
}
