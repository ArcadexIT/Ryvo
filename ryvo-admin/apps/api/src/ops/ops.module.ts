import { Module } from '@nestjs/common';
import { NotificationsModule } from '../notifications/notifications.module';
import { SettingsModule } from '../settings/settings.module';
import { CoverageService } from './coverage.service';
import { TrainingService } from './training.service';
import { AgreementsService } from './agreements.service';
import { BillingOpsService } from './billing-ops.service';
import { OpsBootstrap } from './ops.bootstrap';
import { OpsController } from './ops.controller';

@Module({
  imports: [NotificationsModule, SettingsModule],
  controllers: [OpsController],
  providers: [CoverageService, TrainingService, AgreementsService, BillingOpsService, OpsBootstrap],
  exports: [CoverageService, TrainingService, AgreementsService, BillingOpsService],
})
export class OpsModule {}
