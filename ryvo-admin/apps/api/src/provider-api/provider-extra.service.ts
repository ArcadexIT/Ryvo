import {
  Injectable,
  NotFoundException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { parsePagination, paginateMeta } from '../common/utils';
import { PaginationDto } from '../common/dto/pagination.dto';
import { REQUIRED_KYC_DOC_TYPES } from '@ryvo/shared';
import { SettingsService } from '../settings/settings.service';

@Injectable()
export class ProviderExtraService {
  constructor(
    private prisma: PrismaService,
    private settings: SettingsService,
  ) {}

  // ── Wallet ────────────────────────────────────────────────────────────────

  async getWallet(providerId: string) {
    const [pending, processing] = await Promise.all([
      this.prisma.providerEarning.aggregate({
        where: { providerId, payoutStatus: 'pending' },
        _sum: { netAmount: true },
      }),
      this.prisma.providerEarning.aggregate({
        where: { providerId, payoutStatus: 'processing' },
        _sum: { netAmount: true },
      }),
    ]);

    const available = Number(pending._sum.netAmount ?? 0);
    const inTransit = Number(processing._sum.netAmount ?? 0);

    return {
      available: Math.round(available * 100) / 100,
      pending: Math.round(inTransit * 100) / 100,
      currency: (await this.settings.getPlatformCurrency()).code,
    };
  }

  async withdraw(providerId: string, amount: number, _bankAccountId?: string) {
    if (!amount || amount <= 0) {
      throw new BadRequestException('Amount must be greater than zero');
    }

    const provider = await this.prisma.provider.findUnique({ where: { id: providerId } });
    if (!provider?.stripeAccountId) {
      throw new BadRequestException('Complete Stripe onboarding before requesting a withdrawal.');
    }

    const { available } = await this.getWallet(providerId);
    if (amount > available) {
      throw new BadRequestException('Insufficient available balance');
    }

    return this.prisma.$transaction(async (tx) => {
      const payout = await tx.payout.create({
        data: {
          providerId,
          amount,
          status: 'pending',
          bankAccountRef: 'Stripe Connect',
        },
      });

      // Move enough pending earnings into "processing" to cover the payout.
      const pendingEarnings = await tx.providerEarning.findMany({
        where: { providerId, payoutStatus: 'pending' },
        orderBy: { createdAt: 'asc' },
      });
      let covered = 0;
      const toProcess: string[] = [];
      for (const earning of pendingEarnings) {
        if (covered >= amount) break;
        covered += Number(earning.netAmount);
        toProcess.push(earning.id);
      }
      if (toProcess.length) {
        await tx.providerEarning.updateMany({
          where: { id: { in: toProcess } },
          data: { payoutStatus: 'processing', payoutId: payout.id },
        });
      }

      return payout;
    });
  }

  async listPayouts(providerId: string, dto: PaginationDto) {
    const { page, limit, skip } = parsePagination(dto);
    const where = { providerId };

    const [items, total] = await Promise.all([
      this.prisma.payout.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          bankAccount: {
            select: { bankName: true, lastFour: true, accountHolder: true },
          },
        },
      }),
      this.prisma.payout.count({ where }),
    ]);

    return {
      items: items.map((p) => ({
        id: p.id,
        amount: Number(p.amount),
        status: p.status,
        bankAccountRef: p.bankAccountRef,
        bankName: p.bankAccount?.bankName ?? null,
        lastFour: p.bankAccount?.lastFour ?? null,
        accountHolder: p.bankAccount?.accountHolder ?? null,
        processedAt: p.processedAt,
        createdAt: p.createdAt,
      })),
      meta: paginateMeta(page, limit, total),
    };
  }

  // ── Earnings ──────────────────────────────────────────────────────────────

  async listEarnings(providerId: string, dto: PaginationDto) {
    const { page, limit, skip } = parsePagination(dto);
    const [items, total] = await Promise.all([
      this.prisma.providerEarning.findMany({
        where: { providerId },
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          job: {
            select: { jobNumber: true, completedAt: true, serviceCategory: { select: { name: true } } },
          },
        },
      }),
      this.prisma.providerEarning.count({ where: { providerId } }),
    ]);
    return { items, meta: paginateMeta(page, limit, total) };
  }

  async getWeeklyEarnings(providerId: string) {
    const now = new Date();
    const start = new Date(now);
    start.setDate(now.getDate() - 6);
    start.setHours(0, 0, 0, 0);

    const earnings = await this.prisma.providerEarning.findMany({
      where: { providerId, createdAt: { gte: start } },
      select: { netAmount: true, createdAt: true },
    });

    const dailyBreakdown = Array<number>(7).fill(0);
    let weeklyTotal = 0;
    for (const e of earnings) {
      const net = Number(e.netAmount);
      weeklyTotal += net;
      const dayIndex = Math.floor(
        (e.createdAt.getTime() - start.getTime()) / (24 * 60 * 60 * 1000),
      );
      if (dayIndex >= 0 && dayIndex < 7) dailyBreakdown[dayIndex] += net;
    }

    const provider = await this.prisma.provider.findUnique({
      where: { id: providerId },
      select: { ratingAvg: true },
    });

    return {
      weeklyTotal: Math.round(weeklyTotal * 100) / 100,
      jobCount: earnings.length,
      averageRating: Number(provider?.ratingAvg ?? 0),
      dailyBreakdown: dailyBreakdown.map((v) => Math.round(v * 100) / 100),
    };
  }

  async getTransaction(providerId: string, earningId: string) {
    const earning = await this.prisma.providerEarning.findUnique({
      where: { id: earningId },
      include: {
        job: { select: { jobNumber: true, completedAt: true, serviceCategory: { select: { name: true } } } },
      },
    });
    if (!earning || earning.providerId !== providerId) {
      throw new NotFoundException('Transaction not found');
    }
    return {
      id: earning.id,
      title: earning.job?.serviceCategory?.name ?? earning.job?.jobNumber ?? 'Job payout',
      gross: Number(earning.grossAmount),
      platformFee: Number(earning.platformFee),
      net: Number(earning.netAmount),
      payoutStatus: earning.payoutStatus,
      date: (earning.job?.completedAt ?? earning.createdAt).toISOString(),
    };
  }

  // ── Performance ─────────────────────────────────────────────────────────────

  async getPerformance(providerId: string, userId: string) {
    const [offers, accepted, matchedCount, completedCount, provider, ratings] =
      await Promise.all([
        this.prisma.jobOffer.count({ where: { providerId } }),
        this.prisma.jobOffer.count({ where: { providerId, status: 'accepted' } }),
        this.prisma.job.count({ where: { providerId } }),
        this.prisma.job.count({ where: { providerId, status: 'completed' } }),
        this.prisma.provider.findUnique({
          where: { id: providerId },
          select: { ratingAvg: true, totalJobs: true },
        }),
        this.prisma.rating.findMany({
          where: { toUserId: userId, isHidden: false },
          orderBy: { createdAt: 'desc' },
          take: 50,
          include: {
            fromUser: { select: { fullName: true } },
            job: { select: { jobNumber: true } },
          },
        }),
      ]);

    const breakdown = { 1: 0, 2: 0, 3: 0, 4: 0, 5: 0 } as Record<number, number>;
    for (const r of ratings) {
      if (breakdown[r.score] != null) breakdown[r.score] += 1;
    }

    return {
      acceptanceRate: offers ? Math.round((accepted / offers) * 100) : 0,
      completionRate: matchedCount ? Math.round((completedCount / matchedCount) * 100) : 0,
      totalJobs: provider?.totalJobs ?? 0,
      averageRating: Number(provider?.ratingAvg ?? 0),
      reviewCount: ratings.length,
      ratingBreakdown: breakdown,
      reviews: ratings.map((r) => ({
        id: r.id,
        score: r.score,
        comment: r.comment,
        createdAt: r.createdAt,
        fromName: r.fromUser.fullName,
        jobNumber: r.job.jobNumber,
      })),
    };
  }

  // ── KYC ──────────────────────────────────────────────────────────────────

  async getKycStatus(providerId: string) {
    const [provider, documents, currentAgreementVersion] = await Promise.all([
      this.prisma.provider.findUnique({
        where: { id: providerId },
        select: {
          verificationStatus: true,
          agreementAcceptedAt: true,
          agreementVersionAccepted: true,
        },
      }),
      this.prisma.providerDocument.findMany({
        where: { providerId },
        orderBy: { createdAt: 'desc' },
      }),
      this.settings.getProviderAgreementVersion(),
    ]);

    const latestByType = new Map<string, (typeof documents)[number]>();
    for (const doc of documents) {
      if (!latestByType.has(doc.docType)) {
        latestByType.set(doc.docType, doc);
      }
    }
    const visibleDocuments = [
      ...latestByType.values(),
      ...documents.filter(
        (doc) => doc.docType === 'equipment_proof' && doc.id !== latestByType.get('equipment_proof')?.id,
      ),
    ];

    const requiredDocTypes = [...REQUIRED_KYC_DOC_TYPES];
    const missingDocTypes = requiredDocTypes.filter((t) => !latestByType.has(t));
    const agreementAccepted =
      !!provider?.agreementAcceptedAt &&
      provider.agreementVersionAccepted === currentAgreementVersion;

    return {
      verificationStatus: provider?.verificationStatus ?? 'pending',
      isApproved: provider?.verificationStatus === 'approved',
      documents: visibleDocuments,
      requiredDocTypes,
      missingDocTypes,
      agreementAccepted,
      agreementAcceptedAt: provider?.agreementAcceptedAt ?? null,
      agreementVersionAccepted: provider?.agreementVersionAccepted ?? null,
      currentAgreementVersion,
    };
  }

  // ── Agreement ─────────────────────────────────────────────────────────────

  async getAgreement(providerId: string) {
    const [provider, currentVersion] = await Promise.all([
      this.prisma.provider.findUnique({
        where: { id: providerId },
        select: {
          agreementAcceptedAt: true,
          agreementVersionAccepted: true,
        },
      }),
      this.settings.getProviderAgreementVersion(),
    ]);

    const accepted =
      !!provider?.agreementAcceptedAt &&
      provider.agreementVersionAccepted === currentVersion;

    return {
      currentVersion,
      accepted,
      agreementAcceptedAt: provider?.agreementAcceptedAt ?? null,
      agreementVersionAccepted: provider?.agreementVersionAccepted ?? null,
    };
  }

  async acceptAgreement(providerId: string, version: string) {
    const currentVersion = await this.settings.getProviderAgreementVersion();
    if (!version || version !== currentVersion) {
      throw new BadRequestException(
        `Agreement version mismatch. Current version is "${currentVersion}".`,
      );
    }

    const provider = await this.prisma.provider.update({
      where: { id: providerId },
      data: {
        agreementAcceptedAt: new Date(),
        agreementVersionAccepted: currentVersion,
      },
      select: {
        agreementAcceptedAt: true,
        agreementVersionAccepted: true,
      },
    });

    return {
      currentVersion,
      accepted: true,
      agreementAcceptedAt: provider.agreementAcceptedAt,
      agreementVersionAccepted: provider.agreementVersionAccepted,
    };
  }

  // ── Vehicle ────────────────────────────────────────────────────────────────

  private assertNamedVehicleField(value: string, field: 'make' | 'model') {
    const trimmed = value.trim();
    if (!trimmed) throw new BadRequestException(`${field} is required`);
    if (trimmed.toLowerCase() === 'other') {
      throw new BadRequestException(`Enter a ${field} name instead of Other`);
    }
    return trimmed;
  }

  async listRideClasses() {
    return this.prisma.serviceCategory.findMany({
      where: { isActive: true },
      orderBy: { sortOrder: 'asc' },
      select: { id: true, name: true, slug: true, description: true },
    });
  }

  async getVehicle(providerId: string) {
    return this.prisma.providerVehicle.findFirst({
      where: { providerId },
      orderBy: { createdAt: 'desc' },
    });
  }

  async upsertVehicle(
    providerId: string,
    data: {
      vehicleType: string;
      make: string;
      model: string;
      year: number;
      plateNumber: string;
      transmission: string;
      fuelType: string;
      color?: string;
      engineCapacity?: string;
      photoUrl?: string;
      rideClassSlugs?: string[];
    },
  ) {
    const make = this.assertNamedVehicleField(data.make, 'make');
    const model = this.assertNamedVehicleField(data.model, 'model');
    const plateNumber = data.plateNumber.trim().toUpperCase();
    if (!plateNumber) throw new BadRequestException('plateNumber is required');
    const { rideClassSlugs, ...rest } = data;
    let serviceCapabilities: string[] | undefined;
    if (rideClassSlugs) {
      const slugs = [...new Set(rideClassSlugs.map((slug) => slug.trim()).filter(Boolean))];
      const classes = await this.prisma.serviceCategory.findMany({
        where: { slug: { in: slugs }, isActive: true },
        select: { slug: true },
      });
      if (classes.length !== slugs.length) {
        throw new BadRequestException('Choose an active ride class');
      }
      serviceCapabilities = classes.map((item) => item.slug);
    }
    const vehicle = {
      ...rest,
      make,
      model,
      plateNumber,
      ...(serviceCapabilities ? { serviceCapabilities } : {}),
    };

    const existing = await this.prisma.providerVehicle.findFirst({
      where: { providerId },
      orderBy: { createdAt: 'desc' },
    });
    if (existing) {
      return this.prisma.providerVehicle.update({
        where: { id: existing.id },
        data: vehicle,
      });
    }
    return this.prisma.providerVehicle.create({
      data: { providerId, ...vehicle },
    });
  }

  // ── Bank accounts ─────────────────────────────────────────────────────────

  private formatBankAccount(account: {
    id: string;
    bankName: string;
    accountHolder: string;
    lastFour: string;
    routingNumber: string | null;
    isPrimary: boolean;
    createdAt: Date;
  }) {
    return {
      id: account.id,
      bankName: account.bankName,
      accountHolder: account.accountHolder,
      lastFour: account.lastFour,
      routingNumber: account.routingNumber,
      isPrimary: account.isPrimary,
      createdAt: account.createdAt,
    };
  }

  async listBankAccounts(providerId: string) {
    const accounts = await this.prisma.bankAccount.findMany({
      where: { providerId },
      orderBy: [{ isPrimary: 'desc' }, { createdAt: 'desc' }],
    });
    return accounts.map((a) => this.formatBankAccount(a));
  }

  async createBankAccount(
    providerId: string,
    data: {
      bankName: string;
      accountHolder: string;
      accountNumber: string;
      routingNumber?: string;
    },
  ) {
    const bankName = data.bankName.trim();
    const accountHolder = data.accountHolder.trim();
    const accountNumber = data.accountNumber.replace(/\s/g, '');
    const routingNumber = data.routingNumber?.replace(/\s/g, '') || undefined;

    if (!bankName || !accountHolder || !accountNumber) {
      throw new BadRequestException('Bank name, account holder, and account number are required');
    }
    if (accountNumber.length < 4) {
      throw new BadRequestException('Account number must be at least 4 digits');
    }

    const lastFour = accountNumber.slice(-4);
    const existingCount = await this.prisma.bankAccount.count({ where: { providerId } });

    const account = await this.prisma.bankAccount.create({
      data: {
        providerId,
        bankName,
        accountHolder,
        accountNumber,
        routingNumber,
        lastFour,
        isPrimary: existingCount === 0,
      },
    });

    if (account.isPrimary) {
      await this.prisma.provider.update({
        where: { id: providerId },
        data: { bankAccountRef: `${bankName} •••• ${lastFour}` },
      });
    }

    return this.formatBankAccount(account);
  }

  async setPrimaryBankAccount(providerId: string, accountId: string) {
    const account = await this.prisma.bankAccount.findFirst({
      where: { id: accountId, providerId },
    });
    if (!account) throw new NotFoundException('Bank account not found');

    await this.prisma.$transaction([
      this.prisma.bankAccount.updateMany({
        where: { providerId },
        data: { isPrimary: false },
      }),
      this.prisma.bankAccount.update({
        where: { id: accountId },
        data: { isPrimary: true },
      }),
      this.prisma.provider.update({
        where: { id: providerId },
        data: { bankAccountRef: `${account.bankName} •••• ${account.lastFour}` },
      }),
    ]);

    return this.formatBankAccount({ ...account, isPrimary: true });
  }

  async deleteBankAccount(providerId: string, accountId: string) {
    const account = await this.prisma.bankAccount.findFirst({
      where: { id: accountId, providerId },
    });
    if (!account) throw new NotFoundException('Bank account not found');

    await this.prisma.bankAccount.delete({ where: { id: accountId } });

    if (account.isPrimary) {
      const next = await this.prisma.bankAccount.findFirst({
        where: { providerId },
        orderBy: { createdAt: 'desc' },
      });
      if (next) {
        await this.setPrimaryBankAccount(providerId, next.id);
      } else {
        await this.prisma.provider.update({
          where: { id: providerId },
          data: { bankAccountRef: null },
        });
      }
    }

    return { deleted: true };
  }

  // ── FAQs ──────────────────────────────────────────────────────────────────

  async getFaqs() {
    return this.prisma.faq.findMany({
      where: { isActive: true, OR: [{ category: 'provider' }, { category: null }] },
      orderBy: { sortOrder: 'asc' },
    });
  }
}
