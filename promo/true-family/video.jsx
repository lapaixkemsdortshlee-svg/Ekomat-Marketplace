// True Family — Seminè Fòmasyon Tablo PVC
// 30-second vertical promotional video (1080x1920)

const NAVY = '#0a1c44';
const NAVY_DEEP = '#061230';
const BLUE = '#1f54d8';
const BLUE_LIGHT = '#7ea8ff';
const GOLD = '#d4a84b';
const GOLD_SOFT = '#e7c478';
const CREAM = '#f5f1e8';
const WHITE = '#ffffff';

const SERIF = "'Playfair Display', 'DM Serif Display', Georgia, serif";
const SANS = "'Inter', 'Helvetica Neue', system-ui, sans-serif";
const MONO = "'JetBrains Mono', ui-monospace, monospace";

// ── Helper: animated value with easing ─────────────────────────────────────
const lerp = (a, b, t) => a + (b - a) * t;
const clamp01 = (t) => Math.max(0, Math.min(1, t));

// ── Decorative components ──────────────────────────────────────────────────

function GrainOverlay({ opacity = 0.04 }) {
  return (
    <svg width="100%" height="100%" style={{
      position: 'absolute', inset: 0, pointerEvents: 'none',
      opacity, mixBlendMode: 'overlay',
    }}>
      <filter id="grain">
        <feTurbulence type="fractalNoise" baseFrequency="0.9" numOctaves="2" stitchTiles="stitch"/>
      </filter>
      <rect width="100%" height="100%" filter="url(#grain)"/>
    </svg>
  );
}

function VerticalBars({ color, count = 4, opacity = 0.06 }) {
  return (
    <div style={{
      position: 'absolute', inset: 0, pointerEvents: 'none',
      display: 'grid',
      gridTemplateColumns: `repeat(${count}, 1fr)`,
      opacity,
    }}>
      {Array.from({ length: count }).map((_, i) => (
        <div key={i} style={{
          borderRight: i < count - 1 ? `1px solid ${color}` : 'none',
        }}/>
      ))}
    </div>
  );
}

// ── Brand mark (small, top of frame) ───────────────────────────────────────
function BrandMark({ color = WHITE, accent = GOLD }) {
  return (
    <div style={{
      position: 'absolute', top: 56, left: 60,
      display: 'flex', alignItems: 'center', gap: 14,
      fontFamily: SANS, color, zIndex: 10,
    }}>
      <div style={{
        width: 14, height: 14, borderRadius: 14,
        background: accent,
        boxShadow: `0 0 24px ${accent}`,
      }}/>
      <div style={{
        fontSize: 22, fontWeight: 700, letterSpacing: '0.32em',
      }}>TRUE FAMILY</div>
    </div>
  );
}

function TimestampLabel({ color = 'rgba(255,255,255,0.45)' }) {
  const t = useTime();
  return (
    <div style={{
      position: 'absolute', top: 60, right: 60,
      fontFamily: MONO, fontSize: 18, color,
      letterSpacing: '0.1em', zIndex: 10,
    }}>
      {`00:${String(Math.floor(t)).padStart(2, '0')}`}
    </div>
  );
}

