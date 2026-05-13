import type { SparklinePoint } from '../data/telemetry';

type SparklineProps = {
  points: SparklinePoint[];
  color: string;
};

export function Sparkline({ points, color }: SparklineProps) {
  const width = 220;
  const height = 64;
  const max = Math.max(...points.map((point) => point.value));
  const min = Math.min(...points.map((point) => point.value));
  const range = Math.max(max - min, 1);
  const path = points
    .map((point, index) => {
      const x = (index / Math.max(points.length - 1, 1)) * width;
      const y = height - ((point.value - min) / range) * height;
      return `${index === 0 ? 'M' : 'L'} ${x.toFixed(2)} ${y.toFixed(2)}`;
    })
    .join(' ');

  return (
    <svg className="sparkline" viewBox={`0 0 ${width} ${height}`} role="img" aria-label="Metric history sparkline">
      <path className="sparkline-glow" d={path} stroke={color} />
      <path d={path} stroke={color} />
    </svg>
  );
}
