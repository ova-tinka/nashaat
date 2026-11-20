import { useLocalSearchParams } from 'expo-router';
import { GrowthModuleScreen } from '../../../../../components/growth-module-screen';

export default function StudySectionRoute() {
  const { section } = useLocalSearchParams<{ section?: string }>();
  return <GrowthModuleScreen moduleId="study" sectionId={section} />;
}
