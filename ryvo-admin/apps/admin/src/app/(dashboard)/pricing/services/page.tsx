'use client';

import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Header } from '@/components/layout/header';
import { PageContent } from '@/components/layout/page-content';
import { PageToolbar, PageToolbarActions } from '@/components/layout/page-toolbar';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Dialog } from '@/components/ui/dialog';
import { ConfirmDeleteDialog } from '@/components/ui/confirm-delete-dialog';
import { EmptyState } from '@/components/ui/empty-state';
import { ExportButton } from '@/components/ui/export-button';
import { CardSkeleton } from '@/components/ui/skeleton';
import { Toast, useToast } from '@/components/ui/toast';
import { apiFetch, apiMutate } from '@/lib/api';
import { formatCurrency } from '@/lib/utils';

interface PricingRule {
  id: string;
  baseFare: number | string;
  perKmRate?: number | string;
  perMinuteRate?: number | string;
  minFare?: number | string;
}

interface ServiceCategory {
  id: string;
  name: string;
  slug: string;
  icon?: string | null;
  description?: string | null;
  businessType?: 'taxi' | 'parcel';
  sortOrder: number;
  isActive: boolean;
  pricingRules?: PricingRule[];
}

const emptyForm = {
  name: '',
  slug: '',
  icon: '',
  description: '',
  sortOrder: '0',
  businessType: 'taxi',
  baseFare: '',
  perKmRate: '',
  perMinuteRate: '',
  minFare: '',
};

function money(value: number | string | null | undefined) {
  if (value == null || value === '') return '';
  return String(value);
}

