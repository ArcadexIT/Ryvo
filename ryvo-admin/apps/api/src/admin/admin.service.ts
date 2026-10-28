import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { TrackingService } from '../tracking/tracking.service';
import { RedisService } from '../redis/redis.service';
import { parsePagination, paginateMeta } from '../common/utils';
import { PaginationDto } from '../common/dto/pagination.dto';
import { Prisma, AdminRole, DiscountType } from '@ryvo/database';
import * as bcrypt from 'bcrypt';
import {
  ADMIN_MODULES,
  DEFAULT_ROLE_PERMISSIONS,
  resolveAdminPermissions,
  type AdminModule,
} from './admin-permissions';
import { SmsService } from '../sms/sms.service';
import { NotificationsService } from '../notifications/notifications.service';
import { BillingOpsService } from '../ops/billing-ops.service';
import { SettingsService } from '../settings/settings.service';

function calcChangePercent(current: number, previous: number): number {
  if (previous === 0) return current > 0 ? 100 : 0;
  return Math.round(((current - previous) / previous) * 100);
}

@Injectable()
export class AdminService {
  constructor(
    private prisma: PrismaService,
    private audit: AuditService,
    private tracking: TrackingService,
    private redis: RedisService,
    private sms: SmsService,
    private notifications: NotificationsService,
    private billing: BillingOpsService,
    private settings: SettingsService,
  ) {}

  async getDashboardKpis() {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const yesterday = new Date(today);
    yesterday.setDate(yesterday.getDate() - 1);

    const [
      totalJobs,
      activeJobs,
      completedToday,
      completedYesterday,
      totalCustomers,
      newCustomersToday,
      newCustomersYesterday,
      totalProviders,
      newProvidersToday,
      newProvidersYesterday,
      onlineProviders,
      busyProviders,
      revenueToday,
      revenueYesterday,
      openTickets,
      openTicketsYesterday,
      jobsCreatedToday,
      jobsCreatedYesterday,
    ] = await Promise.all([
      this.prisma.job.count(),
      this.prisma.job.count({
        where: { status: { in: ['searching', 'matched', 'provider_en_route', 'arrived', 'in_progress'] } },
      }),
      this.prisma.job.count({ where: { completedAt: { gte: today } } }),
      this.prisma.job.count({
        where: { completedAt: { gte: yesterday, lt: today } },
      }),
      this.prisma.customer.count({ where: { user: { role: 'customer' } } }),
      this.prisma.customer.count({ where: { createdAt: { gte: today }, user: { role: 'customer' } } }),
      this.prisma.customer.count({
        where: { createdAt: { gte: yesterday, lt: today }, user: { role: 'customer' } },
      }),
      this.prisma.provider.count({ where: { user: { role: 'provider' } } }),
      this.prisma.provider.count({ where: { createdAt: { gte: today }, user: { role: 'provider' } } }),
      this.prisma.provider.count({
        where: { createdAt: { gte: yesterday, lt: today }, user: { role: 'provider' } },
      }),
      this.prisma.provider.count({ where: { onlineStatus: 'online', user: { role: 'provider' } } }),
      this.prisma.provider.count({ where: { onlineStatus: 'busy', user: { role: 'provider' } } }),
      this.prisma.payment.aggregate({
        where: { status: 'paid', paidAt: { gte: today } },
        _sum: { amount: true },
      }),
      this.prisma.payment.aggregate({
        where: { status: 'paid', paidAt: { gte: yesterday, lt: today } },
        _sum: { amount: true },
      }),
      this.prisma.supportTicket.count({ where: { status: { in: ['open', 'in_progress'] } } }),
      this.prisma.supportTicket.count({
        where: {
          status: { in: ['open', 'in_progress'] },
          createdAt: { lt: today },
        },
      }),
      this.prisma.job.count({ where: { createdAt: { gte: today } } }),
      this.prisma.job.count({
        where: { createdAt: { gte: yesterday, lt: today } },
      }),
    ]);

    const revenueTodayVal = Number(revenueToday._sum.amount ?? 0);
    const revenueYesterdayVal = Number(revenueYesterday._sum.amount ?? 0);

    return {
      totalJobs,
      activeJobs,
      completedToday,
      totalCustomers,
      totalProviders,
      onlineProviders,
      busyProviders,
      revenueToday: revenueTodayVal,
      openTickets,
      trends: {
        totalJobs: calcChangePercent(jobsCreatedToday, jobsCreatedYesterday),
        activeJobs: 0,
        completedToday: calcChangePercent(completedToday, completedYesterday),
        totalCustomers: calcChangePercent(newCustomersToday, newCustomersYesterday),
        totalProviders: calcChangePercent(newProvidersToday, newProvidersYesterday),
        onlineProviders: 0,
        revenueToday: calcChangePercent(revenueTodayVal, revenueYesterdayVal),
        openTickets: calcChangePercent(openTickets, openTicketsYesterday),
      },
    };
  }

