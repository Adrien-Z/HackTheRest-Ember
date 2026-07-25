import React from 'react';
import {interpolate, staticFile, Img} from 'remotion';
import {Theme, SF, SFRounded, alpha} from '../theme';
import {
  Card,
  MetricStat,
  NavBar,
  NightBackground,
  SectionHeader,
  StatusBar,
  TabBar,
} from '../components/Phone';
import {
  BedDouble,
  Chevron,
  HandsSparkles,
  Sparkles,
  Thermometer,
  Waves,
  Wind,
} from '../components/icons';

const WideCard: React.FC<{
  title: string;
  subtitle: string;
  metric: string;
  tint: string;
  icon: React.ReactNode;
  pressed?: boolean;
}> = ({title, subtitle, metric, tint, icon, pressed}) => (
  <div
    style={{
      display: 'flex',
      gap: 13,
      padding: 16,
      borderRadius: 18,
      background: 'rgba(28,31,43,0.96)',
      border: `0.8px solid ${alpha(tint, 0.18)}`,
      transform: `scale(${pressed ? 0.97 : 1})`,
      boxShadow: pressed ? `0 0 44px ${alpha(tint, 0.35)}` : 'none',
    }}
  >
    <div
      style={{
        width: 46,
        height: 46,
        borderRadius: 14,
        background: alpha(tint, 0.14),
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        flexShrink: 0,
      }}
    >
      {icon}
    </div>
    <div style={{flex: 1}}>
      <div style={{display: 'flex', alignItems: 'center', gap: 8}}>
        <span style={{fontSize: 17, fontWeight: 600}}>{title}</span>
        <span
          style={{
            fontSize: 11,
            fontWeight: 700,
            color: tint,
            padding: '4px 8px',
            borderRadius: 100,
            background: alpha(tint, 0.14),
          }}
        >
          {metric}
        </span>
      </div>
      <div style={{fontSize: 13, color: Theme.secondaryText, marginTop: 4, lineHeight: 1.35}}>
        {subtitle}
      </div>
    </div>
    <Chevron size={13} color={Theme.secondaryText} style={{alignSelf: 'center'}} />
  </div>
);

const SmallCard: React.FC<{
  title: string;
  subtitle: string;
  tint: string;
  icon: React.ReactNode;
}> = ({title, subtitle, tint, icon}) => (
  <div
    style={{
      minHeight: 124,
      padding: 13,
      borderRadius: 18,
      background: 'rgba(28,31,43,0.96)',
      border: `0.8px solid ${alpha(tint, 0.18)}`,
      display: 'flex',
      flexDirection: 'column',
    }}
  >
    <div
      style={{
        width: 42,
        height: 42,
        borderRadius: 13,
        background: alpha(tint, 0.14),
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
      }}
    >
      {icon}
    </div>
    <div style={{flex: 1, minHeight: 6}} />
    <div style={{fontSize: 15.5, fontWeight: 600}}>{title}</div>
    <div style={{fontSize: 11, color: Theme.secondaryText, marginTop: 2, lineHeight: 1.25}}>
      {subtitle}
    </div>
  </div>
);

