"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.MinioService = void 0;
const Minio = __importStar(require("minio"));
const AppError_1 = require("@shared/errors/AppError");
class MinioService {
    client;
    bucket;
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
    async ensureBucket() {
        try {
            const exists = await this.client.bucketExists(this.bucket);
            if (!exists) {
                await this.client.makeBucket(this.bucket, 'us-east-1');
            }
        }
        catch (err) {
            throw AppError_1.AppError.internal(`MinIO bucket error: ${String(err)}`);
        }
    }
    /**
     * Upload a file buffer to MinIO.
     * Returns the object name (key) stored.
     */
    async uploadFile(params) {
        await this.ensureBucket();
        try {
            await this.client.putObject(this.bucket, params.objectName, params.buffer, params.size, { 'Content-Type': params.mimeType });
            return params.objectName;
        }
        catch (err) {
            throw AppError_1.AppError.internal(`MinIO upload error: ${String(err)}`);
        }
    }
    /**
     * Generate a presigned download URL valid for 1 hour.
     * Rewrites the internal minio hostname to the public URL routed via nginx (/storage/).
     */
    async presignedDownloadUrl(objectName, expireSeconds = 3600) {
        try {
            const url = await this.client.presignedGetObject(this.bucket, objectName, expireSeconds);
            const publicUrl = process.env['MINIO_PUBLIC_URL'];
            if (publicUrl) {
                // Replace "http://minio:9000/" with "{publicUrl}/storage/" so browsers
                // can reach the file via the nginx reverse proxy at /storage/
                return url.replace(/^https?:\/\/[^/]+\//, `${publicUrl}/storage/`);
            }
            return url;
        }
        catch (err) {
            throw AppError_1.AppError.internal(`MinIO presign error: ${String(err)}`);
        }
    }
    /**
     * Delete an object from the bucket.
     */
    async deleteObject(objectName) {
        try {
            await this.client.removeObject(this.bucket, objectName);
        }
        catch {
            // Ignore deletion errors — object may not exist
        }
    }
}
exports.MinioService = MinioService;
