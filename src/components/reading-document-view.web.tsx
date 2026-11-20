import { useEffect, useMemo, useState, createElement } from 'react';
import { ActivityIndicator, StyleSheet, View } from 'react-native';
import { Body, Button, ErrorText } from './bloom-ui';
import { buildReadingDocumentHtml, loadEpubRendererScript, parseReaderMessage } from '../lib/reading-reader';
import type { ReadingDocumentViewProps } from './reading-document-view.types';

export function ReadingDocumentView(props: ReadingDocumentViewProps) {
  const onLocation = props.onLocation;
  const [frame, setFrame] = useState<HTMLIFrameElement | null>(null);
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

  useEffect(() => {
    function receive(event: MessageEvent) {
      if (event.source !== frame?.contentWindow) return;
      const message = parseReaderMessage(typeof event.data === 'string' ? event.data : JSON.stringify(event.data));
      if (!message) return;
      if ('error' in message) setWebError(message.error);
      else { setWebError(null); onLocation(message); }
    }
    window.addEventListener('message', receive);
    return () => window.removeEventListener('message', receive);
  }, [frame, onLocation]);

  return <View style={styles.frame}>
    {html && createElement('iframe', {
      ref: setFrame,
      title: 'Bloom private reading view',
      srcDoc: html,
      sandbox: 'allow-scripts',
      onError: () => setWebError('The private document could not be loaded. Refresh the reader and try again.'),
      style: iframeStyle,
    })}
    {!html && !loadError && <View style={styles.loading}><ActivityIndicator /><Body>Preparing the reader…</Body></View>}
    {(loadError || webError) && <View style={styles.error}>
      <ErrorText>{loadError ?? webError}</ErrorText>
      <Button label="Retry reader" variant="secondary" onPress={() => {
        setLoadError(null); setWebError(null); setEpubScript(props.format === 'pdf' ? '' : null); setLoadAttempt((attempt) => attempt + 1);
      }} />
    </View>}
  </View>;
}

const iframeStyle = { width: '100%', height: '100%', border: 0 } as const;
const styles = StyleSheet.create({
  frame: { height: 560, minHeight: 360, overflow: 'hidden', borderRadius: 16 },
  loading: { flex: 1, alignItems: 'center', justifyContent: 'center', gap: 10 },
  error: { padding: 16, gap: 10 },
});
