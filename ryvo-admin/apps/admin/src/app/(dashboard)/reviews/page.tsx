'use client';

import { useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import Link from 'next/link';
import { Header } from '@/components/layout/header';
import { PageContent } from '@/components/layout/page-content';
import { DataTable, type Column } from '@/components/data-table';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Dialog } from '@/components/ui/dialog';
import { Toast, useToast } from '@/components/ui/toast';
import { apiFetch, apiMutate, buildQuery } from '@/lib/api';
import { formatDate } from '@/lib/utils';
import { Star } from 'lucide-react';

interface Review {
  id: string;
  score: number;
  comment?: string;
  isHidden: boolean;
  createdAt: string;
  fromUser: { fullName: string; role: string };
  toUser: { fullName: string; role: string };
  job: { id: string; jobNumber: string };
}

export default function ReviewsPage() {
  const [page, setPage] = useState(1);
  const [hiddenFilter, setHiddenFilter] = useState('all');
  const [moderateId, setModerateId] = useState<string | null>(null);
  const queryClient = useQueryClient();
  const { toast, show } = useToast();

  const { data, isLoading, error } = useQuery({
    queryKey: ['admin-reviews', page, hiddenFilter],
    queryFn: async () => {
      const res = await apiFetch<Review[]>(
        `/admin/reviews${buildQuery({
          page,
          limit: 20,
          hiddenOnly: hiddenFilter === 'hidden' ? true : undefined,
        })}`,
      );
      return { items: res.data ?? [], meta: res.meta };
    },
  });

  const exportParams = useMemo(
    () => ({ hiddenOnly: hiddenFilter === 'hidden' ? true : undefined }),
    [hiddenFilter],
  );

  const moderateMutation = useMutation({
    mutationFn: (action: 'hide' | 'unhide' | 'delete') =>
      apiMutate(`/admin/reviews/${moderateId}`, 'PATCH', { action }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin-reviews'] });
      setModerateId(null);
      show('Review updated');
    },
    onError: (err: Error) => show(err.message, 'error'),
  });

  const columns: Column<Review>[] = [
    {
      key: 'job',
      header: 'Job',
      render: (r) => (
        <Link href={`/jobs/${r.job.id}`} className="font-mono text-accent hover:underline">
          {r.job.jobNumber}
        </Link>
      ),
      searchable: (r) => r.job.jobNumber,
    },
    {
      key: 'from',
      header: 'From',
      render: (r) => `${r.fromUser.fullName} (${r.fromUser.role})`,
      searchable: (r) => r.fromUser.fullName,
    },
    {
      key: 'to',
      header: 'To',
      render: (r) => `${r.toUser.fullName} (${r.toUser.role})`,
    },
    {
      key: 'score',
      header: 'Rating',
      render: (r) => (
        <span className="inline-flex items-center gap-0.5">
          <Star className="h-3.5 w-3.5 fill-warning text-warning" />
          {r.score}
        </span>
      ),
    },
    {
      key: 'comment',
      header: 'Comment',
      render: (r) => (
        <span className="line-clamp-2 max-w-xs text-secondary">{r.comment ?? '—'}</span>
      ),
    },
    {
      key: 'status',
      header: 'Status',
      render: (r) => (
        <Badge variant={r.isHidden ? 'secondary' : 'default'}>
          {r.isHidden ? 'Hidden' : 'Visible'}
        </Badge>
      ),
    },
    {
      key: 'date',
      header: 'Date',
      render: (r) => formatDate(r.createdAt),
    },
    {
      key: 'actions',
      header: '',
      render: (r) => (
        <Button size="sm" variant="ghost" onClick={() => setModerateId(r.id)}>
          Moderate
        </Button>
      ),
    },
  ];

  const review = data?.items.find((r) => r.id === moderateId);

  return (
    <>
      <Header title="Reviews" description="Moderate customer and driver ratings" />
      <PageContent>
        <DataTable
          data={data?.items ?? []}
          columns={columns}
          meta={data?.meta}
          page={page}
          onPageChange={setPage}
          isLoading={isLoading}
          error={error ? 'Failed to load reviews' : null}
          searchPlaceholder="Search reviews..."
          serverExport={{ type: 'reviews', params: exportParams }}
          filters={[
            {
              key: 'visibility',
              label: 'Visibility',
              value: hiddenFilter,
              onChange: (v) => {
                setHiddenFilter(v);
                setPage(1);
              },
              options: [
                { value: 'all', label: 'All reviews' },
                { value: 'hidden', label: 'Hidden only' },
              ],
            },
          ]}
        />
      </PageContent>

      <Dialog open={!!moderateId} onClose={() => setModerateId(null)} title="Moderate Review">
        {review && (
          <div className="space-y-4 text-sm">
            <p><strong>Job:</strong> {review.job.jobNumber}</p>
            <p><strong>Score:</strong> {review.score}/5</p>
            <p><strong>Comment:</strong> {review.comment ?? '—'}</p>
            <div className="flex flex-wrap gap-2">
              {!review.isHidden && (
                <Button variant="destructive" size="sm" onClick={() => moderateMutation.mutate('hide')}>
                  Hide
                </Button>
              )}
              {review.isHidden && (
                <Button size="sm" onClick={() => moderateMutation.mutate('unhide')}>
                  Unhide
                </Button>
              )}
              <Button variant="destructive" size="sm" onClick={() => moderateMutation.mutate('delete')}>
                Delete
              </Button>
            </div>
          </div>
        )}
      </Dialog>

      {toast && <Toast message={toast.message} type={toast.type} />}
    </>
  );
}
