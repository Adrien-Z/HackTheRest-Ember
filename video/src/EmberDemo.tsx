import React from 'react';
import {AbsoluteFill, Sequence} from 'remotion';
import {SF} from './theme';
import {Hook} from './scenes/Hook';
import {
  BeatAgenda,
  BeatBoxSpace,
  BeatCoach,
  BeatCyclicSigh,
  BeatMindDump,
  BeatRestLab,
  BeatRewards,
  BeatTonight,
} from './scenes/Beats';
import {Finale} from './scenes/Finale';

/**
 * 60s at 30fps. Scenes overlap slightly so each cut is a dissolve rather than
 * a hard cut — the whole piece is meant to work muted.
 */
export const SCENES = {
  hook: {from: 0, duration: 210},
  tonight: {from: 204, duration: 430},
  coach: {from: 628, duration: 306},
  agenda: {from: 928, duration: 372},
  restLab: {from: 1294, duration: 336},
  cyclicSigh: {from: 1624, duration: 330},
  mindDump: {from: 1948, duration: 336},
  boxSpace: {from: 2278, duration: 300},
  rewards: {from: 2572, duration: 288},
  finale: {from: 2854, duration: 210},
};

export const TOTAL_FRAMES = 3064;

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
    <Sequence from={SCENES.cyclicSigh.from} durationInFrames={SCENES.cyclicSigh.duration}>
      <BeatCyclicSigh duration={SCENES.cyclicSigh.duration} />
    </Sequence>
    <Sequence from={SCENES.mindDump.from} durationInFrames={SCENES.mindDump.duration}>
      <BeatMindDump duration={SCENES.mindDump.duration} />
    </Sequence>
    <Sequence from={SCENES.boxSpace.from} durationInFrames={SCENES.boxSpace.duration}>
      <BeatBoxSpace duration={SCENES.boxSpace.duration} />
    </Sequence>
    <Sequence from={SCENES.rewards.from} durationInFrames={SCENES.rewards.duration}>
      <BeatRewards duration={SCENES.rewards.duration} />
    </Sequence>
    <Sequence from={SCENES.finale.from} durationInFrames={SCENES.finale.duration}>
      <Finale duration={SCENES.finale.duration} />
    </Sequence>
  </AbsoluteFill>
);