// ── SCENE 1 — HOOK (0-3s) ──────────────────────────────────────────────────
function SceneHook() {
  const { progress, localTime } = useSprite();

  // Gold line grows
  const lineW = animate({ from: 0, to: 480, start: 0.1, end: 0.9, ease: Easing.easeOutExpo })(localTime);

  // Words stagger in
  const word1Op = animate({ from: 0, to: 1, start: 0.15, end: 0.65 })(localTime);
  const word2Op = animate({ from: 0, to: 1, start: 0.45, end: 0.95 })(localTime);
  const word3Op = animate({ from: 0, to: 1, start: 0.75, end: 1.25 })(localTime);
  const word4Op = animate({ from: 0, to: 1, start: 1.05, end: 1.55 })(localTime);
  const word5Op = animate({ from: 0, to: 1, start: 1.35, end: 1.85 })(localTime);

  const word1Y = lerp(40, 0, Easing.easeOutCubic(word1Op));
  const word2Y = lerp(40, 0, Easing.easeOutCubic(word2Op));
  const word3Y = lerp(40, 0, Easing.easeOutCubic(word3Op));
  const word4Y = lerp(40, 0, Easing.easeOutCubic(word4Op));
  const word5Y = lerp(40, 0, Easing.easeOutCubic(word5Op));

  // Whole scene fade out
  const fadeOut = animate({ from: 1, to: 0, start: 2.7, end: 3.0 })(localTime);

  return (
    <div style={{
      position: 'absolute', inset: 0,
      background: `radial-gradient(ellipse at 30% 20%, #11286a 0%, ${NAVY} 45%, ${NAVY_DEEP} 100%)`,
      opacity: fadeOut,
    }}>
      <VerticalBars color={WHITE} count={6} opacity={0.04}/>
      <GrainOverlay opacity={0.06}/>

      {/* Gold accent line */}
      <div style={{
        position: 'absolute', top: 720, left: 60,
        height: 3, width: lineW,
        background: `linear-gradient(90deg, ${GOLD} 0%, ${GOLD_SOFT} 100%)`,
        boxShadow: `0 0 24px ${GOLD}66`,
      }}/>

      {/* Eyebrow */}
      <div style={{
        position: 'absolute', top: 660, left: 60,
        fontFamily: SANS, fontSize: 24, fontWeight: 500,
        letterSpacing: '0.4em', color: GOLD,
        opacity: animate({ from: 0, to: 1, start: 0, end: 0.5 })(localTime),
      }}>
        OPÒTINITE 2026
      </div>

      {/* Main hook — large serif */}
      <div style={{
        position: 'absolute', left: 60, top: 800,
        fontFamily: SERIF, fontWeight: 700,
        fontSize: 128, lineHeight: 1.15,
        color: WHITE, letterSpacing: '-0.02em',
      }}>
        <div style={{ opacity: word1Op, transform: `translateY(${word1Y}px)` }}>Fè</div>
        <div style={{ opacity: word2Op, transform: `translateY(${word2Y}px)` }}>talan w</div>
        <div style={{ opacity: word3Op, transform: `translateY(${word3Y}px)`, color: GOLD, fontStyle: 'italic' }}>tounen</div>
        <div style={{ opacity: word4Op, transform: `translateY(${word4Y}px)` }}>yon vrè</div>
        <div style={{ opacity: word5Op, transform: `translateY(${word5Y}px)` }}>biznis.</div>
      </div>
    </div>
  );
}

// ── SCENE 2 — TITLE REVEAL (3-7s) ──────────────────────────────────────────
function SceneTitle() {
  const { progress, localTime } = useSprite();

  // Curtain reveal — starts covering, slides up & off to reveal cream beneath
  const curtainProg = animate({ from: 0, to: 1, start: 0, end: 0.6, ease: Easing.easeInOutCubic })(localTime);
  const curtainOffset = curtainProg * 1920;

  const titleOp = animate({ from: 0, to: 1, start: 0.3, end: 1.0 })(localTime);
  const titleY = lerp(60, 0, Easing.easeOutCubic(titleOp));

  const subOp = animate({ from: 0, to: 1, start: 0.6, end: 1.3 })(localTime);
  const subY = lerp(40, 0, Easing.easeOutCubic(subOp));

  const tagOp = animate({ from: 0, to: 1, start: 0.9, end: 1.6 })(localTime);

  const lineProg = animate({ from: 0, to: 1, start: 1.2, end: 2.0, ease: Easing.easeOutExpo })(localTime);

  const fadeOut = animate({ from: 1, to: 0, start: 3.7, end: 4.0 })(localTime);

  return (
    <div style={{
      position: 'absolute', inset: 0,
      background: CREAM,
      opacity: fadeOut,
      overflow: 'hidden',
    }}>
      <GrainOverlay opacity={0.08}/>

      {/* Navy curtain that slides up to reveal */}
      <div style={{
        position: 'absolute', inset: 0,
        background: NAVY,
        transform: `translateY(${-curtainOffset}px)`,
      }}/>

      {/* Decorative corner ornaments */}
      <div style={{
        position: 'absolute', top: 80, right: 60,
        fontFamily: MONO, fontSize: 18,
        letterSpacing: '0.2em', color: NAVY,
        opacity: tagOp,
      }}>
        N° 01 / SEMINÈ
      </div>

      {/* Eyebrow */}
      <div style={{
        position: 'absolute', top: 480, left: 60,
        fontFamily: SANS, fontSize: 26, fontWeight: 600,
        letterSpacing: '0.4em', color: BLUE,
        opacity: titleOp,
      }}>
        SEMINÈ FÒMASYON · 2026
      </div>

      {/* Main title */}
      <div style={{
        position: 'absolute', left: 60, top: 560,
        width: 960,
        opacity: titleOp,
        transform: `translateY(${titleY}px)`,
      }}>
        <div style={{
          fontFamily: SERIF, fontWeight: 700,
          fontSize: 168, lineHeight: 0.95,
          color: NAVY, letterSpacing: '-0.03em',
        }}>
          Fabrikasyon
        </div>
        <div style={{
          fontFamily: SERIF, fontWeight: 700,
          fontSize: 168, lineHeight: 0.95,
          color: NAVY, letterSpacing: '-0.03em',
          fontStyle: 'italic',
          marginTop: 8,
        }}>
          Tablo <span style={{ color: BLUE }}>PVC</span>
        </div>
      </div>

      {/* Description */}
      <div style={{
        position: 'absolute', left: 60, top: 1040,
        width: 880,
        fontFamily: SANS, fontSize: 36, fontWeight: 400,
        lineHeight: 1.4, color: NAVY,
        opacity: subOp,
        transform: `translateY(${subY}px)`,
      }}>
        Yon fòmasyon pratik pou tout moun ki gen pasyon nan kreyativite, dekorasyon ak biznis vizyèl.
      </div>

      {/* Bottom horizontal line + label */}
      <div style={{
        position: 'absolute', bottom: 140, left: 60, right: 60,
        height: 2,
        background: NAVY,
        transformOrigin: 'left',
        transform: `scaleX(${lineProg})`,
      }}/>
      <div style={{
        position: 'absolute', bottom: 80, left: 60,
        fontFamily: MONO, fontSize: 22,
        letterSpacing: '0.2em', color: NAVY,
        opacity: tagOp,
      }}>
        TRUE FAMILY · HAITI
      </div>
      <div style={{
        position: 'absolute', bottom: 80, right: 60,
        fontFamily: MONO, fontSize: 22,
        letterSpacing: '0.2em', color: BLUE,
        opacity: tagOp,
      }}>
        30 · ME · 2026
      </div>
    </div>
  );
}

