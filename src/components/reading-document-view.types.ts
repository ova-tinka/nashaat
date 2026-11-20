import type { ReadingLocation } from '../lib/reading-reader';

export type ReadingDocumentViewProps = {
  format: 'pdf' | 'epub';
  sourceUrl: string;
  initialCfi?: string | null;
  initialPercent?: number;
  initialPage?: number | null;
  backgroundColor: string;
  textColor: string;
  onLocation: (location: ReadingLocation) => void;
};
