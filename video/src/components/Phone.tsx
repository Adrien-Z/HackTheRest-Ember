import React from 'react';
import {Theme, SF, SFRounded, alpha} from '../theme';
import {MoonStars, Calendar, Sparkles, ShippingBox} from './icons';

/** iPhone 15 Pro logical points — the screen is authored at this size. */
export const SCREEN_W = 393;
export const SCREEN_H = 852;

/**
 * Titanium iPhone body with Dynamic Island, drawn around a 393x852 screen.
 * Children render inside the screen at 1:1 point scale; `scale` blows the whole
 * device up to fill the 1080p stage.
 */
export const Phone: React.FC<{
  children: React.ReactNode;
  scale?: number;
  style?: React.CSSProperties;
  glow?: number;
}> = ({children, scale = 1, style, glow = 1}) => {
  const bezel = 12;
  return (
    <div
      style={{
        width: SCREEN_W + bezel * 2,
        height: SCREEN_H + bezel * 2,
        borderRadius: 66,
        padding: bezel,
        background:
          'linear-gradient(150deg, #6E7480 0%, #2B2F38 22%, #9AA1AD 48%, #33373F 74%, #767D89 100%)',
        boxShadow: `0 60px 120px rgba(0,0,0,0.66), 0 0 ${140 * glow}px ${alpha(
          Theme.ember,
          0.22 * glow,
        )}, inset 0 0 2px rgba(255,255,255,0.5)`,
        transform: `scale(${scale})`,
        transformOrigin: 'center center',
        ...style,
      }}
    >
      <div
        style={{
          width: SCREEN_W,
          height: SCREEN_H,
          borderRadius: 54,
          overflow: 'hidden',
          position: 'relative',
          background: Theme.bg,
          fontFamily: SF,
          color: '#fff',
        }}
      >
        {children}
        <DynamicIsland />
        <HomeIndicator />
      </div>
    </div>
  );
};

const DynamicIsland: React.FC = () => (
  <div
    style={{
      position: 'absolute',
      top: 11,
      left: '50%',
      transform: 'translateX(-50%)',
      width: 124,
      height: 36,
      borderRadius: 18,
      background: '#000',
      zIndex: 60,
    }}
  />
);

const HomeIndicator: React.FC = () => (
  <div
    style={{
      position: 'absolute',
      bottom: 8,
      left: '50%',
      transform: 'translateX(-50%)',
      width: 140,
      height: 5,
      borderRadius: 3,
      background: 'rgba(255,255,255,0.5)',
      zIndex: 60,
    }}
  />
);

/** iOS status bar: time left, signal/wifi/battery right. */
export const StatusBar: React.FC<{time?: string}> = ({time = '22:41'}) => (
  <div
    style={{
      position: 'absolute',
      top: 0,
      left: 0,
      right: 0,
      height: 59,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      padding: '0 30px',
      paddingTop: 12,
      zIndex: 50,
      color: '#fff',
    }}
  >
    <div style={{fontSize: 16, fontWeight: 600, letterSpacing: 0.2, width: 90}}>
      {time}
    </div>
    <div style={{display: 'flex', alignItems: 'center', gap: 6, width: 90, justifyContent: 'flex-end'}}>
      {/* cellular */}
      <svg width="18" height="12" viewBox="0 0 18 12">
        {[0, 1, 2, 3].map((i) => (
          <rect
            key={i}
            x={i * 4.6}
            y={9 - i * 2.7}
            width="3.1"
            height={3 + i * 2.7}
            rx="1"
            fill="#fff"
          />
        ))}
      </svg>
      {/* wifi */}
      <svg width="16" height="12" viewBox="0 0 16 12">
        <path d="M8 10.4 6.1 8.3a2.8 2.8 0 0 1 3.8 0Z" fill="#fff" />
        <path d="M3.6 5.8a6.4 6.4 0 0 1 8.8 0" stroke="#fff" strokeWidth="1.5" fill="none" strokeLinecap="round" />
        <path d="M1.2 3.3a9.9 9.9 0 0 1 13.6 0" stroke="#fff" strokeWidth="1.5" fill="none" strokeLinecap="round" />
      </svg>
      {/* battery */}
      <svg width="25" height="12" viewBox="0 0 25 12">
        <rect x="0.6" y="0.6" width="21" height="10.8" rx="3.2" stroke="rgba(255,255,255,0.42)" strokeWidth="1.1" fill="none" />
        <rect x="2.2" y="2.2" width="15" height="7.6" rx="1.9" fill="#fff" />
        <path d="M23.2 4.2v3.6a2 2 0 0 0 0-3.6Z" fill="rgba(255,255,255,0.42)" />
      </svg>
    </div>
  </div>
);

