import { LocalizedText as Text } from './bloom-ui';
import MaterialIcons from '@expo/vector-icons/MaterialIcons';
import { ImageBackground, StyleSheet, View } from 'react-native';
import { bloomPillarImages } from '../assets/bloom-images';
import type { Exercise } from '../lib/bloom';
import { useBloomTheme } from '../lib/theme-context';

function imageSource(mediaLink: string | null) {
  if (mediaLink) {
    try {
      const url = new URL(mediaLink);
      if (url.protocol === 'https:' && !url.username && !url.password && /\.(?:avif|jpe?g|png|webp)$/i.test(url.pathname)) {
        return { uri: url.toString() };
      }
    } catch { /* Use Bloom's bundled exercise image when the catalog has no image URL. */ }
  }
  return bloomPillarImages.exercise;
}

export function ExerciseArtwork({ exercise, size = 'medium' }: {
  exercise: Pick<Exercise, 'name' | 'muscle_group' | 'media_link'>;
  size?: 'small' | 'medium' | 'large';
}) {
  const { theme } = useBloomTheme();
  return <ImageBackground
    source={imageSource(exercise.media_link)}
    resizeMode="cover"
    accessible
    accessibilityRole="image"
    accessibilityLabel={`${exercise.name} exercise image`}
    imageStyle={styles.image}
    style={[styles.artwork, styles[size], { backgroundColor: theme.modules.exercise.surface }]}>
    <View style={styles.shade} />
    <View style={styles.detail}>
      <MaterialIcons name="fitness-center" size={size === 'large' ? 24 : 18} color="#FFFFFF" />
      {exercise.muscle_group ? <Text numberOfLines={1} style={styles.group}>{exercise.muscle_group}</Text> : null}
    </View>
  </ImageBackground>;
}

const styles = StyleSheet.create({
  artwork: { overflow: 'hidden', justifyContent: 'flex-end', borderRadius: 16 },
  small: { width: 64, height: 64, borderRadius: 14 },
  medium: { width: 78, height: 78, borderRadius: 16 },
  large: { width: '100%', height: 176, borderRadius: 20 },
  image: { borderRadius: 16 },
  shade: { ...StyleSheet.absoluteFill, backgroundColor: 'rgba(9, 32, 22, 0.24)' },
  detail: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 6, padding: 9 },
  group: { flexShrink: 1, overflow: 'hidden', borderRadius: 99, paddingHorizontal: 7, paddingVertical: 3, backgroundColor: 'rgba(7, 28, 19, 0.72)', color: '#FFFFFF', fontSize: 9, fontWeight: '700' },
});
