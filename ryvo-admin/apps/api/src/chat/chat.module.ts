import { Module } from '@nestjs/common';
import { ChatService } from './chat.service';
import { CustomerChatController, ProviderChatController } from './chat.controller';
import { TrackingModule } from '../tracking/tracking.module';
import { NotificationsModule } from '../notifications/notifications.module';

@Module({
  imports: [TrackingModule, NotificationsModule],
  controllers: [CustomerChatController, ProviderChatController],
  providers: [ChatService],
})
export class ChatModule {}
