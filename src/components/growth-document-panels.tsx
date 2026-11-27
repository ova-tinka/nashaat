import { randomUUID } from 'expo-crypto';
import AsyncStorage from '@react-native-async-storage/async-storage';
import * as DocumentPicker from 'expo-document-picker';
import { File as ExpoFile } from 'expo-file-system';
import { router, useFocusEffect, type Href } from 'expo-router';
import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { ActivityIndicator, Platform, StyleSheet, Switch, View } from 'react-native';
import { invoke, isTauri } from '@tauri-apps/api/core';
import { Body, Button, ErrorText, Eyebrow, Field, Label, Panel, sharedStyles } from './bloom-ui';
import { useAuth } from '../lib/auth';
import { createGrowthDocument, deleteGrowthDocument, type GrowthDocument, type GrowthItem, type GrowthRecord, uploadGrowthDocumentContent } from '../lib/growth-modules';
import {
  loadGrowthAiPreferences, saveGrowthAiPreferences,
  type GrowthAiPreferences,
} from '../lib/growth-ai';
import { loadStudyDocumentAnswers, requestStudyDocumentHelp, setStudyDocumentAiConsent } from '../lib/growth-modules';
import { useBloomTheme } from '../lib/theme-context';
import { isMacTauriWebView, isReaderFormatSupported, resolveBloomPlatform } from '../lib/platform-capabilities';
import { moduleManifest } from '../lib/module-manifest';
import { bloomWebReaderUrl } from '../lib/bloom-web-reader';

const docxMime = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
const epubMime = 'application/epub+zip';

function currentBloomPlatform() {
  const macTauriApp = Platform.OS === 'web' && typeof navigator !== 'undefined'
    && isTauri() && isMacTauriWebView(navigator.platform, navigator.userAgent);
  return resolveBloomPlatform(Platform.OS, macTauriApp);
}

const readModuleManifest = moduleManifest.find((module) => module.id === 'read');

