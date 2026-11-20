export type StudyPracticeDifficulty = 'gentle' | 'steady' | 'challenge';

export type StudyPracticeAnswer = {
  created_at: string;
  metadata: Record<string, unknown>;
};

export function suggestStudyPracticeDifficulty(answers: StudyPracticeAnswer[]): StudyPracticeDifficulty {
  const recent = answers
    .filter((record) => typeof record.metadata.self_assessed_correct === 'boolean')
    .sort((left, right) => Date.parse(right.created_at) - Date.parse(left.created_at))
    .slice(0, 3);
  if (recent.length < 2) return 'steady';
  const correct = recent.filter((record) => record.metadata.self_assessed_correct === true).length;
  if (correct >= 2) return 'challenge';
  if (correct === 0) return 'gentle';
  return 'steady';
}
