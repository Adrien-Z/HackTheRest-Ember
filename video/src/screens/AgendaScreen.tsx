import React from 'react';
import {Img, staticFile} from 'remotion';
import {Theme, SF, alpha} from '../theme';
import {NavBar, NightBackground, StatusBar, TabBar} from '../components/Phone';
import {
  ArrowUpDown,
  BedDouble,
  Info,
  MoonStars,
  MoonZzz,
  Rotate,
  Sunrise,
  Thermometer,
} from '../components/icons';

/** `PlanMetric` — a small icon + monospaced value in the plan banner. */
const PlanMetric: React.FC<{icon: React.ReactNode; value: string}> = ({icon, value}) => (
  <div style={{display: 'flex', alignItems: 'center', gap: 5, width: 64}}>
    {icon}
    <span
      style={{
        fontSize: 11,
        fontWeight: 600,
        color: Theme.secondaryText,
        fontVariantNumeric: 'tabular-nums',
      }}
    >
      {value}
    </span>
  </div>
);

// ── CircadianModel, ported from Ember/Algorithms/CircadianModel.swift ────────
const WAKE_CONTROL: [number, number][] = [
  [0.0, 0.35],
  [0.12, 0.7],
  [0.25, 0.88],
  [0.38, 0.74],
  [0.46, 0.52],
  [0.6, 0.74],
  [0.8, 0.84],
  [0.9, 0.58],
  [1.0, 0.28],
];

const lerpPoints = (f: number, pts: [number, number][]) => {
  const x = Math.min(Math.max(f, 0), 1);
  for (let i = 1; i < pts.length; i++) {
    if (x <= pts[i][0]) {
      const [x0, y0] = pts[i - 1];
      const [x1, y1] = pts[i];
      const t = (x - x0) / (x1 - x0);
      return y0 + (y1 - y0) * (t * t * (3 - 2 * t)); // smoothstep, as in the app
    }
  }
  return pts[pts.length - 1][1];
};

const WAKE_MIN = 405; // 06:45
const BED_MIN = 1370; // 22:50
const WW = (((BED_MIN - WAKE_MIN) % 1440) + 1440) % 1440;

export const alertness = (t: number) => {
  const sinceWake = (((t - WAKE_MIN) % 1440) + 1440) % 1440;
  if (sinceWake <= WW) return lerpPoints(sinceWake / WW, WAKE_CONTROL);
  const sinceBed = (((t - BED_MIN) % 1440) + 1440) % 1440;
  const sleepSpan = 1440 - WW;
  const g = sinceBed / Math.max(1, sleepSpan);
  const troughAt = (sleepSpan - 120) / sleepSpan;
  const dist = Math.abs(g - troughAt);
  return Math.max(0.03, 0.22 - 0.19 * (1 - Math.min(1, dist / 0.5)));
};

// ── Timeline geometry ───────────────────────────────────────────────────────
const ORIGIN = 360; // 06:00
const SPAN = 26 * 60; // through 08:00 next day
const PPM = 0.66;
const GUTTER = 42;
const RIBBON_W = 54;
const CANVAS_W = 369;
const LANE_X = GUTTER + 4;
const LANE_W = CANVAS_W - GUTTER - RIBBON_W - 12;
const RIBBON_X = CANVAS_W - RIBBON_W;
const TOTAL_H = SPAN * PPM;

const y = (min: number) => (min - ORIGIN) * PPM;
const hhmm = (m: number) => {
  const h = Math.floor((m % 1440) / 60);
  const mm = m % 60;
  return `${String(h).padStart(2, '0')}:${String(mm).padStart(2, '0')}`;
};

