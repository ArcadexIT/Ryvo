'use client';

import { useCallback, useMemo, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Download, Printer } from 'lucide-react';
import { Header } from '@/components/layout/header';
import { PageContent } from '@/components/layout/page-content';
import { DataTable, type Column } from '@/components/data-table';
import { Button } from '@/components/ui/button';
import { Modal } from '@/components/ui/modal';
import { apiFetch } from '@/lib/api';
import {
  customerEmail,
  customerName,
  downloadInvoice,
  downloadInvoiceList,
  printInvoice,
  printInvoiceList,
  type InvoiceRecord as Invoice,
} from '@/lib/invoice-document';
import { cn, formatCurrency, formatDate } from '@/lib/utils';

type StatusFilter = 'all' | 'sent' | 'unsent';
type PeriodFilter = 'all' | 'today' | '7d' | '30d';

function withinPeriod(issuedAt: string, period: PeriodFilter) {
  if (period === 'all') return true;
  const issued = new Date(issuedAt).getTime();
  const start = new Date();
  start.setHours(0, 0, 0, 0);
  if (period === 'today') return issued >= start.getTime();
  const days = period === '7d' ? 7 : 30;
  return issued >= start.getTime() - (days - 1) * 86_400_000;
}

export default function InvoicesPage() {
  const [search, setSearch] = useState('');
  const [status, setStatus] = useState<StatusFilter>('all');
  const [period, setPeriod] = useState<PeriodFilter>('all');
  const [selected, setSelected] = useState<Invoice | null>(null);
  const onSearchChange = useCallback((value: string) => setSearch(value), []);

  const invoices = useQuery({
    queryKey: ['invoices'],
    queryFn: async () => (await apiFetch<Invoice[]>('/admin/invoices')).data ?? [],
  });

  const rows = invoices.data ?? [];
  const filtered = useMemo(() => {
    const query = search.trim().toLowerCase();
    return rows.filter((invoice) => {
      if (status === 'sent' && !invoice.sentAt) return false;
      if (status === 'unsent' && invoice.sentAt) return false;
      if (!withinPeriod(invoice.issuedAt, period)) return false;
      if (!query) return true;
      return [invoice.invoiceNumber, customerName(invoice), customerEmail(invoice), invoice.customer?.user?.phone, invoice.job?.jobNumber, invoice.job?.serviceCategory?.name]
        .filter(Boolean)
        .some((value) => value!.toLowerCase().includes(query));
    });
  }, [rows, search, status, period]);

  const sent = rows.filter((invoice) => invoice.sentAt).length;
  const total = rows.reduce((sum, invoice) => sum + Number(invoice.total), 0);

  const columns: Column<Invoice>[] = [
    {
      key: 'number',
      header: 'Invoice',
      sortable: true,
      sortValue: (row) => row.invoiceNumber,
      exportValue: (row) => row.invoiceNumber,
      render: (row) => <span className="font-medium text-primary">{row.invoiceNumber}</span>,
    },
    {
      key: 'customer',
      header: 'Customer',
      sortable: true,
      sortValue: (row) => customerName(row),
      exportValue: (row) => customerName(row),
      render: (row) => (
        <span>
          <span className="block text-primary">{customerName(row)}</span>
          <span className="block text-xs text-muted">{customerEmail(row) || row.customer?.user?.phone || 'No contact'}</span>
        </span>
      ),
    },
    {
      key: 'trip',
      header: 'Trip',
      sortable: true,
      sortValue: (row) => row.job?.jobNumber ?? '',
      exportValue: (row) => row.job?.jobNumber ?? '',
      render: (row) => <span className="text-muted">{row.job?.jobNumber || '—'}</span>,
    },
    {
      key: 'status',
      header: 'Status',
      sortable: true,
      sortValue: (row) => (row.sentAt ? 1 : 0),
      exportValue: (row) => (row.sentAt ? 'Sent' : 'Not sent'),
      render: (row) => (
        <span className={cn('rounded-full px-2 py-0.5 text-xs font-medium', row.sentAt ? 'bg-success/10 text-success' : 'bg-input text-muted')}>
          {row.sentAt ? 'Sent' : 'Not sent'}
        </span>
      ),
    },
    {
      key: 'issued',
      header: 'Issued',
      sortable: true,
      sortValue: (row) => new Date(row.issuedAt).getTime(),
      exportValue: (row) => formatDate(row.issuedAt),
      render: (row) => <span className="text-muted">{formatDate(row.issuedAt)}</span>,
    },
    {
      key: 'total',
      header: 'Total',
      numeric: true,
      sortable: true,
      sortValue: (row) => Number(row.total),
      exportValue: (row) => Number(row.total),
      render: (row) => <span className="num font-medium text-primary">{formatCurrency(Number(row.total))}</span>,
    },
    {
      key: 'actions',
      header: '',
      sortable: false,
      render: (row) => (
        <span className="flex justify-end gap-1" onClick={(event) => event.stopPropagation()}>
          <Button variant="ghost" size="icon" aria-label={`Print ${row.invoiceNumber}`} onClick={() => printInvoice(row)}>
            <Printer className="size-4" />
          </Button>
          <Button variant="ghost" size="icon" aria-label={`Download ${row.invoiceNumber}`} onClick={() => downloadInvoice(row)}>
            <Download className="size-4" />
          </Button>
        </span>
      ),
    },
  ];

  return (
    <>
      <Header
        title="Invoices"
        description="Search, filter, download, and print completed-trip invoices."
        actions={
          <div className="flex items-center gap-2">
            <Button variant="outline" onClick={() => printInvoiceList(filtered)} disabled={filtered.length === 0}>
              <Printer className="size-4" />
              Print
            </Button>
            <Button variant="outline" onClick={() => downloadInvoiceList(filtered)} disabled={filtered.length === 0}>
              <Download className="size-4" />
              Download
            </Button>
          </div>
        }
      />
      <PageContent>
        <div className="mb-4 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
          <Summary label="Invoices" value={rows.length} wash="stat-wash-emerald" active={status === 'all' && period === 'all'} onClick={() => { setStatus('all'); setPeriod('all'); }} />
          <Summary label="Billed" value={formatCurrency(total)} wash="stat-wash-sky" />
          <Summary label="Sent" value={sent} wash="stat-wash-teal" active={status === 'sent'} onClick={() => setStatus('sent')} />
          <Summary label="Not sent" value={rows.length - sent} wash="stat-wash-amber" active={status === 'unsent'} onClick={() => setStatus('unsent')} />
        </div>
        <DataTable
          data={filtered}
          columns={columns}
          page={1}
          onPageChange={() => undefined}
          isLoading={invoices.isLoading}
          error={invoices.error ? 'Failed to load invoices' : null}
          emptyMessage="No invoices match these filters."
          searchPlaceholder="Search invoice, customer, trip..."
          searchValue={search}
          onSearchChange={onSearchChange}
          exportFilename="ryvo-invoices"
          onRowClick={setSelected}
          filters={[
            {
              key: 'status',
              label: 'Status',
              value: status,
              onChange: (value) => setStatus(value as StatusFilter),
              options: [
                { value: 'all', label: 'All' },
                { value: 'sent', label: 'Sent' },
                { value: 'unsent', label: 'Not sent' },
              ],
            },
            {
              key: 'period',
              label: 'Issued',
              value: period,
              onChange: (value) => setPeriod(value as PeriodFilter),
              options: [
                { value: 'all', label: 'All time' },
                { value: 'today', label: 'Today' },
                { value: '7d', label: 'Last 7 days' },
                { value: '30d', label: 'Last 30 days' },
              ],
            },
          ]}
        />
      </PageContent>
      <Modal open={Boolean(selected)} onClose={() => setSelected(null)} title={selected?.invoiceNumber ?? 'Invoice'} description={selected ? customerName(selected) : undefined} className="max-w-xl">
        {selected ? (
          <div className="space-y-4">
            <dl className="grid grid-cols-2 gap-3 text-sm">
              <Detail label="Total" value={formatCurrency(Number(selected.total))} />
              <Detail label="Status" value={selected.sentAt ? `Sent ${formatDate(selected.sentAt)}` : 'Not sent'} />
              <Detail label="Issued" value={formatDate(selected.issuedAt)} />
              <Detail label="Trip" value={selected.job?.jobNumber || '—'} />
              <Detail label="Service" value={selected.job?.serviceCategory?.name || '—'} />
              <Detail label="Driver" value={selected.job?.provider?.user?.fullName || '—'} />
              <Detail label="Email" value={customerEmail(selected) || '—'} />
              <Detail label="Phone" value={selected.customer?.user?.phone || '—'} />
              <Detail label="Pickup" value={selected.job?.pickupAddress || '—'} />
              <Detail label="Dropoff" value={selected.job?.dropoffAddress || '—'} />
            </dl>
            <div className="flex justify-end gap-2">
              <Button variant="outline" onClick={() => downloadInvoice(selected)}>
                <Download className="size-4" />
                Download
              </Button>
              <Button onClick={() => printInvoice(selected)}>
                <Printer className="size-4" />
                Print
              </Button>
            </div>
          </div>
        ) : null}
      </Modal>
    </>
  );
}

function Summary({
  label,
  value,
  wash,
  active,
  onClick,
}: {
  label: string;
  value: string | number;
  wash: string;
  active?: boolean;
  onClick?: () => void;
}) {
  const className = cn('rounded-[18px] border p-4 text-left', wash, active ? 'border-primary' : 'border-hairline');
  const body = (
    <>
      <p className="text-sm text-muted">{label}</p>
      <p className="num mt-1 text-[26px] font-bold leading-none tracking-tight text-primary">{value}</p>
    </>
  );
  if (!onClick) return <div className={className}>{body}</div>;
  return (
    <button type="button" onClick={onClick} className={className}>
      {body}
    </button>
  );
}

function Detail({ label, value }: { label: string; value: string }) {
  return (
    <div className="min-w-0">
      <dt className="text-xs text-muted">{label}</dt>
      <dd className="mt-0.5 truncate text-primary">{value}</dd>
    </div>
  );
}