/** `RestLabView` — pick the lever: two protocols on top, wind-down tools below. */
export const RestLabScreen: React.FC<{reveal?: number; pressWarm?: boolean}> = ({
  reveal = 1,
  pressWarm = false,
}) => {
  const rise = (i: number) => {
    const t = interpolate(reveal, [i * 0.11, i * 0.11 + 0.48], [0, 1], {
      extrapolateLeft: 'clamp',
      extrapolateRight: 'clamp',
    });
    return {opacity: t, transform: `translateY(${(1 - t) * 24}px)`};
  };
  return (
    <div style={{position: 'absolute', inset: 0, fontFamily: SF}}>
      <NightBackground />
      <div style={{position: 'absolute', top: 107, left: 16, right: 16}}>
        {/* hero */}
        <div style={rise(0)}>
          <Card style={{display: 'flex', gap: 14, alignItems: 'center', marginBottom: 18}}>
            <Img
              src={staticFile('skins/moon_blue.png')}
              style={{width: 72, height: 72, objectFit: 'contain'}}
            />
            <div style={{flex: 1}}>
              <div style={{fontSize: 20, fontWeight: 700, letterSpacing: -0.3}}>
                Choose the right lever
              </div>
              <div style={{fontSize: 13, color: Theme.secondaryText, marginTop: 4, lineHeight: 1.35}}>
                Science-backed plans and gentle wind-down tools live here.
              </div>
            </div>
          </Card>
        </div>

        <div style={{...rise(1), marginBottom: 18}}>
          <SectionHeader
            title="Build tonight's plan"
            subtitle="Personalized protocols that adapt from your data."
          />
          <div style={{display: 'flex', flexDirection: 'column', gap: 10, marginTop: 10}}>
            <WideCard
              title="Warm-Up"
              metric="60m before bed"
              subtitle="Time your foot bath, shower, or warm towel so the cool-down helps sleep start."
              tint={Theme.ember}
              icon={<Thermometer size={22} color={Theme.ember} />}
              pressed={pressWarm}
            />
            <WideCard
              title="Efficiency"
              metric="7h 20m"
              subtitle="Tune a realistic sleep window so time in bed feels more solid."
              tint={Theme.cool}
              icon={<BedDouble size={22} color={Theme.cool} />}
            />
          </div>
        </div>

        <div style={rise(2)}>
          <SectionHeader
            title="Wind down now"
            subtitle="Small tools for the last stretch before bed."
          />
          <div
            style={{
              display: 'grid',
              gridTemplateColumns: '1fr 1fr 1fr',
              gap: 10,
              marginTop: 10,
            }}
          >
            <SmallCard
              title="Rituals"
              subtitle="Warmth, tea"
              tint={Theme.ember}
              icon={<HandsSparkles size={19} color={Theme.ember} />}
            />
            <SmallCard
              title="Breathing"
              subtitle="4 · 4 · 6"
              tint={Theme.mint}
              icon={<Wind size={19} color={Theme.mint} />}
            />
            <SmallCard
              title="Sounds"
              subtitle="Rain, stream"
              tint={Theme.cool}
              icon={<Waves size={19} color={Theme.cool} />}
            />
          </div>
        </div>

        {/* AskCoachLink */}
        <div style={{...rise(3), marginTop: 14}}>
          <Card
            padding={12}
            style={{display: 'flex', alignItems: 'center', gap: 10}}
          >
            <Img
              src={staticFile('skins/moon_blue.png')}
              style={{width: 28, height: 28, objectFit: 'contain'}}
            />
            <span style={{fontSize: 15, fontWeight: 600}}>Ask the coach</span>
            <div style={{flex: 1}} />
            <Chevron size={12} color={Theme.secondaryText} />
          </Card>
        </div>
      </div>

      <StatusBar />
      <NavBar title="Rest Lab" />
      <TabBar active="lab" />
    </div>
  );
};

// ── Warm-Up detail (ThermalView) ────────────────────────────────────────────

const TITRATION = [
  {block: 'Block 1', offset: 30, sol: 46},
  {block: 'Block 2', offset: 45, sol: 34},
  {block: 'Block 3', offset: 60, sol: 21},
  {block: 'Block 4', offset: 60, sol: 18},
];

/** Sleep-onset latency falling as EMBER titrates the warming offset. */
const SOLChart: React.FC<{progress: number}> = ({progress}) => {
  const vals = [48, 44, 46, 39, 35, 33, 26, 23, 21, 19, 18, 17];
  const w = 313;
  const h = 108;
  const max = 52;
  const bw = w / vals.length;
  return (
    <svg width={w} height={h} style={{display: 'block'}}>
      <line x1="0" y1={h - (20 / max) * h} x2={w} y2={h - (20 / max) * h} stroke={alpha(Theme.mint, 0.5)} strokeWidth="1" strokeDasharray="4 4" />
      {vals.map((v, i) => {
        const t = interpolate(progress, [i * 0.055, i * 0.055 + 0.3], [0, 1], {
          extrapolateLeft: 'clamp',
          extrapolateRight: 'clamp',
        });
        const bh = (v / max) * h * t;
        const under = v <= 20;
        return (
          <rect
            key={i}
            x={i * bw + 2.5}
            y={h - bh}
            width={bw - 5}
            height={bh}
            rx={3}
            fill={under ? Theme.mint : Theme.ember}
            opacity={under ? 0.95 : 0.8}
          />
        );
      })}
    </svg>
  );
};

