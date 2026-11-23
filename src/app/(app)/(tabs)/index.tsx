import { useCallback, useRef, useState } from 'react';
import { useFocusEffect } from 'expo-router';
import { HomeDashboard } from '../../../components/home-dashboard';
import { loadCreditLedger } from '../../../lib/bloom';
import { useAuth } from '../../../lib/auth';
import { loadDevices, type BloomDevice } from '../../../lib/devices';
import { useBloom } from '../../../lib/bloom-context';
import { buildDailyScreenTimeTotals, summarizeWeeklyGoals, type DailyScreenTimeTotal } from '../../../lib/home-dashboard';
import { getAppLocale } from '../../../lib/locale-context';
import { loadGrowthActivity, loadWeeklyPillarActuals, loadWeeklyPillarGoals, type GrowthActivityEvent } from '../../../lib/growth-modules';

type LoadState<T> = { profileId: string | null; data: T | null; loading: boolean; error: string | null };

const initialLoadState: LoadState<never> = { profileId: null, data: null, loading: true, error: null };

export default function HomeScreen() {
  const { creditSettings } = useBloom();
  const { profileId } = useAuth();
  const requestVersion = useRef(0);
  const [weeklyState, setWeeklyState] = useState<LoadState<ReturnType<typeof summarizeWeeklyGoals>>>(initialLoadState);
  const [growthActivityState, setGrowthActivityState] = useState<LoadState<GrowthActivityEvent[]>>(initialLoadState);
  const [creditState, setCreditState] = useState<LoadState<DailyScreenTimeTotal[]>>(initialLoadState);
  const [deviceState, setDeviceState] = useState<LoadState<BloomDevice[]>>(initialLoadState);

  const refresh = useCallback(async () => {
    if (!profileId) return;
    const request = ++requestVersion.current;
    const isCurrent = () => request === requestVersion.current;
    setWeeklyState({ profileId, data: null, loading: true, error: null });
    setGrowthActivityState({ profileId, data: null, loading: true, error: null });
    setCreditState({ profileId, data: null, loading: true, error: null });
    setDeviceState({ profileId, data: null, loading: true, error: null });

    await Promise.all([
      Promise.all([loadWeeklyPillarGoals(), loadWeeklyPillarActuals()]).then(([goals, actuals]) => {
        if (isCurrent()) setWeeklyState({ profileId, data: summarizeWeeklyGoals(goals, actuals), loading: false, error: null });
      }).catch(() => {
        if (isCurrent()) setWeeklyState({ profileId, data: null, loading: false, error: 'Could not load weekly goals. Please try again.' });
      }),
      loadGrowthActivity(profileId).then((events) => {
        if (isCurrent()) setGrowthActivityState({ profileId, data: events, loading: false, error: null });
      }).catch(() => {
        if (isCurrent()) setGrowthActivityState({ profileId, data: null, loading: false, error: 'Could not load today’s pillar activity.' });
      }),
      loadCreditLedger().then((entries) => {
        const timezone = creditSettings?.credit_timezone ?? Intl.DateTimeFormat().resolvedOptions().timeZone;
        const totals = buildDailyScreenTimeTotals(entries, new Date(), timezone, getAppLocale());
        if (isCurrent()) setCreditState({ profileId, data: totals, loading: false, error: null });
      }).catch(() => {
        if (isCurrent()) setCreditState({ profileId, data: null, loading: false, error: 'Could not load recent credit history. Please try again.' });
      }),
      loadDevices().then((devices) => {
        if (isCurrent()) setDeviceState({ profileId, data: devices, loading: false, error: null });
      }).catch(() => {
        if (isCurrent()) setDeviceState({ profileId, data: null, loading: false, error: 'Could not load connected devices. Please try again.' });
      }),
    ]);
  }, [creditSettings?.credit_timezone, profileId]);

  useFocusEffect(useCallback(() => {
    void refresh();
    return () => { requestVersion.current += 1; };
  }, [refresh]));

  const profileWeekly = weeklyState.profileId === profileId ? weeklyState : initialLoadState;
  const profileGrowthActivity = growthActivityState.profileId === profileId ? growthActivityState : initialLoadState;
  const profileCredits = creditState.profileId === profileId ? creditState : initialLoadState;
  const profileDevices = deviceState.profileId === profileId ? deviceState : initialLoadState;

  return <HomeDashboard
    weeklySummary={profileWeekly.data}
    weeklyLoading={profileWeekly.loading}
    weeklyError={profileWeekly.error}
    growthActivity={profileGrowthActivity.data}
    growthActivityLoading={profileGrowthActivity.loading}
    growthActivityError={profileGrowthActivity.error}
    creditHistory={profileCredits.data}
    creditHistoryLoading={profileCredits.loading}
    creditHistoryError={profileCredits.error}
    devices={profileDevices.data}
    devicesLoading={profileDevices.loading}
    devicesError={profileDevices.error}
    onRefresh={() => void refresh()}
  />;
}
