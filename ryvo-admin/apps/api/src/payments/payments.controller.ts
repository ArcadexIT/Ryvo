import {
  Controller,
  Get,
  Post,
  Param,
  Body,
  Query,
  UseGuards,
  Req,
  Headers,
  RawBodyRequest,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { PaymentsService } from './payments.service';
import { JwtAuthGuard, RolesGuard } from '../auth/guards';
import { Roles } from '../auth/roles.decorator';
import { UserRole } from '@ryvo/shared';
import { successResponse } from '../common/utils';
import { PaginationDto } from '../common/dto/pagination.dto';
import { IsEnum, IsNumber, IsOptional, IsString, IsUUID, Min } from 'class-validator';
import { PaymentMethod, PaymentStatus } from '@ryvo/database';
import { Request } from 'express';

class PaymentFiltersDto extends PaginationDto {
  @IsOptional() @IsEnum(PaymentStatus) status?: PaymentStatus;
  @IsOptional() @IsEnum(PaymentMethod) method?: PaymentMethod;
}

class CreatePaymentIntentDto {
  @IsUUID() jobId!: string;
  @IsNumber() @Min(0.01) amount!: number;
  @IsOptional() @IsString() currency?: string;
}

class ConfirmPaymentDto {
  @IsOptional() @IsString() paymentIntentId?: string;
}

class RefundDto {
  @IsOptional() @IsNumber() @Min(0.01) amount?: number;
  @IsOptional() @IsString() reason?: string;
}

@ApiTags('Admin Payments')
@Controller('admin/payments')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN)
@ApiBearerAuth()
export class AdminPaymentsController {
  constructor(private payments: PaymentsService) {}

  @Get()
  async list(@Query() query: PaymentFiltersDto) {
    const result = await this.payments.findAll(query);
    return successResponse(result.items, undefined, result.meta);
  }

  @Get('job/:jobId')
  async byJob(@Param('jobId') jobId: string) {
    return successResponse(await this.payments.findByJob(jobId));
  }

  @Post('job/:jobId/refund')
  async refund(@Param('jobId') jobId: string, @Body() dto: RefundDto) {
    return successResponse(await this.payments.refund(jobId, dto.amount, dto.reason));
  }

  @Post('job/:jobId/retry')
  async retry(@Param('jobId') jobId: string) {
    return successResponse(await this.payments.chargeForCompletedJob(jobId));
  }
}

@ApiTags('Customer Payments')
@Controller('customer/payments')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.CUSTOMER)
@ApiBearerAuth()
export class CustomerPaymentsController {
  constructor(private payments: PaymentsService) {}

  @Post('setup-intent')
  async setupIntent(@Req() req: { user: { id: string } }) {
    return successResponse(await this.payments.createSetupIntent(req.user.id));
  }

  @Post('intent')
  async createIntent(
    @Req() req: { user: { id: string } },
    @Body() dto: CreatePaymentIntentDto,
  ) {
    return successResponse(
      await this.payments.createPaymentIntent(dto.jobId, dto.amount, req.user.id),
    );
  }

  @Post('job/:jobId/confirm')
  async confirm(@Param('jobId') jobId: string, @Body() dto: ConfirmPaymentDto) {
    return successResponse(await this.payments.confirmPayment(jobId, dto.paymentIntentId));
  }

  @Get('job/:jobId')
  async byJob(@Param('jobId') jobId: string) {
    return successResponse(await this.payments.findByJob(jobId));
  }

  @Post('job/:jobId/wallet')
  async payWithWallet(
    @Req() req: { user: { id: string } },
    @Param('jobId') jobId: string,
  ) {
    return successResponse(await this.payments.payWithWallet(jobId, req.user.id));
  }

  @Post('job/:jobId/cash')
  async payWithCash(
    @Req() req: { user: { id: string } },
    @Param('jobId') jobId: string,
  ) {
    return successResponse(await this.payments.payWithCash(jobId, req.user.id));
  }
}

@ApiTags('Stripe Webhooks')
@Controller('webhooks/stripe')
export class StripeWebhookController {
  constructor(private payments: PaymentsService) {}

  @Post()
  async handleWebhook(
    @Req() req: RawBodyRequest<Request>,
    @Headers('stripe-signature') signature: string,
  ) {
    const rawBody = req.rawBody;
    if (!rawBody) {
      return { success: false, message: 'Missing raw body' };
    }
    return successResponse(await this.payments.handleStripeWebhook(rawBody, signature));
  }
}
