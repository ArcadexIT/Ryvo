const STATUS_ROWS = [
  { key: 'pending', label: 'Pending', bar: 'bg-input', statuses: ['searching', 'draft', 'payment_pending', 'no_provider_found'] },
  { key: 'accepted', label: 'Accepted', bar: 'bg-success', statuses: ['matched'] },
  { key: 'ongoing', label: 'Ongoing', bar: 'bg-warning', statuses: ['provider_en_route', 'arrived', 'in_progress'] },
  { key: 'completed', label: 'Completed', bar: 'bg-success/40', statuses: ['completed'] },
  { key: 'cancelled', label: 'Cancelled', bar: 'bg-danger', statuses: ['cancelled_by_customer', 'cancelled_by_provider', 'cancelled_by_admin'] },
] as const;

export function JobStatusCard({ breakdown }: { breakdown: Record<string, number> }) {
  const rows = STATUS_ROWS.map((row) => ({
    ...row,
    value: row.statuses.reduce((sum, status) => sum + (breakdown[status] ?? 0), 0),
  }));
  const total = rows.reduce((sum, row) => sum + row.value, 0);

  return (
    <section className="rounded-lg border border-hairline bg-card p-4">
      <div className="flex items-center justify-between">
        <h2 className="text-sm font-semibold text-primary">Trip status</h2>
        <span className="num text-xs text-muted">{total}</span>
      </div>
      {total === 0 ? (
        <p className="mt-6 text-sm text-muted">No trips in this range.</p>
      ) : (
        <ul className="mt-4 space-y-3">
          {rows.map((row) => {
            const pct = Math.round((row.value / total) * 100);
            return (
              <li key={row.key}>
                <div className="mb-1 flex items-center justify-between text-xs">
                  <span className="text-muted">{row.label}</span>
                  <span className="num text-primary">
                    {row.value} · {pct}%
                  </span>
                </div>
                <div className="h-1.5 overflow-hidden rounded-full bg-input">
                  <div className={`h-full rounded-full ${row.bar}`} style={{ width: `${pct}%` }} />
                </div>
              </li>
            );
          })}
        </ul>
      )}
    </section>
  );
}
