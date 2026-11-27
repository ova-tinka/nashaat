import { preliminary, reply, type Identity, type SessionTokens } from './child-pairing.ts';

export type UnlockDependencies = {
  authenticate: (token: string) => Promise<string | null>;
  verify: (childId: string, deviceId: string, secret: string, pin: string) => Promise<string | null>;
  eligibleParent: (parentId: string) => Promise<Identity | null>;
  issueSession: (identity: Identity) => Promise<SessionTokens>;
};

export function unlockHandler(_deps?: UnlockDependencies) {
  return async (request: Request): Promise<Response> => {
    const early = preliminary(request);
    if (early) return early;
    return reply(410, { error: 'Parent PIN sign-in has been retired. Sign in with your parent account instead.' });
  };
}
