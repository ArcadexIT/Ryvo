import { Injectable, Logger } from '@nestjs/common';
import type { Server } from 'socket.io';
import { PrismaService } from '../prisma/prisma.service';
import { isLiveShareStatus, isTerminalShareStatus } from './trip-share.status';

/**
 * Thin wrapper around the Socket.IO server so any module can push realtime
 * events without depending on the gateway directly. The gateway registers its
 * server instance on init via {@link setServer}.
 */
@Injectable()
export class RealtimeService {
  private readonly logger = new Logger(RealtimeService.name);
  private server?: Server;

  constructor(private prisma: PrismaService) {}

  setServer(server: Server) {
    this.server = server;
  }

  private emit(room: string, event: string, payload: unknown) {
    if (!this.server) {
      this.logger.debug(`Socket server not ready, dropped ${event} -> ${room}`);
      return;
    }
    this.server.to(room).emit(event, payload);
  }

  emitToJob(jobId: string, event: string, payload: unknown) {
    this.emit(`job:${jobId}`, event, payload);
    if (event === 'job:location' || event === 'job:status') {
      void this.mirrorToShares(jobId, event, payload);
    }
  }

  emitToShare(shareId: string, event: string, payload: unknown) {
    this.emit(`share:${shareId}`, event, payload);
  }

  emitToUser(userId: string, event: string, payload: unknown) {
    this.emit(`user:${userId}`, event, payload);
  }

  emitToProvider(providerId: string, event: string, payload: unknown) {
    this.emit(`provider:${providerId}`, event, payload);
  }

  emitToAdminLiveMap(event: string, payload: unknown) {
    this.emit('admin:live-map', event, payload);
  }

  /**
   * Family viewers sit in `share:{id}`, not the job room, so they never receive
   * chat, bids, phone numbers, or the job id.
   */
  private async mirrorToShares(jobId: string, event: string, payload: unknown) {
    const share = await this.prisma.tripShare.findFirst({
      where: { jobId, revokedAt: null },
      select: { id: true, job: { select: { status: true } } },
    });
    if (!share) return;

    if (event === 'job:status') {
      const status =
        payload && typeof payload === 'object' && 'status' in payload
          ? String((payload as { status?: unknown }).status ?? '')
          : '';
      if (!status) return;
      if (isTerminalShareStatus(status)) {
        await this.prisma.tripShare.update({
          where: { id: share.id },
          data: { revokedAt: new Date() },
        });
        this.emitToShare(share.id, 'job:status', { status: 'ended', ended: true });
        return;
      }
      this.emitToShare(share.id, 'job:status', { status });
      return;
    }

    if (!isLiveShareStatus(share.job.status)) return;
    const loc = payload as { lat?: unknown; lng?: unknown; heading?: unknown };
    const lat = Number(loc.lat);
    const lng = Number(loc.lng);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) return;
    const heading = Number(loc.heading);
    this.emitToShare(share.id, 'job:location', {
      lat,
      lng,
      ...(Number.isFinite(heading) ? { heading } : {}),
    });
  }
}
