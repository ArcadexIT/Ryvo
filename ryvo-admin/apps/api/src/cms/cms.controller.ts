import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Param,
  Body,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiBearerAuth } from '@nestjs/swagger';
import { CmsService } from './cms.service';
import { JwtAuthGuard, RolesGuard } from '../auth/guards';
import { Roles } from '../auth/roles.decorator';
import { UserRole } from '@ryvo/shared';
import { successResponse } from '../common/utils';
import { IsBoolean, IsInt, IsOptional, IsString, MinLength } from 'class-validator';

class BannerDto {
  @IsString() title!: string;
  @IsString() imageUrl!: string;
  @IsOptional() @IsString() link?: string;
  @IsOptional() @IsString() targetApp?: string;
  @IsOptional() @IsBoolean() isActive?: boolean;
  @IsOptional() @IsInt() sortOrder?: number;
}

class FaqDto {
  @IsString() question!: string;
  @IsString() answer!: string;
  @IsOptional() @IsString() category?: string;
  @IsOptional() @IsBoolean() isActive?: boolean;
  @IsOptional() @IsInt() sortOrder?: number;
}

class LegalDocumentDto {
  @IsString()
  @MinLength(1)
  title!: string;

  @IsString()
  @MinLength(1)
  content!: string;
}

@ApiTags('Admin CMS')
@Controller('admin/cms')
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles(UserRole.ADMIN)
@ApiBearerAuth()
export class AdminCmsController {
  constructor(private cms: CmsService) {}

  @Get('banners')
  async listBanners() {
    return successResponse(await this.cms.listBanners());
  }

  @Post('banners')
  async createBanner(@Body() dto: BannerDto) {
    return successResponse(await this.cms.createBanner(dto));
  }

  @Patch('banners/:id')
  async updateBanner(@Param('id') id: string, @Body() dto: BannerDto) {
    return successResponse(await this.cms.updateBanner(id, dto));
  }

  @Delete('banners/:id')
  async deleteBanner(@Param('id') id: string) {
    return successResponse(await this.cms.deleteBanner(id));
  }

  @Get('faqs')
  async listFaqs() {
    return successResponse(await this.cms.listFaqs());
  }

  @Post('faqs')
  async createFaq(@Body() dto: FaqDto) {
    return successResponse(await this.cms.createFaq(dto));
  }

  @Patch('faqs/:id')
  async updateFaq(@Param('id') id: string, @Body() dto: FaqDto) {
    return successResponse(await this.cms.updateFaq(id, dto));
  }

  @Delete('faqs/:id')
  async deleteFaq(@Param('id') id: string) {
    return successResponse(await this.cms.deleteFaq(id));
  }

  @Get('legal')
  async listLegal() {
    return successResponse(await this.cms.listLegal());
  }

  @Patch('legal/:key')
  async updateLegal(@Param('key') key: string, @Body() dto: LegalDocumentDto) {
    return successResponse(await this.cms.updateLegal(key, dto));
  }
}

@ApiTags('Public CMS')
@Controller('customer/cms')
export class PublicCmsController {
  constructor(private cms: CmsService) {}

  @Get('banners')
  async banners(@Query('targetApp') targetApp?: string) {
    return successResponse(await this.cms.listBanners(true, targetApp ?? 'customer'));
  }

  @Get('faqs')
  async faqs(@Query('category') category?: string) {
    return successResponse(await this.cms.listFaqs(true, category));
  }
}

@ApiTags('Public Legal')
@Controller('legal')
export class PublicLegalController {
  constructor(private cms: CmsService) {}

  @Get()
  async list() {
    return successResponse(await this.cms.listLegal());
  }

  @Get(':key')
  async get(@Param('key') key: string) {
    return successResponse(await this.cms.getLegal(key));
  }
}
