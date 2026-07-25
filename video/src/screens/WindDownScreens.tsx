import React from 'react';
import {Img, interpolate, staticFile} from 'remotion';
import {Theme, SF, SFRounded, alpha} from '../theme';
import {Card, NavBar, NightBackground, StatusBar} from '../components/Phone';
import {
  ArrowDown,
  ArrowUp,
  BellBadge,
  CheckCircle,
  Info,
  Mic,
  Plus,
  Rotate,
} from '../components/icons';

// ── Cyclic Sigh ─────────────────────────────────────────────────────────────
// Port of `CyclicSighPhase` from Ember/Views/RestToolsViews.swift.

const INHALE = 1.8;
const TOP_UP = 0.9;
const EXHALE = 5.3;
const CYCLE = INHALE + TOP_UP + EXHALE;

export type SighPhase = {
  id: 'inhale' | 'topUp' | 'exhale';
  title: string;
  subtitle: string;
  tint: string;
  phaseProgress: number;
  breathFill: number;
  lungScale: number;
  mascotOffset: number;
  rotation: number;
  secondsRemaining: number;
};

export const sighPhase = (elapsed: number): SighPhase => {
  const pos = elapsed % CYCLE;
  let id: SighPhase['id'];
  let phaseElapsed: number;
  let phaseDuration: number;
  if (pos < INHALE) {
    id = 'inhale';
    phaseElapsed = pos;
    phaseDuration = INHALE;
  } else if (pos < INHALE + TOP_UP) {
    id = 'topUp';
    phaseElapsed = pos - INHALE;
    phaseDuration = TOP_UP;
  } else {
    id = 'exhale';
    phaseElapsed = pos - INHALE - TOP_UP;
    phaseDuration = EXHALE;
  }
  const phaseProgress = Math.min(1, Math.max(0, phaseElapsed / phaseDuration));
  const breathFill =
    id === 'inhale'
      ? 0.25 + phaseProgress * 0.55
      : id === 'topUp'
        ? 0.8 + phaseProgress * 0.2
        : 1 - phaseProgress * 0.76;
  const rotation =
    id === 'inhale'
      ? phaseProgress * 8
      : id === 'topUp'
        ? 8 + phaseProgress * 6
        : 14 - phaseProgress * 20;
  return {
    id,
    title: id === 'inhale' ? 'Inhale' : id === 'topUp' ? 'Top up' : 'Long exhale',
    subtitle:
      id === 'inhale'
        ? 'Fill the lungs gently'
        : id === 'topUp'
          ? 'Tiny second sip of air'
          : 'Let the body drop',
    tint: id === 'inhale' ? Theme.cool : id === 'topUp' ? Theme.amber : Theme.mint,
    phaseProgress,
    breathFill,
    lungScale: 0.82 + breathFill * 0.34,
    mascotOffset: -18 + breathFill * 24,
    rotation,
    secondsRemaining: Math.max(1, Math.ceil(phaseDuration - phaseElapsed)),
  };
};

/**
 * `BreathingTrainingView` — the cyclic sigh. Two inhales and one long exhale,
 * with the user's box rising and falling on the breath.
 */
