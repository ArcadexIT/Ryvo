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
import {
  IsArray,
  IsIn,
  IsNumber,
  IsOptional,
  IsString,
  IsInt,
  IsUUID,
  Min,
  MinLength,
} from 'class-validator';
import { JwtAuthGuard, RolesGuard } from '../auth/guards';
import { Roles } from '../auth/roles.decorator';
import { UserRole } from '@ryvo/shared';
import { successResponse } from '../common/utils';
import { PaginationDto } from '../common/dto/pagination.dto';
import { ProviderExtraService } from './provider-extra.service';
import { SubscriptionsService } from '../subscriptions/subscriptions.service';
import { SettingsService } from '../settings/settings.service';

class WithdrawDto {
  @IsNumber() amount!: number;
  @IsOptional()
  @IsString()
  bankAccountId?: string;
}

class CreateBankAccountDto {
  @IsString() bankName!: string;
  @IsString() accountHolder!: string;
  @IsString() @MinLength(4) accountNumber!: string;
  @IsOptional() @IsString() routingNumber?: string;
}

class UpsertVehicleDto {
  @IsIn(['car', 'motorcycle']) vehicleType!: string;
  @IsString() make!: string;
  @IsString() model!: string;
  @IsInt() @Min(1900) year!: number;
  @IsString() plateNumber!: string;
  @IsIn(['manual', 'auto']) transmission!: string;
  @IsIn(['petrol', 'diesel', 'electric']) fuelType!: string;
  @IsOptional() @IsString() color?: string;
  @IsOptional() @IsString() engineCapacity?: string;
  @IsOptional() @IsString() photoUrl?: string;
  @IsOptional() @IsArray() @IsString({ each: true }) rideClassSlugs?: string[];
}

class AcceptAgreementDto {
  @IsString() version!: string;
}

type ProviderReq = { user: { id: string; provider?: { id: string } } };

@ApiTags('Provider Wallet & Profile')
@Controller('provider')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.PROVIDER)
@ApiBearerAuth()
export class ProviderExtraController {
  constructor(
    private extra: ProviderExtraService,
    private subscriptions: SubscriptionsService,
    private settings: SettingsService,
  ) {}

  @Get('app-config')
  async appConfig() {
    return successResponse(await this.settings.getProviderAppConfig());
  }

  @Get('subscriptions/plans')
  async subscriptionPlans() {
    return successResponse(await this.subscriptions.listPlans());
  }

  @Get('subscriptions/current')
  async currentSubscription(@Req() req: ProviderReq) {
    return successResponse(await this.subscriptions.getProviderStatus(req.user.provider!.id));
  }

  @Post('subscriptions/purchase')
  async purchaseSubscription(
    @Req() req: ProviderReq,
    @Body() body: { planId: string },
  ) {
    return successResponse(await this.subscriptions.purchase(req.user.provider!.id, body.planId));
  }

  @Get('wallet')
  async wallet(@Req() req: ProviderReq) {
    return successResponse(await this.extra.getWallet(req.user.provider!.id));
  }

  @Post('wallet/withdraw')
  async withdraw(@Req() req: ProviderReq, @Body() dto: WithdrawDto) {
    return successResponse(
      await this.extra.withdraw(
        req.user.provider!.id,
        dto.amount,
        dto.bankAccountId,
      ),
    );
  }

  @Get('payouts')
  async payouts(@Req() req: ProviderReq, @Query() query: PaginationDto) {
    const result = await this.extra.listPayouts(req.user.provider!.id, query);
    return successResponse(result.items, undefined, result.meta);
  }

  @Get('bank-accounts')
  async bankAccounts(@Req() req: ProviderReq) {
    return successResponse(await this.extra.listBankAccounts(req.user.provider!.id));
  }

  @Post('bank-accounts')
  async createBankAccount(@Req() req: ProviderReq, @Body() dto: CreateBankAccountDto) {
    return successResponse(
      await this.extra.createBankAccount(req.user.provider!.id, dto),
    );
  }

  @Patch('bank-accounts/:id/primary')
  async setPrimaryBankAccount(@Req() req: ProviderReq, @Param('id') id: string) {
    return successResponse(
      await this.extra.setPrimaryBankAccount(req.user.provider!.id, id),
    );
  }

  @Delete('bank-accounts/:id')
  async deleteBankAccount(@Req() req: ProviderReq, @Param('id') id: string) {
    return successResponse(
      await this.extra.deleteBankAccount(req.user.provider!.id, id),
    );
  }

  @Get('earnings/weekly')
  async weekly(@Req() req: ProviderReq) {
    return successResponse(await this.extra.getWeeklyEarnings(req.user.provider!.id));
  }

  @Get('earnings/history')
  async earningsHistory(@Req() req: ProviderReq, @Query() query: PaginationDto) {
    const result = await this.extra.listEarnings(req.user.provider!.id, query);
    return successResponse(result.items, undefined, result.meta);
  }

  @Get('transactions/:id')
  async transaction(@Req() req: ProviderReq, @Param('id') id: string) {
    return successResponse(await this.extra.getTransaction(req.user.provider!.id, id));
  }

  @Get('performance')
  async performance(@Req() req: ProviderReq) {
    return successResponse(
      await this.extra.getPerformance(req.user.provider!.id, req.user.id),
    );
  }

  @Get('kyc/status')
  async kycStatus(@Req() req: ProviderReq) {
    return successResponse(await this.extra.getKycStatus(req.user.provider!.id));
  }

  @Get('agreement')
  async getAgreement(@Req() req: ProviderReq) {
    return successResponse(await this.extra.getAgreement(req.user.provider!.id));
  }

  @Post('agreement/accept')
  async acceptAgreement(@Req() req: ProviderReq, @Body() dto: AcceptAgreementDto) {
    return successResponse(
      await this.extra.acceptAgreement(req.user.provider!.id, dto.version),
    );
  }

  @Get('ride-classes')
  async rideClasses() {
    return successResponse(await this.extra.listRideClasses());
  }

  @Get('vehicle')
  async getVehicle(@Req() req: ProviderReq) {
    return successResponse(await this.extra.getVehicle(req.user.provider!.id));
  }

  @Patch('vehicle')
  async upsertVehicle(@Req() req: ProviderReq, @Body() dto: UpsertVehicleDto) {
    return successResponse(await this.extra.upsertVehicle(req.user.provider!.id, dto));
  }

  @Get('faqs')
  async faqs() {
    return successResponse(await this.extra.getFaqs());
  }
}
