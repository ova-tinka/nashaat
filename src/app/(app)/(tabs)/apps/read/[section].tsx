import { useLocalSearchParams } from 'expo-router';
import { GrowthModuleScreen } from '../../../../../components/growth-module-screen';

export default function ReadSectionRoute() {
  const { section } = useLocalSearchParams<{ section?: string }>();
  return <GrowthModuleScreen moduleId="read" sectionId={section} />;
}