// ── SCENE 3 — PRODUCT SHOWCASE (7-13s) ─────────────────────────────────────
function SceneProduct() {
  const { progress, localTime } = useSprite();

  const imgOp = animate({ from: 0, to: 1, start: 0.0, end: 0.7 })(localTime);
  const imgScale = lerp(1.15, 1.0, Easing.easeOutCubic(imgOp)) * lerp(1.0, 1.08, progress);

  const sideTextOp = animate({ from: 0, to: 1, start: 0.5, end: 1.1 })(localTime);
  const sideTextX = lerp(-40, 0, Easing.easeOutCubic(sideTextOp));

  const stampOp = animate({ from: 0, to: 1, start: 1.5, end: 2.0 })(localTime);
  const stampRot = lerp(-15, 0, Easing.easeOutBack(stampOp));

  const captionOp = animate({ from: 0, to: 1, start: 2.5, end: 3.0 })(localTime);

  const fadeOut = animate({ from: 1, to: 0, start: 5.7, end: 6.0 })(localTime);

  return (
    <div style={{
      position: 'absolute', inset: 0,
      background: NAVY_DEEP,
      opacity: fadeOut,
      overflow: 'hidden',
    }}>
      <GrainOverlay opacity={0.08}/>

      {/* Eyebrow */}
      <div style={{
        position: 'absolute', top: 140, left: 60,
        fontFamily: MONO, fontSize: 22,
        letterSpacing: '0.3em', color: GOLD,
        opacity: sideTextOp,
        transform: `translateX(${sideTextX}px)`,
      }}>
        — SA W AP KREYE
      </div>

      {/* Product image */}
      <div style={{
        position: 'absolute', left: 60, top: 250,
        width: 960, height: 1200,
        overflow: 'hidden',
        borderRadius: 8,
        opacity: imgOp,
        boxShadow: `0 40px 80px rgba(0,0,0,0.5), 0 0 0 1px rgba(212,168,75,0.3)`,
      }}>
        <img src="assets/pvc-sample.jpg" alt="Tablo PVC"
          style={{
            width: '100%', height: '100%', objectFit: 'cover',
            transform: `scale(${imgScale})`,
            transformOrigin: 'center 40%',
          }}/>

        {/* Gradient overlay */}
        <div style={{
          position: 'absolute', inset: 0,
          background: `linear-gradient(180deg, transparent 50%, rgba(6,18,48,0.75) 100%)`,
        }}/>
      </div>

      {/* Diagonal stamp */}
      <div style={{
        position: 'absolute', top: 290, right: 60,
        width: 220, height: 220,
        borderRadius: 220,
        background: GOLD,
        display: 'flex', flexDirection: 'column',
        alignItems: 'center', justifyContent: 'center',
        fontFamily: SANS, color: NAVY_DEEP,
        textAlign: 'center', lineHeight: 1.1,
        opacity: stampOp,
        transform: `rotate(${stampRot}deg) scale(${stampOp})`,
        boxShadow: `0 12px 40px rgba(212,168,75,0.5)`,
      }}>
        <div style={{ fontSize: 18, fontWeight: 700, letterSpacing: '0.2em' }}>RIZILTA</div>
        <div style={{ fontSize: 64, fontWeight: 900, fontFamily: SERIF, lineHeight: 1 }}>100%</div>
        <div style={{ fontSize: 18, fontWeight: 700, letterSpacing: '0.2em' }}>PWO</div>
      </div>

      {/* Bottom caption block */}
      <div style={{
        position: 'absolute', left: 60, bottom: 140,
        width: 960,
        opacity: captionOp,
        transform: `translateY(${lerp(20, 0, Easing.easeOutCubic(captionOp))}px)`,
      }}>
        <div style={{
          fontFamily: SERIF, fontSize: 88, fontWeight: 700,
          color: WHITE, lineHeight: 1.0,
          letterSpacing: '-0.02em',
        }}>
          Sa elèv yo<br/>
          <span style={{ fontStyle: 'italic', color: GOLD }}>ap pwodwi.</span>
        </div>
      </div>
    </div>
  );
}

