'use client';

import { ThemeProvider } from '@/contexts/theme-context';
import { NotificationProvider } from '@/contexts/notification-context';
import { SidebarProvider } from '@/contexts/sidebar-context';
import { AuthProvider } from '@/contexts/auth-context';
import { Toaster } from 'sonner';

export function AppProviders({ children }: { children: React.ReactNode }) {
  return (
    <ThemeProvider>
      <AuthProvider>
        <NotificationProvider>
          <SidebarProvider>
            {children}
            <Toaster
              position="bottom-right"
              duration={4000}
              toastOptions={{
                classNames: {
                  toast:
                    'bg-sheet border border-hairline text-primary shadow-popover rounded-xl',
                  success: 'border-success/30',
                  error: 'border-danger/30',
                  warning: 'border-warning/30',
                  info: 'border-info/30',
                },
              }}
            />
          </SidebarProvider>
        </NotificationProvider>
      </AuthProvider>
    </ThemeProvider>
  );
}
