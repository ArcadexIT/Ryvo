import {
  Controller,
  Get,
  Post,
  Patch,
  Body,
  Param,
  Query,
  UseGuards,
  Req,
  ForbiddenException,
  BadRequestException,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard, RolesGuard } from '../auth/guards';
import { Roles } from '../auth/roles.decorator';
import { UserRole } from '@ryvo/shared';
import { successResponse, parsePagination, paginateMeta } from '../common/utils';
import { PaginationDto } from '../common/dto/pagination.dto';
import { PrismaService } from '../prisma/prisma.service';
import { MatchingService } from '../matching/matching.service';
import { BiddingService } from '../bidding/bidding.service';
import { SubscriptionsService } from '../subscriptions/subscriptions.service';
import { TrackingService } from '../tracking/tracking.service';
import { RealtimeService } from '../tracking/realtime.service';
import { RedisService } from '../redis/redis.service';
import { CoverageService } from '../ops/coverage.service';
import { AgreementsService } from '../ops/agreements.service';
import { ProvidersService } from '../providers/providers.service';
import { FilesService } from '../files/files.service';
import {
  IsEmail,
  IsEnum,
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Min,
} from 'class-validator';
import { DocumentType, OnlineStatus, Prisma } from '@ryvo/database';
import { providerTravelToPickup } from '../ops/geo';

const PROVIDER_GEO_KEY = 'provider:online';

class UpdateProfileDto {
  @IsOptional() @IsString() fullName?: string;
  @IsOptional() @IsString() businessName?: string;
  @IsOptional() @IsString() avatarUrl?: string;
  @IsOptional() @IsString() bankAccountRef?: string;
  @IsOptional() @IsEmail() email?: string;
}

class OnlineStatusDto {
  @IsEnum(OnlineStatus) status!: OnlineStatus;
}

class LocationDto {
  @IsNumber() lat!: number;
  @IsNumber() lng!: number;
  @IsOptional() @IsUUID() jobId?: string;
}

class UploadDocumentDto {
  @IsEnum(DocumentType) docType!: DocumentType;
  @IsString() fileUrl!: string;
  @IsOptional() @IsUUID() serviceCategoryId?: string;
  @IsOptional() @IsUUID() equipmentRequirementId?: string;
  @IsOptional() @IsString() equipmentLabel?: string;
}

class SubmitBidDto {
  @IsNumber() @Min(0.5) amount!: number;
  @IsIn(['accept', 'counter']) kind!: 'accept' | 'counter';
  @IsOptional() @IsString() message?: string;
}

@ApiTags('Provider API')
@Controller('provider')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.PROVIDER)
@ApiBearerAuth()
export class ProviderApiController {
  constructor(
    private prisma: PrismaService,
    private matching: MatchingService,
    private tracking: TrackingService,
    private realtime: RealtimeService,
    private redis: RedisService,
    private coverage: CoverageService,
    private agreements: AgreementsService,
    private providers: ProvidersService,
    private files: FilesService,
    private bidding: BiddingService,
    private subscriptions: SubscriptionsService,
  ) {}

