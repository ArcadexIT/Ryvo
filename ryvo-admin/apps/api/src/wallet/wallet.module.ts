import { Module } from '@nestjs/common';
import { WalletService } from './wallet.service';
import { CustomerWalletController, AdminWalletController } from './wallet.controller';
import { SettingsModule } from '../settings/settings.module';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [PrismaModule, SettingsModule],
  providers: [WalletService],
  controllers: [CustomerWalletController, AdminWalletController],
  exports: [WalletService],
})
export class WalletModule {}
