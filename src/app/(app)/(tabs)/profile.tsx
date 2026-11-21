import { View } from 'react-native';
import { Body, Eyebrow, Heading, Label, Panel, Screen, sharedStyles } from '../../../components/bloom-ui';
import { useAuth } from '../../../lib/auth';

export default function ProfileScreen() {
  const { session, childProfile } = useAuth();
  return <Screen safeAreaTop={false}>
    <View style={sharedStyles.column}>
      <Eyebrow>Account</Eyebrow>
      <Heading>My profile</Heading>
    </View>
    <Panel>
      <Label>Email</Label>
      <Body>{session?.user.email || 'No email address on this account.'}</Body>
      <Label>Profile type</Label>
      <Body>{childProfile ? 'Child profile' : 'Personal profile'}</Body>
    </Panel>
  </Screen>;
}
