import { Injectable, Logger } from '@nestjs/common';
import type { Server } from 'socket.io';

/**
 * Thin wrapper around the Socket.IO server so any module can push realtime
 * events without depending on the gateway directly. The gateway registers its
 * server instance on init via {@link setServer}.
 */
@Injectable()
export class RealtimeService {
  private readonly logger = new Logger(RealtimeService.name);
  private server?: Server;

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
}
