'use client';

import { useState, type Dispatch, type ReactNode, type SetStateAction } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import Image from 'next/image';
import { Bell, CreditCard, Eye, EyeOff, MapPin, Plug, Shield, SlidersHorizontal, type LucideIcon } from 'lucide-react';
import { Header } from '@/components/layout/header';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Select } from '@/components/ui/select';
import { Badge } from '@/components/ui/badge';
import { toast as sonnerToast } from 'sonner';
import { apiFetch, apiMutate } from '@/lib/api';
import {
  MAP_API_KEY_SETTING,
  SETTING_LABELS,
  STRIPE_PK_SETTING,
  BILLING_TOGGLE_SETTINGS,
  CURRENCY_SETTING,
  SEARCH_TIMEOUT_SEC_SETTING,
  VEHICLE_LOOKUP_API_KEY_SETTING,
  VEHICLE_LOOKUP_BASE_URL_SETTING,
} from '@/lib/settings-meta';
import { CURRENCY_OPTIONS } from '@/lib/currency';
import { cn } from '@/lib/utils';
import { useAuth } from '@/contexts/auth-context';

interface Setting {
  key: string;
  value: unknown;
  updatedAt?: string;
}

const CANCEL_SETTING_KEYS = [
  'customer_cancel_fee_after_match',
  'customer_cancel_fee_after_arrived',
  'customer_cancel_fee_after_start',
  'provider_cancel_penalty_after_accept',
  'provider_cancel_penalty_after_arrived',
  'provider_cancel_penalty_after_start',
] as const;

const CUSTOMER_CANCEL_KEYS = CANCEL_SETTING_KEYS.slice(0, 3);
const DRIVER_CANCEL_KEYS = CANCEL_SETTING_KEYS.slice(3);

const DISPATCH_KEYS = [
  'matching_radius_km',
  'offer_timeout_sec',
  SEARCH_TIMEOUT_SEC_SETTING,
  'bid_window_sec',
  'bid_min_fare_ratio',
  'bid_max_fare_ratio',
];
const PRICING_KEYS = ['driver_monetization_mode', 'default_commission_rate', 'surge_multiplier'];
const FEATURE_KEYS = [
  'bid_counters_enabled',
  'parcel_otp_enabled',
  'whatsapp_booking_enabled',
  'whatsapp_welcome_text',
];

const HIDDEN_KEYS = new Set<string>([
  MAP_API_KEY_SETTING,
  STRIPE_PK_SETTING,
  VEHICLE_LOOKUP_BASE_URL_SETTING,
  VEHICLE_LOOKUP_API_KEY_SETTING,
  'provider_otp_enabled',
  ...BILLING_TOGGLE_SETTINGS,
  ...CANCEL_SETTING_KEYS,
]);

const TABS = [
  { id: 'general', label: 'General', hint: 'Dispatch and pricing', icon: SlidersHorizontal },
  { id: 'notifications', label: 'Notifications', hint: 'Alerts and OTP', icon: Bell },
  { id: 'integrations', label: 'Integrations', hint: 'Maps', icon: Plug },
  { id: 'billing', label: 'Billing', hint: 'Payments and fees', icon: CreditCard },
  { id: 'security', label: 'Security', hint: 'Sign-in protection', icon: Shield },
] as const;

type TabId = (typeof TABS)[number]['id'];

const NOTIFICATION_PREFS = [
  { key: 'admin_alert_kyc', label: 'KYC submissions', desc: 'Alert when a driver uploads new documents.' },
  { key: 'admin_alert_payments', label: 'Payment failures', desc: 'Alert when a card payment fails.' },
  { key: 'admin_alert_tickets', label: 'Support tickets', desc: 'Alert when a new ticket is opened.' },
  { key: 'admin_alert_payouts', label: 'Payout events', desc: 'Alert when a payout is processed.' },
];

