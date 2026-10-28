import { Injectable, UnauthorizedException, BadRequestException, ConflictException, ServiceUnavailableException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import { authenticator } from 'otplib';
import * as QRCode from 'qrcode';
import { PrismaService } from '../prisma/prisma.service';
import { hashToken, generateOtp, normalizePhone } from '../common/utils';
import { UserRole } from '@ryvo/shared';
import { v4 as uuidv4 } from 'uuid';
import { resolveAdminPermissions } from '../admin/admin-permissions';
import { AdminRole, Prisma } from '@ryvo/database';
import { SmsService } from '../sms/sms.service';
import { SettingsService } from '../settings/settings.service';

/** Fixed code for the driver app so registration and password reset work without SMS. */
const DEMO_DRIVER_OTP = '123456';

@Injectable()
export class AuthService {
  constructor(
    private prisma: PrismaService,
    private jwt: JwtService,
    private config: ConfigService,
    private sms: SmsService,
    private settings: SettingsService,
  ) {}

  private get accessSecret() {
    return this.config.get<string>('JWT_ACCESS_SECRET') ?? 'ryvo-access-secret-change-me';
  }

  private get refreshSecret() {
    return this.config.get<string>('JWT_REFRESH_SECRET') ?? 'ryvo-refresh-secret-change-me';
  }

  async login(phone: string, password: string, appRole?: UserRole.CUSTOMER | UserRole.PROVIDER) {
    const normalizedPhone = normalizePhone(phone);
    const user = await this.prisma.user.findUnique({
      where: { phone: normalizedPhone },
      include: { adminUser: true, customer: true, provider: true },
    });
    if (!user?.passwordHash) throw new UnauthorizedException('Invalid credentials');
    const valid = await bcrypt.compare(password, user.passwordHash);
    if (!valid) throw new UnauthorizedException('Invalid credentials');
    if (user.status === 'suspended') throw new UnauthorizedException('Account suspended');
    if (appRole === UserRole.CUSTOMER && !user.phoneVerifiedAt) {
      throw new BadRequestException('Verify your phone number to finish registration');
    }

    if (appRole) {
      if (this.isAdminAccount(user)) throw new UnauthorizedException('Invalid credentials');
      if (appRole === UserRole.CUSTOMER && user.role === UserRole.PROVIDER) {
        throw new UnauthorizedException('This phone is registered as a driver');
      }
      if (appRole === UserRole.PROVIDER && user.role === UserRole.CUSTOMER) {
        throw new UnauthorizedException('This phone is registered as a rider');
      }
      await this.ensureAppProfiles(user.id, appRole);
    }

    await this.prisma.user.update({
      where: { id: user.id },
      data: { lastLoginAt: new Date() },
    });

    const tokenRole = appRole ?? user.role;
    return this.issueTokens(user.id, tokenRole);
  }

  async register(data: {
    phone: string;
    password: string;
    fullName: string;
    email?: string;
    role: UserRole;
    acceptedTerms?: boolean;
  }) {
    if (data.role === UserRole.CUSTOMER && data.acceptedTerms !== true) {
      throw new BadRequestException('You must accept the Terms and Conditions and Privacy Policy');
    }

    data.phone = normalizePhone(data.phone);

    const existing = await this.prisma.user.findUnique({
      where: { phone: data.phone },
      include: { adminUser: true, customer: true, provider: true },
    });

    if (existing) {
      if (this.isAdminAccount(existing)) throw new ConflictException('Phone already registered');
      if (!existing.passwordHash) throw new UnauthorizedException('Invalid credentials');
      const valid = await bcrypt.compare(data.password, existing.passwordHash);
      if (!valid) throw new UnauthorizedException('Invalid credentials');
      if (existing.status === 'suspended') throw new UnauthorizedException('Account suspended');

      if (data.role === UserRole.CUSTOMER) {
        if (existing.customer && existing.phoneVerifiedAt) {
          throw new ConflictException('Phone already registered');
        }
        if (!existing.customer) {
          if (existing.role === UserRole.PROVIDER) {
            throw new ConflictException('This phone is already registered as a driver');
          }
          await this.ensureAppProfiles(existing.id, UserRole.CUSTOMER);
          await this.prisma.customer.update({
            where: { userId: existing.id },
            data: { termsAcceptedAt: new Date() },
          });
        }
        if (!existing.phoneVerifiedAt) {
          return { verificationRequired: true, phone: data.phone };
        }
        await this.prisma.user.update({
          where: { id: existing.id },
          data: { lastLoginAt: new Date() },
        });
        return this.issueTokens(existing.id, UserRole.CUSTOMER);
      }

      if (existing.provider) {
        throw new ConflictException('Phone already registered');
      }
      if (existing.role === UserRole.CUSTOMER) {
        throw new ConflictException('This phone is already registered as a rider');
      }

      await this.ensureAppProfiles(existing.id, UserRole.PROVIDER);
      await this.prisma.user.update({
        where: { id: existing.id },
        data: { lastLoginAt: new Date() },
      });
      return this.issueTokens(existing.id, data.role);
    }

    const passwordHash = await bcrypt.hash(data.password, 12);
    const [providerOtpEnabled, currency] = await Promise.all([
      this.settings.isProviderOtpEnabled(),
      this.settings.getPlatformCurrency(),
    ]);
    const skipProviderOtp = data.role === UserRole.PROVIDER && !providerOtpEnabled;

    let user;
    try {
      user = await this.prisma.user.create({
        data: {
          phone: data.phone,
          email: data.email,
          passwordHash,
          fullName: data.fullName,
          role: data.role,
          status: skipProviderOtp ? 'active' : 'pending_verification',
          phoneVerifiedAt: skipProviderOtp ? new Date() : undefined,
          wallet: { create: { balance: 0, currency: currency.code } },
          ...(data.role === UserRole.CUSTOMER
            ? { customer: { create: { termsAcceptedAt: new Date() } } }
            : {}),
          ...(data.role === UserRole.PROVIDER ? { provider: { create: {} } } : {}),
        },
      });
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
        const target = Array.isArray(error.meta?.target) ? error.meta.target.join(',') : '';
        throw new ConflictException(
          target.includes('email') ? 'That email is already in use.' : 'Phone already registered',
        );
      }
      throw error;
    }

    if (data.role === UserRole.CUSTOMER) {
      return { verificationRequired: true, phone: user.phone };
    }

    return this.issueTokens(user.id, data.role);
  }

  async sendOtp(phone: string, purpose: string) {
    phone = normalizePhone(phone);
    const recent = await this.prisma.otpVerification.findFirst({
      where: { phone, createdAt: { gt: new Date(Date.now() - 60_000) } },
      orderBy: { createdAt: 'desc' },
    });
    if (recent) {
      throw new BadRequestException('Please wait a minute before requesting another code');
    }

    const code = generateOtp();
    const codeHash = await bcrypt.hash(code, 10);
    const expiresAt = new Date(Date.now() + 5 * 60 * 1000);

    const created = await this.prisma.otpVerification.create({
      data: { phone, codeHash, purpose, expiresAt },
    });

    const isDev = (this.config.get<string>('NODE_ENV') ?? 'development') === 'development';

    if (this.sms.enabled) {
      try {
        await this.sms.sendOtp(phone, code, purpose);
      } catch (err) {
        await this.prisma.otpVerification.delete({ where: { id: created.id } }).catch(() => undefined);
        const message = (err as Error).message ?? '';
        if (/not a valid phone number/i.test(message)) {
          throw new BadRequestException(
            'That phone number is not valid. Check the country code and number, then try again.',
          );
        }
        throw new ServiceUnavailableException('Could not send verification code. Please try again later.');
      }
      return { message: 'OTP sent' };
    }

    if (isDev) {
      console.log(`[OTP] ${phone} (${purpose}): ${code}`);
      return { message: 'OTP sent', debugCode: code };
    }

    throw new ServiceUnavailableException('SMS service is not configured');
  }

  async verifyOtp(
    phone: string,
    code: string,
    purpose: string,
    appRole?: UserRole.CUSTOMER | UserRole.PROVIDER,
  ) {
    phone = normalizePhone(phone);
    const demo =
      (appRole === UserRole.PROVIDER || appRole === UserRole.CUSTOMER) &&
      code === DEMO_DRIVER_OTP;
    const otp = await this.prisma.otpVerification.findFirst({
      where: { phone, purpose, verifiedAt: null, expiresAt: { gt: new Date() } },
      orderBy: { createdAt: 'desc' },
    });
    if (!otp && !demo) throw new BadRequestException('Invalid or expired OTP');

    if (!demo) {
      const valid = await bcrypt.compare(code, otp!.codeHash);
      if (!valid) throw new BadRequestException('Invalid OTP');
    }

    if (otp) {
      await this.prisma.otpVerification.update({
        where: { id: otp.id },
        data: { verifiedAt: new Date() },
      });
    }

    await this.prisma.user.updateMany({
      where: { phone },
      data: { phoneVerifiedAt: new Date(), status: 'active' },
    });

    const user = await this.prisma.user.findUnique({ where: { phone } });
    if (!user) throw new BadRequestException('User not found');

    return this.issueTokens(user.id, appRole ?? user.role);
  }

  async refresh(refreshToken: string) {
    try {
      const payload = this.jwt.verify(refreshToken, { secret: this.refreshSecret }) as {
        sub: string;
        type: string;
        role?: string;
      };
      if (payload.type !== 'refresh') throw new UnauthorizedException();

      const tokenHash = hashToken(refreshToken);
      const stored = await this.prisma.refreshToken.findFirst({
        where: { tokenHash, userId: payload.sub, revokedAt: null, expiresAt: { gt: new Date() } },
      });
      if (!stored) throw new UnauthorizedException('Invalid refresh token');

      const user = await this.prisma.user.findUnique({
        where: { id: payload.sub },
        include: { adminUser: true, customer: true, provider: true },
      });
      if (!user) throw new UnauthorizedException();
      if (payload.role === UserRole.CUSTOMER && !user.phoneVerifiedAt) {
        throw new UnauthorizedException('Verify your phone number to finish registration');
      }

      await this.prisma.refreshToken.update({ where: { id: stored.id }, data: { revokedAt: new Date() } });
      return this.issueTokens(user.id, this.resolveTokenRole(payload.role, user));
    } catch {
      throw new UnauthorizedException('Invalid refresh token');
    }
  }

  async resetPassword(
    phone: string,
    code: string,
    newPassword: string,
    options?: { allowDemoCode?: boolean },
  ) {
    phone = normalizePhone(phone);
    const demo = options?.allowDemoCode === true && code === DEMO_DRIVER_OTP;
    const otp = await this.prisma.otpVerification.findFirst({
      where: {
        phone,
        purpose: 'reset_password',
        verifiedAt: null,
        expiresAt: { gt: new Date() },
      },
      orderBy: { createdAt: 'desc' },
    });
    if (!otp && !demo) throw new BadRequestException('Invalid or expired OTP');

    if (!demo) {
      const valid = await bcrypt.compare(code, otp!.codeHash);
      if (!valid) throw new BadRequestException('Invalid OTP');
    }

    const user = await this.prisma.user.findUnique({ where: { phone } });
    if (!user) throw new BadRequestException('User not found');

    const passwordHash = await bcrypt.hash(newPassword, 12);
    await this.prisma.$transaction([
      ...(otp
        ? [
            this.prisma.otpVerification.update({
              where: { id: otp.id },
              data: { verifiedAt: new Date() },
            }),
          ]
        : []),
      this.prisma.user.update({
        where: { id: user.id },
        data: { passwordHash },
      }),
      this.prisma.refreshToken.updateMany({
        where: { userId: user.id, revokedAt: null },
        data: { revokedAt: new Date() },
      }),
    ]);

    return { message: 'Password reset successful' };
  }

  async logout(refreshToken: string) {
    const tokenHash = hashToken(refreshToken);
    await this.prisma.refreshToken.updateMany({
      where: { tokenHash },
      data: { revokedAt: new Date() },
    });
    return { message: 'Logged out' };
  }

  async setup2FA(userId: string) {
    const admin = await this.prisma.adminUser.findUnique({ where: { userId } });
    if (!admin) throw new BadRequestException('Not an admin user');

    const secret = authenticator.generateSecret();
    await this.prisma.adminUser.update({
      where: { userId },
      data: { totpSecret: secret },
    });

    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    const otpauth = authenticator.keyuri(user!.email ?? user!.phone, 'RYVO Admin', secret);
    const qrCode = await QRCode.toDataURL(otpauth);

    return { secret, qrCode };
  }

  async verify2FA(userId: string, code: string) {
    const admin = await this.prisma.adminUser.findUnique({ where: { userId } });
    if (!admin?.totpSecret) throw new BadRequestException('2FA not configured');

    const valid = authenticator.verify({ token: code, secret: admin.totpSecret });
    if (!valid) throw new UnauthorizedException('Invalid 2FA code');

    await this.prisma.adminUser.update({
      where: { userId },
      data: { totpEnabled: true },
    });

    return { message: '2FA enabled' };
  }

  async verify2FALogin(userId: string, code: string) {
    const admin = await this.prisma.adminUser.findUnique({ where: { userId } });
    if (!admin?.totpEnabled || !admin.totpSecret) return true;

    const valid = authenticator.verify({ token: code, secret: admin.totpSecret });
    if (!valid) throw new UnauthorizedException('Invalid 2FA code');
    return true;
  }

  async getAdminProfile(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { adminUser: true },
    });
    if (!user?.adminUser) throw new UnauthorizedException('Not an admin user');

    const overrideSetting = await this.prisma.platformSetting.findUnique({
      where: { key: 'admin_role_permissions' },
    });
    const overrides =
      (overrideSetting?.value as Partial<Record<AdminRole, string[]>>) ?? {};

    const permissions = resolveAdminPermissions(
      user.adminUser.adminRole,
      user.adminUser.permissions,
      overrides as Partial<Record<AdminRole, import('../admin/admin-permissions').AdminModule[]>>,
    );

    return {
      id: user.id,
      fullName: user.fullName,
      phone: user.phone,
      email: user.email,
      adminRole: user.adminUser.adminRole,
      permissions,
      totpEnabled: user.adminUser.totpEnabled,
      lastLoginAt: user.lastLoginAt,
    };
  }

  private isAdminAccount(user: { role: string; adminUser?: { id: string } | null }) {
    return user.role === UserRole.ADMIN || !!user.adminUser;
  }

  /** Create only the profile for the app being used. A driver is not also a rider. */
  private async ensureAppProfiles(userId: string, appRole: UserRole.CUSTOMER | UserRole.PROVIDER) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      include: { adminUser: true, customer: true, provider: true },
    });
    if (!user || this.isAdminAccount(user)) return;

    if (appRole === UserRole.CUSTOMER && !user.customer && user.role !== UserRole.PROVIDER) {
      await this.prisma.customer.create({ data: { userId } });
    }
    if (appRole === UserRole.PROVIDER && !user.provider && user.role !== UserRole.CUSTOMER) {
      await this.prisma.provider.create({ data: { userId } });
    }
  }

  private resolveTokenRole(
    tokenRole: string | undefined,
    user: { role: string; customer?: { id: string } | null; provider?: { id: string } | null; adminUser?: { id: string } | null },
  ) {
    if (this.isAdminAccount(user)) return user.role;
    if (tokenRole === UserRole.PROVIDER && user.provider) return UserRole.PROVIDER;
    if (tokenRole === UserRole.CUSTOMER && user.customer) return UserRole.CUSTOMER;
    if (user.provider && !user.customer) return UserRole.PROVIDER;
    if (user.customer) return UserRole.CUSTOMER;
    return user.role;
  }

  private async issueTokens(userId: string, role: string) {
    const accessToken = this.jwt.sign(
      { sub: userId, role, type: 'access' },
      { secret: this.accessSecret, expiresIn: '15m' },
    );

    const refreshTokenValue = uuidv4();
    const refreshToken = this.jwt.sign(
      { sub: userId, role, type: 'refresh', jti: refreshTokenValue },
      { secret: this.refreshSecret, expiresIn: '7d' },
    );

    await this.prisma.refreshToken.create({
      data: {
        userId,
        tokenHash: hashToken(refreshToken),
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
      },
    });

    return { accessToken, refreshToken, expiresIn: 900 };
  }
}
