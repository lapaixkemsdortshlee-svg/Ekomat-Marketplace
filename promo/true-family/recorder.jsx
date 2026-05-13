// recorder.jsx — Frame-by-frame video exporter
// Captures the True Family promo at exact 1080x1920, 30fps
// Renders each frame via html-to-image, feeds MediaRecorder via canvas.captureStream

// ── Pre-fetch Google Fonts and inline as data URLs ─────────────────────────
// html-to-image can't read cross-origin <link> stylesheets via document.styleSheets,
// so we fetch them ourselves (Google Fonts allows CORS) and inline the font binaries.
async function buildFontEmbedCSS() {
  const linkEls = [...document.querySelectorAll('link[rel="stylesheet"]')]
    .filter(l => l.href.includes('fonts.googleapis.com'));
  let combined = '';
  for (const link of linkEls) {
    try {
      const res = await fetch(link.href);
      let css = await res.text();
      const urlRegex = /url\((https:\/\/fonts\.gstatic\.com\/[^)]+)\)/g;
      const urls = [...new Set([...css.matchAll(urlRegex)].map(m => m[1]))];
      for (const url of urls) {
        try {
          const fontRes = await fetch(url);
          const blob = await fontRes.blob();
          const dataUrl = await new Promise((resolve, reject) => {
            const reader = new FileReader();
            reader.onload = () => resolve(reader.result);
            reader.onerror = reject;
            reader.readAsDataURL(blob);
          });
          css = css.split(url).join(dataUrl);
        } catch (e) {
          console.warn('Font inline failed:', url, e);
        }
      }
      combined += css + '\n';
    } catch (e) {
      console.warn('CSS fetch failed:', link.href, e);
    }
  }
  return combined;
}

function ExposeStageControls() {
  const ctx = useTimeline();
  React.useEffect(() => {
    window.__stage = {
      setTime: ctx.setTime,
      setPlaying: ctx.setPlaying,
      duration: ctx.duration,
    };
  }, [ctx.setTime, ctx.setPlaying, ctx.duration]);
  return null;
}

