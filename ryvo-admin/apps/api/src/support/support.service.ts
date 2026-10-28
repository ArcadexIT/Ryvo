import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { parsePagination, paginateMeta, generateTicketNumber } from '../common/utils';
import { PaginationDto } from '../common/dto/pagination.dto';
import { Prisma, SupportPriority, SupportTicketStatus } from '@ryvo/database';

@Injectable()
export class SupportService {
  constructor(private prisma: PrismaService) {}

  async findAll(
    dto: PaginationDto & {
      status?: SupportTicketStatus;
      priority?: SupportPriority;
      assignedToId?: string;
    },
  ) {
    const { page, limit, skip } = parsePagination(dto);
    const where: Prisma.SupportTicketWhereInput = {
      ...(dto.status && { status: dto.status }),
      ...(dto.priority && { priority: dto.priority }),
      ...(dto.assignedToId && { assignedToId: dto.assignedToId }),
      ...(dto.search && {
        OR: [
          { ticketNumber: { contains: dto.search, mode: 'insensitive' } },
          { subject: { contains: dto.search, mode: 'insensitive' } },
        ],
      }),
    };

    const [items, total] = await Promise.all([
      this.prisma.supportTicket.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          user: { select: { fullName: true, phone: true, role: true } },
          assignedTo: { include: { user: { select: { fullName: true } } } },
        },
      }),
      this.prisma.supportTicket.count({ where }),
    ]);

    return { items, meta: paginateMeta(page, limit, total) };
  }

  async findByUser(userId: string, dto: PaginationDto) {
    const { page, limit, skip } = parsePagination(dto);

    const [items, total] = await Promise.all([
      this.prisma.supportTicket.findMany({
        where: { userId },
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.supportTicket.count({ where: { userId } }),
    ]);

    return { items, meta: paginateMeta(page, limit, total) };
  }

  async findOne(id: string, userId?: string) {
    const ticket = await this.prisma.supportTicket.findUnique({
      where: { id },
      include: {
        user: { select: { id: true, fullName: true, role: true, phone: true } },
        assignedTo: { include: { user: { select: { fullName: true } } } },
        messages: {
          orderBy: { createdAt: 'asc' },
          include: { sender: { select: { fullName: true, role: true } } },
        },
        job: { select: { id: true, jobNumber: true } },
      },
    });
    if (!ticket) throw new NotFoundException('Ticket not found');
    if (userId && ticket.userId !== userId) {
      throw new ForbiddenException('Access denied');
    }
    return ticket;
  }

  async create(
    userId: string,
    data: {
      category: string;
      subject: string;
      message: string;
      jobId?: string;
      priority?: SupportPriority;
    },
    senderType = 'customer',
  ) {
    return this.prisma.$transaction(async (tx) => {
      const ticket = await tx.supportTicket.create({
        data: {
          ticketNumber: generateTicketNumber(),
          userId,
          category: data.category,
          subject: data.subject,
          jobId: data.jobId,
          priority: data.priority ?? 'medium',
        },
      });
      await tx.supportMessage.create({
        data: {
          ticketId: ticket.id,
          senderId: userId,
          senderType,
          message: data.message,
        },
      });
      return ticket;
    });
  }

  async addMessage(
    ticketId: string,
    senderId: string,
    senderType: string,
    message: string,
    attachmentUrl?: string,
    ownerUserId?: string,
  ) {
    const ticket = await this.findOne(ticketId, ownerUserId);
    if (!message.trim()) throw new BadRequestException('Message cannot be empty');

    if (ownerUserId) {
      if (ticket.status === 'closed') {
        throw new BadRequestException('This ticket is closed. Open a new ticket for further help.');
      }
      if (ticket.status === 'resolved') {
        await this.prisma.supportTicket.update({
          where: { id: ticketId },
          data: { status: 'open', resolvedAt: null },
        });
      }
    }

    return this.prisma.supportMessage.create({
      data: { ticketId, senderId, senderType, message, attachmentUrl },
    });
  }

  async updateStatus(ticketId: string, status: SupportTicketStatus) {
    await this.findOne(ticketId);
    return this.prisma.supportTicket.update({
      where: { id: ticketId },
      data: {
        status,
        resolvedAt: status === 'resolved' || status === 'closed' ? new Date() : null,
      },
    });
  }

  async assign(ticketId: string, adminUserId: string) {
    await this.findOne(ticketId);
    return this.prisma.supportTicket.update({
      where: { id: ticketId },
      data: { assignedToId: adminUserId, status: 'in_progress' },
    });
  }

  async unassign(ticketId: string) {
    await this.findOne(ticketId);
    return this.prisma.supportTicket.update({
      where: { id: ticketId },
      data: { assignedToId: null, status: 'open' },
    });
  }

  async updatePriority(ticketId: string, priority: SupportPriority) {
    await this.findOne(ticketId);
    return this.prisma.supportTicket.update({
      where: { id: ticketId },
      data: { priority },
    });
  }
}
