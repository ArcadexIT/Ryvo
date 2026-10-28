import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { parsePagination, paginateMeta } from '../common/utils';
import { PaginationDto } from '../common/dto/pagination.dto';
import { Prisma, DocumentType } from '@ryvo/database';
import { REQUIRED_KYC_DOC_TYPES } from '@ryvo/shared';
import { deleteAppUser } from '../common/delete-app-user';
import { RedisService } from '../redis/redis.service';
import { TrainingService } from '../ops/training.service';
import { SettingsService } from '../settings/settings.service';

@Injectable()
export class ProvidersService {
  constructor(
    private prisma: PrismaService,
    private redis: RedisService,
    private training: TrainingService,
    private settings: SettingsService,
  ) {}

  async findAll(dto: PaginationDto & { verificationStatus?: string; onlineStatus?: string }) {
    const { page, limit, skip } = parsePagination(dto);
    const where: Prisma.ProviderWhereInput = {
      user: {
        role: 'provider',
        ...(dto.search && {
          OR: [{ fullName: { contains: dto.search, mode: 'insensitive' } }, { phone: { contains: dto.search } }],
        }),
      },
      ...(dto.verificationStatus && { verificationStatus: dto.verificationStatus as Prisma.EnumVerificationStatusFilter['equals'] }),
      ...(dto.onlineStatus && { onlineStatus: dto.onlineStatus as Prisma.EnumOnlineStatusFilter['equals'] }),
    };

    const [items, total] = await Promise.all([
      this.prisma.provider.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          user: { select: { id: true, fullName: true, phone: true, status: true, avatarUrl: true } },
          _count: { select: { jobs: true, documents: true } },
        },
      }),
      this.prisma.provider.count({ where }),
    ]);

    return { items, meta: paginateMeta(page, limit, total) };
  }

  async findOne(id: string) {
    const provider = await this.prisma.provider.findUnique({
      where: { id },
      include: {
        user: { include: { wallet: true } },
        documents: {
          orderBy: { createdAt: 'desc' },
          include: { serviceCategory: { select: { name: true } } },
        },
        vehicles: true,
        availability: true,
        serviceAreas: true,
        jobs: { take: 10, orderBy: { createdAt: 'desc' }, include: { serviceCategory: true } },
        subscriptions: {
          where: { status: { in: ['active', 'pending'] } },
          include: { plan: true },
          orderBy: { expiresAt: 'desc' },
          take: 3,
        },
      },
    });
    if (!provider) throw new NotFoundException('Driver not found');

    const [pendingAgg, processingAgg, qualifications] = await Promise.all([
      this.prisma.providerEarning.aggregate({
        where: { providerId: id, payoutStatus: 'pending' },
        _sum: { netAmount: true },
      }),
      this.prisma.providerEarning.aggregate({
        where: { providerId: id, payoutStatus: 'processing' },
        _sum: { netAmount: true },
      }),
      this.training.listForProvider(id),
    ]);

    return {
      ...provider,
      documents: this.latestDocuments(provider.documents),
      earningsWallet: {
        available: Math.round(Number(pendingAgg._sum.netAmount ?? 0) * 100) / 100,
        pending: Math.round(Number(processingAgg._sum.netAmount ?? 0) * 100) / 100,
        currency: (await this.settings.getPlatformCurrency()).code,
      },
      qualifications,
    };
  }

  async getKycPending(dto: PaginationDto) {
    const { page, limit, skip } = parsePagination(dto);
    const search = dto.search?.trim();
    const userSearch: Prisma.UserWhereInput | undefined = search
      ? {
          OR: [
            { fullName: { contains: search, mode: 'insensitive' } },
            { phone: { contains: search } },
          ],
        }
      : undefined;

    const providerWhere: Prisma.ProviderWhereInput = {
      documents: { some: { status: 'pending' } },
      user: { role: 'provider', ...(userSearch ?? {}) },
    };
    const pendingDocsWhere: Prisma.ProviderDocumentWhereInput = {
      status: 'pending',
      provider: { user: { role: 'provider', ...(userSearch ?? {}) } },
    };

    const [providers, providerTotal, documentTotal] = await Promise.all([
      this.prisma.provider.findMany({
        where: providerWhere,
        skip,
        take: limit,
        orderBy: { user: { fullName: 'asc' } },
        include: {
          user: { select: { fullName: true, phone: true, avatarUrl: true } },
          documents: {
            where: { status: 'pending' },
            orderBy: { createdAt: 'asc' },
            include: {
              serviceCategory: { select: { id: true, name: true } },
              equipmentRequirement: { select: { id: true, label: true } },
            },
          },
        },
      }),
      this.prisma.provider.count({ where: providerWhere }),
      this.prisma.providerDocument.count({ where: pendingDocsWhere }),
    ]);

    const docOrder = ['selfie', 'license', 'id_card', 'vehicle_registration', 'insurance', 'equipment_proof'];
    const items = providers.map((provider) => {
      const documents = this.latestDocuments(provider.documents).sort((a, b) => {
        const ai = docOrder.indexOf(a.docType);
        const bi = docOrder.indexOf(b.docType);
        const order = (ai === -1 ? 99 : ai) - (bi === -1 ? 99 : bi);
        if (order !== 0) return order;
        const labelA = (a.equipmentLabel ?? a.equipmentRequirement?.label ?? '').toLowerCase();
        const labelB = (b.equipmentLabel ?? b.equipmentRequirement?.label ?? '').toLowerCase();
        if (labelA !== labelB) return labelA.localeCompare(labelB);
        return a.createdAt.getTime() - b.createdAt.getTime();
      });

      const oldestSubmittedAt = documents.reduce<Date | null>((oldest, doc) => {
        if (!oldest || doc.createdAt < oldest) return doc.createdAt;
        return oldest;
      }, null);

      return {
        provider: {
          id: provider.id,
          user: provider.user,
        },
        pendingCount: documents.length,
        oldestSubmittedAt,
        documents: documents.map((doc) => ({
          id: doc.id,
          docType: doc.docType,
          fileUrl: doc.fileUrl,
          status: doc.status,
          createdAt: doc.createdAt,
          equipmentLabel: doc.equipmentLabel ?? doc.equipmentRequirement?.label ?? null,
          serviceCategoryName: doc.serviceCategory?.name ?? null,
        })),
      };
    });

    return {
      items,
      summary: { providers: providerTotal, documents: documentTotal },
      meta: paginateMeta(page, limit, providerTotal),
    };
  }

  async reviewDocument(
    docId: string,
    adminId: string,
    data: { status: 'approved' | 'rejected'; rejectionReason?: string },
  ) {
    const doc = await this.prisma.providerDocument.findUnique({
      where: { id: docId },
      include: { provider: { select: { userId: true } } },
    });
    if (!doc) throw new NotFoundException('Document not found');

    const updated = await this.prisma.providerDocument.update({
      where: { id: docId },
      data: {
        status: data.status,
        reviewedById: adminId,
        reviewedAt: new Date(),
        rejectionReason: data.status === 'rejected' ? (data.rejectionReason ?? null) : null,
      },
    });

    if (data.status === 'approved' && doc.docType === DocumentType.selfie) {
      await this.prisma.user.update({
        where: { id: doc.provider.userId },
        data: { avatarUrl: doc.fileUrl },
      });
    }

    await this.syncProviderVerificationStatus(doc.providerId);
    if (data.status === 'approved' && doc.serviceCategoryId && doc.docType === DocumentType.equipment_proof) {
      await this.training.refreshEquipmentQualification(doc.providerId, doc.serviceCategoryId);
    }
    return updated;
  }

  /** One current file per identity document. Equipment photos stay as a set. */
  private latestDocuments<T extends { docType: string; createdAt: Date }>(docs: T[]): T[] {
    const equipment = docs.filter((doc) => doc.docType === DocumentType.equipment_proof);
    const singles = new Map<string, T>();
    for (const doc of docs) {
      if (doc.docType === DocumentType.equipment_proof) continue;
      const current = singles.get(doc.docType);
      if (!current || doc.createdAt > current.createdAt) singles.set(doc.docType, doc);
    }
    return [...singles.values(), ...equipment];
  }

  /** Recompute review status after a driver uploads a document so it appears in admin verification. */
  async refreshVerificationStatus(providerId: string) {
    await this.syncProviderVerificationStatus(providerId);
  }

  /**
   * Approve only when every required doc type has a latest upload that is approved.
   * Latest doc per type is by createdAt desc.
   */
  private async syncProviderVerificationStatus(providerId: string) {
    const docs = await this.prisma.providerDocument.findMany({
      where: { providerId },
      orderBy: { createdAt: 'desc' },
    });

    const latestByType = new Map<string, (typeof docs)[number]>();
    for (const doc of docs) {
      if (!latestByType.has(doc.docType)) {
        latestByType.set(doc.docType, doc);
      }
    }

    const requiredLatest = REQUIRED_KYC_DOC_TYPES.map((t) => latestByType.get(t));
    const missingRequired = requiredLatest.some((d) => !d);
    const hasRejectedRequired = requiredLatest.some((d) => d?.status === 'rejected');
    const allRequiredApproved = requiredLatest.every((d) => d?.status === 'approved');

    let verificationStatus: 'pending' | 'approved' | 'rejected' = 'pending';
    if (hasRejectedRequired) verificationStatus = 'rejected';
    else if (!missingRequired && allRequiredApproved) verificationStatus = 'approved';
    else verificationStatus = 'pending';

    await this.prisma.provider.update({
      where: { id: providerId },
      data: { verificationStatus },
    });

    if (verificationStatus !== 'approved') {
      await this.forceOffline(providerId);
    }
  }

  async updateVerificationStatus(
    providerId: string,
    verificationStatus: 'pending' | 'approved' | 'rejected' | 'suspended',
  ) {
    const provider = await this.prisma.provider.findUnique({ where: { id: providerId } });
    if (!provider) throw new NotFoundException('Driver not found');
    const updated = await this.prisma.provider.update({
      where: { id: providerId },
      data: { verificationStatus },
    });
    if (verificationStatus !== 'approved') {
      await this.forceOffline(providerId);
    }
    return updated;
  }

  async forceOffline(providerId: string) {
    const provider = await this.findOne(providerId);
    await this.prisma.provider.update({
      where: { id: providerId },
      data: { onlineStatus: 'offline' },
    });
    await this.redis.getClient().zrem('provider:online', providerId);
    return { message: 'Driver forced offline' };
  }

  async remove(id: string) {
    const provider = await this.prisma.provider.findUnique({
      where: { id },
      select: {
        id: true,
        userId: true,
        user: { select: { fullName: true, phone: true } },
      },
    });
    if (!provider) throw new NotFoundException('Driver not found');
    await this.redis.getClient().zrem('provider:online', id);
    await deleteAppUser(this.prisma, provider.userId);
    return {
      id: provider.id,
      fullName: provider.user.fullName,
      phone: provider.user.phone,
    };
  }

  async updateCommission(providerId: string, commissionRate: number) {
    if (commissionRate < 0 || commissionRate > 1) {
      throw new BadRequestException('Commission rate must be between 0 and 1');
    }
    return this.prisma.provider.update({
      where: { id: providerId },
      data: { commissionRate },
    });
  }
}