type Ev = {title: string; start: number; end: number; color: string};
const EVENTS: Ev[] = [
  {title: 'Standup', start: 9 * 60, end: 9 * 60 + 20, color: Theme.ember},
  {title: 'Design review', start: 10 * 60, end: 11 * 60 + 15, color: Theme.ember},
  {title: 'Lunch with Sam', start: 12 * 60 + 30, end: 13 * 60 + 15, color: Theme.mint},
  {title: '1:1 with Priya', start: 14 * 60, end: 14 * 60 + 45, color: Theme.ember},
  {title: 'Gym', start: 18 * 60 + 30, end: 19 * 60 + 30, color: Theme.amber},
  {title: 'Dinner', start: 20 * 60, end: 21 * 60, color: Theme.mint},
];

const MARKERS = [
  {min: WAKE_MIN + Math.round(WW * 0.25), color: Theme.amber, kind: 'peak' as const},
  {min: WAKE_MIN + Math.round(WW * 0.45), color: Theme.cool, kind: 'dip' as const},
  {min: WAKE_MIN + Math.round(WW * 0.8), color: Theme.amber, kind: 'bolt' as const},
  {min: BED_MIN - 120, color: Theme.ember, kind: 'moon' as const},
];

const MarkerGlyph: React.FC<{kind: string}> = ({kind}) => {
  if (kind === 'peak')
    return (
      <svg width="13" height="13" viewBox="0 0 24 24">
        <circle cx="12" cy="12" r="5" fill="#fff" />
        <g stroke="#fff" strokeWidth="2" strokeLinecap="round">
          <path d="M12 1.6v2.6M12 19.8v2.6M22.4 12h-2.6M4.2 12H1.6M19.4 4.6l-1.8 1.8M6.4 17.6l-1.8 1.8M19.4 19.4l-1.8-1.8M6.4 6.4 4.6 4.6" />
        </g>
      </svg>
    );
  if (kind === 'dip')
    return (
      <svg width="13" height="13" viewBox="0 0 24 24">
        <path d="M12 5v11M12 16l-4.5-4.5M12 16l4.5-4.5" stroke="#fff" strokeWidth="2.4" fill="none" strokeLinecap="round" strokeLinejoin="round" />
      </svg>
    );
  if (kind === 'bolt')
    return (
      <svg width="13" height="13" viewBox="0 0 24 24">
        <path d="M13.6 2 5.4 13.4h5.2L9.4 22l8.6-11.8h-5.4Z" fill="#fff" />
      </svg>
    );
  return (
    <svg width="13" height="13" viewBox="0 0 24 24">
      <path d="M15.6 3.2a8.4 8.4 0 1 0 5.6 9.9A6.8 6.8 0 0 1 15.6 3.2Z" fill="#fff" />
    </svg>
  );
};

/** The energy ribbon: filled alertness curve pinned to the right edge. */
const EnergyRibbon: React.FC<{draw: number}> = ({draw}) => {
  const pts: [number, number][] = [];
  for (let m = 0; m <= SPAN; m += 12) {
    const a = alertness((ORIGIN + m) % 1440);
    pts.push([RIBBON_X + RIBBON_W * (1 - a), m * PPM]);
  }
  const shown = Math.max(2, Math.round(pts.length * draw));
  const seg = pts.slice(0, shown);
  const line = seg.map((p, i) => `${i === 0 ? 'M' : 'L'}${p[0].toFixed(1)},${p[1].toFixed(1)}`).join(' ');
  const fill = `M${RIBBON_X + RIBBON_W},0 L${RIBBON_X + RIBBON_W},${seg[seg.length - 1][1].toFixed(1)} ${seg
    .slice()
    .reverse()
    .map((p) => `L${p[0].toFixed(1)},${p[1].toFixed(1)}`)
    .join(' ')} Z`;
  return (
    <svg
      width={CANVAS_W}
      height={TOTAL_H}
      style={{position: 'absolute', top: 0, left: 0, pointerEvents: 'none'}}
    >
      <defs>
        <linearGradient id="energyFill" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor={alpha(Theme.amber, 0.3)} />
          <stop offset="100%" stopColor={alpha(Theme.ember, 0.1)} />
        </linearGradient>
        <filter id="energyGlow" x="-50%" y="-10%" width="200%" height="120%">
          <feGaussianBlur stdDeviation="6" />
        </filter>
      </defs>
      <path d={fill} fill="url(#energyFill)" />
      <path d={line} stroke={alpha(Theme.amber, 0.5)} strokeWidth={5} fill="none" filter="url(#energyGlow)" />
      <path d={line} stroke={alpha(Theme.amber, 0.85)} strokeWidth={1.5} fill="none" />
      <text
        x={RIBBON_X + RIBBON_W - 7}
        y={22}
        fill={Theme.secondaryText}
        fontSize={8}
        fontWeight={700}
        letterSpacing={0.6}
        transform={`rotate(90, ${RIBBON_X + RIBBON_W - 7}, 22)`}
      >
        ENERGY
      </text>
    </svg>
  );
};

