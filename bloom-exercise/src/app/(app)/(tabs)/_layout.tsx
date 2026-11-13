import MaterialIcons from '@expo/vector-icons/MaterialIcons';
import { Tabs } from 'expo-router';
import { Pressable, StyleSheet, Text, View, useWindowDimensions } from 'react-native';
import { isMacDesktop } from '../../../lib/macos-blocking';
import { colors } from '../../../theme';

const icons = { index: 'home', workouts: 'fitness-center', library: 'menu-book', focus: 'block', settings: 'person-outline' } as const;

export default function TabLayout() {
  const desktop = isMacDesktop();
  const { width } = useWindowDimensions();
  const compact = width < 850;
  return <Tabs
    tabBar={desktop ? ({ state, descriptors, emitter, navigateToTab }) => <View style={[styles.sidebar, compact && styles.compact]}>
      <Text style={styles.brand}>{compact ? 'B' : 'Bloom'}</Text>
      {!compact && <Text style={styles.caption}>YOUR SPACE TO GROW</Text>}
      <View style={styles.navigation}>{state.routes.map((route, index) => {
        const selected = state.index === index;
        const title = descriptors[route.key].options.title ?? route.name;
        const icon = icons[route.name as keyof typeof icons];
        if (!icon) return null;
        return <Pressable key={route.key} accessibilityRole="button" accessibilityLabel={title} accessibilityState={{ selected }} onPress={() => {
          const event = emitter.emit({ type: 'tabPress', target: route.key, canPreventDefault: true });
          if (!selected && !event.defaultPrevented) navigateToTab(route.key);
        }} style={[styles.item, compact && styles.compactItem, selected && styles.selected]}>
          <MaterialIcons name={icon} size={22} color={selected ? colors.accent : colors.muted} />
          {!compact && <Text style={[styles.itemText, selected && styles.selectedText]}>{title}</Text>}
        </Pressable>;
      })}</View>
      {!compact && <Text style={styles.footer}>MOVE  ·  EARN  ·  FOCUS</Text>}
    </View> : undefined}
    screenOptions={{
      headerShown: false,
      tabBarActiveTintColor: colors.accent,
      tabBarInactiveTintColor: colors.muted,
      tabBarStyle: { backgroundColor: colors.background, borderTopColor: colors.border },
      tabBarLabelStyle: { fontWeight: '700' },
      ...(desktop ? { tabBarPosition: 'left' as const } : {}),
    }}>
    <Tabs.Screen name="index" options={{ title: 'Home', tabBarIcon: ({ focused, size }) => <MaterialIcons name="home" color={focused ? colors.accent : colors.muted} size={size} /> }} />
    <Tabs.Screen name="workouts" options={{ title: 'Workouts', tabBarIcon: ({ focused, size }) => <MaterialIcons name="fitness-center" color={focused ? colors.accent : colors.muted} size={size} /> }} />
    <Tabs.Screen name="library" options={{ title: 'Library', tabBarIcon: ({ focused, size }) => <MaterialIcons name="menu-book" color={focused ? colors.accent : colors.muted} size={size} /> }} />
    <Tabs.Screen name="focus" options={{ title: 'Focus', tabBarIcon: ({ focused, size }) => <MaterialIcons name="block" color={focused ? colors.accent : colors.muted} size={size} /> }} />
    <Tabs.Screen name="settings" options={{ title: 'Profile', tabBarIcon: ({ focused, size }) => <MaterialIcons name="person-outline" color={focused ? colors.accent : colors.muted} size={size} /> }} />
  </Tabs>;
}

const styles = StyleSheet.create({
  sidebar: { width: 220, backgroundColor: colors.card, borderRightWidth: 1, borderColor: colors.border, paddingHorizontal: 16, paddingTop: 36, paddingBottom: 24 },
  compact: { width: 72, paddingHorizontal: 8 },
  brand: { color: colors.text, fontSize: 26, fontWeight: '800', letterSpacing: -1, marginHorizontal: 12 },
  caption: { color: colors.muted, fontSize: 10, letterSpacing: 1.4, marginHorizontal: 12, marginTop: 5 },
  navigation: { flex: 1, gap: 5, marginTop: 44 },
  item: { minHeight: 48, flexDirection: 'row', alignItems: 'center', gap: 14, borderRadius: 12, paddingHorizontal: 12 },
  compactItem: { justifyContent: 'center', paddingHorizontal: 0 },
  selected: { backgroundColor: colors.raised },
  itemText: { color: colors.body, fontWeight: '700', fontSize: 15 },
  selectedText: { color: colors.text },
  footer: { color: colors.muted, fontSize: 10, letterSpacing: 1.1, marginHorizontal: 12 },
});
