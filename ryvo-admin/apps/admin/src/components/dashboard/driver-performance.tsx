interface DriverPerformanceProps {
  online: number;
  offline: number;
  onBreak: number;
}

const SEGMENTS = [
  { key: 'online', label: 'Online', bar: 'bg-success' },
  { key: 'offline', label: 'Offline', bar: 'bg-input' },
  { key: 'onBreak', label: 'On break', bar: 'bg-warning' },
] as const;

export function DriverPerformance({ online, offline, onBreak }: DriverPerformanceProps) {
  const values = { online, offline, onBreak };
  const total = online + offline + onBreak;

  return (
    <section className="rounded-lg border border-hairline bg-card p-4">
      <div className="flex items-center justify-between">
        <h2 className="text-sm font-semibold text-primary">Driver performance</h2>
        <span className="num text-xs text-muted">{total} drivers</span>
      </div>
      {total === 0 ? (
        <p className="mt-6 text-sm text-muted">No drivers to show.</p>
      ) : (
        <ul className="mt-4 space-y-3">
          {SEGMENTS.map((segment) => {
            const count = values[segment.key];
            const pct = Math.round((count / total) * 100);
            return (
              <li key={segment.key}>
                <div className="mb-1 flex items-center justify-between text-xs">
                  <span className="text-muted">{segment.label}</span>
                  <span className="num text-primary">
                    {count} · {pct}%
                  </span>
                </div>
                <div className="h-1.5 overflow-hidden rounded-full bg-input">
                  <div className={`h-full rounded-full ${segment.bar}`} style={{ width: `${pct}%` }} />
                </div>
              </li>
            );
          })}
        </ul>
      )}
    </section>
  );
}
