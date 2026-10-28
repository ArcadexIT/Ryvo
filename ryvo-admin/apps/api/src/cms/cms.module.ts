import { Module } from '@nestjs/common';
import { CmsService } from './cms.service';
import { AdminCmsController, PublicCmsController, PublicLegalController } from './cms.controller';

@Module({
  providers: [CmsService],
  controllers: [AdminCmsController, PublicCmsController, PublicLegalController],
  exports: [CmsService],
})
export class CmsModule {}