  async getCharts(days = 7) {
    const since = new Date();
    since.setDate(since.getDate() - days);

    const jobs = await this.prisma.job.findMany({
      where: { createdAt: { gte: since } },
      select: { createdAt: true, status: true, finalFare: true, estimatedFare: true },
    });

    const byDay = new Map<string, { jobs: number; revenue: number }>();
    for (const job of jobs) {
      const day = job.createdAt.toISOString().slice(0, 10);
      const entry = byDay.get(day) ?? { jobs: 0, revenue: 0 };
      entry.jobs += 1;
      if (job.status === 'completed') {
        entry.revenue += Number(job.finalFare ?? job.estimatedFare ?? 0);
      }
      byDay.set(day, entry);
    }

    return {
      jobsByDay: Array.from(byDay.entries()).map(([date, data]) => ({ date, ...data })),
      statusBreakdown: jobs.reduce(
        (acc, j) => {
          acc[j.status] = (acc[j.status] ?? 0) + 1;
          return acc;
        },
        {} as Record<string, number>,
      ),
    };
  }

  async getLiveSnapshot() {
    const providers = await this.tracking.getLiveProviders();
    const activeJobs = await this.prisma.job.findMany({
      where: { status: { in: ['matched', 'provider_en_route', 'arrived', 'in_progress', 'searching'] } },
      take: 50,
      include: {
        customer: { include: { user: { select: { fullName: true } } } },
        provider: { include: { user: { select: { fullName: true } } } },
        serviceCategory: { select: { name: true } },
        _count: { select: { offers: true } },
      },
    });
    return { providers, activeJobs };
  }

