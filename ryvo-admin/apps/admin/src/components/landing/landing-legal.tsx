import { LEGAL_DEFAULTS, type LegalKey } from '../../../../api/src/cms/legal-defaults';
import { LegalDocumentBody } from '@/components/legal/legal-document-body';

export interface PublicLegalDocument {
  key: string;
  title: string;
  content: string;
  updatedAt?: string;
}

async function loadLegal(key: LegalKey): Promise<PublicLegalDocument> {
  const fallback = { key, ...LEGAL_DEFAULTS[key] };
  const base = process.env.NEXT_PUBLIC_API_URL ?? 'http://localhost:4000/api/v1';
  try {
    const res = await fetch(`${base}/legal/${key}`, { cache: 'no-store' });
    if (!res.ok) return fallback;
    const json = (await res.json()) as { data?: PublicLegalDocument };
    if (!json.data?.title || !json.data.content) return fallback;
    return json.data;
  } catch {
    return fallback;
  }
}

function formatUpdated(value?: string) {
  if (!value) return null;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return null;
  return date.toLocaleDateString('en-GB', { day: 'numeric', month: 'long', year: 'numeric' });
}

export async function LandingLegal({ documentKey }: { documentKey: LegalKey }) {
  const document = await loadLegal(documentKey);
  const updated = formatUpdated(document.updatedAt);

  return (
    <main>
      <section className="landing-section bg-[var(--landing-cream)]">
        <div className="mx-auto max-w-3xl px-4 sm:px-6 lg:px-8">
          <p className="landing-eyebrow">Legal</p>
          <h1 className="landing-text-navy mt-5 text-4xl sm:text-5xl lg:text-6xl">{document.title}</h1>
          {updated ? <p className="landing-text-muted mt-5 text-base">Last updated: {updated}</p> : null}
        </div>
      </section>

      <article className="landing-prose mx-auto max-w-3xl px-4 py-12 sm:px-6 sm:py-16 lg:px-8 lg:py-20">
        <LegalDocumentBody content={document.content} variant="landing" />
      </article>
    </main>
  );
}
