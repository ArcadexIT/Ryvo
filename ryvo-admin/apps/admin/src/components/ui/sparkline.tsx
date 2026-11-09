'use client';

import { useId } from 'react';

interface SparklineProps {
  data: number[];
  color?: string;
  className?: string;
  height?: number;
}

const WAVES = [
  'M0 46 C 50 46 70 22 120 26 C 170 30 190 54 240 48 C 300 40 330 14 380 18 C 420 22 450 36 480 32 L 480 80 L 0 80 Z',
  'M0 52 C 60 52 90 30 140 28 C 190 26 210 48 270 50 C 330 52 360 24 410 20 C 450 16 470 34 480 38 L 480 80 L 0 80 Z',
  'M0 40 C 40 44 80 58 130 50 C 180 42 210 18 270 22 C 330 26 370 48 430 40 C 460 34 470 30 480 28 L 480 80 L 0 80 Z',
];

export function StatWave({ color = 'currentColor', variant = 0 }: { color?: string; variant?: number }) {
  const gradientId = useId();
  const d = WAVES[variant % WAVES.length];
  return (
    <svg viewBox="0 0 480 80" preserveAspectRatio="none" className="h-full w-full" aria-hidden>
      <defs>
        <linearGradient id={gradientId} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor={color} stopOpacity="0.38" />
          <stop offset="100%" stopColor={color} stopOpacity="0" />
        </linearGradient>
      </defs>
      <path d={d} fill={`url(#${gradientId})`} />
      <path d={d.replace(/ L 480 80 L 0 80 Z$/, '')} fill="none" stroke={color} strokeWidth="2.25" />
    </svg>
  );
}

export function Sparkline({ data, color = 'currentColor', className, height = 32 }: SparklineProps) {
  const gradientId = useId();

  if (data.length < 2) return null;

  const width = 100;
  const min = Math.min(...data);
  const max = Math.max(...data);
  const range = max - min || 1;
  const stepX = width / (data.length - 1);
  const pad = 3;
  const usableHeight = height - pad * 2;

  const points = data.map((v, i) => {
    const x = i * stepX;
    const y = pad + usableHeight - ((v - min) / range) * usableHeight;
    return [x, y] as const;
  });

  const linePath = points
    .map(([x, y], i) => `${i === 0 ? 'M' : 'L'}${x.toFixed(2)},${y.toFixed(2)}`)
    .join(' ');
  const areaPath = `${linePath} L${width},${height} L0,${height} Z`;

  return (
    <svg
      viewBox={`0 0 ${width} ${height}`}
      preserveAspectRatio="none"
      className={className}
      style={{ width: '100%', height }}
      aria-hidden
    >
      <defs>
        <linearGradient id={gradientId} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0%" stopColor={color} stopOpacity="0.32" />
          <stop offset="100%" stopColor={color} stopOpacity="0" />
        </linearGradient>
      </defs>
      <path d={areaPath} fill={`url(#${gradientId})`} stroke="none" />
      <path
        d={linePath}
        fill="none"
        stroke={color}
        strokeWidth={1.75}
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

/**
 * Deterministic decorative series seeded by an index + the real trend %.
 * Used only where no genuine historical series exists for a metric — purely
 * a presentational accent (no axis/values are ever shown), never a data source.
 */
export function seededSparklineData(seed: number, trend: number, length = 12): number[] {
  let value = 50;
  const points: number[] = [value];
  let rngState = (seed + 1) * 9301 + 49297;
  for (let i = 1; i < length; i++) {
    rngState = (rngState * 9301 + 49297) % 233280;
    const rnd = rngState / 233280 - 0.5;
    const drift = (trend / 100) * (i / length) * 24;
    value = Math.max(8, Math.min(92, value + rnd * 16 + drift));
    points.push(value);
  }
  return points;
}