// ── SCENE 4 — TECHNIQUES (13-19s) ──────────────────────────────────────────
function SceneTechniques() {
  const { progress, localTime } = useSprite();

  const techs = [
    { num: '01', title: 'Konsepsyon Grafik', sub: 'Design ki kaptive je' },
    { num: '02', title: 'Teknik Dekoupaj', sub: 'Presizyon nan koupe' },
    { num: '03', title: 'Aplikasyon Vinyle', sub: 'Aplikasyon pwòp ak san defo' },
    { num: '04', title: 'Kolaj & Montaj', sub: 'Asanblaj pwofesyonèl' },
  ];

  const headerOp = animate({ from: 0, to: 1, start: 0, end: 0.5 })(localTime);
  const headerY = lerp(30, 0, Easing.easeOutCubic(headerOp));

  const fadeOut = animate({ from: 1, to: 0, start: 5.7, end: 6.0 })(localTime);

  return (
    <div style={{
      position: 'absolute', inset: 0,
      background: CREAM,
      opacity: fadeOut,
      overflow: 'hidden',
    }}>
      <GrainOverlay opacity={0.08}/>

      {/* Decorative diagonal stripes top */}
      <div style={{
        position: 'absolute', top: 0, left: 0, right: 0, height: 14,
        background: `repeating-linear-gradient(135deg, ${NAVY} 0 24px, ${BLUE} 24px 48px)`,
        opacity: animate({ from: 0, to: 1, start: 0, end: 0.4 })(localTime),
      }}/>

      {/* Eyebrow */}
      <div style={{
        position: 'absolute', top: 200, left: 60,
        fontFamily: MONO, fontSize: 22,
        letterSpacing: '0.3em', color: BLUE,
        opacity: headerOp,
        transform: `translateY(${headerY}px)`,
      }}>
        — 04 LADRÈS PRATIK
      </div>

      {/* Header */}
      <div style={{
        position: 'absolute', top: 260, left: 60, width: 960,
        opacity: headerOp,
        transform: `translateY(${headerY}px)`,
      }}>
        <div style={{
          fontFamily: SERIF, fontSize: 124, fontWeight: 700,
          color: NAVY, lineHeight: 0.95, letterSpacing: '-0.03em',
        }}>
          Sa w pral
        </div>
        <div style={{
          fontFamily: SERIF, fontSize: 124, fontWeight: 700,
          color: BLUE, lineHeight: 0.95, letterSpacing: '-0.03em',
          fontStyle: 'italic',
        }}>
          aprann.
        </div>
      </div>

      {/* Technique list */}
      <div style={{
        position: 'absolute', top: 700, left: 60, right: 60,
        display: 'flex', flexDirection: 'column', gap: 0,
      }}>
        {techs.map((tech, i) => {
          const stagger = 0.7 + i * 0.45;
          const op = animate({ from: 0, to: 1, start: stagger, end: stagger + 0.5 })(localTime);
          const x = lerp(-60, 0, Easing.easeOutCubic(op));

          return (
            <div key={i} style={{
              display: 'flex', alignItems: 'center', gap: 36,
              padding: '40px 0',
              borderBottom: i < techs.length - 1 ? `1px solid ${NAVY}22` : 'none',
              opacity: op,
              transform: `translateX(${x}px)`,
            }}>
              <div style={{
                fontFamily: MONO, fontSize: 28,
                color: BLUE, fontWeight: 500,
                width: 80, letterSpacing: '0.05em',
              }}>
                {tech.num}
              </div>
              <div style={{ flex: 1 }}>
                <div style={{
                  fontFamily: SERIF, fontSize: 64, fontWeight: 700,
                  color: NAVY, lineHeight: 1.05, letterSpacing: '-0.02em',
                }}>
                  {tech.title}
                </div>
                <div style={{
                  fontFamily: SANS, fontSize: 26, fontWeight: 400,
                  color: '#5a6680', marginTop: 6,
                }}>
                  {tech.sub}
                </div>
              </div>
              <svg width="36" height="36" viewBox="0 0 36 36" style={{ flexShrink: 0 }}>
                <circle cx="18" cy="18" r="17" stroke={BLUE} strokeWidth="1.5" fill="none"/>
                <path d="M14 12l6 6-6 6" stroke={BLUE} strokeWidth="2" fill="none" strokeLinecap="round" strokeLinejoin="round"/>
              </svg>
            </div>
          );
        })}
      </div>
    </div>
  );
}

