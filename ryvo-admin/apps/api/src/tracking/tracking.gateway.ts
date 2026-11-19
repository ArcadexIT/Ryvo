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
import { TripShareService } from './trip-share.service';
import { PrismaService } from '../prisma/prisma.service';

interface SocketData {
  userId?: string;
  role?: string;
  providerId?: string;
  customerId?: string;
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
    private shares: TripShareService,
  ) {}

  afterInit(server: Server) {
    this.realtime.setServer(server);
  }

  /**
   * Require a valid access token on connect. Share-token viewers authenticate
   * later with `share:subscribe` on a short-lived anonymous socket that is
   * limited to that one event.
   */
  async handleConnection(client: Socket) {
    const token =
      (client.handshake.auth?.token as string | undefined) ??
      (client.handshake.query?.token as string | undefined);

    if (!token) {
      // Allow unauthenticated sockets only for public trip-share subscribe.
      (client.data as SocketData).role = 'anonymous';
      this.logger.debug(`Share-only anonymous client connected: ${client.id}`);
      return;
    }

    try {
      const secret = this.config.get<string>('JWT_ACCESS_SECRET') ?? 'xxxxxxxx';
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

      if (payload.role === 'customer') {
        const customer = await this.prisma.customer.findUnique({
          where: { userId: payload.sub },
          select: { id: true },
        });
        if (customer) data.customerId = customer.id;
      }

      this.logger.debug(`Authenticated ${payload.role} ${payload.sub}`);
    } catch {
      this.logger.debug(`Invalid socket token from ${client.id}`);
      client.disconnect(true);
    }
  }

  @SubscribeMessage('provider:location')
  async handleProviderLocation(
    @ConnectedSocket() client: Socket,
    @MessageBody()
    payload: {
      lat: number;
      lng: number;
      jobId?: string;
      heading?: number;
      speed?: number;
    },
  ) {
    const data = client.data as SocketData;
    if (data.role !== 'provider' || !data.providerId) {
      return { success: false, message: 'Provider authentication required' };
    }

    const providerId = data.providerId;

    if (payload.jobId) {
      const job = await this.prisma.job.findUnique({
        where: { id: payload.jobId },
        select: { providerId: true },
      });
      if (!job || job.providerId !== providerId) {
        return { success: false, message: 'Job does not belong to this driver' };
      }
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
      this.realtime.emitToJob(payload.jobId, 'job:location', result);
    }
    this.server.to('admin:live-map').emit('provider:location', result);

    return { success: true, data: result };
  }

  @SubscribeMessage('job:subscribe')
  async handleJobSubscribe(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { jobId: string },
  ) {
    const data = client.data as SocketData;
    if (!data.userId || !payload?.jobId) {
      return { success: false, message: 'Authentication required' };
    }

    const job = await this.prisma.job.findUnique({
      where: { id: payload.jobId },
      select: {
        customerId: true,
        providerId: true,
        customer: { select: { userId: true } },
        provider: {
          select: {
            id: true,
            userId: true,
            currentLat: true,
            currentLng: true,
          },
        },
      },
    });
    if (!job) return { success: false, message: 'Job not found' };

    const isCustomer = job.customer.userId === data.userId;
    const isProvider = job.provider?.userId === data.userId;
    const isAdmin = data.role === 'admin';
    if (!isCustomer && !isProvider && !isAdmin) {
      return { success: false, message: 'Not allowed to join this trip' };
    }

    void client.join(`job:${payload.jobId}`);
    if (job.provider?.currentLat != null && job.provider.currentLng != null) {
      client.emit('job:location', {
        providerId: job.provider.id,
        lat: Number(job.provider.currentLat),
        lng: Number(job.provider.currentLng),
        jobId: payload.jobId,
      });
    }
    return { success: true, room: `job:${payload.jobId}` };
  }

  @SubscribeMessage('share:subscribe')
  async handleShareSubscribe(
    @ConnectedSocket() client: Socket,
    @MessageBody() payload: { token?: string },
  ) {
    const token = typeof payload?.token === 'string' ? payload.token : '';
    const result = token ? await this.shares.resolveSubscribe(token) : { ok: false as const };
    if (!result.ok) {
      client.emit('job:status', { status: 'ended', ended: true });
      return { success: false };
    }
    void client.join(`share:${result.shareId}`);
    client.emit('job:status', { status: result.status, ended: false });
    if (result.lat != null && result.lng != null) {
      client.emit('job:location', { lat: result.lat, lng: result.lng });
    }
    return { success: true };
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
    const data = client.data as SocketData;
    if (data.role !== 'admin' || !data.userId) {
      return { success: false, message: 'Admin authentication required' };
    }
    void client.join('admin:live-map');
    return { success: true, room: 'admin:live-map' };
  }

  @SubscribeMessage('admin:live-map:snapshot')
  async handleLiveSnapshot(@ConnectedSocket() client: Socket) {
    const data = client.data as SocketData;
    if (data.role !== 'admin' || !data.userId) {
      return { success: false, message: 'Admin authentication required' };
    }
    const providers = await this.tracking.getLiveProviders();
    return { success: true, data: providers };
  }
}
