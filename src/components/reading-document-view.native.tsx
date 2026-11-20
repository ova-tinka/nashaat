import { useEffect, useMemo, useState } from 'react';
import { ActivityIndicator, StyleSheet, View } from 'react-native';
import WebView from 'react-native-webview';
import { Body, Button, ErrorText } from './bloom-ui';
import { buildReadingDocumentHtml, loadEpubRendererScript, parseReaderMessage } from '../lib/reading-reader';
import type { ReadingDocumentViewProps } from './reading-document-view.types';

export function ReadingDocumentView(props: ReadingDocumentViewProps) {
  const [epubScript, setEpubScript] = useState<string | null>(props.format === 'pdf' ? '' : null);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [webError, setWebError] = useState<string | null>(null);
  const [loadAttempt, setLoadAttempt] = useState(0);

  useEffect(() => {
    let active = true;
    if (props.format === 'pdf') return () => { active = false; };
    void loadEpubRendererScript().then((script) => {
      if (active) setEpubScript(script);
    }).catch(() => {
      if (active) setLoadError('Could not load the bundled EPUB reader. Retry after reconnecting.');
    });
    return () => { active = false; };
  }, [props.format, loadAttempt]);

  const html = useMemo(() => {
    if (epubScript === null || loadError) return null;
    try {
      return buildReadingDocumentHtml({ format: props.format, sourceUrl: props.sourceUrl, initialCfi: props.initialCfi,
        initialPercent: props.initialPercent, initialPage: props.initialPage, backgroundColor: props.backgroundColor,
        textColor: props.textColor, epubScript });
    } catch {
      return null;
    }
  }, [epubScript, loadError, props.format, props.sourceUrl, props.initialCfi, props.initialPercent, props.initialPage,
    props.backgroundColor, props.textColor]);

  function onMessage(value: string) {
    const message = parseReaderMessage(value);
    if (!message) return;
    if ('error' in message) setWebError(message.error);
    else { setWebError(null); props.onLocation(message); }
  }

  return <View style={styles.frame}>
    {html && <WebView
      source={{ html }}
      originWhitelist={['*']}
      javaScriptEnabled
      domStorageEnabled
      setSupportMultipleWindows={false}
      allowFileAccess={false}
      allowUniversalAccessFromFileURLs={false}
      mixedContentMode="never"
      onMessage={(event) => onMessage(event.nativeEvent.data)}
      onError={() => setWebError('The private document could not be loaded. Refresh the reader and try again.')}
      startInLoadingState
      renderLoading={() => <View style={styles.loading}><ActivityIndicator /><Body>Opening your private document…</Body></View>}
      style={styles.webview}
    />}
    {!html && !loadError && <View style={styles.loading}><ActivityIndicator /><Body>Preparing the reader…</Body></View>}
    {(loadError || webError) && <View style={styles.error}>
      <ErrorText>{loadError ?? webError}</ErrorText>
      <Button label="Retry reader" variant="secondary" onPress={() => {
        setLoadError(null); setWebError(null); setEpubScript(props.format === 'pdf' ? '' : null); setLoadAttempt((attempt) => attempt + 1);
      }} />
    </View>}
  </View>;
}

const styles = StyleSheet.create({
  frame: { height: 560, minHeight: 360, overflow: 'hidden', borderRadius: 16 },
  webview: { flex: 1, backgroundColor: 'transparent' },
  loading: { flex: 1, alignItems: 'center', justifyContent: 'center', gap: 10 },
  error: { padding: 16, gap: 10 },
});
