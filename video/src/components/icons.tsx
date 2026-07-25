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

export const Info: React.FC<P> = (p) => (
  <Svg {...p}>
    <circle cx="12" cy="12" r="9.2" fill="none" strokeWidth={1.8} />
    <circle cx="12" cy="7.6" r="1.2" strokeWidth={0} />
    <path d="M12 10.8v6" strokeWidth={2} strokeLinecap="round" />
  </Svg>
);
