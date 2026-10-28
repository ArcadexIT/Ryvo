import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { parsePagination, paginateMeta } from '../common/utils';
import { deleteAppUser } from '../common/delete-app-user';
import { PaginationDto } from '../common/dto/pagination.dto';
import { Prisma } from '@ryvo/database';

@Injectable()
export class CustomersService {
  constructor(private prisma: PrismaService) {}

  async findAll(dto: PaginationDto & { status?: string }) {
    const { page, limit, skip } = parsePagination(dto);
    const where: Prisma.CustomerWhereInput = {};
    const userWhere: Prisma.UserWhereInput = { role: 'customer' };

    if (dto.search) {
      userWhere.OR = [
        { fullName: { contains: dto.search, mode: 'insensitive' } },
        { phone: { contains: dto.search } },
      ];
    }

    if (dto.status && dto.status !== 'all') {
      userWhere.status = dto.status as 'active' | 'suspended';
    }

    if (Object.keys(userWhere).length > 0) {
      where.user = userWhere;
    }

    const [items, total] = await Promise.all([
      this.prisma.customer.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          user: { select: { id: true, fullName: true, phone: true, email: true, status: true, avatarUrl: true } },
          _count: { select: { jobs: true, vehicles: true } },
        },
      }),
      this.prisma.customer.count({ where }),
    ]);

    return { items, meta: paginateMeta(page, limit, total) };
  }

  async findOne(id: string) {
    const customer = await this.prisma.customer.findUnique({
      where: { id },
      include: {
        user: { include: { wallet: true } },
        vehicles: true,
        addresses: true,
        jobs: {
          take: 10,
          orderBy: { createdAt: 'desc' },
          include: { serviceCategory: true, provider: { include: { user: { select: { fullName: true } } } } },
        },
      },
    });
    if (!customer) throw new NotFoundException('Customer not found');
    return customer;
  }

  async updateStatus(id: string, status: 'active' | 'suspended') {
    const customer = await this.findOne(id);
    return this.prisma.user.update({
      where: { id: customer.userId },
      data: { status },
    });
  }

  async remove(id: string) {
    const customer = await this.prisma.customer.findUnique({
      where: { id },
      select: {
        id: true,
        userId: true,
        user: { select: { fullName: true, phone: true } },
      },
    });
    if (!customer) throw new NotFoundException('Customer not found');
    await deleteAppUser(this.prisma, customer.userId);
    return {
      id: customer.id,
      fullName: customer.user.fullName,
      phone: customer.user.phone,
    };
  }
}
