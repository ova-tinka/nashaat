import { router, type Href } from 'expo-router';
import { Platform, View } from 'react-native';
import { BloomWordmark, Body, Button, DesktopContent, Eyebrow, Heading, Label, Panel, Screen, sharedStyles } from '../components/bloom-ui';

export default function LegalScreen() {
  return <Screen>
    <DesktopContent maxWidth={780}>
      <View style={sharedStyles.column}>
        <BloomWordmark size={28} />
        <Eyebrow>Legal & Support</Eyebrow>
        <Heading>Privacy, Terms & Disclosures</Heading>
        <Body>Clear disclosures describing how Bloom handles your account, permissions, subscriptions, and data.</Body>
        <Button label="Back" variant="tertiary" onPress={() => (router.canGoBack() ? router.back() : router.replace('/sign-in' as Href))} />
      </View>

      <Panel>
        <Label>Privacy Policy</Label>
        <Body>
          Bloom stores your email address, profile settings, and the Exercise, Study, Reading, and Task records you choose to create in Supabase. Optional uploaded Study/Reading files are stored privately for your account.
        </Body>
        <Body>
          On macOS, website addresses checked by Bloom’s Network Extension and Browser Bridge stay on your Mac and are never uploaded to Bloom servers.
        </Body>
        <Body>
          When enabled by the app configuration, crash reports (Sentry) and essential product funnel events (Amplitude) scrub credentials, prompts, documents, and email addresses, and third-party tracking is disabled for child profiles.
        </Body>
        <Body>[OWNER REVIEW REQUIRED: Add legal entity name, registered business address, data retention durations, and DPO/privacy contact email before public release.]</Body>
      </Panel>

      <Panel>
        <Label>Terms of Service & Subscription Terms</Label>
        <Body>
          Bloom is a paid subscription service covering Exercise, Education (Study), Reading, Tasks, and Focus screen-time tools. There is no permanent free tier or free trial.
        </Body>
        <Body>
          Subscriptions renew automatically at the selected weekly, monthly, or yearly interval unless cancelled before the end of the current billing period through your original payment provider (Apple App Store, Google Play, or Bloom website / Tap).
        </Body>
        <Body>[OWNER REVIEW REQUIRED: Confirm governing law, business legal name, and formal refund policy language before commercial launch.]</Body>
      </Panel>

      <Panel>
        <Label>Device Permissions Explained</Label>
        <Body>• iOS Screen Time & Family Controls: Required to shield selected apps and domains on your iPhone/iPad.</Body>
        <Body>• Android Accessibility Service: Required to detect and block selected distraction apps on Android.</Body>
        <Body>• macOS Network Extension, Background Monitor & Accessibility: Required to filter blocked domains, show the Bloom Shield overlay, and coordinate earned screen time on this Mac.</Body>
      </Panel>

      <Panel>
        <Label>Account Deletion & Subscriptions</Label>
        <Body>
          Personal accounts can export data and request account deletion from Profile → Account. Active Family accounts route deletion through a reviewed request so household members remain protected.
        </Body>
        <Body>
          Important: Deleting your Bloom account removes your Bloom data, but does not automatically cancel an active Apple App Store or Google Play subscription. Cancel store-billed subscriptions directly in Apple or Google Play settings.
        </Body>
        <Body>[OWNER REVIEW REQUIRED: Add external web account-deletion request URL for store review compliance.]</Body>
      </Panel>

      <Panel>
        <Label>Support</Label>
        <Body>App version 0.1.1 · Platform: {Platform.OS}</Body>
        <Body>[OWNER REVIEW REQUIRED: Add customer support email and help portal URL.]</Body>
      </Panel>
    </DesktopContent>
  </Screen>;
}
