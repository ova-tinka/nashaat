import { Image, StyleSheet, View } from 'react-native';

export const studySubjectArtworks = [
  { id: 'biology', label: 'Biology', column: 0, row: 0 },
  { id: 'geology', label: 'Geology', column: 1, row: 0 },
  { id: 'chemistry', label: 'Chemistry', column: 2, row: 0 },
  { id: 'physics', label: 'Physics', column: 3, row: 0 },
  { id: 'mathematics', label: 'Mathematics', column: 4, row: 0 },
  { id: 'computer-science', label: 'Computer science', column: 0, row: 1 },
  { id: 'history', label: 'History', column: 1, row: 1 },
  { id: 'geography', label: 'Geography', column: 2, row: 1 },
  { id: 'literature', label: 'Literature', column: 3, row: 1 },
  { id: 'psychology', label: 'Psychology', column: 4, row: 1 },
  { id: 'medicine', label: 'Medicine', column: 0, row: 2 },
  { id: 'astronomy', label: 'Astronomy', column: 1, row: 2 },
  { id: 'economics', label: 'Economics', column: 2, row: 2 },
  { id: 'art', label: 'Art', column: 3, row: 2 },
  { id: 'music', label: 'Music', column: 4, row: 2 },
  { id: 'engineering', label: 'Engineering', column: 0, row: 3 },
  { id: 'environmental-science', label: 'Environmental science', column: 1, row: 3 },
  { id: 'political-science', label: 'Political science', column: 2, row: 3 },
  { id: 'linguistics', label: 'Linguistics', column: 3, row: 3 },
  { id: 'sociology', label: 'Sociology', column: 4, row: 3 },
  { id: 'philosophy', label: 'Philosophy', column: 0, row: 4 },
  { id: 'statistics', label: 'Statistics', column: 1, row: 4 },
  { id: 'anatomy', label: 'Anatomy', column: 2, row: 4 },
  { id: 'design', label: 'Design', column: 3, row: 4 },
  { id: 'agriculture', label: 'Agriculture', column: 4, row: 4 },
] as const;

const atlas = require('../assets/images/study-subjects-atlas.png');
const gridSize = 5;

export function suggestStudySubjectArtwork(title: string) {
  const value = title.trim().toLocaleLowerCase();
  const matches: [RegExp, string][] = [
    [/biology|biological|life science/, 'biology'], [/geolog|earth science|rocks?/, 'geology'],
    [/chemistry|chemical/, 'chemistry'], [/physics|physical science/, 'physics'],
    [/math|algebra|calculus|geometry/, 'mathematics'], [/computer|programming|coding|software|informatics/, 'computer-science'],
    [/history|historical/, 'history'], [/geography|geographic|maps?/, 'geography'],
    [/literature|reading|language arts|english/, 'literature'], [/psychology|behavioral science/, 'psychology'],
    [/medicine|medical|health science|nursing/, 'medicine'], [/astronomy|space science|cosmology/, 'astronomy'],
    [/economics|finance|accounting|business/, 'economics'], [/art|painting|drawing/, 'art'],
    [/music|instrument|composition/, 'music'], [/engineering|robotics|mechanical/, 'engineering'],
    [/environment|climate|ecology/, 'environmental-science'], [/political science|government|civics/, 'political-science'],
    [/linguistic|language/, 'linguistics'], [/sociology|social science|anthropology/, 'sociology'],
    [/philosophy|ethics/, 'philosophy'], [/statistics|data science|analytics/, 'statistics'],
    [/anatomy|physiology/, 'anatomy'], [/design|architecture/, 'design'], [/agriculture|farming|botany/, 'agriculture'],
  ];
  return matches.find(([pattern]) => pattern.test(value))?.[1] ?? 'literature';
}

export function SubjectArtwork({ artworkId, size = 68 }: { artworkId: string; size?: number }) {
  const artwork = studySubjectArtworks.find((item) => item.id === artworkId) ?? studySubjectArtworks[8];
  return <View accessible accessibilityRole="image" accessibilityLabel={`${artwork.label} subject artwork`}
    style={[styles.crop, { width: size, height: size, borderRadius: size * 0.22 }]}>
    <Image source={atlas} resizeMode="stretch" accessible={false} style={{
      position: 'absolute', width: size * gridSize, height: size * gridSize,
      left: -artwork.column * size, top: -artwork.row * size,
    }} />
  </View>;
}

const styles = StyleSheet.create({ crop: { overflow: 'hidden', backgroundColor: '#F6F8FC' } });
