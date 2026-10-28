import { Module, forwardRef } from '@nestjs/common';
import { PaymentsService } from './payments.service';
import {
  AdminPaymentsController,
  CustomerPaymentsController,
  StripeWebhookController,
} from './payments.controller';
import { WalletModule } from '../wallet/wallet.module';
import { PrismaModule } from '../prisma/prisma.module';
import { TrackingModule } from '../tracking/tracking.module';
import { MatchingModule } from '../matching/matching.module';
import { SettingsModule } from '../settings/settings.module';
import { SubscriptionsModule } from '../subscriptions/subscriptions.module';

@Module({
  imports: [WalletModule, PrismaModule, TrackingModule, SettingsModule, forwardRef(() => MatchingModule), forwardRef(() => SubscriptionsModule)],
  providers: [PaymentsService],
  controllers: [AdminPaymentsController, CustomerPaymentsController, StripeWebhookController],
  exports: [PaymentsService],
})
export class PaymentsModule {}
