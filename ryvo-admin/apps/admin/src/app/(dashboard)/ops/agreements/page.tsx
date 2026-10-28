'use client';

import { useEffect, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Check, ChevronDown, ChevronUp, Plus, Trash2 } from 'lucide-react';
import { Header } from '@/components/layout/header';
import { PageContent } from '@/components/layout/page-content';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Card, CardContent } from '@/components/ui/card';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { apiFetch, apiMutate } from '@/lib/api';
import { cn } from '@/lib/utils';
import { toast } from 'sonner';

type AgreementKey = 'service' | 'tax_status' | 'insurance';

interface AgreementDocument {
  id: string;
  key: AgreementKey;
  version: string;
  title: string;
  body: string;
  acknowledgements: string[];
  isCurrent: boolean;
}

interface Draft {
  version: string;
  title: string;
  body: string;
  acknowledgements: string[];
}

const AGREEMENT_KEYS: AgreementKey[] = ['service', 'tax_status', 'insurance'];

const KEY_LABELS: Record<AgreementKey, string> = {
  service: 'Driver service agreement',
  tax_status: 'Driver status and tax',
  insurance: 'Insurance and cover',
};

const fieldClass = 'border-border-strong bg-base';

function nextVersion(version: string) {
  const match = version.trim().match(/^(\d+)(.*)$/);
  if (!match) return '1';
  return `${Number(match[1]) + 1}${match[2]}`;
}

function sortDocuments(documents: AgreementDocument[]) {
  return [...documents].sort(
    (a, b) => AGREEMENT_KEYS.indexOf(a.key) - AGREEMENT_KEYS.indexOf(b.key),
  );
}

function draftFrom(doc: AgreementDocument | undefined, key: AgreementKey): Draft {
  return {
    version: doc ? nextVersion(doc.version) : '1',
    title: doc?.title ?? '',
    body: doc?.body ?? '',
    acknowledgements: doc?.acknowledgements?.length ? [...doc.acknowledgements] : [''],
  };
}

function sameStatements(left: string[], right: string[]) {
  return left.length === right.length && left.every((item, index) => item === right[index]);
}

