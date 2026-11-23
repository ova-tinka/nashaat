import { router, type Href } from 'expo-router';
import { StyleSheet, View } from 'react-native';
import { Body, Eyebrow, Heading, ModuleTile, Panel, Screen, sharedStyles } from '../../../../components/bloom-ui';
import { moduleManifest } from '../../../../lib/module-manifest';
import { useAuth } from '../../../../lib/auth';

const moduleHighlights: Record<(typeof moduleManifest)[number]['id'], string> = {
  exercise: 'Plans · records · challenges',
  study: 'Plan · practice · tutor',
  read: 'Reading · notes · discovery',
  tasks: 'Projects · Focus · steps',
};

export default function AllAppsScreen() {
  const { childProfile, assignedModules } = useAuth();
  const visibleModules = moduleManifest.filter((module) => !childProfile || (module.available && assignedModules.includes(module.id)));
  return <Screen safeAreaTop={false}>
    <View style={sharedStyles.column}>
      <Eyebrow>Bloom</Eyebrow>
      <Heading>All apps</Heading>
      <Body>Choose a space to explore. Each one brings its plans, tools, and progress together.</Body>
    </View>
    {visibleModules.length > 0 && <View style={styles.grid}>
      {visibleModules.map((module) => <View key={module.id} style={styles.cell}>
        <ModuleTile module={module.id} subtitle={module.available ? moduleHighlights[module.id] : 'Coming later'} disabled={!module.available} onPress={() => { if (module.available && module.route) router.push(module.route as Href); }} />
        {module.available && <Body>Available on {module.supportedPlatforms.map((platform) => platform === 'ios' ? 'iOS' : platform === 'android' ? 'Android' : platform === 'macos' ? 'Mac' : 'Web').join(' · ')}</Body>}
      </View>)}
    </View>}
    {childProfile && visibleModules.length === 0 && <Panel><Eyebrow>Child View</Eyebrow><Body>No modules have been assigned. Ask your guardian to choose which Bloom modules you can use.</Body></Panel>}
    <Panel>
      <Eyebrow>Shared across Bloom</Eyebrow>
      <Body>Progress and screen-time rewards update after Bloom saves an activity. Each device needs its own blocking permission.</Body>
    </Panel>
  </Screen>;
}

const styles = StyleSheet.create({
  grid: { flexDirection: 'row', flexWrap: 'wrap', gap: 12 },
  cell: { width: '48%', minWidth: 126, flexGrow: 1, flexBasis: 132 },
});
