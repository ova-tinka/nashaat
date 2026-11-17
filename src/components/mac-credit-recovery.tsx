import AsyncStorage from '@react-native-async-storage/async-storage';
import { useEffect, useRef } from 'react';
import { useBloom } from '../lib/bloom-context';
import { isMacDesktop, macCreditMarker, macosFilter, parseMacCreditMarker } from '../lib/macos-blocking';
import { useAuth } from '../lib/auth';

export type MacCreditRecoveryStatus = 'checking' | 'active' | 'blocked' | 'expired' | 'rejected';

function publish(userId: string, status: MacCreditRecoveryStatus) {
  if (typeof window !== 'undefined') {
    window.dispatchEvent(new CustomEvent('bloom-mac-credit-recovery', { detail: { userId, status } }));
  }
}

export function MacCreditRecovery() {
  const { session, profileId } = useAuth();
  const { refresh } = useBloom();
  const inFlight = useRef(false);

  useEffect(() => {
    const userId = profileId;
    const accessToken = session?.access_token;
    if (!userId || !accessToken || !isMacDesktop()) return;
    let mounted = true;

    const recover = async () => {
      if (!mounted || inFlight.current) return;
      inFlight.current = true;
      try {
        const key = macCreditMarker(userId);
        const marker = parseMacCreditMarker(await AsyncStorage.getItem(key), userId);
        if (!marker) return;
        publish(userId, 'checking');
        const result = await macosFilter('startCreditAccess', undefined, {
          requestId: marker.requestId,
          deviceKey: marker.deviceKey,
          minutes: marker.minutes,
          accessToken,
        }, undefined, marker.targets, undefined, userId);
        if (result.status === 'expired') {
          await AsyncStorage.removeItem(key);
          publish(userId, 'expired');
          await refresh();
          return;
        }
        if (result.status === 'rejected') {
          await AsyncStorage.removeItem(key);
          publish(userId, 'rejected');
          return;
        }
        if (result.status !== 'allowed') throw new Error('server lease not confirmed');
        await AsyncStorage.setItem(key, JSON.stringify({ ...marker, state: 'active' }));
        publish(userId, 'active');
      } catch {
        // Keep the owner-bound request so the next foreground or network event
        // can revalidate it. Native protection remains fail-closed meanwhile.
        publish(userId, 'blocked');
      } finally {
        inFlight.current = false;
      }
    };

    const retry = () => { void recover(); };
    void recover();
    window.addEventListener('focus', retry);
    window.addEventListener('online', retry);
    return () => {
      mounted = false;
      window.removeEventListener('focus', retry);
      window.removeEventListener('online', retry);
    };
  }, [session?.access_token, profileId, refresh]);

  return null;
}
