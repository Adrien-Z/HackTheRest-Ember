import React from 'react';
import {AbsoluteFill, Sequence} from 'remotion';
import {SF} from './theme';
import {Hook} from './scenes/Hook';
import {
  BeatAgenda,
  BeatBoxSpace,
  BeatCoach,
  BeatRestLab,
  BeatTonight,
} from './scenes/Beats';
import {Finale} from './scenes/Finale';

/**
 * 60s at 30fps. Scenes overlap slightly so each cut is a dissolve rather than
 * a hard cut — the whole piece is meant to work muted.
 */
export const SCENES = {
  hook: {from: 0, duration: 210},
  tonight: {from: 204, duration: 372},
  coach: {from: 570, duration: 306},
  agenda: {from: 870, duration: 366},
  restLab: {from: 1230, duration: 336},
  boxSpace: {from: 1560, duration: 306},
  finale: {from: 1860, duration: 210},
};

export const TOTAL_FRAMES = 2070;

export const EmberDemo: React.FC = () => (
  <AbsoluteFill style={{background: '#05060B', fontFamily: SF}}>
    <Sequence from={SCENES.hook.from} durationInFrames={SCENES.hook.duration}>
      <Hook />
    </Sequence>
    <Sequence from={SCENES.tonight.from} durationInFrames={SCENES.tonight.duration}>
      <BeatTonight duration={SCENES.tonight.duration} />
    </Sequence>
    <Sequence from={SCENES.coach.from} durationInFrames={SCENES.coach.duration}>
      <BeatCoach duration={SCENES.coach.duration} />
    </Sequence>
    <Sequence from={SCENES.agenda.from} durationInFrames={SCENES.agenda.duration}>
      <BeatAgenda duration={SCENES.agenda.duration} />
    </Sequence>
    <Sequence from={SCENES.restLab.from} durationInFrames={SCENES.restLab.duration}>
      <BeatRestLab duration={SCENES.restLab.duration} />
    </Sequence>
    <Sequence from={SCENES.boxSpace.from} durationInFrames={SCENES.boxSpace.duration}>
      <BeatBoxSpace duration={SCENES.boxSpace.duration} />
    </Sequence>
    <Sequence from={SCENES.finale.from} durationInFrames={SCENES.finale.duration}>
      <Finale duration={SCENES.finale.duration} />
    </Sequence>
  </AbsoluteFill>
);