// ── SCENE 5 — PRICE & BENEFITS (19-23s) ────────────────────────────────────
function ScenePrice() {
  const { progress, localTime } = useSprite();

  const headerOp = animate({ from: 0, to: 1, start: 0, end: 0.4 })(localTime);
  const headerY = lerp(30, 0, Easing.easeOutCubic(headerOp));

  const card1Op = animate({ from: 0, to: 1, start: 0.4, end: 0.9 })(localTime);
  const card1Y = lerp(40, 0, Easing.easeOutCubic(card1Op));

  const card2Op = animate({ from: 0, to: 1, start: 0.7, end: 1.2 })(localTime);
  const card2Y = lerp(40, 0, Easing.easeOutCubic(card2Op));

  const includeOp = animate({ from: 0, to: 1, start: 1.3, end: 1.8 })(localTime);
  const includeY = lerp(30, 0, Easing.easeOutCubic(includeOp));

  // Number counters
  const num1 = Math.round(lerp(0, 250, animate({ from: 0, to: 1, start: 0.5, end: 1.3, ease: Easing.easeOutCubic })(localTime)));
  const num2 = Math.round(lerp(0, 1500, animate({ from: 0, to: 1, start: 0.8, end: 1.6, ease: Easing.easeOutCubic })(localTime)));

  const fadeOut = animate({ from: 1, to: 0, start: 3.7, end: 4.0 })(localTime);

  return (
    <div style={{
      position: 'absolute', inset: 0,
      background: `linear-gradient(180deg, ${NAVY} 0%, ${NAVY_DEEP} 100%)`,
      opacity: fadeOut,
      overflow: 'hidden',
    }}>
      <VerticalBars color={WHITE} count={4} opacity={0.04}/>
      <GrainOverlay opacity={0.06}/>

      {/* Eyebrow */}
      <div style={{
        position: 'absolute', top: 200, left: 60,
        fontFamily: MONO, fontSize: 22,
        letterSpacing: '0.3em', color: GOLD,
        opacity: headerOp,
        transform: `translateY(${headerY}px)`,
      }}>
        — ENVESTISMAN
      </div>

      {/* Header */}
      <div style={{
        position: 'absolute', top: 260, left: 60, width: 960,
        opacity: headerOp,
        transform: `translateY(${headerY}px)`,
      }}>
        <div style={{
          fontFamily: SERIF, fontSize: 116, fontWeight: 700,
          color: WHITE, lineHeight: 0.95, letterSpacing: '-0.03em',
        }}>
          Yon valè ki
        </div>
        <div style={{
          fontFamily: SERIF, fontSize: 116, fontWeight: 700,
          color: GOLD, lineHeight: 0.95, letterSpacing: '-0.03em',
          fontStyle: 'italic',
        }}>
          tounen kapital.
        </div>
      </div>

      {/* Price cards */}
      <div style={{
        position: 'absolute', top: 660, left: 60, right: 60,
        display: 'flex', flexDirection: 'column', gap: 24,
      }}>
        {/* Card 1 — Enskripsyon */}
        <div style={{
          padding: '40px 48px',
          background: 'rgba(255,255,255,0.06)',
          border: `1px solid rgba(255,255,255,0.12)`,
          borderRadius: 4,
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          opacity: card1Op,
          transform: `translateY(${card1Y}px)`,
        }}>
          <div>
            <div style={{
              fontFamily: MONO, fontSize: 18,
              letterSpacing: '0.25em', color: BLUE_LIGHT,
              marginBottom: 8,
            }}>ENSKRIPSYON</div>
            <div style={{
              fontFamily: SERIF, fontSize: 36, color: WHITE,
              fontWeight: 500,
            }}>Frè dosye</div>
          </div>
          <div style={{
            fontFamily: SERIF, fontSize: 96, fontWeight: 700,
            color: WHITE, letterSpacing: '-0.02em',
          }}>
            {num1}<span style={{ fontSize: 36, color: GOLD, marginLeft: 8, fontFamily: SANS, fontWeight: 600 }}>Gdes</span>
          </div>
        </div>

        {/* Card 2 — Patisipasyon */}
        <div style={{
          padding: '48px',
          background: GOLD,
          border: `1px solid ${GOLD_SOFT}`,
          borderRadius: 4,
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          opacity: card2Op,
          transform: `translateY(${card2Y}px)`,
        }}>
          <div>
            <div style={{
              fontFamily: MONO, fontSize: 18,
              letterSpacing: '0.25em', color: NAVY_DEEP,
              marginBottom: 8,
            }}>PATISIPASYON KONPLÈ</div>
            <div style={{
              fontFamily: SERIF, fontSize: 36, color: NAVY_DEEP,
              fontWeight: 500,
            }}>Tout fòmasyon an</div>
          </div>
          <div style={{
            fontFamily: SERIF, fontSize: 108, fontWeight: 700,
            color: NAVY_DEEP, letterSpacing: '-0.02em',
          }}>
            {num2}<span style={{ fontSize: 36, color: NAVY, marginLeft: 8, fontFamily: SANS, fontWeight: 600 }}>Gdes</span>
          </div>
        </div>
      </div>

      {/* Included */}
      <div style={{
        position: 'absolute', bottom: 160, left: 60, right: 60,
        textAlign: 'center',
        opacity: includeOp,
        transform: `translateY(${includeY}px)`,
      }}>
        <div style={{
          fontFamily: MONO, fontSize: 20,
          letterSpacing: '0.3em', color: GOLD,
          marginBottom: 16,
        }}>+ ENKLI NAN FÒMASYON</div>
        <div style={{
          fontFamily: SERIF, fontSize: 52, color: WHITE,
          fontWeight: 500, lineHeight: 1.2,
        }}>
          Sètifika ofisyèl  ·  Tablo PVC pèsonèl
        </div>
      </div>
    </div>
  );
}

