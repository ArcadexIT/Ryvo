'use client';

import { useEffect, useState } from 'react';
import { Modal } from '@/components/ui/modal';

const SHORTCUTS = [
  { keys: ['⌘', 'K'], description: 'Open command palette' },
  { keys: ['?'], description: 'Show keyboard shortcuts' },
  { keys: ['⌘', 'B'], description: 'Toggle sidebar' },
  { keys: ['G', 'D'], description: 'Go to Overview' },
  { keys: ['G', 'C'], description: 'Go to Drivers' },
  { keys: ['G', 'J'], description: 'Go to Trips' },
];

export function KeyboardShortcutsPanel() {
  const [open, setOpen] = useState(false);

  useEffect(() => {
    const handler = (e: KeyboardEvent) => {
      if (e.key === '?' && !e.metaKey && !e.ctrlKey) {
        const target = e.target as HTMLElement;
        if (target.tagName === 'INPUT' || target.tagName === 'TEXTAREA') return;
        e.preventDefault();
        setOpen((prev) => !prev);
      }
    };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  }, []);

  return (
    <Modal open={open} onClose={() => setOpen(false)} title="Keyboard Shortcuts">
      <div className="space-y-3">
        {SHORTCUTS.map((s) => (
          <div key={s.description} className="flex items-center justify-between">
            <span className="text-sm text-secondary">{s.description}</span>
            <div className="flex gap-1">
              {s.keys.map((k) => (
                <kbd
                  key={k}
                  className="rounded border border-border bg-surface px-2 py-0.5 text-xs font-medium text-primary"
                >
                  {k}
                </kbd>
              ))}
            </div>
          </div>
        ))}
      </div>
    </Modal>
  );
}
