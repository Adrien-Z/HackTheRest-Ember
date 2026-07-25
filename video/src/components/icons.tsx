import React from 'react';

/**
 * SF Symbol stand-ins, drawn to match the weight and silhouette of the symbols
 * the app actually uses. `size` is the glyph box; paths are authored on a
 * 24x24 grid.
 */
type P = {size?: number; color?: string; style?: React.CSSProperties};

const Svg: React.FC<P & {children: React.ReactNode}> = ({
  size = 20,
  color = '#fff',
  style,
  children,
}) => (
  <svg
    width={size}
    height={size}
    viewBox="0 0 24 24"
    fill="none"
    style={{display: 'block', flexShrink: 0, ...style}}
  >
    <g fill={color} stroke={color}>
      {children}
    </g>
  </svg>
);

export const MoonStars: React.FC<P> = (p) => (
  <Svg {...p}>
    <path
      d="M15.6 3.2a8.4 8.4 0 1 0 5.6 9.9A6.8 6.8 0 0 1 15.6 3.2Z"
      strokeWidth={0}
    />
    <path d="M5.6 4.2 6.3 6l1.8.7-1.8.7-.7 1.8-.7-1.8L3.1 6.7 4.9 6Z" strokeWidth={0} />
  </Svg>
);

export const Calendar: React.FC<P> = (p) => (
  <Svg {...p}>
    <rect x="3" y="5" width="18" height="16" rx="3.5" fill="none" strokeWidth={1.8} />
    <path d="M3 9.5h18" strokeWidth={1.8} />
    <path d="M7.5 3v3.6M16.5 3v3.6" strokeWidth={1.8} strokeLinecap="round" />
    <circle cx="8" cy="13.5" r="1.2" strokeWidth={0} />
    <circle cx="12" cy="13.5" r="1.2" strokeWidth={0} />
  </Svg>
);

export const Sparkles: React.FC<P> = (p) => (
  <Svg {...p}>
    <path
      d="M12 2.5l1.7 4.6 4.6 1.7-4.6 1.7L12 15.1l-1.7-4.6L5.7 8.8l4.6-1.7Z"
      strokeWidth={0}
    />
    <path d="M18.8 14.4l.9 2.4 2.4.9-2.4.9-.9 2.4-.9-2.4-2.4-.9 2.4-.9Z" strokeWidth={0} />
    <path d="M5.3 15.1l.7 1.8 1.8.7-1.8.7-.7 1.8-.7-1.8-1.8-.7 1.8-.7Z" strokeWidth={0} />
  </Svg>
);

export const ShippingBox: React.FC<P> = (p) => (
  <Svg {...p}>
    <path
      d="M12 2.6 21.4 7v10L12 21.4 2.6 17V7Z"
      fill="none"
      strokeWidth={1.8}
      strokeLinejoin="round"
    />
    <path d="M2.6 7 12 11.4 21.4 7M12 11.4v10" strokeWidth={1.8} strokeLinejoin="round" />
  </Svg>
);

export const Gear: React.FC<P> = (p) => (
  <Svg {...p}>
    <circle cx="12" cy="12" r="3.2" fill="none" strokeWidth={1.8} />
    <path
      d="M12 2.6v2.6M12 18.8v2.6M21.4 12h-2.6M5.2 12H2.6M18.6 5.4l-1.8 1.8M7.2 16.8l-1.8 1.8M18.6 18.6l-1.8-1.8M7.2 7.2 5.4 5.4"
      strokeWidth={1.8}
      strokeLinecap="round"
    />
  </Svg>
);

export const Thermometer: React.FC<P> = (p) => (
  <Svg {...p}>
    <path
      d="M11 4.4a2.4 2.4 0 0 1 4.8 0v8.2a4.4 4.4 0 1 1-4.8 0Z"
      fill="none"
      strokeWidth={1.8}
    />
    <circle cx="13.4" cy="16.6" r="2.1" strokeWidth={0} />
    <path d="M13.4 8.2v6.4" strokeWidth={2.2} strokeLinecap="round" />
    <path d="M3.4 6.6h3.4M3.4 11h3.4" strokeWidth={1.8} strokeLinecap="round" />
  </Svg>
);