// ── SCENE 6 — DATE & LOCATION (23-27s) ─────────────────────────────────────
function SceneDate() {
  const { progress, localTime } = useSprite();

  const headerOp = animate({ from: 0, to: 1, start: 0, end: 0.4 })(localTime);
  const dateOp = animate({ from: 0, to: 1, start: 0.3, end: 0.9 })(localTime);
  const dateScale = lerp(0.85, 1, Easing.easeOutBack(dateOp));

  const locOp = animate({ from: 0, to: 1, start: 0.9, end: 1.5 })(localTime);
  const locY = lerp(30, 0, Easing.easeOutCubic(locOp));

  const mapOp = animate({ from: 0, to: 1, start: 1.2, end: 1.8 })(localTime);

  const fadeOut = animate({ from: 1, to: 0, start: 3.7, end: 4.0 })(localTime);

  return (
    <div style={{
      position: 'absolute', inset: 0,
      background: CREAM,
      opacity: fadeOut,
      overflow: 'hidden',
    }}>
      <GrainOverlay opacity={0.08}/>

      {/* Top bar */}
      <div style={{
        position: 'absolute', top: 0, left: 0, right: 0, height: 14,
        background: NAVY,
        opacity: headerOp,
      }}/>

      <div style={{
        position: 'absolute', top: 200, left: 60,
        fontFamily: MONO, fontSize: 22,
        letterSpacing: '0.3em', color: BLUE,
        opacity: headerOp,
      }}>
        — KIBOU & KI KOTE
      </div>

      {/* Date — huge */}
      <div style={{
        position: 'absolute', top: 320, left: 60, right: 60,
        textAlign: 'center',
        opacity: dateOp,
        transform: `scale(${dateScale})`,
        transformOrigin: 'center',
      }}>
        <div style={{
          fontFamily: SANS, fontSize: 32, fontWeight: 600,
          letterSpacing: '0.4em', color: NAVY, marginBottom: 24,
        }}>SAMDI</div>

        <div style={{
          fontFamily: SERIF, fontSize: 380, fontWeight: 900,
          color: NAVY, lineHeight: 0.85, letterSpacing: '-0.04em',
          paddingBottom: 40,
        }}>30</div>

        <div style={{
          fontFamily: SERIF, fontSize: 96, fontWeight: 700,
          color: BLUE, fontStyle: 'italic', marginTop: 24,
          lineHeight: 1, letterSpacing: '-0.02em',
        }}>Me 2026</div>
      </div>

      {/* Divider */}
      <div style={{
        position: 'absolute', top: 1240, left: 200, right: 200,
        height: 1, background: NAVY,
        opacity: locOp,
        transformOrigin: 'center',
        transform: `scaleX(${Easing.easeOutCubic(locOp)})`,
      }}/>

      {/* Location */}
      <div style={{
        position: 'absolute', top: 1300, left: 60, right: 60,
        textAlign: 'center',
        opacity: locOp,
        transform: `translateY(${locY}px)`,
      }}>
        <div style={{
          fontFamily: MONO, fontSize: 22,
          letterSpacing: '0.3em', color: BLUE, marginBottom: 16,
        }}>📍 LYE</div>
        <div style={{
          fontFamily: SERIF, fontSize: 60, fontWeight: 700,
          color: NAVY, lineHeight: 1.1, letterSpacing: '-0.02em',
        }}>
          Lycée Horatius Laventure
        </div>
        <div style={{
          fontFamily: SANS, fontSize: 36, fontWeight: 400,
          color: NAVY, marginTop: 16, opacity: 0.75,
        }}>
          Delmas 75 · Rue Faustin 1er
        </div>
      </div>

      {/* Bottom seal */}
      <div style={{
        position: 'absolute', bottom: 100, left: '50%',
        transform: `translateX(-50%) scale(${mapOp})`,
        opacity: mapOp,
        display: 'flex', alignItems: 'center', gap: 16,
        padding: '14px 32px',
        background: NAVY,
        borderRadius: 100,
      }}>
        <div style={{
          width: 8, height: 8, borderRadius: 8,
          background: GOLD,
        }}/>
        <div style={{
          fontFamily: MONO, fontSize: 20,
          letterSpacing: '0.3em', color: WHITE, fontWeight: 600,
        }}>PLAS LIMITE · RESERVE KOUNYE A</div>
      </div>
    </div>
  );
}

