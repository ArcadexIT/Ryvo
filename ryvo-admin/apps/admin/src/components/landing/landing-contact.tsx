'use client';

import { useEffect, useMemo, useState } from 'react';
import { useSearchParams } from 'next/navigation';
import { Bug, LifeBuoy, Mail, Trash2 } from 'lucide-react';

const SUPPORT_EMAIL = 'enquiries@ryvo.arcadexit.com';

type TopicId = 'support' | 'bug' | 'account-deletion';

const TOPICS: {
  id: TopicId;
  label: string;
  subjectPrefix: string;
  placeholder: string;
}[] = [
  {
    id: 'support',
    label: 'Help & Support',
    subjectPrefix: 'Help & Support',
    placeholder: 'Tell us how we can help you…',
  },
  {
    id: 'bug',
    label: 'Report an issue or bug',
    subjectPrefix: 'Issue / Bug report',
    placeholder: 'Describe the issue, what you expected, and the steps to reproduce it…',
  },
  {
    id: 'account-deletion',
    label: 'Account deletion request',
    subjectPrefix: 'Account deletion request',
    placeholder:
      'Please confirm the phone number and/or email linked to your RYVO account so we can verify and delete it.',
  },
];

function normaliseTopic(value: string | null): TopicId {
  if (value === 'bug' || value === 'account-deletion' || value === 'support') {
    return value;
  }
  if (value === 'delete' || value === 'deletion' || value === 'account') {
    return 'account-deletion';
  }
  return 'support';
}

