import { Module } from '@nestjs/common';
import { ProviderApiController } from './provider-api.controller';
import { ProviderJobsController } from './provider-jobs.controller';
import { ProviderExtraController } from './provider-extra.controller';
import { ProviderJobsService } from './provider-jobs.service';
import { ProviderExtraService } from './provider-extra.service';
import { MatchingModule } from '../matching/matching.module';
import { TrackingModule } from '../tracking/tracking.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { SettingsModule } from '../settings/settings.module';
import { PaymentsModule } from '../payments/payments.module';
import { JobsModule } from '../jobs/jobs.module';
import { OpsModule } from '../ops/ops.module';
import { ProvidersModule } from '../providers/providers.module';
import { FilesModule } from '../files/files.module';
import { BiddingModule } from '../bidding/bidding.module';
import { SubscriptionsModule } from '../subscriptions/subscriptions.module';

@Module({
  imports: [MatchingModule, TrackingModule, NotificationsModule, SettingsModule, PaymentsModule, JobsModule, OpsModule, ProvidersModule, FilesModule, BiddingModule, SubscriptionsModule],
  controllers: [
    ProviderApiController,
    ProviderJobsController,
    ProviderExtraController,
  ],
  providers: [ProviderJobsService, ProviderExtraService],
})
export class ProviderApiModule {}
