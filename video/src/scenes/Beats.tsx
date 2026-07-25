import React from 'react';
import {interpolate, spring, useCurrentFrame, useVideoConfig} from 'remotion';
import {Theme, SF, SFRounded, alpha, mapGradient} from '../theme';
import {Phone} from '../components/Phone';
import {Caption, FloatingCard, StageBackground, Starfield, Vignette} from '../components/Stage';
import {HomeScreen} from '../screens/HomeScreen';
import {AgendaScreen} from '../screens/AgendaScreen';
import {RestLabScreen, WarmUpDetailScreen} from '../screens/RestLabScreen';
import {BoxSpaceScreen, DecorationStudioScreen} from '../screens/BoxSpaceScreen';
import {CoachAvatar, CoachScreen} from '../screens/CoachScreen';
import {CyclicSighScreen, MindDumpScreen, sighPhase} from '../screens/WindDownScreens';
import {RewardsScreen} from '../screens/RewardsScreen';
import {
  BellBadge,
  ChartBar,
  CheckSeal,
  Mic,
  Thermometer,
  Ticket,
  Wind,
} from '../components/icons';

const PHONE_SCALE = 1.04;

/** Fade a scene in and out so cuts land soft rather than hard. */
const useSceneFade = (duration: number, inF = 12, outF = 12) => {
  const frame = useCurrentFrame();
  return interpolate(
    frame,
    [0, inF, duration - outF, duration],
    [0, 1, 1, 0],
    {extrapolateLeft: 'clamp', extrapolateRight: 'clamp'},
  );
};

// ── Beat 1 · Tonight's Plan + Apple Health ──────────────────────────────────

