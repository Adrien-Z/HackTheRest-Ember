import React from 'react';
import {Img, interpolate, spring, staticFile, useCurrentFrame, useVideoConfig} from 'remotion';
import {Theme, SF, alpha} from '../theme';
import {Starfield, Vignette} from '../components/Stage';

/**
 * The mascot is already asleep in the app icon — so the finale simply lets the
 * room go quiet around it, then sets the wordmark.
 */
export const Finale: React.FC<{duration: number}> = ({duration}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();

  const boxIn = spring({frame: frame - 4, fps, config: {damping: 16, mass: 1.1}});
  // Gentle breathing, then the glow settles.
  const breathe = 1 + Math.sin(frame / 34) * 0.014;
  const glow = interpolate(frame, [10, 66, 118], [0.2, 1, 0.42], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  const boxUp = interpolate(frame, [92, 132], [0, -104], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const boxShrink = interpolate(frame, [92, 132], [1, 0.72], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  const markIn = interpolate(frame, [122, 152], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const lineIn = interpolate(frame, [142, 172], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const ruleIn = interpolate(frame, [134, 168], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  const out = interpolate(frame, [duration - 26, duration - 2], [1, 0], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });

  return (
    <div style={{position: 'absolute', inset: 0, background: '#05060B', opacity: out}}>
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background: `radial-gradient(1000px 720px at 50% 46%, ${alpha(
            Theme.emberDeep,
            0.62 * glow + 0.12,
          )} 0%, transparent 64%)`,
        }}
      />
      <Starfield count={120} opacity={0.42 + 0.34 * (1 - glow)} speed={0.35} />

      <div
        style={{
          position: 'absolute',
          inset: 0,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <Img
          src={staticFile('appicon.png')}
          style={{
            width: 300,
            height: 300,
            objectFit: 'contain',
            opacity: boxIn,
            transform: `translateY(${(1 - boxIn) * 40 + boxUp}px) scale(${
              breathe * boxShrink * (0.9 + boxIn * 0.1)
            })`,
            filter: `drop-shadow(0 0 ${70 * glow}px ${alpha(Theme.ember, 0.6 * glow)})`,
            borderRadius: 68,
          }}
        />

        <div
          style={{
            position: 'absolute',
            top: 596,
            textAlign: 'center',
            fontFamily: SF,
          }}
        >
          <div
            style={{
              fontSize: 108,
              fontWeight: 600,
              letterSpacing: 22,
              paddingLeft: 22,
              color: '#fff',
              opacity: markIn,
              transform: `translateY(${(1 - markIn) * 16}px)`,
              filter: `blur(${(1 - markIn) * 8}px)`,
            }}
          >
            EMBER
          </div>
          <div
            style={{
              width: 300 * ruleIn,
              height: 1,
              margin: '30px auto 0',
              background: `linear-gradient(90deg, transparent, ${alpha(Theme.ember, 0.85)}, transparent)`,
            }}
          />
          <div
            style={{
              fontSize: 34,
              fontWeight: 400,
              letterSpacing: 0.6,
              color: Theme.secondaryText,
              marginTop: 28,
              opacity: lineIn,
              transform: `translateY(${(1 - lineIn) * 14}px)`,
              filter: `blur(${(1 - lineIn) * 5}px)`,
            }}
          >
            Rest that adapts to you.
          </div>
        </div>
      </div>

      <Vignette />
    </div>
  );
};
