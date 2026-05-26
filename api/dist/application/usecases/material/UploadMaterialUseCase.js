"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.UploadMaterialUseCase = void 0;
const uuid_1 = require("uuid");
const path_1 = __importDefault(require("path"));
class UploadMaterialUseCase {
    materialRepo;
    minioService;
    constructor(materialRepo, minioService) {
        this.materialRepo = materialRepo;
        this.minioService = minioService;
    }
    async execute(input) {
        const ext = path_1.default.extname(input.originalName).toLowerCase();
        const objectName = `${input.cellId}/${(0, uuid_1.v4)()}${ext}`;
        await this.minioService.uploadFile({
            objectName,
            buffer: input.fileBuffer,
            mimeType: input.mimeType,
            size: input.sizeBytes,
        });
        const fileType = this.resolveFileType(ext, input.mimeType);
        const data = {
            cellId: input.cellId,
            title: input.title,
            ...(input.description !== undefined && { description: input.description }),
            url: objectName, // stored as MinIO object key
            fileType,
            sizeBytes: input.sizeBytes,
            uploadedById: input.uploadedById,
        };
        return this.materialRepo.create(data);
    }
    resolveFileType(ext, mime) {
        if (ext === '.pdf' || mime === 'application/pdf')
            return 'pdf';
        if (['.doc', '.docx'].includes(ext))
            return 'docx';
        if (['.ppt', '.pptx'].includes(ext))
            return 'ppt';
        if (mime.startsWith('video/'))
            return 'video';
        return 'outro';
    }
}
exports.UploadMaterialUseCase = UploadMaterialUseCase;
