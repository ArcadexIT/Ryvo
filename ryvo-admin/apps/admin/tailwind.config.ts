import type { Config } from 'tailwindcss';

const config: Config = {
  darkMode: 'class',
  content: ['./src/**/*.{js,ts,jsx,tsx,mdx}'],
  theme: {
    extend: {
      fontFamily: {
        sans: ['var(--font-sans)', 'ui-sans-serif', 'system-ui', 'sans-serif'],
        mono: ['var(--font-geist-mono)', 'ui-monospace', 'SFMono-Regular', 'monospace'],
      },
      fontSize: {
        // [fontSize, { lineHeight, letterSpacing, fontWeight }]
        xs: ['0.75rem', { lineHeight: '1.1rem', letterSpacing: '0' }],
        sm: ['0.8125rem', { lineHeight: '1.25rem', letterSpacing: '-0.006em' }],
        base: ['0.875rem', { lineHeight: '1.4rem', letterSpacing: '-0.008em' }],
        lg: ['1rem', { lineHeight: '1.5rem', letterSpacing: '-0.011em' }],
        xl: ['1.125rem', { lineHeight: '1.6rem', letterSpacing: '-0.014em' }],
        '2xl': ['1.375rem', { lineHeight: '1.75rem', letterSpacing: '-0.017em' }],
        '3xl': ['1.75rem', { lineHeight: '2.1rem', letterSpacing: '-0.02em' }],
        '4xl': ['2.25rem', { lineHeight: '2.5rem', letterSpacing: '-0.025em' }],
        // Data/number-forward sizes for KPI figures
        stat: ['1.75rem', { lineHeight: '2rem', letterSpacing: '-0.02em', fontWeight: '600' }],
        'stat-lg': ['2.25rem', { lineHeight: '2.5rem', letterSpacing: '-0.025em', fontWeight: '600' }],
      },
      colors: {
        canvas: 'var(--bg-canvas)',
        base: 'var(--bg-base)',
        surface: 'var(--bg-surface)',
        elevated: 'var(--bg-elevated)',
        overlay: 'var(--bg-overlay)',
        border: 'var(--border)',
        'border-strong': 'var(--border-strong)',
        primary: 'var(--text-primary)',
        secondary: 'var(--text-secondary)',
        muted: 'var(--text-muted)',
        accent: {
          DEFAULT: 'var(--accent)',
          hover: 'var(--accent-hover)',
          soft: 'var(--accent-soft)',
          foreground: 'var(--accent-foreground)',
        },
        sidebar: {
          DEFAULT: 'var(--sidebar-bg)',
          border: 'var(--sidebar-border)',
          fg: 'var(--sidebar-text)',
          strong: 'var(--sidebar-text-strong)',
          muted: 'var(--sidebar-muted)',
          hover: 'var(--sidebar-hover)',
          active: 'var(--sidebar-active)',
        },
        success: 'var(--success)',
        danger: 'var(--danger)',
        warning: 'var(--warning)',
        info: 'var(--info)',
      },
      boxShadow: {
        xs: 'var(--shadow-xs)',
        sm: 'var(--shadow-sm)',
        md: 'var(--shadow-md)',
        lg: 'var(--shadow-lg)',
        xl: 'var(--shadow-xl)',
        focus: 'var(--shadow-focus)',
      },
      borderRadius: {
        sm: 'var(--radius-sm)',
        md: 'var(--radius-md)',
        lg: 'var(--radius-lg)',
        xl: 'var(--radius-xl)',
      },
      height: {
        topbar: '60px',
        nav: '40px',
      },
      width: {
        sidebar: '240px',
        'sidebar-collapsed': '64px',
      },
      transitionDuration: {
        DEFAULT: '150ms',
      },
    },
  },
  plugins: [],
};

export default config;
