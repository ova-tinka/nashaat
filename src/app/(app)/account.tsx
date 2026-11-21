import { router, type Href } from 'expo-router';
import { View } from 'react-native';
import { Body, Button, Eyebrow, Heading, Label, Panel, Screen, sharedStyles } from '../../components/bloom-ui';
import { useAuth } from '../../lib/auth';

export default function AccountScreen() {
  const { session, childProfile } = useAuth();
  return <Screen safeAreaTop={false}>
    <View style={sharedStyles.column}><Eyebrow>Profile</Eyebrow><Heading>Account</Heading><Body>Manage your account, privacy, and family spaces.</Body><Button label="Back to profile" variant="tertiary" onPress={() => router.canGoBack() ? router.back() : router.replace('/profile' as Href)} /></View>
    <Panel><Label>Account details</Label><Body>{session?.user.email || 'No email address on this account.'}</Body><Body>{childProfile ? 'Child profile' : 'Personal profile'}</Body></Panel>
    <Panel><Label>Privacy</Label><Body>Manage your display name and whether others can find your profile.</Body><Button label="Privacy settings" variant="secondary" onPress={() => router.push('/privacy' as Href)} /></Panel>
    {!childProfile && <Panel><Label>Family Space</Label><Body>Manage your family, profiles and permissions.</Body><Button label="Open Family Space" variant="secondary" onPress={() => router.push('/family' as Href)} /></Panel>}
    <Panel><Label>Profiles</Label><Button label={childProfile ? 'Switch to parent' : 'Profile switching and PIN'} variant="secondary" onPress={() => router.push('/profile-switch' as Href)} /></Panel>
  </Screen>;
}