  @Get('profile')
  async profile(@Req() req: { user: { id: string; provider?: { id: string } } }) {
    const provider = await this.prisma.provider.findUnique({
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
        documents: true,
        vehicles: true,
        availability: true,
        serviceAreas: true,
      },
    });
    return successResponse(provider);
  }

  @Patch('profile')
  async updateProfile(
    @Req() req: { user: { id: string; provider?: { id: string } } },
    @Body() dto: UpdateProfileDto,
  ) {
    const { businessName, bankAccountRef, email, ...userFields } = dto;
    const userData: { fullName?: string; avatarUrl?: string; email?: string } = { ...userFields };
    const nextEmail = email?.trim();
    if (nextEmail) {
      const current = await this.prisma.user.findUnique({
        where: { id: req.user.id },
        select: { email: true },
      });
      if (!current?.email?.trim()) userData.email = nextEmail;
    }
    if (Object.keys(userData).length) {
      try {
        await this.prisma.user.update({ where: { id: req.user.id }, data: userData });
      } catch (error) {
        if (error instanceof Prisma.PrismaClientKnownRequestError && error.code === 'P2002') {
          throw new BadRequestException('That email is already in use.');
        }
        throw error;
      }
    }
    const provider = await this.prisma.provider.update({
      where: { id: req.user.provider!.id },
      data: { businessName, bankAccountRef },
      include: { user: { select: { fullName: true, avatarUrl: true } } },
    });
    return successResponse(provider);
  }

  @Get('documents')
  async documents(@Req() req: { user: { provider?: { id: string } } }) {
    const items = await this.prisma.providerDocument.findMany({
      where: { providerId: req.user.provider!.id },
      orderBy: { createdAt: 'desc' },
    });
    return successResponse(items);
  }

  /**
   * Identity, license, registration, and insurance are one file per type.
   * A new upload replaces that file. Equipment photos can stack.
   */
  private async saveDocument(
    providerId: string,
    dto: UploadDocumentDto,
  ) {
    if (dto.docType === DocumentType.equipment_proof) {
      return this.prisma.providerDocument.create({
        data: { providerId, ...dto, status: 'pending' },
      });
    }

    const existing = await this.prisma.providerDocument.findMany({
      where: { providerId, docType: dto.docType },
      orderBy: { createdAt: 'desc' },
    });

    if (!existing.length) {
      return this.prisma.providerDocument.create({
        data: { providerId, ...dto, status: 'pending' },
      });
    }

    const [current, ...older] = existing;
    const doc = await this.prisma.providerDocument.update({
      where: { id: current.id },
      data: {
        fileUrl: dto.fileUrl,
        status: 'pending',
        reviewedById: null,
        reviewedAt: null,
        rejectionReason: null,
      },
    });

    if (older.length) {
      await this.prisma.providerDocument.deleteMany({
        where: { id: { in: older.map((row) => row.id) } },
      });
    }

    const staleUrls = existing
      .map((row) => row.fileUrl)
      .filter((url) => url && url !== dto.fileUrl);
    await Promise.all(staleUrls.map((url) => this.files.deleteStoredFile(url)));
    return doc;
  }

  @Post('documents')
  async uploadDocument(
    @Req() req: { user: { id: string; provider?: { id: string } } },
    @Body() dto: UploadDocumentDto,
  ) {
    const providerId = req.user.provider!.id;
    const doc = await this.saveDocument(providerId, dto);

    if (dto.docType === DocumentType.selfie) {
      await this.prisma.user.update({
        where: { id: req.user.id },
        data: { avatarUrl: dto.fileUrl },
      });
    }

    await this.providers.refreshVerificationStatus(providerId);
    return successResponse(doc);
  }

  @Patch('status')
  async setOnlineStatus(
    @Req() req: { user: { provider?: { id: string } } },
    @Body() dto: OnlineStatusDto,
  ) {
    const providerId = req.user.provider!.id;
    const current = await this.prisma.provider.findUnique({
      where: { id: providerId },
    });
    if (!current) {
      throw new ForbiddenException('Driver profile not found');
    }
    const client = this.redis.getClient();

    if (dto.status === 'online') {
      if (current.verificationStatus !== 'approved') {
        throw new ForbiddenException(
          current.verificationStatus === 'rejected'
            ? 'Your onboarding was rejected. You cannot go online.'
            : current.verificationStatus === 'suspended'
              ? 'Your account is suspended. You cannot go online.'
              : 'Complete onboarding and wait for approval before going online.',
        );
      }
      await this.agreements.assertCurrent(providerId);
      await this.subscriptions.assertCanGoOnline(providerId);
      const vehicle = await this.prisma.providerVehicle.findFirst({
        where: { providerId },
        orderBy: { createdAt: 'desc' },
      });
      if (!vehicle) {
        throw new ForbiddenException('Add your vehicle details before going online.');
      }
      const classes = Array.isArray(vehicle.serviceCapabilities)
        ? vehicle.serviceCapabilities.map((value) => String(value))
        : [];
      const activeClasses = classes.length
        ? await this.prisma.serviceCategory.count({
            where: { isActive: true, slug: { in: classes } },
          })
        : 0;
      if (activeClasses === 0) {
        throw new ForbiddenException('Choose at least one ride class before going online.');
      }
      if (current.currentLat != null && current.currentLng != null) {
        const area = await this.coverage.check(Number(current.currentLat), Number(current.currentLng), 'provider');
        if (!area.inside) {
          await this.prisma.provider.update({ where: { id: providerId }, data: { onlineStatus: 'offline' } });
          await client.zrem(PROVIDER_GEO_KEY, providerId);
          throw new ForbiddenException(
            `OUT_OF_AREA: ${area.message ?? 'RYVO is unavailable in the current area'}`,
          );
        }
      }
    }

    const provider = await this.prisma.provider.update({
      where: { id: providerId },
      data: { onlineStatus: dto.status },
    });

    if (dto.status === 'online' && provider.currentLat && provider.currentLng) {
      await client.geoadd(
        PROVIDER_GEO_KEY,
        Number(provider.currentLng),
        Number(provider.currentLat),
        providerId,
      );
    } else if (dto.status === 'offline') {
      await client.zrem(PROVIDER_GEO_KEY, providerId);
    }

    return successResponse(provider);
  }

  @Patch('location')
  async updateLocation(
    @Req() req: { user: { provider?: { id: string } } },
    @Body() dto: LocationDto,
  ) {
    const providerId = req.user.provider!.id;
    const area = await this.coverage.check(dto.lat, dto.lng, 'provider');
    let forcedOffline = false;
    if (!area.inside) {
      const current = await this.prisma.provider.findUnique({
        where: { id: providerId },
        select: { onlineStatus: true },
      });
      if (current?.onlineStatus === 'online' || current?.onlineStatus === 'busy') {
        await this.prisma.provider.update({
          where: { id: providerId },
          data: { onlineStatus: 'offline' },
        });
        await this.redis.getClient().zrem(PROVIDER_GEO_KEY, providerId);
        forcedOffline = true;
      }
    }
    const result = await this.tracking.updateProviderLocation(
      providerId,
      dto.lat,
      dto.lng,
      dto.jobId,
    );
    if (forcedOffline) {
      return successResponse({ ...result, forcedOffline: true, message: area.message });
    }
    if (dto.jobId) {
      this.realtime.emitToJob(dto.jobId, 'job:location', result);
    }
    return successResponse(result);
  }

  @Get('offers')
  async pendingOffers(@Req() req: { user: { provider?: { id: string } } }) {
    const providerId = req.user.provider!.id;
    const [offers, provider] = await Promise.all([
      this.prisma.jobOffer.findMany({
        where: {
          providerId,
          status: 'sent',
          expiresAt: { gt: new Date() },
          job: { status: 'searching' },
        },
        orderBy: { offeredAt: 'desc' },
        include: {
          job: {
            include: {
              serviceCategory: true,
              vehicle: true,
              customer: { include: { user: { select: { fullName: true } } } },
            },
          },
        },
      }),
      this.prisma.provider.findUnique({
        where: { id: providerId },
        select: { currentLat: true, currentLng: true },
      }),
    ]);
    return successResponse(
      offers.map((offer) => {
        const travel = providerTravelToPickup(
          provider?.currentLat,
          provider?.currentLng,
          offer.job.pickupLat,
          offer.job.pickupLng,
        );
        return {
          ...offer,
          job: {
            ...offer.job,
            providerDistanceKm: travel?.providerDistanceKm ?? null,
            etaMinutes: travel?.etaMinutes ?? null,
            distanceKm: travel?.providerDistanceKm ?? offer.job.distanceKm,
          },
        };
      }),
    );
  }

  @Post('offers/:offerId/accept')
  async acceptOffer(
    @Req() req: { user: { provider?: { id: string } } },
    @Param('offerId') offerId: string,
  ) {
    return successResponse(
      await this.matching.acceptOffer(offerId, req.user.provider!.id),
    );
  }

  @Post('offers/:offerId/reject')
  async rejectOffer(
    @Req() req: { user: { provider?: { id: string } } },
    @Param('offerId') offerId: string,
  ) {
    return successResponse(
      await this.matching.rejectOffer(offerId, req.user.provider!.id),
    );
  }

  @Get('bids/open')
  async openBids(@Req() req: { user: { provider?: { id: string } } }) {
    return successResponse(await this.bidding.listOpenBidJobs(req.user.provider!.id));
  }

  @Post('jobs/:jobId/bids')
  async submitBid(
    @Req() req: { user: { provider?: { id: string } } },
    @Param('jobId') jobId: string,
    @Body() dto: SubmitBidDto,
  ) {
    return successResponse(
      await this.bidding.submitBid(req.user.provider!.id, jobId, dto),
    );
  }

  @Get('earnings')
  async earnings(
    @Req() req: { user: { provider?: { id: string } } },
    @Query() query: PaginationDto,
  ) {
    const { page, limit, skip } = parsePagination(query);
    const providerId = req.user.provider!.id;

    const [items, total] = await Promise.all([
      this.prisma.providerEarning.findMany({
        where: { providerId },
        skip,
        take: limit,
        orderBy: { createdAt: 'desc' },
        include: { job: { select: { jobNumber: true, completedAt: true } } },
      }),
      this.prisma.providerEarning.count({ where: { providerId } }),
    ]);

    return successResponse(items, undefined, paginateMeta(page, limit, total));
  }
}
