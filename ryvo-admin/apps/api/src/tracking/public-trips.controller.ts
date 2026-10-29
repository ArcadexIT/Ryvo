import { Controller, Get, Param } from '@nestjs/common';
import { ApiTags } from '@nestjs/swagger';
import { successResponse } from '../common/utils';
import { TripShareService } from './trip-share.service';

/** Unauthenticated read of a family share link. The token is the only credential. */
@ApiTags('Public trips')
@Controller('public/trips')
export class PublicTripsController {
  constructor(private shares: TripShareService) {}

  @Get(':token')
  async snapshot(@Param('token') token: string) {
    return successResponse(await this.shares.publicSnapshot(token));
  }
}
