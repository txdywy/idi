export type Trend = 'rising' | 'falling' | 'steady';

export type SparklinePoint = {
  value: number;
};

export type Metric = {
  label: string;
  value: string;
  detail: string;
  accent: string;
  trend: Trend;
  history: SparklinePoint[];
};

export type ProcessStat = {
  name: string;
  value: string;
  share: number;
};

export type TelemetrySnapshot = {
  generatedAt: string;
  healthScore: number;
  menuStrip: Metric[];
  cpu: Metric & { cores: number[]; topProcesses: ProcessStat[] };
  memory: Metric & { pressure: number; topProcesses: ProcessStat[] };
  disk: Metric & { volumes: ProcessStat[] };
  network: Metric & { down: string; up: string; interfaces: ProcessStat[] };
  battery: Metric & { cycles: number; powerSource: string };
  sensors: Metric & { readings: ProcessStat[] };
  weather: Metric & { forecast: ProcessStat[] };
  time: Metric & { cities: ProcessStat[] };
};

const wave = (seed: number, length = 28) =>
  Array.from({ length }, (_, index) => ({
    value: Math.round(42 + Math.sin(index / 2 + seed) * 24 + Math.cos(index / 5 + seed) * 12)
  }));

export const telemetry: TelemetrySnapshot = {
  generatedAt: 'Live demo feed',
  healthScore: 92,
  menuStrip: [
    { label: 'CPU', value: '38%', detail: '8-core balanced', accent: '#8ee6ff', trend: 'steady', history: wave(0.2) },
    { label: 'MEM', value: '11.2 GB', detail: 'green pressure', accent: '#b6f09c', trend: 'falling', history: wave(1.7) },
    { label: 'NET', value: '42 MB/s', detail: 'Wi‑Fi 6E', accent: '#f6d365', trend: 'rising', history: wave(2.9) },
    { label: 'BAT', value: '84%', detail: '4h 12m', accent: '#fda085', trend: 'steady', history: wave(4.1) }
  ],
  cpu: {
    label: 'Processor',
    value: '38%',
    detail: 'Performance cores cruising below thermal limit',
    accent: '#8ee6ff',
    trend: 'steady',
    history: wave(0.6, 36),
    cores: [32, 41, 27, 52, 47, 35, 22, 49, 30, 44],
    topProcesses: [
      { name: 'Xcode Preview', value: '11.8%', share: 72 },
      { name: 'Safari WebContent', value: '8.4%', share: 51 },
      { name: 'WindowServer', value: '5.9%', share: 36 }
    ]
  },
  memory: {
    label: 'Memory',
    value: '11.2 / 24 GB',
    detail: 'Compressed 1.1 GB · swap idle',
    accent: '#b6f09c',
    trend: 'falling',
    history: wave(1.4, 36),
    pressure: 34,
    topProcesses: [
      { name: 'Figma', value: '2.2 GB', share: 76 },
      { name: 'Claude', value: '1.4 GB', share: 49 },
      { name: 'Arc Helper', value: '920 MB', share: 31 }
    ]
  },
  disk: {
    label: 'Storage',
    value: '612 GB free',
    detail: 'Read 480 MB/s · write 210 MB/s',
    accent: '#c3a6ff',
    trend: 'steady',
    history: wave(2.2, 36),
    volumes: [
      { name: 'Macintosh HD', value: '58%', share: 58 },
      { name: 'Projects', value: '71%', share: 71 },
      { name: 'Backups', value: '42%', share: 42 }
    ]
  },
  network: {
    label: 'Network',
    value: '42 MB/s',
    detail: 'Low latency route · public IP hidden',
    accent: '#f6d365',
    trend: 'rising',
    history: wave(3.1, 36),
    down: '38.4 MB/s',
    up: '3.6 MB/s',
    interfaces: [
      { name: 'Wi‑Fi', value: '98%', share: 98 },
      { name: 'Thunderbolt Bridge', value: '0%', share: 0 },
      { name: 'VPN', value: '42 ms', share: 64 }
    ]
  },
  battery: {
    label: 'Power',
    value: '84%',
    detail: 'Optimized charging · 4h 12m estimate',
    accent: '#fda085',
    trend: 'steady',
    history: wave(4.4, 36),
    cycles: 118,
    powerSource: 'Battery'
  },
  sensors: {
    label: 'Thermals',
    value: '47°C',
    detail: 'Fans quiet · enclosure cool',
    accent: '#ff7a90',
    trend: 'steady',
    history: wave(5.4, 36),
    readings: [
      { name: 'CPU proximity', value: '47°C', share: 47 },
      { name: 'GPU die', value: '43°C', share: 43 },
      { name: 'Fan left', value: '1260 rpm', share: 28 }
    ]
  },
  weather: {
    label: 'Weather',
    value: '19°C',
    detail: 'Clear evening · air quality good',
    accent: '#7dd3fc',
    trend: 'falling',
    history: wave(6.3, 36),
    forecast: [
      { name: 'Now', value: '19° clear', share: 82 },
      { name: '22:00', value: '17° calm', share: 68 },
      { name: 'Tomorrow', value: '24° bright', share: 74 }
    ]
  },
  time: {
    label: 'Time',
    value: '21:48',
    detail: 'Wednesday · next event in 42m',
    accent: '#fef08a',
    trend: 'steady',
    history: wave(7.2, 36),
    cities: [
      { name: 'Shanghai', value: '21:48', share: 90 },
      { name: 'London', value: '14:48', share: 62 },
      { name: 'San Francisco', value: '06:48', share: 28 }
    ]
  }
};
