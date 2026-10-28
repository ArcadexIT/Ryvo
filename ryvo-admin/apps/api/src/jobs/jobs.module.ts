import { Module } from '@nestjs/common';
import { JobsService } from './jobs.service';
import { JobsController } from './jobs.controller';
import { PaymentsModule } from '../payments/payments.module';
import { TrackingModule } from '../tracking/tracking.module';
import { SettingsModule } from '../settings/settings.module';
import { MatchingModule } from '../matching/matching.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { OpsModule } from '../ops/ops.module';

@Module({
  imports: [PaymentsModule, TrackingModule, SettingsModule, MatchingModule, NotificationsModule, OpsModule],
  providers: [JobsService],
  controllers: [JobsController],
  exports: [JobsService],
})
export class JobsModule {}
