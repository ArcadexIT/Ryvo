'use client';

import { useEffect, useMemo, useState } from 'react';
import Link from 'next/link';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Check, ChevronDown, Eye, FileText, Search } from 'lucide-react';
import { Header } from '@/components/layout/header';
import { Badge, statusBadgeVariant } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { EmptyState } from '@/components/ui/empty-state';
import { ExportButton } from '@/components/ui/export-button';
import { Input } from '@/components/ui/input';
import { Modal } from '@/components/ui/modal';
import { Pagination } from '@/components/ui/pagination';
import { SecureAvatar } from '@/components/ui/secure-avatar';
import { SecureFilePreview } from '@/components/ui/secure-file-preview';
import { Skeleton } from '@/components/ui/skeleton';
import { Textarea } from '@/components/ui/textarea';
import { useDebounce } from '@/hooks/use-debounce';
import { useFileAccessUrl } from '@/hooks/use-file-access-url';
import { toast as sonnerToast } from 'sonner';
import { apiFetch, apiMutate, buildQuery } from '@/lib/api';
import { cn, formatDate, formatDocumentType } from '@/lib/utils';

interface KycDocument {
  id: string;
  docType: string;
  fileUrl: string;
  status: string;
  createdAt: string;
  equipmentLabel: string | null;
  serviceCategoryName: string | null;
}

interface KycProviderGroup {
  provider: {
    id: string;
    user: { fullName: string; phone: string; avatarUrl?: string | null };
  };
  pendingCount: number;
  oldestSubmittedAt: string | null;
  documents: KycDocument[];
}

interface KycQueuePayload {
  providers: KycProviderGroup[];
  summary: { providers: number; documents: number };
}

const PAGE_SIZE = 10;

function documentTitle(doc: KycDocument) {
  if (doc.docType === 'equipment_proof') return doc.equipmentLabel || 'Equipment photo';
  return formatDocumentType(doc.docType);
}

function summaryChips(docs: KycDocument[]) {
  const chips: string[] = [];
  const equipment = new Map<string, number>();
  for (const doc of docs) {
    if (doc.docType === 'equipment_proof') {
      const key = doc.serviceCategoryName || 'Equipment';
      equipment.set(key, (equipment.get(key) ?? 0) + 1);
    } else {
      chips.push(formatDocumentType(doc.docType));
    }
  }
  for (const [name, count] of Array.from(equipment.entries())) {
    chips.push(count > 1 ? `${name} · ${count} photos` : `${name} · 1 photo`);
  }
  return chips;
}

function groupDocuments(docs: KycDocument[]) {
  const identity = docs.filter((doc) => doc.docType !== 'equipment_proof');
  const equipment = new Map<string, KycDocument[]>();
  for (const doc of docs) {
    if (doc.docType !== 'equipment_proof') continue;
    const key = doc.serviceCategoryName || 'Equipment';
    const list = equipment.get(key) ?? [];
    list.push(doc);
    equipment.set(key, list);
  }
  return { identity, equipment: Array.from(equipment.entries()) };
}

function DocThumb({ fileUrl, alt }: { fileUrl: string; alt: string }) {
  const isPdf = fileUrl.toLowerCase().includes('.pdf');
  const { data: accessUrl, isLoading } = useFileAccessUrl(isPdf ? null : fileUrl);

  if (isPdf) {
    return (
      <div className="flex h-14 w-14 items-center justify-center rounded-lg border border-border bg-surface text-secondary">
        <FileText className="h-5 w-5" />
      </div>
    );
  }

  if (isLoading || !accessUrl) {
    return <Skeleton className="h-14 w-14 rounded-lg" />;
  }

  return (
    <img
      src={accessUrl}
      alt={alt}
      className="h-14 w-14 rounded-lg border border-border bg-surface object-cover"
    />
  );
}