export default function ServicesPage() {
  const queryClient = useQueryClient();
  const { toast, show } = useToast();
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editing, setEditing] = useState<ServiceCategory | null>(null);
  const [deleting, setDeleting] = useState<ServiceCategory | null>(null);
  const [form, setForm] = useState(emptyForm);

  const { data, isLoading, error } = useQuery({
    queryKey: ['pricing-categories'],
    queryFn: async () => {
      const res = await apiFetch<ServiceCategory[]>('/admin/pricing/categories');
      return res.data ?? [];
    },
  });

  const saveMutation = useMutation({
    mutationFn: () => {
      const body = {
        name: form.name.trim(),
        slug: form.slug.trim(),
        icon: form.icon.trim() || undefined,
        description: form.description.trim() || undefined,
        sortOrder: Number(form.sortOrder) || 0,
        businessType: form.businessType,
        baseFare: Number(form.baseFare),
        perKmRate: Number(form.perKmRate) || 0,
        perMinuteRate: Number(form.perMinuteRate) || 0,
        minFare: Number(form.minFare) || 0,
      };
      if (editing) {
        return apiMutate(`/admin/pricing/categories/${editing.id}`, 'PATCH', body);
      }
      return apiMutate('/admin/pricing/categories', 'POST', body);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pricing-categories'] });
      queryClient.invalidateQueries({ queryKey: ['pricing-rules'] });
      setDialogOpen(false);
      setEditing(null);
      setForm(emptyForm);
      show(editing ? 'Ride type updated' : 'Ride type created');
    },
    onError: (err: Error) => show(err.message, 'error'),
  });

  const toggleMutation = useMutation({
    mutationFn: (cat: ServiceCategory) =>
      apiMutate(`/admin/pricing/categories/${cat.id}`, 'PATCH', {
        name: cat.name,
        slug: cat.slug,
        description: cat.description,
        sortOrder: cat.sortOrder,
        isActive: !cat.isActive,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pricing-categories'] });
      show('Ride type updated');
    },
    onError: (err: Error) => show(err.message, 'error'),
  });

  const deleteMutation = useMutation({
    mutationFn: (cat: ServiceCategory) => apiMutate(`/admin/pricing/categories/${cat.id}`, 'DELETE'),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pricing-categories'] });
      queryClient.invalidateQueries({ queryKey: ['pricing-rules'] });
      setDeleting(null);
      show('Ride type deleted');
    },
    onError: (err: Error) => show(err.message, 'error'),
  });

  const openCreate = () => {
    setEditing(null);
    setForm(emptyForm);
    setDialogOpen(true);
  };

  const openEdit = (cat: ServiceCategory) => {
    const fare = cat.pricingRules?.[0];
    setEditing(cat);
    setForm({
      name: cat.name,
      slug: cat.slug,
      icon: cat.icon ?? '',
      description: cat.description ?? '',
      sortOrder: String(cat.sortOrder),
      businessType: cat.businessType ?? 'taxi',
      baseFare: money(fare?.baseFare),
      perKmRate: money(fare?.perKmRate),
      perMinuteRate: money(fare?.perMinuteRate),
      minFare: money(fare?.minFare),
    });
    setDialogOpen(true);
  };

  return (
    <>
      <Header title="Ride and parcel types" description="Add, edit, price, or remove the options shown in the customer app" />
      <PageContent>
        <PageToolbar>
          <PageToolbarActions>
            <Button onClick={openCreate}>Add type</Button>
          </PageToolbarActions>
          {!!data?.length && (
            <ExportButton
              data={data.map((c) => ({
                name: c.name,
                slug: c.slug,
                description: c.description ?? '',
                sortOrder: c.sortOrder,
                isActive: c.isActive ? 'active' : 'inactive',
              }))}
              filename="service-categories"
              columns={[
                { key: 'name', header: 'Name' },
                { key: 'slug', header: 'Slug' },
                { key: 'description', header: 'Description' },
                { key: 'sortOrder', header: 'Sort Order' },
                { key: 'isActive', header: 'Status' },
              ]}
            />
          )}
        </PageToolbar>

        {isLoading && (
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
            {Array.from({ length: 3 }).map((_, i) => (
              <CardSkeleton key={i} />
            ))}
          </div>
        )}
        {error && <p className="text-sm text-danger">Failed to load categories</p>}

        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {data?.map((cat) => {
            const fare = cat.pricingRules?.[0];
            return (
              <Card key={cat.id}>
                <CardHeader>
                  <div className="flex items-center justify-between gap-2">
                    <CardTitle className="text-base">{cat.name}</CardTitle>
                    <Badge variant={cat.isActive ? 'success' : 'secondary'}>
                      {cat.isActive ? 'Active' : 'Inactive'}
                    </Badge>
                  </div>
                </CardHeader>
                <CardContent className="space-y-2 text-sm text-secondary">
                  <p>Slug: {cat.slug}</p>
                  <p>Type: {cat.businessType === 'parcel' ? 'Parcel' : 'Taxi'}</p>
                  {cat.description && <p>{cat.description}</p>}
                  <p>Sort: {cat.sortOrder}</p>
                  {fare && (
                    <p>
                      From {formatCurrency(Number(fare.minFare ?? fare.baseFare))} · {formatCurrency(Number(fare.baseFare))} base
                    </p>
                  )}
                  <div className="flex flex-wrap gap-2 pt-2">
                    <Button size="sm" variant="outline" onClick={() => openEdit(cat)}>
                      Edit
                    </Button>
                    <Button
                      size="sm"
                      variant="outline"
                      disabled={toggleMutation.isPending}
                      onClick={() => toggleMutation.mutate(cat)}
                    >
                      {cat.isActive ? 'Deactivate' : 'Activate'}
                    </Button>
                    <Button size="sm" variant="destructive" onClick={() => setDeleting(cat)}>
                      Delete
                    </Button>
                  </div>
                </CardContent>
              </Card>
            );
          })}
        </div>

        {!isLoading && !error && data?.length === 0 && (
          <EmptyState
            title="No ride types yet"
            description="Add a type to show it in the customer app."
            actionLabel="Add type"
            onAction={openCreate}
          />
        )}
      </PageContent>

      <Dialog
        open={dialogOpen}
        onClose={() => setDialogOpen(false)}
        title={editing ? 'Edit ride type' : 'Add ride type'}
      >
        <div className="space-y-3">
          <Input placeholder="Name" value={form.name} onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))} />
          <Input placeholder="Slug" value={form.slug} onChange={(e) => setForm((f) => ({ ...f, slug: e.target.value }))} />
          <select
            className="h-10 w-full rounded-md border border-border bg-background px-3 text-sm"
            value={form.businessType}
            onChange={(e) => setForm((f) => ({ ...f, businessType: e.target.value }))}
          >
            <option value="taxi">Taxi</option>
            <option value="parcel">Parcel</option>
          </select>
          <Input
            placeholder="Description"
            value={form.description}
            onChange={(e) => setForm((f) => ({ ...f, description: e.target.value }))}
          />
          <Input
            placeholder="Icon (pets, diamond, electric_car)"
            value={form.icon}
            onChange={(e) => setForm((f) => ({ ...f, icon: e.target.value }))}
          />
          <Input
            type="number"
            placeholder="Sort order"
            value={form.sortOrder}
            onChange={(e) => setForm((f) => ({ ...f, sortOrder: e.target.value }))}
          />
          <div className="grid grid-cols-2 gap-2">
            <Input type="number" placeholder="Base fare" value={form.baseFare} onChange={(e) => setForm((f) => ({ ...f, baseFare: e.target.value }))} />
            <Input type="number" placeholder="Minimum fare" value={form.minFare} onChange={(e) => setForm((f) => ({ ...f, minFare: e.target.value }))} />
            <Input type="number" placeholder="Per km" value={form.perKmRate} onChange={(e) => setForm((f) => ({ ...f, perKmRate: e.target.value }))} />
            <Input type="number" placeholder="Per minute" value={form.perMinuteRate} onChange={(e) => setForm((f) => ({ ...f, perMinuteRate: e.target.value }))} />
          </div>
          <div className="flex justify-end gap-2">
            <Button variant="ghost" onClick={() => setDialogOpen(false)}>
              Cancel
            </Button>
            <Button
              disabled={!form.name.trim() || !form.slug.trim() || form.baseFare === '' || saveMutation.isPending}
              onClick={() => saveMutation.mutate()}
            >
              {editing ? 'Update' : 'Create'}
            </Button>
          </div>
        </div>
      </Dialog>

      <ConfirmDeleteDialog
        open={!!deleting}
        title="Delete ride type"
        description={
          deleting
            ? `Delete ${deleting.name}? This cannot be undone. If rides already use it, deactivate it instead.`
            : ''
        }
        loading={deleteMutation.isPending}
        onClose={() => setDeleting(null)}
        onConfirm={() => deleting && deleteMutation.mutate(deleting)}
      />

      {toast && <Toast message={toast.message} type={toast.type} />}
    </>
  );
}
