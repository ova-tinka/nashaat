import { unlockHandler } from '../_shared/parent-pin.ts';

Deno.serve(unlockHandler());
