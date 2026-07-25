import React from 'react';
import {Img, interpolate, spring, staticFile} from 'remotion';
import {Theme, SF, SFRounded, alpha, mapGradient} from '../theme';
import {StatusBar, TabBar} from '../components/Phone';
import {Gift, PersonClock, PersonPlus} from '../components/icons';

type Person = {
  name: string;
  skin: string;
  pts: number;
  rank: number;
  x: number;
  y: number;
  me?: boolean;
};

/**
 * `BoxWorldLayout` — the current user holds the centre, friends fill the first
 * ring at six evenly spaced slots starting at twelve o'clock.
 */
// Slightly elliptical: the tiles are taller than they are wide, so the ring is
// stretched vertically to keep the labels from touching.
const RING_X = 132;
const RING_Y = 158;
const slot = (i: number) => {
  const angle = -Math.PI / 2 + i * ((2 * Math.PI) / 6);
  return {x: Math.cos(angle) * RING_X, y: Math.sin(angle) * RING_Y};
};

export const PEOPLE: Person[] = [
  {name: 'Alex', skin: 'moon_blue', pts: 2140, rank: 2, x: 0, y: 0, me: true},
  {name: 'Priya', skin: 'royal_blue', pts: 2480, rank: 1, ...slot(0)},
  {name: 'Sam', skin: 'cozy_blue', pts: 1970, rank: 3, ...slot(1)},
  {name: 'Théo', skin: 'happy_blue', pts: 1640, rank: 5, ...slot(2)},
  {name: 'Mira', skin: 'sleepy_blue', pts: 1495, rank: 6, ...slot(3)},
  {name: 'Noor', skin: 'dream_blue', pts: 1815, rank: 4, ...slot(4)},
  {name: 'Jonas', skin: 'story_blue', pts: 1320, rank: 7, ...slot(5)},
];

/**
 * `BoxResident` — the box, then the name and monthly points stacked under it.
 * The current user's tile sits on a soft blue plate and glows.
 */
const BoxAvatar: React.FC<{
  person: Person;
  pop: number;
  bob: number;
}> = ({person, pop, bob}) => (
  <div
    style={{
      position: 'absolute',
      left: `calc(50% + ${person.x}px)`,
      top: `calc(50% + ${person.y}px)`,
      transform: `translate(-50%, -50%) scale(${pop}) translateY(${bob}px)`,
      width: 112,
      padding: '6px 0',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      gap: 5,
      opacity: Math.min(1, pop * 1.6),
      borderRadius: 16,
      background: person.me ? alpha(Theme.boxBlue, 0.08) : 'transparent',
    }}
  >
    <Img
      src={staticFile(`skins/${person.skin}.png`)}
      style={{
        width: person.me ? 100 : 90,
        height: person.me ? 100 : 90,
        objectFit: 'contain',
        filter: person.me
          ? `drop-shadow(0 5px 12px ${alpha(Theme.boxBlue, 0.55)})`
          : 'drop-shadow(0 5px 5px rgba(0,0,0,0.25))',
      }}
    />
    <div style={{fontSize: 12, fontWeight: 600, lineHeight: 1}}>
      {person.me ? 'You' : person.name}
    </div>
    <div style={{fontSize: 11, color: Theme.secondaryText, lineHeight: 1}}>
      {person.pts.toLocaleString('en-US')} pts
    </div>
  </div>
);

/**
 * `BoxMapFloor` — a faint 54pt grid with dashed concentric rings marking each
 * ring of the world, and a dot at the centre.
 */
const MapFloor: React.FC = () => (
  <div style={{position: 'absolute', inset: 0, overflow: 'hidden'}}>
    <svg width="100%" height="100%">
      <defs>
        <pattern id="floorGrid" width="54" height="54" patternUnits="userSpaceOnUse">
          <path d="M54 0H0V54" fill="none" stroke="rgba(255,255,255,0.025)" strokeWidth="1" />
        </pattern>
      </defs>
      <rect width="100%" height="100%" fill="url(#floorGrid)" />
    </svg>
    {[150, 300].map((r, i) => (
      <div
        key={r}
        style={{
          position: 'absolute',
          left: '50%',
          top: '50%',
          width: r * 2,
          height: r * 2,
          marginLeft: -r,
          marginTop: -r,
          borderRadius: '50%',
          border: `1px dashed ${alpha(Theme.boxBlue, i === 0 ? 0.1 : 0.055)}`,
        }}
      />
    ))}
    <div
      style={{
        position: 'absolute',
        left: '50%',
        top: '50%',
        width: 22,
        height: 22,
        marginLeft: -11,
        marginTop: -11,
        borderRadius: '50%',
        background: alpha(Theme.boxBlue, 0.08),
      }}
    />
  </div>
);

