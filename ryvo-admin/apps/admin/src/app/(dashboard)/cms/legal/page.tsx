'use client';

import { useEffect, useRef, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Header } from '@/components/layout/header';
import { PageContent } from '@/components/layout/page-content';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { LegalDocumentBody } from '@/components/legal/legal-document-body';
import { apiFetch, apiMutate } from '@/lib/api';
import { cn } from '@/lib/utils';
import { toast } from 'sonner';

type LegalKey = 'terms' | 'privacy';

interface LegalDocument {
  key: LegalKey;
  title: string;
  content: string;
  updatedAt: string;
}

const KEYS: LegalKey[] = ['terms', 'privacy'];

const KEY_LABELS: Record<LegalKey, string> = {
  terms: 'Terms and Conditions',
  privacy: 'Privacy Policy',
};

export default function LegalDocumentsPage() {
  const queryClient = useQueryClient();
  const documents = useQuery({
    queryKey: ['cms-legal'],
    queryFn: async () => (await apiFetch<LegalDocument[]>('/admin/cms/legal')).data ?? [],
  });

  const [activeKey, setActiveKey] = useState<LegalKey>('terms');
  const [title, setTitle] = useState('');
  const [content, setContent] = useState('');

  const active = documents.data?.find((doc) => doc.key === activeKey);
  const documentsRef = useRef(documents.data);
  documentsRef.current = documents.data;
  const revision = `${activeKey}:${active?.updatedAt ?? ''}`;

  useEffect(() => {
    const doc = documentsRef.current?.find((item) => item.key === activeKey);
    if (!doc) return;
    setTitle(doc.title);
    setContent(doc.content);
  }, [revision, activeKey]);

  const dirty = !!active && (title !== active.title || content !== active.content);

  const save = useMutation({
    mutationFn: () =>
      apiMutate<LegalDocument>(`/admin/cms/legal/${activeKey}`, 'PATCH', {
        title: title.trim(),
        content: content.trim(),
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['cms-legal'] });
      toast.success('Document saved');
    },
    onError: (err: Error) => toast.error(err.message || 'Could not save document'),
  });

  const updatedLabel = active?.updatedAt
    ? new Date(active.updatedAt).toLocaleString('en-GB', {
        day: 'numeric',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit',
      })
    : null;

  return (
    <>
      <Header
        title="Legal"
        description="Edit the Terms and Conditions and Privacy Policy shown on the landing page and in the customer app."
      />
      <PageContent>
        {documents.error ? (
          <Card>
            <CardContent className="py-8 text-sm text-danger">
              {(documents.error as Error).message || 'Could not load legal documents.'}
            </CardContent>
          </Card>
        ) : null}

        <div className="grid items-start gap-6 xl:grid-cols-[240px_minmax(0,1fr)]">
          <div className="space-y-2">
            {KEYS.map((key) => {
              const doc = documents.data?.find((item) => item.key === key);
              const selected = key === activeKey;
              return (
                <button
                  key={key}
                  type="button"
                  onClick={() => setActiveKey(key)}
                  className={cn(
                    'w-full rounded-xl border px-3 py-3 text-left transition-colors',
                    selected
                      ? 'border-accent bg-accent-soft'
                      : 'border-border bg-elevated hover:border-border-strong',
                  )}
                >
                  <span className="block text-sm font-medium text-primary">
                    {doc?.title || KEY_LABELS[key]}
                  </span>
                  <span className="mt-1 block text-xs text-secondary">
                    {key === 'terms' ? 'Landing /terms' : 'Landing /privacy-policy'}
                  </span>
                </button>
              );
            })}
          </div>

          <Card>
            <CardContent className="space-y-4 p-5">
              {documents.isLoading ? (
                <div className="h-80 animate-pulse rounded-lg bg-elevated" />
              ) : (
                <>
                  <div className="flex flex-wrap items-center justify-between gap-3">
                    <div>
                      <p className="text-sm font-medium text-primary">{KEY_LABELS[activeKey]}</p>
                      {updatedLabel ? (
                        <p className="mt-1 text-xs text-secondary">Last saved {updatedLabel}</p>
                      ) : null}
                    </div>
                    <Button onClick={() => save.mutate()} disabled={!dirty || save.isPending || !title.trim() || !content.trim()} loading={save.isPending}>
                      Save changes
                    </Button>
                  </div>

                  <label className="block space-y-1.5">
                    <span className="text-xs font-medium text-secondary">Title</span>
                    <Input value={title} onChange={(event) => setTitle(event.target.value)} />
                  </label>

                  <label className="block space-y-1.5">
                    <span className="text-xs font-medium text-secondary">Content</span>
                    <Textarea
                      value={content}
                      onChange={(event) => setContent(event.target.value)}
                      className="min-h-[420px] font-mono text-[13px] leading-relaxed"
                    />
                    <span className="block text-xs text-muted">
                      Separate paragraphs with a blank line. Start a line with ## for a heading and - for a bullet.
                    </span>
                  </label>

                  <div className="rounded-xl border border-border bg-base p-5">
                    <p className="text-xs font-medium uppercase tracking-wide text-muted">Preview</p>
                    <div className="mt-4">
                      <LegalDocumentBody content={content} variant="admin" />
                    </div>
                  </div>
                </>
              )}
            </CardContent>
          </Card>
        </div>
      </PageContent>
    </>
  );
}