/**
 * `AgendaView` — day strip, plan banner, and the day canvas where the user's
 * calendar, the circadian energy ribbon, and EMBER's sleep + warming bands
 * share one timeline.
 */
export const AgendaScreen: React.FC<{
  /** 0-1 energy curve draw-in. */
  draw?: number;
  /** timeline scroll in points. */
  scroll?: number;
  /** minutes the plan has been dragged (snaps in 5s in the app). */
  dragMin?: number;
  /** 0-1 fade-in of the plan bands. */
  bands?: number;
  lifted?: boolean;
}> = ({draw = 1, scroll = 0, dragMin = 0, bands = 1, lifted = false}) => {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const dates = [12, 13, 14, 15, 16, 17, 18];
  const sel = 2;

  const warmStart = 1310 + dragMin; // 21:50
  const warmEnd = 1322 + dragMin;
  const bedT = BED_MIN + dragMin;
  const wakeT = 1440 + WAKE_MIN + dragMin;

  return (
    <div style={{position: 'absolute', inset: 0, fontFamily: SF}}>
      <NightBackground />

      {/* day strip */}
      <div
        style={{
          position: 'absolute',
          top: 103,
          left: 0,
          right: 0,
          display: 'flex',
          gap: 6,
          padding: '10px 12px 12px',
          zIndex: 20,
        }}
      >
        {days.map((d, i) => (
          <div
            key={d}
            style={{
              flex: 1,
              textAlign: 'center',
              padding: '6px 0 7px',
              borderRadius: 13,
              background: i === sel ? Theme.ember : 'rgba(255,255,255,0.06)',
            }}
          >
            <div
              style={{
                fontSize: 10,
                fontWeight: 600,
                color: i === sel ? 'rgba(255,255,255,0.85)' : Theme.tertiaryText,
              }}
            >
              {d.toUpperCase()}
            </div>
            <div style={{fontSize: 15, fontWeight: 700, marginTop: 1}}>{dates[i]}</div>
          </div>
        ))}
      </div>

      {/* PlanBanner: the user's own box, the night's headline, and its metrics */}
      <div
        style={{
          position: 'absolute',
          top: 172,
          left: 12,
          right: 12,
          zIndex: 20,
          display: 'flex',
          alignItems: 'flex-start',
          gap: 12,
          padding: 12,
          borderRadius: 20,
          background: 'rgba(28,31,43,0.96)',
          border: `1px solid ${Theme.hairline}`,
        }}
      >
        <Img
          src={staticFile('skins/moon_blue.png')}
          style={{width: 46, height: 52, objectFit: 'contain', flexShrink: 0}}
        />
        <div style={{flex: 1}}>
          <div style={{display: 'flex', alignItems: 'center'}}>
            <span style={{fontSize: 13.5, fontWeight: 600}}>A protected night</span>
            <div style={{flex: 1}} />
            <span
              style={{
                fontSize: 10,
                fontWeight: 700,
                letterSpacing: 0.4,
                color: Theme.mint,
                padding: '3px 8px',
                borderRadius: 100,
                background: alpha(Theme.mint, 0.18),
              }}
            >
              LOW SQUEEZE
            </span>
          </div>
          <div style={{fontSize: 11.5, color: Theme.secondaryText, marginTop: 5, lineHeight: 1.35}}>
            Gym at 18:30 raises your core temperature, so warm-up shifts later and
            the window still holds.
          </div>
          <div style={{display: 'flex', gap: 10, marginTop: 7, alignItems: 'center'}}>
            <PlanMetric icon={<BedDouble size={12} color={Theme.secondaryText} />} value={hhmm(bedT)} />
            <PlanMetric icon={<Sunrise size={12} color={Theme.secondaryText} />} value={hhmm(wakeT)} />
            <PlanMetric icon={<MoonZzz size={12} color={Theme.secondaryText} />} value="7h 55m" />
            <div style={{flex: 1}} />
            <Rotate size={13} color={Theme.secondaryText} />
          </div>
        </div>
      </div>

      {/* sleep climate badge, from the live forecast */}
      <div
        style={{
          position: 'absolute',
          top: 284,
          right: 16,
          zIndex: 25,
          display: 'flex',
          alignItems: 'center',
          gap: 5,
          padding: '5px 10px',
          borderRadius: 100,
          background: 'rgba(20,24,36,0.88)',
          border: `0.8px solid ${alpha(Theme.amber, 0.45)}`,
          boxShadow: `0 4px 8px ${alpha(Theme.amber, 0.18)}`,
          fontSize: 11,
          fontWeight: 700,
          color: Theme.amber,
        }}
      >
        <Thermometer size={12} color={Theme.amber} />
        Warm night
      </div>

      {/* day canvas */}
      <div
        style={{
          position: 'absolute',
          top: 272,
          left: 12,
          width: CANVAS_W,
          bottom: 96,
          overflow: 'hidden',
        }}
      >
        <div
          style={{
            position: 'absolute',
            top: 0,
            left: 0,
            width: CANVAS_W,
            height: TOTAL_H,
            transform: `translateY(${-scroll}px)`,
          }}
        >
          {/* hour rules */}
          {Array.from({length: 27}, (_, i) => ORIGIN + i * 60).map((m) => (
            <div key={m} style={{position: 'absolute', top: y(m), left: 0, right: 0}}>
              <div
                style={{
                  position: 'absolute',
                  left: 0,
                  top: -6,
                  width: GUTTER - 6,
                  textAlign: 'right',
                  fontSize: 10,
                  color: Theme.tertiaryText,
                  fontVariantNumeric: 'tabular-nums',
                }}
              >
                {hhmm(m)}
              </div>
              <div
                style={{
                  position: 'absolute',
                  left: GUTTER,
                  right: 0,
                  height: 1,
                  background: 'rgba(255,255,255,0.06)',
                }}
              />
            </div>
          ))}

          <EnergyRibbon draw={draw} />

          {/* midnight divider */}
          <div style={{position: 'absolute', top: y(1440), left: 0, right: 0}}>
            <div style={{position: 'absolute', left: 0, right: 0, height: 1, background: alpha(Theme.ember, 0.35)}} />
            <div
              style={{
                position: 'absolute',
                left: GUTTER + 4,
                top: -9,
                fontSize: 9.5,
                fontWeight: 700,
                color: Theme.ember,
                padding: '2px 8px',
                borderRadius: 100,
                background: Theme.bg,
                border: `0.5px solid ${alpha(Theme.ember, 0.4)}`,
              }}
            >
              Thu, Jun 15
            </div>
          </div>

          {/* events */}
          {EVENTS.map((e) => (
            <div
              key={e.title}
              style={{
                position: 'absolute',
                left: LANE_X,
                top: y(e.start),
                width: LANE_W,
                height: Math.max(26, (e.end - e.start) * PPM),
                borderRadius: 9,
                background: alpha(e.color, 0.18),
                border: `1px solid ${alpha(e.color, 0.4)}`,
                padding: '4px 7px',
                overflow: 'hidden',
              }}
            >
              <div
                style={{
                  position: 'absolute',
                  left: 3,
                  top: 3,
                  bottom: 3,
                  width: 3,
                  borderRadius: 2,
                  background: e.color,
                }}
              />
              <div style={{marginLeft: 6}}>
                <div style={{fontSize: 11.5, fontWeight: 600, lineHeight: 1.2}}>{e.title}</div>
                {(e.end - e.start) * PPM > 34 ? (
                  <div style={{fontSize: 10, color: Theme.secondaryText}}>
                    {hhmm(e.start)}–{hhmm(e.end)}
                  </div>
                ) : null}
              </div>
            </div>
          ))}

          {/* circadian markers */}
          {MARKERS.map((mk) => (
            <div
              key={mk.min}
              style={{
                position: 'absolute',
                left: RIBBON_X + RIBBON_W / 2 - 13,
                top: y(mk.min) - 13,
                width: 26,
                height: 26,
                borderRadius: 13,
                background: mk.color,
                border: `1.5px solid ${Theme.bg}`,
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                opacity: draw,
              }}
            >
              <MarkerGlyph kind={mk.kind} />
            </div>
          ))}

          {/* warming band */}
          <Band
            top={y(warmStart)}
            height={Math.max(30, (warmEnd - warmStart) * PPM)}
            color={Theme.amber}
            icon={<Thermometer size={12} color="#fff" />}
            title="Warm-up"
            subtitle={hhmm(warmStart)}
            opacity={bands}
            lifted={lifted}
          />
          {/* sleep band */}
          <Band
            top={y(bedT)}
            height={Math.max(30, (wakeT - bedT) * PPM)}
            color={Theme.ember}
            icon={<MoonStars size={12} color="#fff" />}
            title={`Sleep · 7h 55m`}
            subtitle={`${hhmm(bedT)}–${hhmm(wakeT)}`}
            opacity={bands}
            lifted={lifted}
            handle
          />
        </div>
      </div>

      <StatusBar />
      <NavBar title="Agenda" trailing={<Info size={20} color={Theme.ember} />} />
      <TabBar active="agenda" />
    </div>
  );
};

