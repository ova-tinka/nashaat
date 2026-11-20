import { router, type Href } from 'expo-router';
import MaterialIcons from '@expo/vector-icons/MaterialIcons';
import { ActivityIndicator, StyleSheet, View } from 'react-native';
import { Body, Button, ErrorText, Eyebrow, FeatureTile, Heading, Label, Panel, Screen, sharedStyles } from './bloom-ui';
import { GrowthModuleScreen } from './growth-module-screen';
import { useBloom } from '../lib/bloom-context';
import { useBloomTheme } from '../lib/theme-context';
import { moduleManifest } from '../lib/module-manifest';
import type { ModuleKey } from '../theme';

export function PillarHomeScreen({ moduleId }: { moduleId: ModuleKey }) {
  if (moduleId === 'exercise') return <ExerciseHomeScreen />;
  return <GrowthModuleScreen moduleId={moduleId} />;
}

function ExerciseHomeScreen() {
  const module = moduleManifest.find((item) => item.id === 'exercise')!;
  const { plans, activeWorkout, workoutAnalytics, loading, error, refresh } = useBloom();
  const { theme } = useBloomTheme();
  const colors = theme.modules.exercise;
  const tools = [
    { title: 'Workouts', subtitle: 'Shape a routine that fits your week.', icon: 'fitness-center' as const, route: '/workouts' as Href },
    { title: 'Exercise library', subtitle: 'Choose movements for your next plan.', icon: 'search' as const, route: '/library' as Href },
    { title: 'Progress', subtitle: 'See your completed workouts and progress.', icon: 'insights' as const, route: '/progress' as Href },
    { title: 'Movement coach', subtitle: 'Plan flexibly and refresh your goals.', icon: 'favorite-border' as const, route: '/coach' as Href },
    { title: 'Private challenges', subtitle: 'Set a movement goal with friends.', icon: 'emoji-events' as const, route: '/competitions' as Href },
  ];

  return <Screen safeAreaTop={false}>
    <View style={[styles.hero, { backgroundColor: colors.surface, borderColor: theme.colors.border }]}>
      <View style={styles.heroTop}>
        <View style={[styles.icon, { backgroundColor: theme.colors.surface }]}><MaterialIcons name={module.icon} size={24} color={colors.deep} /></View>
        <View style={sharedStyles.grow}>
          <Eyebrow>Bloom Exercise</Eyebrow>
          <Heading>{module.name}</Heading>
        </View>
        <Button label="Today" variant="tertiary" onPress={() => router.replace('/exercise' as Href)} />
      </View>
      <Body>Make movement part of a routine that fits your day.</Body>
    </View>

    {loading && <ActivityIndicator color={colors.deep} />}
    {error && <Panel>
      <ErrorText>{error}</ErrorText>
      <Body>Your exercise tools stay available while saved activity reconnects.</Body>
      <Button label="Try again" variant="secondary" onPress={() => void refresh()} />
    </Panel>}

    {!loading && !error && <Panel>
      <Eyebrow>Exercise this week</Eyebrow>
      <View style={styles.summary}>
        <View style={styles.metric}><Heading>{workoutAnalytics?.workouts_completed ?? 0}</Heading><Body>completed workouts</Body></View>
        <View style={styles.metric}><Heading>{plans.length}</Heading><Body>workout plans</Body></View>
      </View>
      {activeWorkout && <View style={styles.continueWorkout}>
        <Label>A session is ready to continue.</Label>
        <Button label="Resume workout" onPress={() => router.push({ pathname: '/session', params: { id: activeWorkout.id } })} />
      </View>}
    </Panel>}

    <View style={styles.tools}>
      <View style={styles.toolsHeading}><Eyebrow>Bloom Exercise</Eyebrow><Heading>Your movement</Heading></View>
      <View style={styles.grid}>
        {tools.map((tool) => <View key={tool.title} style={styles.tile}>
          <FeatureTile title={tool.title} subtitle={tool.subtitle} icon={tool.icon} accentColor={colors.deep}
            backgroundColor={colors.surface} onPress={() => router.push(tool.route)} />
        </View>)}
      </View>
    </View>
  </Screen>;
}

const styles = StyleSheet.create({
  hero: { borderWidth: 1, borderRadius: 26, padding: 20, gap: 12 },
  heroTop: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  icon: { width: 48, height: 48, borderRadius: 16, alignItems: 'center', justifyContent: 'center' },
  summary: { flexDirection: 'row', gap: 12 },
  metric: { flex: 1, gap: 3 },
  continueWorkout: { gap: 8, borderTopWidth: StyleSheet.hairlineWidth, borderTopColor: '#DCE6DF', paddingTop: 12 },
  tools: { gap: 12 },
  toolsHeading: { gap: 4 },
  grid: { flexDirection: 'row', flexWrap: 'wrap', gap: 10 },
  tile: { width: '48%', minWidth: 145, flexGrow: 1, flexBasis: 150 },
});