/** Inline large-title-off nav bar with an optional trailing glyph. */
export const NavBar: React.FC<{
  title: string;
  trailing?: React.ReactNode;
  leading?: React.ReactNode;
}> = ({title, trailing, leading}) => (
  <div
    style={{
      position: 'absolute',
      top: 0,
      left: 0,
      right: 0,
      height: 103,
      display: 'flex',
      alignItems: 'flex-end',
      justifyContent: 'center',
      paddingBottom: 8,
      zIndex: 40,
      // iOS scrolls content *under* the bar, so it needs the same material.
      background: 'rgba(15,18,28,0.7)',
      backdropFilter: 'blur(18px)',
      WebkitBackdropFilter: 'blur(18px)',
      boxShadow: '0 0.5px 0 rgba(255,255,255,0.07)',
    }}
  >
    <div style={{fontSize: 17, fontWeight: 600, letterSpacing: 0.1}}>{title}</div>
    {leading ? (
      <div style={{position: 'absolute', left: 18, bottom: 9}}>{leading}</div>
    ) : null}
    {trailing ? (
      <div style={{position: 'absolute', right: 18, bottom: 9}}>{trailing}</div>
    ) : null}
  </div>
);

export type TabKey = 'today' | 'agenda' | 'lab' | 'box';

const TABS: {key: TabKey; label: string; Icon: React.FC<any>}[] = [
  {key: 'today', label: 'Today', Icon: MoonStars},
  {key: 'agenda', label: 'Agenda', Icon: Calendar},
  {key: 'lab', label: 'Rest Lab', Icon: Sparkles},
  {key: 'box', label: 'Box Space', Icon: ShippingBox},
];

/** iOS 26 floating glass tab bar. */
export const TabBar: React.FC<{active: TabKey}> = ({active}) => (
  <div
    style={{
      position: 'absolute',
      bottom: 22,
      left: 12,
      right: 12,
      height: 62,
      display: 'flex',
      alignItems: 'center',
      borderRadius: 31,
      background: 'rgba(30,33,45,0.72)',
      backdropFilter: 'blur(24px)',
      WebkitBackdropFilter: 'blur(24px)',
      border: '0.75px solid rgba(255,255,255,0.13)',
      boxShadow: '0 12px 30px rgba(0,0,0,0.4)',
      zIndex: 55,
    }}
  >
    {TABS.map(({key, label, Icon}) => {
      const on = key === active;
      return (
        <div
          key={key}
          style={{
            flex: 1,
            display: 'flex',
            flexDirection: 'column',
            alignItems: 'center',
            gap: 3,
          }}
        >
          <Icon size={23} color={on ? Theme.ember : 'rgba(255,255,255,0.52)'} />
          <div
            style={{
              fontSize: 10,
              fontWeight: on ? 600 : 500,
              color: on ? Theme.ember : 'rgba(255,255,255,0.52)',
            }}
          >
            {label}
          </div>
        </div>
      );
    })}
  </div>
);

/** `.emberCard()` — material fill, 20pt continuous radius, hairline stroke. */
export const Card: React.FC<{
  children: React.ReactNode;
  padding?: number;
  radius?: number;
  style?: React.CSSProperties;
}> = ({children, padding = 16, radius = 20, style}) => (
  <div
    style={{
      padding,
      borderRadius: radius,
      background: 'rgba(28,31,43,0.96)',
      border: `1px solid ${Theme.hairline}`,
      ...style,
    }}
  >
    {children}
  </div>
);

/** `MetricStat` — big rounded numeral over a caption. */
export const MetricStat: React.FC<{
  value: string;
  label: string;
  color?: string;
}> = ({value, label, color = '#fff'}) => (
  <div style={{flex: 1, textAlign: 'center'}}>
    <div
      style={{
        fontFamily: SFRounded,
        fontSize: 28,
        fontWeight: 700,
        color,
        letterSpacing: -0.4,
      }}
    >
      {value}
    </div>
    <div style={{fontSize: 12, color: Theme.secondaryText, marginTop: 2}}>{label}</div>
  </div>
);

/** `SectionHeader`. */
export const SectionHeader: React.FC<{title: string; subtitle?: string}> = ({
  title,
  subtitle,
}) => (
  <div style={{marginBottom: 2}}>
    <div style={{fontSize: 20, fontWeight: 600, letterSpacing: -0.3}}>{title}</div>
    {subtitle ? (
      <div style={{fontSize: 15, color: Theme.secondaryText, marginTop: 2}}>
        {subtitle}
      </div>
    ) : null}
  </div>
);

/** `InsightPill`. */
export const Pill: React.FC<{
  children: React.ReactNode;
  color?: string;
  bg?: string;
}> = ({children, color = '#fff', bg}) => (
  <div
    style={{
      display: 'flex',
      alignItems: 'center',
      gap: 5,
      padding: '5px 10px',
      borderRadius: 100,
      background: bg ?? 'rgba(255,255,255,0.09)',
      fontSize: 12,
      fontWeight: 600,
      color,
    }}
  >
    {children}
  </div>
);

export const NightBackground: React.FC = () => (
  <div
    style={{
      position: 'absolute',
      inset: 0,
      background: `linear-gradient(180deg, ${Theme.nightTop} 0%, ${Theme.bg} 100%)`,
    }}
  />
);
