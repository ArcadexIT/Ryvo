import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { SettingsModule } from '../settings/settings.module';
import { TrackingService } from './tracking.service';
import { TrackingGateway } from './tracking.gateway';
import { RealtimeService } from './realtime.service';
import { TripShareService } from './trip-share.service';
import { PublicTripsController } from './public-trips.controller';

@Module({
  imports: [AuthModule, SettingsModule],
  controllers: [PublicTripsController],
  providers: [TrackingService, TrackingGateway, RealtimeService, TripShareService],
  exports: [TrackingService, RealtimeService, TripShareService],
})
export class TrackingModule {}
