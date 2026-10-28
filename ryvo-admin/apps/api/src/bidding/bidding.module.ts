import { Module } from '@nestjs/common';
import { BiddingService } from './bidding.service';
import { MatchingModule } from '../matching/matching.module';
import { SettingsModule } from '../settings/settings.module';
import { TrackingModule } from '../tracking/tracking.module';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [MatchingModule, SettingsModule, TrackingModule, NotificationsModule],
  providers: [BiddingService],
  exports: [BiddingService],
})
export class BiddingModule {}
