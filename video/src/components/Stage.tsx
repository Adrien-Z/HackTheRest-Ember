import React from 'react';
import {interpolate, random, useCurrentFrame} from 'remotion';
import {Theme, SF, alpha} from '../theme';

/** Slow-drifting starfield — the app's night mood, at stage scale. */
export const Starfield: React.FC<{count?: number; opacity?: number; speed?: number}> = ({
  count = 90,
  opacity = 1,
  speed = 1,
}) => {
  const frame = useCurrentFrame();
  return (
    <div style={{position: 'absolute', inset: 0, opacity}}>
      {Array.from({length: count}, (_, i) => {
        const x = random(`x${i}`) * 1920;
        const y = random(`y${i}`) * 1080;
        const r = 0.7 + random(`r${i}`) * 1.9;
        const tw = 0.35 + 0.65 * Math.abs(Math.sin((frame * speed) / (40 + random(`t${i}`) * 90) + i));
        return (
          <div
            key={i}
            style={{
              position: 'absolute',
              left: x,
              top: y + Math.sin((frame * speed) / 150 + i) * 6,
              width: r * 2,
              height: r * 2,
              borderRadius: '50%',
              background: '#fff',
              opacity: tw * 0.55,
            }}
          />
        );
      })}
    </div>
  );
};

/** The deep-night stage the phone sits on. */
export const StageBackground: React.FC<{glow?: number}> = ({glow = 1}) => (
  <div style={{position: 'absolute', inset: 0, background: '#080A11'}}>
    <div
      style={{
        position: 'absolute',
        inset: 0,
        background: `radial-gradient(1200px 800px at 62% 46%, ${alpha(
          Theme.emberDeep,
          0.55 * glow,
        )} 0%, transparent 62%)`,
      }}
    />
    <div
      style={{
        position: 'absolute',
        inset: 0,
        background: `radial-gradient(900px 620px at 18% 78%, ${alpha(
          Theme.ember,
          0.16 * glow,
        )} 0%, transparent 60%)`,
      }}
    />
  </div>
);

export const Vignette: React.FC = () => (
  <div
    style={{
      position: 'absolute',
      inset: 0,
      pointerEvents: 'none',
      background:
        'radial-gradient(120% 100% at 50% 50%, transparent 52%, rgba(0,0,0,0.55) 100%)',
    }}
  />
);

/**
 * Caption block. Lines rise and un-blur one after another, then hold —
 * unhurried, readable muted, no motion competing with the UI.
 */
export const Caption: React.FC<{
  headline: string;
  sub?: string;
  /** local frame within the beat. */
  frame: number;
  start?: number;
  out?: number;
  align?: 'left' | 'center';
  width?: number;
}> = ({headline, sub, frame, start = 0, out, align = 'left', width = 800}) => {
  const enter = (d: number) =>
    interpolate(frame, [start + d, start + d + 22], [0, 1], {
      extrapolateLeft: 'clamp',
      extrapolateRight: 'clamp',
    });
  const exit =
    out === undefined
      ? 1
      : interpolate(frame, [out, out + 14], [1, 0], {
          extrapolateLeft: 'clamp',
          extrapolateRight: 'clamp',
        });

  const h = enter(0);
  const s = enter(9);

  return (
    <div style={{width, textAlign: align, opacity: exit}}>
      <div
        style={{
          fontFamily: SF,
          fontSize: 86,
          lineHeight: 1.06,
          fontWeight: 600,
          letterSpacing: -3,
          color: '#fff',
          opacity: h,
          transform: `translateY(${(1 - h) * 26}px)`,
          filter: `blur(${(1 - h) * 8}px)`,
        }}
      >
        {headline}
      </div>
      {sub ? (
        <div
          style={{
            fontFamily: SF,
            fontSize: 35,
            lineHeight: 1.38,
            fontWeight: 400,
            letterSpacing: -0.4,
            color: Theme.secondaryText,
            marginTop: 26,
            maxWidth: 740,
            marginLeft: align === 'center' ? 'auto' : 0,
            marginRight: align === 'center' ? 'auto' : 0,
            opacity: s,
            transform: `translateY(${(1 - s) * 18}px)`,
            filter: `blur(${(1 - s) * 5}px)`,
          }}
        >
          {sub}
        </div>
      ) : null}
    </div>
  );
};

/**
 * A detached UI chip that flies out of the phone to spotlight one detail.
 * Keeps the "impressive" register without cutting away from the product.
 */
export const FloatingCard: React.FC<{
  children: React.ReactNode;
  frame: number;
  start: number;
  out?: number;
  x: number;
  y: number;
  tint?: string;
}> = ({children, frame, start, out, x, y, tint = Theme.ember}) => {
  const t = interpolate(frame, [start, start + 26], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const exit =
    out === undefined
      ? 1
      : interpolate(frame, [out, out + 16], [1, 0], {
          extrapolateLeft: 'clamp',
          extrapolateRight: 'clamp',
        });
  const drift = Math.sin(frame / 44) * 5;
  return (
    <div
      style={{
        position: 'absolute',
        left: x,
        top: y,
        opacity: t * exit,
        transform: `translate(${(1 - t) * -34}px, ${(1 - t) * 16 + drift}px) scale(${
          0.9 + t * 0.1
        })`,
        padding: '26px 30px',
        borderRadius: 28,
        background: 'rgba(24,28,40,0.86)',
        backdropFilter: 'blur(30px)',
        WebkitBackdropFilter: 'blur(30px)',
        border: `1px solid ${alpha(tint, 0.32)}`,
        boxShadow: `0 30px 70px rgba(0,0,0,0.5), 0 0 60px ${alpha(tint, 0.16)}`,
        fontFamily: SF,
        color: '#fff',
      }}
    >
      {children}
    </div>
  );
};