export const CyclicSighScreen: React.FC<{
  /** seconds into the session. */
  elapsed?: number;
  /** 0-1 fade of the whole panel. */
  reveal?: number;
}> = ({elapsed = 0, reveal = 1}) => {
  const p = sighPhase(elapsed);
  const target = 5 * 60;
  const progress = Math.min(1, elapsed / target);
  const left = Math.max(0, target - elapsed);
  const mm = Math.floor(left / 60);
  const ss = Math.floor(left % 60);

  return (
    <div style={{position: 'absolute', inset: 0, fontFamily: SF, opacity: reveal}}>
      <NightBackground />

      {/* header: title + 5 minute progress ring */}
      <div
        style={{
          position: 'absolute',
          top: 132,
          left: 24,
          right: 24,
          display: 'flex',
          alignItems: 'center',
        }}
      >
        <div style={{flex: 1}}>
          <div style={{fontSize: 22, fontWeight: 700, letterSpacing: -0.4}}>Downshift</div>
          <div style={{fontSize: 13, color: Theme.secondaryText, marginTop: 3}}>
            {elapsed < 1 ? 'Five slow minutes' : 'Follow the box'}
          </div>
        </div>
        <div style={{position: 'relative', width: 58, height: 58}}>
          <svg width="58" height="58" style={{transform: 'rotate(-90deg)'}}>
            <circle cx="29" cy="29" r="26" stroke="rgba(255,255,255,0.10)" strokeWidth="6" fill="none" />
            <circle
              cx="29"
              cy="29"
              r="26"
              stroke={Theme.mint}
              strokeWidth="6"
              fill="none"
              strokeLinecap="round"
              strokeDasharray={2 * Math.PI * 26}
              strokeDashoffset={2 * Math.PI * 26 * (1 - progress)}
            />
          </svg>
          <div
            style={{
              position: 'absolute',
              inset: 0,
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              fontSize: 12,
              fontWeight: 700,
              fontVariantNumeric: 'tabular-nums',
            }}
          >
            {mm}:{String(ss).padStart(2, '0')}
          </div>
        </div>
      </div>

      {/* the breath itself */}
      <div
        style={{
          position: 'absolute',
          top: 232,
          left: 0,
          right: 0,
          height: 300,
          display: 'flex',
          alignItems: 'center',
          justifyContent: 'center',
        }}
      >
        {/* rotating halo frames */}
        {[0, 1, 2, 3].map((i) => (
          <div
            key={i}
            style={{
              position: 'absolute',
              width: 210 + i * 30,
              height: 210 + i * 30,
              borderRadius: 46,
              border: `1px solid ${alpha(p.tint, 0.2)}`,
              transform: `rotate(${i * 12 + p.rotation}deg) scale(${
                0.9 + p.breathFill * 0.16 + i * 0.025
              })`,
              opacity: 0.88 - i * 0.16,
            }}
          />
        ))}
        {/* lungs */}
        <div
          style={{
            position: 'absolute',
            width: 188,
            height: 188,
            borderRadius: '50%',
            background: alpha(Theme.mint, 0.1),
            transform: `scale(${p.lungScale + 0.12})`,
          }}
        />
        <div
          style={{
            position: 'absolute',
            width: 210,
            height: 210,
            borderRadius: '50%',
            border: `1.2px solid ${alpha(Theme.mint, 0.28)}`,
            transform: `scale(${p.lungScale})`,
          }}
        />
        <div
          style={{
            position: 'absolute',
            width: 156,
            height: 156,
            borderRadius: '50%',
            border: `7px solid ${alpha(p.tint, 0.78)}`,
            boxShadow: `0 0 16px ${alpha(p.tint, 0.32)}`,
            transform: `scale(${p.lungScale})`,
          }}
        />
        <Img
          src={staticFile('skins/moon_blue.png')}
          style={{
            position: 'absolute',
            width: 92,
            height: 92,
            objectFit: 'contain',
            transform: `scale(${0.9 + p.breathFill * 0.18}) translateY(${p.mascotOffset}px)`,
          }}
        />
      </div>

      {/* phase readout */}
      <div style={{position: 'absolute', top: 528, left: 0, right: 0, textAlign: 'center'}}>
        <div
          style={{
            fontFamily: SFRounded,
            fontSize: 23,
            fontWeight: 800,
            color: p.tint,
          }}
        >
          {p.title}
        </div>
        <div style={{fontSize: 14, fontWeight: 600, color: Theme.secondaryText, marginTop: 4}}>
          {p.subtitle}
        </div>
        <div
          style={{
            fontFamily: SFRounded,
            fontSize: 44,
            fontWeight: 800,
            marginTop: 4,
            fontVariantNumeric: 'tabular-nums',
          }}
        >
          {p.secondsRemaining}s
        </div>
      </div>

      {/* phase track */}
      <div
        style={{
          position: 'absolute',
          bottom: 108,
          left: 24,
          right: 24,
          padding: 14,
          borderRadius: 18,
          background: 'rgba(28,31,43,0.72)',
        }}
      >
        <div style={{display: 'flex', gap: 8}}>
          {(['inhale', 'topUp', 'exhale'] as const).map((id) => {
            const on = id === p.id;
            return (
              <div
                key={id}
                style={{
                  flex: 1,
                  height: 8,
                  borderRadius: 4,
                  background: on ? p.tint : 'rgba(255,255,255,0.12)',
                  overflow: 'hidden',
                }}
              >
                {on ? (
                  <div
                    style={{
                      height: '100%',
                      width: `${p.phaseProgress * 100}%`,
                      background: 'rgba(255,255,255,0.34)',
                    }}
                  />
                ) : null}
              </div>
            );
          })}
        </div>
        <div
          style={{
            display: 'flex',
            justifyContent: 'space-between',
            marginTop: 8,
            fontSize: 10.5,
            fontWeight: 600,
            color: Theme.secondaryText,
          }}
        >
          <span style={{display: 'flex', alignItems: 'center', gap: 4}}>
            <ArrowDown size={11} color={Theme.secondaryText} />
            Inhale
          </span>
          <span style={{display: 'flex', alignItems: 'center', gap: 4}}>
            <Plus size={11} color={Theme.secondaryText} />
            Top up
          </span>
          <span style={{display: 'flex', alignItems: 'center', gap: 4}}>
            <ArrowUp size={11} color={Theme.secondaryText} />
            Exhale
          </span>
        </div>
      </div>

      {/* controls */}
      <div
        style={{
          position: 'absolute',
          bottom: 38,
          left: 24,
          right: 24,
          display: 'flex',
          gap: 10,
        }}
      >
        <div
          style={{
            flex: 1,
            height: 52,
            borderRadius: 13,
            background: Theme.mint,
            color: '#08130E',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: 8,
            fontSize: 16,
            fontWeight: 600,
          }}
        >
          Pause
        </div>
        <div
          style={{
            width: 52,
            height: 52,
            borderRadius: 13,
            border: `1px solid ${Theme.hairline}`,
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
          }}
        >
          <Rotate size={18} color={Theme.secondaryText} />
        </div>
      </div>

      <StatusBar />
      <NavBar title="Cyclic Sigh" trailing={<Info size={20} color={Theme.ember} />} />
    </div>
  );
};

