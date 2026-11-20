import { Asset } from 'expo-asset';
import { File as ExpoFile } from 'expo-file-system';

// Expo Metro resolves this inert text bundle as an asset module identifier.
// eslint-disable-next-line @typescript-eslint/no-require-imports
const epubRendererAsset = require('../assets/epubjs.min.bundle') as number;
let epubRendererPromise: Promise<string> | null = null;

export type ReadingLocation = { cfi: string; percent: number };

export async function loadEpubRendererScript() {
  if (!epubRendererPromise) {
    epubRendererPromise = (async () => {
      const asset = Asset.fromModule(epubRendererAsset);
      await asset.downloadAsync();
      if (asset.localUri?.startsWith('file://')) return new ExpoFile(asset.localUri).text();
      const response = await fetch(asset.localUri ?? asset.uri);
      if (!response.ok) throw new Error('Could not load the bundled EPUB reader.');
      return response.text();
    })().catch((error) => {
      epubRendererPromise = null;
      throw error;
    });
  }
  return epubRendererPromise;
}

function jsonForScript(value: unknown) {
  return JSON.stringify(value).replace(/</g, '\\u003c').replace(/>/g, '\\u003e').replace(/&/g, '\\u0026');
}

function cssColor(value: string) {
  const color = value.trim();
  if (/^#[\da-f]{3,8}$/i.test(color)
    || /^rgba?\(\s*[\d.% ,/+-]+\)$/i.test(color)
    || /^hsla?\(\s*[\d.% ,/+-]+\)$/i.test(color)
    || color === 'transparent') return color;
  return '#ffffff';
}

