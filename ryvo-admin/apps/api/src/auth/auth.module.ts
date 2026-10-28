import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { AuthService } from './auth.service';
import { JwtStrategy } from './jwt.strategy';
import { JwtAuthGuard, RolesGuard, AdminRoleGuard } from './guards';
import { AdminAuthController, CustomerAuthController, ProviderAuthController } from './auth.controller';
import { SettingsModule } from '../settings/settings.module';

@Module({
  imports: [PassportModule.register({ defaultStrategy: 'jwt' }), JwtModule.register({}), SettingsModule],
  controllers: [AdminAuthController, CustomerAuthController, ProviderAuthController],
  providers: [AuthService, JwtStrategy, JwtAuthGuard, RolesGuard, AdminRoleGuard],
  exports: [AuthService, JwtModule, JwtAuthGuard, RolesGuard, AdminRoleGuard],
})
export class AuthModule {}
