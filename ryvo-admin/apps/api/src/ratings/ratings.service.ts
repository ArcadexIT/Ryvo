import {
  Injectable,
  NotFoundException,
  BadRequestException,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { parsePagination, paginateMeta } from '../common/utils';
import { PaginationDto } from '../common/dto/pagination.dto';

@Injectable()
export class RatingsService {
  constructor(
    private prisma: PrismaService,
    private notifications: NotificationsService,
  ) {}

  async create(
    fromUserId: string,
    data: { jobId: string; score: number; comment?: string },
  ) {
    if (data.score < 1 || data.score > 5) {
      throw new BadRequestException('Score must be between 1 and 5');
    }

    const comment = data.comment?.trim() || undefined;

    const job = await this.prisma.job.findUnique({
      where: { id: data.jobId },
      include: {
        customer: { include: { user: { select: { id: true, fullName: true } } } },
        provider: { include: { user: { select: { id: true, fullName: true } } } },
      },
    });
    if (!job) throw new NotFoundException('Job not found');
    if (job.status !== 'completed') {
      throw new BadRequestException('Can only rate completed jobs');
    }

    const isCustomer = job.customer.userId === fromUserId;
    const isProvider = job.provider?.userId === fromUserId;
    if (!isCustomer && !isProvider) {
      throw new ForbiddenException('Not authorized to rate this job');
    }
    if (isCustomer && !job.provider) {
      throw new BadRequestException('Job has no driver to rate');
    }

    const existing = await this.prisma.rating.findUnique({
      where: { jobId_fromUserId: { jobId: data.jobId, fromUserId } },
    });
    if (existing) {
      throw new BadRequestException('You have already rated this job');
    }

    const toUserId = isCustomer ? job.provider!.userId : job.customer.userId;
    const fromName = isCustomer
      ? job.customer.user.fullName
      : job.provider!.user.fullName;

    const rating = await this.prisma.$transaction(async (tx) => {
      const created = await tx.rating.create({
        data: {
          jobId: data.jobId,
          fromUserId,
          toUserId,
          score: data.score,
          comment,
        },
      });

      const avgResult = await tx.rating.aggregate({
        where: { toUserId, isHidden: false },
        _avg: { score: true },
      });
      const avg = avgResult._avg.score ?? data.score;

      if (isCustomer && job.providerId) {
        await tx.provider.update({
          where: { id: job.providerId },
          data: { ratingAvg: avg },
        });
      } else {
        await tx.customer.update({
          where: { id: job.customerId },
          data: { ratingAvg: avg },
        });
      }

      return created;
    });

    const stars = data.score === 1 ? 'star' : 'stars';
    let body = `${fromName} rated you ${data.score} ${stars}`;
    if (comment) {
      body += comment.length > 80 ? `: ${comment.slice(0, 77)}...` : `: ${comment}`;
    }

    void this.notifications.notify({
      userId: toUserId,
      type: 'rating_received',
      title: 'New review',
      body,
      data: { jobId: data.jobId, ratingId: rating.id, score: data.score },
    });

    return rating;
  }

  async getForUser(userId: string, dto: PaginationDto) {
    const { page, limit, skip } = parsePagination(dto);
    const where = { toUserId: userId, isHidden: false };

    const [items, total] = await Promise.all([
      this.prisma.rating.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: {
          fromUser: { select: { fullName: true, avatarUrl: true, role: true } },
          job: { select: { id: true, jobNumber: true } },
        },
      }),
      this.prisma.rating.count({ where }),
    ]);

    return { items, meta: paginateMeta(page, limit, total) };
  }

  async getByJob(jobId: string) {
    const ratings = await this.prisma.rating.findMany({
      where: { jobId, isHidden: false },
      include: { fromUser: { select: { fullName: true, role: true } } },
      orderBy: { createdAt: 'asc' },
    });
    if (!ratings.length) throw new NotFoundException('No ratings for this job');
    return ratings;
  }
}