export default function KycQueuePage() {
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [openIds, setOpenIds] = useState<Set<string>>(new Set());
  const [previewDoc, setPreviewDoc] = useState<KycDocument | null>(null);
  const [rejectDoc, setRejectDoc] = useState<KycDocument | null>(null);
  const [rejectReason, setRejectReason] = useState('');
  const [approveAll, setApproveAll] = useState<KycProviderGroup | null>(null);
  const [activeDocId, setActiveDocId] = useState<string | null>(null);
  const [bulkProviderId, setBulkProviderId] = useState<string | null>(null);
  const debouncedSearch = useDebounce(search, 300);
  const queryClient = useQueryClient();

  useEffect(() => {
    setPage(1);
  }, [debouncedSearch]);

  const { data, isLoading, error, isFetching } = useQuery({
    queryKey: ['providers-kyc', page, debouncedSearch],
    queryFn: async () => {
      const res = await apiFetch<KycQueuePayload>(
        `/admin/providers/kyc/pending${buildQuery({
          page,
          limit: PAGE_SIZE,
          search: debouncedSearch || undefined,
        })}`,
      );
      return {
        providers: res.data?.providers ?? [],
        summary: res.data?.summary ?? { providers: 0, documents: 0 },
        meta: res.meta,
      };
    },
  });

  const reviewMutation = useMutation({
    mutationFn: ({
      docId,
      status,
      reason,
    }: {
      docId: string;
      status: 'approved' | 'rejected';
      reason?: string;
      silent?: boolean;
    }) =>
      apiMutate(`/admin/providers/documents/${docId}/review`, 'PATCH', {
        status,
        ...(reason ? { rejectionReason: reason } : {}),
      }),
    onSuccess: (_result, variables) => {
      queryClient.invalidateQueries({ queryKey: ['providers-kyc'] });
      queryClient.invalidateQueries({ queryKey: ['kyc-pending-count'] });
      queryClient.invalidateQueries({ queryKey: ['providers-stats'] });
      if (!variables.silent) {
        setPreviewDoc(null);
        setRejectDoc(null);
        setRejectReason('');
        sonnerToast.success(variables.status === 'approved' ? 'Document approved' : 'Document rejected');
      }
    },
    onError: (err: Error) => sonnerToast.error(err.message),
  });

  const providers = data?.providers ?? [];
  const summary = data?.summary;

  const exportRows = useMemo(
    () =>
      providers.flatMap((group) =>
        group.documents.map((doc) => ({
          provider: group.provider.user.fullName,
          phone: group.provider.user.phone,
          document: documentTitle(doc),
          category: doc.serviceCategoryName ?? '',
          submitted: formatDate(doc.createdAt),
          status: doc.status,
        })),
      ),
    [providers],
  );

  function toggle(id: string) {
    setOpenIds((current) => {
      const next = new Set(current);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  async function confirmApproveAll() {
    if (!approveAll) return;
    const group = approveAll;
    setApproveAll(null);
    setBulkProviderId(group.provider.id);
    setOpenIds((current) => new Set(current).add(group.provider.id));
    try {
      for (const doc of group.documents) {
        await reviewMutation.mutateAsync({ docId: doc.id, status: 'approved', silent: true });
      }
      sonnerToast.success(
        `Approved ${group.documents.length} document${group.documents.length === 1 ? '' : 's'} for ${group.provider.user.fullName}`,
      );
    } catch (err) {
      sonnerToast.error(err instanceof Error ? err.message : 'Could not approve every document');
    } finally {
      setBulkProviderId(null);
    }
  }

  const allOpen = providers.length > 0 && providers.every((group) => openIds.has(group.provider.id));

  return (
    <>
      <Header
        title="Verification"
        description="Review driving licence, vehicle registration, insurance, and vehicle photos."
      />
      <div className="flex-1 overflow-y-auto p-4 lg:p-6">
        <div className="mb-4 flex flex-wrap items-center justify-between gap-3">
          <div className="relative min-w-[240px] max-w-md flex-1">
            <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted" />
            <Input
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              placeholder="Search by driver name or phone"
              className="pl-9"
            />
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <p className="text-sm text-secondary">
              {isLoading ? (
                'Loading queue'
              ) : summary ? (
                <>
                  <span className="font-medium text-primary">{summary.providers}</span>{' '}
                  {summary.providers === 1 ? 'driver' : 'drivers'}
                  <span className="mx-1.5 text-muted">·</span>
                  <span className="font-medium text-primary">{summary.documents}</span>{' '}
                  {summary.documents === 1 ? 'document' : 'documents'}
                </>
              ) : null}
            </p>
            {providers.length > 0 && (
              <Button
                variant="ghost"
                size="sm"
                onClick={() =>
                  setOpenIds(allOpen ? new Set() : new Set(providers.map((group) => group.provider.id)))
                }
              >
                {allOpen ? 'Collapse all' : 'Expand all'}
              </Button>
            )}
            <ExportButton
              data={exportRows}
              filename="kyc-queue"
              disabled={exportRows.length === 0}
              columns={[
                { key: 'provider', header: 'Driver' },
                { key: 'phone', header: 'Phone' },
                { key: 'document', header: 'Document' },
                { key: 'category', header: 'Category' },
                { key: 'submitted', header: 'Submitted' },
                { key: 'status', header: 'Status' },
              ]}
            />
          </div>
        </div>

        {isLoading ? (
          <div className="space-y-3">
            {Array.from({ length: 4 }).map((_, index) => (
              <Skeleton key={index} className="h-24 w-full rounded-2xl" />
            ))}
          </div>
        ) : error ? (
          <EmptyState
            title="Couldn’t load the KYC queue"
            description="Check your connection and try again."
          />
        ) : providers.length === 0 ? (
          <EmptyState
            title={debouncedSearch ? 'No matching drivers' : 'No pending KYC documents'}
            description={
              debouncedSearch
                ? 'Try another name or phone number.'
                : 'New submissions will show up here, grouped by driver.'
            }
            actionLabel={debouncedSearch ? undefined : 'View Drivers'}
            onAction={debouncedSearch ? undefined : () => (window.location.href = '/providers')}
          />
        ) : (
          <div className={cn('space-y-3', isFetching && 'opacity-70')}>
            {providers.map((group) => {
              const open = openIds.has(group.provider.id);
              const sections = groupDocuments(group.documents);
              const busy = bulkProviderId === group.provider.id;
              return (
                <section
                  key={group.provider.id}
                  className="overflow-hidden rounded-2xl border border-border bg-elevated shadow-sm"
                >
                  <button
                    type="button"
                    className="flex w-full items-start gap-3 px-4 py-4 text-left transition-colors hover:bg-surface/60"
                    aria-expanded={open}
                    onClick={() => toggle(group.provider.id)}
                  >
                    <SecureAvatar
                      name={group.provider.user.fullName}
                      src={group.provider.user.avatarUrl}
                      size="lg"
                    />
                    <div className="min-w-0 flex-1">
                      <div className="flex flex-wrap items-center gap-2">
                        <span className="font-medium text-primary">{group.provider.user.fullName}</span>
                        <Badge variant="warning">
                          {group.pendingCount} {group.pendingCount === 1 ? 'file' : 'files'}
                        </Badge>
                      </div>
                      <p className="mt-0.5 text-sm text-secondary">{group.provider.user.phone}</p>
                      <div className="mt-2 flex flex-wrap gap-1.5">
                        {summaryChips(group.documents).map((chip) => (
                          <span
                            key={chip}
                            className="rounded-full border border-border bg-surface px-2 py-0.5 text-[11px] text-secondary"
                          >
                            {chip}
                          </span>
                        ))}
                      </div>
                    </div>
                    <div className="flex shrink-0 items-center gap-3 pt-1">
                      {group.oldestSubmittedAt && (
                        <span className="hidden text-xs text-muted sm:block">
                          Since {formatDate(group.oldestSubmittedAt)}
                        </span>
                      )}
                      <ChevronDown
                        className={cn('h-4 w-4 text-muted transition-transform', open && 'rotate-180')}
                      />
                    </div>
                  </button>

                  {open && (
                    <div className="space-y-5 border-t border-border px-4 py-4">
                      <div className="flex flex-wrap items-center justify-between gap-2">
                        <Link
                          href={`/providers/${group.provider.id}`}
                          className="text-sm font-medium text-accent hover:underline"
                        >
                          Open provider profile
                        </Link>
                        <Button size="sm" disabled={busy} onClick={() => setApproveAll(group)}>
                          <Check className="h-3.5 w-3.5" />
                          Approve all {group.pendingCount}
                        </Button>
                      </div>

                      {sections.identity.length > 0 && (
                        <DocumentSection
                          title="Identity and vehicle"
                          documents={sections.identity}
                          busy={busy}
                          activeDocId={activeDocId}
                          onPreview={setPreviewDoc}
                          onApprove={(doc) => {
                            setActiveDocId(doc.id);
                            reviewMutation.mutate(
                              { docId: doc.id, status: 'approved' },
                              { onSettled: () => setActiveDocId(null) },
                            );
                          }}
                          onReject={setRejectDoc}
                        />
                      )}

                      {sections.equipment.map(([category, documents]) => (
                        <DocumentSection
                          key={category}
                          title={category}
                          documents={documents}
                          busy={busy}
                          activeDocId={activeDocId}
                          onPreview={setPreviewDoc}
                          onApprove={(doc) => {
                            setActiveDocId(doc.id);
                            reviewMutation.mutate(
                              { docId: doc.id, status: 'approved' },
                              { onSettled: () => setActiveDocId(null) },
                            );
                          }}
                          onReject={setRejectDoc}
                        />
                      ))}
                    </div>
                  )}
                </section>
              );
            })}
          </div>
        )}

        {(data?.meta?.total ?? 0) > 0 && (
          <Pagination
            className="mt-4"
            meta={data?.meta}
            page={page}
            pageSize={PAGE_SIZE}
            onPageChange={setPage}
          />
        )}
      </div>

      <Modal
        open={!!previewDoc}
        onClose={() => setPreviewDoc(null)}
        title={previewDoc ? documentTitle(previewDoc) : 'Document preview'}
        description={previewDoc?.serviceCategoryName ?? undefined}
        className="max-w-2xl"
      >
        {previewDoc?.fileUrl && (
          <div className="space-y-4">
            <SecureFilePreview fileUrl={previewDoc.fileUrl} title={documentTitle(previewDoc)} />
            <div className="flex gap-2">
              <Button
                loading={activeDocId === previewDoc.id}
                onClick={() => {
                  setActiveDocId(previewDoc.id);
                  reviewMutation.mutate(
                    { docId: previewDoc.id, status: 'approved' },
                    { onSettled: () => setActiveDocId(null) },
                  );
                }}
              >
                Approve
              </Button>
              <Button
                variant="destructive"
                onClick={() => {
                  setRejectDoc(previewDoc);
                  setPreviewDoc(null);
                }}
              >
                Reject
              </Button>
            </div>
          </div>
        )}
      </Modal>

      <Modal
        open={!!rejectDoc}
        onClose={() => {
          setRejectDoc(null);
          setRejectReason('');
        }}
        title={rejectDoc ? `Reject ${documentTitle(rejectDoc)}` : 'Reject document'}
        description="The driver will see this reason and can upload a replacement."
      >
        <div className="space-y-4">
          <Textarea
            placeholder="Reason for rejection..."
            value={rejectReason}
            onChange={(e) => setRejectReason(e.target.value)}
            rows={4}
          />
          <div className="flex justify-end gap-2">
            <Button variant="outline" onClick={() => setRejectDoc(null)}>
              Cancel
            </Button>
            <Button
              variant="destructive"
              disabled={!rejectReason.trim()}
              loading={!!rejectDoc && activeDocId === rejectDoc.id}
              onClick={() => {
                if (!rejectDoc) return;
                setActiveDocId(rejectDoc.id);
                reviewMutation.mutate(
                  {
                    docId: rejectDoc.id,
                    status: 'rejected',
                    reason: rejectReason.trim(),
                  },
                  { onSettled: () => setActiveDocId(null) },
                );
              }}
            >
              Confirm reject
            </Button>
          </div>
        </div>
      </Modal>

      <Modal
        open={!!approveAll}
        onClose={() => setApproveAll(null)}
        title={approveAll ? `Approve all files for ${approveAll.provider.user.fullName}?` : 'Approve all'}
        description={
          approveAll
            ? `${approveAll.pendingCount} pending document${approveAll.pendingCount === 1 ? '' : 's'} will be marked approved.`
            : undefined
        }
      >
        <div className="flex justify-end gap-2">
          <Button variant="outline" onClick={() => setApproveAll(null)}>
            Cancel
          </Button>
          <Button onClick={confirmApproveAll}>Approve all</Button>
        </div>
      </Modal>
    </>
  );
}

function DocumentSection({
  title,
  documents,
  busy,
  activeDocId,
  onPreview,
  onApprove,
  onReject,
}: {
  title: string;
  documents: KycDocument[];
  busy: boolean;
  activeDocId: string | null;
  onPreview: (doc: KycDocument) => void;
  onApprove: (doc: KycDocument) => void;
  onReject: (doc: KycDocument) => void;
}) {
  return (
    <div>
      <div className="mb-2 flex items-center justify-between gap-2">
        <h3 className="text-xs font-semibold uppercase tracking-wide text-muted">{title}</h3>
        <span className="text-xs text-secondary">
          {documents.length} {documents.length === 1 ? 'file' : 'files'}
        </span>
      </div>
      <div className="divide-y divide-border overflow-hidden rounded-xl border border-border">
        {documents.map((doc) => (
          <div key={doc.id} className="flex flex-wrap items-center gap-3 bg-base px-3 py-3">
            <button type="button" onClick={() => onPreview(doc)} className="shrink-0" aria-label={`Preview ${documentTitle(doc)}`}>
              <DocThumb fileUrl={doc.fileUrl} alt={documentTitle(doc)} />
            </button>
            <div className="min-w-[180px] flex-1">
              <p className="text-sm font-medium text-primary">{documentTitle(doc)}</p>
              <p className="mt-0.5 text-xs text-secondary">{formatDate(doc.createdAt)}</p>
            </div>
            <Badge variant={statusBadgeVariant(doc.status)}>{doc.status}</Badge>
            <div className="flex gap-2">
              <Button size="sm" variant="ghost" onClick={() => onPreview(doc)}>
                <Eye className="h-3.5 w-3.5" />
                Preview
              </Button>
              <Button
                size="sm"
                variant="outline"
                disabled={busy}
                loading={activeDocId === doc.id}
                onClick={() => onApprove(doc)}
              >
                Approve
              </Button>
              <Button size="sm" variant="destructive" disabled={busy} onClick={() => onReject(doc)}>
                Reject
              </Button>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