export const BeatTonight: React.FC<{duration: number}> = ({duration}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const fade = useSceneFade(duration);

  const rise = spring({frame: frame - 2, fps, config: {damping: 17, mass: 1.1}});
  const reveal = interpolate(frame, [14, 96], [0, 1], {extrapolateRight: 'clamp'});
  // The Daily Rhythm curve sweeps sunrise to sunrise, then the page scrolls on
  // to the Sleep Score.
  const rhythm = interpolate(frame, [34, 164], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  // The page only has ~130pt of travel below the fold, so it scrolls to the
  // end rather than parking the Sleep Score card at the top.
  const scroll = interpolate(frame, [226, 306], [0, 132], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  // The Sleep Score card is partly on screen from the start, so it settles
  // early instead of sitting at zero until the scroll reaches it.
  const chart = interpolate(frame, [76, 166], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const score = interpolate(frame, [76, 154], [0, 87], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const drift = Math.sin(frame / 90) * 8;

  return (
    <div style={{position: 'absolute', inset: 0, opacity: fade}}>
      <StageBackground />
      <Starfield count={70} opacity={0.5} speed={0.4} />

      <div style={{position: 'absolute', left: 132, top: 312}}>
        <Caption
          headline="Your whole day, one curve."
          sub="Sunrise, sunset, lights out, wake. Drawn from the real daylight where you are."
          frame={frame}
          start={22}
          out={210}
        />
      </div>
      <div style={{position: 'absolute', left: 132, top: 312}}>
        <Caption
          headline="It learns every night."
          sub="We read your sleep from Apple Health. Our own science-backed engine scores the night and moves tomorrow’s plan."
          frame={frame}
          start={216}
        />
      </div>

      <div
        style={{
          position: 'absolute',
          left: 1386,
          top: 540,
          transform: `translate(-50%, -50%) translateY(${(1 - rise) * 220 + drift}px)`,
          opacity: rise,
        }}
      >
        <Phone scale={PHONE_SCALE}>
          <HomeScreen
            reveal={reveal}
            chart={chart}
            scroll={scroll}
            score={score}
            alarmSet={frame > 178}
            bob={Math.sin(frame / 23)}
            rhythm={rhythm}
            updating={frame < 40}
          />
        </Phone>
      </div>

      <FloatingCard frame={frame} start={332} x={800} y={158} tint={Theme.cool}>
        <div style={{display: 'flex', alignItems: 'center', gap: 20}}>
          <div
            style={{
              fontFamily: SFRounded,
              fontSize: 80,
              fontWeight: 700,
              color: Theme.cool,
              letterSpacing: -2.6,
              lineHeight: 1,
            }}
          >
            {Math.round(score)}
          </div>
          <div>
            <div style={{fontSize: 29, fontWeight: 600}}>Sleep Score</div>
            <div style={{fontSize: 22, color: Theme.mint, marginTop: 6, display: 'flex', gap: 8}}>
              <ChartBar size={19} color={Theme.mint} />
              +12 vs last week
            </div>
          </div>
        </div>
      </FloatingCard>

      <FloatingCard frame={frame} start={366} x={738} y={742} tint={Theme.mint}>
        <div style={{display: 'flex', alignItems: 'center', gap: 15}}>
          <CheckSeal size={32} color={Theme.mint} />
          <div style={{fontSize: 27, fontWeight: 600}}>91% of time in bed, asleep</div>
        </div>
      </FloatingCard>

      <Vignette />
    </div>
  );
};

// ── Beat 1b · Rest Coach ────────────────────────────────────────────────────

export const BeatCoach: React.FC<{duration: number}> = ({duration}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const fade = useSceneFade(duration);

  // Continues the push that started when "Ask Rest Coach" was tapped.
  const push = spring({frame: frame - 2, fps, config: {damping: 20, mass: 1}});
  const ask = interpolate(frame, [30, 50], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const thinking = frame > 50 && frame < 82;
  const stream = interpolate(frame, [84, 206], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const widget = interpolate(frame, [206, 236], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const drift = Math.sin(frame / 90) * 8;

  return (
    <div style={{position: 'absolute', inset: 0, opacity: fade}}>
      <StageBackground />
      <Starfield count={70} opacity={0.45} speed={0.4} />

      <div style={{position: 'absolute', left: 132, top: 322}}>
        <Caption
          headline="Ask it why."
          sub="The coach already has your plan, your calendar, and every night you have logged. It answers with your numbers, not generic advice."
          frame={frame}
          start={40}
        />
      </div>

      <div
        style={{
          position: 'absolute',
          left: 1386,
          top: 540,
          transform: `translate(-50%, -50%) translateX(${(1 - push) * 560}px) translateY(${drift}px)`,
          opacity: push,
        }}
      >
        <Phone scale={PHONE_SCALE}>
          <CoachScreen ask={ask} stream={stream} widget={widget} thinking={thinking} />
        </Phone>
      </div>

      <FloatingCard frame={frame} start={196} x={742} y={706} tint={Theme.ember}>
        <div style={{display: 'flex', alignItems: 'center', gap: 18}}>
          <CoachAvatar size={46} />
          <div>
            <div style={{fontSize: 27, fontWeight: 600}}>Answers from your data</div>
            <div style={{fontSize: 21, color: Theme.secondaryText, marginTop: 6}}>
              Charts and stats, not just chat
            </div>
          </div>
        </div>
      </FloatingCard>

      <Vignette />
    </div>
  );
};

// ── Beat 2 · Agenda ─────────────────────────────────────────────────────────

export const BeatAgenda: React.FC<{duration: number}> = ({duration}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const fade = useSceneFade(duration);

  const slide = spring({frame: frame - 2, fps, config: {damping: 18, mass: 1.1}});
  const draw = interpolate(frame, [26, 116], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const scroll = interpolate(frame, [40, 190], [30, 386], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const bands = interpolate(frame, [110, 150], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  // Lift the night and slide it 20 minutes earlier, snapping in 5-min steps.
  const lifted = frame > 210 && frame < 272;
  const rawDrag = interpolate(frame, [216, 264], [0, -20], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const dragMin = Math.round(rawDrag / 5) * 5;
  const drift = Math.sin(frame / 90) * 7;

  return (
    <div style={{position: 'absolute', inset: 0, opacity: fade}}>
      <StageBackground />
      <Starfield count={70} opacity={0.45} speed={0.4} />

      <div style={{position: 'absolute', left: 1004, top: 306}}>
        <Caption
          headline="Your day, read by your body clock."
          sub="Morning peak, afternoon dip, and the wind-down window, laid over the calendar you already keep."
          frame={frame}
          start={26}
          out={182}
          width={782}
        />
      </div>
      <div style={{position: 'absolute', left: 1004, top: 306}}>
        <Caption
          headline="Move the night. The plan follows."
          sub="Drag your sleep block and the warm-up, wake time, and alarm all shift with it."
          frame={frame}
          start={188}
          width={782}
        />
      </div>

      <div
        style={{
          position: 'absolute',
          left: 540,
          top: 540,
          transform: `translate(-50%, -50%) translateX(${(1 - slide) * -260}px) translateY(${drift}px)`,
          opacity: slide,
        }}
      >
        <Phone scale={PHONE_SCALE}>
          <AgendaScreen
            draw={draw}
            scroll={scroll}
            bands={bands}
            dragMin={dragMin}
            lifted={lifted}
          />
        </Phone>
      </div>

      <FloatingCard frame={frame} start={132} out={186} x={790} y={232} tint={Theme.amber}>
        <div style={{fontSize: 19, fontWeight: 700, letterSpacing: 2.4, color: Theme.amber}}>
          AFTERNOON DIP
        </div>
        <div style={{fontSize: 26, marginTop: 10, color: Theme.secondaryText}}>
          A walk beats a coffee here.
        </div>
      </FloatingCard>

      <FloatingCard frame={frame} start={268} x={790} y={678} tint={Theme.ember}>
        <div style={{display: 'flex', alignItems: 'baseline', gap: 14}}>
          <span
            style={{
              fontFamily: SFRounded,
              fontSize: 54,
              fontWeight: 700,
              letterSpacing: -1.4,
            }}
          >
            22:30
          </span>
          <span style={{fontSize: 25, color: Theme.secondaryText}}>lights out</span>
        </div>
        <div style={{fontSize: 22, color: Theme.amber, marginTop: 10, display: 'flex', gap: 9}}>
          <Thermometer size={20} color={Theme.amber} />
          warm-up moved to 21:30
        </div>
      </FloatingCard>

      <Vignette />
    </div>
  );
};

// ── Beat 3 · Rest Lab ───────────────────────────────────────────────────────

export const BeatRestLab: React.FC<{duration: number}> = ({duration}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const fade = useSceneFade(duration);

  const rise = spring({frame: frame - 2, fps, config: {damping: 17, mass: 1.1}});
  const reveal = interpolate(frame, [14, 100], [0, 1], {extrapolateRight: 'clamp'});
  const press = frame > 128 && frame < 146;

  // iOS push: the detail slides over from the right, the list parks behind it.
  const push = spring({frame: frame - 142, fps, config: {damping: 20, mass: 1}});
  // Draw as the pushed screen lands, so the chart is never on screen empty.
  const chart = interpolate(frame, [156, 252], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const drift = Math.sin(frame / 90) * 7;

  return (
    <div style={{position: 'absolute', inset: 0, opacity: fade}}>
      <StageBackground />
      <Starfield count={70} opacity={0.45} speed={0.4} />

      <div style={{position: 'absolute', left: 128, top: 318}}>
        <Caption
          headline="Two levers. One good night."
          sub="Warm up at the right hour, and spend less time awake in bed. Both are proven. Both are automatic here."
          frame={frame}
          start={22}
          out={168}
          width={700}
        />
      </div>
      <div style={{position: 'absolute', left: 128, top: 318}}>
        <Caption
          headline="It tunes itself."
          sub="Twelve nights of data walked warm-up from 30 to 60 minutes before bed, then held it."
          frame={frame}
          start={174}
          width={700}
        />
      </div>

      {/* the list, parked back */}
      <div
        style={{
          position: 'absolute',
          left: 1240,
          top: 540,
          transform: `translate(-50%, -50%) translateY(${(1 - rise) * 200 + drift}px) translateX(${
            push * -104
          }px) scale(${1 - push * 0.07})`,
          opacity: rise * (1 - push * 0.5),
          filter: `brightness(${1 - push * 0.45})`,
        }}
      >
        <Phone scale={PHONE_SCALE} glow={0.5}>
          <RestLabScreen reveal={reveal} pressWarm={press} />
        </Phone>
      </div>

      {/* the pushed detail */}
      <div
        style={{
          position: 'absolute',
          left: 1512,
          top: 540,
          transform: `translate(-50%, -50%) translateX(${(1 - push) * 620}px) translateY(${drift}px)`,
          opacity: push,
        }}
      >
        <Phone scale={PHONE_SCALE}>
          <WarmUpDetailScreen chart={chart} />
        </Phone>
      </div>

      <FloatingCard frame={frame} start={250} x={172} y={712} tint={Theme.mint}>
        <div style={{display: 'flex', alignItems: 'center', gap: 26}}>
          <div style={{textAlign: 'center'}}>
            <div
              style={{
                fontFamily: SFRounded,
                fontSize: 58,
                fontWeight: 700,
                color: Theme.secondaryText,
                letterSpacing: -1.8,
              }}
            >
              46m
            </div>
            <div style={{fontSize: 18, color: Theme.tertiaryText, marginTop: 5}}>before</div>
          </div>
          <div style={{fontSize: 38, color: Theme.tertiaryText}}>→</div>
          <div style={{textAlign: 'center'}}>
            <div
              style={{
                fontFamily: SFRounded,
                fontSize: 58,
                fontWeight: 700,
                color: Theme.mint,
                letterSpacing: -1.8,
              }}
            >
              18m
            </div>
            <div style={{fontSize: 18, color: Theme.tertiaryText, marginTop: 5}}>now</div>
          </div>
          <div style={{width: 1, height: 68, background: 'rgba(255,255,255,0.16)'}} />
          <div style={{fontSize: 25}}>to fall asleep</div>
        </div>
      </FloatingCard>

      <Vignette />
    </div>
  );
};

// ── Beat 3b · Cyclic Sigh ───────────────────────────────────────────────────

export const BeatCyclicSigh: React.FC<{duration: number}> = ({duration}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const fade = useSceneFade(duration);

  const push = spring({frame: frame - 2, fps, config: {damping: 20, mass: 1}});
  // Enter mid-session so the ring already reads as progress, then breathe on.
  const elapsed = 96 + Math.max(0, frame - 12) / fps;
  const p = sighPhase(elapsed);
  const drift = Math.sin(frame / 90) * 7;

  return (
    <div style={{position: 'absolute', inset: 0, opacity: fade}}>
      <StageBackground />
      <Starfield count={70} opacity={0.45} speed={0.4} />
      {/* the stage breathes with the exercise */}
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background: `radial-gradient(880px 620px at 68% 50%, ${alpha(
            p.tint,
            0.06 + p.breathFill * 0.1,
          )} 0%, transparent 64%)`,
        }}
      />

      <div style={{position: 'absolute', left: 132, top: 306}}>
        <Caption
          headline="Five minutes to downshift."
          sub="The cyclic sigh: two inhales, one long exhale. Your box rises and falls with you, so there is nothing to count."
          frame={frame}
          start={30}
          width={760}
        />
      </div>

      <div
        style={{
          position: 'absolute',
          left: 1386,
          top: 540,
          transform: `translate(-50%, -50%) translateX(${(1 - push) * 540}px) translateY(${drift}px)`,
          opacity: push,
        }}
      >
        <Phone scale={PHONE_SCALE}>
          <CyclicSighScreen elapsed={elapsed} />
        </Phone>
      </div>

      <FloatingCard frame={frame} start={186} x={742} y={716} tint={p.tint}>
        <div style={{display: 'flex', alignItems: 'center', gap: 20}}>
          <Wind size={34} color={p.tint} />
          <div>
            <div style={{fontSize: 27, fontWeight: 600}}>{p.title}</div>
            <div style={{fontSize: 21, color: Theme.secondaryText, marginTop: 6}}>
              {p.subtitle}
            </div>
          </div>
        </div>
      </FloatingCard>

      <Vignette />
    </div>
  );
};

// ── Beat 3c · Mind Dump ─────────────────────────────────────────────────────

export const BeatMindDump: React.FC<{duration: number}> = ({duration}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const fade = useSceneFade(duration);

  const push = spring({frame: frame - 2, fps, config: {damping: 20, mass: 1}});
  // Dictate, send, sort, then the reminder card lands.
  const recording = frame > 26 && frame < 130;
  const dictate = interpolate(frame, [34, 126], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const sent = frame > 142;
  const thinking = frame > 142 && frame < 182;
  const stream = interpolate(frame, [184, 252], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const reminder = interpolate(frame, [226, 286], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const drift = Math.sin(frame / 90) * 7;

  return (
    <div style={{position: 'absolute', inset: 0, opacity: fade}}>
      <StageBackground />
      <Starfield count={70} opacity={0.45} speed={0.4} />

      <div style={{position: 'absolute', left: 132, top: 306}}>
        <Caption
          headline="Say it out loud. Then let it go."
          sub="Talk or type whatever is circling. EMBER sorts it and holds it for you."
          frame={frame}
          start={28}
          out={196}
          width={760}
        />
      </div>
      <div style={{position: 'absolute', left: 132, top: 306}}>
        <Caption
          headline="It hands it back in the morning."
          sub="Everything worth keeping becomes a 09:30 reminder, so none of it has to stay in your head tonight."
          frame={frame}
          start={202}
          width={760}
        />
      </div>

      <div
        style={{
          position: 'absolute',
          left: 1386,
          top: 540,
          transform: `translate(-50%, -50%) translateX(${(1 - push) * 540}px) translateY(${drift}px)`,
          opacity: push,
        }}
      >
        <Phone scale={PHONE_SCALE}>
          <MindDumpScreen
            dictate={dictate}
            recording={recording}
            sent={sent}
            thinking={thinking}
            stream={stream}
            reminder={reminder}
          />
        </Phone>
      </div>

      <FloatingCard frame={frame} start={60} out={168} x={742} y={716} tint={Theme.mint}>
        <div style={{display: 'flex', alignItems: 'center', gap: 20}}>
          <Mic size={32} color={Theme.mint} />
          <div>
            <div style={{fontSize: 27, fontWeight: 600}}>Just speak</div>
            <div style={{fontSize: 21, color: Theme.secondaryText, marginTop: 6}}>
              No typing in a dark room
            </div>
          </div>
        </div>
      </FloatingCard>

      <FloatingCard frame={frame} start={286} x={742} y={716} tint={Theme.amber}>
        <div style={{display: 'flex', alignItems: 'center', gap: 20}}>
          <BellBadge size={32} color={Theme.amber} />
          <div>
            <div style={{fontSize: 27, fontWeight: 600}}>Tomorrow, 09:30</div>
            <div style={{fontSize: 21, color: Theme.secondaryText, marginTop: 6}}>
              Two things, waiting for you
            </div>
          </div>
        </div>
      </FloatingCard>

      <Vignette />
    </div>
  );
};

// ── Beat 4 · Box Space ──────────────────────────────────────────────────────

export const BeatBoxSpace: React.FC<{duration: number}> = ({duration}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const fade = useSceneFade(duration);

  const rise = spring({frame: frame - 2, fps, config: {damping: 18, mass: 1.1}});
  const points = interpolate(frame, [40, 130], [1980, 2140], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const panX = interpolate(frame, [0, 150], [26, -18], {extrapolateRight: 'clamp'});
  const panY = interpolate(frame, [0, 150], [-14, 12], {extrapolateRight: 'clamp'});

  // Cross-fade the map into the decoration studio.
  const studio = interpolate(frame, [148, 172], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const selected = frame < 216 ? 0 : frame < 250 ? 2 : 3;
  const studioReveal = interpolate(frame, [166, 226], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const drift = Math.sin(frame / 90) * 7;

  return (
    <div style={{position: 'absolute', inset: 0, opacity: fade}}>
      {/* the map bleeds past the phone and fills the stage */}
      <div style={{position: 'absolute', inset: 0, background: mapGradient}} />
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background: `radial-gradient(1000px 700px at 50% 50%, ${alpha(Theme.boxBlue, 0.24)} 0%, transparent 66%)`,
        }}
      />
      <Starfield count={60} opacity={0.35} speed={0.4} />

      <div style={{position: 'absolute', left: 132, top: 330}}>
        <Caption
          headline="Rest, together."
          sub="Your friends are boxes on a map. Sleep well and yours climbs the month’s ranking."
          frame={frame}
          start={26}
          out={152}
          width={660}
        />
      </div>
      <div style={{position: 'absolute', left: 132, top: 330}}>
        <Caption
          headline="Boxes worth collecting."
          sub="Rest Points come from nights you actually slept. Then you spend them on skins."
          frame={frame}
          start={158}
          width={660}
        />
      </div>

      <div
        style={{
          position: 'absolute',
          left: 1330,
          top: 540,
          transform: `translate(-50%, -50%) translateY(${(1 - rise) * 200 + drift}px)`,
          opacity: rise,
        }}
      >
        <Phone scale={PHONE_SCALE}>
          <div style={{position: 'absolute', inset: 0, opacity: 1 - studio}}>
            <BoxSpaceScreen
              frame={frame}
              points={points}
              panX={panX}
              panY={panY}
              fps={fps}
            />
          </div>
          <div style={{position: 'absolute', inset: 0, opacity: studio}}>
            <DecorationStudioScreen reveal={studioReveal} selected={selected} />
          </div>
        </Phone>
      </div>

      <FloatingCard frame={frame} start={96} out={162} x={172} y={712} tint={Theme.boxBlue}>
        <div style={{display: 'flex', alignItems: 'center', gap: 24}}>
          <div>
            <div
              style={{
                fontFamily: SFRounded,
                fontSize: 58,
                fontWeight: 700,
                letterSpacing: -1.8,
              }}
            >
              +160
            </div>
            <div style={{fontSize: 20, color: Theme.secondaryText, marginTop: 4}}>
              sleep points this week
            </div>
          </div>
          <div style={{width: 1, height: 68, background: 'rgba(255,255,255,0.16)'}} />
          <div style={{fontSize: 27, fontWeight: 600}}>Rank #2</div>
        </div>
      </FloatingCard>

      <Vignette />
    </div>
  );
};

// ── Beat 5 · Blue Box rewards ───────────────────────────────────────────────

export const BeatRewards: React.FC<{duration: number}> = ({duration}) => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();
  const fade = useSceneFade(duration);

  const rise = spring({frame: frame - 2, fps, config: {damping: 18, mass: 1.1}});
  const points = interpolate(frame, [26, 96], [0, 1180], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const reveal = interpolate(frame, [36, 132], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
  });
  const claimed = frame > 202 ? 'n2-pillow' : null;
  const drift = Math.sin(frame / 90) * 7;

  return (
    <div style={{position: 'absolute', inset: 0, opacity: fade}}>
      <div style={{position: 'absolute', inset: 0, background: mapGradient}} />
      <div
        style={{
          position: 'absolute',
          inset: 0,
          background: `radial-gradient(1000px 700px at 52% 50%, ${alpha(Theme.boxBlue, 0.26)} 0%, transparent 66%)`,
        }}
      />
      <Starfield count={60} opacity={0.35} speed={0.4} />

      <div style={{position: 'absolute', left: 132, top: 318}}>
        <Caption
          headline="Sleep well. Get actual things."
          sub="Rest Points are not only for skins. Spend them on real Blue Box perks: pillow coupons, mattress discounts, a warmth ritual kit."
          frame={frame}
          start={30}
          width={740}
        />
      </div>

      <div
        style={{
          position: 'absolute',
          left: 1386,
          top: 540,
          transform: `translate(-50%, -50%) translateY(${(1 - rise) * 200 + drift}px)`,
          opacity: rise,
        }}
      >
        <Phone scale={PHONE_SCALE}>
          <RewardsScreen points={points} reveal={reveal} claimed={claimed} />
        </Phone>
      </div>

      <FloatingCard frame={frame} start={216} x={742} y={716} tint={Theme.mint}>
        <div style={{display: 'flex', alignItems: 'center', gap: 20}}>
          <Ticket size={32} color={Theme.mint} />
          <div>
            <div style={{fontSize: 27, fontWeight: 600}}>Claimed with 250 pts</div>
            <div
              style={{
                fontSize: 22,
                color: Theme.mint,
                marginTop: 8,
                fontFamily: SFRounded,
                fontWeight: 700,
                letterSpacing: 1,
              }}
            >
              N2-EMBER-15
            </div>
          </div>
        </div>
      </FloatingCard>

      <Vignette />
    </div>
  );
};
