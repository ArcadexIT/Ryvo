import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  Query,
  UseGuards,
  Req,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard, RolesGuard } from '../auth/guards';
import { Roles } from '../auth/roles.decorator';
import { CancelledBy, UserRole } from '@ryvo/shared';
import { BiddingService } from '../bidding/bidding.service';
import { TripShareService } from '../tracking/trip-share.service';
import { successResponse } from '../common/utils';
import { PaginationDto } from '../common/dto/pagination.dto';
import { PrismaService } from '../prisma/prisma.service';
import { JobsService } from '../jobs/jobs.service';
import { MatchingService } from '../matching/matching.service';
import {
  IsBoolean,
  IsIn,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Max,
  MaxLength,
  Min,
} from 'class-validator';
import { Transform } from 'class-transformer';

class UpdateProfileDto {
  @IsOptional() @IsString() fullName?: string;
  @IsOptional() @IsString() email?: string;
  @IsOptional() @IsString() avatarUrl?: string;
}

class AddressDto {
  @IsOptional() @IsString() label?: string;
  @IsString() addressLine!: string;
  @IsNumber() lat!: number;
  @IsNumber() lng!: number;
  @IsOptional() @IsBoolean() isDefault?: boolean;
}

class CreateJobDto {
  @IsOptional() @IsUUID() vehicleId?: string;
  @IsOptional() @IsIn(['taxi', 'bidding', 'parcel']) jobType?: 'taxi' | 'bidding' | 'parcel';
  @IsOptional() @IsNumber() @Min(0.5) offeredPrice?: number;
  @IsOptional() @IsString() @MaxLength(120) recipientName?: string;
  @IsOptional() @IsString() @MaxLength(32) recipientPhone?: string;
  @IsOptional() @IsIn(['small', 'medium', 'large']) parcelSize?: 'small' | 'medium' | 'large';
  @IsOptional() @IsString() @MaxLength(500) parcelNotes?: string;
  @IsUUID() serviceCategoryId!: string;
  @Transform(({ value }: { value: unknown }) =>
    typeof value === 'string' ? value.trim() : value,
  )
  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  pickupAddress!: string;
  @IsNumber() @Min(-90) @Max(90) pickupLat!: number;
  @IsNumber() @Min(-180) @Max(180) pickupLng!: number;
  @IsString() @IsNotEmpty() @MaxLength(500) dropoffAddress!: string;
  @IsNumber() @Min(-90) @Max(90) dropoffLat!: number;
  @IsNumber() @Min(-180) @Max(180) dropoffLng!: number;
  @IsOptional() @IsString() customerNotes?: string;
  @IsOptional() @IsString() bookingType?: 'instant' | 'scheduled';
  @IsOptional() @IsString() scheduledAt?: string;
  @IsIn(['stripe', 'wallet', 'cash']) paymentMethod!: 'stripe' | 'wallet' | 'cash';
  @IsOptional() @IsString() stripePaymentMethodId?: string;
}

class EstimateFareDto {
  @IsUUID() serviceCategoryId!: string;
  @IsNumber() @Min(-90) @Max(90) pickupLat!: number;
  @IsNumber() @Min(-180) @Max(180) pickupLng!: number;
  @IsNumber() @Min(-90) @Max(90) dropoffLat!: number;
  @IsNumber() @Min(-180) @Max(180) dropoffLng!: number;
}

@ApiTags('Customer API')
@Controller('customer')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.CUSTOMER)
@ApiBearerAuth()
export class CustomerApiController {
  constructor(
    private prisma: PrismaService,
    private jobs: JobsService,
    private matching: MatchingService,
    private bidding: BiddingService,
    private tripShares: TripShareService,
  ) {}

  @Get('profile')
  async profile(@Req() req: { user: { id: string; customer?: { id: string } } }) {
    const customer = await this.prisma.customer.findUnique({
      where: { userId: req.user.id },
      include: {
        user: {
          select: {
            id: true,
            fullName: true,
            phone: true,
            email: true,
            avatarUrl: true,
            status: true,
          },
        },
        addresses: true,
        vehicles: true,
      },
    });
    return successResponse(customer);
  }

  @Patch('profile')
  async updateProfile(@Req() req: { user: { id: string } }, @Body() dto: UpdateProfileDto) {
    const user = await this.prisma.user.update({
      where: { id: req.user.id },
      data: dto,
    });
    return successResponse(user);
  }

  @Get('addresses')
  async addresses(@Req() req: { user: { customer?: { id: string } } }) {
    const items = await this.prisma.customerAddress.findMany({
      where: { customerId: req.user.customer!.id },
      orderBy: [{ isDefault: 'desc' }, { createdAt: 'desc' }],
    });
    return successResponse(items);
  }

  @Post('addresses')
  async createAddress(
    @Req() req: { user: { customer?: { id: string } } },
    @Body() dto: AddressDto,
  ) {
    if (dto.isDefault) {
      await this.prisma.customerAddress.updateMany({
        where: { customerId: req.user.customer!.id },
        data: { isDefault: false },
      });
    }
    const address = await this.prisma.customerAddress.create({
      data: { customerId: req.user.customer!.id, ...dto },
    });
    return successResponse(address);
  }

  @Patch('addresses/:id')
  async updateAddress(
    @Req() req: { user: { customer?: { id: string } } },
    @Param('id') id: string,
    @Body() dto: AddressDto,
  ) {
    if (dto.isDefault) {
      await this.prisma.customerAddress.updateMany({
        where: { customerId: req.user.customer!.id, id: { not: id } },
        data: { isDefault: false },
      });
    }
    const address = await this.prisma.customerAddress.update({
      where: { id, customerId: req.user.customer!.id },
      data: dto,
    });
    return successResponse(address);
  }

