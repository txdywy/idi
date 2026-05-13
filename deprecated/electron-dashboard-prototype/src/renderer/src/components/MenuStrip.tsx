import type { CSSProperties } from 'react';
import type { Metric } from '../data/telemetry';

type MenuStripProps = {
  metrics: Metric[];
};

export function MenuStrip({ metrics }: MenuStripProps) {
  return (
    <section className="menu-strip" aria-label="Menu bar preview">
      <div className="menu-strip__window-dots"><span /><span /><span /></div>
      {metrics.map((metric) => (
        <div className="menu-pill" key={metric.label} style={{ '--accent': metric.accent } as CSSProperties}>
          <span>{metric.label}</span>
          <strong>{metric.value}</strong>
        </div>
      ))}
      <div className="menu-strip__spacer" />
      <span className="menu-strip__clock">idi live cockpit</span>
    </section>
  );
}
