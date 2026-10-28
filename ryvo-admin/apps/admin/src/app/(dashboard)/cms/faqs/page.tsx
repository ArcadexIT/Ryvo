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
import { Textarea } from '@/components/ui/textarea';
import { Dialog } from '@/components/ui/dialog';
import { EmptyState } from '@/components/ui/empty-state';
import { ExportButton } from '@/components/ui/export-button';
import { Skeleton } from '@/components/ui/skeleton';
import { Toast, useToast } from '@/components/ui/toast';
import { apiFetch, apiMutate } from '@/lib/api';

interface Faq {
  id: string;
  question: string;
  answer: string;
  category?: string;
  isActive: boolean;
  sortOrder: number;
}

const emptyForm = {
  question: '',
  answer: '',
  category: '',
  sortOrder: '0',
  isActive: true,
};

export default function FaqsPage() {
  const queryClient = useQueryClient();
  const { toast, show } = useToast();
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editing, setEditing] = useState<Faq | null>(null);
  const [form, setForm] = useState(emptyForm);

  const { data, isLoading, error } = useQuery({
    queryKey: ['cms-faqs'],
    queryFn: async () => {
      const res = await apiFetch<Faq[]>('/admin/cms/faqs');
      return res.data ?? [];
    },
  });

  const saveMutation = useMutation({
    mutationFn: () => {
      const body = {
        question: form.question,
        answer: form.answer,
        category: form.category || undefined,
        isActive: form.isActive,
        sortOrder: Number(form.sortOrder),
      };
      if (editing) {
        return apiMutate(`/admin/cms/faqs/${editing.id}`, 'PATCH', body);
      }
      return apiMutate('/admin/cms/faqs', 'POST', body);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['cms-faqs'] });
      setDialogOpen(false);
      setEditing(null);
      setForm(emptyForm);
      show(editing ? 'FAQ updated' : 'FAQ created');
    },
    onError: (err: Error) => show(err.message, 'error'),
  });

  const deleteMutation = useMutation({
    mutationFn: (id: string) => apiMutate(`/admin/cms/faqs/${id}`, 'DELETE'),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['cms-faqs'] });
      show('FAQ deleted');
    },
    onError: (err: Error) => show(err.message, 'error'),
  });

  const openCreate = () => {
    setEditing(null);
    setForm(emptyForm);
    setDialogOpen(true);
  };

  const openEdit = (faq: Faq) => {
    setEditing(faq);
    setForm({
      question: faq.question,
      answer: faq.answer,
      category: faq.category ?? '',
      sortOrder: String(faq.sortOrder),
      isActive: faq.isActive,
    });
    setDialogOpen(true);
  };

  return (
    <>
      <Header title="FAQs" description="Manage frequently asked questions" />
      <PageContent>
        <PageToolbar>
          <PageToolbarActions>
            <Button onClick={openCreate}>Add FAQ</Button>
          </PageToolbarActions>
          {!!data?.length && (
            <ExportButton
              data={data.map((f) => ({
                question: f.question,
                answer: f.answer,
                category: f.category ?? '',
                isActive: f.isActive ? 'active' : 'inactive',
              }))}
              filename="faqs"
              columns={[
                { key: 'question', header: 'Question' },
                { key: 'answer', header: 'Answer' },
                { key: 'category', header: 'Category' },
                { key: 'isActive', header: 'Status' },
              ]}
            />
          )}
        </PageToolbar>

        {isLoading && (
          <div className="space-y-4">
            {Array.from({ length: 3 }).map((_, i) => (
              <Skeleton key={i} className="h-24 w-full rounded-xl" />
            ))}
          </div>
        )}
        {error && <p className="text-sm text-danger">Failed to load FAQs</p>}

        <div className="space-y-4">
          {data?.map((faq) => (
            <Card key={faq.id}>
              <CardHeader>
                <div className="flex items-start justify-between gap-4">
                  <CardTitle className="text-base">{faq.question}</CardTitle>
                  <div className="flex shrink-0 gap-2">
                    {faq.category && <Badge variant="outline">{faq.category}</Badge>}
                    <Badge variant={faq.isActive ? 'success' : 'secondary'}>
                      {faq.isActive ? 'Active' : 'Inactive'}
                    </Badge>
                  </div>
                </div>
              </CardHeader>
              <CardContent>
                <p className="text-sm text-secondary">{faq.answer}</p>
                <div className="mt-3 flex gap-2">
                  <Button size="sm" variant="outline" onClick={() => openEdit(faq)}>
                    Edit
                  </Button>
                  <Button
                    size="sm"
                    variant="destructive"
                    disabled={deleteMutation.isPending}
                    onClick={() => deleteMutation.mutate(faq.id)}
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
            title="No FAQs configured"
            description="Add frequently asked questions for your users."
            actionLabel="Add FAQ"
            onAction={openCreate}
          />
        )}
      </PageContent>

      <Dialog
        open={dialogOpen}
        onClose={() => setDialogOpen(false)}
        title={editing ? 'Edit FAQ' : 'Add FAQ'}
      >
        <div className="space-y-4">
          <Input
            placeholder="Question"
            value={form.question}
            onChange={(e) => setForm((f) => ({ ...f, question: e.target.value }))}
          />
          <Textarea
            placeholder="Answer"
            value={form.answer}
            onChange={(e) => setForm((f) => ({ ...f, answer: e.target.value }))}
          />
          <Input
            placeholder="Category (optional)"
            value={form.category}
            onChange={(e) => setForm((f) => ({ ...f, category: e.target.value }))}
          />
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
              disabled={!form.question || !form.answer || saveMutation.isPending}
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
