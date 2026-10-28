'use client';

import { useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Header } from '@/components/layout/header';
import { PageContent } from '@/components/layout/page-content';
import { PageToolbar, PageToolbarActions } from '@/components/layout/page-toolbar';
import { DataTable, type Column } from '@/components/data-table';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Select } from '@/components/ui/select';
import { Dialog } from '@/components/ui/dialog';
import { Toast, useToast } from '@/components/ui/toast';
import { apiFetch, apiMutate } from '@/lib/api';
import { formatCurrency } from '@/lib/utils';

interface ServiceCategory {
  id: string;
  name: string;
}

interface PricingRule {
  id: string;
  baseFare: number;
  perKmRate?: number;
  perMinuteRate?: number;
  minFare?: number;
  surgeMultiplier?: number;
  city?: string;
  serviceCategory?: { name: string; id: string };
}

const emptyForm = {
  serviceCategoryId: '',
  baseFare: '',
  perKmRate: '',
  perMinuteRate: '',
  minFare: '',
  surgeMultiplier: '1',
  city: '',
};

export default function PricingRulesPage() {
  const queryClient = useQueryClient();
  const { toast, show } = useToast();
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editItem, setEditItem] = useState<PricingRule | null>(null);
  const [categoryFilter, setCategoryFilter] = useState('all');
  const [form, setForm] = useState(emptyForm);
  const [editForm, setEditForm] = useState({
    baseFare: '',
    perKmRate: '',
    perMinuteRate: '',
    minFare: '',
    surgeMultiplier: '',
    city: '',
  });

  const { data, isLoading, error } = useQuery({
    queryKey: ['pricing-rules'],
    queryFn: async () => {
      const res = await apiFetch<PricingRule[]>('/admin/pricing/rules');
      return res.data ?? [];
    },
  });

  const { data: categories } = useQuery({
    queryKey: ['pricing-categories'],
    queryFn: async () => {
      const res = await apiFetch<ServiceCategory[]>('/admin/pricing/categories');
      return res.data ?? [];
    },
  });

  const filteredRules = useMemo(() => {
    const rules = data ?? [];
    if (categoryFilter === 'all') return rules;
    return rules.filter((r) => r.serviceCategory?.id === categoryFilter);
  }, [data, categoryFilter]);

  const createMutation = useMutation({
    mutationFn: () =>
      apiMutate('/admin/pricing/rules', 'POST', {
        serviceCategoryId: form.serviceCategoryId,
        baseFare: Number(form.baseFare),
        perKmRate: form.perKmRate ? Number(form.perKmRate) : undefined,
        perMinuteRate: form.perMinuteRate ? Number(form.perMinuteRate) : undefined,
        minFare: form.minFare ? Number(form.minFare) : undefined,
        surgeMultiplier: form.surgeMultiplier ? Number(form.surgeMultiplier) : undefined,
        city: form.city || undefined,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pricing-rules'] });
      setDialogOpen(false);
      setForm(emptyForm);
      show('Pricing rule created');
    },
    onError: (err: Error) => show(err.message, 'error'),
  });

  const updateMutation = useMutation({
    mutationFn: () =>
      apiMutate(`/admin/pricing/rules/${editItem!.id}`, 'PATCH', {
        baseFare: Number(editForm.baseFare),
        perKmRate: editForm.perKmRate ? Number(editForm.perKmRate) : undefined,
        perMinuteRate: editForm.perMinuteRate ? Number(editForm.perMinuteRate) : undefined,
        minFare: editForm.minFare ? Number(editForm.minFare) : undefined,
        surgeMultiplier: editForm.surgeMultiplier ? Number(editForm.surgeMultiplier) : undefined,
        city: editForm.city || undefined,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pricing-rules'] });
      setEditItem(null);
      show('Pricing rule updated');
    },
    onError: (err: Error) => show(err.message, 'error'),
  });

  const columns: Column<PricingRule>[] = [
    {
      key: 'service',
      header: 'Service',
      render: (r) => r.serviceCategory?.name ?? '—',
      searchable: (r) => r.serviceCategory?.name ?? '',
      exportValue: (r) => r.serviceCategory?.name ?? '',
    },
    {
      key: 'base',
      header: 'Base Fare',
      render: (r) => formatCurrency(Number(r.baseFare)),
      exportValue: (r) => r.baseFare,
    },
    {
      key: 'perKm',
      header: 'Per KM',
      render: (r) => (r.perKmRate != null ? formatCurrency(Number(r.perKmRate)) : '—'),
      exportValue: (r) => r.perKmRate ?? '',
    },
    {
      key: 'perMin',
      header: 'Per Min',
      render: (r) => (r.perMinuteRate != null ? formatCurrency(Number(r.perMinuteRate)) : '—'),
      exportValue: (r) => r.perMinuteRate ?? '',
    },
    {
      key: 'min',
      header: 'Min Fare',
      render: (r) => (r.minFare != null ? formatCurrency(Number(r.minFare)) : '—'),
      exportValue: (r) => r.minFare ?? '',
    },
    {
      key: 'surge',
      header: 'Surge',
      render: (r) => (r.surgeMultiplier != null ? `${r.surgeMultiplier}x` : '—'),
      exportValue: (r) => r.surgeMultiplier ?? '',
    },
    {
      key: 'city',
      header: 'City',
      render: (r) => r.city ?? 'Default',
      exportValue: (r) => r.city ?? 'Default',
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
              baseFare: String(r.baseFare),
              perKmRate: r.perKmRate != null ? String(r.perKmRate) : '',
              perMinuteRate: r.perMinuteRate != null ? String(r.perMinuteRate) : '',
              minFare: r.minFare != null ? String(r.minFare) : '',
              surgeMultiplier: r.surgeMultiplier != null ? String(r.surgeMultiplier) : '1',
              city: r.city ?? '',
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
      <Header title="Fare rules" description="Base fare, per km, and per minute for each ride type" />
      <PageContent>
        <PageToolbar>
          <PageToolbarActions>
            <Button onClick={() => setDialogOpen(true)}>Add Rule</Button>
          </PageToolbarActions>
        </PageToolbar>
        <DataTable
          data={filteredRules}
          columns={columns}
          page={1}
          onPageChange={() => {}}
          isLoading={isLoading}
          error={error ? 'Failed to load pricing rules' : null}
          searchPlaceholder="Search rules..."
          exportFilename="pricing-rules"
          filters={[
            {
              key: 'category',
              label: 'Service',
              value: categoryFilter,
              onChange: setCategoryFilter,
              options: [
                { value: 'all', label: 'All services' },
                ...(categories ?? []).map((c) => ({ value: c.id, label: c.name })),
              ],
            },
          ]}
        />
      </PageContent>

      <Dialog open={dialogOpen} onClose={() => setDialogOpen(false)} title="Create Pricing Rule">
        <div className="space-y-4">
          <Select
            value={form.serviceCategoryId}
            onChange={(e) => setForm((f) => ({ ...f, serviceCategoryId: e.target.value }))}
          >
            <option value="">Select service category</option>
            {categories?.map((cat) => (
              <option key={cat.id} value={cat.id}>
                {cat.name}
              </option>
            ))}
          </Select>
          <Input
            type="number"
            step="0.01"
            placeholder="Base fare"
            value={form.baseFare}
            onChange={(e) => setForm((f) => ({ ...f, baseFare: e.target.value }))}
          />
          <Input
            type="number"
            step="0.01"
            placeholder="Per KM rate"
            value={form.perKmRate}
            onChange={(e) => setForm((f) => ({ ...f, perKmRate: e.target.value }))}
          />
          <Input
            type="number"
            step="0.01"
            placeholder="Per minute rate"
            value={form.perMinuteRate}
            onChange={(e) => setForm((f) => ({ ...f, perMinuteRate: e.target.value }))}
          />
          <Input
            type="number"
            step="0.01"
            placeholder="Min fare"
            value={form.minFare}
            onChange={(e) => setForm((f) => ({ ...f, minFare: e.target.value }))}
          />
          <Input
            type="number"
            step="0.01"
            placeholder="Surge multiplier"
            value={form.surgeMultiplier}
            onChange={(e) => setForm((f) => ({ ...f, surgeMultiplier: e.target.value }))}
          />
          <Input
            placeholder="City (optional)"
            value={form.city}
            onChange={(e) => setForm((f) => ({ ...f, city: e.target.value }))}
          />
          <div className="flex justify-end gap-2">
            <Button variant="ghost" onClick={() => setDialogOpen(false)}>
              Cancel
            </Button>
            <Button
              disabled={!form.serviceCategoryId || !form.baseFare || createMutation.isPending}
              onClick={() => createMutation.mutate()}
            >
              Create
            </Button>
          </div>
        </div>
      </Dialog>

      <Dialog open={!!editItem} onClose={() => setEditItem(null)} title="Edit Pricing Rule">
        <div className="space-y-4">
          <Input type="number" step="0.01" placeholder="Base fare" value={editForm.baseFare} onChange={(e) => setEditForm((f) => ({ ...f, baseFare: e.target.value }))} />
          <Input type="number" step="0.01" placeholder="Per KM" value={editForm.perKmRate} onChange={(e) => setEditForm((f) => ({ ...f, perKmRate: e.target.value }))} />
          <Input type="number" step="0.01" placeholder="Per minute" value={editForm.perMinuteRate} onChange={(e) => setEditForm((f) => ({ ...f, perMinuteRate: e.target.value }))} />
          <Input type="number" step="0.01" placeholder="Min fare" value={editForm.minFare} onChange={(e) => setEditForm((f) => ({ ...f, minFare: e.target.value }))} />
          <Input type="number" step="0.01" placeholder="Surge" value={editForm.surgeMultiplier} onChange={(e) => setEditForm((f) => ({ ...f, surgeMultiplier: e.target.value }))} />
          <Input placeholder="City" value={editForm.city} onChange={(e) => setEditForm((f) => ({ ...f, city: e.target.value }))} />
          <div className="flex justify-end gap-2">
            <Button variant="ghost" onClick={() => setEditItem(null)}>Cancel</Button>
            <Button disabled={!editForm.baseFare || updateMutation.isPending} onClick={() => updateMutation.mutate()}>Save</Button>
          </div>
        </div>
      </Dialog>

      {toast && <Toast message={toast.message} type={toast.type} />}
    </>
  );
}
