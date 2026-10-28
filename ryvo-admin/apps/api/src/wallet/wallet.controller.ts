import { Controller, Get, Post, Body, Query, Param, UseGuards, Req } from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { WalletService } from './wallet.service';
import { JwtAuthGuard, RolesGuard } from '../auth/guards';
import { Roles } from '../auth/roles.decorator';
import { UserRole } from '@ryvo/shared';
import { successResponse } from '../common/utils';
import { PaginationDto } from '../common/dto/pagination.dto';
import { AuditService } from '../audit/audit.service';
import { IsNumber, IsOptional, IsString, IsUUID, Min } from 'class-validator';

class TopUpDto {
  @IsNumber() @Min(0.01) amount!: number;
  @IsOptional() @IsString() description?: string;
}

class AdminAdjustDto {
  @IsUUID() userId!: string;
  @IsNumber() amount!: number;
  @IsOptional() @IsString() description?: string;
}

@ApiTags('Customer Wallet')
@Controller('customer/wallet')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.CUSTOMER)
@ApiBearerAuth()
export class CustomerWalletController {
  constructor(private wallet: WalletService) {}

  @Get('balance')
  async balance(@Req() req: { user: { id: string } }) {
    return successResponse(await this.wallet.getBalance(req.user.id));
  }

  @Get('transactions')
  async transactions(@Req() req: { user: { id: string } }, @Query() query: PaginationDto) {
    const result = await this.wallet.getTransactions(req.user.id, query);
    return successResponse(result.items, undefined, result.meta);
  }

  @Post('top-up')
  async topUp(@Req() req: { user: { id: string } }, @Body() dto: TopUpDto) {
    return successResponse(await this.wallet.topUp(req.user.id, dto.amount, dto.description));
  }
}

@ApiTags('Admin Wallet')
@Controller('admin/wallet')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN)
@ApiBearerAuth()
export class AdminWalletController {
  constructor(
    private wallet: WalletService,
    private audit: AuditService,
  ) {}

  @Get('lookup')
  async lookup(@Query('q') q: string) {
    return successResponse(await this.wallet.lookupUser(q));
  }

  @Get('user/:userId/balance')
  async balance(@Param('userId') userId: string) {
    return successResponse(await this.wallet.getAdminBalanceView(userId));
  }

  @Get('user/:userId/transactions')
  async transactions(@Param('userId') userId: string, @Query() query: PaginationDto) {
    await this.wallet.findUserById(userId);
    const result = await this.wallet.getTransactions(userId, query, { bypassFeatureFlag: true });
    return successResponse(result.items, undefined, result.meta);
  }

  @Post('adjust')
  async adjust(
    @Body() dto: AdminAdjustDto,
    @Req() req: { user: { adminUser?: { id: string } } },
  ) {
    const result = await this.wallet.adminAdjust(
      dto.userId,
      dto.amount,
      dto.description,
      req.user.adminUser?.id,
    );
    if (req.user.adminUser) {
      await this.audit.log({
        adminId: req.user.adminUser.id,
        action: 'wallet_adjust',
        entityType: 'wallet',
        entityId: dto.userId,
        newValues: dto,
      });
    }
    return successResponse(result);
  }
}
