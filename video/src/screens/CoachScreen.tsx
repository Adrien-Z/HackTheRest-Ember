import React from 'react';
import {Img, interpolate, staticFile} from 'remotion';
import {Theme, SF, SFRounded, alpha} from '../theme';
import {NavBar, NightBackground, StatusBar} from '../components/Phone';
import {Chevron} from '../components/icons';

/** The coach's avatar is the user's own box. */
export const CoachAvatar: React.FC<{size?: number}> = ({size = 34}) => (
  <div
    style={{
      width: size + 10,
      height: size + 10,
      borderRadius: (size + 10) / 2,
      background: 'rgba(28,31,43,0.7)',
      border: `0.8px solid ${alpha(Theme.ember, 0.18)}`,
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      flexShrink: 0,
    }}
  >
    <Img
      src={staticFile('skins/moon_blue.png')}
      style={{width: size, height: size, objectFit: 'contain'}}
    />
  </div>
);

const REPLY =
  'You fall asleep when your core temperature drops. A 12 minute foot bath at 21:50 pulls blood to your skin, and the fall that follows lands right on 22:50.';

const STATS = [
  {label: 'Warm-up', value: '60m', caption: 'before bed'},
  {label: 'Recent', value: '18m', caption: 'to fall asleep'},
  {label: 'Target', value: '20m', caption: 'or less'},
];

/**
 * `CoachView` — a grounded assistant. It is handed the user's plan, calendar,
 * and sleep history, and it answers with inline widgets built from that data
 * rather than plain prose.
 */
export const CoachScreen: React.FC<{
  /** 0-1 reveal of the user's question bubble. */
  ask?: number;
  /** 0-1 of the reply streaming in. */
  stream?: number;
  /** 0-1 of the inline stats widget. */
  widget?: number;
  thinking?: boolean;
}> = ({ask = 1, stream = 1, widget = 1, thinking = false}) => {
  const shown = Math.round(REPLY.length * stream);
  const text = REPLY.slice(0, shown);

  return (
    <div style={{position: 'absolute', inset: 0, fontFamily: SF}}>
      <NightBackground />

      <div style={{position: 'absolute', top: 116, left: 16, right: 16}}>
        {/* user bubble */}
        <div
          style={{
            display: 'flex',
            justifyContent: 'flex-end',
            opacity: ask,
            transform: `translateY(${(1 - ask) * 14}px)`,
          }}
        >
          <div
            style={{
              maxWidth: 280,
              padding: 13,
              borderRadius: 16,
              background: alpha(Theme.ember, 0.9),
              fontSize: 15.5,
              lineHeight: 1.35,
            }}
          >
            Why start warming at 21:50 tonight?
          </div>
        </div>

        {/* coach reply */}
        <div style={{display: 'flex', gap: 9, marginTop: 14, alignItems: 'flex-start'}}>
          <CoachAvatar />
          <div style={{flex: 1}}>
            {thinking ? (
              <div
                style={{
                  display: 'flex',
                  alignItems: 'center',
                  gap: 8,
                  height: 26,
                  fontSize: 13,
                  color: Theme.secondaryText,
                }}
              >
                <div
                  style={{
                    width: 15,
                    height: 15,
                    borderRadius: 8,
                    border: `2px solid ${alpha(Theme.ember, 0.3)}`,
                    borderTopColor: Theme.ember,
                  }}
                />
                Thinking…
              </div>
            ) : (
              <>
                <div
                  style={{
                    padding: 13,
                    borderRadius: 16,
                    background: Theme.card,
                    fontSize: 15.5,
                    lineHeight: 1.42,
                  }}
                >
                  {text}
                  {stream < 1 ? (
                    <span
                      style={{
                        display: 'inline-block',
                        width: 2,
                        height: 15,
                        marginLeft: 2,
                        background: Theme.ember,
                        verticalAlign: 'text-bottom',
                      }}
                    />
                  ) : null}
                </div>

                {/* inline generative widget: a stats row built from the user's data */}
                <div
                  style={{
                    marginTop: 10,
                    padding: 14,
                    borderRadius: 16,
                    background: Theme.card,
                    border: `1px solid ${Theme.hairline}`,
                    opacity: widget,
                    transform: `translateY(${(1 - widget) * 12}px)`,
                  }}
                >
                  <div
                    style={{
                      fontSize: 11,
                      fontWeight: 700,
                      letterSpacing: 0.8,
                      color: Theme.tertiaryText,
                      marginBottom: 11,
                    }}
                  >
                    YOUR THERMAL BLOCK
                  </div>
                  <div style={{display: 'flex'}}>
                    {STATS.map((s, i) => (
                      <div key={s.label} style={{flex: 1, textAlign: 'center'}}>
                        <div
                          style={{
                            fontFamily: SFRounded,
                            fontSize: 23,
                            fontWeight: 700,
                            color: i === 1 ? Theme.mint : '#fff',
                            letterSpacing: -0.6,
                          }}
                        >
                          {s.value}
                        </div>
                        <div style={{fontSize: 11.5, marginTop: 3}}>{s.label}</div>
                        <div style={{fontSize: 10, color: Theme.tertiaryText, marginTop: 1}}>
                          {s.caption}
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              </>
            )}
          </div>
        </div>
      </div>

      {/* suggestion chips */}
      <div
        style={{
          position: 'absolute',
          bottom: 78,
          left: 16,
          right: 0,
          display: 'flex',
          gap: 8,
          opacity: interpolate(widget, [0.4, 1], [0, 1], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
          }),
        }}
      >
        {['Why did my time in bed change?', 'Can I drink tea tonight?'].map((s) => (
          <div
            key={s}
            style={{
              padding: '8px 12px',
              borderRadius: 100,
              background: Theme.card,
              fontSize: 12,
              whiteSpace: 'nowrap',
              flexShrink: 0,
            }}
          >
            {s}
          </div>
        ))}
      </div>

      {/* input bar */}
      <div
        style={{
          position: 'absolute',
          bottom: 20,
          left: 16,
          right: 16,
          display: 'flex',
          alignItems: 'center',
          gap: 10,
        }}
      >
        <div
          style={{
            flex: 1,
            padding: 12,
            borderRadius: 16,
            background: Theme.card,
            fontSize: 15,
            color: Theme.tertiaryText,
          }}
        >
          Ask about your plan…
        </div>
        <svg width="30" height="30" viewBox="0 0 24 24">
          <circle cx="12" cy="12" r="11" fill={Theme.ember} />
          <path
            d="M12 17V7.6M12 7.6 7.8 11.8M12 7.6l4.2 4.2"
            stroke="#fff"
            strokeWidth="2"
            fill="none"
            strokeLinecap="round"
            strokeLinejoin="round"
          />
        </svg>
      </div>

      <StatusBar />
      <NavBar
        title="Rest Coach"
        leading={
          <div style={{display: 'flex', alignItems: 'center', gap: 3, color: Theme.ember}}>
            <Chevron size={16} color={Theme.ember} style={{transform: 'rotate(180deg)'}} />
            <span style={{fontSize: 16}}>EMBER</span>
          </div>
        }
      />
    </div>
  );
};
