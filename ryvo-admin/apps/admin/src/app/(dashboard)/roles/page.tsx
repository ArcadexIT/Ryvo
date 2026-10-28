'use client';

import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Header } from '@/components/layout/header';
import { PageContent } from '@/components/layout/page-content';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Toast, useToast } from '@/components/ui/toast';
import { apiFetch, apiMutate } from '@/lib/api';
import { cn } from '@/lib/utils';

interface Permission {
  key: string;
  label: string;
}

interface RoleConfig {
  key: string;
  label: string;
  permissions: string[];
}

export default function RolesPage() {
  const queryClient = useQueryClient();
  const { toast, show } = useToast();
  const [selectedRole, setSelectedRole] = useState<string | null>(null);
  const [draftPerms, setDraftPerms] = useState<string[]>([]);

  const { data: permissions } = useQuery({
    queryKey: ['admin-permissions'],
    queryFn: async () => {
      const res = await apiFetch<Permission[]>('/admin/permissions');
      return res.data ?? [];
    },
  });

  const { data: roles, isLoading } = useQuery({
    queryKey: ['admin-roles'],
    queryFn: async () => {
      const res = await apiFetch<RoleConfig[]>('/admin/roles');
      return res.data ?? [];
    },
  });

  const saveMutation = useMutation({
    mutationFn: () =>
      apiMutate(`/admin/roles/${selectedRole}`, 'PATCH', { permissions: draftPerms }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin-roles'] });
      show('Role permissions updated');
    },
    onError: (err: Error) => show(err.message, 'error'),
  });

  const selectRole = (role: RoleConfig) => {
    if (role.key === 'super_admin') return;
    setSelectedRole(role.key);
    setDraftPerms(role.permissions);
  };

  const togglePerm = (key: string) => {
    setDraftPerms((prev) =>
      prev.includes(key) ? prev.filter((p) => p !== key) : [...prev, key],
    );
  };

  return (
    <>
      <Header title="Access" description="Configure admin role access by module" />
      <PageContent>
        {isLoading && <p className="text-sm text-muted">Loading roles...</p>}

        <div className="grid gap-6 lg:grid-cols-3">
          <div className="space-y-3">
            <h2 className="text-sm font-semibold text-secondary">Roles</h2>
            {(roles ?? []).map((role) => (
              <Card
                key={role.key}
                className={cn(
                  'cursor-pointer transition-colors hover:border-accent/50',
                  selectedRole === role.key && 'border-accent',
                  role.key === 'super_admin' && 'opacity-60',
                )}
                onClick={() => selectRole(role)}
              >
                <CardContent className="py-4">
                  <p className="font-medium capitalize text-primary">{role.label}</p>
                  <p className="text-xs text-muted">{role.permissions.length} modules</p>
                  {role.key === 'super_admin' && (
                    <Badge variant="default" className="mt-2">Full access</Badge>
                  )}
                </CardContent>
              </Card>
            ))}
          </div>

          <div className="lg:col-span-2">
            {selectedRole ? (
              <Card>
                <CardHeader className="flex flex-row items-center justify-between">
                  <CardTitle className="capitalize">{selectedRole.replace(/_/g, ' ')}</CardTitle>
                  <Button
                    size="sm"
                    disabled={saveMutation.isPending}
                    onClick={() => saveMutation.mutate()}
                  >
                    Save Permissions
                  </Button>
                </CardHeader>
                <CardContent>
                  <div className="grid gap-2 sm:grid-cols-2">
                    {(permissions ?? []).map((perm) => (
                      <label
                        key={perm.key}
                        className="flex cursor-pointer items-center gap-2 rounded-lg border border-border px-3 py-2 text-sm hover:bg-surface"
                      >
                        <input
                          type="checkbox"
                          checked={draftPerms.includes(perm.key)}
                          onChange={() => togglePerm(perm.key)}
                        />
                        {perm.label}
                      </label>
                    ))}
                  </div>
                </CardContent>
              </Card>
            ) : (
              <Card>
                <CardContent className="py-12 text-center text-secondary">
                  Select a role to edit its module permissions.
                </CardContent>
              </Card>
            )}
          </div>
        </div>
      </PageContent>
      {toast && <Toast message={toast.message} type={toast.type} />}
    </>
  );
}
