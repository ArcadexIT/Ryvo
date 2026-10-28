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
import { Select } from '@/components/ui/select';
import { Dialog } from '@/components/ui/dialog';
import { EmptyState } from '@/components/ui/empty-state';
import { ExportButton } from '@/components/ui/export-button';
import { CardSkeleton } from '@/components/ui/skeleton';
import { Toast, useToast } from '@/components/ui/toast';
import { apiFetch, apiMutate } from '@/lib/api';
import { formatDate } from '@/lib/utils';
import { uploadAdminFile } from '@/lib/upload';

interface Banner {
  id: string;
  title: string;
  imageUrl: string;
  link?: string;
  targetApp?: string;
  isActive: boolean;
  sortOrder: number;
  createdAt?: string;
}

const emptyForm = {
  title: '',
  imageUrl: '',
  link: '',
  targetApp: 'provider',
  sortOrder: '0',
  isActive: true,
};

export default function BannersPage() {
  const queryClient = useQueryClient();
  const { toast, show } = useToast();
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editing, setEditing] = useState<Banner | null>(null);
  const [form, setForm] = useState(emptyForm);

  const { data, isLoading, error } = useQuery({
    queryKey: ['cms-banners'],
    queryFn: async () => {
      const res = await apiFetch<Banner[]>('/admin/cms/banners');
      return res.data ?? [];
    },
  });

  const [uploading, setUploading] = useState(false);

  const handleImageUpload = async (file: File) => {
    setUploading(true);
    try {
      const url = await uploadAdminFile(file, 'cms/banners');
      setForm((f) => ({ ...f, imageUrl: url }));
      show('Image uploaded');
    } catch (err) {
      show(err instanceof Error ? err.message : 'Upload failed', 'error');
    } finally {
      setUploading(false);
    }
  };

  const saveMutation = useMutation({
    mutationFn: () => {
      const body = {
        title: form.title,
        imageUrl: form.imageUrl,
        link: form.link || undefined,
        targetApp: form.targetApp || undefined,
        isActive: form.isActive,
        sortOrder: Number(form.sortOrder),
      };
      if (editing) {
        return apiMutate(`/admin/cms/banners/${editing.id}`, 'PATCH', body);
      }
      return apiMutate('/admin/cms/banners', 'POST', body);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['cms-banners'] });
      setDialogOpen(false);
      setEditing(null);
      setForm(emptyForm);
      show(editing ? 'Banner updated' : 'Banner created');
    },
    onError: (err: Error) => show(err.message, 'error'),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => apiMutate(`/admin/cms/banners/${id}`, 'DELETE'),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['cms-banners'] });
      show('Banner deleted');
    },
    onError: (err: Error) => show(err.message, 'error'),
  });

  const openCreate = () => {
    setEditing(null);
    setForm(emptyForm);
    setDialogOpen(true);
  };

  const openEdit = (banner: Banner) => {
    setEditing(banner);
    setForm({
      title: banner.title,
      imageUrl: banner.imageUrl,
      link: banner.link ?? '',
      targetApp: 'provider',
      sortOrder: String(banner.sortOrder),
      isActive: banner.isActive,
    });
    setDialogOpen(true);
  };

  return (
    <>
      <Header title="Banners" description="Manage in-app promotional banners" />
      <PageContent>
        <PageToolbar>
          <PageToolbarActions>
            <Button onClick={openCreate}>Add Banner</Button>
          </PageToolbarActions>
          {!!data?.length && (
            <ExportButton
              data={data.map((b) => ({
                title: b.title,
                targetApp: b.targetApp ?? 'all',
                isActive: b.isActive ? 'active' : 'inactive',
                sortOrder: b.sortOrder,
                created: b.createdAt ? formatDate(b.createdAt) : '',
              }))}
              filename="banners"
              columns={[
                { key: 'title', header: 'Title' },
                { key: 'targetApp', header: 'Target App' },
                { key: 'isActive', header: 'Status' },
                { key: 'sortOrder', header: 'Sort Order' },
                { key: 'created', header: 'Created' },
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
        {error && <p className="text-sm text-danger">Failed to load banners</p>}

        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {data?.map((banner) => (
            <Card key={banner.id}>
              <CardHeader>
                <div className="flex items-center justify-between">
                  <CardTitle className="text-base">{banner.title}</CardTitle>
                  <Badge variant={banner.isActive ? 'success' : 'secondary'}>
                    {banner.isActive ? 'Active' : 'Inactive'}
                  </Badge>
                </div>
              </CardHeader>
              <CardContent className="space-y-2 text-sm">
                <div className="aspect-video overflow-hidden rounded-md bg-surface">
                  {/* eslint-disable-next-line @next/next/no-img-element */}
                  <img
                    src={banner.imageUrl}
                    alt={banner.title}
                    className="h-full w-full object-cover"
                  />
                </div>
                <p className="text-muted">Target: {banner.targetApp ?? 'all'}</p>
                {banner.link && <p className="truncate text-muted">Link: {banner.link}</p>}
                <div className="flex gap-2 pt-2">
                  <Button size="sm" variant="outline" onClick={() => openEdit(banner)}>
                    Edit
                  </Button>
                  <Button
                    size="sm"
                    variant="destructive"
                    disabled={deleteMutation.isPending}
                    onClick={() => deleteMutation.mutate(banner.id)}
                  >
                    Delete
                  </Button>
                </div>
              </CardContent>
            </Card>
          ))}
        </div>

        {!isLoading && !error && data?.length === 0 && (
          <EmptyState
            title="No banners configured"
            description="Create your first promotional banner."
            actionLabel="Add Banner"
            onAction={openCreate}
          />
        )}
      </PageContent>

      <Dialog
        open={dialogOpen}
        onClose={() => setDialogOpen(false)}
        title={editing ? 'Edit Banner' : 'Add Banner'}
      >
        <div className="space-y-4">
          <Input
            placeholder="Title"
            value={form.title}
            onChange={(e) => setForm((f) => ({ ...f, title: e.target.value }))}
          />
          <div className="space-y-2">
            <Input
              placeholder="Image URL"
              value={form.imageUrl}
              onChange={(e) => setForm((f) => ({ ...f, imageUrl: e.target.value }))}
            />
            <label className="flex cursor-pointer items-center gap-2 text-sm text-accent hover:underline">
              <input
                type="file"
                accept="image/*"
                className="hidden"
                disabled={uploading}
                onChange={(e) => {
                  const file = e.target.files?.[0];
                  if (file) void handleImageUpload(file);
                }}
              />
              {uploading ? 'Uploading...' : 'Or upload image file'}
            </label>
          </div>
          <Input
            placeholder="Link (optional)"
            value={form.link}
            onChange={(e) => setForm((f) => ({ ...f, link: e.target.value }))}
          />
          <Select
            value={form.targetApp}
            onChange={(e) => setForm((f) => ({ ...f, targetApp: e.target.value }))}
          >
            <option value="provider">Driver</option>
          </Select>
          <Input
            type="number"
            placeholder="Sort order"
            value={form.sortOrder}
            onChange={(e) => setForm((f) => ({ ...f, sortOrder: e.target.value }))}
          />
          <Select
            value={form.isActive ? 'true' : 'false'}
            onChange={(e) => setForm((f) => ({ ...f, isActive: e.target.value === 'true' }))}
          >
            <option value="true">Active</option>
            <option value="false">Inactive</option>
          </Select>
          <div className="flex justify-end gap-2">
            <Button variant="ghost" onClick={() => setDialogOpen(false)}>
              Cancel
            </Button>
            <Button
              disabled={!form.title || !form.imageUrl || saveMutation.isPending}
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
