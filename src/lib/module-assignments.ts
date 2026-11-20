import { supabase } from './supabase';
import type { ModuleKey } from '../theme';

const moduleIds: ModuleKey[] = ['exercise', 'study', 'read', 'tasks'];

export type ChildModuleAssignment = {
  module_id: ModuleKey;
  assigned: boolean;
  updated_by: string | null;
  updated_at: string | null;
};

function client() {
  if (!supabase) throw new Error('Bloom is not configured.');
  return supabase;
}

export function parseModuleIds(data: unknown): ModuleKey[] {
  if (!Array.isArray(data)) throw new Error('Could not read assigned modules.');
  const parsed = data.map((entry) => {
    const module = typeof entry === 'string' ? entry : entry && typeof entry === 'object'
      ? (entry as Record<string, unknown>).module_id
      : null;
    if (typeof module !== 'string' || !moduleIds.includes(module as ModuleKey)) {
      throw new Error('Could not read assigned modules.');
    }
    return module as ModuleKey;
  });
  if (parsed.some((module) => !moduleIds.includes(module))) {
    throw new Error('Could not read assigned modules.');
  }
  return [...new Set(parsed)];
}

function parseAssignments(data: unknown): ChildModuleAssignment[] {
  if (!Array.isArray(data)) throw new Error('Could not read module assignments.');
  return data.map((entry) => {
    if (!entry || typeof entry !== 'object') throw new Error('Invalid module assignment.');
    const row = entry as Record<string, unknown>;
    if (typeof row.module_id !== 'string' || !moduleIds.includes(row.module_id as ModuleKey)
      || typeof row.assigned !== 'boolean'
      || (row.updated_by !== null && typeof row.updated_by !== 'string')
      || (row.updated_at !== null && typeof row.updated_at !== 'string')) throw new Error('Invalid module assignment.');
    return {
      module_id: row.module_id as ModuleKey,
      assigned: row.assigned,
      updated_by: row.updated_by as string | null,
      updated_at: row.updated_at as string | null,
    };
  });
}

export async function loadMyModuleAssignments(): Promise<ModuleKey[]> {
  const { data, error } = await client().rpc('bloom_my_module_assignments');
  if (error) throw error;
  return parseModuleIds(data);
}

export async function loadChildModuleAssignments(childProfileId: string): Promise<ChildModuleAssignment[]> {
  const { data, error } = await client().rpc('bloom_child_module_assignments', { p_child_profile_id: childProfileId });
  if (error) throw error;
  const assignments = parseAssignments(data);
  if (assignments.length !== moduleIds.length || moduleIds.some((id) => !assignments.some((row) => row.module_id === id))) {
    throw new Error('The server returned an incomplete module assignment list.');
  }
  return assignments;
}

export async function saveChildModuleAssignments(childProfileId: string, assignedModules: ModuleKey[]) {
  const uniqueModules = [...new Set(assignedModules)];
  if (uniqueModules.length !== assignedModules.length || uniqueModules.some((id) => !moduleIds.includes(id))) {
    throw new Error('Choose each supported module no more than once.');
  }
  const { data, error } = await client().rpc('bloom_set_child_module_assignments', {
    p_child_profile_id: childProfileId,
    p_module_ids: uniqueModules,
  });
  if (error) throw error;
  return parseAssignments(data);
}