export function buildReadingDocumentHtml(args: {
  format: 'pdf' | 'epub';
  sourceUrl: string;
  epubScript?: string;
  initialCfi?: string | null;
  initialPercent?: number;
  initialPage?: number | null;
  backgroundColor: string;
  textColor: string;
}) {
  const source = jsonForScript(args.sourceUrl);
  const background = cssColor(args.backgroundColor);
  const foreground = cssColor(args.textColor);
  if (args.format === 'pdf') {
    const page = Number.isInteger(args.initialPage) && Number(args.initialPage) > 0 ? `#page=${args.initialPage}` : '';
    const pdfUrl = jsonForScript(`${args.sourceUrl}${page}`);
    return `<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1"><style>
      html,body,#pdf{margin:0;width:100%;height:100%;overflow:hidden;background:${background};color:${foreground}}
      #pdf{border:0;display:block;width:100%;height:100%;background:${background}}
    </style></head><body><iframe id="pdf" title="Private PDF reader" src=${pdfUrl}></iframe></body></html>`;
  }

  if (!args.epubScript) throw new Error('The EPUB reader is unavailable.');
  const bundledScript = args.epubScript.replace(/<\/script/gi, '<\\/script');
  const initialCfi = jsonForScript(args.initialCfi ?? '');
  const initialPercent = Number.isFinite(args.initialPercent) ? Math.min(100, Math.max(0, Number(args.initialPercent))) : 0;
  return `<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no"><style>
    :root{color-scheme:light dark} *{box-sizing:border-box} html,body{margin:0;width:100%;height:100%;overflow:hidden;background:${background};color:${foreground}}
    body{font-family:system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
    #toolbar{height:56px;display:flex;align-items:center;justify-content:space-between;gap:8px;padding:6px 12px;border-bottom:1px solid #8885;background:${background};position:relative;z-index:2}
    #toolbar button,#contents summary{min-height:40px;padding:0 12px;border:1px solid #8888;border-radius:10px;background:transparent;color:inherit;font:inherit;cursor:pointer}
    #toolbar button:focus-visible,#contents summary:focus-visible{outline:3px solid #5879e8;outline-offset:2px}
    #reader-tools{display:flex;align-items:center;gap:6px}.nav-tools{display:flex;gap:6px}
    #contents{position:relative} #toc{position:absolute;right:0;top:46px;width:min(320px,85vw);max-height:min(65vh,520px);overflow:auto;padding:8px;border:1px solid #8888;border-radius:12px;background:${background};box-shadow:0 8px 28px #0003}
    #toc button{display:block;width:100%;height:auto;min-height:42px;text-align:left;white-space:normal;margin:2px 0}
    #viewer{height:calc(100dvh - 56px);width:100%;overflow:hidden;background:${background};color:${foreground};font-family:Georgia,"Times New Roman",serif}
    #status{position:absolute;left:50%;top:56px;transform:translateX(-50%);z-index:1;padding:4px 10px;border-radius:0 0 9px 9px;background:${background};font:12px system-ui,sans-serif;opacity:.75}
    @media(max-width:520px){#toolbar{padding:5px;gap:3px}#toolbar button,#contents summary{padding:0 8px}#reader-tools{gap:3px}}
  </style></head><body><header id="toolbar" aria-label="Reader controls">
    <div class="nav-tools"><button id="previous" type="button" aria-label="Previous page">‹</button><button id="next" type="button" aria-label="Next page">›</button></div>
    <div id="reader-tools"><button id="smaller" type="button" aria-label="Decrease text size">A−</button><button id="larger" type="button" aria-label="Increase text size">A+</button>
      <button id="theme" type="button" aria-label="Change reading theme">Sepia</button><details id="contents"><summary>Contents</summary><nav id="toc" aria-label="Table of contents"></nav></details></div>
  </header><div id="status" aria-live="polite">Opening book…</div><main id="viewer" aria-label="EPUB reading area"></main>
  <script>${bundledScript}</script><script>
    (function(){
      const source=${source}; const startCfi=${initialCfi}; const startPercent=${initialPercent};
      const status=document.getElementById('status'); const themes=[
        {name:'Light',background:'#ffffff',foreground:'#222222'},
        {name:'Sepia',background:'#f3ead7',foreground:'#3d3022'},
        {name:'Dark',background:'#17191e',foreground:'#e8e9ec'}
      ]; let themeIndex=0; let fontPercent=100;
      const send=(message)=>{ const value=JSON.stringify({source:'bloom-reader',...message});
        if(window.ReactNativeWebView){window.ReactNativeWebView.postMessage(value);}
        else {window.parent.postMessage(value,'*');}
      };
      try {
        if(typeof window.ePub!=='function') throw new Error('EPUB renderer did not load.');
        const book=window.ePub(source);
        const rendition=book.renderTo('viewer',{width:'100%',height:'100%',flow:'paginated',spread:'none'});
        const applyTheme=()=>{
          const value=themes[themeIndex]; document.body.style.background=value.background; document.body.style.color=value.foreground;
          document.getElementById('viewer').style.background=value.background; document.getElementById('viewer').style.color=value.foreground;
          rendition.themes.register('bloom-reader-theme',{body:{background:value.background,color:value.foreground}});
          rendition.themes.select('bloom-reader-theme');
          document.getElementById('theme').textContent=value.name;
          document.getElementById('theme').setAttribute('aria-label','Reading theme: '+value.name+'. Activate to change theme.');
        };
        document.getElementById('previous').addEventListener('click',()=>rendition.prev());
        document.getElementById('next').addEventListener('click',()=>rendition.next());
        document.getElementById('smaller').addEventListener('click',()=>{fontPercent=Math.max(70,fontPercent-10);rendition.themes.fontSize(fontPercent+'%');});
        document.getElementById('larger').addEventListener('click',()=>{fontPercent=Math.min(180,fontPercent+10);rendition.themes.fontSize(fontPercent+'%');});
        document.getElementById('theme').addEventListener('click',()=>{themeIndex=(themeIndex+1)%themes.length;applyTheme();});
        rendition.on('relocated',(location)=>{
          const cfi=location&&location.start&&location.start.cfi;
          if(!cfi) return;
          let fraction=Number(location.start.percentage);
          try { const value=book.locations.percentageFromCfi(cfi); if(Number.isFinite(value)) fraction=value; } catch (_) {}
          send({type:'location',cfi,percent:Math.min(100,Math.max(0,Math.round(fraction*1000)/10))});
        });
        book.ready.then(async()=>{
          applyTheme();
          const toc=document.getElementById('toc');
          book.loaded.navigation.then((navigation)=>{
            const addEntries=(entries,depth)=>entries.forEach((entry)=>{
              const button=document.createElement('button'); button.type='button'; button.textContent=('　'.repeat(Math.min(depth,4)))+(entry.label||'Untitled section');
              button.addEventListener('click',()=>{rendition.display(entry.href);document.getElementById('contents').open=false;}); toc.appendChild(button);
              if(entry.subitems&&entry.subitems.length)addEntries(entry.subitems,depth+1);
            });
            addEntries(navigation.toc||[],0);
            if(!toc.children.length){const empty=document.createElement('p');empty.textContent='No contents list is available for this book.';toc.appendChild(empty);}
          }).catch(()=>{const empty=document.createElement('p');empty.textContent='The contents list is unavailable.';toc.appendChild(empty);});
          if(startCfi) await rendition.display(startCfi);
          else if(startPercent>0){ await book.locations.generate(1000); await rendition.display(book.locations.cfiFromPercentage(startPercent/100)); }
          else await rendition.display();
          status.textContent='';
          book.locations.generate(1000).then(()=>{
            const current=rendition.currentLocation(); const cfi=current&&current.start&&current.start.cfi;
            if(cfi){const fraction=book.locations.percentageFromCfi(cfi);send({type:'location',cfi,percent:Math.round(fraction*1000)/10});}
          }).catch(()=>{});
        }).catch((error)=>{status.textContent='Could not open this book.';send({type:'error',message:String(error&&error.message||'Could not open this EPUB.')});});
      } catch(error){send({type:'error',message:String(error&&error.message||'Could not open this EPUB.')});}
    })();
  </script></body></html>`;
}

export function parseReaderMessage(value: string): ReadingLocation | { error: string } | null {
  try {
    const message = JSON.parse(value) as { source?: unknown; type?: unknown; cfi?: unknown; percent?: unknown; message?: unknown };
    if (message.source !== 'bloom-reader') return null;
    if (message.type === 'error') return { error: typeof message.message === 'string' ? message.message : 'Could not open this EPUB.' };
    const percent = Number(message.percent);
    if (message.type !== 'location' || typeof message.cfi !== 'string' || !Number.isFinite(percent)) return null;
    return { cfi: message.cfi, percent: Math.min(100, Math.max(0, percent)) };
  } catch {
    return null;
  }
}
