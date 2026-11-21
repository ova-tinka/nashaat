import { Image, StyleSheet, View } from 'react-native';
import { studySubjectArtworks } from '../lib/study-subject-artworks';

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
