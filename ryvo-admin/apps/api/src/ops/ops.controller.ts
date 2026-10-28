import { Body, Controller, Get, Param, Patch, Post, Req, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiTags } from '@nestjs/swagger';
import { IsArray, IsBoolean, IsIn, IsNumber, IsOptional, IsString, ValidateNested } from 'class-validator';
import { Type } from 'class-transformer';
import { JwtAuthGuard, RolesGuard } from '../auth/guards';
import { Roles } from '../auth/roles.decorator';
import { UserRole } from '@ryvo/shared';
import { successResponse } from '../common/utils';
import { CoverageService } from './coverage.service';
import { TrainingService } from './training.service';
import { AgreementsService } from './agreements.service';
import { BillingOpsService } from './billing-ops.service';
import { AgreementKey, ZoneAudience } from '@ryvo/database';
import { PrismaService } from '../prisma/prisma.service';

class CoverageCheckDto {
  @IsNumber() lat!: number;
  @IsNumber() lng!: number;
}

class CoverageNotifyDto extends CoverageCheckDto {
  @IsOptional() @IsString() addressLabel?: string;
}

class AnswerDto {
  @IsString() questionId!: string;
  @IsString() optionId!: string;
}

class SubmitTrainingDto {
  @IsArray() @ValidateNested({ each: true }) @Type(() => AnswerDto) answers!: AnswerDto[];
}

class AcceptAgreementDto {
  @IsIn(['service', 'tax_status', 'insurance']) key!: AgreementKey;
  @IsString() version!: string;
  @IsOptional() @IsString() appVersion?: string;
}

class ZoneDto {
  @IsOptional() @IsString() id?: string;
  @IsString() name!: string;
  @IsIn(['customer', 'provider', 'both']) audience!: ZoneAudience;
  @IsNumber() centerLat!: number;
  @IsNumber() centerLng!: number;
  @IsNumber() radiusKm!: number;
  @IsOptional() @IsBoolean() isActive?: boolean;
}

class PublishAgreementDto {
  @IsIn(['service', 'tax_status', 'insurance']) key!: AgreementKey;
  @IsString() version!: string;
  @IsString() title!: string;
  @IsString() body!: string;
  @IsArray()
  @IsString({ each: true })
  acknowledgements!: string[];
}

class LookupDto {
  @IsString() registration!: string;
}

class TrainingBlockDto {
  @IsIn(['text', 'image', 'video']) type!: 'text' | 'image' | 'video';
  @IsString() body!: string;
  @IsOptional() @IsString() caption?: string;
}

class TrainingOptionDto {
  @IsString() label!: string;
  @IsBoolean() isCorrect!: boolean;
}

class TrainingQuestionDto {
  @IsString() prompt!: string;
  @IsArray() @ValidateNested({ each: true }) @Type(() => TrainingOptionDto) options!: TrainingOptionDto[];
}

class SaveTrainingDto {
  @IsOptional() @IsString() id?: string;
  @IsString() title!: string;
  @IsNumber() passPercent!: number;
  @IsOptional() @IsString() serviceCategoryId?: string | null;
  @IsOptional() @IsBoolean() isActive?: boolean;
  @IsArray() @ValidateNested({ each: true }) @Type(() => TrainingBlockDto) blocks!: TrainingBlockDto[];
  @IsArray() @ValidateNested({ each: true }) @Type(() => TrainingQuestionDto) questions!: TrainingQuestionDto[];
}

class SaveEquipmentDto {
  @IsOptional() @IsString() id?: string;
  @IsString() serviceCategoryId!: string;
  @IsString() label!: string;
  @IsOptional() @IsNumber() sortOrder?: number;
  @IsOptional() @IsBoolean() isActive?: boolean;
}

class ConnectLinkDto {
  @IsString() refreshUrl!: string;
  @IsString() returnUrl!: string;
}

type AppReq = { user: { id: string; customer?: { id: string }; provider?: { id: string } } };

@ApiTags('Coverage')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard, RolesGuard)
@Controller()
export class OpsController {
  constructor(
    private coverage: CoverageService,
    private training: TrainingService,
    private agreements: AgreementsService,
    private billing: BillingOpsService,
    private prisma: PrismaService,
  ) {}

  @Post('customer/coverage/check')
  @Roles(UserRole.CUSTOMER)
  async customerCheck(@Body() dto: CoverageCheckDto) {
    return successResponse(await this.coverage.check(dto.lat, dto.lng, 'customer'));
  }

