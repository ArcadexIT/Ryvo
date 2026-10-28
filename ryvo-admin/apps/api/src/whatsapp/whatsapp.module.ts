import { Module } from '@nestjs/common';
import { WhatsAppService } from './whatsapp.service';
import { WhatsAppController } from './whatsapp.controller';
import { JobsModule } from '../jobs/jobs.module';
import { SettingsModule } from '../settings/settings.module';

@Module({
  imports: [JobsModule, SettingsModule],
  providers: [WhatsAppService],
  controllers: [WhatsAppController],
  exports: [WhatsAppService],
})
export class WhatsAppModule {}