export default function AgreementsPage() {
  const queryClient = useQueryClient();
  const agreements = useQuery({
    queryKey: ['admin-agreements'],
    queryFn: async () => (await apiFetch<AgreementDocument[]>('/admin/agreements')).data ?? [],
  });

  const documents = sortDocuments(agreements.data ?? []);
  const [activeKey, setActiveKey] = useState<AgreementKey>('service');
  const [drafts, setDrafts] = useState<Record<AgreementKey, Draft> | null>(null);
  const [previewOn, setPreviewOn] = useState<boolean[]>([]);

  useEffect(() => {
    if (!agreements.data || drafts) return;
    const next = {} as Record<AgreementKey, Draft>;
    for (const key of AGREEMENT_KEYS) {
      next[key] = draftFrom(
        agreements.data.find((doc) => doc.key === key),
        key,
      );
    }
    setDrafts(next);
  }, [agreements.data, drafts]);

  const draft = drafts?.[activeKey];
  const published = documents.find((doc) => doc.key === activeKey);
  const statementCount = draft?.acknowledgements.length ?? 0;

  useEffect(() => {
    setPreviewOn(Array.from({ length: statementCount }, () => false));
  }, [activeKey, statementCount]);

  const updateDraft = (patch: Partial<Draft>) => {
    setDrafts((current) =>
      current ? { ...current, [activeKey]: { ...current[activeKey], ...patch } } : current,
    );
  };

  const updateStatement = (index: number, value: string) => {
    if (!draft) return;
    const acknowledgements = draft.acknowledgements.map((item, itemIndex) =>
      itemIndex === index ? value : item,
    );
    updateDraft({ acknowledgements });
  };

  const moveStatement = (index: number, direction: -1 | 1) => {
    if (!draft) return;
    const target = index + direction;
    if (target < 0 || target >= draft.acknowledgements.length) return;
    const acknowledgements = [...draft.acknowledgements];
    const [item] = acknowledgements.splice(index, 1);
    acknowledgements.splice(target, 0, item);
    updateDraft({ acknowledgements });
    setPreviewOn((current) => {
      const next = [...current];
      const [checked] = next.splice(index, 1);
      next.splice(target, 0, checked);
      return next;
    });
  };

  const removeStatement = (index: number) => {
    if (!draft || draft.acknowledgements.length < 2) return;
    updateDraft({ acknowledgements: draft.acknowledgements.filter((_, itemIndex) => itemIndex !== index) });
  };

  const publish = useMutation({
    mutationFn: () => {
      if (!draft) throw new Error('Agreement is still loading.');
      return apiMutate<AgreementDocument>('/admin/agreements', 'POST', {
        key: activeKey,
        version: draft.version.trim(),
        title: draft.title.trim(),
        body: draft.body.trim(),
        acknowledgements: draft.acknowledgements.map((item) => item.trim()).filter(Boolean),
      });
    },
    onSuccess: (res) => {
      const publishedDoc = res.data;
      toast.success('Agreement published. Drivers must accept it before going online.');
      if (publishedDoc) {
        setDrafts((current) =>
          current
            ? {
                ...current,
                [publishedDoc.key]: {
                  version: nextVersion(publishedDoc.version),
                  title: publishedDoc.title,
                  body: publishedDoc.body,
                  acknowledgements: [...publishedDoc.acknowledgements],
                },
              }
            : current,
        );
      }
      queryClient.invalidateQueries({ queryKey: ['admin-agreements'] });
    },
    onError: (err: Error) => toast.error(err.message),
  });

  const statementsReady = !!draft?.acknowledgements.some((item) => item.trim());
  const canPublish =
    !!draft &&
    !!draft.title.trim() &&
    !!draft.body.trim() &&
    !!draft.version.trim() &&
    statementsReady &&
    draft.acknowledgements.every((item) => item.trim()) &&
    !publish.isPending;

  const dirty =
    !!draft &&
    !!published &&
    (draft.title !== published.title ||
      draft.body !== published.body ||
      !sameStatements(draft.acknowledgements, published.acknowledgements));

  const allPreviewChecked = statementCount > 0 && previewOn.length === statementCount && previewOn.every(Boolean);

  return (
    <>
      <Header
        title="Agreements"
        description="Edit the text and the statements drivers tick in the app. Publishing a new version asks them to accept it again."
      />
      <PageContent>
        {agreements.isError && (
          <Card className="mb-6">
            <CardContent className="py-8 text-sm text-danger">
              {(agreements.error as Error).message || 'Could not load agreements.'}
            </CardContent>
          </Card>
        )}

        <div className="grid items-start gap-6 xl:grid-cols-[260px_minmax(0,1fr)]">
          <div className="space-y-2">
            <p className="px-1 text-xs font-medium uppercase tracking-wide text-muted">Published</p>
            {agreements.isLoading &&
              AGREEMENT_KEYS.map((key) => (
                <div key={key} className="h-[72px] animate-pulse rounded-xl border border-border bg-elevated" />
              ))}
            {!agreements.isLoading &&
              AGREEMENT_KEYS.map((key) => {
                const doc = documents.find((item) => item.key === key);
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
                      {doc ? `Version ${doc.version}` : 'Not published'}
                      {doc ? ` · ${doc.acknowledgements.length} statement${doc.acknowledgements.length === 1 ? '' : 's'}` : ''}
                    </span>
                  </button>
                );
              })}
          </div>

          <div className="grid items-start gap-6 xl:grid-cols-[minmax(0,1fr)_320px]">
            <Card>
              <CardContent className="space-y-5 p-5">
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div>
                    <h2 className="text-lg text-primary">{KEY_LABELS[activeKey]}</h2>
                    <p className="mt-1 text-sm text-secondary">
                      {published
                        ? `Version ${published.version} is live. This editor publishes version ${draft?.version || '—'}.`
                        : 'This agreement has not been published yet.'}
                    </p>
                  </div>
                  <div className="flex items-center gap-2">
                    {dirty && <Badge variant="warning">Unsaved edits</Badge>}
                    {published && <Badge variant="success">Live v{published.version}</Badge>}
                  </div>
                </div>

                {!draft ? (
                  <p className="text-sm text-secondary">Loading agreement…</p>
                ) : (
                  <>
                    <div className="grid gap-4 sm:grid-cols-[minmax(0,1fr)_120px]">
                      <label className="block space-y-1.5">
                        <span className="text-xs font-medium text-secondary">Title</span>
                        <Input
                          className={fieldClass}
                          value={draft.title}
                          placeholder="Driver Agreement"
                          onChange={(e) => updateDraft({ title: e.target.value })}
                        />
                      </label>
                      <label className="block space-y-1.5">
                        <span className="text-xs font-medium text-secondary">New version</span>
                        <Input
                          className={fieldClass}
                          value={draft.version}
                          onChange={(e) => updateDraft({ version: e.target.value })}
                        />
                      </label>
                    </div>

                    <label className="block space-y-1.5">
                      <span className="text-xs font-medium text-secondary">Agreement text</span>
                      <Textarea
                        rows={10}
                        className={cn(fieldClass, 'min-h-[180px] resize-y')}
                        placeholder="The agreement drivers will read"
                        value={draft.body}
                        onChange={(e) => updateDraft({ body: e.target.value })}
                      />
                    </label>

                    <div className="space-y-3">
                      <div className="flex items-end justify-between gap-3">
                        <div>
                          <p className="text-xs font-medium text-secondary">Statements to tick</p>
                          <p className="mt-1 text-xs text-muted">
                            Each line becomes a checkbox. Drivers must tick all of them.
                          </p>
                        </div>
                        <Button
                          type="button"
                          variant="outline"
                          size="sm"
                          onClick={() => updateDraft({ acknowledgements: [...draft.acknowledgements, ''] })}
                        >
                          <Plus className="h-3.5 w-3.5" />
                          Add
                        </Button>
                      </div>

                      {draft.acknowledgements.map((statement, index) => (
                        <div key={`${activeKey}-${index}`} className="rounded-lg border border-border bg-base p-3">
                          <div className="mb-2 flex items-center justify-between gap-2">
                            <span className="text-xs font-medium text-secondary">Statement {index + 1}</span>
                            <div className="flex items-center">
                              <Button
                                type="button"
                                variant="ghost"
                                size="icon"
                                aria-label="Move statement up"
                                disabled={index === 0}
                                onClick={() => moveStatement(index, -1)}
                              >
                                <ChevronUp className="h-4 w-4" />
                              </Button>
                              <Button
                                type="button"
                                variant="ghost"
                                size="icon"
                                aria-label="Move statement down"
                                disabled={index === draft.acknowledgements.length - 1}
                                onClick={() => moveStatement(index, 1)}
                              >
                                <ChevronDown className="h-4 w-4" />
                              </Button>
                              <Button
                                type="button"
                                variant="ghost"
                                size="icon"
                                aria-label="Remove statement"
                                disabled={draft.acknowledgements.length < 2}
                                onClick={() => removeStatement(index)}
                              >
                                <Trash2 className="h-4 w-4" />
                              </Button>
                            </div>
                          </div>
                          <Textarea
                            rows={2}
                            className={cn(fieldClass, 'min-h-[64px] resize-y')}
                            placeholder="I have read and accept this agreement."
                            value={statement}
                            onChange={(e) => updateStatement(index, e.target.value)}
                          />
                        </div>
                      ))}
                    </div>

                    <div className="flex items-center justify-end gap-3 border-t border-border pt-4">
                      {published && (
                        <Button
                          type="button"
                          variant="ghost"
                          onClick={() => updateDraft(draftFrom(published, activeKey))}
                        >
                          Reset
                        </Button>
                      )}
                      <Button disabled={!canPublish} onClick={() => publish.mutate()}>
                        {publish.isPending ? 'Publishing…' : `Publish version ${draft.version || ''}`}
                      </Button>
                    </div>
                  </>
                )}
              </CardContent>
            </Card>

            <div className="xl:sticky xl:top-4">
              <p className="mb-2 px-1 text-xs font-medium uppercase tracking-wide text-muted">Driver app preview</p>
              <div className="rounded-[28px] border border-border-strong bg-base p-3 shadow-md">
                <div className="mb-3 flex items-center justify-center">
                  <span className="h-1.5 w-16 rounded-full bg-border-strong" />
                </div>
                <div className="rounded-2xl border border-border bg-elevated p-4">
                  <h3 className="text-base font-semibold text-primary">{draft?.title || 'Untitled agreement'}</h3>
                  <p className="mt-3 whitespace-pre-wrap text-sm leading-relaxed text-secondary">
                    {draft?.body.trim() || 'Agreement text appears here.'}
                  </p>
                  <div className="mt-4 space-y-1">
                    {(draft?.acknowledgements ?? []).map((statement, index) => {
                      const on = previewOn[index] === true;
                      const label = statement.trim() || 'Statement text';
                      return (
                        <button
                          key={`${activeKey}-preview-${index}`}
                          type="button"
                          onClick={() =>
                            setPreviewOn((current) => current.map((value, itemIndex) => (itemIndex === index ? !value : value)))
                          }
                          className="flex w-full items-start gap-3 rounded-lg px-1 py-2 text-left hover:bg-surface"
                        >
                          <span
                            className={cn(
                              'mt-0.5 flex h-4 w-4 shrink-0 items-center justify-center rounded-[4px] border',
                              on ? 'border-accent bg-accent text-accent-foreground' : 'border-border-strong bg-base',
                            )}
                          >
                            {on && <Check className="h-3 w-3" />}
                          </span>
                          <span className={cn('text-sm leading-snug', statement.trim() ? 'text-primary' : 'text-muted')}>
                            {label}
                          </span>
                        </button>
                      );
                    })}
                  </div>
                  <button
                    type="button"
                    disabled={!allPreviewChecked}
                    className="mt-4 h-10 w-full rounded-md bg-accent text-sm font-medium text-accent-foreground disabled:opacity-40"
                  >
                    Agree & Submit
                  </button>
                </div>
              </div>
              <p className="mt-2 px-1 text-xs text-muted">Tick the preview to see when the provider can submit. This does not publish.</p>
            </div>
          </div>
        </div>
      </PageContent>
    </>
  );
}
