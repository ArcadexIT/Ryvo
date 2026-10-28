'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import {
  Bell,
  Search,
  LogOut,
  User,
  Settings,
  CheckCheck,
  ChevronDown,
} from 'lucide-react';
import { ThemeToggle } from '@/components/layout/theme-toggle';
import { CommandPalette } from '@/components/layout/command-palette';
import { KeyboardShortcutsPanel } from '@/components/layout/keyboard-shortcuts';
import { useCommandPalette } from '@/hooks/use-command-palette';
import { useNotifications } from '@/contexts/notification-context';
import { useAuth } from '@/contexts/auth-context';
import { useSidebar } from '@/contexts/sidebar-context';
import { ADMIN_ROLE_LABELS } from '@/lib/permissions';
import { Button } from '@/components/ui/button';
import { Avatar } from '@/components/ui/avatar';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { formatDate } from '@/lib/utils';
import { cn } from '@/lib/utils';

export function Topbar() {
  const router = useRouter();
  const { open, openPalette, closePalette } = useCommandPalette();
  const { notifications, unreadCount, markAsRead, markAllAsRead } = useNotifications();
  const { user, logout } = useAuth();
  const { setMobileOpen, toggleCollapsed } = useSidebar();
  const [scrolled, setScrolled] = useState(false);

  const displayName = user?.fullName ?? 'Admin';
  const displayRole = user?.adminRole
    ? (ADMIN_ROLE_LABELS[user.adminRole] ?? user.adminRole)
    : 'Admin';

  return (
    <>
      <header
        className={cn(
          'flex h-16 shrink-0 items-center gap-3 border-b border-border bg-elevated px-4',
          scrolled && 'shadow-sm',
        )}
        onScrollCapture={(e) => setScrolled((e.target as HTMLElement).scrollTop > 0)}
      >
        <div className="flex min-w-0 flex-1 items-center gap-3">
          <button
            type="button"
            className="rounded-lg p-2 text-secondary hover:bg-surface"
            onClick={() => (window.innerWidth < 1024 ? setMobileOpen(true) : toggleCollapsed())}
            aria-label="Toggle menu"
          >
            <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
            </svg>
          </button>
          <button
            type="button"
            onClick={openPalette}
            className="hidden h-10 max-w-xl flex-1 items-center gap-2 rounded-full border border-border bg-surface px-4 text-sm text-muted transition-colors hover:bg-elevated md:flex"
          >
            <Search className="h-4 w-4 shrink-0" />
            <span className="flex-1 text-left">Search anything...</span>
            <kbd className="rounded-md border border-border bg-elevated px-1.5 py-0.5 text-[10px] text-secondary">⌘K</kbd>
          </button>
        </div>

        <div className="flex items-center gap-1">
          <Button
            variant="ghost"
            size="icon"
            className="md:hidden"
            onClick={openPalette}
            aria-label="Search"
          >
            <Search className="h-[18px] w-[18px]" />
          </Button>

          <ThemeToggle />

          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="ghost" size="icon" className="relative" aria-label="Notifications">
                <Bell className="h-[18px] w-[18px] text-secondary" />
                {unreadCount > 0 && (
                  <span className="absolute -right-0.5 -top-0.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-danger px-1 text-[10px] font-bold text-white badge-pop">
                    {unreadCount > 9 ? '9+' : unreadCount}
                  </span>
                )}
              </Button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" className="w-80">
              <div className="flex items-center justify-between px-2 py-1.5">
                <DropdownMenuLabel className="p-0">Notifications</DropdownMenuLabel>
                {unreadCount > 0 && (
                  <button
                    type="button"
                    onClick={markAllAsRead}
                    className="flex items-center gap-1 text-xs text-accent hover:underline"
                  >
                    <CheckCheck className="h-3 w-3" />
                    Mark all read
                  </button>
                )}
              </div>
              <DropdownMenuSeparator />
              <div className="max-h-72 overflow-y-auto">
                {notifications.length === 0 ? (
                  <p className="px-2 py-4 text-center text-xs text-muted">No notifications</p>
                ) : (
                  notifications.map((n) => (
                    <DropdownMenuItem
                      key={n.id}
                      className={cn('flex flex-col items-start gap-0.5 py-2', !n.read && 'bg-accent-soft/50')}
                      onClick={() => {
                        markAsRead(n.id);
                        if (n.href) router.push(n.href);
                      }}
                    >
                      <span className="text-sm font-medium text-primary">{n.title}</span>
                      <span className="text-xs text-secondary line-clamp-2">{n.message}</span>
                      <span className="text-[10px] text-muted">{formatDate(n.timestamp)}</span>
                    </DropdownMenuItem>
                  ))
                )}
              </div>
            </DropdownMenuContent>
          </DropdownMenu>

          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <button
                type="button"
                className="ml-1 flex items-center gap-2 rounded-full py-1 pl-1 pr-2 transition-colors hover:bg-surface"
              >
                <Avatar name={displayName} size="sm" className="bg-[#efe4ff] text-[#7c3aed]" />
                <span className="hidden text-sm font-medium text-primary lg:block">{displayName}</span>
                <ChevronDown className="hidden h-4 w-4 text-muted lg:block" />
              </button>
            </DropdownMenuTrigger>
            <DropdownMenuContent align="end" className="w-56">
              <DropdownMenuLabel>
                <p className="font-medium">{displayName}</p>
                <p className="text-xs font-normal text-muted">{displayRole}</p>
              </DropdownMenuLabel>
              <DropdownMenuSeparator />
              <DropdownMenuItem onClick={() => router.push('/settings')}>
                <User className="h-4 w-4" />
                View Profile
              </DropdownMenuItem>
              <DropdownMenuItem onClick={() => router.push('/settings')}>
                <Settings className="h-4 w-4" />
                Settings
              </DropdownMenuItem>
              <DropdownMenuSeparator />
              <DropdownMenuItem onClick={() => void logout()} className="text-danger focus:text-danger">
                <LogOut className="h-4 w-4" />
                Logout
              </DropdownMenuItem>
            </DropdownMenuContent>
          </DropdownMenu>
        </div>
      </header>

      <CommandPalette open={open} onClose={closePalette} />
      <KeyboardShortcutsPanel />
    </>
  );
}