  @Delete('addresses/:id')
  async deleteAddress(
    @Req() req: { user: { customer?: { id: string } } },
    @Param('id') id: string,
  ) {
    await this.prisma.customerAddress.delete({
      where: { id, customerId: req.user.customer!.id },
    });
    return successResponse({ deleted: true });
  }

  @Get('jobs')
  async listJobs(@Req() req: { user: { customer?: { id: string } } }, @Query() query: PaginationDto) {
    const result = await this.jobs.findByCustomer(req.user.customer!.id, query);
    return successResponse(result.items, undefined, result.meta);
  }

  @Get('jobs/active')
  async activeJob(@Req() req: { user: { customer?: { id: string } } }) {
    return successResponse(await this.jobs.findActiveByCustomer(req.user.customer!.id));
  }

  @Get('jobs/:id')
  async jobDetail(
    @Req() req: { user: { customer?: { id: string } } },
    @Param('id') id: string,
  ) {
    await this.jobs.assertCustomerOwnership(id, req.user.customer!.id);
    return successResponse(await this.jobs.findOne(id));
  }

  @Post('jobs/estimate-fare')
  async estimateFare(@Body() dto: EstimateFareDto) {
    return successResponse(await this.jobs.estimateFare(dto));
  }

  @Post('jobs')
  async createJob(
    @Req() req: { user: { customer?: { id: string } } },
    @Body() dto: CreateJobDto,
  ) {
    const job = await this.jobs.createJob(req.user.customer!.id, dto);
    return successResponse(job);
  }

  @Post('jobs/:id/confirm-start')
  async confirmStart(
    @Req() req: { user: { customer?: { id: string } } },
    @Param('id') id: string,
  ) {
    await this.jobs.assertCustomerOwnership(id, req.user.customer!.id);
    return successResponse(
      await this.jobs.confirmJobStart(id, 'customer', req.user.customer!.id),
    );
  }

  @Post('jobs/:id/share')
  async shareTrip(
    @Req() req: { user: { customer?: { id: string } } },
    @Param('id') id: string,
  ) {
    return successResponse(await this.tripShares.create(req.user.customer!.id, id));
  }

  @Delete('jobs/:id/share')
  async stopSharingTrip(
    @Req() req: { user: { customer?: { id: string } } },
    @Param('id') id: string,
  ) {
    return successResponse(await this.tripShares.revoke(req.user.customer!.id, id));
  }

  @Patch('jobs/:id/cancel')
  async cancelJob(
    @Req() req: { user: { customer?: { id: string } } },
    @Param('id') id: string,
    @Body() body: { reason?: string },
  ) {
    await this.jobs.assertCustomerOwnership(id, req.user.customer!.id);
    return successResponse(
      await this.jobs.cancelJob(id, CancelledBy.CUSTOMER, body.reason, req.user.customer!.id),
    );
  }

  @Get('jobs/:id/timeline')
  async jobTimeline(
    @Req() req: { user: { customer?: { id: string } } },
    @Param('id') id: string,
  ) {
    await this.jobs.assertCustomerOwnership(id, req.user.customer!.id);
    return successResponse(await this.jobs.getTimeline(id));
  }

  @Get('jobs/:id/location-trail')
  async locationTrail(
    @Req() req: { user: { customer?: { id: string } } },
    @Param('id') id: string,
  ) {
    await this.jobs.assertCustomerOwnership(id, req.user.customer!.id);
    return successResponse(await this.jobs.getLocationTrail(id));
  }

  @Get('jobs/:id/bids')
  async listBids(
    @Req() req: { user: { customer?: { id: string } } },
    @Param('id') id: string,
  ) {
    return successResponse(await this.bidding.listBids(id, req.user.customer!.id));
  }

  @Post('jobs/:id/bids/:bidId/accept')
  async acceptBid(
    @Req() req: { user: { customer?: { id: string } } },
    @Param('id') id: string,
    @Param('bidId') bidId: string,
  ) {
    return successResponse(await this.bidding.acceptBid(req.user.customer!.id, id, bidId));
  }

  @Get('providers/nearby')
  async nearbyProviders(
    @Query('lat') lat: string,
    @Query('lng') lng: string,
    @Query('radiusKm') radiusKm?: string,
  ) {
    const providers = await this.matching.findNearbyProviders(
      Number(lat),
      Number(lng),
      radiusKm ? Number(radiusKm) : undefined,
    );
    const mapped = providers.map((p) => ({
      id: p.id,
      fullName: p.user?.fullName ?? 'Driver',
      avatarUrl: p.user?.avatarUrl ?? null,
      ratingAvg: p.ratingAvg,
      lat: p.currentLat,
      lng: p.currentLng,
      distanceKm: p.distanceKm,
      etaMinutes:
        p.distanceKm != null ? Math.max(1, Math.round((p.distanceKm / 40) * 60)) : null,
    }));
    return successResponse(mapped);
  }

  @Get('services')
  async listServices(@Query('businessType') businessType?: string) {
    const items = await this.prisma.serviceCategory.findMany({
      where: {
        isActive: true,
        ...(businessType === 'parcel' || businessType === 'taxi'
          ? { businessType }
          : {}),
      },
      orderBy: { sortOrder: 'asc' },
    });
    return successResponse(items);
  }
}
