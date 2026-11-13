import { pairHandler } from '../_shared/child-pairing.ts';
import { admin, findIdentity, issueSession } from '../_shared/supabase.ts';

Deno.serve(pairHandler({
  async consume(hash) {
    const { data, error } = await admin.rpc('bloom_consume_child_pairing_code', { p_hash: hash });
    return error || typeof data !== 'string' ? null : data;
  },
  findIdentity,
  issueSession,
}));
