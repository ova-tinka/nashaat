import { Redirect } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { DesignSystemGallery } from '../components/design-system-gallery';
import { ThemeProvider, useBloomTheme } from '../lib/theme-context';

function GalleryWithStatusBar() {
  const { mode } = useBloomTheme();
  return <>
    <StatusBar style={mode === 'dark' ? 'light' : 'dark'} />
    <DesignSystemGallery />
  </>;
}

export default function DesignSystemScreen() {
  if (!__DEV__) return <Redirect href="/sign-in" />;
  return <ThemeProvider initialMode="light"><GalleryWithStatusBar /></ThemeProvider>;
}
