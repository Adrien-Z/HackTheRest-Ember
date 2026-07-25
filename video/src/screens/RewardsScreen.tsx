import React from 'react';
import {interpolate} from 'remotion';
import {Theme, SF, SFRounded, alpha, boxGradient} from '../theme';
import {Card, NavBar, NightBackground, StatusBar} from '../components/Phone';
import {
  BedDouble,
  CheckSeal,
  Gift,
  Layers,
  Lock,
  Tag,
  Thermometer,
  Ticket,
} from '../components/icons';

/** `BlueBoxReward.sample` from Ember/Views/PodView.swift. */
const REWARDS = [
  {
    id: 'n2-pillow',
    title: 'N2 pillow coupon',
    subtitle: 'A softer landing for nights when your routine is on track.',
    cost: 250,
    tint: Theme.mint,
    action: 'Reveal code',
    code: 'N2-EMBER-15',
    Icon: BedDouble,
  },
  {
    id: 'z1-discount',
    title: 'Z1 mattress discount',
    subtitle: 'Use a strong rest month toward a bigger Blue Box upgrade.',
    cost: 600,
    // The deep brand blue is too dark for a label on a dark card, so the row
    // uses the accessible accent while the artwork keeps the brand tone.
    tint: Theme.ember,
    action: 'Reveal code',
    code: 'Z1-SLEEP-10',
    Icon: Tag,
  },
  {
    id: 'topper-credit',
    title: 'Topper upgrade credit',
    subtitle: 'A comfort boost inspired by Blue Box topper-style bedding.',
    cost: 900,
    tint: Theme.amber,
    action: 'Send to email',
    code: null,
    Icon: Layers,
  },
  {
    id: 'routine-kit',
    title: 'Warmth ritual kit',
    subtitle: 'A foot-bath and wind-down perk for protecting bedtime.',
    cost: 1400,
    tint: Theme.cool,
    action: 'Reserve kit',
    code: null,
    Icon: Thermometer,
  },
] as const;

/**
 * `RewardsShopSheet` — Rest Points buy real Blue Box perks. Rows unlock as the
 * balance passes their cost; a claimed row swaps to its code.
 */
export const RewardsScreen: React.FC<{
  /** available Rest Points. */
  points?: number;
  /** 0-1 stagger of the rows. */
  reveal?: number;
  /** id of the reward that has been claimed. */
  claimed?: string | null;
}> = ({points = 1180, reveal = 1, claimed = null}) => (
  <div style={{position: 'absolute', inset: 0, fontFamily: SF}}>
    <NightBackground />

    <div style={{position: 'absolute', top: 112, left: 16, right: 16}}>
      {/* hero */}
      <Card style={{display: 'flex', alignItems: 'center', gap: 14, marginBottom: 16}}>
        <div
          style={{
            width: 72,
            height: 72,
            borderRadius: 36,
            background: alpha(Theme.boxBlue, 0.16),
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            flexShrink: 0,
          }}
        >
          <Gift size={30} color={Theme.boxBlue} />
        </div>
        <div style={{flex: 1}}>
          <div
            style={{
              fontSize: 20,
              fontWeight: 800,
              letterSpacing: -0.3,
              fontVariantNumeric: 'tabular-nums',
            }}
          >
            {Math.round(points).toLocaleString('en-US')} pts available
          </div>
          <div style={{fontSize: 12.5, color: Theme.secondaryText, marginTop: 4, lineHeight: 1.35}}>
            Earn points to unlock skins and redeem Blue Box perks.
          </div>
        </div>
      </Card>

      {/* reward rows */}
      <div style={{display: 'flex', flexDirection: 'column', gap: 10}}>
        {REWARDS.map((r, i) => {
          const t = interpolate(reveal, [i * 0.13, i * 0.13 + 0.42], [0, 1], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
          });
          const unlocked = points >= r.cost;
          const isClaimed = claimed === r.id;
          const {Icon} = r;
          return (
            <div
              key={r.id}
              style={{
                padding: 14,
                borderRadius: 20,
                background: 'rgba(28,31,43,0.96)',
                border: `1px solid ${
                  unlocked ? alpha(r.tint, 0.22) : 'rgba(255,255,255,0.10)'
                }`,
                opacity: t,
                transform: `translateY(${(1 - t) * 16}px)`,
              }}
            >
              <div style={{display: 'flex', gap: 12, alignItems: 'flex-start'}}>
                <div
                  style={{
                    width: 54,
                    height: 54,
                    borderRadius: 16,
                    background: alpha(r.tint, unlocked ? 0.18 : 0.08),
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    flexShrink: 0,
                  }}
                >
                  <Icon size={22} color={unlocked ? r.tint : Theme.tertiaryText} />
                </div>
                <div style={{flex: 1}}>
                  <div style={{display: 'flex', alignItems: 'center', gap: 7}}>
                    <span style={{fontSize: 16, fontWeight: 600}}>{r.title}</span>
                    <span
                      style={{
                        fontSize: 10,
                        fontWeight: 900,
                        color: unlocked ? r.tint : Theme.tertiaryText,
                        padding: '4px 7px',
                        borderRadius: 100,
                        background: 'rgba(255,255,255,0.08)',
                        whiteSpace: 'nowrap',
                      }}
                    >
                      {r.cost.toLocaleString('en-US')} pts
                    </span>
                  </div>
                  <div
                    style={{
                      fontSize: 12.5,
                      color: Theme.secondaryText,
                      marginTop: 4,
                      lineHeight: 1.35,
                    }}
                  >
                    {r.subtitle}
                  </div>
                </div>
              </div>

              {isClaimed ? (
                <div
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    gap: 10,
                    marginTop: 12,
                    padding: 12,
                    borderRadius: 14,
                    background: alpha(Theme.mint, 0.12),
                  }}
                >
                  <CheckSeal size={17} color={Theme.mint} />
                  <div>
                    <div style={{fontSize: 11.5, fontWeight: 700, color: Theme.mint}}>
                      Claimed
                    </div>
                    <div style={{fontSize: 12.5, fontWeight: 600, marginTop: 1}}>
                      Code: {r.code}
                    </div>
                  </div>
                </div>
              ) : (
                <div
                  style={{
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    gap: 7,
                    marginTop: 12,
                    padding: '11px 0',
                    borderRadius: 14,
                    background: unlocked ? boxGradient : 'rgba(255,255,255,0.08)',
                    fontSize: 14,
                    fontWeight: 700,
                    color: unlocked ? '#fff' : Theme.secondaryText,
                  }}
                >
                  {unlocked ? (
                    <Ticket size={15} color="#fff" />
                  ) : (
                    <Lock size={14} color={Theme.secondaryText} />
                  )}
                  {unlocked
                    ? r.action
                    : `${(r.cost - Math.round(points)).toLocaleString('en-US')} pts to go`}
                </div>
              )}
            </div>
          );
        })}
      </div>
    </div>

    <StatusBar />
    <NavBar
      title="Rewards"
      trailing={<span style={{fontSize: 16, color: Theme.ember}}>Done</span>}
    />
  </div>
);
