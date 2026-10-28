'use client';

interface HeaderProps {
  title: string;
  description?: string;
  actions?: React.ReactNode;
}

export function Header({ title, description, actions }: HeaderProps) {
  return (
    <div className="flex shrink-0 items-center justify-between gap-4 border-b border-border bg-base px-5 py-3">
      <div className="min-w-0">
        <h1 className="truncate text-base font-semibold text-primary">{title}</h1>
        {description && <p className="mt-0.5 truncate text-xs text-secondary">{description}</p>}
      </div>
      {actions ? <div className="flex shrink-0 items-center gap-2">{actions}</div> : null}
    </div>
  );
}
