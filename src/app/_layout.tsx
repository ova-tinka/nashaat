import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { AuthProvider } from '../lib/auth';
import { ThemeProvider, useBloomTheme } from '../lib/theme-context';

export default function RootLayout() {
  return <ThemeProvider initialMode="light"><SafeAreaProvider><AuthProvider><RootNavigator /></AuthProvider></SafeAreaProvider></ThemeProvider>;
}

function RootNavigator() {
  const { mode, theme } = useBloomTheme();
  return <>
    <StatusBar style={mode === 'dark' ? 'light' : 'dark'} />
    <Stack screenOptions={{ headerShown: false, contentStyle: { backgroundColor: theme.colors.canvas } }} />
  </>;
}
