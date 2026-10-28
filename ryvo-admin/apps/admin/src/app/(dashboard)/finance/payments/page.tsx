'use client';

import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { MoreHorizontal, Undo2 } from 'lucide-react';
import { Header } from '@/components/layout/header';
import { PageContent } from '@/components/layout/page-content';
import { PageToolbar } from '@/components/layout/page-toolbar';
import { DataTable, type Column } from '@/components/data-table';
import { StatusBadge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { Toast, useToast } from '@/components/ui/toast';
import { ServerExportButton } from '@/components/ui/server-export-button';
import { apiFetch, apiMutate, buildQuery } from '@/lib/api';
import { formatCurrency, formatDate } from '@/lib/utils';

interface Payment {
  id: string;
  jobId?: string;
  amount: number;
  status: string;
  method: string;
  paidAt?: string;
  createdAt: string;
  job?: { id: string; jobNumber: string };
}

export default function PaymentsPage() {
  const [page, setPage] = useState(1);
  const [statusFilter, setStatusFilter] = useState('all');
  const queryClient = useQueryClient();
  const { toast, show } = useToast();

  const { data, isLoading, error } = useQuery({
    queryKey: ['finance-payments', page, statusFilter],
    queryFn: async () => {
      const res = await apiFetch<Payment[]>(
        `/admin/finance/payments${buildQuery({
          page,
          limit: 20,
          status: statusFilter === 'all' ? undefined : statusFilter,
        })}`,
      );
      return { items: res.data ?? [], meta: res.meta };
    },
  });

  const refundMutation = useMutation({
    mutationFn: (jobId: string) =>
      apiMutate(`/admin/payments/job/${jobId}/refund`, 'POST', {}),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['finance-payments'] });
      show('Refund processed');
    },
    onError: (err: Error) => show(err.message, 'error'),
  });

  const columns: Column<Payment>[] = [
    {
      key: 'job',
      header: 'Job',
      render: (r) => (
        <span className="font-mono text-[13px] text-primary">{r.job?.jobNumber ?? '—'}</span>
      ),
      searchable: (r) => r.job?.jobNumber ?? '',
      exportValue: (r) => r.job?.jobNumber ?? '',
    },
    {
      key: 'amount',
      header: 'Amount',
      render: (r) => (
        <span className="font-mono text-[13px] font-medium text-primary">
          {formatCurrency(Number(r.amount))}
        </span>
      ),
      exportValue: (r) => Number(r.amount),
    },
    {
      key: 'method',
      header: 'Method',
      render: (r) => <span className="capitalize text-secondary">{r.method}</span>,
      exportValue: (r) => r.method,
    },
    {
      key: 'status',
      header: 'Status',
      render: (r) => <StatusBadge status={r.status} />,
      exportValue: (r) => r.status,
    },
    {
      key: 'paid',
      header: 'Paid At',
      render: (r) => (
        <span className="font-mono text-[13px] text-muted">
          {r.paidAt ? formatDate(r.paidAt) : '—'}
        </span>
      ),
      exportValue: (r) => (r.paidAt ? formatDate(r.paidAt) : ''),
    },
    {
      key: 'actions',
      header: '',
      sortable: false,
      render: (r) => {
        const jobId = r.job?.id ?? r.jobId;
        const canRefund = r.status === 'paid' && !!jobId;
        return (
          <div className="flex justify-end" onClick={(e) => e.stopPropagation()}>
            <DropdownMenu>
              <DropdownMenuTrigger asChild>
                <Button
                  variant="ghost"
                  size="icon"
                  className="h-8 w-8"
                  aria-label="Payment actions"
                >
                  <MoreHorizontal className="h-4 w-4" />
                </Button>
              </DropdownMenuTrigger>
              <DropdownMenuContent align="end" className="w-44">
                <DropdownMenuItem
                  disabled={!canRefund || refundMutation.isPending}
                  onClick={() => jobId && refundMutation.mutate(jobId)}
                  className="text-danger focus:text-danger"
                >
                  <Undo2 className="h-4 w-4" />
                  Refund payment
                </DropdownMenuItem>
              </DropdownMenuContent>
            </DropdownMenu>
          </div>
        );
      },
    },
  ];

  return (
    <>
      <Header title="Payments" description="Payment transactions" />
      <PageContent>
        <PageToolbar>
          <ServerExportButton type="payments" />
        </PageToolbar>
        <DataTable
          data={data?.items ?? []}
          columns={columns}
          meta={data?.meta}
          page={page}
          onPageChange={setPage}
          isLoading={isLoading}
          error={error ? 'Failed to load payments' : null}
          searchPlaceholder="Search payments..."
          exportFilename="payments"
          filters={[
            {
              key: 'status',
              label: 'Status',
              value: statusFilter,
              onChange: (v) => {
                setStatusFilter(v);
                setPage(1);
              },
              options: [
                { value: 'all', label: 'All statuses' },
                { value: 'paid', label: 'Paid' },
                { value: 'pending', label: 'Pending' },
                { value: 'failed', label: 'Failed' },
                { value: 'refunded', label: 'Refunded' },
              ],
            },
          ]}
        />
      </PageContent>
      {toast && <Toast message={toast.message} type={toast.type} />}
    </>
  );
}
