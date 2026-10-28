import { Controller, Post, Body, Get, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { AuthService } from './auth.service';
import { LoginDto, RegisterDto, OtpSendDto, OtpVerifyDto, RefreshTokenDto, TotpVerifyDto, PasswordResetDto } from './dto/auth.dto';
import { successResponse } from '../common/utils';
import { JwtAuthGuard, RolesGuard } from './guards';
import { Roles } from './roles.decorator';
import { UserRole } from '@ryvo/shared';

@ApiTags('Admin Auth')
@Controller('admin/auth')
export class AdminAuthController {
  constructor(private auth: AuthService) {}

  @Post('login')
  async login(@Body() dto: LoginDto) {
    const tokens = await this.auth.login(dto.phone, dto.password);
    return successResponse(tokens);
  }

  @Post('refresh')
  async refresh(@Body() dto: RefreshTokenDto) {
    return successResponse(await this.auth.refresh(dto.refreshToken));
  }

  @Post('logout')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  async logout(@Body() dto: RefreshTokenDto) {
    return successResponse(await this.auth.logout(dto.refreshToken));
  }

  @Get('me')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  async me(@Req() req: { user: { id: string } }) {
    return successResponse(await this.auth.getAdminProfile(req.user.id));
  }

  @Post('2fa/setup')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @Roles(UserRole.ADMIN)
  async setup2FA(@Req() req: { user: { id: string } }) {
    return successResponse(await this.auth.setup2FA(req.user.id));
  }

  @Post('2fa/verify')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @Roles(UserRole.ADMIN)
  async verify2FA(@Req() req: { user: { id: string } }, @Body() dto: TotpVerifyDto) {
    return successResponse(await this.auth.verify2FA(req.user.id, dto.code));
  }
}

@ApiTags('Customer Auth')
@Controller('customer/auth')
export class CustomerAuthController {
  constructor(private auth: AuthService) {}

  @Post('register')
  async register(@Body() dto: RegisterDto) {
    return successResponse(
      await this.auth.register({ ...dto, role: UserRole.CUSTOMER }),
    );
  }

  @Post('login')
  async login(@Body() dto: LoginDto) {
    return successResponse(await this.auth.login(dto.phone, dto.password, UserRole.CUSTOMER));
  }

  @Post('otp/send')
  async sendOtp(@Body() dto: OtpSendDto) {
    return successResponse(await this.auth.sendOtp(dto.phone, dto.purpose));
  }

  @Post('otp/verify')
  async verifyOtp(@Body() dto: OtpVerifyDto) {
    return successResponse(
      await this.auth.verifyOtp(dto.phone, dto.code, dto.purpose, UserRole.CUSTOMER),
    );
  }

  @Post('password/reset')
  async resetPassword(@Body() dto: PasswordResetDto) {
    return successResponse(
      await this.auth.resetPassword(dto.phone, dto.code, dto.newPassword, { allowDemoCode: true }),
    );
  }

  @Post('refresh')
  async refresh(@Body() dto: RefreshTokenDto) {
    return successResponse(await this.auth.refresh(dto.refreshToken));
  }

  @Post('logout')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  async logout(@Body() dto: RefreshTokenDto) {
    return successResponse(await this.auth.logout(dto.refreshToken));
  }
}

@ApiTags('Provider Auth')
@Controller('provider/auth')
export class ProviderAuthController {
  constructor(private auth: AuthService) {}

  @Post('register')
  async register(@Body() dto: RegisterDto) {
    return successResponse(
      await this.auth.register({ ...dto, role: UserRole.PROVIDER }),
    );
  }

  @Post('login')
  async login(@Body() dto: LoginDto) {
    return successResponse(await this.auth.login(dto.phone, dto.password, UserRole.PROVIDER));
  }

  @Post('otp/send')
  async sendOtp(@Body() dto: OtpSendDto) {
    return successResponse(await this.auth.sendOtp(dto.phone, dto.purpose));
  }

  @Post('otp/verify')
  async verifyOtp(@Body() dto: OtpVerifyDto) {
    return successResponse(
      await this.auth.verifyOtp(dto.phone, dto.code, dto.purpose, UserRole.PROVIDER),
    );
  }

  @Post('password/reset')
  async resetPassword(@Body() dto: PasswordResetDto) {
    return successResponse(
      await this.auth.resetPassword(dto.phone, dto.code, dto.newPassword, { allowDemoCode: true }),
    );
  }

  @Post('refresh')
  async refresh(@Body() dto: RefreshTokenDto) {
    return successResponse(await this.auth.refresh(dto.refreshToken));
  }

  @Post('logout')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  async logout(@Body() dto: RefreshTokenDto) {
    return successResponse(await this.auth.logout(dto.refreshToken));
  }
}