export const BedDouble: React.FC<P> = (p) => (
  <Svg {...p}>
    <path d="M3 18.6V8.4" strokeWidth={2} strokeLinecap="round" />
    <path d="M21 18.6v-4" strokeWidth={2} strokeLinecap="round" />
    <path
      d="M3 14.6h18a3 3 0 0 0-3-3H8a5 5 0 0 0-5 3Z"
      strokeWidth={1.8}
      strokeLinejoin="round"
    />
    <circle cx="7.4" cy="9.6" r="1.9" strokeWidth={0} />
  </Svg>
);

export const Wind: React.FC<P> = (p) => (
  <Svg {...p}>
    <path
      d="M3 8.4h9.6a2.7 2.7 0 1 0-2.7-2.7M3 12.6h13.4a2.7 2.7 0 1 1-2.7 2.7M3 16.8h6.8"
      fill="none"
      strokeWidth={1.9}
      strokeLinecap="round"
    />
  </Svg>
);

export const Waves: React.FC<P> = (p) => (
  <Svg {...p}>
    <path
      d="M2.4 8.4c1.6-1.6 3.2-1.6 4.8 0s3.2 1.6 4.8 0 3.2-1.6 4.8 0 3.2 1.6 4.8 0M2.4 13.2c1.6-1.6 3.2-1.6 4.8 0s3.2 1.6 4.8 0 3.2-1.6 4.8 0 3.2 1.6 4.8 0M2.4 18c1.6-1.6 3.2-1.6 4.8 0s3.2 1.6 4.8 0 3.2-1.6 4.8 0 3.2 1.6 4.8 0"
      fill="none"
      strokeWidth={1.7}
      strokeLinecap="round"
    />
  </Svg>
);

export const HandsSparkles: React.FC<P> = (p) => (
  <Svg {...p}>
    <path
      d="M8.4 21V13a1.5 1.5 0 0 0-3 0v2.4L4 17.4c-.6 1.5 0 3 1.4 3.6Z"
      strokeWidth={0}
    />
    <path
      d="M15.6 21V13a1.5 1.5 0 0 1 3 0v2.4l1.4 2c.6 1.5 0 3-1.4 3.6Z"
      strokeWidth={0}
    />
    <path d="M12 2.2l1.3 3.4 3.4 1.3-3.4 1.3L12 11.6l-1.3-3.4L7.3 6.9l3.4-1.3Z" strokeWidth={0} />
  </Svg>
);

export const Alarm: React.FC<P> = (p) => (
  <Svg {...p}>
    <circle cx="12" cy="13.4" r="7.4" fill="none" strokeWidth={1.9} />
    <path d="M12 9.6v4.2l2.8 1.6" strokeWidth={1.9} strokeLinecap="round" />
    <path d="M4.4 4.6 7.6 2.4M19.6 4.6 16.4 2.4" strokeWidth={2.2} strokeLinecap="round" />
  </Svg>
);

export const Chevron: React.FC<P> = (p) => (
  <Svg {...p}>
    <path d="M9.4 5.2 16 12l-6.6 6.8" fill="none" strokeWidth={2.4} strokeLinecap="round" strokeLinejoin="round" />
  </Svg>
);

export const PersonPlus: React.FC<P> = (p) => (
  <Svg {...p}>
    <circle cx="9.6" cy="7.6" r="3.7" fill="none" strokeWidth={1.8} />
    <path d="M2.8 20c0-3.6 3-6.2 6.8-6.2 1.3 0 2.5.3 3.5.8" fill="none" strokeWidth={1.8} strokeLinecap="round" />
    <path d="M18 13.6v6M15 16.6h6" strokeWidth={2} strokeLinecap="round" />
  </Svg>
);

export const PersonClock: React.FC<P> = (p) => (
  <Svg {...p}>
    <circle cx="9.6" cy="7.6" r="3.7" fill="none" strokeWidth={1.8} />
    <path d="M2.8 20c0-3.6 3-6.2 6.8-6.2" fill="none" strokeWidth={1.8} strokeLinecap="round" />
    <circle cx="17.4" cy="16.4" r="4.4" fill="none" strokeWidth={1.8} />
    <path d="M17.4 14v2.6l1.8 1" strokeWidth={1.7} strokeLinecap="round" />
  </Svg>
);