// ── Mind Dump ───────────────────────────────────────────────────────────────

const DUMP =
  'I keep replaying the Q3 numbers, and I still have not booked the dentist.';
const REPLY =
  'Both of those are tomorrow problems. I have written them down, so you can stop holding them.';

const REMINDERS = ['Re-check the Q3 numbers with Priya', 'Book the dentist'];

/**
 * `MindDumpCoachView` — say what is keeping you up, by voice or text. EMBER
 * parks it and hands it back as a reminder in the morning.
 */
export const MindDumpScreen: React.FC<{
  /** 0-1 of the user's dictated text appearing. */
  dictate?: number;
  recording?: boolean;
  sent?: boolean;
  thinking?: boolean;
  /** 0-1 of the coach reply streaming. */
  stream?: number;
  /** 0-1 of the tomorrow reminder card. */
  reminder?: number;
}> = ({
  dictate = 1,
  recording = false,
  sent = false,
  thinking = false,
  stream = 1,
  reminder = 1,
}) => {
  // The composer clears the moment it is sent, as it does in the app.
  const draft = sent ? '' : DUMP.slice(0, Math.round(DUMP.length * dictate));
  const replyText = REPLY.slice(0, Math.round(REPLY.length * stream));

  return (
    <div style={{position: 'absolute', inset: 0, fontFamily: SF}}>
      <NightBackground />

      <div style={{position: 'absolute', top: 116, left: 16, right: 16}}>
        <Card padding={12} style={{display: 'flex', gap: 13, alignItems: 'center'}}>
          <Img
            src={staticFile('skins/moon_blue.png')}
            style={{width: 58, height: 58, objectFit: 'contain'}}
          />
          <div style={{flex: 1}}>
            <div style={{fontSize: 16, fontWeight: 600}}>Brain dump, then park it</div>
            <div style={{fontSize: 12.5, color: Theme.secondaryText, marginTop: 3, lineHeight: 1.35}}>
              EMBER keeps the thread here and reminds you tomorrow morning.
            </div>
          </div>
        </Card>

        {/* tomorrow reminder card */}
        {reminder > 0 ? (
          <div
            style={{
              marginTop: 12,
              opacity: reminder,
              transform: `translateY(${(1 - reminder) * 16}px)`,
            }}
          >
            <Card padding={12}>
              <div style={{display: 'flex', alignItems: 'center', gap: 8, marginBottom: 10}}>
                <BellBadge size={16} color={Theme.amber} />
                <span style={{fontSize: 14, fontWeight: 700}}>Tomorrow reminder</span>
                <div style={{flex: 1}} />
                <span style={{fontSize: 12, fontWeight: 700, color: Theme.secondaryText}}>
                  09:30
                </span>
              </div>
              {REMINDERS.map((item, i) => {
                const t = interpolate(reminder, [0.35 + i * 0.22, 0.75 + i * 0.22], [0, 1], {
                  extrapolateLeft: 'clamp',
                  extrapolateRight: 'clamp',
                });
                return (
                  <div
                    key={item}
                    style={{
                      display: 'flex',
                      gap: 9,
                      alignItems: 'flex-start',
                      padding: '8px 10px',
                      marginBottom: 8,
                      borderRadius: 12,
                      background: 'rgba(255,255,255,0.07)',
                      opacity: t,
                      transform: `translateX(${(1 - t) * -10}px)`,
                    }}
                  >
                    <div style={{marginTop: 1}}>
                      <CheckCircle size={13} color={Theme.mint} />
                    </div>
                    <span style={{fontSize: 12.5, fontWeight: 600, lineHeight: 1.35}}>{item}</span>
                  </div>
                );
              })}
            </Card>
          </div>
        ) : null}

        {/* the dump, once sent */}
        {sent ? (
          <div style={{display: 'flex', justifyContent: 'flex-end', marginTop: 12}}>
            <div
              style={{
                maxWidth: 280,
                padding: 12,
                borderRadius: 16,
                background: alpha(Theme.amber, 0.9),
                color: '#1A1206',
                fontSize: 14.5,
                lineHeight: 1.35,
                fontWeight: 500,
              }}
            >
              {DUMP}
            </div>
          </div>
        ) : null}

        {thinking ? (
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 8,
              marginTop: 12,
              fontSize: 13,
              color: Theme.secondaryText,
            }}
          >
            <div
              style={{
                width: 15,
                height: 15,
                borderRadius: 8,
                border: `2px solid ${alpha(Theme.amber, 0.3)}`,
                borderTopColor: Theme.amber,
              }}
            />
            Sorting…
          </div>
        ) : null}

        {stream > 0 ? (
          <div style={{display: 'flex', gap: 9, marginTop: 12, alignItems: 'flex-start'}}>
            <Img
              src={staticFile('skins/moon_blue.png')}
              style={{width: 34, height: 34, objectFit: 'contain', flexShrink: 0}}
            />
            <div
              style={{
                flex: 1,
                padding: 12,
                borderRadius: 16,
                background: Theme.card,
                fontSize: 14.5,
                lineHeight: 1.4,
              }}
            >
              {replyText}
            </div>
          </div>
        ) : null}
      </div>

      {/* input bar with dictation */}
      <div style={{position: 'absolute', bottom: 20, left: 16, right: 16}}>
        <div style={{display: 'flex', alignItems: 'flex-end', gap: 10}}>
          <div
            style={{
              flex: 1,
              minHeight: 48,
              padding: '13px 12px',
              borderRadius: 16,
              background: Theme.card,
              fontSize: 14.5,
              lineHeight: 1.35,
              color: draft ? '#fff' : Theme.tertiaryText,
            }}
          >
            {draft || 'What’s on your mind?'}
          </div>
          <div
            style={{
              width: 34,
              height: 34,
              borderRadius: 17,
              background: recording ? alpha(Theme.mint, 0.16) : 'rgba(255,255,255,0.06)',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              flexShrink: 0,
            }}
          >
            <Mic size={18} color={recording ? Theme.mint : Theme.secondaryText} />
          </div>
          <svg width="30" height="30" viewBox="0 0 24 24" style={{flexShrink: 0}}>
            <circle cx="12" cy="12" r="11" fill={Theme.amber} />
            <path
              d="M12 17V7.6M12 7.6 7.8 11.8M12 7.6l4.2 4.2"
              stroke="#1A1206"
              strokeWidth="2"
              fill="none"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
        </div>
        {recording ? (
          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: 7,
              marginTop: 8,
              paddingLeft: 6,
              fontSize: 12,
              fontWeight: 600,
              color: Theme.secondaryText,
            }}
          >
            <svg width="15" height="12" viewBox="0 0 15 12">
              {[3, 7, 11, 6, 9, 4].map((h, i) => (
                <rect
                  key={i}
                  x={i * 2.5}
                  y={6 - h / 2}
                  width="1.6"
                  height={h}
                  rx="0.8"
                  fill={Theme.mint}
                />
              ))}
            </svg>
            Listening… tap stop, then edit or send.
          </div>
        ) : null}
      </div>

      <StatusBar />
      <NavBar title="Mind Dump" trailing={<Rotate size={18} color={Theme.ember} />} />
    </div>
  );
};
