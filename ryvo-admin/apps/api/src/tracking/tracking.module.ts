import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { TrackingService } from './tracking.service';
import { TrackingGateway } from './tracking.gateway';
import { RealtimeService } from './realtime.service';

@Module({
  imports: [AuthModule],
  providers: [TrackingService, TrackingGateway, RealtimeService],
  exports: [TrackingService, RealtimeService],
})
export class TrackingModule {}
