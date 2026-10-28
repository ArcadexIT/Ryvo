import { Module, forwardRef } from '@nestjs/common';
import { MatchingService } from './matching.service';
import { SettingsModule } from '../settings/settings.module';
import { TrackingModule } from '../tracking/tracking.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { PaymentsModule } from '../payments/payments.module';
import { OpsModule } from '../ops/ops.module';

@Module({
  imports: [SettingsModule, TrackingModule, NotificationsModule, forwardRef(() => PaymentsModule), OpsModule],
  providers: [MatchingService],
  exports: [MatchingService],
})
export class MatchingModule {}