// ── SCENE 7 — CTA / BRAND FINALE (27-30s) ──────────────────────────────────
function SceneCTA() {
  const { progress, localTime } = useSprite();

  const logoOp = animate({ from: 0, to: 1, start: 0, end: 0.6, ease: Easing.easeOutBack })(localTime);
  const logoScale = logoOp;

  const tagOp = animate({ from: 0, to: 1, start: 0.5, end: 1.0 })(localTime);
  const tagY = lerp(20, 0, Easing.easeOutCubic(tagOp));

  const phonesOp = animate({ from: 0, to: 1, start: 1.0, end: 1.5 })(localTime);
  const phonesY = lerp(20, 0, Easing.easeOutCubic(phonesOp));

  const ctaOp = animate({ from: 0, to: 1, start: 1.5, end: 2.0 })(localTime);

  // Pulsing dot
  const pulseT = (localTime % 1.5) / 1.5;
  const pulseScale = 1 + 0.5 * Math.sin(pulseT * Math.PI);
  const pulseOp = 1 - pulseT;

  return (
    <div style={{
      position: 'absolute', inset: 0,
      background: `radial-gradient(ellipse at 50% 40%, #15306f 0%, ${NAVY} 50%, ${NAVY_DEEP} 100%)`,
      overflow: 'hidden',
    }}>
      <GrainOverlay opacity={0.06}/>

      {/* Brand mark center */}
      <div style={{
        position: 'absolute', top: 480, left: 0, right: 0,
        textAlign: 'center',
        opacity: logoOp,
        transform: `scale(${logoScale})`,
      }}>
        <div style={{
          position: 'relative', display: 'inline-block',
        }}>
          {/* Pulsing dot */}
          <div style={{
            position: 'absolute', left: '50%', top: -60,
            width: 16, height: 16, borderRadius: 16,
            background: GOLD,
            transform: `translateX(-50%) scale(${pulseScale})`,
            opacity: pulseOp,
            boxShadow: `0 0 32px ${GOLD}`,
          }}/>
          <div style={{
            position: 'absolute', left: '50%', top: -60,
            width: 16, height: 16, borderRadius: 16,
            background: GOLD,
            transform: `translateX(-50%)`,
            boxShadow: `0 0 24px ${GOLD}`,
          }}/>

          <div style={{
            fontFamily: SANS, fontSize: 28, fontWeight: 600,
            letterSpacing: '0.5em', color: GOLD, marginBottom: 32,
          }}>
            PREZANTE PA
          </div>

          <div style={{
            fontFamily: SERIF, fontSize: 184, fontWeight: 900,
            color: WHITE, lineHeight: 0.9,
            letterSpacing: '-0.03em',
          }}>
            TRUE
          </div>
          <div style={{
            fontFamily: SERIF, fontSize: 184, fontWeight: 900,
            color: GOLD, lineHeight: 0.9,
            letterSpacing: '-0.03em',
            fontStyle: 'italic',
          }}>
            FAMILY
          </div>
        </div>
      </div>

      {/* Tagline */}
      <div style={{
        position: 'absolute', top: 1180, left: 60, right: 60,
        textAlign: 'center',
        opacity: tagOp,
        transform: `translateY(${tagY}px)`,
      }}>
        <div style={{
          fontFamily: SERIF, fontSize: 44, fontWeight: 500,
          color: WHITE, fontStyle: 'italic', lineHeight: 1.3,
        }}>
          "Fè talan w tounen yon opòtinite pwofesyonèl."
        </div>
      </div>

      {/* Phone numbers */}
      <div style={{
        position: 'absolute', top: 1400, left: 60, right: 60,
        textAlign: 'center',
        opacity: phonesOp,
        transform: `translateY(${phonesY}px)`,
      }}>
        <div style={{
          fontFamily: MONO, fontSize: 22,
          letterSpacing: '0.3em', color: GOLD, marginBottom: 24,
        }}>📞 REZÈVASYON</div>

        <div style={{
          display: 'flex', justifyContent: 'center', gap: 40,
          fontFamily: SANS, fontSize: 44, fontWeight: 700,
          color: WHITE, letterSpacing: '0.02em',
        }}>
          <div>+509 3322-2932</div>
          <div style={{ color: 'rgba(255,255,255,0.3)' }}>/</div>
          <div>+509 3311-8773</div>
        </div>
      </div>

      {/* Bottom CTA bar */}
      <div style={{
        position: 'absolute', bottom: 80, left: 60, right: 60,
        padding: '32px',
        background: GOLD,
        borderRadius: 4,
        textAlign: 'center',
        opacity: ctaOp,
        transform: `scale(${lerp(0.95, 1, Easing.easeOutCubic(ctaOp))})`,
      }}>
        <div style={{
          fontFamily: SERIF, fontSize: 56, fontWeight: 700,
          color: NAVY_DEEP, lineHeight: 1, letterSpacing: '-0.02em',
        }}>
          Rezève Plas Ou — Kounye a.
        </div>
      </div>
    </div>
  );
}

