'use client';

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
  const { setMobileOpen } = useSidebar();

  const displayName = user?.fullName ?? 'Admin';
  const displayRole = user?.adminRole
    ? (ADMIN_ROLE_LABELS[user.adminRole] ?? user.adminRole)
    : 'Admin';

  return (
    <>
      <header className="relative flex h-16 shrink-0 items-center bg-canvas px-4 lg:px-6">
        <button
          type="button"
          className="relative z-10 grid size-10 place-items-center rounded-full border border-hairline bg-sheet text-secondary lg:hidden"
          onClick={() => setMobileOpen(true)}
          aria-label="Open menu"
        >
          <svg className="size-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.75}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M4 6h16M4 12h16M4 18h16" />
          </svg>
        </button>
        <div className="pointer-events-none absolute inset-x-0 flex justify-center px-4">
        <button
          type="button"
          onClick={openPalette}
          className="pointer-events-auto hidden h-11 w-full max-w-md items-center gap-2.5 rounded-full border border-hairline bg-sheet pl-1.5 pr-2 text-sm text-muted transition-colors duration-150 hover:bg-input md:flex"
        >
          <span className="grid size-8 place-items-center rounded-full bg-input text-muted">
            <Search className="size-4" strokeWidth={1.75} />
          </span>
          <span className="flex-1 text-left">Search riders, trips, payouts…</span>
          <kbd className="num rounded-full bg-input px-2 py-1 text-[11px] font-medium text-muted">⌘K</kbd>
        </button>
        </div>

        <div className="relative z-10 ml-auto flex items-center justify-end gap-2">
          <Button
            variant="outline"
            size="icon"
            className="size-10 rounded-full bg-sheet md:hidden"
            onClick={openPalette}
            aria-label="Search"
          >
            <Search className="size-4" />
          </Button>

          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <Button variant="outline" size="icon" className="relative size-10 rounded-full bg-sheet" aria-label="Notifications">
                <Bell className="size-4 text-secondary" strokeWidth={1.75} />
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

          <ThemeToggle className="size-10 rounded-full border border-hairline bg-sheet text-secondary hover:bg-input" />

          <DropdownMenu>
            <DropdownMenuTrigger asChild>
              <button
                type="button"
                className="flex h-10 items-center gap-2 rounded-full border border-hairline bg-sheet py-1 pl-1 pr-2.5 transition-colors hover:bg-input"
              >
                <Avatar name={displayName} size="sm" className="h-8 w-8 bg-input" />
                <span className="hidden min-w-0 text-left lg:block">
                  <span className="block max-w-[9rem] truncate text-sm font-semibold leading-tight text-primary">{displayName}</span>
                  <span className="block max-w-[9rem] truncate text-[11px] leading-tight text-muted">{displayRole}</span>
                </span>
                <ChevronDown className="size-4 text-muted" strokeWidth={1.75} />
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
