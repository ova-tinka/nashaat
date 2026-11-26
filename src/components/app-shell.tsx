import MaterialIcons from '@expo/vector-icons/MaterialIcons';
import { router, useGlobalSearchParams, usePathname, type Href } from 'expo-router';
import { useContext, useEffect, useMemo, useRef, useState, type ComponentProps, type ReactNode } from 'react';
import { AccessibilityInfo, findNodeHandle, I18nManager, Image, Keyboard, Modal, Platform, Pressable, ScrollView, StyleSheet, View, useWindowDimensions, type PressableInstance } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Body, BloomFloatingDockContext, BloomWordmark, Label, LocalizedText as Text, useReduceMotionPreference } from './bloom-ui';
import { useAuth } from '../lib/auth';
import { useBloom } from '../lib/bloom-context';
import { isMacDesktop } from '../lib/macos-blocking';
import { isFamilySpaceRoute, moduleForPath } from '../lib/route-access';
import { moduleManifest } from '../lib/module-manifest';
import { useBloomTheme } from '../lib/theme-context';
import { useModuleVisibility } from '../lib/module-visibility';
import { showNavigationItem } from '../lib/module-visibility-state';
import { bloomHomeImage } from '../assets/bloom-images';

export function BloomDesktopNavigation() {
  const { theme } = useBloomTheme();
  const { childProfile, assignedModules } = useAuth();
  const { visibleModules } = useModuleVisibility();
  const { width } = useWindowDimensions();
  const pathname = usePathname();
  const compact = width < 1100;
  const activeModule = moduleForPath(pathname);
  const familyRoute = isFamilySpaceRoute(pathname);
  const enabledModules = useMemo(() => moduleManifest.filter((module) => module.available && visibleModules.includes(module.id)
    && (!childProfile || assignedModules.includes(module.id))), [assignedModules, childProfile, visibleModules]);

  useEffect(() => {
    if (!isMacDesktop()) return;
    const onKeyDown = (event: KeyboardEvent) => {
      if (!event.metaKey || event.altKey || event.ctrlKey || event.repeat) return;
      const target = event.target;
      if (target instanceof HTMLElement && (target.isContentEditable || target.closest('input, textarea, select, [contenteditable="true"]'))) return;

      const key = event.key.toLowerCase();
      let route: Href | null = null;
      if (key === '1') route = '/' as Href;
      else if (key >= '2' && key <= '5') route = (enabledModules[Number(key) - 2]?.route as Href | undefined) ?? null;
      else if (key === '6') route = '/focus' as Href;
      else if (key === ',') route = '/settings' as Href;
      if (!route) return;

      event.preventDefault();
      router.replace(route);
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [enabledModules]);

  return <View style={[styles.sidebar, { backgroundColor: theme.colors.surface, borderColor: theme.colors.border }, compact && styles.compact]}>
    <ScrollView contentContainerStyle={styles.sidebarScroll}>
      <Text style={[styles.groupLabel, { color: theme.colors.inkSubtle }]}>{compact ? '•' : 'BLOOM'}</Text>
      <View style={styles.navigation}>
        <RailAction title="Home" shortcut="Command+1" icon="home" compact={compact} selected={pathname === '/'} onPress={() => router.replace('/' as Href)} />
        {enabledModules.map((module, index) => (
          <RailAction key={module.id} title={module.name} compactTitle={module.name} shortcut={`Command+${index + 2}`} icon={module.icon} compact={compact}
            selected={activeModule === module.id} iconColor={activeModule === module.id ? theme.modules[module.id].deep : undefined}
            onPress={() => { if (module.route) router.replace(module.route as Href); }} />
        ))}
      </View>
      <Text style={[styles.groupLabel, styles.modulesLabel, { color: theme.colors.inkSubtle }]}>{compact ? '•' : 'INSIGHTS'}</Text>
      <View style={styles.navigation}>
        <RailAction title="Focus & Screen Time" compactTitle="Focus" shortcut="Command+6" icon="timer" compact={compact} selected={pathname === '/focus'} onPress={() => router.replace('/focus' as Href)} />
        <RailAction title="Progress" icon="insights" compact={compact} selected={pathname === '/progress'} onPress={() => router.replace('/progress' as Href)} />
        <RailAction title="Activity" icon="history" compact={compact} selected={pathname === '/activity'} onPress={() => router.replace('/activity' as Href)} />
        <RailAction title="Devices" icon="devices" compact={compact} selected={pathname === '/devices' || pathname === '/device-detail'} onPress={() => router.replace('/devices' as Href)} />
      </View>
      {!childProfile && <>
        <Text style={[styles.groupLabel, styles.modulesLabel, { color: theme.colors.inkSubtle }]}>{compact ? '•' : 'YOUR SPACES'}</Text>
        <View style={styles.navigation}>
          <RailAction title="Family" icon="diversity-3" compact={compact} selected={familyRoute} onPress={() => router.replace('/family' as Href)} />
        </View>
      </>}
      <Text style={[styles.groupLabel, styles.modulesLabel, { color: theme.colors.inkSubtle }]}>{compact ? '•' : 'ACCOUNT'}</Text>
      <View style={styles.navigation}>
        <RailAction title="Settings" shortcut="Command+," icon="settings" compact={compact} selected={pathname === '/settings' || pathname === '/profile-switch'} onPress={() => router.replace('/(app)/(tabs)/settings' as Href)} />
      </View>
    </ScrollView>
    {!compact && <View style={styles.footerArea}>
      <Text style={[styles.footer, { color: theme.colors.inkMuted }]}>{childProfile ? 'CHILD VIEW' : 'MY SPACE'}</Text>
      <Text style={[styles.shortcutFooter, { color: theme.colors.inkSubtle }]}>⌘1 Home · ⌘2–5 Pillars · ⌘6 Focus · ⌘, Settings</Text>
    </View>}
  </View>;
}

type DesktopTab = { id: string; label: string; href: Href };

const desktopPillarTabs: Record<string, DesktopTab[]> = {
  exercise: [
    { id: 'today', label: 'Today', href: '/exercise' as Href },
    { id: 'plans', label: 'Plans', href: { pathname: '/exercise', params: { section: 'plans' } } as Href },
    { id: 'library', label: 'Library', href: '/library' as Href },
    { id: 'progress', label: 'Progress', href: { pathname: '/exercise', params: { section: 'progress' } } as Href },
    { id: 'more', label: 'More', href: { pathname: '/exercise', params: { section: 'more' } } as Href },
  ],
  study: [
    { id: 'today', label: 'Today', href: '/study' as Href },
    { id: 'plan', label: 'Plan', href: { pathname: '/apps/study/[section]', params: { section: 'plan' } } as Href },
    { id: 'courses', label: 'Courses', href: { pathname: '/apps/study/[section]', params: { section: 'courses' } } as Href },
    { id: 'more', label: 'Tools', href: { pathname: '/apps/study/[section]', params: { section: 'more' } } as Href },
    { id: 'progress', label: 'Progress', href: { pathname: '/apps/study/[section]', params: { section: 'progress' } } as Href },
  ],
  read: [
    { id: 'today', label: 'Today', href: '/read' as Href },
    { id: 'library', label: 'Library', href: { pathname: '/apps/read/[section]', params: { section: 'library' } } as Href },
    { id: 'discover', label: 'Discover', href: { pathname: '/apps/read/[section]', params: { section: 'discover' } } as Href },
    { id: 'progress', label: 'Progress', href: { pathname: '/apps/read/[section]', params: { section: 'progress' } } as Href },
  ],
  tasks: [
    { id: 'today', label: 'Today', href: '/tasks' as Href },
    { id: 'projects', label: 'Projects', href: { pathname: '/apps/tasks/[section]', params: { section: 'projects' } } as Href },
    { id: 'focus', label: 'Focus', href: { pathname: '/apps/tasks/[section]', params: { section: 'focus' } } as Href },
    { id: 'breakdown', label: 'Breakdown', href: { pathname: '/apps/tasks/[section]', params: { section: 'breakdown' } } as Href },
  ],
};

const focusTabs: DesktopTab[] = [
  { id: 'focus', label: 'Overview', href: '/focus' as Href },
  { id: 'apps', label: 'Apps', href: { pathname: '/focus', params: { section: 'apps' } } as Href },
  { id: 'websites', label: 'Websites', href: { pathname: '/focus', params: { section: 'websites' } } as Href },
  { id: 'rules', label: 'Rules', href: { pathname: '/focus', params: { section: 'rules' } } as Href },
];

export function BloomDesktopSectionNavigation() {
  const { theme } = useBloomTheme();
  const { width } = useWindowDimensions();
  const pathname = usePathname();
  const params = useGlobalSearchParams<{ section?: string | string[] }>();
  const [focusedTab, setFocusedTab] = useState<string | null>(null);
  const desktop = isMacDesktop() || (Platform.OS === 'web' && width >= 1024);
  const moduleId = moduleForPath(pathname);
  const tabs = pathname === '/focus' ? focusTabs : moduleId ? desktopPillarTabs[moduleId] : null;
  if (!desktop || !tabs) return null;

  const routeSection = Array.isArray(params.section) ? params.section[0] : params.section;
  let selected = routeSection ?? 'today';
  if (pathname === '/focus') selected = routeSection ?? 'focus';
  else if (moduleId === 'exercise') {
    if (pathname === '/library' || pathname.startsWith('/library/')) selected = 'library';
    else if (pathname === '/workouts' || pathname === '/new-plan' || pathname.startsWith('/exercise/')) selected = 'plans';
  } else if (moduleId === 'read' && (pathname.includes('/reader/') || ['/apps/read/item', '/apps/read/add', '/apps/read/edit', '/apps/read/notes'].includes(pathname))) selected = 'library';
  if (!tabs.some((tab) => tab.id === selected)) selected = pathname === '/focus' ? 'focus' : 'today';

  return <View style={[styles.sectionBar, { borderBottomColor: theme.colors.border, backgroundColor: theme.colors.canvas }]}>
    <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.sectionTabs} accessibilityRole="tablist">
      {tabs.map((tab) => {
        const active = selected === tab.id;
        return <Pressable key={tab.id} accessibilityRole="tab" accessibilityLabel={tab.label}
          accessibilityState={{ selected: active }} onFocus={() => setFocusedTab(tab.id)}
          onBlur={() => setFocusedTab((current) => current === tab.id ? null : current)} onPress={() => {
            if (moduleId === 'exercise' && pathname === '/exercise' && tab.id !== 'library') {
              router.setParams({ section: tab.id });
            } else if (pathname === '/focus') {
              router.setParams({ section: tab.id === 'focus' ? undefined : tab.id });
            } else router.replace(tab.href);
          }}
          style={({ pressed }) => [styles.sectionTab, {
            borderBottomColor: active ? theme.colors.action : 'transparent',
            borderTopColor: focusedTab === tab.id ? theme.colors.focusRing : 'transparent',
          }, pressed && styles.pressed]}>
          <Text style={[styles.sectionTabText, { color: active ? theme.colors.ink : theme.colors.inkMuted }]}>{tab.label}</Text>
        </Pressable>;
      })}
    </ScrollView>
  </View>;
}

const mobilePrimaryRoutes = [
  { name: 'Home', icon: 'home', href: '/' as const, moduleId: null },
  ...moduleManifest.map((module) => ({ name: module.name, icon: module.icon, href: module.route, moduleId: module.id })),
] as const;

export function BloomBottomNavigation() {
  const { theme } = useBloomTheme();
  const dock = useContext(BloomFloatingDockContext);
  const { childProfile, assignedModules } = useAuth();
  const { visibleModules } = useModuleVisibility();
  const pathname = usePathname();
  const insets = useSafeAreaInsets();
  const [keyboardVisible, setKeyboardVisible] = useState(false);
  const activeModule = moduleForPath(pathname);
  const items = mobilePrimaryRoutes.filter((item) => showNavigationItem(item.moduleId,
    item.moduleId === null || moduleManifest.some((module) => module.id === item.moduleId && module.available),
    visibleModules, childProfile, assignedModules));

  useEffect(() => {
    const show = Keyboard.addListener('keyboardDidShow', () => setKeyboardVisible(true));
    const hide = Keyboard.addListener('keyboardDidHide', () => setKeyboardVisible(false));
    return () => { show.remove(); hide.remove(); };
  }, []);

  if (keyboardVisible) return null;

  return <View pointerEvents="box-none" onLayout={(event) => dock.reportHeight(Math.ceil(event.nativeEvent.layout.height))} style={[styles.dockFrame, { paddingBottom: Math.max(insets.bottom + 4, 12) }]}>
    <View style={[styles.dock, { backgroundColor: theme.colors.surface, borderColor: theme.colors.border }]} accessibilityRole="tablist">
      {items.map((item) => {
        const selected = item.moduleId === null ? pathname === '/' : item.moduleId === activeModule;
        const color = item.moduleId ? theme.modules[item.moduleId].deep : theme.colors.action;
        return <Pressable key={item.name}
          accessibilityRole="tab"
          accessibilityLabel={`Open ${item.name}`}
          accessibilityHint={item.moduleId ? `Open the ${item.name} pillar.` : 'Return to Bloom Home.'}
          accessibilityState={{ selected }}
          onPress={() => router.replace(item.href as Href)}
          style={({ pressed }) => [styles.dockButton, pressed && styles.pressed]}>
          <View style={[styles.dockIcon, selected && { backgroundColor: theme.colors.surfaceTinted }]}>
            <MaterialIcons name={item.icon} size={25} color={selected ? color : theme.colors.inkMuted} />
          </View>
        </Pressable>;
      })}
    </View>
  </View>;
}

export function BloomAppHeader() {
  const { childProfile } = useAuth();
  const { error: bloomError, loading, blockingRulesSyncError } = useBloom();
  const { theme } = useBloomTheme();
  const { width } = useWindowDimensions();
  const insets = useSafeAreaInsets();
  const pathname = usePathname();
  const desktop = isMacDesktop() || (Platform.OS === 'web' && width >= 1024);
  const reduceMotion = useReduceMotionPreference();
  const [open, setOpen] = useState(false);
  const [noticesOpen, setNoticesOpen] = useState(false);
  const spaceTriggerRef = useRef<PressableInstance>(null);
  const noticeTriggerRef = useRef<PressableInstance>(null);
  const [popoverPlacement, setPopoverPlacement] = useState<{ top: number; left: number } | null>(null);
  const [noticePlacement, setNoticePlacement] = useState<{ top: number; left: number } | null>(null);
  const [spaceFocused, setSpaceFocused] = useState(false);
  const [noticesFocused, setNoticesFocused] = useState(false);
  const wide = width >= 850 && (isMacDesktop() || Platform.OS === 'web');
  const familyRoute = isFamilySpaceRoute(pathname);
  const currentSpace = childProfile ? 'Child profile' : familyRoute ? 'Family Space' : 'My profile';
  const notice = blockingRulesSyncError ?? (!loading ? bloomError : null);

  function closeSpaceSelector(restoreFocus = true) {
    setOpen(false);
    if (!restoreFocus) return;
    requestAnimationFrame(() => {
      const trigger = spaceTriggerRef.current;
      if (!trigger) return;
      if (Platform.OS === 'web') trigger.focus();
      else {
        const reactTag = findNodeHandle(trigger);
        if (reactTag != null) AccessibilityInfo.setAccessibilityFocus(reactTag);
      }
    });
  }

  function go(href: Href, replace = false) {
    closeSpaceSelector(false);
    requestAnimationFrame(() => {
      if (replace) router.replace(href);
      else router.push(href);
    });
  }

  function openSpaceSelector() {
    setOpen(true);
    setPopoverPlacement(null);
    if (!wide) return;
    requestAnimationFrame(() => {
      spaceTriggerRef.current?.measureInWindow((x, y, triggerWidth, triggerHeight) => {
        const popoverWidth = Math.min(380, width - 32);
        const anchorLeft = I18nManager.isRTL ? x + triggerWidth - popoverWidth : x;
        const left = Math.max(16, Math.min(anchorLeft, width - popoverWidth - 16));
        setPopoverPlacement({ top: y + triggerHeight + 8, left });
      });
    });
  }

  function openNotices() {
    setNoticesOpen(true);
    setNoticePlacement(null);
    if (!wide) return;
    requestAnimationFrame(() => {
      noticeTriggerRef.current?.measureInWindow((x, y, triggerWidth, triggerHeight) => {
        const popoverWidth = Math.min(380, width - 32);
        const anchorLeft = I18nManager.isRTL ? x + triggerWidth - popoverWidth : x;
        const left = Math.max(16, Math.min(anchorLeft, width - popoverWidth - 16));
        setNoticePlacement({ top: y + triggerHeight + 8, left });
      });
    });
  }

  return <>
    <View style={[styles.header, { paddingTop: Platform.OS === 'web' ? 0 : insets.top, backgroundColor: theme.colors.canvas }]}>
      <View style={styles.headerInner}>
        <View style={styles.brandBlock}>
          <BloomWordmark size={32} />
          {!desktop && moduleForPath(pathname) === 'exercise' && <Text style={[styles.brandSubtitle, { color: theme.modules.exercise.deep }]}>Exercise</Text>}
        </View>
        {desktop && <View style={styles.pageTitleWrap}>
          <Text accessibilityRole="header" numberOfLines={1} style={[styles.pageTitle, { color: theme.colors.ink }]}>{desktopPageTitle(pathname)}</Text>
        </View>}
        <View style={styles.headerSpacer} />
        <Pressable
          ref={noticeTriggerRef}
          accessibilityRole="button"
          accessibilityLabel={notice ? `Notifications, one notice. ${notice}` : 'Notifications'}
          accessibilityState={{ expanded: noticesOpen }}
          onFocus={() => setNoticesFocused(true)}
          onBlur={() => setNoticesFocused(false)}
          onPress={openNotices}
          style={({ pressed }) => [styles.iconButton, { borderColor: noticesFocused ? theme.colors.focusRing : 'transparent', borderWidth: noticesFocused ? 2 : 1 }, pressed && styles.pressed]}>
          <MaterialIcons name="notifications-none" size={25} color={theme.colors.ink} />
          {notice && <View style={[styles.noticeBadge, { backgroundColor: theme.modules.tasks.deep, borderColor: theme.colors.canvas }]} />}
        </Pressable>
        <Pressable
          accessibilityRole="button"
          ref={spaceTriggerRef}
          accessibilityLabel={`Current profile: ${currentSpace}. Open profile menu.`}
          accessibilityHint="Opens My profile, Family Space, and Settings."
          accessibilityState={{ expanded: open }}
          onFocus={() => setSpaceFocused(true)}
          onBlur={() => setSpaceFocused(false)}
          onPress={openSpaceSelector}
          style={({ pressed }) => [styles.avatarButton, { borderColor: spaceFocused ? theme.colors.focusRing : 'transparent', borderWidth: spaceFocused ? 2 : 1 }, pressed && styles.pressed]}>
          <Image source={bloomHomeImage} resizeMode="cover" accessible={false} style={styles.avatarImage} />
        </Pressable>
      </View>
    </View>
    <Modal visible={open} transparent animationType={reduceMotion ? 'none' : 'fade'} onRequestClose={() => closeSpaceSelector()} statusBarTranslucent>
      <View style={[styles.modalFrame, wide ? styles.desktopFrame : styles.mobileFrame]}>
        <Pressable accessibilityRole="button" accessibilityLabel="Close space selector" style={StyleSheet.absoluteFill} onPress={() => closeSpaceSelector()} />
        <View style={[styles.sheet, wide && styles.popover, wide && (popoverPlacement ? { position: 'absolute', top: popoverPlacement.top, left: popoverPlacement.left } : styles.popoverFallback), { backgroundColor: theme.colors.surface, borderColor: theme.colors.border }]}>
          <View style={styles.sheetHeading}>
            <View style={styles.sheetTitle}>
              <Label>Profile</Label>
            </View>
            <Pressable accessibilityRole="button" accessibilityLabel="Close" hitSlop={10} onPress={() => closeSpaceSelector()} style={styles.closeButton}>
              <MaterialIcons name="close" size={22} color={theme.colors.inkMuted} />
            </Pressable>
          </View>
          <SpaceOption title="My profile" icon="person-outline" selected={pathname === '/profile'} onPress={() => go('/profile' as Href, true)} />
          <SpaceOption title="Family Space" message={childProfile ? 'Available in parent profile' : undefined} icon="diversity-3" selected={familyRoute} disabled={childProfile} onPress={() => go('/family' as Href, true)} />
          <SpaceOption title="Settings" icon="settings" selected={pathname === '/settings'} onPress={() => go('/(app)/(tabs)/settings' as Href, true)} />
        </View>
      </View>
    </Modal>
    <Modal visible={noticesOpen} transparent animationType={reduceMotion ? 'none' : 'fade'} onRequestClose={() => setNoticesOpen(false)} statusBarTranslucent>
      <View style={[styles.modalFrame, wide ? styles.desktopFrame : styles.mobileFrame]}>
        <Pressable accessibilityRole="button" accessibilityLabel="Close notifications" style={StyleSheet.absoluteFill} onPress={() => setNoticesOpen(false)} />
        <View style={[styles.sheet, wide && styles.popover, wide && (noticePlacement ? { position: 'absolute', top: noticePlacement.top, left: noticePlacement.left } : styles.popoverFallback), { backgroundColor: theme.colors.surface, borderColor: theme.colors.border }]}>
          <View style={styles.sheetHeading}>
            <View style={styles.sheetTitle}>
              <Label>Notifications</Label>
              <Body>{notice ? 'Bloom needs a quick check.' : 'You’re all caught up.'}</Body>
            </View>
            <Pressable accessibilityRole="button" accessibilityLabel="Close" hitSlop={10} onPress={() => setNoticesOpen(false)} style={styles.closeButton}>
              <MaterialIcons name="close" size={22} color={theme.colors.inkMuted} />
            </Pressable>
          </View>
          {notice
            ? <SpaceOption title="Check your devices" message={notice} icon="devices" onPress={() => { setNoticesOpen(false); router.push('/devices' as Href); }} />
            : <SpaceOption title="No new notices" message="Device and account updates will appear here." icon="notifications-none" onPress={() => setNoticesOpen(false)} />}
          <SpaceOption title="Screen-time history" message="Review the balance confirmed for your profile." icon="schedule" onPress={() => { setNoticesOpen(false); router.push('/credit-history' as Href); }} />
        </View>
      </View>
    </Modal>
  </>;
}

function desktopPageTitle(pathname: string) {
  if (pathname === '/' || pathname === '/index') return 'Home';
  if (pathname === '/focus') return 'Focus & Screen Time';
  if (pathname === '/progress') return 'Progress';
  if (pathname === '/activity') return 'Activity';
  if (pathname === '/devices' || pathname === '/device-detail') return 'Devices';
  if (pathname === '/family' || pathname.startsWith('/family/')) return 'Family';
  if (pathname === '/settings') return 'Settings';
  if (pathname === '/profile' || pathname === '/profile-switch') return 'Profile';
  if (pathname === '/library') return 'Exercise Library';
  if (pathname === '/workouts') return 'Workout History';
  if (pathname === '/new-plan') return 'Workout Plan';
  if (pathname.startsWith('/apps/read/reader/')) return 'Reader';
  if (pathname === '/credit-history') return 'Credit History';
  const moduleId = moduleForPath(pathname);
  if (moduleId) return moduleManifest.find((module) => module.id === moduleId)?.name ?? 'Bloom';
  const lastSegment = pathname.split('/').filter(Boolean).at(-1);
  return lastSegment ? lastSegment.replace(/[-_]/g, ' ').replace(/\b\w/g, (letter) => letter.toUpperCase()) : 'Bloom';
}

function SpaceOption({ title, message, icon, selected = false, disabled = false, onPress }: {
  title: string;
  message?: string;
  icon: ComponentProps<typeof MaterialIcons>['name'];
  selected?: boolean;
  disabled?: boolean;
  onPress: () => void;
}) {
  const { theme } = useBloomTheme();
  const [focused, setFocused] = useState(false);
  return <Pressable
    accessibilityRole="button"
    accessibilityLabel={message ? `${title}. ${message}` : title}
    accessibilityState={{ selected, disabled }}
    disabled={disabled}
    onFocus={() => setFocused(true)}
    onBlur={() => setFocused(false)}
    onPress={onPress}
    style={({ pressed }) => [styles.spaceOption, {
      backgroundColor: selected ? theme.colors.surfaceTinted : theme.colors.surface,
      borderColor: focused ? theme.colors.focusRing : selected ? theme.colors.action : theme.colors.border,
      borderWidth: focused ? 2 : 1,
    }, disabled && styles.disabledOption, pressed && styles.pressed]}>
    <View style={[styles.optionIcon, { backgroundColor: theme.colors.surfaceSoft }]}>
      <MaterialIcons name={icon} size={20} color={theme.colors.action} />
    </View>
    <View style={styles.optionCopy}>
      <Text style={[styles.optionTitle, { color: theme.colors.ink }]}>{title}</Text>
      {message && <Text style={[styles.optionMessage, { color: theme.colors.inkMuted }]}>{message}</Text>}
    </View>
    {selected && <MaterialIcons name="check-circle" size={20} color={theme.colors.action} />}
  </Pressable>;
}

const styles = StyleSheet.create({
  header: {},
  headerInner: { minHeight: 72, width: '100%', maxWidth: 1280, alignSelf: 'center', flexDirection: 'row', alignItems: 'center', gap: 12, paddingHorizontal: 22, paddingVertical: 8 },
  brandBlock: { alignItems: 'flex-start', justifyContent: 'center' },
  pageTitleWrap: { minWidth: 0, paddingStart: 20, borderStartWidth: StyleSheet.hairlineWidth, borderStartColor: '#D9E0EC' },
  pageTitle: { maxWidth: 360, fontSize: 18, lineHeight: 24, fontWeight: '700', letterSpacing: -0.25 },
  brandSubtitle: { marginStart: 40, marginTop: -1, fontSize: 12, lineHeight: 15, fontWeight: '700', letterSpacing: 0.2 },
  avatarButton: { width: 46, height: 46, overflow: 'hidden', borderRadius: 17 },
  avatarImage: { width: '100%', height: '100%' },
  noticeBadge: { position: 'absolute', top: 7, right: 8, width: 11, height: 11, borderRadius: 6, borderWidth: 2 },
  dockFrame: { position: 'absolute', right: 0, bottom: 0, left: 0, zIndex: 20, alignItems: 'center', paddingTop: 8, paddingHorizontal: 20, backgroundColor: 'transparent' },
  dock: { width: '100%', maxWidth: 560, minHeight: 68, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-around', gap: 4, borderWidth: 1, borderRadius: 999, paddingHorizontal: 8, shadowColor: '#282348', shadowOffset: { width: 0, height: 7 }, shadowOpacity: 0.14, shadowRadius: 24, elevation: 7 },
  dockButton: { minWidth: 44, minHeight: 52, flex: 1, alignItems: 'center', justifyContent: 'center', borderRadius: 999 },
  dockIcon: { width: 43, height: 43, alignItems: 'center', justifyContent: 'center', borderRadius: 22 },
  headerSpacer: { flex: 1 },
  sectionBar: { borderBottomWidth: StyleSheet.hairlineWidth },
  sectionTabs: { width: '100%', maxWidth: 1200, alignSelf: 'center', flexDirection: 'row', gap: 28, paddingHorizontal: 40 },
  sectionTab: { minHeight: 48, justifyContent: 'center', borderBottomWidth: 2, borderTopWidth: 2, paddingHorizontal: 2 },
  sectionTabText: { fontSize: 14, lineHeight: 20, fontWeight: '600' },
  iconButton: { width: 44, height: 44, borderWidth: 1, borderRadius: 14, alignItems: 'center', justifyContent: 'center' },
  pressed: { opacity: 0.76 },
  modalFrame: { flex: 1, backgroundColor: 'rgba(16,21,43,0.28)' },
  mobileFrame: { justifyContent: 'flex-end' },
  desktopFrame: { justifyContent: 'flex-start' },
  sheet: { width: '100%', borderTopLeftRadius: 26, borderTopRightRadius: 26, borderWidth: 1, padding: 20, paddingBottom: 28, gap: 12 },
  popover: { width: 380, borderRadius: 22, padding: 18, shadowColor: '#10152B', shadowOffset: { width: 0, height: 12 }, shadowOpacity: 0.14, shadowRadius: 28, elevation: 8 },
  popoverFallback: { alignSelf: 'flex-end', marginTop: 68, marginEnd: 22 },
  sheetHeading: { flexDirection: 'row', alignItems: 'flex-start', gap: 12, paddingBottom: 4 },
  sheetTitle: { flex: 1, gap: 5 },
  closeButton: { width: 36, height: 36, alignItems: 'center', justifyContent: 'center' },
  spaceOption: { minHeight: 68, flexDirection: 'row', alignItems: 'center', gap: 12, borderWidth: 1, borderRadius: 16, padding: 12 },
  optionIcon: { width: 40, height: 40, alignItems: 'center', justifyContent: 'center', borderRadius: 13 },
  optionCopy: { flex: 1, gap: 2 },
  optionTitle: { fontSize: 15, lineHeight: 20, fontWeight: '700' },
  optionMessage: { fontSize: 12, lineHeight: 17 },
  disabledOption: { opacity: 0.6 },
  sidebar: { width: 244, borderEndWidth: 1, paddingHorizontal: 14, paddingTop: 22, paddingBottom: 18 },
  compact: { width: 88, paddingHorizontal: 8 },
  sidebarScroll: { paddingTop: 8, paddingBottom: 16 },
  groupLabel: { fontSize: 10, fontWeight: '800', letterSpacing: 1.1, paddingHorizontal: 12, marginBottom: 9 },
  modulesLabel: { marginTop: 24 },
  navigation: { gap: 4 },
  item: { minHeight: 46, flexDirection: 'row', alignItems: 'center', gap: 12, borderRadius: 13, borderWidth: 1, paddingHorizontal: 12 },
  compactItem: { minHeight: 58, flexDirection: 'column', justifyContent: 'center', gap: 3, paddingHorizontal: 4, paddingVertical: 5 },
  itemText: { fontWeight: '700', fontSize: 14 },
  compactItemText: { width: '100%', fontSize: 12, fontWeight: '700', textAlign: 'center' },
  moduleRowText: { flex: 1, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 6 },
  comingLater: { fontSize: 9, fontWeight: '700' },
  disabled: { opacity: 0.56 },
  footerArea: { paddingTop: 8, gap: 4 },
  footer: { fontSize: 10, fontWeight: '800', letterSpacing: 1.2, paddingHorizontal: 12, paddingTop: 14 },
  shortcutFooter: { fontSize: 9, lineHeight: 13, paddingHorizontal: 12 },
});

function RailAction({ title, compactTitle = title, shortcut, icon, compact, selected, disabled = false, iconColor, onPress, children }: {
  title: string;
  compactTitle?: string;
  shortcut?: string;
  icon: ComponentProps<typeof MaterialIcons>['name'];
  compact: boolean;
  selected: boolean;
  disabled?: boolean;
  iconColor?: string;
  onPress: () => void;
  children?: ReactNode;
}) {
  const { theme } = useBloomTheme();
  const [focused, setFocused] = useState(false);
  return <Pressable accessibilityRole="button" accessibilityLabel={title} accessibilityHint={shortcut ? `Keyboard shortcut ${shortcut}.` : undefined} accessibilityState={{ selected, disabled }} disabled={disabled} onFocus={() => setFocused(true)} onBlur={() => setFocused(false)} onPress={onPress} style={({ pressed }) => [styles.item, compact && styles.compactItem, { borderColor: focused ? theme.colors.focusRing : 'transparent', borderWidth: focused ? 2 : 1 }, selected && { backgroundColor: theme.colors.surfaceTinted }, disabled && styles.disabled, pressed && styles.pressed]}>
    <MaterialIcons name={icon} size={21} color={iconColor ?? (selected ? theme.colors.action : theme.colors.inkMuted)} />
    {compact
      ? <Text style={[styles.compactItemText, { color: selected ? theme.colors.ink : theme.colors.inkMuted }]}>{compactTitle}</Text>
      : children ?? <Text style={[styles.itemText, { color: selected ? theme.colors.ink : theme.colors.inkMuted }]}>{title}</Text>}
  </Pressable>;
}