/**
 * `BoxSpaceView` — the friend map. Everyone is a Blue Box; the size of your
 * month's sleep points sets your rank, and skins are the reward.
 */
export const BoxSpaceScreen: React.FC<{
  frame?: number;
  /** 0-1 stagger of the boxes popping in. */
  pop?: number;
  /** live score readout. */
  points?: number;
  /** map pan in points. */
  panX?: number;
  panY?: number;
  fps?: number;
  rewardsPressed?: boolean;
}> = ({
  frame = 0,
  pop = 1,
  points = 2140,
  panX = 0,
  panY = 0,
  fps = 30,
  rewardsPressed = false,
}) => (
  <div style={{position: 'absolute', inset: 0, fontFamily: SF, background: mapGradient}}>
    {/* world */}
    <div
      style={{
        position: 'absolute',
        inset: 0,
        transform: `translate(${panX}px, ${panY}px)`,
      }}
    >
      <MapFloor />
      <div
        style={{
          position: 'absolute',
          left: '50%',
          top: '50%',
          width: 420,
          height: 420,
          marginLeft: -210,
          marginTop: -210,
          borderRadius: '50%',
          background: `radial-gradient(circle, ${alpha(Theme.ember, 0.13)} 0%, transparent 68%)`,
        }}
      />
      {PEOPLE.map((p, i) => {
        const delay = i * 3;
        const s = spring({
          frame: frame - delay,
          fps,
          config: {damping: 12, mass: 0.7},
        });
        const bob = Math.sin((frame + i * 22) / 26) * 3.5;
        return (
          <BoxAvatar key={p.name} person={p} pop={Math.min(s, pop === 1 ? 1 : pop)} bob={bob} />
        );
      })}
    </div>

    {/* floating score card */}
    <div
      style={{
        position: 'absolute',
        top: 68,
        left: 16,
        right: 16,
        display: 'flex',
        alignItems: 'center',
        gap: 13,
        padding: '11px 14px',
        borderRadius: 22,
        background: 'rgba(30,34,48,0.72)',
        backdropFilter: 'blur(24px)',
        WebkitBackdropFilter: 'blur(24px)',
        border: '0.75px solid rgba(255,255,255,0.13)',
        boxShadow: '0 7px 14px rgba(0,0,0,0.22)',
        zIndex: 30,
      }}
    >
      <Img
        src={staticFile('skins/moon_blue.png')}
        style={{width: 44, height: 44, objectFit: 'contain'}}
      />
      <div>
        <div style={{display: 'flex', alignItems: 'center', gap: 6}}>
          <span style={{fontSize: 15, fontWeight: 700}}>Alex</span>
          <span style={{fontSize: 11, fontWeight: 600, color: Theme.secondaryText}}>June</span>
        </div>
        <div style={{display: 'flex', alignItems: 'baseline', gap: 4, marginTop: 2}}>
          <span style={{fontFamily: SFRounded, fontSize: 20, fontWeight: 700}}>
            {Math.round(points).toLocaleString('en-US')}
          </span>
          <span style={{fontSize: 11, fontWeight: 600, color: Theme.secondaryText}}>
            sleep pts
          </span>
        </div>
      </div>
      <div style={{flex: 1}} />
      <div style={{width: 1, height: 34, background: 'rgba(255,255,255,0.14)'}} />
      <div style={{textAlign: 'right'}}>
        <div style={{fontSize: 12, fontWeight: 700}}>Rank #2</div>
        <div style={{fontSize: 11, color: Theme.secondaryText, marginTop: 1}}>
          Resets in 9d
        </div>
      </div>
    </div>

    {/* social actions */}
    <div style={{position: 'absolute', top: 148, left: 16, display: 'flex', gap: 8, zIndex: 30}}>
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 6,
          padding: '8px 12px',
          borderRadius: 100,
          background: 'rgba(30,34,48,0.72)',
          backdropFilter: 'blur(20px)',
          border: '0.75px solid rgba(255,255,255,0.13)',
          fontSize: 12.5,
          fontWeight: 600,
        }}
      >
        <PersonClock size={14} color="#fff" />
        Requests
        <span
          style={{
            fontFamily: SFRounded,
            fontSize: 10,
            fontWeight: 700,
            minWidth: 16,
            height: 16,
            borderRadius: 8,
            background: Theme.boxBlue,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            padding: '0 4px',
          }}
        >
          2
        </span>
      </div>
      <div
        style={{
          width: 34,
          height: 34,
          borderRadius: 17,
          background: 'rgba(30,34,48,0.72)',
          backdropFilter: 'blur(20px)',
          border: '0.75px solid rgba(255,255,255,0.13)',
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        <PersonPlus size={16} color="#fff" />
      </div>
      <div style={{flex: 1}} />
      {/* Blue Box rewards */}
      <div
        style={{
          display: 'flex',
          alignItems: 'center',
          gap: 6,
          padding: '8px 12px',
          borderRadius: 100,
          background: rewardsPressed ? Theme.boxBlue : 'rgba(30,34,48,0.72)',
          backdropFilter: 'blur(20px)',
          border: `0.75px solid ${
            rewardsPressed ? alpha(Theme.boxBlue, 0.9) : 'rgba(255,255,255,0.13)'
          }`,
          boxShadow: rewardsPressed ? `0 0 34px ${alpha(Theme.boxBlue, 0.6)}` : 'none',
          fontSize: 12.5,
          fontWeight: 600,
          transform: `scale(${rewardsPressed ? 0.95 : 1})`,
        }}
      >
        <Gift size={14} color="#fff" />
        Rewards
      </div>
    </div>

    <StatusBar />
    <TabBar active="box" />
  </div>
);

/** `BoxDecorationStudio` — the collectible skins, unlocked with Rest Points. */
export const DecorationStudioScreen: React.FC<{
  reveal?: number;
  selected?: number;
}> = ({reveal = 1, selected = 0}) => {
  const skins = [
    {id: 'moon_blue', name: 'Moon', cost: 0},
    {id: 'cozy_blue', name: 'Cozy', cost: 400},
    {id: 'royal_blue', name: 'Royal', cost: 900},
    {id: 'dream_blue', name: 'Dream', cost: 1200},
    {id: 'happy_blue', name: 'Happy', cost: 600},
    {id: 'sleepy_blue', name: 'Sleepy', cost: 800},
    {id: 'story_blue', name: 'Story', cost: 1500},
    {id: 'beauty_blue', name: 'Beauty', cost: 1800},
    {id: 'foodie_blue', name: 'Foodie', cost: 2000},
  ];
  return (
    <div style={{position: 'absolute', inset: 0, fontFamily: SF}}>
      <div style={{position: 'absolute', inset: 0, background: mapGradient}} />
      <div style={{position: 'absolute', top: 118, left: 0, right: 0, textAlign: 'center'}}>
        <Img
          src={staticFile(`skins/${skins[selected].id}.png`)}
          style={{
            width: 168,
            height: 168,
            objectFit: 'contain',
            filter: `drop-shadow(0 0 40px ${alpha(Theme.boxBlue, 0.75)})`,
          }}
        />
        <div style={{fontSize: 22, fontWeight: 700, marginTop: 2}}>
          {skins[selected].name}
        </div>
        <div style={{fontSize: 13, color: Theme.secondaryText, marginTop: 3}}>
          Unlocked with Rest Points
        </div>
      </div>
      <div
        style={{
          position: 'absolute',
          top: 396,
          left: 16,
          right: 16,
          display: 'grid',
          gridTemplateColumns: 'repeat(3, 1fr)',
          gap: 10,
        }}
      >
        {skins.map((s, i) => {
          const t = interpolate(reveal, [i * 0.07, i * 0.07 + 0.35], [0, 1], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
          });
          const on = i === selected;
          return (
            <div
              key={s.id}
              style={{
                height: 100,
                borderRadius: 18,
                background: on ? alpha(Theme.boxBlue, 0.26) : 'rgba(255,255,255,0.055)',
                border: `1px solid ${on ? Theme.boxBlue : 'rgba(255,255,255,0.1)'}`,
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                justifyContent: 'center',
                opacity: t,
                transform: `scale(${0.86 + t * 0.14})`,
              }}
            >
              <Img
                src={staticFile(`skins/${s.id}.png`)}
                style={{width: 58, height: 58, objectFit: 'contain'}}
              />
              <div style={{fontSize: 10, fontWeight: 600, color: Theme.secondaryText}}>
                {s.cost === 0 ? 'Owned' : `${s.cost} pts`}
              </div>
            </div>
          );
        })}
      </div>

      <StatusBar />
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
        }}
      >
        <span style={{fontSize: 17, fontWeight: 600}}>Decorate Box</span>
      </div>
      <TabBar active="box" />
    </div>
  );
};
