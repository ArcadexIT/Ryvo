import {
  Injectable,
  NotFoundException,
  ForbiddenException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { RealtimeService } from '../tracking/realtime.service';
import { NotificationsService } from '../notifications/notifications.service';

type SenderType = 'customer' | 'provider';

@Injectable()
export class ChatService {
  constructor(
    private prisma: PrismaService,
    private realtime: RealtimeService,
    private notifications: NotificationsService,
  ) {}

  /** Resolve the job and both participant user ids, enforcing membership. */
  private async assertParticipant(jobId: string, userId: string, as: SenderType) {
    const job = await this.prisma.job.findUnique({
      where: { id: jobId },
      include: {
        customer: { select: { userId: true } },
        provider: { select: { userId: true } },
      },
    });
    if (!job) throw new NotFoundException('Job not found');

    const customerUserId = job.customer.userId;
    const providerUserId = job.provider?.userId ?? null;

    if (as === 'customer' && customerUserId !== userId) {
      throw new ForbiddenException('Not your job');
    }
    if (as === 'provider' && providerUserId !== userId) {
      throw new ForbiddenException('Not your job');
    }
    return { job, customerUserId, providerUserId };
  }

  async listMessages(jobId: string, userId: string, as: SenderType) {
    await this.assertParticipant(jobId, userId, as);
    const messages = await this.prisma.jobMessage.findMany({
      where: { jobId },
      orderBy: { createdAt: 'asc' },
    });

    // Mark inbound messages read.
    await this.prisma.jobMessage.updateMany({
      where: { jobId, senderType: { not: as }, readAt: null },
      data: { readAt: new Date(), deliveryStatus: 'read' },
    });

    return messages;
  }

  async sendMessage(jobId: string, userId: string, as: SenderType, text: string) {
    const { customerUserId, providerUserId } = await this.assertParticipant(
      jobId,
      userId,
      as,
    );

    const message = await this.prisma.jobMessage.create({
      data: { jobId, senderId: userId, senderType: as, text },
    });

    this.realtime.emitToJob(jobId, 'job:message', message);

    const recipientUserId = as === 'customer' ? providerUserId : customerUserId;
    if (recipientUserId) {
      void this.notifications.notify({
        userId: recipientUserId,
        type: 'chat_message',
        title: 'New message',
        body: text.length > 80 ? `${text.slice(0, 77)}...` : text,
        data: { jobId },
      });
    }

    return message;
  }
}
