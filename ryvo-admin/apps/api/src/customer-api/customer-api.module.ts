import { Module } from '@nestjs/common';
import { CustomerApiController } from './customer-api.controller';
import { AppConfigController } from './app-config.controller';
import { JobsModule } from '../jobs/jobs.module';
import { MatchingModule } from '../matching/matching.module';
import { PrismaModule } from '../prisma/prisma.module';
import { SettingsModule } from '../settings/settings.module';
import { BiddingModule } from '../bidding/bidding.module';
import { TrackingModule } from '../tracking/tracking.module';

@Module({
  imports: [JobsModule, MatchingModule, PrismaModule, SettingsModule, BiddingModule, TrackingModule],
  controllers: [CustomerApiController, AppConfigController],
})
export class CustomerApiModule {}
