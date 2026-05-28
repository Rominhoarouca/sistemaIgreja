import * as Minio from 'minio';
import { AppError } from '@shared/errors/AppError';

export class MinioService {
  private readonly client: Minio.Client;
  private readonly bucket: string;

  constructor() {
    this.bucket = process.env['MINIO_BUCKET'] ?? 'materiais';
    this.client = new Minio.Client({
      endPoint: process.env['MINIO_ENDPOINT'] ?? 'localhost',
      port: Number(process.env['MINIO_PORT'] ?? 9000),
      useSSL: process.env['MINIO_USE_SSL'] === 'true',
      accessKey: process.env['MINIO_ACCESS_KEY'] ?? 'minio_user',
      secretKey: process.env['MINIO_SECRET_KEY'] ?? 'minio_password',
    });
  }

  async ensureBucket(): Promise<void> {
    try {
      const exists = await this.client.bucketExists(this.bucket);
      if (!exists) {
        await this.client.makeBucket(this.bucket, 'us-east-1');
      }
    } catch (err) {
      throw AppError.internal(`MinIO bucket error: ${String(err)}`);
    }
  }

  /**
   * Upload a file buffer to MinIO.
   * Returns the object name (key) stored.
   */
  async uploadFile(params: {
    objectName: string;
    buffer: Buffer;
    mimeType: string;
    size: number;
  }): Promise<string> {
    await this.ensureBucket();
    try {
      await this.client.putObject(
        this.bucket,
        params.objectName,
        params.buffer,
        params.size,
        { 'Content-Type': params.mimeType },
      );
      return params.objectName;
    } catch (err) {
      throw AppError.internal(`MinIO upload error: ${String(err)}`);
    }
  }

  /**
   * Generate a presigned download URL valid for 1 hour.
   * Rewrites the internal minio hostname to the public URL routed via nginx (/storage/).
   */
  async presignedDownloadUrl(objectName: string, expireSeconds = 3600): Promise<string> {
    try {
      const url = await this.client.presignedGetObject(this.bucket, objectName, expireSeconds);
      const publicUrl = process.env['MINIO_PUBLIC_URL'];
      if (publicUrl) {
        // Replace "http://minio:9000/" with "{publicUrl}/storage/" so browsers
        // can reach the file via the nginx reverse proxy at /storage/
        return url.replace(/^https?:\/\/[^/]+\//, `${publicUrl}/storage/`);
      }
      return url;
    } catch (err) {
      throw AppError.internal(`MinIO presign error: ${String(err)}`);
    }
  }

  /**
   * Delete an object from the bucket.
   */
  async deleteObject(objectName: string): Promise<void> {
    try {
      await this.client.removeObject(this.bucket, objectName);
    } catch {
      // Ignore deletion errors — object may not exist
    }
  }
}
