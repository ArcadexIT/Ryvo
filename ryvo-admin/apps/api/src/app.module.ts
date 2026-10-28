import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerModule } from '@nestjs/throttler';
import { PrismaModule } from './prisma/prisma.module';
import { RedisModule } from './redis/redis.module';
import { AuthModule } from './auth/auth.module';
import { FilesModule } from './files/files.module';
import { AuditModule } from './audit/audit.module';
import { SettingsModule } from './settings/settings.module';
import { CustomersModule } from './customers/customers.module';
import { ProvidersModule } from './providers/providers.module';
import { VehiclesModule } from './vehicles/vehicles.module';
import { VehicleCatalogModule } from './vehicle-catalog/vehicle-catalog.module';
import { JobsModule } from './jobs/jobs.module';
import { MatchingModule } from './matching/matching.module';
import { TrackingModule } from './tracking/tracking.module';
import { PaymentsModule } from './payments/payments.module';
import { WalletModule } from './wallet/wallet.module';
import { RatingsModule } from './ratings/ratings.module';
import { NotificationsModule } from './notifications/notifications.module';
import { SupportModule } from './support/support.module';
import { CmsModule } from './cms/cms.module';
import { CountriesModule } from './countries/countries.module';
import { AdminModule } from './admin/admin.module';
import { CustomerApiModule } from './customer-api/customer-api.module';
import { ProviderApiModule } from './provider-api/provider-api.module';
import { ChatModule } from './chat/chat.module';
import { EmailModule } from './email/email.module';
import { SmsModule } from './sms/sms.module';
import { OpsModule } from './ops/ops.module';
import { HealthController } from './health.controller';
import { BiddingModule } from './bidding/bidding.module';
import { SubscriptionsModule } from './subscriptions/subscriptions.module';
import { WhatsAppModule } from './whatsapp/whatsapp.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    ThrottlerModule.forRoot([{ ttl: 60000, limit: 100 }]),
    PrismaModule,
    RedisModule,
    AuthModule,
    FilesModule,
    AuditModule,
    SettingsModule,
    CustomersModule,
    ProvidersModule,
    VehiclesModule,
    VehicleCatalogModule,
    JobsModule,
    MatchingModule,
    TrackingModule,
    PaymentsModule,
    WalletModule,
    RatingsModule,
    NotificationsModule,
    EmailModule,
    SmsModule,
    SupportModule,
    CmsModule,
    CountriesModule,
    AdminModule,
    CustomerApiModule,
    ProviderApiModule,
    ChatModule,
    OpsModule,
    BiddingModule,
    SubscriptionsModule,
    WhatsAppModule,
  ],
  controllers: [HealthController],
})
export class AppModule {}
