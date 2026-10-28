'use client';

import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Header } from '@/components/layout/header';
import { PageContent } from '@/components/layout/page-content';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { DataTable, type Column } from '@/components/data-table';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { Select } from '@/components/ui/select';
import { Toast, useToast } from '@/components/ui/toast';
import { apiFetch, apiMutate, buildQuery } from '@/lib/api';
import { formatDate } from '@/lib/utils';

interface Broadcast {
  id: string;
  title: string;
  body: string;
  audience: string;
  sentCount: number;
  createdAt: string;
}

export default function NotificationsPage() {
  const [page, setPage] = useState(1);
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const audience = 'providers' as const;
  const queryClient = useQueryClient();
  const { toast, show } = useToast();

  const { data, isLoading, error } = useQuery({
    queryKey: ['broadcasts', page],
    queryFn: async () => {
      const res = await apiFetch<Broadcast[]>(
        `/admin/notifications/broadcasts${buildQuery({ page, limit: 20 })}`,
      );
      return { items: res.data ?? [], meta: res.meta };
    },
  });

  const sendMutation = useMutation({
    mutationFn: () =>
      apiMutate('/admin/notifications/broadcast', 'POST', { title, body, audience }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['broadcasts'] });
      setTitle('');
      setBody('');
      show('Broadcast sent');
    },
    onError: (err: Error) => show(err.message, 'error'),
  });

  const columns: Column<Broadcast>[] = [
    { key: 'title', header: 'Title', render: (r) => r.title, searchable: (r) => r.title },
    { key: 'audience', header: 'Audience', render: (r) => r.audience },
    { key: 'sent', header: 'Recipients', render: (r) => r.sentCount },
    { key: 'date', header: 'Sent', render: (r) => formatDate(r.createdAt) },
  ];

  return (
    <>
      <Header title="Broadcasts" description="Send push broadcasts to app users" />
      <PageContent>
        <Card className="mb-6">
          <CardHeader>
            <CardTitle className="text-base">Compose Broadcast</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <Input placeholder="Title" value={title} onChange={(e) => setTitle(e.target.value)} />
            <Textarea placeholder="Message body" value={body} onChange={(e) => setBody(e.target.value)} />
            <Select value={audience} onChange={() => undefined}>
              <option value="providers">Drivers</option>
            </Select>
            <Button
              disabled={!title.trim() || !body.trim() || sendMutation.isPending}
              onClick={() => sendMutation.mutate()}
            >
              Send Broadcast
            </Button>
          </CardContent>
        </Card>

        <h2 className="mb-3 font-display text-lg text-primary">Sent History</h2>
        <DataTable
          data={data?.items ?? []}
          columns={columns}
          meta={data?.meta}
          page={page}
          onPageChange={setPage}
          isLoading={isLoading}
          error={error ? 'Failed to load broadcasts' : null}
          searchPlaceholder="Search broadcasts..."
        />
      </PageContent>
      {toast && <Toast message={toast.message} type={toast.type} />}
    </>
  );
}
