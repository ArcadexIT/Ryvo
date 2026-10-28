'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { Phone, Lock, Eye, EyeOff, AlertCircle, ShieldCheck, Zap, BarChart3 } from 'lucide-react';
import { login } from '@/lib/auth';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { ThemeToggle } from '@/components/layout/theme-toggle';
import { BrandWordmark } from '@/components/brand-wordmark';

const FEATURES = [
  { icon: BarChart3, text: 'Real-time operations & revenue insights' },
  { icon: Zap, text: 'Live dispatch and job monitoring' },
  { icon: ShieldCheck, text: 'Enterprise-grade security & audit trails' },
];

const ADMIN_PHONE = '01754713136';
const ADMIN_PASSWORD = '123456';

export default function LoginPage() {
  const router = useRouter();
  const [phone, setPhone] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const normalizedPhone = phone.trim().startsWith('+')
        ? phone.trim()
        : `+${phone.trim().replace(/[^\d]/g, '')}`;
      await login(normalizedPhone, password);
      router.push('/');
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Login failed');
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="relative flex min-h-screen bg-canvas p-3 lg:p-4">
      <div className="absolute right-6 top-6 z-20">
        <ThemeToggle />
      </div>

      <div className="relative hidden w-[46%] flex-col justify-between overflow-hidden rounded-[28px] bg-[#111111] p-12 text-white xl:p-16 lg:flex">
        <div className="pointer-events-none absolute -left-16 top-10 h-64 w-64 rounded-full bg-[#ff5500]/30 blur-3xl" />
        <div className="relative">
          <BrandWordmark className="h-8 brightness-0 invert" priority />
        </div>
        <div className="relative">
          <p className="text-xs font-semibold uppercase tracking-[0.18em] text-[#ff5500]">Operations</p>
          <h1 className="mt-4 max-w-md text-5xl font-semibold leading-[1.02] tracking-[-0.045em]">
            Run your platform with clarity.
          </h1>
          <p className="mt-4 max-w-sm text-white/60">
            Everything you need to manage jobs, providers, and payments — in one operations
            console.
          </p>
          <ul className="mt-10 space-y-4">
            {FEATURES.map(({ icon: Icon, text }) => (
              <li key={text} className="flex items-center gap-3">
                <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-white/10 text-[#ff5500]">
                  <Icon className="h-[18px] w-[18px]" />
                </span>
                <span className="text-sm text-white/75">{text}</span>
              </li>
            ))}
          </ul>
        </div>
        <p className="relative text-xs text-white/40">© {new Date().getFullYear()} Ryvo Platform. All rights reserved.</p>
      </div>

      <div className="flex w-full flex-col items-center justify-center px-6 py-12 lg:w-[54%]">
        <div className="w-full max-w-sm animate-fade-in-up">
          <div className="mb-8 flex flex-col items-center text-center lg:items-start lg:text-left">
            <div className="mb-6 flex h-14 w-auto items-center justify-center rounded-2xl bg-elevated px-4 shadow-md ring-1 ring-border lg:hidden">
              <BrandWordmark className="h-7" priority />
            </div>
            <h2 className="font-display text-2xl font-semibold text-primary">Welcome back</h2>
            <p className="mt-2 text-sm text-secondary">Sign in to the Ryvo operations dashboard</p>
          </div>

          <Button
            type="button"
            variant="secondary"
            className="mb-4 w-full"
            onClick={() => {
              setPhone(ADMIN_PHONE);
              setPassword(ADMIN_PASSWORD);
              setError(null);
            }}
          >
            Autofill
          </Button>

          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="space-y-2">
              <label htmlFor="phone" className="text-sm font-medium text-secondary">
                Phone number
              </label>
              <div className="relative">
                <Phone className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted" />
                <Input
                  id="phone"
                  type="tel"
                  placeholder="01754713136"
                  value={phone}
                  onChange={(e) => setPhone(e.target.value)}
                  className="pl-10"
                  required
                  autoComplete="tel"
                />
              </div>
            </div>

            <div className="space-y-2">
              <div className="flex items-center justify-between">
                <label htmlFor="password" className="text-sm font-medium text-secondary">
                  Password
                </label>
              </div>
              <div className="relative">
                <Lock className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted" />
                <Input
                  id="password"
                  type={showPassword ? 'text' : 'password'}
                  placeholder="••••••••"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="pl-10 pr-10"
                  required
                  autoComplete="current-password"
                />
                <button
                  type="button"
                  onClick={() => setShowPassword((v) => !v)}
                  className="absolute right-3 top-1/2 -translate-y-1/2 text-muted transition-colors hover:text-secondary"
                  aria-label={showPassword ? 'Hide password' : 'Show password'}
                  tabIndex={-1}
                >
                  {showPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                </button>
              </div>
            </div>

            {error && (
              <div className="flex items-start gap-2 rounded-md border border-danger/20 bg-danger/10 px-3 py-2.5 text-sm text-danger animate-fade-in-up">
                <AlertCircle className="mt-0.5 h-4 w-4 shrink-0" />
                <span>{error}</span>
              </div>
            )}

            <Button
              type="submit"
              className="w-full bg-gradient-to-r from-orange-500 to-accent text-white shadow-md hover:brightness-105"
              size="lg"
              loading={loading}
            >
              Sign In
            </Button>
          </form>

          <p className="mt-8 text-center text-xs text-muted lg:text-left">
            Protected by enterprise-grade security. Contact your administrator if you need
            access.
          </p>
        </div>
      </div>
    </div>
  );
}
