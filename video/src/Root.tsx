import React from 'react';
import {Composition} from 'remotion';
import {EmberDemo, TOTAL_FRAMES} from './EmberDemo';

export const RemotionRoot: React.FC = () => (
  <>
    <Composition
      id="EmberDemo"
      component={EmberDemo}
      durationInFrames={TOTAL_FRAMES}
      fps={30}
      width={1920}
      height={1080}
    />
  </>
);
