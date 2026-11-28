import { Stack } from 'expo-router';
import { StatusBar } from 'expo-status-bar';
import { Component, useEffect, type ErrorInfo, type ReactNode } from 'react';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { Body, Button, Heading, Panel, Screen } from '../components/bloom-ui';
import { AuthProvider } from '../lib/auth';
import { LocaleProvider } from '../lib/locale-context';
import { captureException, initSentry } from '../lib/sentry';
import { ThemeProvider, useBloomTheme } from '../lib/theme-context';

class BloomErrorBoundary extends Component<{ children: ReactNode }, { hasError: boolean }> {
  state = { hasError: false };

  static getDerivedStateFromError() {
    return { hasError: true };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    captureException(error, { componentStack: info.componentStack?.slice(0, 300) });
  }

  render() {
    if (this.state.hasError) {
      return <Screen>
        <Panel>
          <Heading>Something went wrong</Heading>
          <Body>Bloom encountered an unexpected error. Your saved progress is safe.</Body>
          <Button label="Try again" onPress={() => this.setState({ hasError: false })} />
        </Panel>
      </Screen>;
    }
    return this.props.children;
  }
}

export default function RootLayout() {
  useEffect(() => {
    initSentry();
  }, []);

  return <LocaleProvider><ThemeProvider initialMode="light"><SafeAreaProvider><BloomErrorBoundary><AuthProvider><RootNavigator /></AuthProvider></BloomErrorBoundary></SafeAreaProvider></ThemeProvider></LocaleProvider>;
}

function RootNavigator() {
  const { mode, theme } = useBloomTheme();
  return <>
    <StatusBar style={mode === 'dark' ? 'light' : 'dark'} />
    <Stack screenOptions={{ headerShown: false, contentStyle: { backgroundColor: theme.colors.canvas } }} />
  </>;
}
