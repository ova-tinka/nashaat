import { Tabs, usePathname } from 'expo-router';
import { Platform, useWindowDimensions } from 'react-native';
import { BloomBottomNavigation } from '../../../components/app-shell';
import { isMacDesktop } from '../../../lib/macos-blocking';

export default function TabLayout() {
  const pathname = usePathname();
  const { width } = useWindowDimensions();
  const desktop = isMacDesktop() || (Platform.OS === 'web' && width >= 1024);
  const immersive = pathname === '/session' || pathname.startsWith('/apps/read/reader/');

  return <Tabs tabBar={desktop || immersive ? () => null : () => <BloomBottomNavigation />} screenOptions={{
    headerShown: false,
    tabBarStyle: { display: 'none' },
  }}>
    <Tabs.Screen name="index" options={{ title: 'Home' }} />
    <Tabs.Screen name="exercise" options={{ title: 'Exercise' }} />
    <Tabs.Screen name="study" options={{ title: 'Study' }} />
    <Tabs.Screen name="read" options={{ title: 'Read' }} />
    <Tabs.Screen name="tasks" options={{ title: 'Tasks' }} />
    <Tabs.Screen name="progress" options={{ href: null }} />
    <Tabs.Screen name="activity" options={{ href: null }} />
    <Tabs.Screen name="devices" options={{ href: null }} />
    <Tabs.Screen name="settings" options={{ href: null }} />
    <Tabs.Screen name="device-detail" options={{ href: null }} />
    <Tabs.Screen name="credit-history" options={{ href: null }} />
    <Tabs.Screen name="workouts" options={{ href: null }} />
    <Tabs.Screen name="library" options={{ href: null }} />
    <Tabs.Screen name="family" options={{ href: null }} />
    <Tabs.Screen name="family-child" options={{ href: null }} />
    <Tabs.Screen name="profile-switch" options={{ href: null }} />
    <Tabs.Screen name="apps/index" options={{ href: null }} />
    <Tabs.Screen name="apps/[module]" options={{ href: null }} />
    <Tabs.Screen name="apps/study/[section]" options={{ tabBarItemStyle: { display: 'none' } }} />
    <Tabs.Screen name="apps/read/[section]" options={{ tabBarItemStyle: { display: 'none' } }} />
    <Tabs.Screen name="apps/tasks/[section]" options={{ tabBarItemStyle: { display: 'none' } }} />
    <Tabs.Screen name="apps/read/reader/[id]" options={{ href: null }} />
  </Tabs>;
}
