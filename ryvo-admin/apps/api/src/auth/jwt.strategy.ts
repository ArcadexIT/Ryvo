import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import { UserRole } from '@ryvo/shared';

export interface JwtPayload {
  sub: string;
  role: string;
  type: 'access' | 'refresh';
}

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy, 'jwt') {
  constructor(
    config: ConfigService,
    private prisma: PrismaService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: config.get<string>('JWT_ACCESS_SECRET') ?? 'ryvo-access-secret-change-me',
    });
  }

  async validate(payload: JwtPayload) {
    if (payload.type !== 'access') {
      throw new UnauthorizedException('Invalid token type');
    }
    const user = await this.prisma.user.findUnique({
      where: { id: payload.sub },
      include: { adminUser: true, customer: true, provider: true },
    });
    if (!user || user.status === 'deleted' || user.status === 'suspended') {
      throw new UnauthorizedException('User not found or inactive');
    }
    if (payload.role === UserRole.CUSTOMER && user.status === 'pending_verification') {
      throw new UnauthorizedException('Verify your phone number to finish registration');
    }
    return user;
  }
}
