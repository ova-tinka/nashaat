import * as Linking from 'expo-linking';
import { supabase } from './supabase';

export type SocialProfile = { display_name: string; searchable: boolean; child_search_opt_in: boolean };
export type Person = { profile_id: string; display_name: string };
export type Friend = Person & { id: string; status: 'pending' | 'accepted' | 'rejected'; incoming: boolean };
export type Competition = { id: string; owner_profile_id: string; title: string; description: string; metric: 'workouts' | 'minutes';
  visibility: 'private' | 'public'; status: 'draft' | 'published' | 'cancelled'; max_participants: number; starts_at: string; ends_at: string };
export type Participation = { competition_id: string; profile_id: string; status: 'pending_parent' | 'approved' | 'rejected'; approved_at: string | null };
export type CompetitionResult = { display_name: string; score: number; placement: number; is_self: boolean; winner: boolean };
export type CompetitionBadge = { competition_id: string; title: string; awarded_at: string };
export type CompetitionDraft = { title: string; description: string; metric: Competition['metric']; visibility: Competition['visibility']; max: number; starts: string; ends: string };

function client() { if (!supabase) throw new Error('Bloom is not configured.'); return supabase; }
export async function loadSocialProfile(profileId: string): Promise<SocialProfile | null> {
  const { data, error } = await client().from('bloom_social_profiles').select('display_name,searchable,child_search_opt_in').eq('profile_id', profileId).maybeSingle();
  if (error) throw error;
  return data as SocialProfile | null;
}
export async function loadCompetitionHome(profileId: string) {
  const db = client();
  const [social, friends, events, participation, invites, badges, admin] = await Promise.all([
    db.from('bloom_social_profiles').select('display_name,searchable,child_search_opt_in').eq('profile_id', profileId).maybeSingle(),
    db.rpc('bloom_list_friends'),
    db.from('bloom_competitions').select('id,owner_profile_id,title,description,metric,visibility,status,max_participants,starts_at,ends_at').order('starts_at'),
    db.from('bloom_competition_participants').select('competition_id,profile_id,status,approved_at').eq('profile_id', profileId),
    db.from('bloom_competition_friend_invites').select('competition_id').eq('invitee_id', profileId).is('accepted_at', null),
    db.rpc('bloom_my_competition_badges'),
    db.rpc('bloom_is_competition_admin'),
  ]);
  for (const result of [social, friends, events, participation, invites, badges, admin]) if (result.error) throw result.error;
  return { social: social.data as SocialProfile | null, friends: (friends.data ?? []) as Friend[], events: (events.data ?? []) as Competition[],
    participation: (participation.data ?? []) as Participation[], invites: (invites.data ?? []) as { competition_id: string }[],
    badges: (badges.data ?? []) as CompetitionBadge[], admin: admin.data === true };
}
export async function saveSocialProfile(name: string, searchable: boolean) {
  const { error } = await client().rpc('bloom_set_social_profile', { p_name: name.trim(), p_searchable: searchable }); if (error) throw error;
}
export async function searchPeople(query: string): Promise<Person[]> {
  const { data, error } = await client().rpc('bloom_search_people', { p_query: query.trim() }); if (error) throw error; return (data ?? []) as Person[];
}
export async function sendFriendRequest(id: string) { const { error } = await client().rpc('bloom_send_friend_request', { p_other: id }); if (error) throw error; }
export async function respondFriend(id: string, accept: boolean) { const { error } = await client().rpc('bloom_respond_friend_request', { p_friendship_id: id, p_accept: accept }); if (error) throw error; }
export async function removeFriend(id: string) { const { error } = await client().rpc('bloom_remove_friend', { p_friendship_id: id }); if (error) throw error; }
export async function saveCompetition(draft: CompetitionDraft, id?: string) {
  const params = { p_title: draft.title.trim(), p_description: draft.description.trim(), p_metric: draft.metric,
    p_max: draft.max, p_starts: draft.starts, p_ends: draft.ends };
  const result = id ? await client().rpc('bloom_update_public_competition_draft', { p_id: id, ...params })
    : await client().rpc('bloom_create_competition', { ...params, p_visibility: draft.visibility });
  if (result.error) throw result.error;
}
export async function publishCompetition(id: string) { const { error } = await client().rpc('bloom_publish_competition', { p_id: id }); if (error) throw error; }
export async function joinPublicCompetition(id: string) { const { error } = await client().rpc('bloom_join_public_competition', { p_id: id }); if (error) throw error; }
export async function inviteFriend(eventId: string, friendId: string) { const { error } = await client().rpc('bloom_invite_competition_friend', { p_id: eventId, p_friend: friendId }); if (error) throw error; }
export async function acceptFriendInvite(eventId: string) { const { error } = await client().rpc('bloom_accept_competition_friend_invite', { p_id: eventId }); if (error) throw error; }
export async function createCompetitionLink(eventId: string): Promise<string> {
  const { data, error } = await client().rpc('bloom_create_competition_link', { p_id: eventId });
  if (error) throw error;
  if (typeof data !== 'string' || !/^[0-9a-f]{64}$/.test(data)) throw new Error('Could not create invitation.');
  return Linking.createURL('/competition-invite', { queryParams: { code: data } });
}
export async function acceptCompetitionLink(code: string): Promise<string> {
  const { data, error } = await client().rpc('bloom_accept_competition_link', { p_token: code.trim().toLowerCase() });
  if (error) throw error;
  if (typeof data !== 'string') throw new Error('Could not join competition.');
  return data;
}
export async function competitionResults(id: string): Promise<CompetitionResult[]> {
  const { data, error } = await client().rpc('bloom_competition_results', { p_id: id }); if (error) throw error; return (data ?? []) as CompetitionResult[];
}
export async function loadChildCompetitions(childId: string) {
  const db = client();
  const [social, requests] = await Promise.all([
    db.from('bloom_social_profiles').select('display_name,searchable,child_search_opt_in').eq('profile_id', childId).maybeSingle(),
    db.from('bloom_competition_participants').select('competition_id,status,competition:bloom_competitions(id,title,metric,visibility,starts_at,ends_at)').eq('profile_id', childId).eq('status', 'pending_parent'),
  ]);
  if (social.error) throw social.error; if (requests.error) throw requests.error;
  return { social: social.data as SocialProfile | null,
    requests: (requests.data ?? []) as unknown as { competition_id: string; status: string; competition: Pick<Competition, 'id' | 'title' | 'metric' | 'visibility' | 'starts_at' | 'ends_at'> | null }[] };
}
export async function setChildSearch(childId: string, enabled: boolean) {
  const { error } = await client().rpc('bloom_set_child_search', { p_child_id: childId, p_enabled: enabled }); if (error) throw error;
}
export async function approveChildCompetition(eventId: string, childId: string, approve: boolean) {
  const { error } = await client().rpc('bloom_approve_competition_child', { p_id: eventId, p_child_id: childId, p_approve: approve }); if (error) throw error;
}