export const CheckSeal: React.FC<P> = (p) => (
  <Svg {...p}>
    <path
      d="M12 2.2 14.3 4l2.9-.3 1.1 2.7 2.5 1.5-.8 2.8.8 2.8-2.5 1.5-1.1 2.7-2.9-.3L12 21.8 9.7 20l-2.9.3-1.1-2.7-2.5-1.5.8-2.8-.8-2.8 2.5-1.5 1.1-2.7L9.7 4Z"
      strokeWidth={0}
    />
    <path d="M8.4 12.2 11 14.8l4.8-5" stroke="#0F121C" strokeWidth={2.1} fill="none" strokeLinecap="round" strokeLinejoin="round" />
  </Svg>
);

export const BoltHeart: React.FC<P> = (p) => (
  <Svg {...p}>
    <path
      d="M12 20.8S3.4 15.6 3.4 9.6a4.6 4.6 0 0 1 8.6-2.3 4.6 4.6 0 0 1 8.6 2.3c0 6-8.6 11.2-8.6 11.2Z"
      strokeWidth={0}
    />
    <path d="M12.6 8.4 10 12.4h2.2l-.8 3.4 2.8-4.2h-2.3Z" stroke="#0F121C" strokeWidth={1.4} fill="#0F121C" strokeLinejoin="round" />
  </Svg>
);

export const ChartBar: React.FC<P> = (p) => (
  <Svg {...p}>
    <rect x="3.4" y="12.6" width="4" height="8" rx="1.4" strokeWidth={0} />
    <rect x="10" y="7.6" width="4" height="13" rx="1.4" strokeWidth={0} />
    <rect x="16.6" y="3.4" width="4" height="17.2" rx="1.4" strokeWidth={0} />
  </Svg>
);

export const Paintbrush: React.FC<P> = (p) => (
  <Svg {...p}>
    <path d="M20.4 3.6c-1.2-1.2-3-.4-6.4 3l-3.4 3.4 3.4 3.4 3.4-3.4c3.4-3.4 4.2-5.2 3-6.4Z" strokeWidth={0} />
    <path d="M8.6 13.2c-1.6-.5-3.2.3-3.8 1.9-.5 1.3-1 2-2 2.7 1 1.4 2.8 2.2 4.5 1.9 2-.4 3.2-2.2 2.9-4.1" strokeWidth={0} />
  </Svg>
);

export const ArrowUpDown: React.FC<P> = (p) => (
  <Svg {...p}>
    <path d="M8 3.6v16.8M8 3.6 4.8 7M8 3.6 11.2 7" fill="none" strokeWidth={1.9} strokeLinecap="round" strokeLinejoin="round" />
    <path d="M16 20.4V3.6M16 20.4 12.8 17M16 20.4 19.2 17" fill="none" strokeWidth={1.9} strokeLinecap="round" strokeLinejoin="round" />
  </Svg>
);

/** `waveform.path.ecg` — the Daily Rhythm glyph. */
export const Waveform: React.FC<P> = (p) => (
  <Svg {...p}>
    <path
      d="M1.8 12h4.4l2.2-6.6 3.4 13.2 2.6-8.4 1.8 1.8h5.4"
      fill="none"
      strokeWidth={1.9}
      strokeLinecap="round"
      strokeLinejoin="round"
    />
  </Svg>
);

/** `bubble.left.and.text.bubble.right.fill` — the Mind Dump glyph. */
export const Bubbles: React.FC<P> = (p) => (
  <Svg {...p}>
    <path
      d="M2.2 8.4a4 4 0 0 1 4-4h6.2a4 4 0 0 1 4 4v2.4a4 4 0 0 1-4 4H7.4l-3.6 2.8v-2.9a4 4 0 0 1-1.6-3.2Z"
      strokeWidth={0}
    />
    <path
      d="M21.8 14.4a3.4 3.4 0 0 0-3.4-3.4h-.5v.2a5.4 5.4 0 0 1-5.4 5.4h-1.1a3.4 3.4 0 0 0 3.2 2.3h3.6l3 2.3v-2.5a3.4 3.4 0 0 0 .6-4.3Z"
      strokeWidth={0}
    />
  </Svg>
);