const PAYMENT_PREFS = [
  {
    key: 'customer_wallet_enabled',
    label: 'Customer wallet',
    desc: 'Wallet tab, balance, top-up, and history in the customer app.',
  },
  {
    key: 'payment_wallet_enabled',
    label: 'Pay with wallet',
    desc: 'Wallet option at checkout. Unavailable while the customer wallet is off.',
  },
  {
    key: 'payment_stripe_enabled',
    label: 'Pay with card',
    desc: 'Stripe Payment Sheet at checkout.',
  },
  {
    key: 'payment_cash_enabled',
    label: 'Pay with cash',
    desc: 'Customer pays the driver in person when the trip ends.',
  },
];

function isEnabled(value: unknown, missingMeansOn = false) {
  if (value == null) return missingMeansOn;
  return value !== false && value !== 'false';
}

function baselineText(setting: Setting) {
  if (typeof setting.value === 'string') return setting.value;
  if (setting.value == null) return '';
  return JSON.stringify(setting.value);
}

function parseValue(raw: string, original: unknown): unknown {
  if (typeof original === 'number') return Number(raw);
  if (typeof original === 'boolean') return raw === 'true';
  if (typeof original === 'object' && original !== null) {
    try {
      return JSON.parse(raw);
    } catch {
      return raw;
    }
  }
  return raw;
}

function labelFor(key: string) {
  return SETTING_LABELS[key]?.label ?? key;
}

function descriptionFor(key: string) {
  return SETTING_LABELS[key]?.description;
}

function Toggle({
  checked,
  disabled,
  onClick,
  label,
}: {
  checked: boolean;
  disabled?: boolean;
  onClick: () => void;
  label: string;
}) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      aria-label={label}
      disabled={disabled}
      onClick={onClick}
      className={cn(
        'relative h-6 w-11 shrink-0 rounded-full transition-colors duration-150',
        checked ? 'bg-[#1fa855]' : 'bg-border',
        disabled && 'cursor-not-allowed opacity-40',
      )}
    >
      <span
        className={cn(
          'absolute top-0.5 h-5 w-5 rounded-full bg-white shadow-sm transition-transform duration-150',
          checked ? 'translate-x-5' : 'translate-x-0.5',
        )}
      />
    </button>
  );
}

function Panel({
  icon: Icon,
  title,
  description,
  children,
}: {
  icon: LucideIcon;
  title: string;
  description?: string;
  children: ReactNode;
}) {
  return (
    <section className="overflow-hidden rounded-2xl border border-border bg-elevated shadow-sm">
      <div className="flex items-start gap-3 border-b border-border px-5 py-4">
        <span className="grid h-9 w-9 shrink-0 place-items-center rounded-xl bg-accent-soft text-accent">
          <Icon className="h-4 w-4" />
        </span>
        <div className="min-w-0">
          <h2 className="text-sm font-semibold text-primary">{title}</h2>
          {description ? <p className="mt-0.5 text-sm text-secondary">{description}</p> : null}
        </div>
      </div>
      {children}
    </section>
  );
}

function Row({
  title,
  description,
  children,
}: {
  title: string;
  description?: string;
  children: ReactNode;
}) {
  return (
    <div className="flex flex-col gap-3 border-b border-border px-5 py-4 last:border-b-0 sm:flex-row sm:items-center sm:justify-between">
      <div className="min-w-0 sm:max-w-md">
        <p className="text-sm font-medium text-primary">{title}</p>
        {description ? <p className="mt-0.5 text-[13px] leading-5 text-secondary">{description}</p> : null}
      </div>
      <div className="flex w-full shrink-0 items-center gap-2 sm:w-80 sm:justify-end">{children}</div>
    </div>
  );
}

