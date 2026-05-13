import React from 'react';
import ReactDOM from 'react-dom/client';
import { MetricCard } from './components/MetricCard';
import { MenuStrip } from './components/MenuStrip';
import { StatusRail } from './components/StatusRail';
import { telemetry } from './data/telemetry';
import './styles/app.css';

function App() {
  return (
    <main className="app-shell">
      <MenuStrip metrics={telemetry.menuStrip} />
      <section className="hero-panel">
        <div className="hero-copy">
          <span className="eyebrow">idi / free system intelligence</span>
          <h1>Mac telemetry, redesigned as a precision cockpit.</h1>
          <p>
            A dense original dashboard for live performance, power, thermals, network, weather, and time signals — built as the foundation for a full menu-bar monitor.
          </p>
        </div>
        <StatusRail score={telemetry.healthScore} generatedAt={telemetry.generatedAt} />
      </section>
      <section className="dashboard-grid">
        <MetricCard metric={telemetry.cpu} stats={telemetry.cpu.topProcesses} hero />
        <MetricCard metric={telemetry.memory} stats={telemetry.memory.topProcesses} />
        <MetricCard metric={telemetry.network} stats={telemetry.network.interfaces} />
        <MetricCard metric={telemetry.disk} stats={telemetry.disk.volumes} />
        <MetricCard metric={telemetry.sensors} stats={telemetry.sensors.readings} />
        <MetricCard metric={telemetry.battery} stats={[{ name: telemetry.battery.powerSource, value: `${telemetry.battery.cycles} cycles`, share: 84 }]} />
        <MetricCard metric={telemetry.weather} stats={telemetry.weather.forecast} />
        <MetricCard metric={telemetry.time} stats={telemetry.time.cities} />
      </section>
    </main>
  );
}

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
