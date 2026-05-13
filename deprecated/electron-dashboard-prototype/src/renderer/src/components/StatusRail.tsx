type StatusRailProps = {
  score: number;
  generatedAt: string;
};

export function StatusRail({ score, generatedAt }: StatusRailProps) {
  return (
    <aside className="status-rail">
      <div>
        <span className="eyebrow">System health</span>
        <strong>{score}</strong>
      </div>
      <div className="status-orbit" aria-hidden="true">
        <span />
        <span />
        <span />
      </div>
      <p>{generatedAt}</p>
    </aside>
  );
}