function SecretField({
  value,
  shown,
  onToggle,
  onChange,
  placeholder,
  label,
}: {
  value: string;
  shown: boolean;
  onToggle: () => void;
  onChange: (value: string) => void;
  placeholder: string;
  label: string;
}) {
  return (
    <div className="relative min-w-0 flex-1">
      <Input
        type={shown ? 'text' : 'password'}
        placeholder={placeholder}
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="pr-10 font-mono text-sm"
        autoComplete="off"
      />
      <button
        type="button"
        onClick={onToggle}
        className="absolute right-3 top-1/2 -translate-y-1/2 text-muted hover:text-primary"
        aria-label={shown ? `Hide ${label}` : `Show ${label}`}
      >
        {shown ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
      </button>
    </div>
  );
}

function SecurityTab() {
  const { user, refetch } = useAuth();
  const [code, setCode] = useState('');
  const [qrCode, setQrCode] = useState<string | null>(null);

  const setupMutation = useMutation({
    mutationFn: () => apiMutate<{ qrCode: string }>('/admin/auth/2fa/setup', 'POST'),
    onSuccess: (res) => {
      setQrCode(res.data?.qrCode ?? null);
      sonnerToast.success('Scan the QR code with your authenticator app');
    },
    onError: (err: Error) => sonnerToast.error(err.message),
  });

  const verifyMutation = useMutation({
    mutationFn: () => apiMutate('/admin/auth/2fa/verify', 'POST', { code }),
    onSuccess: () => {
      setCode('');
      setQrCode(null);
      refetch();
      sonnerToast.success('2FA enabled successfully');
    },
    onError: (err: Error) => sonnerToast.error(err.message),
  });

  return (
    <div className="space-y-5">
      <Panel
        icon={Shield}
        title="Two-factor authentication"
        description="Require a code from an authenticator app when you sign in."
      >
        <div className="flex flex-col gap-4 px-5 py-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <Badge variant={user?.totpEnabled ? 'success' : 'secondary'}>
              {user?.totpEnabled ? 'Enabled' : 'Not enabled'}
            </Badge>
            <p className="mt-2 max-w-md text-sm text-secondary">
              {user?.totpEnabled
                ? 'This account asks for a 6-digit code at sign-in.'
                : 'Set this up with Google Authenticator, 1Password, or any TOTP app.'}
            </p>
          </div>
          {!user?.totpEnabled && !qrCode ? (
            <Button loading={setupMutation.isPending} onClick={() => setupMutation.mutate()}>
              Set up 2FA
            </Button>
          ) : null}
        </div>
        {!user?.totpEnabled && qrCode ? (
          <div className="flex flex-col gap-4 border-t border-border px-5 py-4 sm:flex-row sm:items-center">
            <Image
              src={qrCode}
              alt="2FA QR code"
              width={160}
              height={160}
              className="rounded-xl border border-border bg-white p-2"
            />
            <div className="w-full max-w-xs space-y-3">
              <p className="text-sm text-secondary">Scan the code, then enter the 6 digits from the app.</p>
              <Input
                placeholder="000000"
                value={code}
                onChange={(e) => setCode(e.target.value.replace(/\D/g, '').slice(0, 6))}
                maxLength={6}
                inputMode="numeric"
                className="font-mono tracking-[0.3em]"
              />
              <Button
                disabled={code.length < 6 || verifyMutation.isPending}
                loading={verifyMutation.isPending}
                onClick={() => verifyMutation.mutate()}
              >
                Verify and enable
              </Button>
            </div>
          </div>
        ) : null}
      </Panel>

      <Panel icon={Shield} title="Sessions" description="How long a signed-in admin stays signed in.">
        <div className="grid gap-px bg-border sm:grid-cols-2">
          <div className="bg-elevated px-5 py-4">
            <p className="text-xs font-medium uppercase tracking-[0.14em] text-muted">Access token</p>
            <p className="mt-1 text-sm font-medium text-primary">15 minutes</p>
          </div>
          <div className="bg-elevated px-5 py-4">
            <p className="text-xs font-medium uppercase tracking-[0.14em] text-muted">Refresh token</p>
            <p className="mt-1 text-sm font-medium text-primary">7 days</p>
          </div>
        </div>
        <p className="border-t border-border px-5 py-4 text-sm text-secondary">
          Log out to end the current session. Refresh tokens are revoked when you sign out.
        </p>
      </Panel>
    </div>
  );
}

export default function SettingsPage() {
  const queryClient = useQueryClient();
  const [activeTab, setActiveTab] = useState<TabId>('general');
  const [drafts, setDrafts] = useState<Record<string, string>>({});
  const [mapKeyDraft, setMapKeyDraft] = useState<string | null>(null);
  const [showMapKey, setShowMapKey] = useState(false);
  const [stripeKeyDraft, setStripeKeyDraft] = useState<string | null>(null);
  const [showStripeKey, setShowStripeKey] = useState(false);

  const { data, isLoading, error } = useQuery({
    queryKey: ['settings'],
    queryFn: async () => {
      const res = await apiFetch<Setting[]>('/admin/settings');
      return res.data ?? [];
    },
  });

  const saveMutation = useMutation({
    mutationFn: ({ key, value }: { key: string; value: unknown }) =>
      apiMutate(`/admin/settings/${key}`, 'PATCH', { value }),
    onSuccess: (_data, variables) => {
      queryClient.invalidateQueries({ queryKey: ['settings'] });
      setDrafts((prev) => {
        if (prev[variables.key] === undefined) return prev;
        const next = { ...prev };
        delete next[variables.key];
        return next;
      });
      if (variables.key === MAP_API_KEY_SETTING) {
        queryClient.invalidateQueries({ queryKey: ['map-api-key'] });
        setMapKeyDraft(null);
      }
      if (variables.key === STRIPE_PK_SETTING) setStripeKeyDraft(null);
      sonnerToast.success('Setting saved');
    },
    onError: (err: Error) => sonnerToast.error(err.message),
  });

  const findSetting = (key: string) => data?.find((setting) => setting.key === key);

  const platformSettings = (() => {
    const filtered = data?.filter((setting) => !HIDDEN_KEYS.has(setting.key)) ?? [];
    if (!filtered.some((setting) => setting.key === 'provider_agreement_version')) {
      filtered.push({ key: 'provider_agreement_version', value: '1' });
    }
    if (!filtered.some((setting) => setting.key === SEARCH_TIMEOUT_SEC_SETTING)) {
      filtered.push({ key: SEARCH_TIMEOUT_SEC_SETTING, value: 60 });
    }
    if (!filtered.some((setting) => setting.key === CURRENCY_SETTING)) {
      filtered.unshift({ key: CURRENCY_SETTING, value: 'GBP' });
    }
    return filtered;
  })();

  const settingByKey = (key: string) =>
    platformSettings.find((setting) => setting.key === key) ?? { key, value: '' };

  const draftOf = (setting: Setting) => drafts[setting.key] ?? baselineText(setting);

  const dirty = (setting: Setting) =>
    drafts[setting.key] !== undefined && drafts[setting.key] !== baselineText(setting);

  const savingKey = saveMutation.isPending ? saveMutation.variables?.key : undefined;

  const saveSetting = (setting: Setting, raw = draftOf(setting)) => {
    saveMutation.mutate({
      key: setting.key,
      value: parseValue(raw, setting.value),
    });
  };

  const mapKey = mapKeyDraft ?? (typeof findSetting(MAP_API_KEY_SETTING)?.value === 'string'
    ? (findSetting(MAP_API_KEY_SETTING)?.value as string)
    : '');

  const stripeSetting = findSetting(STRIPE_PK_SETTING);
  const stripeKey =
    stripeKeyDraft ?? (typeof stripeSetting?.value === 'string' ? stripeSetting.value : '');

  const groupedKeys = new Set<string>([
    CURRENCY_SETTING,
    'surge_enabled',
    'provider_agreement_version',
    ...DISPATCH_KEYS,
    ...PRICING_KEYS,
    ...FEATURE_KEYS,
  ]);
  const otherSettings = platformSettings.filter((setting) => !groupedKeys.has(setting.key));

  const renderValueControl = (setting: Setting) => {
    if (setting.key === CURRENCY_SETTING) {
      const raw = draftOf(setting).replace(/"/g, '').trim().toUpperCase();
      const value = CURRENCY_OPTIONS.some((option) => option.code === raw) ? raw : 'GBP';
      return (
        <>
          <Select
            value={value}
            onChange={(e) => setDrafts((prev) => ({ ...prev, [setting.key]: e.target.value }))}
            className="sm:max-w-[220px]"
          >
            {CURRENCY_OPTIONS.map((option) => (
              <option key={option.code} value={option.code}>
                {option.symbol} {option.code}
              </option>
            ))}
          </Select>
          <Button
            disabled={!dirty(setting)}
            loading={savingKey === setting.key}
            onClick={() => saveSetting(setting)}
          >
            Save
          </Button>
        </>
      );
    }

    if (setting.key === 'driver_monetization_mode') {
      const raw = draftOf(setting).replace(/"/g, '').trim().toLowerCase();
      const value = raw === 'subscription' ? 'subscription' : 'commission';
      return (
        <>
          <Select
            value={value}
            onChange={(e) => setDrafts((prev) => ({ ...prev, [setting.key]: e.target.value }))}
            className="sm:max-w-[220px]"
          >
            <option value="commission">Commission</option>
            <option value="subscription">Subscription</option>
          </Select>
          <Button
            disabled={!dirty(setting)}
            loading={savingKey === setting.key}
            onClick={() => saveSetting(setting)}
          >
            Save
          </Button>
        </>
      );
    }

    if (SETTING_LABELS[setting.key]?.type === 'boolean') {
      const on = isEnabled(setting.value, false);
      return (
        <>
          <span className="mr-auto text-sm text-secondary sm:mr-2">{on ? 'On' : 'Off'}</span>
          <Toggle
            checked={on}
            disabled={savingKey === setting.key}
            label={labelFor(setting.key)}
            onClick={() => saveMutation.mutate({ key: setting.key, value: !on })}
          />
        </>
      );
    }

    const numeric = typeof setting.value === 'number' || SETTING_LABELS[setting.key]?.type === 'number';
    return (
      <>
        <Input
          type={numeric ? 'number' : 'text'}
          min={numeric ? '0' : undefined}
          step={numeric ? 'any' : undefined}
          value={draftOf(setting)}
          onChange={(e) => setDrafts((prev) => ({ ...prev, [setting.key]: e.target.value }))}
          className="font-mono text-sm"
        />
        <Button
          disabled={!dirty(setting)}
          loading={savingKey === setting.key}
          onClick={() => saveSetting(setting)}
        >
          Save
        </Button>
      </>
    );
  };

  const surgeOn = isEnabled(findSetting('surge_enabled')?.value, false);
  const walletMasterOff = !isEnabled(findSetting('customer_wallet_enabled')?.value, true);

  return (
    <>
      <Header title="Settings" description="Platform configuration" />
      <div className="flex-1 overflow-y-auto p-4 lg:p-6">
        <div className="mx-auto flex max-w-6xl flex-col gap-6 lg:flex-row lg:items-start">
          <nav className="flex gap-1 overflow-x-auto lg:sticky lg:top-0 lg:w-56 lg:shrink-0 lg:flex-col">
            {TABS.map((tab) => {
              const Icon = tab.icon;
              const active = activeTab === tab.id;
              return (
                <button
                  key={tab.id}
                  type="button"
                  onClick={() => setActiveTab(tab.id)}
                  className={cn(
                    'flex min-w-[9.5rem] items-center gap-3 rounded-xl px-3 py-2.5 text-left transition-colors lg:min-w-0 lg:w-full',
                    active
                      ? 'bg-elevated text-primary shadow-sm ring-1 ring-border'
                      : 'text-secondary hover:bg-surface hover:text-primary',
                  )}
                >
                  <span
                    className={cn(
                      'grid h-8 w-8 shrink-0 place-items-center rounded-lg',
                      active ? 'bg-accent-soft text-accent' : 'bg-surface text-muted',
                    )}
                  >
                    <Icon className="h-4 w-4" />
                  </span>
                  <span className="min-w-0">
                    <span className="block text-sm font-medium">{tab.label}</span>
                    <span className="hidden text-xs text-muted lg:block">{tab.hint}</span>
                  </span>
                </button>
              );
            })}
          </nav>

          <div className="min-w-0 flex-1 space-y-5">
            {isLoading ? <p className="text-sm text-secondary">Loading settings…</p> : null}
            {error ? <p className="text-sm text-danger">Failed to load settings.</p> : null}

            {activeTab === 'general' && !isLoading && !error ? (
              <>
                <Panel icon={SlidersHorizontal} title="Platform" description="Currency and the driver agreement version.">
                  <Row title={labelFor(CURRENCY_SETTING)} description={descriptionFor(CURRENCY_SETTING)}>
                    {renderValueControl(settingByKey(CURRENCY_SETTING))}
                  </Row>
                  <Row
                    title={labelFor('provider_agreement_version')}
                    description={descriptionFor('provider_agreement_version')}
                  >
                    {renderValueControl(settingByKey('provider_agreement_version'))}
                  </Row>
                </Panel>

                <Panel
                  icon={MapPin}
                  title="Dispatch"
                  description="How far and how long the platform looks for a driver."
                >
                  {DISPATCH_KEYS.map((key) => (
                    <Row key={key} title={labelFor(key)} description={descriptionFor(key)}>
                      {renderValueControl(settingByKey(key))}
                    </Row>
                  ))}
                </Panel>

                <Panel icon={CreditCard} title="Pricing" description="Commission and surge applied to fares.">
                  <Row title={labelFor('surge_enabled')} description={descriptionFor('surge_enabled')}>
                    <span className="mr-auto text-sm text-secondary sm:mr-2">{surgeOn ? 'On' : 'Off'}</span>
                    <Toggle
                      checked={surgeOn}
                      disabled={savingKey === 'surge_enabled'}
                      label="Surge pricing"
                      onClick={() => saveMutation.mutate({ key: 'surge_enabled', value: !surgeOn })}
                    />
                  </Row>
                  {PRICING_KEYS.map((key) => (
                    <Row key={key} title={labelFor(key)} description={descriptionFor(key)}>
                      {renderValueControl(settingByKey(key))}
                    </Row>
                  ))}
                </Panel>

                <Panel
                  icon={SlidersHorizontal}
                  title="Ride, bid, parcel, WhatsApp"
                  description="Bidding limits, parcel proof, and WhatsApp booking."
                >
                  {FEATURE_KEYS.map((key) => (
                    <Row key={key} title={labelFor(key)} description={descriptionFor(key)}>
                      {renderValueControl(settingByKey(key))}
                    </Row>
                  ))}
                </Panel>

                {otherSettings.length > 0 ? (
                  <Panel icon={SlidersHorizontal} title="Other" description="Additional platform values.">
                    {otherSettings.map((setting) => (
                      <Row key={setting.key} title={labelFor(setting.key)} description={descriptionFor(setting.key)}>
                        {renderValueControl(setting)}
                      </Row>
                    ))}
                  </Panel>
                ) : null}
              </>
            ) : null}

            {activeTab === 'notifications' ? (
              <Panel icon={Bell} title="Alerts" description="What the admin team is notified about.">
                <Row
                  title="Driver registration OTP"
                  description="New drivers verify their phone by SMS before KYC. Turn this off to skip that step."
                >
                  <span className="mr-auto text-sm text-secondary sm:mr-2">
                    {isEnabled(findSetting('provider_otp_enabled')?.value, true) ? 'On' : 'Off'}
                  </span>
                  <Toggle
                    checked={isEnabled(findSetting('provider_otp_enabled')?.value, true)}
                    disabled={savingKey === 'provider_otp_enabled'}
                    label="Driver registration OTP"
                    onClick={() =>
                      saveMutation.mutate({
                        key: 'provider_otp_enabled',
                        value: !isEnabled(findSetting('provider_otp_enabled')?.value, true),
                      })
                    }
                  />
                </Row>
                {NOTIFICATION_PREFS.map((pref) => {
                  const enabled = isEnabled(findSetting(pref.key)?.value, true);
                  return (
                    <Row key={pref.key} title={pref.label} description={pref.desc}>
                      <span className="mr-auto text-sm text-secondary sm:mr-2">{enabled ? 'On' : 'Off'}</span>
                      <Toggle
                        checked={enabled}
                        disabled={savingKey === pref.key}
                        label={pref.label}
                        onClick={() => saveMutation.mutate({ key: pref.key, value: !enabled })}
                      />
                    </Row>
                  );
                })}
              </Panel>
            ) : null}

            {activeTab === 'integrations' ? (
              <Panel
                icon={MapPin}
                title="Google Maps"
                description="Used by the live map. The key takes effect as soon as you save it."
              >
                <div className="space-y-3 px-5 py-4">
                  <div className="flex flex-wrap items-center gap-2">
                    <Badge variant={mapKey.trim() ? 'success' : 'warning'}>
                      {mapKey.trim() ? 'Configured' : 'Missing'}
                    </Badge>
                    <p className="text-sm text-secondary">
                      {mapKey.trim()
                        ? 'Live Ops will load the map with this key.'
                        : 'Live Ops shows a placeholder until a key is saved.'}
                    </p>
                  </div>
                  <div className="flex flex-col gap-2 sm:flex-row">
                    <SecretField
                      label="map API key"
                      value={mapKey}
                      shown={showMapKey}
                      onToggle={() => setShowMapKey((value) => !value)}
                      onChange={setMapKeyDraft}
                      placeholder="AIzaSy..."
                    />
                    <Button
                      loading={savingKey === MAP_API_KEY_SETTING}
                      onClick={() => saveMutation.mutate({ key: MAP_API_KEY_SETTING, value: mapKey.trim() })}
                    >
                      Save key
                    </Button>
                  </div>
                </div>
              </Panel>
            ) : null}

            {activeTab === 'billing' ? (
              <>
                <Panel
                  icon={CreditCard}
                  title="Customer payments"
                  description="Which ways a rider can pay. The customer app reads this on the next launch."
                >
                  {PAYMENT_PREFS.map((pref) => {
                    const enabled = isEnabled(findSetting(pref.key)?.value, true);
                    const blocked = pref.key === 'payment_wallet_enabled' && walletMasterOff;
                    const on = enabled && !blocked;
                    return (
                      <Row key={pref.key} title={pref.label} description={pref.desc}>
                        <div className="mr-auto flex flex-col items-start sm:mr-2 sm:items-end">
                          <span className="text-sm text-secondary">{on ? 'On' : 'Off'}</span>
                          {blocked ? (
                            <span className="text-xs text-warning">Turn on the customer wallet first.</span>
                          ) : null}
                        </div>
                        <Toggle
                          checked={on}
                          disabled={blocked || savingKey === pref.key}
                          label={pref.label}
                          onClick={() => saveMutation.mutate({ key: pref.key, value: !enabled })}
                        />
                      </Row>
                    );
                  })}
                </Panel>

                <Panel
                  icon={CreditCard}
                  title="Stripe"
                  description="Publishable key for the card payment sheet. The secret key stays in the API environment."
                >
                  <div className="space-y-3 px-5 py-4">
                    <Badge
                      variant={!stripeKey ? 'warning' : stripeKey.startsWith('pk_live_') ? 'success' : 'warning'}
                    >
                      {!stripeKey
                        ? 'Not configured'
                        : stripeKey.startsWith('pk_live_')
                          ? 'Live key'
                          : 'Test key'}
                    </Badge>
                    <p className="text-sm text-secondary">
                      {!stripeKey
                        ? 'Card payments stay off until a publishable key is saved.'
                        : stripeKey.startsWith('pk_live_')
                          ? 'Real card payments are active.'
                          : 'This is a test key. Use a pk_live_ key in production.'}
                    </p>
                    <div className="flex flex-col gap-2 sm:flex-row">
                      <SecretField
                        label="Stripe key"
                        value={stripeKey}
                        shown={showStripeKey}
                        onToggle={() => setShowStripeKey((value) => !value)}
                        onChange={setStripeKeyDraft}
                        placeholder="pk_live_... or pk_test_..."
                      />
                      <Button
                        loading={savingKey === STRIPE_PK_SETTING}
                        onClick={() =>
                          saveMutation.mutate({ key: STRIPE_PK_SETTING, value: stripeKey.trim() })
                        }
                      >
                        Save key
                      </Button>
                    </div>
                  </div>
                </Panel>

                <Panel
                  icon={CreditCard}
                  title="Cancellation fees"
                  description="Charged after a driver is matched. Cancels while still searching stay free. Use 0 to charge nothing."
                >
                  <div className="grid gap-6 px-5 py-4 lg:grid-cols-2">
                    <FeeGroup
                      title="Customer"
                      keys={CUSTOMER_CANCEL_KEYS}
                      settings={data}
                      drafts={drafts}
                      setDrafts={setDrafts}
                      savingKey={savingKey}
                      onSave={(key, value) => saveMutation.mutate({ key, value })}
                    />
                    <FeeGroup
                      title="Driver"
                      keys={DRIVER_CANCEL_KEYS}
                      settings={data}
                      drafts={drafts}
                      setDrafts={setDrafts}
                      savingKey={savingKey}
                      onSave={(key, value) => saveMutation.mutate({ key, value })}
                    />
                  </div>
                </Panel>
              </>
            ) : null}

            {activeTab === 'security' ? <SecurityTab /> : null}
          </div>
        </div>
      </div>
    </>
  );
}

function FeeGroup({
  title,
  keys,
  settings,
  drafts,
  setDrafts,
  savingKey,
  onSave,
}: {
  title: string;
  keys: readonly string[];
  settings?: Setting[];
  drafts: Record<string, string>;
  setDrafts: Dispatch<SetStateAction<Record<string, string>>>;
  savingKey?: string;
  onSave: (key: string, value: number) => void;
}) {
  return (
    <div className="space-y-3">
      <p className="text-xs font-semibold uppercase tracking-[0.14em] text-muted">{title}</p>
      {keys.map((key) => {
        const setting = settings?.find((item) => item.key === key) ?? { key, value: 0 };
        const current = drafts[key] ?? baselineText(setting);
        const changed = drafts[key] !== undefined && drafts[key] !== baselineText(setting);
        return (
          <label key={key} className="block rounded-xl border border-border bg-surface/60 p-3">
            <span className="text-sm font-medium text-primary">{labelFor(key)}</span>
            <span className="mt-0.5 block text-[13px] leading-5 text-secondary">{descriptionFor(key)}</span>
            <span className="mt-3 flex gap-2">
              <Input
                type="number"
                min="0"
                step="0.01"
                value={current}
                onChange={(e) => setDrafts((prev) => ({ ...prev, [key]: e.target.value }))}
                className="font-mono text-sm"
              />
              <Button disabled={!changed} loading={savingKey === key} onClick={() => onSave(key, Number(current) || 0)}>
                Save
              </Button>
            </span>
          </label>
        );
      })}
    </div>
  );
}
