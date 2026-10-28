import { BadRequestException, Injectable, ServiceUnavailableException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { S3Client, PutObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { v2 as cloudinary, UploadApiResponse } from 'cloudinary';
import { v4 as uuidv4 } from 'uuid';

@Injectable()
export class FilesService {
  private s3: S3Client;
  private bucket: string;
  private region: string;
  private cloudName: string;
  private uploadPreset: string;

  constructor(private config: ConfigService) {
    this.bucket = this.config.get<string>('AWS_S3_BUCKET') ?? 'ryvo-uploads';
    this.region = this.config.get<string>('AWS_REGION') ?? 'us-east-1';
    this.cloudName = this.config.get<string>('CLOUDINARY_CLOUD_NAME')?.trim() ?? '';
    this.uploadPreset = this.config.get<string>('CLOUDINARY_UPLOAD_PRESET')?.trim() ?? '';
    this.s3 = new S3Client({
      region: this.region,
      credentials: {
        accessKeyId: this.config.get<string>('AWS_ACCESS_KEY_ID') ?? 'local',
        secretAccessKey: this.config.get<string>('AWS_SECRET_ACCESS_KEY') ?? 'local',
      },
      ...(this.config.get('AWS_S3_ENDPOINT') && {
        endpoint: this.config.get('AWS_S3_ENDPOINT'),
        forcePathStyle: true,
      }),
    });

    if (this.isConfigured()) {
      cloudinary.config({
        cloud_name: this.cloudName,
        api_key: this.config.get<string>('CLOUDINARY_API_KEY')?.trim(),
        api_secret: this.config.get<string>('CLOUDINARY_API_SECRET')?.trim(),
        secure: true,
      });
    }
  }

  /** New uploads require Cloudinary. AWS keys remain for SES and old S3 objects. */
  isConfigured(): boolean {
    const key = this.config.get<string>('CLOUDINARY_API_KEY')?.trim();
    const secret = this.config.get<string>('CLOUDINARY_API_SECRET')?.trim();
    return Boolean(this.cloudName && key && secret);
  }

  private s3Configured(): boolean {
    const id = this.config.get<string>('AWS_ACCESS_KEY_ID')?.trim();
    const secret = this.config.get<string>('AWS_SECRET_ACCESS_KEY')?.trim();
    return Boolean(id && secret && id !== 'local' && secret !== 'local');
  }

  private assertConfigured() {
    if (!this.isConfigured()) {
      throw new ServiceUnavailableException(
        'File storage is not configured. Set CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, and CLOUDINARY_API_SECRET in the API .env file.',
      );
    }
  }

  private sanitizeFilename(filename: string) {
    return filename.replace(/[^\w.\-()]/g, '_') || 'upload';
  }

  private buildKey(prefix: string, filename: string) {
    return `${prefix}/${uuidv4()}-${this.sanitizeFilename(filename)}`;
  }

  private isS3Url(value: string): boolean {
    try {
      const host = new URL(value).hostname;
      return host.includes('amazonaws.com') || host.startsWith(`${this.bucket}.`);
    } catch {
      return false;
    }
  }

  private isCloudinaryUrl(value: string): boolean {
    try {
      return new URL(value).hostname === 'res.cloudinary.com';
    } catch {
      return false;
    }
  }

  /** Stable URL stored in the database. Authenticated assets are opened via a signed URL. */
  private storedCloudinaryUrl(result: UploadApiResponse): string {
    return result.secure_url;
  }

  extractKey(fileUrlOrKey: string): string {
    const value = fileUrlOrKey.trim();
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      return value.replace(/^\//, '');
    }
    if (this.isCloudinaryUrl(value)) {
      return this.parseCloudinary(value).publicId;
    }
    try {
      const url = new URL(value);
      const host = url.hostname;
      const path = decodeURIComponent(url.pathname.replace(/^\//, ''));

      if (host.startsWith(`${this.bucket}.`)) {
        return path;
      }

      if (path.startsWith(`${this.bucket}/`)) {
        return path.slice(this.bucket.length + 1);
      }

      return path;
    } catch {
      throw new BadRequestException('Invalid file URL');
    }
  }

  private parseCloudinary(fileUrl: string): { resourceType: string; publicId: string; deliveryType: string } {
    const url = new URL(fileUrl);
    const parts = url.pathname.split('/').filter(Boolean);
    // https://res.cloudinary.com/<cloud>/<resource_type>/<delivery_type>/[s--sig--/][v123/]<public_id>
    if (parts.length < 4) {
      throw new BadRequestException('Invalid Cloudinary URL');
    }
    const resourceType = parts[1];
    const deliveryType = parts[2];
    let rest = parts.slice(3);
    if (rest[0]?.startsWith('s--')) rest = rest.slice(1);
    if (rest[0] && /^v\d+$/.test(rest[0])) rest = rest.slice(1);
    let publicId = decodeURIComponent(rest.join('/'));
    if (!publicId) throw new BadRequestException('Invalid Cloudinary URL');
    if (resourceType !== 'raw') {
      publicId = publicId.replace(/\.[a-zA-Z0-9]+$/, '');
    }
    return { resourceType, publicId, deliveryType };
  }

  private signCloudinaryUrl(fileUrl: string, expiresIn: number): string {
    const { resourceType, publicId, deliveryType } = this.parseCloudinary(fileUrl);
    const type =
      deliveryType === 'upload' || deliveryType === 'private' || deliveryType === 'authenticated'
        ? deliveryType
        : 'authenticated';
    if (type === 'upload') return fileUrl;
    return cloudinary.url(publicId, {
      resource_type: resourceType,
      type,
      sign_url: true,
      secure: true,
      expires_at: Math.floor(Date.now() / 1000) + expiresIn,
    });
  }

  /** Best-effort removal of a replaced upload. Failures must not block the new document. */
  async deleteStoredFile(fileUrl: string) {
    const value = fileUrl?.trim();
    if (!value || !this.isCloudinaryUrl(value) || !this.isConfigured()) return;
    try {
      const { resourceType, publicId, deliveryType } = this.parseCloudinary(value);
      const type =
        deliveryType === 'upload' || deliveryType === 'private' || deliveryType === 'authenticated'
          ? deliveryType
          : 'authenticated';
      await cloudinary.uploader.destroy(publicId, { resource_type: resourceType, type });
    } catch {
      // The new document is already saved. An orphaned file is preferable to a failed replace.
    }
  }

  private uploadToCloudinary(prefix: string, filename: string, body: Buffer): Promise<UploadApiResponse> {
    const publicId = this.buildKey(prefix, filename).replace(/\.[^.]+$/, '');
    return new Promise((resolve, reject) => {
      const stream = cloudinary.uploader.upload_stream(
        {
          public_id: publicId,
          resource_type: 'auto',
          type: 'authenticated',
          overwrite: false,
          ...(this.uploadPreset ? { upload_preset: this.uploadPreset } : {}),
        },
        (error, result) => {
          if (error || !result) {
            reject(error ?? new Error('Cloudinary upload returned no result'));
            return;
          }
          resolve(result);
        },
      );
      stream.end(body);
    });
  }

  /** Upload file bytes directly from the API server (recommended for mobile apps). */
  async uploadBuffer(prefix: string, filename: string, contentType: string, body: Buffer) {
    if (this.isConfigured()) {
      try {
        const result = await this.uploadToCloudinary(prefix, filename, body);
        const fileUrl = this.storedCloudinaryUrl(result);
        return { uploadUrl: fileUrl, fileUrl, key: result.public_id };
      } catch (err: unknown) {
        const message = err instanceof Error ? err.message : String(err);
        throw new ServiceUnavailableException(`Cloudinary upload failed: ${message}`);
      }
    }

    if (this.s3Configured()) {
      return this.uploadToS3(prefix, filename, contentType, body);
    }

    throw new ServiceUnavailableException(
      'File storage is not configured. Set CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, and CLOUDINARY_API_SECRET in the API .env file.',
    );
  }

  private async uploadToS3(prefix: string, filename: string, contentType: string, body: Buffer) {
    const key = this.buildKey(prefix, filename);
    await this.s3.send(
      new PutObjectCommand({
        Bucket: this.bucket,
        Key: key,
        Body: body,
        ContentType: contentType || 'application/octet-stream',
      }),
    );
    const fileUrl = `https://${this.bucket}.s3.${this.region}.amazonaws.com/${key
      .split('/')
      .map((part) => encodeURIComponent(part))
      .join('/')}`;
    return { uploadUrl: fileUrl, fileUrl, key };
  }

  async getUploadUrl(folder: string, filename: string, contentType: string) {
    this.assertConfigured();
    void contentType;
    const timestamp = Math.floor(Date.now() / 1000);
    const publicId = this.buildKey(folder, filename).replace(/\.[^.]+$/, '');
    const paramsToSign = {
      public_id: publicId,
      timestamp,
      type: 'authenticated',
      ...(this.uploadPreset ? { upload_preset: this.uploadPreset } : {}),
    };
    const signature = cloudinary.utils.api_sign_request(
      paramsToSign,
      this.config.get<string>('CLOUDINARY_API_SECRET')!.trim(),
    );
    const uploadUrl = `https://api.cloudinary.com/v1_1/${this.cloudName}/auto/upload`;
    const fileUrl = cloudinary.url(publicId, {
      resource_type: 'image',
      type: 'authenticated',
      secure: true,
      sign_url: true,
    });
    return { uploadUrl, fileUrl, key: publicId, signature, timestamp, apiKey: this.config.get<string>('CLOUDINARY_API_KEY')?.trim() };
  }

  private async getS3DownloadUrl(key: string, expiresIn = 3600) {
    if (!this.s3Configured()) {
      throw new ServiceUnavailableException('This file is still stored on S3, and AWS credentials are not configured.');
    }
    const command = new GetObjectCommand({ Bucket: this.bucket, Key: key });
    return getSignedUrl(this.s3, command, { expiresIn });
  }

  async getDownloadUrl(key: string, expiresIn = 3600) {
    return this.getS3DownloadUrl(key, expiresIn);
  }

  async resolveAccessUrl(fileUrlOrKey: string, expiresIn = 3600) {
    const value = fileUrlOrKey.trim();

    if (this.isS3Url(value)) {
      return this.getS3DownloadUrl(this.extractKey(value), expiresIn);
    }

    if (this.isCloudinaryUrl(value)) {
      this.assertConfigured();
      return this.signCloudinaryUrl(value, expiresIn);
    }

    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      if (this.s3Configured()) {
        return this.getS3DownloadUrl(this.extractKey(value), expiresIn);
      }
      this.assertConfigured();
      return cloudinary.url(this.extractKey(value), {
        type: 'authenticated',
        sign_url: true,
        secure: true,
        expires_at: Math.floor(Date.now() / 1000) + expiresIn,
      });
    }

    return value;
  }

  /** Quick connectivity check — performs a tiny authenticated upload, then deletes it. */
  async testConnection() {
    if (!this.isConfigured()) {
      return { ok: false, error: 'Cloudinary credentials not configured in .env' };
    }
    const publicId = `_healthcheck/ping-${uuidv4()}`;
    try {
      const uploaded = await cloudinary.uploader.upload(
        `data:text/plain;base64,${Buffer.from('ok').toString('base64')}`,
        { public_id: publicId, resource_type: 'raw', type: 'authenticated' },
      );
      await cloudinary.uploader.destroy(uploaded.public_id, { resource_type: 'raw', type: 'authenticated' });
      return { ok: true, cloudName: this.cloudName, key: uploaded.public_id };
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      return { ok: false, cloudName: this.cloudName, error: message };
    }
  }
}
