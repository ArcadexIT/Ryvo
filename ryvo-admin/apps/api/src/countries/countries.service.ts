import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { parsePagination, paginateMeta } from '../common/utils';
import { PaginationDto } from '../common/dto/pagination.dto';
import { Prisma } from '@ryvo/database';

@Injectable()
export class CountriesService {
  constructor(private prisma: PrismaService) {}

  async findAll(dto: PaginationDto & { status?: string }) {
    const { page, limit, skip } = parsePagination(dto);
    const where: Prisma.CountryWhereInput = {};

    if (dto.search) {
      where.OR = [
        { name: { contains: dto.search, mode: 'insensitive' } },
        { code: { contains: dto.search, mode: 'insensitive' } },
        { code3: { contains: dto.search, mode: 'insensitive' } },
        { dialCode: { contains: dto.search } },
      ];
    }

    if (dto.status === 'active') where.isActive = true;
    if (dto.status === 'inactive') where.isActive = false;

    const [items, total] = await Promise.all([
      this.prisma.country.findMany({
        where,
        skip,
        take: limit,
        orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
      }),
      this.prisma.country.count({ where }),
    ]);

    return { items, meta: paginateMeta(page, limit, total) };
  }

  async listActive() {
    return this.prisma.country.findMany({
      where: { isActive: true },
      orderBy: [{ sortOrder: 'asc' }, { name: 'asc' }],
    });
  }

  async findOne(id: string) {
    const country = await this.prisma.country.findUnique({ where: { id } });
    if (!country) throw new NotFoundException('Country not found');
    return country;
  }

  async setActive(id: string, isActive: boolean) {
    await this.findOne(id);
    return this.prisma.country.update({ where: { id }, data: { isActive } });
  }

  async update(
    id: string,
    data: { name?: string; dialCode?: string; icon?: string; sortOrder?: number },
  ) {
    await this.findOne(id);
    return this.prisma.country.update({ where: { id }, data });
  }
}
