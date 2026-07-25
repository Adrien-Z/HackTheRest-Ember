import React from 'react';
import {interpolate} from 'remotion';
import {SFRounded} from '../theme';

/**
 * `DailyRhythmView` — a direct port of Ember/Views/Components/DailyRhythmView.swift.
 *
 * The whole day drawn as one sine wave anchored to the real sunrise and sunset
 * from WeatherManager: the sun arcs above the horizon, the night dips below it,
 * and four markers sit on the curve.
 */

const W = 329; // card inner width at 393pt screen with 16pt page + 16pt card padding
const H = 260; // DailyRhythmView.frame(height: 260)

const SUNRISE = 5.14; // WeatherManager default
const SUNSET = 21.0;
const SLEEP = 23.0;
const WAKE = 7.0;

const HORIZON_Y = H * 0.52;
const AMPLITUDE = H * 0.3;
const DAY_DURATION = Math.max(0.1, SUNSET - SUNRISE);
const NIGHT_DURATION = Math.max(0.1, 24 - DAY_DURATION);

const pointForAngle = (angle: number) => ({
  x: W * (angle / (Math.PI * 2)),
  y: HORIZON_Y - AMPLITUDE * Math.sin(angle),
});

const angleForHour = (hour: number) => {
  const cycleHour = hour >= SUNRISE ? hour - SUNRISE : hour + 24 - SUNRISE;
  if (cycleHour <= DAY_DURATION) return (cycleHour / DAY_DURATION) * Math.PI;
  return Math.PI + ((cycleHour - DAY_DURATION) / NIGHT_DURATION) * Math.PI;
};

const timeLabel = (hour: number) => {
  const normalized = ((hour % 24) + 24) % 24;
  const total = Math.round(normalized * 60) % (24 * 60);
  return `${String(Math.floor(total / 60)).padStart(2, '0')}:${String(total % 60).padStart(2, '0')}`;
};

const curvePath = (start: number, end: number) => {
  const samples = 160;
  let d = '';
  for (let i = 0; i <= samples; i++) {
    const angle = start + (end - start) * (i / samples);
    const p = pointForAngle(angle);
    d += `${i === 0 ? 'M' : 'L'}${p.x.toFixed(2)},${p.y.toFixed(2)}`;
  }
  return d;
};

const DAY_PATH = curvePath(0, Math.PI);
const NIGHT_PATH = curvePath(Math.PI, Math.PI * 2);

const STARS = [
  [0.12, 0.16],
  [0.28, 0.1],
  [0.66, 0.18],
  [0.82, 0.13],
  [0.91, 0.28],
];

type MarkerSpec = {
  title: string;
  hour: number;
  angle?: number;
  placement: 'above' | 'below';
  color: string;
  labelOffsetX?: number;
  guide?: boolean;
};

const MARKERS: MarkerSpec[] = [
  {title: 'Sunrise', hour: SUNRISE, angle: 0, placement: 'below', color: '#FFD161', labelOffsetX: 10},
  {title: 'Sunset', hour: SUNSET, angle: Math.PI, placement: 'above', color: '#FF8C47'},
  {title: 'Sleep', hour: SLEEP, placement: 'below', color: '#BD8FFF', guide: true},
  {title: 'Wake', hour: WAKE, placement: 'above', color: '#FFD16B'},
];

const LABEL_W = 76;
const LABEL_DISTANCE = 36;
const GUIDE_LENGTH = 22;
const EDGE_PADDING = 12;

