# EMBER — demo video (Remotion)

A 102-second product film for the EMBER iOS app, rendered at 1920×1080 / 30fps.
Every screen is a React re-creation of the real SwiftUI view — same palette,
same type scale, same components — so nothing here is a screenshot that can go
stale.

```bash
npm install    # node_modules is not committed; run this first
npm start      # Remotion Studio, to scrub, tweak copy, see changes live
npm run build  # renders out/ember-demo.mp4
```

## The cut

| Time | Beat | On screen |
| --- | --- | --- |
| 0:00–0:07 | Hook | The clock crawls 23:00 → 01:47, then EMBER's plan answers it. Wordless. |
| 0:07–0:21 | Daily Rhythm | `HomeView`: the Daily Rhythm curve sweeping sunrise to sunrise, the wake alarm toggle, and the Sleep Score card with its bobbing `InsightMascot`. |
| 0:21–0:31 | Rest Coach | `CoachView`: a question is asked, the reply streams in, and an inline stats widget builds itself from the user's own numbers. |
| 0:31–0:43 | Agenda | `AgendaView`: the redesigned `PlanBanner`, the circadian energy ribbon over the real calendar, the sleep-climate badge, and the night dragging with the plan following. |
| 0:43–0:54 | Rest Lab | The 2×2 wind-down grid, then a push to the Warm-Up detail and the titration path 30m → 60m. |
| 0:54–1:05 | Cyclic Sigh | `BreathingTrainingView`: two inhales, one long exhale, the box rising and falling on the breath. |
| 1:05–1:16 | Mind Dump | `MindDumpCoachView`: dictation, the coach sorting it, and the 09:30 reminder card landing. |
| 1:16–1:26 | Box Space | The friend map on its new grid floor, sleep points, and the collectible skins. |
| 1:26–1:35 | Rewards | `RewardsShopSheet`: Rest Points spent on real Blue Box perks, and a code claimed. |
| 1:35–1:42 | Finale | The Blue Box mascot, EMBER, "Rest that adapts to you." |

It is caption-driven and works muted. There is no voiceover, by design.

The mascot appears in the hook, the Home greeting and Sleep Score card, the
Coach avatar, the Agenda plan banner, the Rest Lab hero and science note, the
centre of the Cyclic Sigh, the Mind Dump hero and replies, all of Box Space,
and the finale.

## Adding music

The render currently has no audio track. Drop a file at `public/music.mp3` and
add this inside `EmberDemo.tsx`'s `<AbsoluteFill>`:

```tsx
import {Audio, staticFile} from 'remotion';

<Audio src={staticFile('music.mp3')} volume={(f) =>
  interpolate(f, [0, 45, 2940, 3064], [0, 0.55, 0.55, 0], {extrapolateRight: 'clamp'})
} />
```

The fade-out at the end lands with the wordmark. Something ambient at
70–80 BPM suits the pacing; anything with a hard beat will fight it.

## Where the fidelity comes from

- `src/theme.ts` — `Ember/Theme/Theme.swift` converted to hex, one for one.
- `src/components/Phone.tsx` — iPhone 15 Pro at 393×852 logical points, iOS
  status bar, the floating glass tab bar, and `.emberCard()`.
- `src/components/icons.tsx` — SF Symbol stand-ins drawn to match the symbols
  the app actually references.
- `src/screens/AgendaScreen.tsx` — the alertness curve is a direct port of
  `CircadianModel.wakeControlPoints`, so the energy ribbon has the real shape.
- `src/screens/DailyRhythm.tsx` — a direct port of `DailyRhythmView.swift`: same
  `RhythmGeometry` (horizon at 0.52, amplitude at 0.30, the sunrise-anchored
  angle mapping), same three sky glows, same arc gradients and marker placement
  logic including the edge clamping. Sunrise and sunset use `WeatherManager`'s
  defaults, 05:08 and 21:00.
- `src/screens/WindDownScreens.tsx` — `sighPhase()` is a direct port of
  `CyclicSighPhase`, same 1.8s / 0.9s / 5.3s cycle, same `breathFill` and
  `lungScale` curves, so the box breathes at exactly the app's rhythm.
- `src/screens/RewardsScreen.tsx` — the four rewards are `BlueBoxReward.sample`,
  costs and codes included.
- `public/skins/` + `public/appicon.png` — the app's own art, copied from
  `Ember/Assets.xcassets`.

Data on screen is polished demo data, not the `seed.json` trajectories.

## Changing copy

All captions live in `src/scenes/Beats.tsx` as `<Caption headline= sub=>` pairs.
Most beats have two, and the `start` / `out` props are frame numbers local to
that beat. A beat's second caption starts ~6 frames after the first one's `out`
so they cross rather than leaving a blank hold. Keep headlines under ~30
characters or they wrap to three lines at the current 86px size.

The copy avoids em dashes throughout. The only remaining en dashes are inside
time ranges (`22:30–06:25`), which mirror how `AgendaView.swift` formats them.