  @Post('customer/coverage/notify')
  @Roles(UserRole.CUSTOMER)
  async customerNotify(@Req() req: AppReq, @Body() dto: CoverageNotifyDto) {
    return successResponse(await this.coverage.notify(req.user.id, 'customer', dto.lat, dto.lng, dto.addressLabel));
  }

  @Get('customer/invoices')
  @Roles(UserRole.CUSTOMER)
  async customerInvoices(@Req() req: AppReq) {
    return successResponse(await this.billing.listForCustomer(req.user.customer!.id));
  }

  @Get('customer/invoices/:id')
  @Roles(UserRole.CUSTOMER)
  async customerInvoice(@Req() req: AppReq, @Param('id') id: string) {
    return successResponse(await this.billing.getForCustomer(req.user.customer!.id, id));
  }

  @Post('vehicle-lookup')
  @Roles(UserRole.CUSTOMER, UserRole.PROVIDER)
  async lookup(@Body() dto: LookupDto) {
    return successResponse(await this.billing.lookupVehicle(dto.registration));
  }

  @Post('provider/coverage/check')
  @Roles(UserRole.PROVIDER)
  async providerCheck(@Body() dto: CoverageCheckDto) {
    return successResponse(await this.coverage.check(dto.lat, dto.lng, 'provider'));
  }

  @Post('provider/coverage/notify')
  @Roles(UserRole.PROVIDER)
  async providerNotify(@Req() req: AppReq, @Body() dto: CoverageNotifyDto) {
    return successResponse(await this.coverage.notify(req.user.id, 'provider', dto.lat, dto.lng, dto.addressLabel));
  }

  @Get('provider/training')
  @Roles(UserRole.PROVIDER)
  async trainingList(@Req() req: AppReq) {
    return successResponse(await this.training.listForProvider(req.user.provider!.id));
  }

  @Get('provider/training/:id')
  @Roles(UserRole.PROVIDER)
  async trainingOne(@Param('id') id: string) {
    return successResponse(await this.training.getProgram(id));
  }

  @Post('provider/training/:id/submit')
  @Roles(UserRole.PROVIDER)
  async trainingSubmit(@Req() req: AppReq, @Param('id') id: string, @Body() dto: SubmitTrainingDto) {
    return successResponse(await this.training.submit(req.user.provider!.id, id, dto.answers));
  }

  @Get('provider/equipment-requirements')
  @Roles(UserRole.PROVIDER)
  async equipment(@Req() req: AppReq) {
    const providerId = req.user.provider!.id;
    const [rows, docs] = await Promise.all([
      this.prisma.equipmentRequirement.findMany({
        where: { isActive: true },
        orderBy: [{ serviceCategoryId: 'asc' }, { sortOrder: 'asc' }],
        include: { serviceCategory: { select: { id: true, name: true, slug: true } } },
      }),
      this.prisma.providerDocument.findMany({
        where: { providerId, docType: 'equipment_proof' },
        orderBy: { createdAt: 'desc' },
        select: {
          id: true,
          status: true,
          fileUrl: true,
          rejectionReason: true,
          equipmentRequirementId: true,
          equipmentLabel: true,
          createdAt: true,
        },
      }),
    ]);

    const latestByRequirement = new Map<string, (typeof docs)[number]>();
    const latestByLabel = new Map<string, (typeof docs)[number]>();
    for (const doc of docs) {
      if (doc.equipmentRequirementId && !latestByRequirement.has(doc.equipmentRequirementId)) {
        latestByRequirement.set(doc.equipmentRequirementId, doc);
      }
      const label = doc.equipmentLabel?.trim().toLowerCase();
      if (label && !doc.equipmentRequirementId && !latestByLabel.has(label)) {
        latestByLabel.set(label, doc);
      }
    }

    const usedDocIds = new Set<string>();
    const data = rows.map((row) => {
      const byId = latestByRequirement.get(row.id);
      const byLabel = latestByLabel.get(row.label.trim().toLowerCase());
      const proof = byId ?? (byLabel && !usedDocIds.has(byLabel.id) ? byLabel : null);
      if (proof) usedDocIds.add(proof.id);
      return {
        ...row,
        status: proof?.status ?? null,
        fileUrl: proof?.fileUrl ?? null,
        rejectionReason: proof?.rejectionReason ?? null,
        document: proof
          ? {
              id: proof.id,
              status: proof.status,
              fileUrl: proof.fileUrl,
              rejectionReason: proof.rejectionReason,
              createdAt: proof.createdAt,
            }
          : null,
      };
    });

    return successResponse(data);
  }

