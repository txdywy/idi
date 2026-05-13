import type { CSSProperties } from 'react';
import type { Metric, ProcessStat } from '../data/telemetry';
import { Sparkline } from './Sparkline';

type MetricCardProps = {
  metric: Metric;
  stats?: ProcessStat[];
  hero?: boolean;
};

export function MetricCard({ metric, stats = [], hero = false }: MetricCardProps) {
  return (
    <article className={`metric-card ${hero ? 'metric-card--hero' : ''}`} style={{ '--accent': metric.accent } as CSSProperties}>
      <div className="metric-card__topline">
        <span>{metric.label}</span>
        <small>{metric.trend}</small>
      </div>
      <div className="metric-card__value">{metric.value}</div>
      <p>{metric.detail}</p>
      <Sparkline points={metric.history} color={metric.accent} />
      {stats.length > 0 && (
        <div className="metric-card__stats">
          {stats.map((stat) => (
            <div className="stat-row" key={stat.name}>
              <span>{stat.name}</span>
              <strong>{stat.value}</strong>
              <i style={{ width: `${stat.share}%` }} />
            </div>
          ))}
        </div>
      )}
    </article>
  );
}