export function GrowthDocumentLibraryPanel({ moduleId, items, records, documents, initialItemId, onDocumentHelp, readOnly, onSaved }: {
  moduleId: 'study' | 'read'; items: GrowthItem[]; records: GrowthRecord[]; documents: GrowthDocument[]; initialItemId?: string;
  onDocumentHelp?: (documentId: string) => void; readOnly: boolean; onSaved: () => void;
}) {
  const [itemId, setItemId] = useState(initialItemId ?? items.find((item) => item.state === 'active')?.id ?? '');
  const [title, setTitle] = useState('');
  const [picked, setPicked] = useState<DocumentPicker.DocumentPickerAsset | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [confirmDelete, setConfirmDelete] = useState<GrowthDocument | null>(null);
  const pendingUpload = useRef<{ signature: string; requestId: string } | null>(null);
  const candidates = useMemo(() => items.filter((item) => moduleId === 'read'
    ? item.state !== 'archived' && item.item_type === 'reading'
    : item.state === 'active' && ['subject', 'course', 'lesson', 'assignment'].includes(item.item_type)), [items, moduleId]);
  const selectedItemId = candidates.some((item) => item.id === itemId) ? itemId : candidates[0]?.id ?? '';
  const itemNames = new Map(items.map((item) => [item.id, item.title]));
  const attached = documents.filter((document) => moduleId === 'read' ? document.format !== 'docx' : true);
  const maxBytes = moduleId === 'study' ? 10 * 1024 * 1024 : 25 * 1024 * 1024;

  function documentProgress(documentId: string) {
    const record = records.filter((entry) => entry.kind === 'reader_position' && entry.metadata.document_id === documentId)
      .sort((left, right) => Date.parse(right.updated_at) - Date.parse(left.updated_at))[0];
    if (!record) return null;
    try {
      const value = JSON.parse(record.body) as { percent?: unknown };
      return typeof value.percent === 'number' && Number.isFinite(value.percent)
        ? Math.max(0, Math.min(100, value.percent)) : null;
    } catch { return null; }
  }

  function formatFor(asset: DocumentPicker.DocumentPickerAsset) {
    const fileName = asset.name.toLocaleLowerCase();
    if (fileName.endsWith('.pdf')) return { format: 'pdf' as const, mimeType: 'application/pdf' };
    if (moduleId === 'study' && fileName.endsWith('.docx')) return { format: 'docx' as const, mimeType: docxMime };
    if (moduleId === 'read' && fileName.endsWith('.epub')) return { format: 'epub' as const, mimeType: epubMime };
    return null;
  }

  async function chooseFile() {
    setError(null); setNotice(null); setPicked(null);
    try {
      const result = await DocumentPicker.getDocumentAsync({
        type: moduleId === 'study' ? ['application/pdf', docxMime] : ['application/pdf', epubMime],
        copyToCacheDirectory: true,
        multiple: false,
      });
      if (result.canceled || !result.assets[0]) return;
      const asset = result.assets[0];
      const supported = formatFor(asset);
      if (!supported) throw new Error(moduleId === 'study' ? 'Choose a PDF or DOCX file.' : 'Choose a PDF or EPUB file.');
      if (typeof asset.size === 'number' && asset.size > maxBytes) {
        throw new Error(`Choose a file smaller than ${moduleId === 'study' ? '10 MB' : '25 MB'}.`);
      }
      pendingUpload.current = null;
      setPicked(asset);
      setTitle(asset.name.replace(/\.[^.]+$/, '').slice(0, 120));
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Could not open the file picker.');
    }
  }

  async function upload() {
    if (!picked || !selectedItemId || !title.trim()) { setError('Choose an item, a supported file, and a title.'); return; }
    const supported = formatFor(picked);
    if (!supported) { setError('This file format is not supported.'); return; }
    const signature = JSON.stringify([moduleId, selectedItemId, title.trim(), picked.name, picked.size, picked.uri]);
    if (pendingUpload.current?.signature !== signature) pendingUpload.current = { signature, requestId: randomUUID() };
    setBusy(true); setError(null); setNotice(null);
    let prepared: Awaited<ReturnType<typeof createGrowthDocument>> | null = null;
    try {
      const content = picked.file
        ? await picked.file.arrayBuffer()
        : await new ExpoFile(picked.uri).arrayBuffer();
      if (!content.byteLength || content.byteLength > maxBytes) {
        throw new Error(`Choose a non-empty file smaller than ${moduleId === 'study' ? '10 MB' : '25 MB'}.`);
      }
      prepared = await createGrowthDocument({
        moduleId, itemId: selectedItemId, title: title.trim(), fileName: picked.name, format: supported.format,
        mimeType: supported.mimeType, byteSize: content.byteLength, requestId: pendingUpload.current.requestId,
      });
      await uploadGrowthDocumentContent(prepared.storagePath, content, supported.mimeType);
      pendingUpload.current = null; setPicked(null); setTitle('');
      setNotice('Private document uploaded. It is available only in this profile.');
      onSaved();
    } catch (cause) {
      if (prepared) {
        try { await deleteGrowthDocument({ id: prepared.id, storage_path: prepared.storagePath }); } catch { /* Keep the retry state visible if cleanup is unavailable. */ }
      }
      setError(cause instanceof Error ? cause.message : 'Could not upload this private document. Your file remains on this device; retry when connected.');
    } finally { setBusy(false); }
  }

  async function remove(document: GrowthDocument) {
    setBusy(true); setError(null); setNotice(null);
    try {
      await deleteGrowthDocument(document); setConfirmDelete(null);
      setNotice(`${document.title} was deleted from private storage.`); onSaved();
    } catch { setError('Could not remove this document. Retry while connected.'); }
    finally { setBusy(false); }
  }

  async function openReaderInBrowser(document: GrowthDocument) {
    const url = bloomWebReaderUrl(document.id);
    if (!url) { setError('Bloom’s web app address is not configured for this build.'); return; }
    setBusy(true); setError(null); setNotice(null);
    try {
      await invoke('open_reader_in_browser', { documentId: document.id });
      setNotice(`Opened ${document.title} in Bloom’s web reader.`);
    } catch { setError('Could not open Bloom’s web reader. Check the app address and try again.'); }
    finally { setBusy(false); }
  }

  return <Panel>
    <Eyebrow>{moduleId === 'study' ? 'Private source documents' : 'Your reading files'}</Eyebrow>
    <Body>{moduleId === 'study'
      ? 'Add text-based PDFs or DOCX files up to 10 MB. Bloom keeps each file private. Scanned PDFs and image-only documents are not supported.'
      : 'Add an authorized PDF or EPUB up to 25 MB. Bloom stores it privately for this profile.'}</Body>
    {candidates.length === 0 ? <Body>{moduleId === 'study' ? 'Add a Study subject or course first.' : 'Add a reading item before selecting a file.'}</Body> : <>
      <View style={styles.choiceRow}>{candidates.map((item) => <Button key={item.id} label={`${selectedItemId === item.id ? '✓ ' : ''}${item.title}`}
        variant="tertiary" disabled={busy || readOnly} onPress={() => setItemId(item.id)} />)}</View>
      <Field label="Document title" value={title} onChangeText={setTitle} maxLength={120} editable={!busy && !readOnly} />
      {picked && <Body>{picked.name}{typeof picked.size === 'number' ? ` · ${(picked.size / 1024 / 1024).toFixed(1)} MB` : ''}</Body>}
      <View style={sharedStyles.row}>
        <Button label="Choose a private file" variant="secondary" onPress={() => void chooseFile()} disabled={busy || readOnly} />
        <Button label="Upload document" onPress={() => void upload()} busy={busy} disabled={busy || readOnly || !picked || !title.trim() || !selectedItemId} />
      </View>
    </>}
    <Label>Private files · {attached.length}</Label>
    {attached.length === 0 ? <Body>Uploaded documents will appear here.</Body> : attached.map((document) => {
      const browserReaderUrl = moduleId === 'read' ? bloomWebReaderUrl(document.id) : null;
      return <View key={document.id} style={sharedStyles.column}>
      <Label>{document.title}</Label>
      <Body>{itemNames.get(document.item_id) ?? 'Study item'} · {document.format.toUpperCase()} · {(document.byte_size / 1024 / 1024).toFixed(1)} MB
        {moduleId === 'read' && documentProgress(document.id) !== null ? ` · ${Math.round(documentProgress(document.id)!)}% read` : ''}</Body>
      <View style={sharedStyles.row}>
        {moduleId === 'study' && onDocumentHelp && <Button label="Ask about this document" variant="tertiary" disabled={busy}
          onPress={() => onDocumentHelp(document.id)} />}
        {moduleId === 'read' && document.format !== 'docx'
          && isReaderFormatSupported(readModuleManifest?.readerFormats ?? {}, currentBloomPlatform(), document.format)
          ? <Button label="Open reader" variant="secondary" disabled={readOnly || busy}
            onPress={() => router.push({ pathname: '/apps/read/reader/[id]', params: { id: document.id } } as unknown as Href)} />
          : moduleId === 'read' && currentBloomPlatform() === 'macos' ? <View style={sharedStyles.column}>
            <Body>{browserReaderUrl ? 'PDF and EPUB reading is available in Bloom’s web reader.' : 'Browser reading needs Bloom’s public web app address in this build.'}</Body>
            {browserReaderUrl && <Button label="Open in Bloom web reader" variant="secondary" disabled={busy}
              onPress={() => void openReaderInBrowser(document)} />}
          </View>
            : moduleId === 'read' && <Body>The in-app PDF and EPUB reader is available on web. Open this file from Bloom in a web browser.</Body>}
        {!confirmDelete && <Button label="Delete file" variant="tertiary" disabled={readOnly || busy} onPress={() => setConfirmDelete(document)} />}
      </View>
      {confirmDelete?.id === document.id && <View style={sharedStyles.column}>
        <Body>Delete {document.title} and its private file from this profile? Saved document answers are removed with it.</Body>
        <Button label="Confirm delete" variant="destructive" busy={busy} onPress={() => void remove(document)} />
        <Button label="Keep document" variant="secondary" disabled={busy} onPress={() => setConfirmDelete(null)} />
      </View>}
    </View>;
    })}
    {error && <ErrorText>{error}</ErrorText>}{notice && <Body>{notice}</Body>}
  </Panel>;
}

