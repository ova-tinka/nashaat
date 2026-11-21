import MaterialIcons from '@expo/vector-icons/MaterialIcons';
import { router, usePathname, type Href } from 'expo-router';
import { useEffect, useRef, useState, type ComponentProps, type ReactNode } from 'react';
import { AccessibilityInfo, findNodeHandle, I18nManager, Image, Modal, Platform, Pressable, ScrollView, StyleSheet, Text, View, useWindowDimensions, type PressableInstance } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';
import { Body, BloomWordmark, Label } from './bloom-ui';
import { useAuth } from '../lib/auth';
import { useBloom } from '../lib/bloom-context';
import { isMacDesktop } from '../lib/macos-blocking';
import { isFamilySpaceRoute, moduleForPath } from '../lib/route-access';
import { moduleManifest } from '../lib/module-manifest';
import { useBloomTheme } from '../lib/theme-context';
import { useModuleVisibility } from '../lib/module-visibility';
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

  return <View style={[styles.sidebar, { backgroundColor: theme.colors.surface, borderColor: theme.colors.border }, compact && styles.compact]}>
    <ScrollView contentContainerStyle={styles.sidebarScroll}>
      <Text style={[styles.groupLabel, { color: theme.colors.inkSubtle }]}>{compact ? '•' : 'BLOOM'}</Text>
      <View style={styles.navigation}>
        <RailAction title="Home" icon="home" compact={compact} selected={pathname === '/'} onPress={() => router.replace('/' as Href)} />
        {moduleManifest.filter((module) => module.available && visibleModules.includes(module.id)
          && (!childProfile || assignedModules.includes(module.id))).map((module) => (
          <RailAction key={module.id} title={module.name} compactTitle={module.name} icon={module.icon} compact={compact}
            selected={activeModule === module.id} iconColor={activeModule === module.id ? theme.modules[module.id].deep : undefined}
            onPress={() => { if (module.route) router.replace(module.route as Href); }} />
        ))}
      </View>
      <Text style={[styles.groupLabel, styles.modulesLabel, { color: theme.colors.inkSubtle }]}>{compact ? '•' : 'INSIGHTS'}</Text>
      <View style={styles.navigation}>
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
        <RailAction title="Settings" icon="settings" compact={compact} selected={pathname === '/settings' || pathname === '/profile-switch'} onPress={() => router.replace('/settings' as Href)} />
      </View>
    </ScrollView>
    {!compact && <Text style={[styles.footer, { color: theme.colors.inkMuted }]}>{childProfile ? 'CHILD VIEW' : 'MY SPACE'}</Text>}
  </View>;
}

const mobilePrimaryRoutes = [
  { name: 'Home', icon: 'home', href: '/' as const, moduleId: null },
  ...moduleManifest.map((module) => ({ name: module.name, icon: module.icon, href: module.route, moduleId: module.id })),
] as const;

