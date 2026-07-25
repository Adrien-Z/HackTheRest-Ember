import React from 'react';
import {Img, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig} from 'remotion';
import {Theme, SF, SFRounded, alpha} from '../theme';
import {Starfield, Vignette} from '../components/Stage';
import {MoonStars, Thermometer, Alarm} from '../components/icons';

/** The clock a restless night actually shows you. */
const READINGS = [
  {label: '23:00', at: 10, dim: 0.92},
  {label: '23:38', at: 46, dim: 0.74},
  {label: '00:24', at: 84, dim: 0.56},
  {label: '01:47', at: 120, dim: 0.4},
];

/**
 * Scene 0 — wordless. The time crawls; EMBER answers with a plan.
 * No problem copy, no voice: the numbers do the work.
 */
export const Hook: React.FC = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();

  const clockOut = interpolate(frame, [150, 168], [1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  const planIn = spring({frame: frame - 158, fps, config: {damping: 15, mass: 0.6}});
  const bloom = interpolate(frame, [158, 186, 210], [0, 1, 0.85], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  // Global fade to hand off to the first beat.
  const handoff = interpolate(frame, [196, 210], [1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  return (
    <div style={{position: 'absolute', inset: 0, background: '#05060B', opacity: handoff}}>
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background: `radial-gradient(1000px 700px at 50% 50%, ${alpha(
            Theme.emberDeep,
            0.3 + 0.5 * bloom,
          )} 0%, transparent 65%)`,
        }}
      />
      <Starfield count={110} opacity={0.5 + 0.5 * bloom} speed={0.5} />

      {/* the crawling clock */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
          opacity: clockOut,
        }}
      >
        {READINGS.map((r, i) => {
          const next = READINGS[i + 1];
          const o = interpolate(
            frame,
            [r.at, r.at + 12, next ? next.at - 2 : 148, next ? next.at + 10 : 152],
            [0, 1, 1, 0],
            {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
          );
          const breathe = 1 + Math.sin(frame / 30) * 0.006;
          return (
            <div
              key={r.label}
              style={{
                position: 'absolute',
                fontFamily: SFRounded,
                fontSize: 232,
                fontWeight: 300,
                letterSpacing: -6,
                color: '#fff',
                opacity: o * r.dim,
                transform: `scale(${breathe})`,
                filter: `blur(${(1 - o) * 14}px)`,
                fontVariantNumeric: 'tabular-nums',
              }}
            >
              {r.label}
            </div>
          );
        })}
      </div>

      {/* EMBER's answer */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          gap: 34,
          opacity: planIn,
          transform: `scale(${0.94 + planIn * 0.06})`,
        }}
      >
        <div
          style={{
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            gap: 16,
          }}
        >
          <Img
            src={staticFile('skins/moon_blue.png')}
            style={{
              width: 96,
              height: 96,
              objectFit: 'contain',
              filter: `drop-shadow(0 0 34px ${alpha(Theme.ember, 0.6 * bloom)})`,
            }}
          />
          <div
            style={{
              fontFamily: SF,
              fontSize: 24,
              fontWeight: 600,
              letterSpacing: 4,
              color: Theme.ember,
            }}
          >
            TONIGHT&apos;S PLAN
          </div>
        </div>
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            gap: 0,
            padding: '32px 56px',
            borderRadius: 30,
            background: 'rgba(24,28,40,0.8)',
            backdropFilter: 'blur(30px)',
            border: `1px solid ${alpha(Theme.ember, 0.34)}`,
            boxShadow: `0 40px 90px rgba(0,0,0,0.6), 0 0 ${120 * bloom}px ${alpha(
              Theme.ember,
              0.3 * bloom,
            )}`,
          }}
        >
          <Metric
            value="21:50"
            label="start warming"
            color={Theme.ember}
            icon={<Thermometer size={19} color={Theme.ember} />}
            delay={4}
            frame={frame - 158}
            fps={fps}
          />
          <Sep />
          <Metric
            value="22:50"
            label="lights out"
            color="#fff"
            icon={<MoonStars size={19} color="#fff" />}
            delay={10}
            frame={frame - 158}
            fps={fps}
          />
          <Sep />
          <Metric
            value="06:45"
            label="wake"
            color={Theme.amber}
            icon={<Alarm size={19} color={Theme.amber} />}
            delay={16}
            frame={frame - 158}
            fps={fps}
          />
        </div>
      </div>

      <Vignette />
    </div>
  );
};

const Sep: React.FC = () => (
  <div style={{width: 1, height: 76, background: 'rgba(255,255,255,0.13)', margin: '0 44px'}} />
);

const Metric: React.FC<{
  value: string;
  label: string;
  color: string;
  icon: React.ReactNode;
  delay: number;
  frame: number;
  fps: number;
}> = ({value, label, color, icon, delay, frame, fps}) => {
  const s = spring({frame: frame - delay, fps, config: {damping: 14, mass: 0.5}});
  return (
    <div
      style={{
        textAlign: 'center',
        opacity: s,
        transform: `translateY(${(1 - s) * 14}px)`,
      }}
    >
      <div style={{display: 'flex', justifyContent: 'center', marginBottom: 12}}>{icon}</div>
      <div
        style={{
          fontFamily: SFRounded,
          fontSize: 78,
          fontWeight: 700,
          color,
          letterSpacing: -2.4,
          lineHeight: 1,
          fontVariantNumeric: 'tabular-nums',
        }}
      >
        {value}
      </div>
      <div
        style={{
          fontFamily: SF,
          fontSize: 19,
          color: Theme.secondaryText,
          marginTop: 10,
        }}
      >
        {label}
      </div>
    </div>
  );
};