  async getDashboardActivity(limit = 10) {
    const [auditLogs, recentJobs, recentCustomers, recentPayouts, pendingKyc, pendingWithdrawals] = await Promise.all([
      this.prisma.auditLog.findMany({
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: { admin: { include: { user: { select: { fullName: true } } } } },
      }),
      this.prisma.job.findMany({
        where: { status: { in: ['completed', 'cancelled_by_admin', 'cancelled_by_customer', 'cancelled_by_provider'] } },
        take: 5,
        orderBy: { updatedAt: 'desc' },
        include: {
          provider: { include: { user: { select: { fullName: true } } } },
        },
      }),
      this.prisma.customer.findMany({
        take: 3,
        orderBy: { createdAt: 'desc' },
        include: { user: { select: { fullName: true } } },
      }),
      this.prisma.payout.findMany({
        where: { status: 'paid' },
        take: 3,
        orderBy: { processedAt: 'desc' },
        include: { provider: { include: { user: { select: { fullName: true } } } } },
      }),
      this.prisma.providerDocument.count({ where: { status: 'pending' } }),
      this.prisma.payout.findMany({
        where: { status: 'pending' },
        take: 5,
        orderBy: { createdAt: 'desc' },
        include: { provider: { include: { user: { select: { fullName: true } } } } },
      }),
    ]);

    type ActivityItem = {
      id: string;
      type: 'customer' | 'job' | 'payout' | 'alert' | 'admin';
      message: string;
      timestamp: string;
      href?: string;
    };

    const items: ActivityItem[] = [];

    for (const c of recentCustomers) {
      items.push({
        id: `customer-${c.id}`,
        type: 'customer',
        message: `New customer registered — ${c.user.fullName}`,
        timestamp: c.createdAt.toISOString(),
      });
    }

    for (const j of recentJobs) {
      const providerName = j.provider?.user.fullName ?? 'Unassigned';
      const msg =
        j.status === 'completed'
          ? `Job #${j.jobNumber} completed by ${providerName}`
          : `Job #${j.jobNumber} marked as ${j.status.replace(/_/g, ' ')}`;
      items.push({
        id: `job-${j.id}`,
        type: 'job',
        message: msg,
        timestamp: (j.completedAt ?? j.updatedAt).toISOString(),
      });
    }

    const currency = await this.settings.getPlatformCurrency();
    const money = (amount: number) => `${currency.symbol}${amount.toFixed(currency.decimals)}`;

    for (const p of pendingWithdrawals) {
      items.push({
        id: `withdraw-${p.id}`,
        type: 'alert',
        message: `${p.provider.user.fullName} requested a withdrawal of ${money(Number(p.amount))}`,
        timestamp: p.createdAt.toISOString(),
        href: '/finance/payouts?status=pending',
      });
    }

    for (const p of recentPayouts) {
      items.push({
        id: `payout-${p.id}`,
        type: 'payout',
        message: `Payout of ${money(Number(p.amount))} processed for ${p.provider.user.fullName}`,
        timestamp: (p.processedAt ?? p.createdAt).toISOString(),
        href: '/finance/payouts',
      });
    }

    for (const log of auditLogs) {
      items.push({
        id: `audit-${log.id}`,
        type: log.action.includes('reject') || log.action.includes('cancel') ? 'alert' : 'admin',
        message: `${log.admin.user.fullName} — ${log.action.replace(/_/g, ' ')} (${log.entityType})`,
        timestamp: log.createdAt.toISOString(),
      });
    }

    if (pendingKyc > 0) {
      items.push({
        id: 'kyc-pending',
        type: 'alert',
        message: `${pendingKyc} KYC document(s) awaiting review`,
        timestamp: new Date().toISOString(),
      });
    }

    return items
      .sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime())
      .slice(0, limit);
  }

  async getTopProviders(limit = 5) {
    const providers = await this.prisma.provider.findMany({
      take: limit,
      orderBy: { totalJobs: 'desc' },
      include: {
        user: { select: { fullName: true, id: true } },
        earnings: {
          select: { netAmount: true },
        },
      },
    });

    return providers.map((p) => ({
      id: p.id,
      userId: p.user.id,
      name: p.user.fullName,
      jobs: p.totalJobs,
      rating: Number(p.ratingAvg),
      earnings: p.earnings.reduce((sum: number, e) => sum + Number(e.netAmount), 0),
    }));
  }

  async getDashboardHealth() {
    const services: { name: string; status: 'operational' | 'degraded' | 'down' }[] = [];

    try {
      await this.prisma.$queryRaw`SELECT 1`;
      services.push({ name: 'Database', status: 'operational' });
    } catch {
      services.push({ name: 'Database', status: 'down' });
    }

    try {
      const pong = await this.redis.getClient().ping();
      services.push({
        name: 'Redis',
        status: pong === 'PONG' ? 'operational' : 'degraded',
      });
    } catch {
      services.push({ name: 'Redis', status: 'down' });
    }

    services.push({ name: 'API', status: 'operational' });
    services.push({
      name: 'SMS (Twilio)',
      status: this.sms.enabled ? 'operational' : 'degraded',
    });

    try {
      const onlineCount = await this.prisma.provider.count({ where: { onlineStatus: 'online' } });
      services.push({
        name: 'Live Tracking',
        status: onlineCount >= 0 ? 'operational' : 'degraded',
      });
    } catch {
      services.push({ name: 'Live Tracking', status: 'degraded' });
    }

    return { services, checkedAt: new Date().toISOString() };
  }

  async getAdminNotifications(limit = 20) {
    const [pendingKyc, openTickets, failedPayments, recentAudits, pendingPayouts, currency, kycAlerts, ticketAlerts, paymentAlerts, payoutAlerts] =
      await Promise.all([
      this.prisma.providerDocument.findMany({
        where: { status: 'pending' },
        take: 5,
        orderBy: { createdAt: 'desc' },
        include: {
          provider: { include: { user: { select: { fullName: true } } } },
        },
      }),
      this.prisma.supportTicket.findMany({
        where: { status: { in: ['open', 'in_progress'] } },
        take: 5,
        orderBy: { createdAt: 'desc' },
        include: { user: { select: { fullName: true } } },
      }),
      this.prisma.payment.findMany({
        where: { status: 'failed' },
        take: 3,
        orderBy: { createdAt: 'desc' },
        include: { job: { select: { jobNumber: true } } },
      }),
      this.prisma.auditLog.findMany({
        take: 5,
        orderBy: { createdAt: 'desc' },
        where: { action: { in: ['process_payout', 'review_document', 'cancel_job'] } },
      }),
      this.prisma.payout.findMany({
        where: { status: 'pending' },
        take: 8,
        orderBy: { createdAt: 'desc' },
        include: { provider: { include: { user: { select: { fullName: true } } } } },
      }),
      this.settings.getPlatformCurrency(),
      this.settings.isAdminAlertEnabled('admin_alert_kyc'),
      this.settings.isAdminAlertEnabled('admin_alert_tickets'),
      this.settings.isAdminAlertEnabled('admin_alert_payments'),
      this.settings.isAdminAlertEnabled('admin_alert_payouts'),
    ]);

    const money = (amount: number) =>
      `${currency.symbol}${amount.toFixed(currency.decimals)}`;

    type Notif = {
      id: string;
      title: string;
      message: string;
      type: 'info' | 'warning' | 'error' | 'success';
      timestamp: string;
      href?: string;
    };

    const items: Notif[] = [];

    if (payoutAlerts) {
      for (const payout of pendingPayouts) {
        items.push({
          id: `payout-request-${payout.id}`,
          title: 'Withdrawal requested',
          message: `${payout.provider.user.fullName} requested ${money(Number(payout.amount))}.`,
          type: 'warning',
          timestamp: payout.createdAt.toISOString(),
          href: '/finance/payouts?status=pending',
        });
      }
    }

    if (kycAlerts) {
      for (const doc of pendingKyc) {
        items.push({
          id: `kyc-${doc.id}`,
          title: 'New KYC Submission',
          message: `Driver ${doc.provider.user.fullName} submitted ${doc.docType} for review.`,
          type: 'info',
          timestamp: doc.createdAt.toISOString(),
          href: '/providers/kyc',
        });
      }
    }

    if (ticketAlerts) {
      for (const ticket of openTickets) {
        items.push({
          id: `ticket-${ticket.id}`,
          title: 'Open Support Ticket',
          message: `${ticket.user.fullName} — ${ticket.subject}`,
          type: ticket.priority === 'urgent' || ticket.priority === 'high' ? 'warning' : 'info',
          timestamp: ticket.createdAt.toISOString(),
          href: `/support/${ticket.id}`,
        });
      }
    }

    if (paymentAlerts) {
      for (const payment of failedPayments) {
        items.push({
          id: `payment-${payment.id}`,
          title: 'Payment Failed',
          message: `Job #${payment.job?.jobNumber ?? '—'} payment failed — review required.`,
          type: 'error',
          timestamp: payment.createdAt.toISOString(),
          href: '/finance/payments',
        });
      }
    }

    for (const log of recentAudits) {
      items.push({
        id: `audit-${log.id}`,
        title: 'Admin Action',
        message: `${log.action.replace(/_/g, ' ')} on ${log.entityType}`,
        type: log.action.includes('payout') ? 'success' : 'info',
        timestamp: log.createdAt.toISOString(),
        href: '/audit',
      });
    }

    return items
      .sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime())
      .slice(0, limit);
  }

  // ─── Roles & Permissions ───────────────────────────────────────────────────

  async getPermissionsCatalog() {
    return ADMIN_MODULES.map((module) => ({
      key: module,
      label: module.charAt(0).toUpperCase() + module.slice(1).replace(/_/g, ' '),
    }));
  }

  async getRoles() {
    const overrideSetting = await this.prisma.platformSetting.findUnique({
      where: { key: 'admin_role_permissions' },
    });
    const overrides =
      (overrideSetting?.value as Partial<Record<AdminRole, AdminModule[]>>) ?? {};

    return (Object.keys(DEFAULT_ROLE_PERMISSIONS) as AdminRole[]).map((role) => ({
      key: role,
      label: role.replace(/_/g, ' '),
      permissions: overrides[role] ?? DEFAULT_ROLE_PERMISSIONS[role],
    }));
  }

  async updateRolePermissions(role: AdminRole, permissions: AdminModule[]) {
    if (role === 'super_admin') {
      throw new BadRequestException('Cannot modify super_admin permissions');
    }

    const existing = await this.prisma.platformSetting.findUnique({
      where: { key: 'admin_role_permissions' },
    });
    const current =
      (existing?.value as Partial<Record<AdminRole, AdminModule[]>>) ?? {};

    const updated = { ...current, [role]: permissions };

    await this.prisma.platformSetting.upsert({
      where: { key: 'admin_role_permissions' },
      create: { key: 'admin_role_permissions', value: updated },
      update: { value: updated },
    });

    return { role, permissions };
  }

  resolvePermissionsForAdmin(adminRole: AdminRole, customPermissions?: unknown) {
    return resolveAdminPermissions(adminRole, customPermissions);
  }

  // ─── Reviews (admin) ───────────────────────────────────────────────────────

  async listReviews(dto: PaginationDto & { hiddenOnly?: boolean }) {
    const { page, limit, skip } = parsePagination(dto);
    const where: Prisma.RatingWhereInput = dto.hiddenOnly ? { isHidden: true } : {};

    const [items, total] = await Promise.all([
      this.prisma.rating.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          fromUser: { select: { fullName: true, role: true } },
          toUser: { select: { fullName: true, role: true } },
          job: { select: { id: true, jobNumber: true } },
        },
      }),
      this.prisma.rating.count({ where }),
    ]);

    return { items, meta: paginateMeta(page, limit, total) };
  }

  async moderateReview(id: string, action: 'hide' | 'unhide' | 'delete') {
    const rating = await this.prisma.rating.findUnique({ where: { id } });
    if (!rating) throw new NotFoundException('Review not found');

    if (action === 'delete') {
      await this.prisma.rating.delete({ where: { id } });
      await this.recalculateRatingAvg(rating.toUserId);
      return { id, deleted: true };
    }

    const result = await this.prisma.rating.update({
      where: { id },
      data: { isHidden: action === 'hide' },
    });
    await this.recalculateRatingAvg(rating.toUserId);
    return result;
  }

  private async recalculateRatingAvg(toUserId: string) {
    const avgResult = await this.prisma.rating.aggregate({
      where: { toUserId, isHidden: false },
      _avg: { score: true },
    });
    const avg = avgResult._avg.score ?? 0;

    const [customer, provider] = await Promise.all([
      this.prisma.customer.findUnique({ where: { userId: toUserId }, select: { id: true } }),
      this.prisma.provider.findUnique({ where: { userId: toUserId }, select: { id: true } }),
    ]);

    if (provider) {
      await this.prisma.provider.update({ where: { id: provider.id }, data: { ratingAvg: avg } });
    } else if (customer) {
      await this.prisma.customer.update({ where: { id: customer.id }, data: { ratingAvg: avg } });
    }
  }

  // ─── Broadcast notifications ───────────────────────────────────────────────

  async listBroadcasts(dto: PaginationDto) {
    const { page, limit, skip } = parsePagination(dto);
    const [items, total] = await Promise.all([
      this.prisma.adminBroadcast.findMany({
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.adminBroadcast.count(),
    ]);
    return { items, meta: paginateMeta(page, limit, total) };
  }

  async createBroadcast(data: {
    title: string;
    body: string;
    audience: 'all' | 'customers' | 'providers';
    createdBy?: string;
  }) {
    const roleFilter =
      data.audience === 'customers'
        ? { role: 'customer' as const }
        : data.audience === 'providers'
          ? { role: 'provider' as const }
          : { role: { in: ['customer' as const, 'provider' as const] } };

    const users = await this.prisma.user.findMany({
      where: { ...roleFilter, status: 'active' },
      select: { id: true },
    });

    const broadcast = await this.prisma.adminBroadcast.create({
      data: {
        title: data.title,
        body: data.body,
        audience: data.audience,
        sentCount: users.length,
        createdBy: data.createdBy,
      },
    });

    const notificationData = {
      broadcastId: broadcast.id,
      audience: data.audience,
    };

    for (const user of users) {
      void this.notifications.notify({
        userId: user.id,
        type: 'admin_broadcast',
        title: data.title,
        body: data.body,
        data: notificationData,
      });
    }

    return broadcast;
  }

  async listAuditLogs(dto: PaginationDto & { entityType?: string; action?: string; from?: string; to?: string }) {
    const { page, limit, skip } = parsePagination(dto);
    const result = await this.audit.findAll({
      page,
      limit,
      skip,
      entityType: dto.entityType,
      action: dto.action,
      from: dto.from,
      to: dto.to,
    });
    return { items: result.items, meta: paginateMeta(page, limit, result.total) };
  }

  // ─── Admin Users ───────────────────────────────────────────────────────────

  async listAdminUsers(dto: PaginationDto) {
    const { page, limit, skip } = parsePagination(dto);
    const where: Prisma.AdminUserWhereInput = {};
    if (dto.search) {
      where.user = {
        OR: [
          { fullName: { contains: dto.search, mode: 'insensitive' } },
          { phone: { contains: dto.search } },
          { email: { contains: dto.search, mode: 'insensitive' } },
        ],
      };
    }
    const [items, total] = await Promise.all([
      this.prisma.adminUser.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: { user: { select: { id: true, fullName: true, email: true, phone: true, status: true } } },
      }),
      this.prisma.adminUser.count({ where }),
    ]);
    return { items, meta: paginateMeta(page, limit, total) };
  }

  async createAdminUser(data: {
    phone: string;
    fullName: string;
    email?: string;
    password: string;
    adminRole: AdminRole;
  }) {
    const passwordHash = await bcrypt.hash(data.password, 10);
    return this.prisma.$transaction(async (tx) => {
      const user = await tx.user.create({
        data: {
          phone: data.phone,
          email: data.email,
          fullName: data.fullName,
          passwordHash,
          role: 'admin',
        },
      });
      return tx.adminUser.create({
        data: { userId: user.id, adminRole: data.adminRole },
        include: { user: { select: { id: true, fullName: true, email: true, phone: true } } },
      });
    });
  }

  async updateAdminUser(
    id: string,
    data: { adminRole?: AdminRole; fullName?: string; status?: 'active' | 'suspended' },
  ) {
    const admin = await this.prisma.adminUser.findUnique({ where: { id }, include: { user: true } });
    if (!admin) throw new NotFoundException('Admin user not found');

    return this.prisma.$transaction(async (tx) => {
      if (data.fullName || data.status) {
        await tx.user.update({
          where: { id: admin.userId },
          data: {
            ...(data.fullName && { fullName: data.fullName }),
            ...(data.status && { status: data.status }),
          },
        });
      }
      if (data.adminRole) {
        return tx.adminUser.update({
          where: { id },
          data: { adminRole: data.adminRole },
          include: { user: { select: { id: true, fullName: true, email: true, phone: true, status: true } } },
        });
      }
      return tx.adminUser.findUnique({
        where: { id },
        include: { user: { select: { id: true, fullName: true, email: true, phone: true, status: true } } },
      });
    });
  }

  // ─── Pricing ───────────────────────────────────────────────────────────────

  async listServiceCategories() {
    return this.prisma.serviceCategory.findMany({ orderBy: { sortOrder: 'asc' } });
  }

  async createServiceCategory(data: {
    name: string;
    slug: string;
    icon?: string;
    description?: string;
    businessType?: 'taxi' | 'parcel';
    sortOrder?: number;
  }) {
    return this.prisma.serviceCategory.create({ data });
  }

  async updateServiceCategory(
    id: string,
    data: {
      name?: string;
      icon?: string;
      description?: string;
      businessType?: 'taxi' | 'parcel';
      isActive?: boolean;
      sortOrder?: number;
    },
  ) {
    return this.prisma.serviceCategory.update({ where: { id }, data });
  }

  async listPricingRules(serviceCategoryId?: string) {
    return this.prisma.servicePricingRule.findMany({
      where: serviceCategoryId ? { serviceCategoryId } : {},
      include: { serviceCategory: true },
      orderBy: { effectiveFrom: 'desc' },
    });
  }

  async createPricingRule(data: {
    serviceCategoryId: string;
    baseFare: number;
    perKmRate?: number;
    perMinuteRate?: number;
    minFare?: number;
    surgeMultiplier?: number;
    city?: string;
  }) {
    return this.prisma.servicePricingRule.create({ data });
  }

  async updatePricingRule(
    id: string,
    data: Partial<{
      baseFare: number;
      perKmRate: number;
      perMinuteRate: number;
      minFare: number;
      surgeMultiplier: number;
      isActive: boolean;
      city: string;
    }>,
  ) {
    return this.prisma.servicePricingRule.update({ where: { id }, data });
  }

  async listPromoCodes(dto: PaginationDto) {
    const { page, limit, skip } = parsePagination(dto);
    const [items, total] = await Promise.all([
      this.prisma.promoCode.findMany({ skip, take: limit, orderBy: { createdAt: 'desc' } }),
      this.prisma.promoCode.count(),
    ]);
    return { items, meta: paginateMeta(page, limit, total) };
  }

  async createPromoCode(data: {
    code: string;
    discountType: DiscountType;
    discountValue: number;
    maxUses?: number;
    validFrom: string;
    validTo: string;
  }) {
    return this.prisma.promoCode.create({
      data: {
        ...data,
        validFrom: new Date(data.validFrom),
        validTo: new Date(data.validTo),
      },
    });
  }

  async updatePromoCode(
    id: string,
    data: Partial<{ discountValue: number; maxUses: number; validTo: string; isActive: boolean }>,
  ) {
    return this.prisma.promoCode.update({
      where: { id },
      data: {
        ...data,
        ...(data.validTo && { validTo: new Date(data.validTo) }),
      },
    });
  }

  // ─── Finance ───────────────────────────────────────────────────────────────

  async listPayments(dto: PaginationDto & { status?: string; method?: string }) {
    const { page, limit, skip } = parsePagination(dto);
    const where: Prisma.PaymentWhereInput = {};
    if (dto.status && dto.status !== 'all') where.status = dto.status as Prisma.EnumPaymentStatusFilter['equals'];
    if (dto.method && dto.method !== 'all') where.method = dto.method as Prisma.EnumPaymentMethodFilter['equals'];

    const [items, total] = await Promise.all([
      this.prisma.payment.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: { job: { select: { id: true, jobNumber: true } } },
      }),
      this.prisma.payment.count({ where }),
    ]);
    return { items, meta: paginateMeta(page, limit, total) };
  }

  async listEarnings(dto: PaginationDto & { providerId?: string }) {
    const { page, limit, skip } = parsePagination(dto);
    const where: Prisma.ProviderEarningWhereInput = dto.providerId ? { providerId: dto.providerId } : {};

    const [items, total] = await Promise.all([
      this.prisma.providerEarning.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          provider: { include: { user: { select: { fullName: true } } } },
          job: { select: { jobNumber: true } },
        },
      }),
      this.prisma.providerEarning.count({ where }),
    ]);
    return { items, meta: paginateMeta(page, limit, total) };
  }

  async listPayouts(dto: PaginationDto & { providerId?: string; status?: string }) {
    const { page, limit, skip } = parsePagination(dto);
    const where: Prisma.PayoutWhereInput = {};
    if (dto.providerId) where.providerId = dto.providerId;
    if (dto.status && dto.status !== 'all') {
      where.status = dto.status as Prisma.EnumPayoutStatusFilter['equals'];
    }

    const [items, total] = await Promise.all([
      this.prisma.payout.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          provider: {
            include: {
              user: { select: { id: true, fullName: true, phone: true, email: true } },
            },
          },
          bankAccount: {
            select: {
              id: true,
              bankName: true,
              accountHolder: true,
              accountNumber: true,
              routingNumber: true,
              lastFour: true,
            },
          },
        },
      }),
      this.prisma.payout.count({ where }),
    ]);
    return { items, meta: paginateMeta(page, limit, total) };
  }

  async getPayoutSummary() {
    const groups = await this.prisma.payout.groupBy({
      by: ['status'],
      _count: { _all: true },
      _sum: { amount: true },
    });

    const summary = {
      pending: { count: 0, amount: 0 },
      processing: { count: 0, amount: 0 },
      paid: { count: 0, amount: 0 },
    };

    for (const g of groups) {
      const key = g.status as keyof typeof summary;
      if (summary[key]) {
        summary[key] = {
          count: g._count._all,
          amount: Number(g._sum.amount ?? 0),
        };
      }
    }

    return summary;
  }

  async rejectPayout(id: string) {
    const payout = await this.prisma.payout.findUnique({ where: { id } });
    if (!payout) throw new NotFoundException('Payout not found');
    if (payout.status === 'paid') throw new BadRequestException('Payout already processed');
    return this.prisma.$transaction(async (tx) => {
      const updated = await tx.payout.update({
        where: { id },
        data: { status: 'rejected' },
      });
      await tx.providerEarning.updateMany({
        where: { payoutId: id },
        data: { payoutStatus: 'pending', payoutId: null },
      });
      return updated;
    });
  }

  async processPayout(id: string) {
    const payout = await this.prisma.payout.findUnique({
      where: { id },
      include: {
        provider: { include: { user: { select: { id: true, fullName: true } } } },
        bankAccount: true,
      },
    });
    if (!payout) throw new NotFoundException('Payout not found');
    if (payout.status === 'paid') throw new BadRequestException('Payout already processed');
    if (payout.status === 'rejected') throw new BadRequestException('Payout was rejected');

    const stripeTransferId = await this.billing.transferPayout(id);

    const result = await this.prisma.$transaction(async (tx) => {
      const updated = await tx.payout.update({
        where: { id },
        data: { status: 'paid', processedAt: new Date(), stripeTransferId },
        include: {
          provider: { include: { user: { select: { id: true, fullName: true, phone: true, email: true } } } },
          bankAccount: {
            select: {
              id: true,
              bankName: true,
              accountHolder: true,
              accountNumber: true,
              routingNumber: true,
              lastFour: true,
            },
          },
        },
      });

      await tx.providerEarning.updateMany({
        where: { payoutId: id },
        data: { payoutStatus: 'paid' },
      });

      return updated;
    });

    const currency = await this.settings.getPlatformCurrency();
    void this.notifications.notify({
      userId: payout.provider.userId,
      type: 'payout_paid',
      title: 'Payout sent',
      body: `Your withdrawal of ${currency.symbol}${Number(payout.amount).toFixed(currency.decimals)} has been processed.`,
      data: { payoutId: id },
    });

    return result;
  }

  exportFinanceCsv(type: 'payments' | 'earnings' | 'payouts') {
    return this.exportFinanceData(type);
  }

  private async exportFinanceData(type: 'payments' | 'earnings' | 'payouts') {
    const escape = (v: string | number | null | undefined) => {
      const s = String(v ?? '');
      return s.includes(',') || s.includes('"') ? `"${s.replace(/"/g, '""')}"` : s;
    };

    let headers: string[] = [];
    let rows: string[][] = [];

    if (type === 'payments') {
      const items = await this.prisma.payment.findMany({
        take: 5000,
        orderBy: { createdAt: 'desc' },
        include: { job: { select: { jobNumber: true } } },
      });
      headers = ['ID', 'Job', 'Method', 'Amount', 'Status', 'Paid At', 'Created At'];
      rows = items.map((p) => [
        p.id,
        p.job?.jobNumber ?? '',
        p.method,
        String(p.amount),
        p.status,
        p.paidAt?.toISOString() ?? '',
        p.createdAt.toISOString(),
      ]);
    } else if (type === 'earnings') {
      const items = await this.prisma.providerEarning.findMany({
        take: 5000,
        orderBy: { createdAt: 'desc' },
        include: {
          provider: { include: { user: { select: { fullName: true } } } },
          job: { select: { jobNumber: true } },
        },
      });
      headers = ['ID', 'Driver', 'Job', 'Gross', 'Platform Fee', 'Net', 'Created At'];
      rows = items.map((e) => [
        e.id,
        e.provider.user.fullName,
        e.job?.jobNumber ?? '',
        String(e.grossAmount),
        String(e.platformFee),
        String(e.netAmount),
        e.createdAt.toISOString(),
      ]);
    } else {
      const items = await this.prisma.payout.findMany({
        take: 5000,
        orderBy: { createdAt: 'desc' },
        include: {
          provider: { include: { user: { select: { fullName: true } } } },
          bankAccount: true,
        },
      });
      headers = ['ID', 'Driver', 'Amount', 'Status', 'Bank', 'Account Holder', 'Account Number', 'Routing', 'Processed At', 'Created At'];
      rows = items.map((p) => [
        p.id,
        p.provider.user.fullName,
        String(p.amount),
        p.status,
        p.bankAccountRef ?? p.bankAccount?.bankName ?? '',
        p.bankAccount?.accountHolder ?? '',
        p.bankAccount?.accountNumber ?? '',
        p.bankAccount?.routingNumber ?? '',
        p.processedAt?.toISOString() ?? '',
        p.createdAt.toISOString(),
      ]);
    }

    const csv = [headers.join(','), ...rows.map((r) => r.map(escape).join(','))].join('\n');
    return {
      filename: `${type}-export-${new Date().toISOString().slice(0, 10)}.csv`,
      content: csv,
      generatedAt: new Date().toISOString(),
    };
  }

  exportFinanceCsvStub(type: 'payments' | 'earnings' | 'payouts') {
    return this.exportFinanceData(type);
  }

  private csvEscape(v: string | number | null | undefined) {
    const s = String(v ?? '');
    return s.includes(',') || s.includes('"') || s.includes('\n')
      ? `"${s.replace(/"/g, '""')}"`
      : s;
  }

  private buildCsv(headers: string[], rows: (string | number | null | undefined)[][]) {
    return [
      headers.join(','),
      ...rows.map((r) => r.map((c) => this.csvEscape(c)).join(',')),
    ].join('\n');
  }

  async exportListCsv(
    type:
      | 'customers'
      | 'jobs'
      | 'support'
      | 'audit'
      | 'reviews'
      | 'admins'
      | 'promos'
      | 'countries',
    filters: Record<string, string | boolean | undefined> = {},
  ) {
    const limit = 5000;
    let headers: string[] = [];
    let rows: (string | number | null | undefined)[][] = [];

    if (type === 'customers') {
      const userWhere: Prisma.UserWhereInput = {};
      if (filters.search) {
        userWhere.OR = [
          { fullName: { contains: String(filters.search), mode: 'insensitive' } },
          { phone: { contains: String(filters.search) } },
        ];
      }
      if (filters.status && filters.status !== 'all') {
        userWhere.status = filters.status as 'active' | 'suspended';
      }
      const items = await this.prisma.customer.findMany({
        where: Object.keys(userWhere).length ? { user: userWhere } : {},
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: { user: { select: { fullName: true, phone: true, email: true, status: true } } },
      });
      headers = ['ID', 'Name', 'Phone', 'Email', 'Status', 'Joined'];
      rows = items.map((c) => [
        c.id,
        c.user.fullName,
        c.user.phone,
        c.user.email ?? '',
        c.user.status,
        c.createdAt.toISOString(),
      ]);
    } else if (type === 'jobs') {
      const where: Prisma.JobWhereInput = {};
      if (filters.status && filters.status !== 'all') where.status = filters.status as Prisma.EnumJobStatusFilter['equals'];
      if (filters.search) {
        where.OR = [
          { jobNumber: { contains: String(filters.search), mode: 'insensitive' } },
          { pickupAddress: { contains: String(filters.search), mode: 'insensitive' } },
        ];
      }
      const items = await this.prisma.job.findMany({
        where,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          customer: { include: { user: { select: { fullName: true } } } },
          provider: { include: { user: { select: { fullName: true } } } },
        },
      });
      headers = ['Job #', 'Customer', 'Driver', 'Status', 'Fare', 'Created'];
      rows = items.map((j) => [
        j.jobNumber,
        j.customer?.user.fullName ?? '',
        j.provider?.user.fullName ?? '',
        j.status,
        String(j.finalFare ?? j.estimatedFare ?? 0),
        j.createdAt.toISOString(),
      ]);
    } else if (type === 'support') {
      const where: Prisma.SupportTicketWhereInput = {};
      if (filters.status && filters.status !== 'all') {
        where.status = filters.status as Prisma.EnumSupportTicketStatusFilter['equals'];
      }
      if (filters.priority && filters.priority !== 'all') {
        where.priority = filters.priority as Prisma.EnumSupportPriorityFilter['equals'];
      }
      if (filters.assignedToId) where.assignedToId = String(filters.assignedToId);
      if (filters.search) {
        where.OR = [
          { ticketNumber: { contains: String(filters.search), mode: 'insensitive' } },
          { subject: { contains: String(filters.search), mode: 'insensitive' } },
        ];
      }
      const items = await this.prisma.supportTicket.findMany({
        where,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: { user: { select: { fullName: true } } },
      });
      headers = ['Ticket #', 'Subject', 'User', 'Category', 'Status', 'Priority', 'Created'];
      rows = items.map((t) => [
        t.ticketNumber,
        t.subject,
        t.user?.fullName ?? '',
        t.category,
        t.status,
        t.priority,
        t.createdAt.toISOString(),
      ]);
    } else if (type === 'audit') {
      const result = await this.audit.findAll({
        page: 1,
        limit,
        skip: 0,
        entityType: filters.entityType as string | undefined,
        action: filters.action as string | undefined,
        from: filters.from as string | undefined,
        to: filters.to as string | undefined,
      });
      headers = ['Action', 'Entity', 'Entity ID', 'Admin', 'Timestamp'];
      rows = result.items.map((log) => [
        log.action,
        log.entityType,
        log.entityId ?? '',
        log.admin?.user.fullName ?? '',
        log.createdAt.toISOString(),
      ]);
    } else if (type === 'reviews') {
      const where: Prisma.RatingWhereInput = filters.hiddenOnly ? { isHidden: true } : {};
      const items = await this.prisma.rating.findMany({
        where,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          fromUser: { select: { fullName: true } },
          toUser: { select: { fullName: true } },
          job: { select: { jobNumber: true } },
        },
      });
      headers = ['Score', 'From', 'To', 'Job', 'Hidden', 'Comment', 'Created'];
      rows = items.map((r) => [
        r.score,
        r.fromUser.fullName,
        r.toUser.fullName,
        r.job.jobNumber,
        r.isHidden ? 'yes' : 'no',
        r.comment ?? '',
        r.createdAt.toISOString(),
      ]);
    } else if (type === 'admins') {
      const userWhere: Prisma.UserWhereInput = {};
      if (filters.search) {
        userWhere.OR = [
          { fullName: { contains: String(filters.search), mode: 'insensitive' } },
          { phone: { contains: String(filters.search) } },
        ];
      }
      const items = await this.prisma.adminUser.findMany({
        where: Object.keys(userWhere).length ? { user: userWhere } : {},
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: { user: { select: { fullName: true, phone: true, status: true } } },
      });
      headers = ['Name', 'Phone', 'Role', 'Status', 'Created'];
      rows = items.map((a) => [
        a.user.fullName,
        a.user.phone,
        a.adminRole,
        a.user.status,
        a.createdAt.toISOString(),
      ]);
    } else if (type === 'promos') {
      const items = await this.prisma.promoCode.findMany({
        take: limit,
        orderBy: { createdAt: 'desc' },
      });
      headers = ['Code', 'Type', 'Value', 'Uses', 'Max Uses', 'Valid From', 'Valid To', 'Active'];
      rows = items.map((p) => [
        p.code,
        p.discountType,
        String(p.discountValue),
        String(p.usedCount),
        p.maxUses != null ? String(p.maxUses) : '',
        p.validFrom.toISOString(),
        p.validTo.toISOString(),
        p.isActive ? 'yes' : 'no',
      ]);
    } else {
      const where: Prisma.CountryWhereInput = {};
      if (filters.search) {
        where.OR = [
          { name: { contains: String(filters.search), mode: 'insensitive' } },
          { code: { contains: String(filters.search), mode: 'insensitive' } },
          { code3: { contains: String(filters.search), mode: 'insensitive' } },
        ];
      }
      if (filters.status === 'active') where.isActive = true;
      if (filters.status === 'inactive') where.isActive = false;
      const items = await this.prisma.country.findMany({
        where,
        take: limit,
        orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
      });
      headers = ['Name', 'Code', 'Code3', 'Numeric', 'Dial Code', 'Icon', 'Status'];
      rows = items.map((c) => [
        c.name,
        c.code,
        c.code3,
        c.numeric,
        c.dialCode,
        c.icon,
        c.isActive ? 'active' : 'inactive',
      ]);
    }

    return {
      filename: `${type}-export-${new Date().toISOString().slice(0, 10)}.csv`,
      content: this.buildCsv(headers, rows),
      generatedAt: new Date().toISOString(),
    };
  }
}
