import { Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

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

  async findAll(query: {
    page: number;
    limit: number;
    skip: number;
    entityType?: string;
    action?: string;
    from?: string;
    to?: string;
  }) {
    const where: {
      entityType?: string;
      action?: { contains: string };
      createdAt?: { gte?: Date; lte?: Date };
    } = {};
    if (query.entityType && query.entityType !== 'all') {
      where.entityType = query.entityType;
    }
    if (query.action) {
      where.action = { contains: query.action };
    }
    if (query.from || query.to) {
      where.createdAt = {};
      if (query.from) where.createdAt.gte = new Date(query.from);
      if (query.to) where.createdAt.lte = new Date(query.to);
    }

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
}
