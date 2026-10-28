import { Module } from '@nestjs/common';
import { SupportService } from './support.service';
import { AdminSupportController, UserSupportController } from './support.controller';

@Module({
  providers: [SupportService],
  controllers: [AdminSupportController, UserSupportController],
  exports: [SupportService],
})
export class SupportModule {}