// ── Timestamp updater for comment context ──────────────────────────────────
function TimestampScreenLabel() {
  const t = useTime();
  React.useEffect(() => {
    const sec = Math.floor(t);
    const el = document.querySelector('[data-video-root]');
    if (el) el.setAttribute('data-screen-label', `${String(sec).padStart(2, '0')}s — True Family Promo`);
  }, [Math.floor(t)]);
  return null;
}

// ── MAIN VIDEO ─────────────────────────────────────────────────────────────
function Video() {
  return (
    <div data-video-root style={{ width: '100%', height: '100%' }}>
      <Stage width={1080} height={1920} duration={30} background={NAVY_DEEP} persistKey="true-family-promo">
        <ExposeStageControls/>
        <div data-stage-content style={{ position: 'absolute', inset: 0, width: '100%', height: '100%' }}>
          <TimestampScreenLabel/>

          <Sprite start={0} end={3.0}><SceneHook/></Sprite>
          <Sprite start={3.0} end={7.0}><SceneTitle/></Sprite>
          <Sprite start={7.0} end={13.0}><SceneProduct/></Sprite>
          <Sprite start={13.0} end={19.0}><SceneTechniques/></Sprite>
          <Sprite start={19.0} end={23.0}><ScenePrice/></Sprite>
          <Sprite start={23.0} end={27.0}><SceneDate/></Sprite>
          <Sprite start={27.0} end={30.0}><SceneCTA/></Sprite>
        </div>
      </Stage>
    </div>
  );
}

function App() {
  return (
    <React.Fragment>
      <Video/>
      <Recorder duration={30} fps={30} width={1080} height={1920} targetSelector="[data-stage-content]"/>
    </React.Fragment>
  );
}

ReactDOM.createRoot(document.getElementById('root')).render(<App/>);