export function StudyDocumentHelpPanel({ profileId, documents, initialDocumentId, readOnly, onSaved }: {
  profileId: string | null; documents: GrowthDocument[]; initialDocumentId?: string; readOnly: boolean; onSaved: () => void;
}) {
  const { childProfile } = useAuth();
  const { theme } = useBloomTheme();
  const [preferences, setPreferences] = useState<GrowthAiPreferences | null>(null);
  const [sharingConsent, setSharingConsent] = useState(false);
  const [adultAttested, setAdultAttested] = useState(false);
  const [documentConsent, setDocumentConsent] = useState(false);
  const [documentId, setDocumentId] = useState(initialDocumentId ?? documents[0]?.id ?? '');
  const [prompt, setPrompt] = useState('');
  const [loadedDraftKey, setLoadedDraftKey] = useState<string | null>(null);
  const [answers, setAnswers] = useState<Awaited<ReturnType<typeof loadStudyDocumentAnswers>>>([]);
  const [busy, setBusy] = useState(false);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const pending = useRef<{ signature: string; requestId: string } | null>(null);
  const studyDocuments = useMemo(() => documents.filter((document) => document.module_id === 'study'), [documents]);
  const selectedDocument = studyDocuments.find((document) => document.id === documentId) ?? studyDocuments[0];
  const selectedDocumentId = selectedDocument?.id ?? '';
  const draftKey = profileId ? `bloom.study-document-help-draft.v1:${profileId}` : null;
  const source = useRef(0);
  const aiReady = Boolean(preferences?.sharing_consent && (childProfile
    ? preferences.parent_enabled && preferences.parent_sharing_consent && preferences.minor_eligible_attested
    : preferences.adult_attested));
  const documentReady = Boolean(preferences?.document_sharing_consent && (childProfile
    ? preferences.document_parent_enabled && preferences.document_parent_sharing_consent && preferences.document_minor_eligible_attested
    : preferences.document_adult_attested));

  useEffect(() => {
    let active = true;
    if (readOnly || !draftKey) return () => { active = false; };
    void AsyncStorage.getItem(draftKey).then((raw) => {
      if (!active) return;
      if (raw && raw.length <= 2500) {
        try {
          const saved: unknown = JSON.parse(raw);
          if (saved && typeof saved === 'object' && 'version' in saved && saved.version === 1) {
            const value = saved as Record<string, unknown>;
            if (typeof value.prompt === 'string' && value.prompt.length <= 2000) setPrompt(value.prompt);
            if (typeof value.documentId === 'string' && studyDocuments.some((document) => document.id === value.documentId)) setDocumentId(value.documentId);
          }
        } catch { /* Ignore an unreadable local document-help draft. */ }
      }
      setLoadedDraftKey(draftKey);
    }).catch(() => { if (active) setLoadedDraftKey(draftKey); });
    return () => { active = false; };
  }, [draftKey, readOnly, studyDocuments]);

  useEffect(() => {
    if (readOnly || !draftKey || loadedDraftKey !== draftKey) return;
    if (!prompt) {
      void AsyncStorage.removeItem(draftKey).catch(() => undefined);
      return;
    }
    void AsyncStorage.setItem(draftKey, JSON.stringify({ version: 1, documentId: selectedDocumentId, prompt })).catch(() => undefined);
  }, [draftKey, loadedDraftKey, prompt, readOnly, selectedDocumentId]);

  const refreshPreferences = useCallback(async () => {
    if (!profileId) { setPreferences(null); setLoading(false); return; }
    try {
      const result = await loadGrowthAiPreferences(profileId, 'study');
      setPreferences(result);
      setSharingConsent(result?.sharing_consent ?? false);
      setAdultAttested(result?.adult_attested ?? false);
      setDocumentConsent(result?.document_sharing_consent ?? false);
      setError(null);
    } catch { setError('Could not load Study document privacy settings.'); }
    finally { setLoading(false); }
  }, [profileId]);
  useFocusEffect(useCallback(() => { void refreshPreferences(); }, [refreshPreferences]));

  useFocusEffect(useCallback(() => {
    const request = ++source.current;
    if (!selectedDocumentId) { setAnswers([]); return () => { source.current += 1; }; }
    void loadStudyDocumentAnswers(selectedDocumentId).then((result) => {
      if (request === source.current) { setAnswers(result); setError(null); }
    }).catch(() => {
      if (request === source.current) setError('Could not load this document’s private answer history.');
    });
    return () => { source.current += 1; };
  }, [selectedDocumentId]));

  async function saveConsent() {
    setBusy(true); setError(null); setNotice(null);
    try {
      await saveGrowthAiPreferences('study', sharingConsent, childProfile ? false : adultAttested);
      await setStudyDocumentAiConsent(documentConsent, childProfile ? false : adultAttested);
      await refreshPreferences();
      setNotice('Study document privacy settings saved.');
    } catch { setError(childProfile
      ? 'Could not save consent. Ask a parent to enable and approve the Study AI features in Family Space.'
      : 'Could not save consent. Adult eligibility and explicit document consent are required.'); }
    finally { setBusy(false); }
  }

  async function ask() {
    if (!selectedDocument || !prompt.trim() || !aiReady || !documentReady) { setError('Complete the required Study and document consent, then add a question.'); return; }
    const signature = JSON.stringify([selectedDocument.id, prompt.trim()]);
    if (pending.current?.signature !== signature) pending.current = { signature, requestId: randomUUID() };
    setBusy(true); setError(null); setNotice(null);
    try {
      const result = await requestStudyDocumentHelp(pending.current.requestId, selectedDocument.id, prompt.trim());
      pending.current = null; setPrompt('');
      setNotice('Source-aware answer saved in your private Study history.');
      const savedAnswer = { id: result.id, question: prompt.trim(), answer: result.answer, uncertainty: result.uncertainty,
        citations: result.citations, created_at: new Date().toISOString() };
      setAnswers((current) => [savedAnswer, ...current]); onSaved();
      try { setAnswers(await loadStudyDocumentAnswers(selectedDocument.id)); }
      catch { setNotice('Your answer was saved. The full history could not refresh yet.'); }
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Could not answer this question from the document. The question remains here so you can retry.');
    } finally { setBusy(false); }
  }

  return <Panel>
    <Eyebrow>Ask about your Study documents</Eyebrow>
    <Body>Bloom sends only your question and relevant text excerpts to its approved AI provider. Answers include checked citations; scanned PDFs are not supported. You can delete each document and its answers.</Body>
    {!profileId && <Body>Your active profile is unavailable.</Body>}
    {loading && <ActivityIndicator />}
    {childProfile ? <>
      <View style={sharedStyles.row}><View style={sharedStyles.grow}><Label>I agree to send my Study question to Bloom AI</Label><Body>Parent approval and eligibility are required too.</Body></View>
        <Switch accessibilityLabel="Consent to Study AI questions" value={sharingConsent} disabled={busy || readOnly || loading} onValueChange={setSharingConsent} trackColor={{ true: theme.colors.action }} /></View>
      <View style={sharedStyles.row}><View style={sharedStyles.grow}><Label>Allow relevant document excerpts</Label><Body>Only passages related to your question are sent for a cited answer.</Body></View>
        <Switch accessibilityLabel="Consent to source-aware document help" value={documentConsent} disabled={busy || readOnly || loading} onValueChange={setDocumentConsent} trackColor={{ true: theme.colors.action }} /></View>
      <Body>Document sharing: {documentReady ? 'Parent approved and eligible.' : 'Ask your parent to review document-help consent in Family Space.'}</Body>
    </> : <>
      <View style={sharedStyles.row}><View style={sharedStyles.grow}><Label>Allow Study AI questions</Label><Body>This consent also enables the Study tutor service.</Body></View>
        <Switch accessibilityLabel="Consent to Study AI questions" value={sharingConsent} disabled={busy || readOnly || loading} onValueChange={setSharingConsent} trackColor={{ true: theme.colors.action }} /></View>
      <View style={sharedStyles.row}><View style={sharedStyles.grow}><Label>Allow document excerpts for source-aware answers</Label><Body>Only excerpts related to your question are sent.</Body></View>
        <Switch accessibilityLabel="Consent to source-aware document help" value={documentConsent} disabled={busy || readOnly || loading} onValueChange={setDocumentConsent} trackColor={{ true: theme.colors.action }} /></View>
      <View style={sharedStyles.row}><View style={sharedStyles.grow}><Label>Adult under local law</Label><Body>Required before document help can be enabled.</Body></View>
        <Switch accessibilityLabel="Confirm adult eligibility for document help" value={adultAttested} disabled={busy || readOnly || loading} onValueChange={setAdultAttested} trackColor={{ true: theme.colors.action }} /></View>
    </>}
    <Button label={childProfile ? 'Save my Study privacy choices' : 'Save Study document consent'} variant="secondary"
      onPress={() => void saveConsent()} busy={busy} disabled={busy || readOnly || loading} />
    {studyDocuments.length === 0 ? <Body>Upload a private Study PDF or DOCX above before asking a question.</Body> : <>
      <View style={styles.choiceRow}>{studyDocuments.map((document) => <Button key={document.id}
        label={`${selectedDocumentId === document.id ? '✓ ' : ''}${document.title}`} variant="tertiary" disabled={busy || readOnly}
        onPress={() => setDocumentId(document.id)} />)}</View>
      <Field label="Question about the document" value={readOnly ? '' : prompt} onChangeText={setPrompt} maxLength={2000} multiline editable={!busy && !readOnly} />
      <Button label="Ask with cited sources" onPress={() => void ask()} busy={busy}
        disabled={busy || readOnly || !selectedDocument || !prompt.trim() || !aiReady || !documentReady} />
    </>}
    {!aiReady && <Body>Study AI consent and eligibility must be complete before a request can be sent.</Body>}
    {selectedDocument && answers.map((answer) => <View key={answer.id} style={sharedStyles.column}>
      <Label>{answer.question}</Label><Body>{answer.answer}</Body><Body>Uncertainty: {answer.uncertainty}</Body>
      {answer.citations.map((citation, index) => <View key={`${answer.id}:${index}`} style={sharedStyles.column}>
        <Label>{citation.reference}</Label><Body>“{citation.quote}”</Body>
      </View>)}
    </View>)}
    {error && <ErrorText>{error}</ErrorText>}{notice && <Body>{notice}</Body>}
  </Panel>;
}

const styles = StyleSheet.create({ choiceRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 6 } });
