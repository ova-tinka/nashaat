import { randomUUID } from 'expo-crypto';
import * as WebBrowser from 'expo-web-browser';
import { router, useFocusEffect, useLocalSearchParams, type Href } from 'expo-router';
import { useCallback, useEffect, useRef, useState } from 'react';
import { ActivityIndicator, Platform, StyleSheet, View } from 'react-native';
import { isTauri } from '@tauri-apps/api/core';
import { Body, Button, ErrorText, Eyebrow, Field, Heading, Label, Panel, Screen, sharedStyles } from '../../../../../../components/bloom-ui';
import { ReadingDocumentView } from '../../../../../../components/reading-document-view';
import { useAuth } from '../../../../../../lib/auth';
import { createGrowthDocumentUrl, deleteGrowthRecord, finishGrowthSession, loadGrowthDocuments, loadGrowthModule,
  saveGrowthRecord, startGrowthSession, cancelGrowthSession, updateGrowthRecord,
  type GrowthDocument, type GrowthItem, type GrowthRecord, type GrowthSession } from '../../../../../../lib/growth-modules';
import { getCurrentDeviceIdentity } from '../../../../../../lib/devices';
import { useBloomTheme } from '../../../../../../lib/theme-context';
import { isMacTauriWebView, isReaderFormatSupported, resolveBloomPlatform } from '../../../../../../lib/platform-capabilities';
import { moduleManifest } from '../../../../../../lib/module-manifest';

type Location = { cfi: string | null; page: number; pageCount: number; percent: number };
function parseLocation(record?: GrowthRecord | null): Location | null {
  if (!record) return null;
  try {
    const value = JSON.parse(record.body) as Partial<Location>;
    if (typeof value.page !== 'number' || typeof value.pageCount !== 'number' || typeof value.percent !== 'number') return null;
    return { cfi: typeof value.cfi === 'string' ? value.cfi : null, page: value.page, pageCount: value.pageCount,
      percent: Math.max(0, Math.min(100, value.percent)) };
  } catch { return null; }
}