  @Get('provider/agreements')
  @Roles(UserRole.PROVIDER)
  async agreementsFor(@Req() req: AppReq) {
    return successResponse(await this.agreements.statusForProvider(req.user.provider!.id));
  }

  @Post('provider/agreements/accept')
  @Roles(UserRole.PROVIDER)
  async accept(@Req() req: AppReq, @Body() dto: AcceptAgreementDto) {
    return successResponse(
      await this.agreements.accept(req.user.provider!.id, dto.key, dto.version, dto.appVersion),
    );
  }

  @Post('provider/stripe/account-link')
  @Roles(UserRole.PROVIDER)
  async connectLink(@Req() req: AppReq, @Body() dto: ConnectLinkDto) {
    return successResponse(await this.billing.createConnectLink(req.user.provider!.id, dto.refreshUrl, dto.returnUrl));
  }

  @Get('provider/stripe/status')
  @Roles(UserRole.PROVIDER)
  async connectStatus(@Req() req: AppReq) {
    return successResponse(await this.billing.connectStatus(req.user.provider!.id));
  }

  @Get('admin/zones')
  @Roles(UserRole.ADMIN)
  async zones() {
    return successResponse(await this.coverage.listZones());
  }

  @Post('admin/zones')
  @Roles(UserRole.ADMIN)
  async saveZone(@Body() dto: ZoneDto) {
    return successResponse(await this.coverage.upsertZone(dto));
  }

  @Get('admin/coverage-interests')
  @Roles(UserRole.ADMIN)
  async interests() {
    return successResponse(await this.coverage.listInterests());
  }

  @Get('admin/training')
  @Roles(UserRole.ADMIN)
  async adminTraining() {
    const [programs, categories, equipment] = await Promise.all([
      this.prisma.trainingProgram.findMany({
        include: {
          serviceCategory: { select: { id: true, name: true } },
          blocks: { orderBy: { sortOrder: 'asc' } },
          questions: { include: { options: true }, orderBy: { sortOrder: 'asc' } },
        },
        orderBy: { title: 'asc' },
      }),
      this.prisma.serviceCategory.findMany({
        where: { isActive: true },
        select: { id: true, name: true, slug: true },
        orderBy: { name: 'asc' },
      }),
      this.prisma.equipmentRequirement.findMany({
        orderBy: [{ serviceCategoryId: 'asc' }, { sortOrder: 'asc' }],
        include: { serviceCategory: { select: { name: true } } },
      }),
    ]);
    return successResponse({ programs, categories, equipment });
  }

  @Post('admin/training')
  @Roles(UserRole.ADMIN)
  async saveTraining(@Body() dto: SaveTrainingDto) {
    return successResponse(await this.training.saveProgram(dto));
  }

  @Post('admin/equipment')
  @Roles(UserRole.ADMIN)
  async saveEquipment(@Body() dto: SaveEquipmentDto) {
    return successResponse(await this.training.saveEquipment(dto));
  }

  @Get('admin/invoices')
  @Roles(UserRole.ADMIN)
  async invoices() {
    return successResponse(await this.billing.listAll());
  }

  @Get('admin/providers/:id/agreements')
  @Roles(UserRole.ADMIN)
  async providerAgreements(@Param('id') id: string) {
    return successResponse(await this.agreements.adminView(id));
  }

  @Get('admin/agreements')
  @Roles(UserRole.ADMIN)
  async listAgreements() {
    return successResponse(await this.agreements.currentDocuments());
  }

  @Post('admin/agreements')
  @Roles(UserRole.ADMIN)
  async publish(@Body() dto: PublishAgreementDto) {
    return successResponse(await this.agreements.publish(dto));
  }

  @Patch('admin/providers/:id/insurance-proof')
  @Roles(UserRole.ADMIN)
  async requestProof(@Param('id') id: string) {
    const provider = await this.prisma.provider.update({
      where: { id },
      data: { insuranceProofStatus: 'requested', insuranceProofRequestedAt: new Date() },
    });
    return successResponse(provider);
  }
}
