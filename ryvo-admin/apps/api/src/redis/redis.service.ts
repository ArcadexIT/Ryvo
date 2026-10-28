import { Injectable, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';

@Injectable()
export class RedisService implements OnModuleDestroy {
  private client: Redis;
  private pub: Redis;
  private sub: Redis;

  constructor(private config: ConfigService) {
    const url = this.config.get<string>('REDIS_URL') ?? 'redis://localhost:6379';
    this.client = new Redis(url);
    this.pub = new Redis(url);
    this.sub = new Redis(url);
  }

  getClient() {
    return this.client;
  }

  getPub() {
    return this.pub;
  }

  getSub() {
    return this.sub;
  }

  async onModuleDestroy() {
    await Promise.all([this.client.quit(), this.pub.quit(), this.sub.quit()]);
  }
}
