import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  MessageBody,
  ConnectedSocket,
  OnGatewayConnection,
  OnGatewayInit,
} from '@nestjs/websockets';
import { Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { Server, Socket } from 'socket.io';
import { TrackingService } from './tracking.service';
import { RealtimeService } from './realtime.service';
import { PrismaService } from '../prisma/prisma.service';

interface SocketData {
  userId?: string;
  role?: string;
  providerId?: string;
}

@WebSocketGateway({ cors: true, namespace: '/tracking' })
export class TrackingGateway implements OnGatewayConnection, OnGatewayInit {
  private readonly logger = new Logger(TrackingGateway.name);

  @WebSocketServer()
  server!: Server;

  constructor(
    private tracking: TrackingService,
    private realtime: RealtimeService,
    private jwt: JwtService,
    private config: ConfigService,
    private prisma: PrismaService,
  ) {}

  afterInit(server: Server) {
    this.realtime.setServer(server);
  }

  /**
   * Best-effort JWT auth on the handshake. A valid token joins the client to
   * its personal `user:{id}` room (and `provider:{id}` for providers) so the
   * server can push targeted events. Anonymous clients are still accepted for
   * backward compatibility (e.g. the admin live-map bootstrap).
   */
  async handleConnection(client: Socket) {
    const token =
      (client.handshake.auth?.token as string | undefined) ??
      (client.handshake.query?.token as string | undefined);

    if (!token) {
      this.logger.debug(`Anonymous client connected: ${client.id}`);
      return;
    }

    try {
      const secret =
        this.config.get<string>('JWT_ACCESS_SECRET') ??
        'ryvo-access-secret-change-me';
      const payload = this.jwt.verify(token, { secret }) as {
        sub: string;
        role: string;
        type: string;
      };
      if (payload.type !== 'access') throw new Error('wrong token type');

      const data = client.data as SocketData;
      data.userId = payload.sub;
      data.role = payload.role;
      void client.join(`user:${payload.sub}`);

      if (payload.role === 'provider') {
        const provider = await this.prisma.provider.findUnique({
          where: { userId: payload.sub },
          select: { id: true },
        });
        if (provider) {
          data.providerId = provider.id;
          void client.join(`provider:${provider.id}`);
        }
      }
      this.logger.debug(`Authenticated ${payload.role} ${payload.sub}`);
    } catch {
      this.logger.debug(`Invalid socket token from ${client.id}`);
    }
  }

  @SubscribeMessage('provider:location')
  async handleProviderLocation(
    @ConnectedSocket() client: Socket,
    @MessageBody()
    payload: {
      providerId?: string;
      lat: number;
      lng: number;
      jobId?: string;
      heading?: number;
      speed?: number;
    },
  ) {
    const providerId =
      payload.providerId ?? (client.data as SocketData).providerId;
    if (!providerId) {
      return { success: false, message: 'providerId required' };
    }

    const result = await this.tracking.updateProviderLocation(
      providerId,
      payload.lat,
      payload.lng,
      payload.jobId,
      payload.heading,
      payload.speed,
    );

    if (payload.jobId) {
      this.server.to(`job:${payload.jobId}`).emit('job:location', result);
    }
    this.server.to('admin:live-map').emit('provider:location', result);

    return { success: true, data: result };
  }

  @SubscribeMessage('job:subscribe')
  async handleJobSubscribe(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { jobId: string },
  ) {
    void client.join(`job:${payload.jobId}`);
    const job = await this.prisma.job.findUnique({
      where: { id: payload.jobId },
      select: {
        provider: { select: { id: true, currentLat: true, currentLng: true } },
      },
    });
    if (job?.provider?.currentLat != null && job.provider.currentLng != null) {
      client.emit('job:location', {
        providerId: job.provider.id,
        lat: Number(job.provider.currentLat),
        lng: Number(job.provider.currentLng),
        jobId: payload.jobId,
      });
    }
    return { success: true, room: `job:${payload.jobId}` };
  }

  @SubscribeMessage('job:unsubscribe')
  handleJobUnsubscribe(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { jobId: string },
  ) {
    void client.leave(`job:${payload.jobId}`);
    return { success: true };
  }

  @SubscribeMessage('admin:live-map:subscribe')
  handleAdminLiveMap(@ConnectedSocket() client: Socket) {
    void client.join('admin:live-map');
    return { success: true, room: 'admin:live-map' };
  }

  @SubscribeMessage('admin:live-map:snapshot')
  async handleLiveSnapshot() {
    const providers = await this.tracking.getLiveProviders();
    return { success: true, data: providers };
  }
}
