import type { Metadata } from 'next';
import { Plus_Jakarta_Sans } from 'next/font/google';
import { GeistMono } from 'geist/font/mono';
import './globals.css';
import { QueryProvider } from '@/components/providers/query-provider';
import { AppProviders } from '@/components/providers/app-providers';

const sans = Plus_Jakarta_Sans({
  subsets: ['latin'],
  variable: '--font-sans',
  display: 'swap',
});

export const metadata: Metadata = {
  title: 'Ryvo Admin',
  description: 'Ryvo platform operations dashboard',
  icons: {
    icon: '/logo.png',
    shortcut: '/logo.png',
    apple: '/logo.png',
  },
};

const themeScript = `
(function() {
  try {
    if (localStorage.getItem('ryvo-theme-visual') !== 'studio-light') {
      localStorage.setItem('ryvo-theme', 'light');
      localStorage.setItem('ryvo-theme-visual', 'studio-light');
    }
    var stored = localStorage.getItem('ryvo-theme');
    var theme = stored === 'dark' ? 'dark' : 'light';
    var root = document.documentElement;
    root.setAttribute('data-theme', theme);
    root.classList.remove('light', 'dark');
    root.classList.add(theme);
    root.style.colorScheme = theme;
  } catch (e) {}
})();
`;

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html
      lang="en"
      suppressHydrationWarning
      className={`${sans.variable} ${GeistMono.variable}`}
    >
      <head>
        <script dangerouslySetInnerHTML={{ __html: themeScript }} />
      </head>
      <body className="font-sans">
        <QueryProvider>
          <AppProviders>{children}</AppProviders>
        </QueryProvider>
      </body>
    </html>
  );
}
