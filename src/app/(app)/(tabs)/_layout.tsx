import { Tabs, usePathname } from 'expo-router';
import { useCallback, useMemo, useState } from 'react';
import { Platform, useWindowDimensions } from 'react-native';
import { BloomBottomNavigation } from '../../../components/app-shell';
import { BloomFloatingDockContext } from '../../../components/bloom-ui';
import { isMacDesktop } from '../../../lib/macos-blocking';

export default function TabLayout() {
  const pathname = usePathname();
  const { width } = useWindowDimensions();
  const desktop = isMacDesktop() || (Platform.OS === 'web' && width >= 1024);
  const [dockHeight, setDockHeight] = useState(0);
  const immersive = pathname === '/session' || ['/apps/read/item', '/apps/read/add', '/apps/read/edit', '/apps/read/session', '/apps/read/session-complete'].includes(pathname) || pathname.startsWith('/apps/read/reader/')
    || ['/apps/study/active-session', '/apps/study/session-complete', '/apps/study/learning-check'].includes(pathname);
  const reportDockHeight = useCallback((height: number) => {
    setDockHeight((current) => current === height ? current : height);
  }, []);
  const dockState = useMemo(() => ({ visible: !desktop && !immersive, height: dockHeight, reportHeight: reportDockHeight }),
    [desktop, dockHeight, immersive, reportDockHeight]);

  return <BloomFloatingDockContext.Provider value={dockState}><Tabs tabBar={desktop || immersive ? () => null : () => <BloomBottomNavigation />} screenOptions={{
    headerShown: false,
    tabBarStyle: { backgroundColor: 'transparent', borderTopColor: 'transparent', borderTopWidth: 0, elevation: 0 },
  }}>
    <Tabs.Screen name="index" options={{ title: 'Home' }} />
    <Tabs.Screen name="exercise" options={{ title: 'Exercise' }} />
    <Tabs.Screen name="study" options={{ title: 'Study' }} />
    <Tabs.Screen name="read" options={{ title: 'Read' }} />
    <Tabs.Screen name="tasks" options={{ title: 'Tasks' }} />
    <Tabs.Screen name="progress" options={{ tabBarItemStyle: { display: 'none' } }} />
    <Tabs.Screen name="activity" options={{ tabBarItemStyle: { display: 'none' } }} />
    <Tabs.Screen name="devices" options={{ tabBarItemStyle: { display: 'none' } }} />
    <Tabs.Screen name="settings" options={{ tabBarItemStyle: { display: 'none' } }} />
    <Tabs.Screen name="profile" options={{ tabBarItemStyle: { display: 'none' } }} />
    <Tabs.Screen name="device-detail" options={{ tabBarItemStyle: { display: 'none' } }} />
    <Tabs.Screen name="credit-history" options={{ tabBarItemStyle: { display: 'none' } }} />
    <Tabs.Screen name="workouts" options={{ tabBarItemStyle: { display: 'none' } }} />
    <Tabs.Screen name="library" options={{ tabBarItemStyle: { display: 'none' } }} />
    <Tabs.Screen name="family" options={{ tabBarItemStyle: { display: 'none' } }} />
    <Tabs.Screen name="family-child" options={{ tabBarItemStyle: { display: 'none' } }} />
    <Tabs.Screen name="profile-switch" options={{ tabBarItemStyle: { display: 'none' } }} />
    <Tabs.Screen name="apps/index" options={{ tabBarItemStyle: { display: 'none' } }} />
    <Tabs.Screen name="apps/[module]" options={{ tabBarItemStyle: { display: 'none' } }} />
    <Tabs.Screen name="apps/study/[section]" options={{ tabBarItemStyle: { display: 'none' } }} />
    <Tabs.Screen name="apps/read/[section]" options={{ tabBarItemStyle: { display: 'none' } }} />
    <Tabs.Screen name="apps/tasks/[section]" options={{ tabBarItemStyle: { display: 'none' } }} />
    <Tabs.Screen name="apps/read/reader/[id]" options={{ tabBarItemStyle: { display: 'none' } }} />
  </Tabs></BloomFloatingDockContext.Provider>;
}
