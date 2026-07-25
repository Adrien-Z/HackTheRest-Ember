/**
 * Direct port of Ember/Theme/Theme.swift so the video reads as the real app.
 * Values converted from SwiftUI's 0-1 component floats to hex.
 */
export const Theme = {
  ember: '#1F6EFF', // brand blue accent (0.120, 0.430, 1.000)
  emberDeep: '#162C60', // Blue Box deep navy
  cool: '#A8BFE0', // periwinkle — CBT-I / Sleep Score
  mint: '#4DC799', // success / Body Battery
  amber: '#FABF4A', // warming / energy ribbon
  boxBlue: '#0047BA',
  boxBlueDeep: '#162C60',
  bg: '#0F121C', // near-black navy
  card: '#1C1F2B',
  nightTop: '#171A2E',
  secondaryText: 'rgba(255,255,255,0.74)',
  tertiaryText: 'rgba(255,255,255,0.58)',
  hairline: 'rgba(255,255,255,0.14)',
} as const;

export const nightGradient = `linear-gradient(180deg, ${Theme.nightTop} 0%, ${Theme.bg} 100%)`;

export const boxGradient = `linear-gradient(135deg, #7BD4FF 0%, ${Theme.boxBlue} 55%, ${Theme.boxBlueDeep} 100%)`;

/** Box Space map gradient (BoxWorldCanvas.mapGradient). */
export const mapGradient =
  'linear-gradient(135deg, rgb(20,33,56) 0%, rgb(11,15,28) 100%)';

/** San Francisco on the render machine; graceful elsewhere. */
export const SF =
  '-apple-system, "SF Pro Display", "SF Pro Text", system-ui, "Helvetica Neue", sans-serif';

/** SwiftUI's `.system(design: .rounded)` — SF Pro Rounded. */
export const SFRounded =
  'ui-rounded, "SF Pro Rounded", -apple-system, system-ui, sans-serif';

/** iOS card: material fill, 20pt continuous corner, hairline border. */
export const cardStyle = (radius = 20): React.CSSProperties => ({
  background: 'rgba(28,31,43,0.96)',
  borderRadius: radius,
  border: `1px solid ${Theme.hairline}`,
});

export const alpha = (hex: string, a: number) => {
  const n = parseInt(hex.slice(1), 16);
  return `rgba(${(n >> 16) & 255}, ${(n >> 8) & 255}, ${n & 255}, ${a})`;
};
