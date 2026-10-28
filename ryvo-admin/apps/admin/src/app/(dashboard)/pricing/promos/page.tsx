'use client';

import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Header } from '@/components/layout/header';
import { PageContent } from '@/components/layout/page-content';
import { PageToolbar, PageToolbarActions } from '@/components/layout/page-toolbar';
import { DataTable, type Column } from '@/components/data-table';
import { Badge, statusBadgeVariant } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Select } from '@/components/ui/select';
import { Dialog } from '@/components/ui/dialog';
import { Toast, useToast } from '@/components/ui/toast';
import { apiFetch, apiMutate, buildQuery } from '@/lib/api';
import { formatCurrency, formatDate } from '@/lib/utils';

interface PromoCode {
  id: string;
  code: string;
  discountType: string;
  discountValue: number;
  maxUses?: number;
  usedCount: number;
  validFrom: string;
  validTo: string;
  isActive: boolean;
}

const emptyForm = {
  code: '',
  discountType: 'percentage',
  discountValue: '',
  maxUses: '',
  validFrom: '',
  validTo: '',
};

export default function PromosPage() {
  const [page, setPage] = useState(1);
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editItem, setEditItem] = useState<PromoCode | null>(null);
  const [form, setForm] = useState(emptyForm);
  const [editForm, setEditForm] = useState({ discountValue: '', maxUses: '', validTo: '', isActive: true });
  const queryClient = useQueryClient();
  const { toast, show } = useToast();

  const { data, isLoading, error } = useQuery({
    queryKey: ['promo-codes', page],
    queryFn: async () => {
      const res = await apiFetch<PromoCode[]>(
        `/admin/pricing/promo-codes${buildQuery({ page, limit: 20 })}`,
      );
      return { items: res.data ?? [], meta: res.meta };
    },
  });

  const createMutation = useMutation({
    mutationFn: () =>
      apiMutate('/admin/pricing/promo-codes', 'POST', {
        code: form.code,
        discountType: form.discountType,
        discountValue: Number(form.discountValue),
        maxUses: form.maxUses ? Number(form.maxUses) : undefined,
        validFrom: form.validFrom,
        validTo: form.validTo,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['promo-codes'] });
      setDialogOpen(false);
      setForm(emptyForm);
      show('Promo code created');
    },
    onError: (err: Error) => show(err.message, 'error'),
  });

  const updateMutation = useMutation({
    mutationFn: () =>
      apiMutate(`/admin/pricing/promo-codes/${editItem!.id}`, 'PATCH', {
        discountValue: editForm.discountValue ? Number(editForm.discountValue) : undefined,
        maxUses: editForm.maxUses ? Number(editForm.maxUses) : undefined,
        validTo: editForm.validTo || undefined,
        isActive: editForm.isActive,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['promo-codes'] });
      setEditItem(null);
      show('Promo code updated');
    },
    onError: (err: Error) => show(err.message, 'error'),
  });

  const columns: Column<PromoCode>[] = [
    {
      key: 'code',
      header: 'Code',
      render: (r) => <span className="font-mono text-accent">{r.code}</span>,
      searchable: (r) => r.code,
      exportValue: (r) => r.code,
    },
    {
      key: 'discount',
      header: 'Discount',
      render: (r) =>
        r.discountType === 'percentage'
          ? `${r.discountValue}%`
          : formatCurrency(Number(r.discountValue)),
      exportValue: (r) => `${r.discountType}:${r.discountValue}`,
    },
    {
      key: 'uses',
      header: 'Uses',
      render: (r) => `${r.usedCount}${r.maxUses ? ` / ${r.maxUses}` : ''}`,
      exportValue: (r) => r.usedCount,
    },
    {
      key: 'valid',
      header: 'Valid Period',
      render: (r) => `${formatDate(r.validFrom)} – ${formatDate(r.validTo)}`,
      exportValue: (r) => `${formatDate(r.validFrom)} - ${formatDate(r.validTo)}`,
    },
    {
      key: 'status',
      header: 'Status',
      render: (r) => (
        <Badge variant={r.isActive ? statusBadgeVariant('active') : 'secondary'}>
          {r.isActive ? 'Active' : 'Inactive'}
        </Badge>
      ),
      exportValue: (r) => (r.isActive ? 'active' : 'inactive'),
    },
    {
      key: 'actions',
      header: '',
      render: (r) => (
        <Button
          size="sm"
          variant="ghost"
          onClick={() => {
            setEditItem(r);
            setEditForm({
              discountValue: String(r.discountValue),
              maxUses: r.maxUses ? String(r.maxUses) : '',
              validTo: r.validTo.slice(0, 16),
              isActive: r.isActive,
            });
          }}
        >
          Edit
        </Button>
      ),
    },
  ];

  return (
    <>
      <Header title="Promo codes" description="Manage discount codes and promotions" />
      <PageContent>
        <PageToolbar>
          <PageToolbarActions>
            <Button onClick={() => setDialogOpen(true)}>Add Promo</Button>
          </PageToolbarActions>
        </PageToolbar>
        <DataTable
          data={data?.items ?? []}
          columns={columns}
          meta={data?.meta}
          page={page}
          onPageChange={setPage}
          isLoading={isLoading}
          error={error ? 'Failed to load promo codes' : null}
          searchPlaceholder="Search promo codes..."
          serverExport={{ type: 'promos' }}
        />
      </PageContent>

      <Dialog open={dialogOpen} onClose={() => setDialogOpen(false)} title="Create Promo Code">
        <div className="space-y-4">
          <Input
            placeholder="Code"
            value={form.code}
            onChange={(e) => setForm((f) => ({ ...f, code: e.target.value.toUpperCase() }))}
          />
          <Select
            value={form.discountType}
            onChange={(e) => setForm((f) => ({ ...f, discountType: e.target.value }))}
          >
            <option value="percentage">Percentage</option>
            <option value="fixed">Fixed amount</option>
          </Select>
          <Input
            type="number"
            step="0.01"
            placeholder="Discount value"
            value={form.discountValue}
            onChange={(e) => setForm((f) => ({ ...f, discountValue: e.target.value }))}
          />
          <Input
            type="number"
            placeholder="Max uses (optional)"
            value={form.maxUses}
            onChange={(e) => setForm((f) => ({ ...f, maxUses: e.target.value }))}
          />
          <Input
            type="datetime-local"
            value={form.validFrom}
            onChange={(e) => setForm((f) => ({ ...f, validFrom: e.target.value }))}
          />
          <Input
            type="datetime-local"
            value={form.validTo}
            onChange={(e) => setForm((f) => ({ ...f, validTo: e.target.value }))}
          />
          <div className="flex justify-end gap-2">
            <Button variant="ghost" onClick={() => setDialogOpen(false)}>
              Cancel
            </Button>
            <Button
              disabled={
                !form.code ||
                !form.discountValue ||
                !form.validFrom ||
                !form.validTo ||
                createMutation.isPending
              }
              onClick={() => createMutation.mutate()}
            >
              Create
            </Button>
          </div>
        </div>
      </Dialog>

      <Dialog open={!!editItem} onClose={() => setEditItem(null)} title={`Edit ${editItem?.code}`}>
        <div className="space-y-4">
          <Input
            type="number"
            step="0.01"
            placeholder="Discount value"
            value={editForm.discountValue}
            onChange={(e) => setEditForm((f) => ({ ...f, discountValue: e.target.value }))}
          />
          <Input
            type="number"
            placeholder="Max uses"
            value={editForm.maxUses}
            onChange={(e) => setEditForm((f) => ({ ...f, maxUses: e.target.value }))}
          />
          <Input
            type="datetime-local"
            value={editForm.validTo}
            onChange={(e) => setEditForm((f) => ({ ...f, validTo: e.target.value }))}
          />
          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={editForm.isActive}
              onChange={(e) => setEditForm((f) => ({ ...f, isActive: e.target.checked }))}
            />
            Active
          </label>
          <div className="flex justify-end gap-2">
            <Button variant="ghost" onClick={() => setEditItem(null)}>Cancel</Button>
            <Button disabled={updateMutation.isPending} onClick={() => updateMutation.mutate()}>
              Save
            </Button>
          </div>
        </div>
      </Dialog>

      {toast && <Toast message={toast.message} type={toast.type} />}
    </>
  );
}
