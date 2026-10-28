import { Module } from '@nestjs/common';
import { SubscriptionsService } from './subscriptions.service';
import { SettingsModule } from '../settings/settings.module';
import { TrackingModule } from '../tracking/tracking.module';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [SettingsModule, TrackingModule, NotificationsModule],
  providers: [SubscriptionsService],
  exports: [SubscriptionsService],
})
export class SubscriptionsModule {}
