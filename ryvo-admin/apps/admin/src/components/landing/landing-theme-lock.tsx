'use client';

import { useEffect } from 'react';
import { applyTheme } from '@/contexts/theme-context';

export function LandingThemeLock() {
  useEffect(() => {
    applyTheme('light');
  }, []);

  return null;
}
