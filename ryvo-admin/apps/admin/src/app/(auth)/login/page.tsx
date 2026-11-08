'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { Phone, Lock, Eye, EyeOff, AlertCircle, ShieldCheck, Zap, BarChart3 } from 'lucide-react';
import { login } from '@/lib/auth';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { ThemeToggle } from '@/components/layout/theme-toggle';
import Image from 'next/image';
import { BrandWordmark } from '@/components/brand-wordmark';
import { useTheme } from '@/hooks/use-theme';

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
  const { theme } = useTheme();

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
    <div className="relative flex min-h-screen bg-canvas p-2">
      <div className="absolute right-5 top-5 z-20">
        <ThemeToggle />
      </div>

      <div className="relative hidden w-[46%] flex-col justify-between overflow-hidden rounded-xl bg-primary p-12 text-primary-fg lg:flex xl:p-16">
        <div
          aria-hidden
          className="pointer-events-none absolute inset-0 opacity-40"
          style={{
            backgroundImage:
              'linear-gradient(var(--hairline) 1px, transparent 1px), linear-gradient(90deg, var(--hairline) 1px, transparent 1px)',
            backgroundSize: '28px 28px',
          }}
        />
        <div className="relative">
          <Image
            src={theme === 'dark' ? '/logo-wordmark.png' : '/logo-wordmark-light.png'}
            alt="Ryvo"
            width={1415}
            height={360}
            priority
            className="h-8 w-auto"
          />
        </div>
        <div className="relative">
          <p className="text-xs font-semibold uppercase tracking-[0.16em] text-emphasis">Operations</p>
          <h1 className="mt-4 max-w-md text-4xl font-semibold leading-[1.05] tracking-tight">
            Run the network from one console.
          </h1>
          <ul className="mt-10 space-y-4">
            {FEATURES.map(({ icon: Icon, text }) => (
              <li key={text} className="flex items-center gap-3">
                <span className="grid size-9 shrink-0 place-items-center rounded-full bg-primary-fg/10">
                  <Icon className="size-4" strokeWidth={1.75} />
                </span>
                <span className="text-sm text-primary-fg/80">{text}</span>
              </li>
            ))}
          </ul>
        </div>
        <p className="relative text-xs text-primary-fg/50">© {new Date().getFullYear()} Ryvo</p>
      </div>

      <div className="flex w-full flex-col items-center justify-center px-6 py-12 lg:w-[54%]">
        <div className="w-full max-w-sm">
          <div className="mb-8">
            <div className="mb-6 lg:hidden">
              <BrandWordmark className="h-7" priority />
            </div>
            <h2 className="page-title">Welcome back</h2>
            <p className="mt-2 text-sm text-muted">Sign in to the Ryvo operations dashboard</p>
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
              <label htmlFor="phone" className="text-sm font-medium text-primary">
                Phone number
              </label>
              <Input
                id="phone"
                type="tel"
                placeholder="01754713136"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                leading={<Phone strokeWidth={1.75} />}
                required
                autoComplete="tel"
              />
            </div>

            <div className="space-y-2">
              <label htmlFor="password" className="text-sm font-medium text-primary">
                Password
              </label>
              <Input
                id="password"
                type={showPassword ? 'text' : 'password'}
                placeholder="Password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                leading={<Lock strokeWidth={1.75} />}
                trailing={
                  <button
                    type="button"
                    onClick={() => setShowPassword((v) => !v)}
                    className="text-muted hover:text-primary"
                    aria-label={showPassword ? 'Hide password' : 'Show password'}
                  >
                    {showPassword ? <EyeOff className="size-4" strokeWidth={1.75} /> : <Eye className="size-4" strokeWidth={1.75} />}
                  </button>
                }
                required
                autoComplete="current-password"
              />
            </div>

            {error ? (
              <div className="flex items-start gap-2 rounded-md bg-danger/10 px-3 py-2.5 text-sm text-danger">
                <AlertCircle className="mt-0.5 size-4 shrink-0" strokeWidth={1.75} />
                <span>{error}</span>
              </div>
            ) : null}

            <Button type="submit" variant="emphasis" className="w-full" size="lg" loading={loading}>
              Sign in
            </Button>
          </form>
        </div>
      </div>
    </div>
  );
}