export function BloomBottomNavigation() {
  const { theme } = useBloomTheme();
  const { childProfile, assignedModules } = useAuth();
  const { visibleModules } = useModuleVisibility();
  const pathname = usePathname();
  const insets = useSafeAreaInsets();
  const activeModule = moduleForPath(pathname);
  const items = mobilePrimaryRoutes.filter((item) => item.moduleId === null || (
    moduleManifest.some((module) => module.id === item.moduleId && module.available)
    && visibleModules.includes(item.moduleId)
    && (!childProfile || assignedModules.includes(item.moduleId))
  ));

  return <View pointerEvents="box-none" style={[styles.dockFrame, { paddingBottom: Math.max(insets.bottom + 4, 12) }]}>
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
  const { childProfile, managedChild } = useAuth();
  const { error: bloomError, loading, blockingRulesSyncError } = useBloom();
  const { theme } = useBloomTheme();
  const { width } = useWindowDimensions();
  const insets = useSafeAreaInsets();
  const pathname = usePathname();
  const [open, setOpen] = useState(false);
  const [noticesOpen, setNoticesOpen] = useState(false);
  const spaceTriggerRef = useRef<PressableInstance>(null);
  const noticeTriggerRef = useRef<PressableInstance>(null);
  const [popoverPlacement, setPopoverPlacement] = useState<{ top: number; left: number } | null>(null);
  const [noticePlacement, setNoticePlacement] = useState<{ top: number; left: number } | null>(null);
  const [reduceMotion, setReduceMotion] = useState(false);
  const [spaceFocused, setSpaceFocused] = useState(false);
  const [noticesFocused, setNoticesFocused] = useState(false);
  const wide = width >= 850 && (isMacDesktop() || Platform.OS === 'web');
  const familyRoute = isFamilySpaceRoute(pathname);
  const currentSpace = childProfile ? 'Child View' : familyRoute ? 'Family Space' : 'My Space';
  const notice = blockingRulesSyncError ?? (!loading ? bloomError : null);

  useEffect(() => {
    let active = true;
    void AccessibilityInfo.isReduceMotionEnabled().then((enabled) => { if (active) setReduceMotion(enabled); });
    const subscription = AccessibilityInfo.addEventListener('reduceMotionChanged', setReduceMotion);
    return () => { active = false; subscription.remove(); };
  }, []);

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
    if (replace) router.replace(href);
    else router.push(href);
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
        <BloomWordmark size={32} />
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
          accessibilityLabel={`Current space: ${currentSpace}. Open profile and spaces.`}
          accessibilityHint="Opens your personal, family, and profile settings."
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
              <Label>Choose a space</Label>
              <Body>Personal and family data stay in their own space.</Body>
            </View>
            <Pressable accessibilityRole="button" accessibilityLabel="Close" hitSlop={10} onPress={() => closeSpaceSelector()} style={styles.closeButton}>
              <MaterialIcons name="close" size={22} color={theme.colors.inkMuted} />
            </Pressable>
          </View>
          {childProfile ? <>
            <SpaceOption title="Child View" message="This profile shows the child’s own Bloom activity." icon="person" selected onPress={() => closeSpaceSelector()} />
            {managedChild && <SpaceOption title="Switch to parent" message="A parent PIN is required to restore the parent session on this device." icon="lock-outline" onPress={() => go('/profile-switch' as Href)} />}
          </> : <>
            <SpaceOption title="My Space" message="Your personal activities and progress." icon="person-outline" selected={!familyRoute} onPress={() => familyRoute ? go('/', true) : closeSpaceSelector()} />
            <SpaceOption title="Family Space" message="Set up, join, or manage your family." icon="diversity-3" selected={familyRoute} onPress={() => go('/family' as Href, true)} />
            <SpaceOption title="Progress" message="Review your week and your plan." icon="insights" onPress={() => go('/progress' as Href)} />
            <SpaceOption title="Activity history" message="See completed activity across Bloom." icon="history" onPress={() => go('/activity' as Href)} />
            <SpaceOption title="Connected devices" message="Review each device’s latest report." icon="devices" onPress={() => go('/devices' as Href)} />
            <SpaceOption title="Settings" message="Choose which pillars appear in navigation." icon="settings" onPress={() => go('/settings' as Href)} />
            <Pressable accessibilityRole="button" onPress={() => go('/profile-switch' as Href)} style={styles.profileLink}>
              <Text style={[styles.profileLinkText, { color: theme.colors.action }]}>Profile switching and PIN</Text>
              <MaterialIcons name="arrow-forward" size={17} color={theme.colors.action} style={I18nManager.isRTL ? styles.directionalArrow : undefined} />
            </Pressable>
          </>}
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

function SpaceOption({ title, message, icon, selected = false, onPress }: {
  title: string;
  message: string;
  icon: ComponentProps<typeof MaterialIcons>['name'];
  selected?: boolean;
  onPress: () => void;
}) {
  const { theme } = useBloomTheme();
  const [focused, setFocused] = useState(false);
  return <Pressable
    accessibilityRole="button"
    accessibilityLabel={`${title}. ${message}`}
    accessibilityState={{ selected }}
    onFocus={() => setFocused(true)}
    onBlur={() => setFocused(false)}
    onPress={onPress}
    style={({ pressed }) => [styles.spaceOption, {
      backgroundColor: selected ? theme.colors.surfaceTinted : theme.colors.surface,
      borderColor: focused ? theme.colors.focusRing : selected ? theme.colors.action : theme.colors.border,
      borderWidth: focused ? 2 : 1,
    }, pressed && styles.pressed]}>
    <View style={[styles.optionIcon, { backgroundColor: theme.colors.surfaceSoft }]}>
      <MaterialIcons name={icon} size={20} color={theme.colors.action} />
    </View>
    <View style={styles.optionCopy}>
      <Text style={[styles.optionTitle, { color: theme.colors.ink }]}>{title}</Text>
      <Text style={[styles.optionMessage, { color: theme.colors.inkMuted }]}>{message}</Text>
    </View>
    {selected && <MaterialIcons name="check-circle" size={20} color={theme.colors.action} />}
  </Pressable>;
}

const styles = StyleSheet.create({
  header: {},
  headerInner: { minHeight: 72, width: '100%', maxWidth: 1280, alignSelf: 'center', flexDirection: 'row', alignItems: 'center', gap: 12, paddingHorizontal: 22, paddingVertical: 8 },
  avatarButton: { width: 46, height: 46, overflow: 'hidden', borderRadius: 17 },
  avatarImage: { width: '100%', height: '100%' },
  noticeBadge: { position: 'absolute', top: 7, right: 8, width: 11, height: 11, borderRadius: 6, borderWidth: 2 },
  dockFrame: { position: 'absolute', right: 0, bottom: 0, left: 0, zIndex: 20, alignItems: 'center', paddingTop: 8, paddingHorizontal: 20, backgroundColor: 'transparent' },
  dock: { width: '100%', maxWidth: 560, minHeight: 68, flexDirection: 'row', alignItems: 'center', justifyContent: 'space-around', gap: 4, borderWidth: 1, borderRadius: 999, paddingHorizontal: 8, shadowColor: '#282348', shadowOffset: { width: 0, height: 7 }, shadowOpacity: 0.14, shadowRadius: 24, elevation: 7 },
  dockButton: { minWidth: 44, minHeight: 52, flex: 1, alignItems: 'center', justifyContent: 'center', borderRadius: 999 },
  dockIcon: { width: 43, height: 43, alignItems: 'center', justifyContent: 'center', borderRadius: 22 },
  headerSpacer: { flex: 1 },
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
  profileLink: { minHeight: 44, alignSelf: 'flex-start', flexDirection: 'row', alignItems: 'center', gap: 7, paddingHorizontal: 5 },
  profileLinkText: { fontSize: 13, fontWeight: '700' },
  directionalArrow: { transform: [{ scaleX: -1 }] },
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
  footer: { fontSize: 10, fontWeight: '800', letterSpacing: 1.2, paddingHorizontal: 12, paddingTop: 14 },
});

function RailAction({ title, compactTitle = title, icon, compact, selected, disabled = false, iconColor, onPress, children }: {
  title: string;
  compactTitle?: string;
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
  return <Pressable accessibilityRole="button" accessibilityLabel={title} accessibilityState={{ selected, disabled }} disabled={disabled} onFocus={() => setFocused(true)} onBlur={() => setFocused(false)} onPress={onPress} style={({ pressed }) => [styles.item, compact && styles.compactItem, { borderColor: focused ? theme.colors.focusRing : 'transparent', borderWidth: focused ? 2 : 1 }, selected && { backgroundColor: theme.colors.surfaceTinted }, disabled && styles.disabled, pressed && styles.pressed]}>
    <MaterialIcons name={icon} size={21} color={iconColor ?? (selected ? theme.colors.action : theme.colors.inkMuted)} />
    {compact
      ? <Text style={[styles.compactItemText, { color: selected ? theme.colors.ink : theme.colors.inkMuted }]}>{compactTitle}</Text>
      : children ?? <Text style={[styles.itemText, { color: selected ? theme.colors.ink : theme.colors.inkMuted }]}>{title}</Text>}
  </Pressable>;
}