const Marker: React.FC<{spec: MarkerSpec; draw: number}> = ({spec, draw}) => {
  const angle = spec.angle ?? angleForHour(spec.hour);
  const p = pointForAngle(angle);
  const dir = spec.placement === 'above' ? -1 : 1;

  // Each marker lands as the curve reaches it.
  const t = interpolate(draw, [angle / (Math.PI * 2), angle / (Math.PI * 2) + 0.1], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  const half = LABEL_W / 2;
  let centerX = p.x;
  let align: 'left' | 'right' | 'center' = 'center';
  if (p.x - half < EDGE_PADDING) {
    centerX = p.x + half;
    align = 'left';
  } else if (p.x + half > W - EDGE_PADDING) {
    centerX = p.x - half;
    align = 'right';
  }
  centerX += spec.labelOffsetX ?? 0;
  const labelY = p.y + dir * LABEL_DISTANCE;

  return (
    <div style={{opacity: t}}>
      {spec.guide ? (
        <svg
          width={W}
          height={H}
          style={{position: 'absolute', left: 0, top: 0, pointerEvents: 'none'}}
        >
          <line
            x1={p.x}
            y1={p.y}
            x2={p.x}
            y2={p.y + dir * GUIDE_LENGTH}
            stroke={spec.color}
            strokeOpacity={0.42}
            strokeWidth={1}
            strokeLinecap="round"
            strokeDasharray="4 5"
          />
        </svg>
      ) : null}
      <div
        style={{
          position: 'absolute',
          left: p.x - 2.5,
          top: p.y - 2.5,
          width: 5,
          height: 5,
          borderRadius: 3,
          background: spec.color,
          opacity: 0.86,
          boxShadow: `0 0 8px ${spec.color}73`,
        }}
      />
      <div
        style={{
          position: 'absolute',
          left: centerX - half,
          top: labelY - 15,
          width: LABEL_W,
          textAlign: align === 'left' ? 'left' : align === 'right' ? 'right' : 'center',
          fontFamily: SFRounded,
          textShadow: '0 2px 4px rgba(0,0,0,0.24)',
        }}
      >
        <div style={{fontSize: 12, fontWeight: 600, color: spec.color, opacity: 0.82}}>
          {timeLabel(spec.hour)}
        </div>
        <div style={{fontSize: 11, fontWeight: 400, color: spec.color, opacity: 0.68, marginTop: 1}}>
          {spec.title}
        </div>
      </div>
    </div>
  );
};

export const DailyRhythmView: React.FC<{
  /** 0-1 sweep of the curve, from sunrise all the way round to sunrise. */
  draw?: number;
}> = ({draw = 1}) => {
  const sunrisePt = pointForAngle(0);
  const sunsetPt = pointForAngle(Math.PI);
  const midnightPt = pointForAngle(Math.PI * 1.5);

  const dayDash = 1 - Math.min(1, Math.max(0, draw / 0.5));
  const nightDash = 1 - Math.min(1, Math.max(0, (draw - 0.5) / 0.5));

  return (
    <div
      style={{
        position: 'relative',
        width: W,
        height: H,
        borderRadius: 20,
        overflow: 'hidden',
      }}
    >
      <svg width={W} height={H} style={{position: 'absolute', left: 0, top: 0}}>
        <defs>
          <linearGradient id="rhythmSky" x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor="#040914" />
            <stop offset="50%" stopColor="#050D1F" />
            <stop offset="100%" stopColor="#03050E" />
          </linearGradient>
          <radialGradient id="glowSunrise">
            <stop offset="0%" stopColor="#FFB847" stopOpacity="0.28" />
            <stop offset="100%" stopColor="#FFB847" stopOpacity="0" />
          </radialGradient>
          <radialGradient id="glowSunset">
            <stop offset="0%" stopColor="#FF5738" stopOpacity="0.22" />
            <stop offset="100%" stopColor="#FF5738" stopOpacity="0" />
          </radialGradient>
          <radialGradient id="glowNight">
            <stop offset="0%" stopColor="#4D5CFF" stopOpacity="0.2" />
            <stop offset="100%" stopColor="#4D5CFF" stopOpacity="0" />
          </radialGradient>
          <linearGradient id="horizonLine" x1="0" y1="0" x2="1" y2="0">
            <stop offset="0%" stopColor="#FFFFFF" stopOpacity="0.18" />
            <stop offset="33%" stopColor="#FFC25C" stopOpacity="0.44" />
            <stop offset="66%" stopColor="#7A80FF" stopOpacity="0.4" />
            <stop offset="100%" stopColor="#FFFFFF" stopOpacity="0.16" />
          </linearGradient>
          <linearGradient
            id="dayArc"
            gradientUnits="userSpaceOnUse"
            x1={sunrisePt.x}
            y1={sunrisePt.y}
            x2={sunsetPt.x}
            y2={sunsetPt.y}
          >
            <stop offset="0%" stopColor="#FFDB70" />
            <stop offset="100%" stopColor="#FF8A47" />
          </linearGradient>
          <linearGradient
            id="dayGlow"
            gradientUnits="userSpaceOnUse"
            x1={sunrisePt.x}
            y1={sunrisePt.y}
            x2={sunsetPt.x}
            y2={sunsetPt.y}
          >
            <stop offset="0%" stopColor="#FFD161" stopOpacity="0.18" />
            <stop offset="100%" stopColor="#FF7A3D" stopOpacity="0.14" />
          </linearGradient>
          <linearGradient
            id="nightArc"
            gradientUnits="userSpaceOnUse"
            x1={sunsetPt.x}
            y1={sunsetPt.y}
            x2={W}
            y2={sunrisePt.y}
          >
            <stop offset="0%" stopColor="#BD75FF" />
            <stop offset="100%" stopColor="#578FFF" />
          </linearGradient>
          <linearGradient
            id="nightGlow"
            gradientUnits="userSpaceOnUse"
            x1={sunsetPt.x}
            y1={sunsetPt.y}
            x2={W}
            y2={sunrisePt.y}
          >
            <stop offset="0%" stopColor="#B26BFF" stopOpacity="0.16" />
            <stop offset="100%" stopColor="#4D85FF" stopOpacity="0.18" />
          </linearGradient>
        </defs>

        <rect width={W} height={H} fill="url(#rhythmSky)" />

        {/* the three sky glows: sunrise, sunset, deep night */}
        <circle cx={sunrisePt.x} cy={sunrisePt.y} r={W * 0.34} fill="url(#glowSunrise)" />
        <circle cx={sunsetPt.x} cy={sunsetPt.y} r={W * 0.32} fill="url(#glowSunset)" />
        <circle cx={midnightPt.x} cy={midnightPt.y} r={W * 0.34} fill="url(#glowNight)" />

        {STARS.map(([sx, sy], i) => (
          <circle key={i} cx={W * sx + 0.8} cy={H * sy + 0.8} r={0.8} fill="#fff" fillOpacity={0.32} />
        ))}

        <line
          x1={0}
          y1={HORIZON_Y}
          x2={W}
          y2={HORIZON_Y}
          stroke="url(#horizonLine)"
          strokeWidth={0.8}
        />

        {/* soft glow under each arc, then the arc itself */}
        <path
          d={DAY_PATH}
          pathLength={1}
          fill="none"
          stroke="url(#dayGlow)"
          strokeWidth={8}
          strokeLinecap="round"
          strokeLinejoin="round"
          strokeDasharray={1}
          strokeDashoffset={dayDash}
        />
        <path
          d={NIGHT_PATH}
          pathLength={1}
          fill="none"
          stroke="url(#nightGlow)"
          strokeWidth={8}
          strokeLinecap="round"
          strokeLinejoin="round"
          strokeDasharray={1}
          strokeDashoffset={nightDash}
        />
        <path
          d={DAY_PATH}
          pathLength={1}
          fill="none"
          stroke="url(#dayArc)"
          strokeWidth={1.8}
          strokeLinecap="round"
          strokeLinejoin="round"
          strokeDasharray={1}
          strokeDashoffset={dayDash}
        />
        <path
          d={NIGHT_PATH}
          pathLength={1}
          fill="none"
          stroke="url(#nightArc)"
          strokeWidth={1.8}
          strokeLinecap="round"
          strokeLinejoin="round"
          strokeDasharray={1}
          strokeDashoffset={nightDash}
        />
      </svg>

      {MARKERS.map((m) => (
        <Marker key={m.title} spec={m} draw={draw} />
      ))}
    </div>
  );
};