export const Gift: React.FC<P> = (p) => (
  <Svg {...p}>
    <rect x="2.8" y="9.6" width="18.4" height="11.6" rx="2.4" strokeWidth={0} />
    <rect x="1.8" y="5.6" width="20.4" height="4.8" rx="1.8" strokeWidth={0} />
    <path d="M12 5.6V21.2" stroke="#0F121C" strokeWidth={2.2} />
    <path
      d="M12 5.6S10.6 2 8.2 2a2.2 2.2 0 0 0 0 4.4M12 5.6S13.4 2 15.8 2a2.2 2.2 0 0 1 0 4.4"
      fill="none"
      strokeWidth={1.9}
      strokeLinecap="round"
    />
  </Svg>
);

export const Ticket: React.FC<P> = (p) => (
  <Svg {...p}>
    <path
      d="M3 7.4a1.8 1.8 0 0 1 1.8-1.8h14.4A1.8 1.8 0 0 1 21 7.4v2.4a2.2 2.2 0 0 0 0 4.4v2.4a1.8 1.8 0 0 1-1.8 1.8H4.8A1.8 1.8 0 0 1 3 16.6v-2.4a2.2 2.2 0 0 0 0-4.4Z"
      strokeWidth={0}
    />
    <path d="M14.4 6.6v10.8" stroke="#0F121C" strokeWidth={1.8} strokeDasharray="2.4 2.4" />
  </Svg>
);

export const Lock: React.FC<P> = (p) => (
  <Svg {...p}>
    <rect x="4.4" y="10.4" width="15.2" height="10.6" rx="2.6" strokeWidth={0} />
    <path d="M7.8 10.4V7.6a4.2 4.2 0 1 1 8.4 0v2.8" fill="none" strokeWidth={2} strokeLinecap="round" />
  </Svg>
);

export const Tag: React.FC<P> = (p) => (
  <Svg {...p}>
    <path
      d="M11.2 2.6H20a1.4 1.4 0 0 1 1.4 1.4v8.8a1.6 1.6 0 0 1-.5 1.1l-7.4 7.4a1.5 1.5 0 0 1-2.1 0l-8.6-8.6a1.5 1.5 0 0 1 0-2.1l7.4-7.4a1.6 1.6 0 0 1 1-.6Z"
      strokeWidth={0}
    />
    <circle cx="16.6" cy="7.4" r="1.9" fill="#0F121C" stroke="none" />
  </Svg>
);

export const Layers: React.FC<P> = (p) => (
  <Svg {...p}>
    <path d="M12 2.6 22 7.4 12 12.2 2 7.4Z" strokeWidth={0} />
    <path d="M2 12.2 12 17l10-4.8M2 16.6 12 21.4l10-4.8" fill="none" strokeWidth={1.9} strokeLinejoin="round" />
  </Svg>
);

export const BellBadge: React.FC<P> = (p) => (
  <Svg {...p}>
    <path
      d="M5.4 16.6V10a6.6 6.6 0 0 1 13.2 0v6.6l1.4 2H4Z"
      strokeWidth={0}
    />
    <path d="M9.6 20a2.6 2.6 0 0 0 4.8 0" fill="none" strokeWidth={1.9} strokeLinecap="round" />
    <circle cx="18.4" cy="5.4" r="3.4" fill="#FABF4A" stroke="#0F121C" strokeWidth={1.4} />
  </Svg>
);

export const Mic: React.FC<P> = (p) => (
  <Svg {...p}>
    <rect x="8.8" y="2.2" width="6.4" height="12" rx="3.2" strokeWidth={0} />
    <path d="M5 11.4a7 7 0 0 0 14 0M12 18.4v3.4" fill="none" strokeWidth={1.9} strokeLinecap="round" />
  </Svg>
);

