import { Body, Button, Label, Panel } from './bloom-ui';
import { flushOfflineActivitiesForProfile, getPendingOfflineCount } from '../lib/offline-sync-service';

export function OfflinePendingBanner({
  profileId,
  pendingCount,
  onCountUpdated,
  onSynced,
}: {
  profileId: string | null;
  pendingCount: number;
  onCountUpdated: (count: number) => void;
  onSynced: () => Promise<void>;
}) {
  if (pendingCount <= 0) return null;
  return <Panel>
    <Label>Pending offline activity · {pendingCount}</Label>
    <Body>Saved on this device and waiting for connection. Pending records never unlock Screen Time.</Body>
    {profileId && <Button
      label="Sync pending activity"
      variant="secondary"
      onPress={() => void flushOfflineActivitiesForProfile(profileId)
        .then(async () => {
          onCountUpdated(await getPendingOfflineCount(profileId));
          await onSynced();
        })
        .catch(() => undefined)}
    />}
  </Panel>;
}
