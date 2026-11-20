import { useLocalSearchParams } from 'expo-router';
import { GrowthModuleScreen } from '../../../../../components/growth-module-screen';

export default function TasksSectionRoute() {
  const { section } = useLocalSearchParams<{ section?: string }>();
  return <GrowthModuleScreen moduleId="tasks" sectionId={section} />;
}
