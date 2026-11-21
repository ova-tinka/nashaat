import { useLocalSearchParams } from 'expo-router';
import { ReadModuleScreen } from '../../../../../components/read-module-screen';

export default function ReadSectionRoute() {
  const { section } = useLocalSearchParams<{ section?: string }>();
  return <ReadModuleScreen sectionId={section} />;
}
