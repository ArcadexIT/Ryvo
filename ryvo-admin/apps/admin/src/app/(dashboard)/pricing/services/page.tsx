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
import { EmptyState } from '@/components/ui/empty-state';
import { ExportButton } from '@/components/ui/export-button';
import { CardSkeleton } from '@/components/ui/skeleton';
import { Toast, useToast } from '@/components/ui/toast';
import { apiFetch, apiMutate } from '@/lib/api';

interface ServiceCategory {
  id: string;
  name: string;
  slug: string;
  icon?: string;
  description?: string;
  businessType?: 'taxi' | 'parcel';
  sortOrder: number;
  isActive: boolean;
}

const emptyForm = { name: '', slug: '', description: '', sortOrder: '0', businessType: 'taxi' };

export default function ServicesPage() {
  const queryClient = useQueryClient();
  const { toast, show } = useToast();
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editing, setEditing] = useState<ServiceCategory | null>(null);
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
        name: form.name,
        slug: form.slug,
        description: form.description || undefined,
        sortOrder: Number(form.sortOrder),
        businessType: form.businessType,
      };
      if (editing) {
        return apiMutate(`/admin/pricing/categories/${editing.id}`, 'PATCH', body);
      }
      return apiMutate('/admin/pricing/categories', 'POST', body);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['pricing-categories'] });
      setDialogOpen(false);
      setEditing(null);
      setForm(emptyForm);
      show(editing ? 'Category updated' : 'Category created');
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
      show('Category status updated');
    },
    onError: (err: Error) => show(err.message, 'error'),
  });

  const openCreate = () => {
    setEditing(null);
    setForm(emptyForm);
    setDialogOpen(true);
  };

  const openEdit = (cat: ServiceCategory) => {
    setEditing(cat);
    setForm({
      name: cat.name,
      slug: cat.slug,
      description: cat.description ?? '',
      sortOrder: String(cat.sortOrder),
      businessType: cat.businessType ?? 'taxi',
    });
    setDialogOpen(true);
  };

  return (
    <>
      <Header title="Ride and parcel types" description="Taxi classes and parcel categories used in the customer app" />
      <PageContent>
        <PageToolbar>
          <PageToolbarActions>
            <Button onClick={openCreate}>Add Category</Button>
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
          {data?.map((cat) => (
            <Card key={cat.id}>
              <CardHeader>
                <div className="flex items-center justify-between">
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
                <div className="flex gap-2 pt-2">
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
                </div>
              </CardContent>
            </Card>
          ))}
        </div>

        {!isLoading && !error && data?.length === 0 && (
          <EmptyState
            title="No service categories configured"
            description="Add a category to start configuring pricing rules."
            actionLabel="Add Category"
            onAction={openCreate}
          />
        )}
      </PageContent>

      <Dialog
        open={dialogOpen}
        onClose={() => setDialogOpen(false)}
        title={editing ? 'Edit Category' : 'Add Category'}
      >
        <div className="space-y-4">
          <Input
            placeholder="Name"
            value={form.name}
            onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))}
          />
          <Input
            placeholder="Slug"
            value={form.slug}
            onChange={(e) => setForm((f) => ({ ...f, slug: e.target.value }))}
          />
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
            type="number"
            placeholder="Sort order"
            value={form.sortOrder}
            onChange={(e) => setForm((f) => ({ ...f, sortOrder: e.target.value }))}
          />
          <div className="flex justify-end gap-2">
            <Button variant="ghost" onClick={() => setDialogOpen(false)}>
              Cancel
            </Button>
            <Button
              disabled={!form.name || !form.slug || saveMutation.isPending}
              onClick={() => saveMutation.mutate()}
            >
              {editing ? 'Update' : 'Create'}
            </Button>
          </div>
        </div>
      </Dialog>

      {toast && <Toast message={toast.message} type={toast.type} />}
    </>
  );
}
