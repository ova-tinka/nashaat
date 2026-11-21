import { router, type Href } from 'expo-router';
import { View } from 'react-native';
import { Body, Button, Eyebrow, Heading, Label, Panel, Screen, sharedStyles } from '../../../components/bloom-ui';
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
    <Panel>
      <Eyebrow>Family Space · Optional</Eyebrow>
      <Label>{childProfile ? 'Your guardian manages family connections' : 'Manage a family space'}</Label>
      <Body>{childProfile ? 'Family members and supervision permissions are handled by your guardian.' : 'Create a family, connect a child account, or manage an existing household. Personal Mode stays separate.'}</Body>
      {!childProfile && <Button label="Open Family Space" variant="secondary" onPress={() => router.push('/family' as Href)} />}
    </Panel>
    <Panel>
      <Label>Account and privacy</Label>
      <Body>Manage privacy, sign-in, and profile access.</Body>
      <Button label="Open account" variant="secondary" onPress={() => router.push('/account' as Href)} />
    </Panel>
  </Screen>;
}
