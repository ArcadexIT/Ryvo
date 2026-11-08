import { cn } from '@/lib/utils';

interface TimelineItem {
  id?: string;
  title: string;
  meta?: string;
  description?: string;
}

export function Timeline({ items, className }: { items: TimelineItem[]; className?: string }) {
  if (items.length === 0) {
    return <p className="text-sm text-muted">Nothing recent.</p>;
  }

  return (
    <ol className={cn('space-y-0', className)}>
      {items.map((item, index) => (
        <li key={item.id ?? `${item.title}-${index}`} className="relative flex gap-3 pb-4 last:pb-0">
          {index < items.length - 1 ? (
            <span className="absolute left-[5px] top-3 h-full w-px bg-hairline" aria-hidden />
          ) : null}
          <span className="relative mt-1.5 size-[11px] shrink-0 rounded-full border border-hairline bg-sheet" />
          <div className="min-w-0">
            <p className="text-sm font-medium text-primary">{item.title}</p>
            {item.description ? <p className="mt-0.5 text-sm text-muted">{item.description}</p> : null}
            {item.meta ? <p className="num mt-1 text-xs text-muted">{item.meta}</p> : null}
          </div>
        </li>
      ))}
    </ol>
  );
}
