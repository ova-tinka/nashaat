import { router, useLocalSearchParams, type Href } from 'expo-router';
import { Body, Button, Eyebrow, Heading, Panel, Screen } from '../../../../components/bloom-ui';
import { moduleManifest } from '../../../../lib/module-manifest';
import { PillarHomeScreen } from '../../../../components/pillar-home-screen';

export default function ModuleLandingScreen() {
  const { module: moduleParam } = useLocalSearchParams<{ module?: string }>();
  const module = moduleManifest.find((item) => item.id === moduleParam);

  if (!module) return <Screen safeAreaTop={false}>
    <Panel><Eyebrow>Bloom</Eyebrow><Heading>App not found</Heading><Body>This module isn’t in the Bloom app catalog.</Body><Button label="Browse all apps" onPress={() => router.replace('/apps' as Href)} /></Panel>
  </Screen>;

  return <PillarHomeScreen moduleId={module.id} />;
}
