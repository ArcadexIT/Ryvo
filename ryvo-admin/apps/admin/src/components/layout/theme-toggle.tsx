'use client';

import { Moon, Sun } from 'lucide-react';
import { useTheme } from '@/hooks/use-theme';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';

interface ThemeToggleProps {
  className?: string;
}

export function ThemeToggle({ className }: ThemeToggleProps) {
  const { theme, toggleTheme } = useTheme();

  return (
    <Button
      variant="ghost"
      size="icon"
      onClick={toggleTheme}
      aria-label={theme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode'}
      className={cn('relative text-secondary hover:text-primary', className)}
    >
      {theme === 'dark' ? (
        <Sun key="sun" className="h-[18px] w-[18px] theme-icon-animate" />
      ) : (
        <Moon key="moon" className="h-[18px] w-[18px] theme-icon-animate" />
      )}
    </Button>
  );
}
