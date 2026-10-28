import {
  Controller,
  Post,
  Body,
  UseGuards,
  UseInterceptors,
  UploadedFile,
  ParseFilePipe,
  MaxFileSizeValidator,
  FileTypeValidator,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiTags, ApiBearerAuth, ApiConsumes, ApiBody } from '@nestjs/swagger';
import { IsInt, IsOptional, IsString, Max, Min } from 'class-validator';
import { FilesService } from './files.service';
import { JwtAuthGuard, RolesGuard } from '../auth/guards';
import { Roles } from '../auth/roles.decorator';
import { UserRole } from '@ryvo/shared';
import { successResponse } from '../common/utils';

class PresignDto {
  @IsString() folder!: string;
  @IsString() filename!: string;
  @IsString() contentType!: string;
}

class AccessUrlDto {
  @IsString() fileUrl!: string;
  @IsOptional() @IsInt() @Min(60) @Max(86400) expiresIn?: number;
}

class UploadFolderDto {
  @IsString() folder!: string;
}

const MAX_FILE_BYTES = 10 * 1024 * 1024; // 10 MB

interface UploadedFilePayload {
  buffer: Buffer;
  originalname: string;
  mimetype: string;
}

@ApiTags('Files')
@Controller()
export class FilesController {
  constructor(private files: FilesService) {}

  @Post('admin/files/presign')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  presignAdmin(@Body() dto: PresignDto) {
    return this.files.getUploadUrl(dto.folder, dto.filename, dto.contentType).then(successResponse);
  }

  @Post('admin/files/upload')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  @UseInterceptors(FileInterceptor('file'))
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        folder: { type: 'string' },
        file: { type: 'string', format: 'binary' },
      },
    },
  })
  async uploadAdmin(
    @Body() dto: UploadFolderDto,
    @UploadedFile(
      new ParseFilePipe({
        validators: [
          new MaxFileSizeValidator({ maxSize: MAX_FILE_BYTES }),
          new FileTypeValidator({
            fileType: /(image\/(jpeg|jpg|png|webp|heic|heif)|application\/(pdf|octet-stream))/,
            skipMagicNumbersValidation: true,
          }),
        ],
      }),
    )
    file: UploadedFilePayload,
  ) {
    const result = await this.files.uploadBuffer(
      `admin/${dto.folder}`,
      file.originalname,
      normalizeUploadMime(file.mimetype, file.originalname),
      file.buffer,
    );
    return successResponse(result);
  }

  @Post('admin/files/access-url')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  async accessUrlAdmin(@Body() dto: AccessUrlDto) {
    const url = await this.files.resolveAccessUrl(dto.fileUrl, dto.expiresIn ?? 3600);
    return successResponse({ url });
  }

  @Post('admin/files/s3-test')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.ADMIN)
  async s3TestAdmin() {
    return successResponse(await this.files.testConnection());
  }

  @Post('customer/files/presign')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.CUSTOMER)
  presignCustomer(@Body() dto: PresignDto) {
    return this.files.getUploadUrl(`customers/${dto.folder}`, dto.filename, dto.contentType).then(successResponse);
  }

  @Post('customer/files/access-url')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.CUSTOMER)
  async accessUrlCustomer(@Body() dto: AccessUrlDto) {
    const url = await this.files.resolveAccessUrl(dto.fileUrl, dto.expiresIn ?? 3600);
    return successResponse({ url });
  }

  @Post('customer/files/upload')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.CUSTOMER)
  @UseInterceptors(FileInterceptor('file'))
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        folder: { type: 'string' },
        file: { type: 'string', format: 'binary' },
      },
    },
  })
  async uploadCustomer(
    @Body() dto: UploadFolderDto,
    @UploadedFile(
      new ParseFilePipe({
        validators: [
          new MaxFileSizeValidator({ maxSize: MAX_FILE_BYTES }),
          new FileTypeValidator({
            fileType: /(image\/(jpeg|jpg|png|webp|heic|heif)|application\/(pdf|octet-stream))/,
            skipMagicNumbersValidation: true,
          }),
        ],
      }),
    )
    file: UploadedFilePayload,
  ) {
    const result = await this.files.uploadBuffer(
      `customers/${dto.folder}`,
      file.originalname,
      normalizeUploadMime(file.mimetype, file.originalname),
      file.buffer,
    );
    return successResponse(result);
  }

  @Post('provider/files/presign')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.PROVIDER)
  presignProvider(@Body() dto: PresignDto) {
    return this.files.getUploadUrl(`providers/${dto.folder}`, dto.filename, dto.contentType).then(successResponse);
  }

  @Post('provider/files/access-url')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.PROVIDER)
  async accessUrlProvider(@Body() dto: AccessUrlDto) {
    const url = await this.files.resolveAccessUrl(dto.fileUrl, dto.expiresIn ?? 3600);
    return successResponse({ url });
  }

  @Post('provider/files/upload')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard, RolesGuard)
  @Roles(UserRole.PROVIDER)
  @UseInterceptors(FileInterceptor('file'))
  @ApiConsumes('multipart/form-data')
  @ApiBody({
    schema: {
      type: 'object',
      properties: {
        folder: { type: 'string', example: 'documents' },
        file: { type: 'string', format: 'binary' },
      },
    },
  })
  async uploadProvider(
    @Body() dto: UploadFolderDto,
    @UploadedFile(
      new ParseFilePipe({
        validators: [
          new MaxFileSizeValidator({ maxSize: MAX_FILE_BYTES }),
          new FileTypeValidator({
            fileType: /(image\/(jpeg|jpg|png|webp|heic|heif)|application\/(pdf|octet-stream))/,
            skipMagicNumbersValidation: true,
          }),
        ],
      }),
    )
    file: UploadedFilePayload,
  ) {
    const result = await this.files.uploadBuffer(
      `providers/${dto.folder}`,
      file.originalname,
      normalizeUploadMime(file.mimetype, file.originalname),
      file.buffer,
    );
    return successResponse(result);
  }
}

function normalizeUploadMime(mimetype: string, originalname: string): string {
  const mime = (mimetype || '').toLowerCase();
  if (mime.startsWith('image/') || mime === 'application/pdf') {
    return mime === 'image/jpg' ? 'image/jpeg' : mime;
  }
  const lower = originalname.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
  if (lower.endsWith('.pdf')) return 'application/pdf';
  return 'image/jpeg';
}
