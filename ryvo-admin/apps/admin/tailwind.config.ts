import type { Config } from 'tailwindcss';

/** Solid token at full strength, and `/10`-style modifiers via color-mix. */
function mix(token: string) {
  return `color-mix(in srgb, var(${token}) calc(<alpha-value> * 100%), transparent)`;
}

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
        xs: ['0.75rem', { lineHeight: '1rem', letterSpacing: '0' }],
        sm: ['0.8125rem', { lineHeight: '1.125rem', letterSpacing: '-0.006em' }],
        base: ['0.875rem', { lineHeight: '1.25rem', letterSpacing: '-0.011em' }],
        lg: ['1rem', { lineHeight: '1.5rem', letterSpacing: '-0.011em' }],
        xl: ['1.25rem', { lineHeight: '1.75rem', letterSpacing: '-0.02em' }],
        '2xl': ['1.5rem', { lineHeight: '2rem', letterSpacing: '-0.02em' }],
        '3xl': ['2rem', { lineHeight: '2.25rem', letterSpacing: '-0.02em' }],
        stat: ['1.5rem', { lineHeight: '2rem', letterSpacing: '-0.02em', fontWeight: '700' }],
        'stat-lg': ['2rem', { lineHeight: '2.25rem', letterSpacing: '-0.02em', fontWeight: '700' }],
      },
      colors: {
        canvas: mix('--canvas'),
        sheet: mix('--sheet'),
        card: mix('--card'),
        input: mix('--input'),
        foreground: mix('--text'),
        hairline: mix('--hairline'),
        base: mix('--bg-base'),
        surface: mix('--bg-surface'),
        elevated: mix('--bg-elevated'),
        overlay: mix('--bg-overlay'),
        border: mix('--border'),
        'border-strong': mix('--border-strong'),
        primary: {
          DEFAULT: mix('--text'),
          fg: mix('--primary-fg'),
        },
        secondary: mix('--text-muted'),
        muted: mix('--text-muted'),
        emphasis: {
          DEFAULT: mix('--emphasis'),
          fg: mix('--emphasis-fg'),
        },
        accent: {
          DEFAULT: mix('--accent'),
          hover: mix('--accent-hover'),
          soft: mix('--accent-soft'),
          foreground: mix('--accent-foreground'),
        },
        sidebar: {
          DEFAULT: mix('--sidebar-bg'),
          border: mix('--sidebar-border'),
          fg: mix('--sidebar-text'),
          strong: mix('--sidebar-text-strong'),
          muted: mix('--sidebar-muted'),
          hover: mix('--sidebar-hover'),
          active: mix('--sidebar-active'),
        },
        success: mix('--success'),
        danger: mix('--danger'),
        warning: mix('--warning'),
        info: mix('--info'),
      },
      backgroundColor: {
        primary: {
          DEFAULT: mix('--primary'),
          fg: mix('--primary-fg'),
        },
      },
      boxShadow: {
        xs: 'var(--shadow-xs)',
        sm: 'var(--shadow-sm)',
        md: 'var(--shadow-md)',
        lg: 'var(--shadow-lg)',
        xl: 'var(--shadow-xl)',
        focus: 'var(--shadow-focus)',
        popover: 'var(--shadow-popover)',
      },
      borderRadius: {
        sm: 'var(--radius-sm)',
        md: 'var(--radius-md)',
        lg: 'var(--radius-lg)',
        xl: 'var(--radius-xl)',
      },
      height: {
        topbar: '56px',
        nav: '40px',
      },
      width: {
        sidebar: '240px',
        'sidebar-collapsed': '64px',
      },
      transitionDuration: {
        DEFAULT: '150ms',
      },
      transitionTimingFunction: {
        out: 'cubic-bezier(0, 0, 0.2, 1)',
      },
    },
  },
  plugins: [],
};

export default config;