export const WarmUpDetailScreen: React.FC<{chart?: number; reveal?: number}> = ({
  chart = 1,
  reveal = 1,
}) => (
  <div style={{position: 'absolute', inset: 0, fontFamily: SF}}>
    <NightBackground />
    <div style={{position: 'absolute', top: 110, left: 16, right: 16, opacity: reveal}}>
      <Card style={{marginBottom: 16, background: 'rgba(31,110,255,0.09)'}}>
        <div style={{display: 'flex', alignItems: 'center', gap: 8, marginBottom: 14}}>
          <Thermometer size={17} color={Theme.ember} />
          <span style={{fontSize: 17, fontWeight: 600}}>Thermal wind-down</span>
        </div>
        <div style={{display: 'flex'}}>
          <MetricStat value="21:50" label="start" color={Theme.ember} />
          <div style={{width: 1, height: 40, background: 'rgba(255,255,255,0.1)'}} />
          <MetricStat value="12m" label="ritual" />
          <div style={{width: 1, height: 40, background: 'rgba(255,255,255,0.1)'}} />
          <MetricStat value="18m" label="to sleep" color={Theme.mint} />
        </div>
      </Card>

      <Card style={{marginBottom: 16}}>
        <SectionHeader title="Falling asleep" subtitle="Minutes from lights out to asleep." />
        <div style={{marginTop: 14}}>
          <SOLChart progress={chart} />
        </div>
        <div style={{display: 'flex', gap: 14, marginTop: 10, fontSize: 11}}>
          <span style={{color: Theme.secondaryText}}>
            <span
            style={{
              display: 'inline-block',
              width: 14,
              height: 2,
              background: Theme.mint,
              verticalAlign: 'middle',
              marginRight: 5,
            }}
          />
          20m target
          </span>
          <span style={{color: Theme.secondaryText}}>12 nights · 4 blocks</span>
        </div>
      </Card>

      <Card>
        <SectionHeader title="Timing path" subtitle="How EMBER moved your warm-up." />
        <div style={{display: 'flex', gap: 8, marginTop: 12}}>
          {TITRATION.map((b, i) => {
            const on = i === 3;
            return (
              <div
                key={b.block}
                style={{
                  flex: 1,
                  padding: '10px 6px',
                  borderRadius: 12,
                  textAlign: 'center',
                  background: on ? alpha(Theme.ember, 0.18) : 'rgba(255,255,255,0.05)',
                  border: `1px solid ${on ? alpha(Theme.ember, 0.45) : 'rgba(255,255,255,0.08)'}`,
                }}
              >
                <div
                  style={{
                    fontFamily: SFRounded,
                    fontSize: 18,
                    fontWeight: 700,
                    color: on ? Theme.ember : '#fff',
                  }}
                >
                  {b.offset}m
                </div>
                <div style={{fontSize: 9.5, color: Theme.tertiaryText, marginTop: 2}}>
                  before bed
                </div>
              </div>
            );
          })}
        </div>
        <div
          style={{
            marginTop: 12,
            fontSize: 10,
            fontWeight: 700,
            letterSpacing: 0.4,
            color: Theme.amber,
            padding: '4px 9px',
            borderRadius: 100,
            background: alpha(Theme.amber, 0.16),
            display: 'inline-block',
          }}
        >
          HOLD · CONVERGED
        </div>
      </Card>

      {/* ScienceNote */}
      <div
        style={{
          display: 'flex',
          gap: 10,
          padding: 12,
          marginTop: 14,
          borderRadius: 20,
          background: 'rgba(28,31,43,0.96)',
          border: `1px solid ${Theme.hairline}`,
        }}
      >
        <Img
          src={staticFile('skins/moon_blue.png')}
          style={{width: 34, height: 34, objectFit: 'contain', flexShrink: 0}}
        />
        <div style={{fontSize: 12.5, color: Theme.secondaryText, lineHeight: 1.4}}>
          Warming the skin pulls heat away from your core. The drop that follows is
          the same signal your body uses to start sleep.
        </div>
      </div>
    </div>

    <StatusBar />
    <NavBar
      title="Warm-Up"
      leading={
        <div style={{display: 'flex', alignItems: 'center', gap: 3, color: Theme.ember}}>
          <Chevron size={16} color={Theme.ember} style={{transform: 'rotate(180deg)'}} />
          <span style={{fontSize: 16}}>Rest Lab</span>
        </div>
      }
    />
    <TabBar active="lab" />
  </div>
);
