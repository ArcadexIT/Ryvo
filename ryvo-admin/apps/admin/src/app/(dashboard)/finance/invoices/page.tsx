'use client';

import { useQuery } from '@tanstack/react-query';
import { Header } from '@/components/layout/header';
import { PageContent } from '@/components/layout/page-content';
import { Card, CardContent } from '@/components/ui/card';
import { apiFetch } from '@/lib/api';
import { formatCurrency, formatDate } from '@/lib/utils';

interface Invoice {
  id: string;
  invoiceNumber: string;
  total: number | string;
  email?: string | null;
  sentAt?: string | null;
  issuedAt: string;
  customer?: { user?: { fullName?: string; email?: string; phone?: string } };
  job?: { jobNumber?: string };
}

export default function InvoicesPage() {
  const invoices = useQuery({
    queryKey: ['invoices'],
    queryFn: async () => (await apiFetch<Invoice[]>('/admin/invoices')).data ?? [],
  });

  return (
    <>
      <Header title="Invoices" description="Invoices created when a job is completed." />
      <PageContent>
        <Card>
          <CardContent className="divide-y divide-border p-0">
            {(invoices.data ?? []).length === 0 && <p className="p-6 text-sm text-secondary">No invoices yet.</p>}
            {(invoices.data ?? []).map((invoice) => (
              <div key={invoice.id} className="flex items-center justify-between gap-4 px-4 py-3 text-sm">
                <div>
                  <p className="font-medium text-primary">{invoice.invoiceNumber}</p>
                  <p className="text-secondary">
                    {invoice.customer?.user?.fullName || 'Customer'} · {invoice.job?.jobNumber || 'Job'} ·{' '}
                    {invoice.email || invoice.customer?.user?.email || 'No email'}
                  </p>
                </div>
                <div className="text-right">
                  <p className="font-medium">{formatCurrency(Number(invoice.total))}</p>
                  <p className="text-secondary">{invoice.sentAt ? `Sent ${formatDate(invoice.sentAt)}` : formatDate(invoice.issuedAt)}</p>
                </div>
              </div>
            ))}
          </CardContent>
        </Card>
      </PageContent>
    </>
  );
}
