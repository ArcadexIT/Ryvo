import { Controller, Get } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { SettingsService } from '../settings/settings.service';
import { successResponse } from '../common/utils';

/**
 * Public (unauthenticated) endpoint that returns the runtime app configuration
 * the mobile apps need before they can authenticate — Stripe publishable key,
 * payment method toggles, wallet feature flag, etc.
 *
 * Only SAFE-TO-EXPOSE values should ever be returned here.
 */
@ApiTags('App Config')
@Controller('app-config')
export class AppConfigController {
  constructor(private settings: SettingsService) {}

  @Get()
  async getConfig() {
    return successResponse(await this.settings.getCustomerAppConfig());
  }
}
