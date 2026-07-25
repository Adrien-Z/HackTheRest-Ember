# EMBER — demo video (Remotion)

A 69-second product film for the EMBER iOS app, rendered at 1920×1080 / 30fps.
Every screen is a React re-creation of the real SwiftUI view — same palette,
same type scale, same components — so nothing here is a screenshot that can go
stale.

```bash
npm install
npm start      # Remotion Studio — scrub, tweak copy, see changes live
npm run build  # renders out/ember-demo.mp4
```

## The cut

| Time | Beat | On screen |
| --- | --- | --- |
| 0:00–0:07 | Hook | The clock crawls 23:00 → 01:47, then EMBER's plan answers it. Wordless. |
| 0:07–0:19 | Tonight's Plan | `HomeView`: warming / lights out / wake, wake alarm, Sleep Score. |
| 0:19–0:29 | Rest Coach | `CoachView`: a question is asked, the reply streams in, and an inline stats widget builds itself from the user's own numbers. |
| 0:29–0:41 | Agenda | `AgendaView`: circadian energy ribbon over the real calendar; the night drags and the plan follows. |
| 0:41–0:52 | Rest Lab | `RestLabView` pushes to the Warm-Up detail; the titration path 30m → 60m. |
| 0:52–1:02 | Box Space | The friend map, sleep points, and the collectible skins. |
| 1:02–1:09 | Finale | The Blue Box mascot, EMBER, "Rest that adapts to you." |

It is caption-driven and works muted. There is no voiceover, by design.

The mascot appears in the hook, the Home greeting and coach pill, the Coach
avatar and its answers, the Rest Lab hero and science note, all of Box Space,
and the finale.

## Adding music

The render currently has no audio track. Drop a file at `public/music.mp3` and
add this inside `EmberDemo.tsx`'s `<AbsoluteFill>`:

```tsx
import {Audio, staticFile} from 'remotion';

<Audio src={staticFile('music.mp3')} volume={(f) =>
  interpolate(f, [0, 45, 1950, 2070], [0, 0.55, 0.55, 0], {extrapolateRight: 'clamp'})
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
