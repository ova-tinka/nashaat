import type { ImageSourcePropType } from 'react-native';
import type { ModuleKey } from '../theme';

// Replace these stable asset paths when Bloom's final photography is ready.
export const bloomHomeImage: ImageSourcePropType = require('./images/bloom/home-mountain.jpg');

export const bloomPillarImages: Record<ModuleKey, ImageSourcePropType> = {
  exercise: require('./images/bloom/exercise-studio.jpg'),
  study: require('./images/bloom/study-desk.jpg'),
  read: require('./images/bloom/reading-book.jpg'),
  tasks: require('./images/bloom/tasks-journal.jpg'),
};
