import React from 'react';
import {Img, interpolate, staticFile} from 'remotion';
import {Theme, SF, SFRounded, alpha} from '../theme';
import {
  Card,
  MetricStat,
  NavBar,
  NightBackground,
  Pill,
  StatusBar,
  TabBar,
} from '../components/Phone';
import {
  Alarm,
  BedDouble,
  CheckSeal,
  Gear,
  MoonZzz,
  Waveform,
} from '../components/icons';
import {DailyRhythmView} from './DailyRhythm';

/** Sleep Score sparkline — mirrors `InsightTrendChart`. */
const TrendChart: React.FC<{progress: number; tint: string}> = ({progress, tint}) => {
  const pts = [62, 68, 65, 74, 71, 80, 78, 85, 83, 88, 87];
  const w = 313;
  const h = 66;
  const min = 58;
  const max = 92;
  const xy = pts.map((v, i) => ({
    x: (i / (pts.length - 1)) * w,
    y: h - ((v - min) / (max - min)) * h,
  }));
  const shown = Math.max(2, Math.round(xy.length * progress));
  const seg = xy.slice(0, shown);
  const d = seg
    .map((p, i) => `${i === 0 ? 'M' : 'L'}${p.x.toFixed(1)},${p.y.toFixed(1)}`)
    .join(' ');
  const area = `${d} L${seg[seg.length - 1].x.toFixed(1)},${h} L0,${h} Z`;
  return (
    <svg width={w} height={h} style={{display: 'block'}}>
      <defs>
        <linearGradient id="scoreFill" x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor={alpha(tint, 0.34)} />
          <stop offset="100%" stopColor={alpha(tint, 0)} />
        </linearGradient>
      </defs>
      <path d={area} fill="url(#scoreFill)" />
      <path
        d={d}
        fill="none"
        stroke={tint}
        strokeWidth={2.5}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
      <circle
        cx={seg[seg.length - 1].x}
        cy={seg[seg.length - 1].y}
        r={4}
        fill={tint}
        stroke={Theme.card}
        strokeWidth={2}
      />
    </svg>
  );
};

/**
 * `InsightMascot` — the translucent box vignette that bobs in the top-right of
 * each health insight card. `blanket` is the Sleep Score variant: a tilted
 * blanket, the user's box, and a moon.zzz.
 */
const InsightMascot: React.FC<{
  style: 'blanket';
  tint: string;
  /** -1..1 bob phase. */
  bob: number;
}> = ({tint, bob}) => (
  <div
    style={{
      position: 'absolute',
      top: -6,
      right: -8,
      width: 92,
      height: 96,
      opacity: 0.42,
      transform: `translateY(${bob * 3}px)`,
      pointerEvents: 'none',
    }}
  >
    <div
      style={{
        position: 'absolute',
        left: 7,
        top: 48,
        width: 78,
        height: 42,
        borderRadius: 18,
        background: alpha(tint, 0.2),
        transform: 'rotate(-6deg)',
      }}
    />
    <Img
      src={staticFile('skins/moon_blue.png')}
      style={{
        position: 'absolute',
        left: 17,
        top: 17,
        width: 58,
        height: 58,
        objectFit: 'contain',
      }}
    />
    <div style={{position: 'absolute', left: 66, top: 14}}>
      <MoonZzz size={15} color={tint} />
    </div>
  </div>
);

/**
 * `HomeView` — greeting, Tonight's Plan card with the three time metrics and
 * the AlarmKit wake toggle, and the Apple Health insight carousel.
 */
