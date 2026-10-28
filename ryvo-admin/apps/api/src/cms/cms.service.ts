import { BadRequestException, Injectable, Logger, NotFoundException, OnModuleInit } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { LEGAL_DEFAULTS, LEGAL_KEYS, LegalKey } from './legal-defaults';

@Injectable()
export class CmsService implements OnModuleInit {
  private readonly logger = new Logger(CmsService.name);

  constructor(private prisma: PrismaService) {}

  async onModuleInit() {
    await this.ensureLegalDefaults().catch((err) => this.logger.warn(err));
  }

  // ─── Banners ───────────────────────────────────────────────────────────────

  async listBanners(activeOnly = false, targetApp?: string) {
    return this.prisma.cmsBanner.findMany({
      where: {
        ...(activeOnly && { isActive: true }),
        ...(targetApp && { targetApp }),
      },
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }],
    });
  }

  async getBanner(id: string) {
    const banner = await this.prisma.cmsBanner.findUnique({ where: { id } });
    if (!banner) throw new NotFoundException('Banner not found');
    return banner;
  }

  async createBanner(data: {
    title: string;
    imageUrl: string;
    link?: string;
    targetApp?: string;
    isActive?: boolean;
    sortOrder?: number;
  }) {
    return this.prisma.cmsBanner.create({ data });
  }

  async updateBanner(
    id: string,
    data: {
      title?: string;
      imageUrl?: string;
      link?: string;
      targetApp?: string;
      isActive?: boolean;
      sortOrder?: number;
    },
  ) {
    await this.getBanner(id);
    return this.prisma.cmsBanner.update({ where: { id }, data });
  }

  async deleteBanner(id: string) {
    await this.getBanner(id);
    return this.prisma.cmsBanner.delete({ where: { id } });
  }

  // ─── FAQs ──────────────────────────────────────────────────────────────────

  async listFaqs(activeOnly = false, category?: string) {
    return this.prisma.faq.findMany({
      where: {
        ...(activeOnly && { isActive: true }),
        ...(category && { category }),
      },
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'desc' }],
    });
  }

  async getFaq(id: string) {
    const faq = await this.prisma.faq.findUnique({ where: { id } });
    if (!faq) throw new NotFoundException('FAQ not found');
    return faq;
  }

  async createFaq(data: {
    question: string;
    answer: string;
    category?: string;
    isActive?: boolean;
    sortOrder?: number;
  }) {
    return this.prisma.faq.create({ data });
  }

  async updateFaq(
    id: string,
    data: {
      question?: string;
      answer?: string;
      category?: string;
      isActive?: boolean;
      sortOrder?: number;
    },
  ) {
    await this.getFaq(id);
    return this.prisma.faq.update({ where: { id }, data });
  }

  async deleteFaq(id: string) {
    await this.getFaq(id);
    return this.prisma.faq.delete({ where: { id } });
  }

  // ─── Legal documents ───────────────────────────────────────────────────────

  async ensureLegalDefaults() {
    for (const key of LEGAL_KEYS) {
      const existing = await this.prisma.legalDocument.findUnique({ where: { key } });
      const defaults = LEGAL_DEFAULTS[key];
      if (existing) {
        if (/roadside assistance/i.test(existing.content)) {
          await this.prisma.legalDocument.update({
            where: { key },
            data: { title: defaults.title, content: defaults.content },
          });
        }
        continue;
      }
      await this.prisma.legalDocument.create({
        data: { key, title: defaults.title, content: defaults.content },
      });
    }
  }

  async listLegal() {
    await this.ensureLegalDefaults();
    const docs = await this.prisma.legalDocument.findMany();
    return LEGAL_KEYS.map((key) => docs.find((doc) => doc.key === key)).filter(Boolean);
  }

  async getLegal(key: string) {
    this.assertLegalKey(key);
    await this.ensureLegalDefaults();
    const doc = await this.prisma.legalDocument.findUnique({ where: { key } });
    if (!doc) throw new NotFoundException('Document not found');
    return doc;
  }

  async updateLegal(key: string, data: { title: string; content: string }) {
    this.assertLegalKey(key);
    const title = data.title.trim();
    const content = data.content.trim();
    if (!title || !content) {
      throw new BadRequestException('Title and content are required');
    }
    await this.ensureLegalDefaults();
    return this.prisma.legalDocument.update({
      where: { key },
      data: { title, content },
    });
  }

  private assertLegalKey(key: string): asserts key is LegalKey {
    if (!LEGAL_KEYS.includes(key as LegalKey)) {
      throw new BadRequestException('Unknown legal document');
    }
  }
}