export const CheckCircle: React.FC<P> = (p) => (
  <Svg {...p}>
    <circle cx="12" cy="12" r="9.4" strokeWidth={0} />
    <path d="M7.8 12.2 10.6 15l5.6-5.8" stroke="#0F121C" strokeWidth={2.1} fill="none" strokeLinecap="round" strokeLinejoin="round" />
  </Svg>
);

export const Rotate: React.FC<P> = (p) => (
  <Svg {...p}>
    <path
      d="M20.2 12a8.2 8.2 0 1 1-2.6-6"
      fill="none"
      strokeWidth={2}
      strokeLinecap="round"
    />
    <path d="M18.6 2.6v4h-4" fill="none" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" />
  </Svg>
);

export const Humidity: React.FC<P> = (p) => (
  <Svg {...p}>
    <path d="M12 2.6c3.6 4.4 6.2 7.7 6.2 10.6a6.2 6.2 0 1 1-12.4 0C5.8 10.3 8.4 7 12 2.6Z" strokeWidth={0} />
  </Svg>
);

export const Sunrise: React.FC<P> = (p) => (
  <Svg {...p}>
    <path d="M7 15.6a5 5 0 0 1 10 0Z" strokeWidth={0} />
    <path d="M1.8 18.8h20.4" strokeWidth={2} strokeLinecap="round" />
    <path d="M12 2.2v3.6M12 2.2 9.4 4.8M12 2.2l2.6 2.6M3.6 9.4l1.8 1.8M20.4 9.4l-1.8 1.8" fill="none" strokeWidth={1.9} strokeLinecap="round" strokeLinejoin="round" />
  </Svg>
);

export const MoonZzz: React.FC<P> = (p) => (
  <Svg {...p}>
    <path d="M13.8 5a7.6 7.6 0 1 0 5 9A6.2 6.2 0 0 1 13.8 5Z" strokeWidth={0} />
    <path d="M15.6 2.2h4l-4 4h4" fill="none" strokeWidth={1.6} strokeLinecap="round" strokeLinejoin="round" />
  </Svg>
);

export const ArrowDown: React.FC<P> = (p) => (
  <Svg {...p}>
    <path d="M12 3.6v13M12 16.6 7.4 12M12 16.6 16.6 12M5.4 20.4h13.2" fill="none" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" />
  </Svg>
);

export const Plus: React.FC<P> = (p) => (
  <Svg {...p}>
    <path d="M12 4.6v14.8M4.6 12h14.8" fill="none" strokeWidth={2.2} strokeLinecap="round" />
  </Svg>
);

export const ArrowUp: React.FC<P> = (p) => (
  <Svg {...p}>
    <path d="M12 20.4V7.4M12 7.4 7.4 12M12 7.4 16.6 12" fill="none" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round" />
  </Svg>
);

export const Cup: React.FC<P> = (p) => (
  <Svg {...p}>
    <path d="M3.6 6.6h13.2v7a5 5 0 0 1-5 5H8.6a5 5 0 0 1-5-5Z" strokeWidth={0} />
    <path d="M16.8 8.6h1.8a2.8 2.8 0 0 1 0 5.6h-1.8" fill="none" strokeWidth={1.8} />
    <path d="M2.6 21.4h15.2" strokeWidth={1.9} strokeLinecap="round" />
  </Svg>
);

export const Figure: React.FC<P> = (p) => (
  <Svg {...p}>
    <circle cx="12" cy="4.2" r="2.3" strokeWidth={0} />
    <path d="M12 7.6v6.2M12 13.8 8.6 21M12 13.8 15.4 21M6.4 10h11.2" fill="none" strokeWidth={2} strokeLinecap="round" />
  </Svg>
);

export const Info: React.FC<P> = (p) => (
  <Svg {...p}>
    <circle cx="12" cy="12" r="9.2" fill="none" strokeWidth={1.8} />
    <circle cx="12" cy="7.6" r="1.2" strokeWidth={0} />
    <path d="M12 10.8v6" strokeWidth={2} strokeLinecap="round" />
  </Svg>
);