export const HomeScreen: React.FC<{
  /** 0-1 reveal of the card stack. */
  reveal?: number;
  /** 0-1 sparkline draw. */
  chart?: number;
  /** vertical scroll in points. */
  scroll?: number;
  /** counts up the Sleep Score. */
  score?: number;
  alarmSet?: boolean;
  /** -1..1, drives the insight mascot's slow bob. */
  bob?: number;
  /** 0-1 sweep of the Daily Rhythm curve. */
  rhythm?: number;
  /** shows the weather refresh indicator in the card header. */
  updating?: boolean;
}> = ({
  reveal = 1,
  chart = 1,
  scroll = 0,
  score = 87,
  alarmSet = false,
  bob = 0,
  rhythm = 1,
  updating = false,
}) => {
  const rise = (i: number) => {
    const t = interpolate(reveal, [i * 0.12, i * 0.12 + 0.5], [0, 1], {
      extrapolateLeft: 'clamp',
      extrapolateRight: 'clamp',
    });
    return {opacity: t, transform: `translateY(${(1 - t) * 26}px)`};
  };

  return (
    <div style={{position: 'absolute', inset: 0, fontFamily: SF}}>
      <NightBackground />
      <div
        style={{
          position: 'absolute',
          top: 103,
          left: 0,
          right: 0,
          padding: '4px 16px 0',
          transform: `translateY(${-scroll}px)`,
        }}
      >
        {/* greeting */}
        <div
          style={{
            ...rise(0),
            marginBottom: 18,
            display: 'flex',
            alignItems: 'center',
            gap: 12,
          }}
        >
          <div style={{flex: 1}}>
            <div style={{fontSize: 22, fontWeight: 700, letterSpacing: -0.4}}>
              Good evening, Alex
            </div>
            <div style={{fontSize: 15, color: Theme.secondaryText, marginTop: 2}}>
              Let&apos;s set up tonight&apos;s rest.
            </div>
          </div>
          <Img
            src={staticFile('skins/moon_blue.png')}
            style={{width: 52, height: 52, objectFit: 'contain'}}
          />
        </div>

        {/* Tonight's plan */}
        <div style={rise(1)}>
          <Card style={{background: `rgba(31,110,255,0.09)`, marginBottom: 18}}>
            <div style={{display: 'flex', alignItems: 'center', gap: 7, marginBottom: 14}}>
              <Waveform size={17} color="#fff" />
              <span style={{fontSize: 17, fontWeight: 600}}>Daily Rhythm</span>
              <div style={{flex: 1}} />
              {updating ? (
                <div style={{display: 'flex', alignItems: 'center', gap: 5}}>
                  <div
                    style={{
                      width: 11,
                      height: 11,
                      borderRadius: 6,
                      border: `1.6px solid rgba(255,255,255,0.22)`,
                      borderTopColor: Theme.secondaryText,
                    }}
                  />
                  <span style={{fontSize: 11, color: 'rgba(255,255,255,0.61)'}}>Updating</span>
                </div>
              ) : null}
            </div>
            <DailyRhythmView draw={rhythm} />
            <div style={{height: 1, background: 'rgba(255,255,255,0.08)', margin: '14px 0 12px'}} />
            {/* wake alarm is a Toggle now, kept in sync with AlarmKit */}
            <div style={{display: 'flex', alignItems: 'center', gap: 10}}>
              <div style={{width: 24, display: 'flex', justifyContent: 'center'}}>
                <Alarm size={17} color={Theme.amber} />
              </div>
              <div>
                <div style={{fontSize: 13, fontWeight: 600}}>Wake alarm</div>
                <div
                  style={{
                    fontSize: 12,
                    color: Theme.secondaryText,
                    marginTop: 2,
                    fontVariantNumeric: 'tabular-nums',
                  }}
                >
                  06:45
                </div>
              </div>
              <div style={{flex: 1}} />
              <div
                style={{
                  width: 51,
                  height: 31,
                  borderRadius: 16,
                  background: alarmSet ? Theme.ember : 'rgba(255,255,255,0.16)',
                  padding: 2,
                  display: 'flex',
                  justifyContent: alarmSet ? 'flex-end' : 'flex-start',
                }}
              >
                <div
                  style={{
                    width: 27,
                    height: 27,
                    borderRadius: 14,
                    background: '#fff',
                    boxShadow: '0 2px 4px rgba(0,0,0,0.28)',
                  }}
                />
              </div>
            </div>
          </Card>
        </div>

        {/* Apple Health insight carousel — page 1: Sleep Score */}
        <div style={rise(2)}>
          <Card
            padding={20}
            style={{
              height: 288,
              position: 'relative',
              overflow: 'hidden',
              border: `0.9px solid ${alpha(Theme.cool, 0.28)}`,
            }}
          >
            <InsightMascot style="blanket" tint={Theme.cool} bob={bob} />
            <div style={{marginBottom: 12, position: 'relative'}}>
              <div style={{fontSize: 17, fontWeight: 600}}>Sleep Score</div>
              <div style={{fontSize: 12, color: Theme.secondaryText, marginTop: 2}}>
                Your overnight recovery
              </div>
            </div>
            <div style={{display: 'flex', alignItems: 'baseline', gap: 8, marginBottom: 6}}>
              <div
                style={{
                  fontFamily: SFRounded,
                  fontSize: 56,
                  fontWeight: 700,
                  color: Theme.cool,
                  letterSpacing: -1.5,
                  lineHeight: 1,
                }}
              >
                {Math.round(score)}
              </div>
              <div style={{fontSize: 12, fontWeight: 600, color: Theme.secondaryText}}>
                out of 100
              </div>
            </div>
            <TrendChart progress={chart} tint={Theme.cool} />
            <div style={{display: 'flex', gap: 8, marginTop: 12}}>
              <Pill>
                <BedDouble size={12} color="#fff" />
                7h 12m
              </Pill>
              <Pill>
                <CheckSeal size={12} color={Theme.mint} />
                91%
              </Pill>
              <Pill color={Theme.secondaryText}>night quality</Pill>
            </div>
          </Card>
          <div
            style={{
              display: 'flex',
              gap: 7,
              justifyContent: 'center',
              marginTop: 10,
            }}
          >
            {[0, 1, 2].map((i) => (
              <div
                key={i}
                style={{
                  width: i === 0 ? 18 : 6,
                  height: 6,
                  borderRadius: 3,
                  background: i === 0 ? Theme.ember : 'rgba(255,255,255,0.34)',
                }}
              />
            ))}
          </div>
        </div>
      </div>

      <StatusBar />
      <NavBar title="EMBER" trailing={<Gear size={20} color={Theme.ember} />} />
      {/* the scroll edge fades out under the tab bar */}
      <div
        style={{
          position: 'absolute',
          bottom: 84,
          left: 0,
          right: 0,
          height: 60,
          background: `linear-gradient(180deg, transparent, ${Theme.bg})`,
          zIndex: 45,
        }}
      />
      <TabBar active="today" />
    </div>
  );
};