export function LandingContact() {
  const searchParams = useSearchParams();
  const [topic, setTopic] = useState<TopicId>('support');
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [phone, setPhone] = useState('');
  const [message, setMessage] = useState('');

  useEffect(() => {
    setTopic(normaliseTopic(searchParams.get('topic')));
  }, [searchParams]);

  const activeTopic = useMemo(
    () => TOPICS.find((item) => item.id === topic) ?? TOPICS[0],
    [topic],
  );

  function handleSubmit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const subject = `[RYVO] ${activeTopic.subjectPrefix}`;
    const bodyLines = [
      `Topic: ${activeTopic.label}`,
      `Name: ${name || '-'}`,
      `Email: ${email || '-'}`,
      `Phone: ${phone || '-'}`,
      '',
      'Message:',
      message || '-',
    ];
    const mailto = `mailto:${SUPPORT_EMAIL}?subject=${encodeURIComponent(
      subject,
    )}&body=${encodeURIComponent(bodyLines.join('\n'))}`;
    window.location.href = mailto;
  }

  return (
    <main>
      <section className="landing-section bg-[var(--landing-cream)]">
        <div className="mx-auto max-w-3xl px-4 sm:px-6 lg:px-8">
          <p className="landing-eyebrow">Support</p>
          <h1 className="landing-text-navy mt-5 text-4xl sm:text-5xl lg:text-6xl">
            Contact RYVO
          </h1>
          <p className="landing-text-muted mt-5 max-w-2xl text-base leading-relaxed">
            Need a hand, found a bug, or want to delete your account? Pick a topic below and send us a
            message. Our team typically replies within 1–2 business days.
          </p>
        </div>
      </section>

      <section className="mx-auto max-w-5xl px-4 pb-16 sm:px-6 sm:pb-20 lg:px-8 lg:pb-24">
        <div className="grid gap-8 lg:grid-cols-[1.1fr_0.9fr]">
          {/* Contact form */}
          <div className="landing-card p-6 sm:p-8">
            <h2 className="landing-text-navy text-2xl">Send us a message</h2>
            <p className="landing-text-muted mt-2 text-sm">
              Choose what you need help with and we&apos;ll point it to the right team.
            </p>

            <form className="mt-6 space-y-5" onSubmit={handleSubmit}>
              <div>
                <label htmlFor="topic" className="landing-text-navy block text-sm font-semibold">
                  Topic
                </label>
                <select
                  id="topic"
                  value={topic}
                  onChange={(event) => setTopic(event.target.value as TopicId)}
                  className="mt-2 w-full rounded-xl border border-[var(--landing-border)] bg-[var(--landing-paper)] px-4 py-3 text-sm text-[var(--landing-navy)] outline-none focus:border-[var(--landing-orange)]"
                >
                  {TOPICS.map((item) => (
                    <option key={item.id} value={item.id}>
                      {item.label}
                    </option>
                  ))}
                </select>
              </div>

              <div className="grid gap-5 sm:grid-cols-2">
                <div>
                  <label htmlFor="name" className="landing-text-navy block text-sm font-semibold">
                    Full name
                  </label>
                  <input
                    id="name"
                    type="text"
                    value={name}
                    onChange={(event) => setName(event.target.value)}
                    className="mt-2 w-full rounded-xl border border-[var(--landing-border)] bg-[var(--landing-paper)] px-4 py-3 text-sm text-[var(--landing-navy)] outline-none focus:border-[var(--landing-orange)]"
                    placeholder="Your name"
                  />
                </div>
                <div>
                  <label htmlFor="phone" className="landing-text-navy block text-sm font-semibold">
                    Phone number
                  </label>
                  <input
                    id="phone"
                    type="tel"
                    value={phone}
                    onChange={(event) => setPhone(event.target.value)}
                    className="mt-2 w-full rounded-xl border border-[var(--landing-border)] bg-[var(--landing-paper)] px-4 py-3 text-sm text-[var(--landing-navy)] outline-none focus:border-[var(--landing-orange)]"
                    placeholder="e.g. +44 7700 900000"
                  />
                </div>
              </div>

              <div>
                <label htmlFor="email" className="landing-text-navy block text-sm font-semibold">
                  Email address
                </label>
                <input
                  id="email"
                  type="email"
                  required
                  value={email}
                  onChange={(event) => setEmail(event.target.value)}
                  className="mt-2 w-full rounded-xl border border-[var(--landing-border)] bg-[var(--landing-paper)] px-4 py-3 text-sm text-[var(--landing-navy)] outline-none focus:border-[var(--landing-orange)]"
                  placeholder="you@example.com"
                />
              </div>

              <div>
                <label htmlFor="message" className="landing-text-navy block text-sm font-semibold">
                  Message
                </label>
                <textarea
                  id="message"
                  required
                  rows={5}
                  value={message}
                  onChange={(event) => setMessage(event.target.value)}
                  className="mt-2 w-full resize-y rounded-xl border border-[var(--landing-border)] bg-[var(--landing-paper)] px-4 py-3 text-sm text-[var(--landing-navy)] outline-none focus:border-[var(--landing-orange)]"
                  placeholder={activeTopic.placeholder}
                />
              </div>

              <button
                type="submit"
                className="inline-flex w-full items-center justify-center gap-2 rounded-full bg-[var(--landing-orange)] px-6 py-3.5 text-sm font-semibold text-white transition-colors hover:bg-[var(--landing-orange-hover)] sm:w-auto"
              >
                <Mail className="h-4 w-4" />
                Send message
              </button>

              <p className="landing-text-muted text-xs leading-relaxed">
                This opens your email app addressed to{' '}
                <a
                  href={`mailto:${SUPPORT_EMAIL}`}
                  className="font-medium text-[var(--landing-orange)] hover:underline"
                >
                  {SUPPORT_EMAIL}
                </a>
                . If it doesn&apos;t open, email us directly at that address.
              </p>
            </form>
          </div>

          {/* Topic cards + account deletion details */}
          <div className="space-y-5">
            <div className="landing-card p-6">
              <div className="flex items-start gap-3">
                <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-[var(--landing-peach)] text-[var(--landing-orange)]">
                  <LifeBuoy className="h-5 w-5" />
                </span>
                <div>
                  <h3 className="landing-text-navy text-base font-semibold">Help &amp; Support</h3>
                  <p className="landing-text-muted mt-1 text-sm leading-relaxed">
                    Questions about a job, payments, your account or using the app.
                  </p>
                </div>
              </div>
            </div>

            <div className="landing-card p-6">
              <div className="flex items-start gap-3">
                <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-[var(--landing-peach)] text-[var(--landing-orange)]">
                  <Bug className="h-5 w-5" />
                </span>
                <div>
                  <h3 className="landing-text-navy text-base font-semibold">Report an issue or bug</h3>
                  <p className="landing-text-muted mt-1 text-sm leading-relaxed">
                    Something not working? Tell us what happened so we can fix it quickly.
                  </p>
                </div>
              </div>
            </div>

            <div id="account-deletion" className="landing-card p-6">
              <div className="flex items-start gap-3">
                <span className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-[var(--landing-peach)] text-[var(--landing-orange)]">
                  <Trash2 className="h-5 w-5" />
                </span>
                <div>
                  <h3 className="landing-text-navy text-base font-semibold">
                    Account &amp; data deletion
                  </h3>
                  <p className="landing-text-muted mt-1 text-sm leading-relaxed">
                    You can request deletion of your RYVO account and associated personal data at any
                    time.
                  </p>
                  <ol className="landing-text-muted mt-3 list-decimal space-y-1.5 pl-5 text-sm leading-relaxed">
                    <li>
                      Select <strong className="landing-text-navy">Account deletion request</strong>{' '}
                      in the form, or email{' '}
                      <a
                        href={`mailto:${SUPPORT_EMAIL}?subject=${encodeURIComponent(
                          '[RYVO] Account deletion request',
                        )}`}
                        className="font-medium text-[var(--landing-orange)] hover:underline"
                      >
                        {SUPPORT_EMAIL}
                      </a>
                      .
                    </li>
                    <li>
                      Include the phone number and/or email linked to your account so we can verify
                      ownership.
                    </li>
                    <li>We verify your request and delete your account within 30 days.</li>
                  </ol>
                  <p className="landing-text-muted mt-3 text-sm leading-relaxed">
                    We delete your profile, contact details, vehicle information and service history.
                    Certain records (for example transaction and tax records) may be retained where
                    required by law.
                  </p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>
    </main>
  );
}