function Recorder({
  duration = 30,
  fps = 30,
  width = 1080,
  height = 1920,
  targetSelector = '[data-stage-content]',
  filename = 'true-family-pvc-promo',
}) {
  const [state, setState] = React.useState('idle'); // idle, preparing, recording, encoding, done, error
  const [progress, setProgress] = React.useState(0);
  const [downloadUrl, setDownloadUrl] = React.useState(null);
  const [errorMsg, setErrorMsg] = React.useState('');
  const cancelRef = React.useRef(false);

  const start = async () => {
    cancelRef.current = false;
    setState('preparing');
    setProgress(0);
    setDownloadUrl(null);
    setErrorMsg('');

    try {
      if (typeof htmlToImage === 'undefined') {
        throw new Error('Bibliyotèk html-to-image pa chaje. Tcheke koneksyon entènèt ou.');
      }
      if (!window.__stage) {
        throw new Error('Stage pa pare. Tann yon segond epi eseye ankò.');
      }

      // Pause playback, reset to t=0
      window.__stage.setPlaying(false);
      window.__stage.setTime(0);

      // Find target
      const targetEl = document.querySelector(targetSelector);
      if (!targetEl) throw new Error('Pa jwenn elemán videyo a.');

      // Wait for fonts to load
      if (document.fonts && document.fonts.ready) {
        await document.fonts.ready;
      }

      // Pre-fetch Google Fonts CSS + binaries (CORS-safe inline)
      const fontEmbedCSS = await buildFontEmbedCSS();

      // Skip the SVG grain filters to speed up rendering (subtle effect, won't be missed)
      const filterFn = (node) => {
        if (node && node.tagName === 'svg' && node.querySelector && node.querySelector('feTurbulence')) return false;
        return true;
      };

      const renderOpts = {
        width, height, pixelRatio: 1,
        cacheBust: false,
        skipFonts: true, // we provide fontEmbedCSS instead
        fontEmbedCSS,
        filter: filterFn,
      };

      // Wait a bit, then pre-warm with one render
      await new Promise(r => setTimeout(r, 300));
      await htmlToImage.toCanvas(targetEl, renderOpts);

      // Build recording canvas
      const canvas = document.createElement('canvas');
      canvas.width = width;
      canvas.height = height;
      const ctx = canvas.getContext('2d', { alpha: false });
      ctx.fillStyle = '#061230';
      ctx.fillRect(0, 0, width, height);

      const stream = canvas.captureStream(0); // manual frame mode
      const track = stream.getVideoTracks()[0];

      const mimeOptions = [
        'video/webm;codecs=vp9,opus',
        'video/webm;codecs=vp9',
        'video/webm;codecs=vp8',
        'video/webm',
      ];
      const mime = mimeOptions.find(m => MediaRecorder.isTypeSupported(m));
      if (!mime) throw new Error('Navigatè a pa sipòte ankodaj videyo.');

      const recorder = new MediaRecorder(stream, {
        mimeType: mime,
        videoBitsPerSecond: 10_000_000,
      });
      const chunks = [];
      recorder.ondataavailable = (e) => { if (e.data.size > 0) chunks.push(e.data); };

      await new Promise(resolve => {
        recorder.onstart = resolve;
        recorder.start();
      });

      setState('recording');

      const totalFrames = Math.ceil(duration * fps);
      for (let i = 0; i < totalFrames; i++) {
        if (cancelRef.current) {
          try { recorder.stop(); } catch {}
          setState('idle');
          return;
        }

        const t = i / fps;
        window.__stage.setTime(t);

        // Wait for React to commit + paint
        await new Promise(r => requestAnimationFrame(() => requestAnimationFrame(r)));

        try {
          const frameCanvas = await htmlToImage.toCanvas(targetEl, renderOpts);
          ctx.drawImage(frameCanvas, 0, 0, width, height);
        } catch (e) {
          // Skip bad frame but keep going
          console.warn(`Frame ${i} (t=${t.toFixed(2)}) failed:`, e);
        }

        track.requestFrame();
        setProgress((i + 1) / totalFrames);
      }

      setState('encoding');
      await new Promise(r => setTimeout(r, 300));
      recorder.stop();
      await new Promise(r => { recorder.onstop = r; });

      const blob = new Blob(chunks, { type: 'video/webm' });
      const url = URL.createObjectURL(blob);
      setDownloadUrl(url);
      setState('done');
    } catch (err) {
      console.error('Recording error:', err);
      setErrorMsg(err.message || String(err));
      setState('error');
    }
  };

  const cancel = () => { cancelRef.current = true; };
  const reset = () => {
    if (downloadUrl) URL.revokeObjectURL(downloadUrl);
    setDownloadUrl(null);
    setState('idle');
  };

  // ── Idle button ─────────────────────────────────────────────────────────
  if (state === 'idle') {
    return (
      <button onClick={start} style={{
        position: 'fixed', top: 16, right: 16, zIndex: 9999,
        padding: '12px 20px',
        background: 'linear-gradient(180deg, #e7c478, #d4a84b)',
        color: '#061230',
        border: 'none',
        borderRadius: 10,
        fontFamily: "'Inter', system-ui, sans-serif",
        fontSize: 13, fontWeight: 800,
        letterSpacing: '0.12em',
        cursor: 'pointer',
        boxShadow: '0 6px 20px rgba(0,0,0,0.5), 0 0 0 1px rgba(212,168,75,0.4)',
        display: 'flex', alignItems: 'center', gap: 10,
      }}
        onMouseEnter={e => e.currentTarget.style.transform = 'translateY(-1px)'}
        onMouseLeave={e => e.currentTarget.style.transform = 'translateY(0)'}
      >
        <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
          <path d="M7 1v9M3 6l4 4 4-4M2 12h10" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
        </svg>
        TELECHAJE VIDEYO
      </button>
    );
  }

  // ── Progress / status overlay ───────────────────────────────────────────
  return (
    <div style={{
      position: 'fixed', inset: 0, zIndex: 10000,
      background: 'rgba(6, 18, 48, 0.94)',
      backdropFilter: 'blur(12px)',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      fontFamily: "'Inter', system-ui, sans-serif",
      color: '#fff',
      padding: 20,
    }}>
      <div style={{
        padding: '40px 48px',
        background: 'rgba(255,255,255,0.04)',
        border: '1px solid rgba(255,255,255,0.1)',
        borderRadius: 16,
        maxWidth: 520, width: '100%',
        textAlign: 'center',
      }}>
        {state === 'preparing' && (
          <div>
            <Spinner/>
            <div style={{ fontSize: 20, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>
              Pwepare ekspòtasyon...
            </div>
            <div style={{ fontSize: 13, opacity: 0.6 }}>Chaje font ak imaj yo</div>
          </div>
        )}

        {state === 'recording' && (
          <div>
            <div style={{
              fontFamily: "'JetBrains Mono', monospace",
              fontSize: 12, letterSpacing: '0.3em',
              color: '#d4a84b', marginBottom: 16,
            }}>
              ● ANREJISTREMAN AN KOU
            </div>

            <div style={{
              fontSize: 64, fontWeight: 800,
              fontFamily: "'JetBrains Mono', monospace",
              letterSpacing: '-0.02em', marginBottom: 12,
            }}>
              {Math.round(progress * 100)}<span style={{ fontSize: 28, opacity: 0.5 }}>%</span>
            </div>

            <div style={{
              width: '100%', height: 6,
              background: 'rgba(255,255,255,0.08)',
              borderRadius: 6, overflow: 'hidden',
              marginBottom: 32,
            }}>
              <div style={{
                width: `${progress * 100}%`, height: '100%',
                background: 'linear-gradient(90deg, #d4a84b, #e7c478)',
                transition: 'width 0.15s ease-out',
                boxShadow: '0 0 12px rgba(212,168,75,0.6)',
              }}/>
            </div>

            <div style={{ fontSize: 13, opacity: 0.55, lineHeight: 1.7 }}>
              Tanpri pa fèmen paj la oswa chanje tab.<br/>
              <span style={{ color: '#d4a84b' }}>Ekspòtasyon an pran apeprè 2-4 minit.</span>
            </div>

            <button onClick={cancel} style={{
              marginTop: 28, padding: '10px 20px',
              background: 'transparent', color: 'rgba(255,255,255,0.6)',
              border: '1px solid rgba(255,255,255,0.18)', borderRadius: 8,
              cursor: 'pointer', fontSize: 12, fontWeight: 600,
              letterSpacing: '0.1em',
            }}>ANILE</button>
          </div>
        )}

        {state === 'encoding' && (
          <div>
            <Spinner/>
            <div style={{ fontSize: 20, fontWeight: 600, marginTop: 24, marginBottom: 8 }}>
              Finalize fichye videyo a...
            </div>
            <div style={{ fontSize: 13, opacity: 0.6 }}>Ankod ladènye etap la</div>
          </div>
        )}

        {state === 'done' && downloadUrl && (
          <div>
            <div style={{
              width: 64, height: 64, borderRadius: 64,
              background: '#d4a84b', color: '#061230',
              display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
              marginBottom: 20,
            }}>
              <svg width="28" height="28" viewBox="0 0 28 28" fill="none">
                <path d="M6 14l5 5 11-11" stroke="currentColor" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </div>
            <div style={{ fontSize: 24, fontWeight: 700, marginBottom: 8 }}>
              Videyo a pare!
            </div>
            <div style={{ fontSize: 13, opacity: 0.55, marginBottom: 28 }}>
              1080×1920 · 30 segond · WebM
            </div>

            <a href={downloadUrl} download={filename + '.webm'} style={{
              display: 'inline-flex', alignItems: 'center', gap: 10,
              padding: '16px 32px',
              background: 'linear-gradient(180deg, #e7c478, #d4a84b)',
              color: '#061230', borderRadius: 10,
              fontWeight: 800, fontSize: 14, letterSpacing: '0.1em',
              textDecoration: 'none',
              boxShadow: '0 8px 28px rgba(212,168,75,0.4)',
            }}>
              <svg width="14" height="14" viewBox="0 0 14 14" fill="none">
                <path d="M7 1v9M3 6l4 4 4-4M2 12h10" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
              TELECHAJE FICHYE A
            </a>

            <div style={{
              marginTop: 28, padding: 20,
              background: 'rgba(212,168,75,0.08)',
              border: '1px solid rgba(212,168,75,0.2)',
              borderRadius: 10,
              fontSize: 12, opacity: 0.85, lineHeight: 1.7,
              textAlign: 'left',
            }}>
              <strong style={{ color: '#d4a84b', display: 'block', marginBottom: 8, letterSpacing: '0.1em' }}>
                💡 POU PATAJE
              </strong>
              <div style={{ marginBottom: 6 }}>
                <strong>WhatsApp:</strong> Atache fichye a dirèkteman — WhatsApp aksepte WebM.
              </div>
              <div style={{ marginBottom: 6 }}>
                <strong>Facebook / Instagram / TikTok:</strong> Tout aksepte WebM tou.
              </div>
              <div>
                <strong>Si gen pwoblèm:</strong> konvèti l an .mp4 nan{' '}
                <span style={{ color: '#d4a84b' }}>cloudconvert.com</span> oswa{' '}
                <span style={{ color: '#d4a84b' }}>ezgif.com/webm-to-mp4</span>
              </div>
            </div>

            <button onClick={reset} style={{
              marginTop: 20, padding: '10px 20px',
              background: 'transparent', color: 'rgba(255,255,255,0.5)',
              border: '1px solid rgba(255,255,255,0.15)', borderRadius: 8,
              cursor: 'pointer', fontSize: 12, fontWeight: 600,
              letterSpacing: '0.1em',
            }}>FÈMEN</button>
          </div>
        )}

        {state === 'error' && (
          <div>
            <div style={{
              width: 64, height: 64, borderRadius: 64,
              background: '#ff6b6b', color: '#fff',
              display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
              marginBottom: 20, fontSize: 32, fontWeight: 700,
            }}>!</div>
            <div style={{ fontSize: 22, fontWeight: 700, marginBottom: 12 }}>
              Yon pwoblèm rive
            </div>
            <div style={{
              fontSize: 13, opacity: 0.7, marginBottom: 24,
              padding: 16, background: 'rgba(255,107,107,0.08)',
              border: '1px solid rgba(255,107,107,0.2)', borderRadius: 8,
              fontFamily: "'JetBrains Mono', monospace",
            }}>
              {errorMsg}
            </div>
            <button onClick={reset} style={{
              padding: '12px 24px',
              background: '#d4a84b', color: '#061230',
              border: 'none', borderRadius: 8, cursor: 'pointer',
              fontSize: 13, fontWeight: 700, letterSpacing: '0.1em',
            }}>ESEYE ANKÒ</button>
          </div>
        )}
      </div>
    </div>
  );
}

function Spinner() {
  return (
    <div style={{
      display: 'inline-block', width: 48, height: 48,
      border: '3px solid rgba(255,255,255,0.1)',
      borderTopColor: '#d4a84b',
      borderRadius: 48,
      animation: 'spin 0.9s linear infinite',
    }}/>
  );
}

// Inject keyframes
if (!document.getElementById('recorder-keyframes')) {
  const s = document.createElement('style');
  s.id = 'recorder-keyframes';
  s.textContent = `@keyframes spin { to { transform: rotate(360deg); } }`;
  document.head.appendChild(s);
}

Object.assign(window, { Recorder, ExposeStageControls });