export default function IntegratedReaderScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const { profileId } = useAuth();
  const { theme } = useBloomTheme();
  const [document, setDocument] = useState<(GrowthDocument & { format: 'pdf' | 'epub' }) | null>(null);
  const [item, setItem] = useState<GrowthItem | null>(null);
  const [records, setRecords] = useState<GrowthRecord[]>([]);
  const [session, setSession] = useState<GrowthSession | null>(null);
  const [url, setUrl] = useState<string | null>(null);
  const [position, setPosition] = useState<Location>({ cfi: null, page: 1, pageCount: 0, percent: 0 });
  const [startLocation, setStartLocation] = useState<Location | null>(null);
  const [pageText, setPageText] = useState('1');
  const [countText, setCountText] = useState('');
  const [bookmarkName, setBookmarkName] = useState('');
  const [confirmBookmarkDeleteId, setConfirmBookmarkDeleteId] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [tick, setTick] = useState(0);
  const savedPosition = useRef<GrowthRecord | null>(null);
  const currentPosition = useRef(position);
  const positionWrite = useRef<Promise<void>>(Promise.resolve());
  const pendingPosition = useRef<{ signature: string; requestId: string } | null>(null);
  const pendingBookmark = useRef<{ signature: string; requestId: string } | null>(null);

  const refresh = useCallback(async () => {
    if (!profileId || !id) { setLoading(false); setError('The reading profile or file is unavailable.'); return; }
    setLoading(true); setError(null);
    try {
      const [documents, module] = await Promise.all([loadGrowthDocuments('read'), loadGrowthModule(profileId, 'read')]);
      const found = documents.find((entry) => entry.id === id);
      const foundItem = found ? module.items.find((entry) => entry.id === found.item_id) ?? null : null;
      if (!found || !foundItem) throw new Error('This private reading file is not available to this profile.');
      if (found.format === 'docx') throw new Error('DOCX documents are available in Study, not the Read library.');
      const macTauriApp = Platform.OS === 'web' && typeof navigator !== 'undefined'
        && isTauri() && isMacTauriWebView(navigator.platform, navigator.userAgent);
      const bloomPlatform = resolveBloomPlatform(Platform.OS, macTauriApp);
      const readerFormats = moduleManifest.find((entry) => entry.id === 'read')?.readerFormats ?? {};
      if (!isReaderFormatSupported(readerFormats, bloomPlatform, found.format)) {
        throw new Error('Bloom’s in-app PDF and EPUB reader is available on web. Open this file from Bloom in a web browser.');
      }
      const signed = await createGrowthDocumentUrl(found.storage_path);
      setDocument(found as GrowthDocument & { format: 'pdf' | 'epub' }); setItem(foundItem); setRecords(module.records); setUrl(signed);
      setSession(module.sessions.find((entry) => entry.status === 'in_progress') ?? null);
      const record = module.records.filter((entry) => entry.kind === 'reader_position' && entry.metadata.document_id === found.id)
        .sort((a, b) => Date.parse(b.updated_at) - Date.parse(a.updated_at))[0] ?? null;
      savedPosition.current = record;
      const location = parseLocation(record);
      if (location) {
        currentPosition.current = location; setPosition(location);
        setPageText(String(location.page)); setCountText(String(location.pageCount || ''));
      } else {
        const empty = { cfi: null, page: 1, pageCount: 0, percent: 0 };
        currentPosition.current = empty; setPosition(empty); setPageText('1'); setCountText('');
      }
      setStartLocation(location);
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'Could not open this private reading file.'); }
    finally { setLoading(false); }
  }, [id, profileId]);
  useFocusEffect(useCallback(() => { void refresh(); }, [refresh]));

  useEffect(() => {
    if (!session) return;
    const timer = setInterval(() => setTick(Date.now()), 1000);
    return () => clearInterval(timer);
  }, [session]);

  const setCurrentPosition = useCallback((next: Location) => {
    currentPosition.current = next;
    setPosition(next);
  }, []);

  const onReaderLocation = useCallback((location: { cfi: string; percent: number }) => {
    setCurrentPosition({ ...currentPosition.current, cfi: location.cfi, percent: location.percent });
  }, [setCurrentPosition]);

  useEffect(() => {
    if (!document || !item || (position.percent <= 0 && !position.cfi && position.page <= 1)) return;
    const timer = setTimeout(() => { void persistPosition(); }, 700);
    return () => clearTimeout(timer);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [document?.id, item?.id, position.cfi, position.page, position.pageCount, position.percent]);

  async function persistPosition(snapshot = currentPosition.current) {
    if (!document || !item || !profileId) return;
    const positionToSave = { ...snapshot };
    const signature = JSON.stringify(positionToSave);
    positionWrite.current = positionWrite.current.catch(() => undefined).then(async () => {
      if (JSON.stringify(currentPosition.current) !== signature) return;
      try {
        const title = 'Reading position · ' + document.title;
        const body = JSON.stringify(positionToSave);
        const metadata = { document_id: document.id };
        if (savedPosition.current) await updateGrowthRecord(savedPosition.current.id, title, body, metadata);
        else {
          if (pendingPosition.current?.signature !== signature) pendingPosition.current = { signature, requestId: randomUUID() };
          const recordId = await saveGrowthRecord({ moduleId: 'read', itemId: item.id, kind: 'reader_position', title, body,
            metadata, requestId: pendingPosition.current.requestId });
          const now = new Date().toISOString();
          savedPosition.current = { id: recordId, module_id: 'read', item_id: item.id,
            kind: 'reader_position', title, body, metadata, scheduled_at: null, score: null,
            created_at: now, updated_at: now };
          pendingPosition.current = null;
        }
        // Keep progress scoped to this document; the item update RPC rewrites every item field.
        setNotice(null);
      } catch { setNotice('The current position is shown, but Bloom could not save it yet. Retry from this page.'); }
    });
    await positionWrite.current;
  }

  async function syncModuleState() {
    if (!profileId) return;
    const module = await loadGrowthModule(profileId, 'read');
    setRecords(module.records);
    setSession(module.sessions.find((entry) => entry.status === 'in_progress') ?? null);
  }

  async function startSession() {
    if (!profileId || !item) return;
    setBusy(true); setError(null);
    try {
      await startGrowthSession('read', item.id, await getCurrentDeviceIdentity(profileId), randomUUID());
      await syncModuleState(); setNotice('A server-timed reading session started.');
    } catch { setError('Could not start or refresh the reading session. Finish any current session first, then retry.'); }
    finally { setBusy(false); }
  }
  async function finishSession(cancel: boolean) {
    if (!session || session.item_id !== item?.id) return;
    setBusy(true); setError(null);
    try {
      if (cancel) { await cancelGrowthSession(session.id); setNotice('Reading session cancelled.'); }
      else { const result = await finishGrowthSession(session.id); setNotice('Reading session saved · ' + Math.floor(result.durationSeconds / 60) + ' min.'); }
      setSession(null);
    } catch { setError('Could not save the reading session. Retry while connected.'); }
    finally { setBusy(false); }
  }
  async function addBookmark() {
    if (!document || !item) return;
    setBusy(true); setError(null);
    try {
      const location = { ...currentPosition.current };
      if (location.percent > 0 || location.cfi || location.page > 1) await persistPosition(location);
      const title = 'Bookmark · ' + (bookmarkName.trim() || 'Page ' + location.page);
      const body = JSON.stringify(location);
      const signature = JSON.stringify([document.id, title, body]);
      if (pendingBookmark.current?.signature !== signature) pendingBookmark.current = { signature, requestId: randomUUID() };
      const recordId = await saveGrowthRecord({ moduleId: 'read', itemId: item.id, kind: 'reader_bookmark', title, body,
        metadata: { document_id: document.id }, requestId: pendingBookmark.current.requestId });
      const now = new Date().toISOString();
      setRecords((current) => [{ id: recordId, module_id: 'read', item_id: item.id, kind: 'reader_bookmark', title, body,
        metadata: { document_id: document.id }, scheduled_at: null, score: null, created_at: now, updated_at: now }, ...current]);
      pendingBookmark.current = null;
      setBookmarkName(''); setNotice('Bookmark saved.');
    } catch { setError('Could not save this bookmark.'); }
    finally { setBusy(false); }
  }
  async function deleteBookmark(record: GrowthRecord) {
    setBusy(true); setError(null);
    try { await deleteGrowthRecord(record.id); setRecords((current) => current.filter((entry) => entry.id !== record.id)); setConfirmBookmarkDeleteId(null); }
    catch { setError('Could not delete this bookmark.'); }
    finally { setBusy(false); }
  }
  function restoreBookmark(record: GrowthRecord) {
    const location = parseLocation(record);
    if (!location) return;
    setStartLocation(location); setCurrentPosition(location); setPageText(String(location.page));
  }

  const currentBookmarks = records.filter((record) => record.kind === 'reader_bookmark' && record.metadata.document_id === id)
    .sort((a, b) => Date.parse(b.created_at) - Date.parse(a.created_at));
  const activeSession = Boolean(session && session.item_id === item?.id);
  const elapsed = activeSession && tick ? Math.max(0, Math.floor((tick - Date.parse(session!.started_at)) / 1000)) : 0;

  return <Screen safeAreaTop={false}>
    <View style={sharedStyles.column}>
      <Eyebrow>Bloom reader · private file</Eyebrow>
      <Heading>{document?.title ?? 'Open reading file'}</Heading>
      <Body>{document ? document.format.toUpperCase() + ' · ' + (item?.title ?? 'Reading list item') + ' · authorized content' : 'Your reading list stays at /apps/read.'}</Body>
      <Button label="Back to Read" variant="tertiary" onPress={() => router.replace('/apps/read' as Href)} />
    </View>
    {loading && <ActivityIndicator />}
    {error && <Panel><ErrorText>{error}</ErrorText><Button label="Try again" variant="secondary" onPress={() => void refresh()} /></Panel>}
    {!loading && document && item && url && <>
      <Panel>
        <Eyebrow>Reading session</Eyebrow>
        {activeSession ? <><Label>Server-timed session · {clock(elapsed)}</Label>
          <Button label="Finish reading session" onPress={() => void finishSession(false)} busy={busy} />
          <Button label="Cancel session" variant="secondary" onPress={() => void finishSession(true)} disabled={busy} /></>
          : session ? <Body>Another reading session is running. Finish it from its reading item before starting here.</Body>
            : <Button label="Start reading session" onPress={() => void startSession()} busy={busy} />}
        <Body>A reader position is not proof of time spent. Sessions are timed separately by the server.</Body>
      </Panel>
      <Panel>
        <Eyebrow>Reading view · {Platform.OS === 'web' || document.format === 'epub' ? 'in app' : 'platform viewer'}</Eyebrow>
        {(Platform.OS === 'web' || document.format === 'epub') && <ReadingDocumentView key={`${document.id}:${startLocation?.cfi ?? startLocation?.page ?? 1}`} format={document.format} sourceUrl={url}
          initialCfi={startLocation?.cfi} initialPercent={startLocation?.percent}
          initialPage={startLocation?.page} backgroundColor={theme.colors.surface}
          textColor={theme.colors.ink} onLocation={onReaderLocation} />}
        {Platform.OS !== 'web' && document.format === 'pdf' && <>
          <Body>Bloom’s in-app PDF view is enabled on web. Your private PDF can open in the platform browser here.</Body>
          <Button label="Open PDF in browser" variant="secondary" onPress={() => void WebBrowser.openBrowserAsync(url)} />
        </>}
        {Platform.OS !== 'web' && document.format === 'epub' && <Body>EPUB rendering uses Bloom’s bundled reader. If this device cannot open the file, retry or reopen it from your Read library.</Body>}
        {document.format === 'pdf' && <View style={styles.controls}>
          <Field label="Current page" value={pageText} onChangeText={(value) => {
            setPageText(value); const page = Number(value); const count = Number(countText);
            if (Number.isInteger(page) && page >= 1) setCurrentPosition({ cfi: null, page, pageCount: count > 0 ? count : 0, percent: count > 0 ? Math.min(100, page / count * 100) : 0 });
          }} keyboardType="number-pad" editable={!busy} />
          <Field label="Total pages (optional)" value={countText} onChangeText={(value) => {
            setCountText(value); const page = Number(pageText); const count = Number(value);
            if (Number.isInteger(count) && count > 0) setCurrentPosition({ cfi: null, page: Math.max(1, page), pageCount: count, percent: Math.min(100, page / count * 100) });
          }} keyboardType="number-pad" editable={!busy} />
        </View>}
        <Body>Position · {Math.round(position.percent)}%{position.pageCount ? ' · page ' + position.page + ' of ' + position.pageCount : ''}</Body>
        <Button label="Save current position" variant="tertiary" onPress={() => void persistPosition()} disabled={busy} />
        <Field label="Bookmark name (optional)" value={bookmarkName} onChangeText={setBookmarkName} maxLength={80} editable={!busy} placeholder="A useful passage" />
        <Button label="Save bookmark" variant="secondary" onPress={() => void addBookmark()} busy={busy} disabled={busy} />
      </Panel>
      <Panel>
        <Eyebrow>Bookmarks · {currentBookmarks.length}</Eyebrow>
        {currentBookmarks.length === 0 ? <Body>Your saved pages and sections will appear here.</Body> : currentBookmarks.map((record) => <View key={record.id} style={sharedStyles.row}>
          <View style={sharedStyles.grow}><Label>{record.title.replace(/^Bookmark · /, '')}</Label><Body>{parseLocation(record)?.cfi ? 'Reading position · ' + Math.round(parseLocation(record)!.percent) + '%' : 'Page ' + (parseLocation(record)?.page ?? 1)}</Body></View>
          <Button label="Open" variant="tertiary" disabled={busy} onPress={() => restoreBookmark(record)} />
          {confirmBookmarkDeleteId === record.id
            ? <View style={sharedStyles.column}>
              <Body>Delete this bookmark?</Body>
              <Button label="Confirm delete" variant="destructive" disabled={busy} onPress={() => void deleteBookmark(record)} />
              <Button label="Keep bookmark" variant="secondary" disabled={busy} onPress={() => setConfirmBookmarkDeleteId(null)} />
            </View>
            : <Button label="Delete" variant="tertiary" disabled={busy} onPress={() => setConfirmBookmarkDeleteId(record.id)} />}
        </View>)}
      </Panel>
      <Panel>
        <Eyebrow>Reading tools</Eyebrow>
        <Body>Notes, annotations, vocabulary, and reflection prompts stay with this reading item on the Read landing page.</Body>
        <Button label="Open notes, vocabulary, and reflection" variant="secondary" onPress={() => router.replace('/apps/read' as Href)} />
        {notice && <Body>{notice}</Body>}
      </Panel>
    </>}
  </Screen>;
}

function clock(seconds: number) {
  return Math.floor(seconds / 60).toString().padStart(2, '0') + ':' + (seconds % 60).toString().padStart(2, '0');
}
const styles = StyleSheet.create({
  controls: { gap: 10 },
  pdfFrame: { width: '100%' },
});
