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
import { formatDate } from '@/lib/utils';

interface AdminUser {
  id: string;
  adminRole: string;
  createdAt: string;
  user: { fullName: string; phone: string; email?: string; status: string };
}

const ADMIN_ROLES = ['super_admin', 'ops', 'finance', 'support'] as const;

export default function AdminsPage() {
  const [page, setPage] = useState(1);
  const [search, setSearch] = useState('');
  const [dialogOpen, setDialogOpen] = useState(false);
  const [editItem, setEditItem] = useState<AdminUser | null>(null);
  const [editRole, setEditRole] = useState('ops');
  const [editStatus, setEditStatus] = useState('active');
  const [editFullName, setEditFullName] = useState('');
  const [phone, setPhone] = useState('');
  const [fullName, setFullName] = useState('');
  const [password, setPassword] = useState('');
  const [adminRole, setAdminRole] = useState<string>('ops');
  const queryClient = useQueryClient();
  const { toast, show } = useToast();

  const { data, isLoading, error } = useQuery({
    queryKey: ['admin-users', page, search],
    queryFn: async () => {
      const res = await apiFetch<AdminUser[]>(
        `/admin/users${buildQuery({ page, limit: 20, search: search || undefined })}`,
      );
      return { items: res.data ?? [], meta: res.meta };
    },
  });

  const createMutation = useMutation({
    mutationFn: () =>
      apiMutate('/admin/users', 'POST', { phone, fullName, password, adminRole }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin-users'] });
      setDialogOpen(false);
      setPhone('');
      setFullName('');
      setPassword('');
      setAdminRole('ops');
      show('Admin user created');
    },
    onError: (err: Error) => show(err.message, 'error'),
  });

  const updateMutation = useMutation({
    mutationFn: () =>
      apiMutate(`/admin/users/${editItem!.id}`, 'PATCH', {
        adminRole: editRole,
        status: editStatus,
        fullName: editFullName,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin-users'] });
      setEditItem(null);
      show('Admin updated');
    },
    onError: (err: Error) => show(err.message, 'error'),
  });

  const columns: Column<AdminUser>[] = [
    {
      key: 'name',
      header: 'Name',
      render: (r) => r.user.fullName,
      searchable: (r) => r.user.fullName,
      exportValue: (r) => r.user.fullName,
    },
    {
      key: 'phone',
      header: 'Phone',
      render: (r) => <span className="font-mono text-[13px]">{r.user.phone}</span>,
      exportValue: (r) => r.user.phone,
    },
    {
      key: 'role',
      header: 'Role',
      render: (r) => <Badge variant="default">{r.adminRole}</Badge>,
      exportValue: (r) => r.adminRole,
    },
    {
      key: 'status',
      header: 'Status',
      render: (r) => <Badge variant={statusBadgeVariant(r.user.status)}>{r.user.status}</Badge>,
      exportValue: (r) => r.user.status,
    },
    {
      key: 'created',
      header: 'Created',
      render: (r) => formatDate(r.createdAt),
      exportValue: (r) => formatDate(r.createdAt),
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
            setEditRole(r.adminRole);
            setEditStatus(r.user.status);
            setEditFullName(r.user.fullName);
          }}
        >
          Edit
        </Button>
      ),
    },
  ];

  return (
    <>
      <Header title="Team" description="Manage admin accounts and roles" />
      <PageContent>
        <PageToolbar>
          <PageToolbarActions>
            <Button onClick={() => setDialogOpen(true)}>Add Admin</Button>
          </PageToolbarActions>
        </PageToolbar>
        <DataTable
          data={data?.items ?? []}
          columns={columns}
          meta={data?.meta}
          page={page}
          onPageChange={setPage}
          isLoading={isLoading}
          error={error ? 'Failed to load admin users' : null}
          searchPlaceholder="Search admins..."
          searchValue={search}
          onSearchChange={(v) => {
            setSearch(v);
            setPage(1);
          }}
          serverExport={{ type: 'admins', params: { search: search || undefined } }}
        />
      </PageContent>

      <Dialog open={dialogOpen} onClose={() => setDialogOpen(false)} title="Add Admin">
        <div className="space-y-4">
          <Input placeholder="Phone" value={phone} onChange={(e) => setPhone(e.target.value)} />
          <Input placeholder="Full name" value={fullName} onChange={(e) => setFullName(e.target.value)} />
          <Input
            type="password"
            placeholder="Password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
          />
          <Select value={adminRole} onChange={(e) => setAdminRole(e.target.value)}>
            {ADMIN_ROLES.map((role) => (
              <option key={role} value={role}>
                {role.replace('_', ' ')}
              </option>
            ))}
          </Select>
          <div className="flex justify-end gap-2">
            <Button variant="ghost" onClick={() => setDialogOpen(false)}>Cancel</Button>
            <Button
              disabled={!phone || !fullName || !password || createMutation.isPending}
              onClick={() => createMutation.mutate()}
            >
              Create
            </Button>
          </div>
        </div>
      </Dialog>

      <Dialog open={!!editItem} onClose={() => setEditItem(null)} title={`Edit ${editItem?.user.fullName}`}>
        <div className="space-y-4">
          <Input
            placeholder="Full name"
            value={editFullName}
            onChange={(e) => setEditFullName(e.target.value)}
          />
          <Select value={editRole} onChange={(e) => setEditRole(e.target.value)}>
            {ADMIN_ROLES.map((role) => (
              <option key={role} value={role}>{role.replace('_', ' ')}</option>
            ))}
          </Select>
          <Select value={editStatus} onChange={(e) => setEditStatus(e.target.value)}>
            <option value="active">Active</option>
            <option value="suspended">Suspended</option>
          </Select>
          <div className="flex justify-end gap-2">
            <Button variant="ghost" onClick={() => setEditItem(null)}>Cancel</Button>
            <Button disabled={updateMutation.isPending} onClick={() => updateMutation.mutate()}>Save</Button>
          </div>
        </div>
      </Dialog>

      {toast && <Toast message={toast.message} type={toast.type} />}
    </>
  );
}
