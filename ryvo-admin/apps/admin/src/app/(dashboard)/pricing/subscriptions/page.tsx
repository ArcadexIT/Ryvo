'use client';

import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Header } from '@/components/layout/header';
import { PageContent } from '@/components/layout/page-content';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Dialog } from '@/components/ui/dialog';
import { Toast, useToast } from '@/components/ui/toast';
import { apiFetch, apiMutate } from '@/lib/api';
import { formatCurrency } from '@/lib/utils';

interface Plan {
  id: string;
  name: string;
  period: 'daily' | 'weekly' | 'monthly';
  price: number | string;
  commissionRate: number | string;
  isActive: boolean;
  sortOrder: number;
}

const emptyForm = {
  name: '',
  period: 'daily',
  price: '',
  commissionRate: '0',
  sortOrder: '0',
};

export default function DriverPlansPage() {
  const queryClient = useQueryClient();
  const { toast, show } = useToast();
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editing, setEditing] = useState<Plan | null>(null);
  const [form, setForm] = useState(emptyForm);

  const { data, isLoading } = useQuery({
    queryKey: ['driver-plans'],
    queryFn: async () => {
      const res = await apiFetch<Plan[]>('/admin/subscriptions/plans');
      return res.data ?? [];
    },
  });

  const saveMutation = useMutation({
    mutationFn: () =>
      apiMutate('/admin/subscriptions/plans', 'POST', {
        id: editing?.id,
        name: form.name,
        period: form.period,
        price: Number(form.price),
        commissionRate: Number(form.commissionRate || 0),
        sortOrder: Number(form.sortOrder || 0),
        isActive: editing?.isActive ?? true,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['driver-plans'] });
      setDialogOpen(false);
      setEditing(null);
      setForm(emptyForm);
      show(editing ? 'Plan updated' : 'Plan created');
    },
    onError: (err: Error) => show(err.message, 'error'),
  });

  return (
    <>
      <Header
        title="Driver subscription plans"
        description="Daily, weekly, and monthly plans used when monetization is set to subscription"
      />
      <PageContent>
        <div className="mb-4">
          <Button
            onClick={() => {
              setEditing(null);
              setForm(emptyForm);
              setDialogOpen(true);
            }}
          >
            Add plan
          </Button>
        </div>
        {isLoading ? <p className="text-sm text-secondary">Loading plans…</p> : null}
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
          {data?.map((plan) => (
            <Card key={plan.id}>
              <CardHeader>
                <div className="flex items-center justify-between">
                  <CardTitle className="text-base">{plan.name}</CardTitle>
                  <Badge variant={plan.isActive ? 'success' : 'secondary'}>{plan.period}</Badge>
                </div>
              </CardHeader>
              <CardContent className="space-y-2 text-sm text-secondary">
                <p>{formatCurrency(Number(plan.price))}</p>
                <p>Commission while subscribed: {Number(plan.commissionRate) * 100}%</p>
                <Button
                  size="sm"
                  variant="outline"
                  onClick={() => {
                    setEditing(plan);
                    setForm({
                      name: plan.name,
                      period: plan.period,
                      price: String(plan.price),
                      commissionRate: String(plan.commissionRate),
                      sortOrder: String(plan.sortOrder),
                    });
                    setDialogOpen(true);
                  }}
                >
                  Edit
                </Button>
              </CardContent>
            </Card>
          ))}
        </div>
      </PageContent>
      <Dialog open={dialogOpen} onClose={() => setDialogOpen(false)} title={editing ? 'Edit plan' : 'Add plan'}>
        <div className="space-y-4">
          <Input placeholder="Name" value={form.name} onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))} />
          <select
            className="h-10 w-full rounded-md border border-border bg-background px-3 text-sm"
            value={form.period}
            onChange={(e) => setForm((f) => ({ ...f, period: e.target.value }))}
          >
            <option value="daily">Daily</option>
            <option value="weekly">Weekly</option>
            <option value="monthly">Monthly</option>
          </select>
          <Input placeholder="Price" value={form.price} onChange={(e) => setForm((f) => ({ ...f, price: e.target.value }))} />
          <Input
            placeholder="Commission rate (0 = none)"
            value={form.commissionRate}
            onChange={(e) => setForm((f) => ({ ...f, commissionRate: e.target.value }))}
          />
          <div className="flex justify-end gap-2">
            <Button variant="ghost" onClick={() => setDialogOpen(false)}>
              Cancel
            </Button>
            <Button disabled={!form.name || !form.price || saveMutation.isPending} onClick={() => saveMutation.mutate()}>
              Save
            </Button>
          </div>
        </div>
      </Dialog>
      {toast && <Toast message={toast.message} type={toast.type} />}
    </>
  );
}
