import { Module } from '@nestjs/common';
import { ProvidersService } from './providers.service';
import { ProvidersController } from './providers.controller';
import { OpsModule } from '../ops/ops.module';
import { SettingsModule } from '../settings/settings.module';

@Module({
  imports: [OpsModule, SettingsModule],
  providers: [ProvidersService],
  controllers: [ProvidersController],
  exports: [ProvidersService],
})
export class ProvidersModule {}
