import { Injectable } from '@nestjs/common';
import { Prisma } from '@ryvo/database';
import { PrismaService } from '../prisma/prisma.service';

type AuditQuery = {
  entityType?: string;
  action?: string;
  from?: string;
  to?: string;
  search?: string;
};

@Injectable()
export class AuditService {
  constructor(private prisma: PrismaService) {}

  async log(params: {
    adminId: string;
    action: string;
    entityType: string;
    entityId?: string;
    oldValues?: unknown;
    newValues?: unknown;
    ipAddress?: string;
  }) {
    return this.prisma.auditLog.create({
      data: {
        adminId: params.adminId,
        action: params.action,
        entityType: params.entityType,
        entityId: params.entityId,
        oldValues: params.oldValues as object,
        newValues: params.newValues as object,
        ipAddress: params.ipAddress,
      },
    });
  }

  async findAll(query: AuditQuery & { page: number; limit: number; skip: number }) {
    const where = this.where(query, true);

    const [items, total] = await Promise.all([
      this.prisma.auditLog.findMany({
        where,
        skip: query.skip,
        take: query.limit,
        orderBy: { createdAt: 'desc' },
        include: { admin: { include: { user: { select: { fullName: true, email: true } } } } },
      }),
      this.prisma.auditLog.count({ where }),
    ]);
    return { items, total };
  }

  async summarize(query: AuditQuery) {
    const groups = await this.prisma.auditLog.groupBy({
      by: ['entityType'],
      where: this.where(query, false),
      _count: { _all: true },
    });
    const byEntity: Record<string, number> = {};
    let total = 0;
    for (const group of groups) {
      byEntity[group.entityType] = group._count._all;
      total += group._count._all;
    }
    return { total, byEntity };
  }

  private where(query: AuditQuery, includeFocus: boolean): Prisma.AuditLogWhereInput {
    const where: Prisma.AuditLogWhereInput = {};
    if (includeFocus && query.entityType && query.entityType !== 'all') {
      const types = query.entityType.split(',').map((value) => value.trim()).filter(Boolean);
      where.entityType = types.length > 1 ? { in: types } : types[0];
    }
    if (includeFocus && query.action && query.action !== 'all') {
      where.action = { contains: query.action, mode: 'insensitive' };
    }
    const search = query.search?.trim();
    if (search) {
      where.OR = [
        { action: { contains: search, mode: 'insensitive' } },
        { entityType: { contains: search, mode: 'insensitive' } },
        { entityId: { contains: search, mode: 'insensitive' } },
        { admin: { user: { fullName: { contains: search, mode: 'insensitive' } } } },
      ];
    }
    const from = parseQueryDate(query.from);
    const to = parseQueryDate(query.to);
    if (from || to) where.createdAt = { gte: from, lte: to };
    return where;
  }
}

function parseQueryDate(value?: string) {
  if (!value) return undefined;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? undefined : date;
}
