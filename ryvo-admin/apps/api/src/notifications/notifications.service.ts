import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { parsePagination, paginateMeta } from '../common/utils';
import { PaginationDto } from '../common/dto/pagination.dto';
import { RealtimeService } from '../tracking/realtime.service';
import { PushService } from './push.service';

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    private prisma: PrismaService,
    private realtime: RealtimeService,
    private push: PushService,
  ) {}

  async list(userId: string, dto: PaginationDto & { unreadOnly?: boolean }) {
    const { page, limit, skip } = parsePagination(dto);
    const where = {
      userId,
      ...(dto.unreadOnly && { readAt: null }),
    };

    const [items, total] = await Promise.all([
      this.prisma.notification.findMany({
        where,
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.notification.count({ where }),
    ]);

    return { items, meta: paginateMeta(page, limit, total) };
  }

  async markRead(userId: string, notificationId: string) {
    const notification = await this.prisma.notification.findFirst({
      where: { id: notificationId, userId },
    });
    if (!notification) throw new NotFoundException('Notification not found');

    return this.prisma.notification.update({
      where: { id: notificationId },
      data: { readAt: new Date() },
    });
  }

  async markAllRead(userId: string) {
    const result = await this.prisma.notification.updateMany({
      where: { userId, readAt: null },
      data: { readAt: new Date() },
    });
    return { updated: result.count };
  }

  async registerFcmToken(
    userId: string,
    fcmToken: string,
    platform?: 'ios' | 'android',
  ) {
    return this.prisma.user.update({
      where: { id: userId },
      data: {
        fcmToken,
        ...(platform === 'ios' && { fcmTokenIos: fcmToken }),
        ...(platform === 'android' && { fcmTokenAndroid: fcmToken }),
      },
    });
  }

  private collectFcmTokens(user: {
    fcmToken: string | null;
    fcmTokenIos: string | null;
    fcmTokenAndroid: string | null;
  }): string[] {
    return [...new Set(
      [user.fcmTokenIos, user.fcmTokenAndroid, user.fcmToken].filter(
        (token): token is string => !!token?.trim(),
      ),
    )];
  }

  async createNotification(params: {
    userId: string;
    type: string;
    title: string;
    body: string;
    data?: Record<string, unknown>;
  }) {
    return this.prisma.notification.create({
      data: {
        userId: params.userId,
        type: params.type,
        title: params.title,
        body: params.body,
        data: (params.data ?? {}) as object,
      },
    });
  }

  /**
   * Persist an in-app notification, push it over the socket in real time, and
   * deliver an FCM push to the user's registered device. Fully fail-soft: any
   * delivery error is logged and never bubbles up to the calling flow.
   */
  async notify(params: {
    userId: string;
    type: string;
    title: string;
    body: string;
    data?: Record<string, unknown>;
  }) {
    try {
      const notification = await this.createNotification(params);

      this.realtime.emitToUser(params.userId, 'notification:new', notification);

      const user = await this.prisma.user.findUnique({
        where: { id: params.userId },
        select: { fcmToken: true, fcmTokenIos: true, fcmTokenAndroid: true },
      });
      if (user) {
        const data: Record<string, string> = { type: params.type };
        for (const [k, v] of Object.entries(params.data ?? {})) {
          data[k] = typeof v === 'string' ? v : JSON.stringify(v);
        }
        for (const token of this.collectFcmTokens(user)) {
          await this.push.sendToToken(
            token,
            { title: params.title, body: params.body },
            data,
          );
        }
      }

      return notification;
    } catch (err) {
      this.logger.error(
        `notify() failed for user ${params.userId}`,
        err as Error,
      );
      return null;
    }
  }
}