const Band: React.FC<{
  top: number;
  height: number;
  color: string;
  icon: React.ReactNode;
  title: string;
  subtitle: string;
  opacity: number;
  lifted: boolean;
  handle?: boolean;
}> = ({top, height, color, icon, title, subtitle, opacity, lifted, handle}) => (
  <div
    style={{
      position: 'absolute',
      left: LANE_X,
      top,
      width: LANE_W,
      height,
      borderRadius: 12,
      background: alpha(color, lifted ? 0.34 : 0.22),
      border: `${lifted ? 1.5 : 1}px solid ${alpha(color, lifted ? 0.9 : 0.55)}`,
      boxShadow: lifted ? '0 3px 7px rgba(0,0,0,0.32)' : 'none',
      padding: '4px 10px 0',
      opacity,
      display: 'flex',
      alignItems: 'flex-start',
      gap: 8,
    }}
  >
    <div style={{marginTop: 2}}>{icon}</div>
    <div>
      <div style={{fontSize: 11.5, fontWeight: 700}}>{title}</div>
      {height > 42 ? (
        <div style={{fontSize: 10, opacity: 0.85}}>{subtitle}</div>
      ) : null}
    </div>
    {handle ? (
      <>
        <div style={{flex: 1}} />
        <div
          style={{
            width: 34,
            height: 34,
            borderRadius: 17,
            background: `rgba(0,0,0,${lifted ? 0.22 : 0.08})`,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            marginTop: 2,
          }}
        >
          <ArrowUpDown size={14} color="rgba(255,255,255,0.78)" />
        </div>
      </>
    ) : null}
  </div>
);
