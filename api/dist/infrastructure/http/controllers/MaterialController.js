"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.MaterialController = void 0;
const zod_1 = require("zod");
const AppError_1 = require("@shared/errors/AppError");
class MaterialController {
    uploadUseCase;
    materialRepo;
    minioService;
    constructor(uploadUseCase, materialRepo, minioService) {
        this.uploadUseCase = uploadUseCase;
        this.materialRepo = materialRepo;
        this.minioService = minioService;
    }
    upload = async (req, res) => {
        const file = req.file;
        if (!file)
            throw new AppError_1.AppError('Nenhum arquivo enviado', 400);
        const { cellId } = zod_1.z.object({ cellId: zod_1.z.string().uuid() }).parse(req.body);
        const title = req.body.title ?? file.originalname;
        const description = req.body.description;
        const material = await this.uploadUseCase.execute({
            cellId,
            title,
            ...(description !== undefined && { description }),
            fileBuffer: file.buffer,
            originalName: file.originalname,
            mimeType: file.mimetype,
            sizeBytes: file.size,
            uploadedById: req.userId,
        });
        res.status(201).json({ material });
    };
    findByCell = async (req, res) => {
        const { cellId } = zod_1.z.object({ cellId: zod_1.z.string().uuid().optional() }).parse(req.query);
        const materials = cellId
            ? await this.materialRepo.findByCell(cellId)
            : await this.materialRepo.findAll();
        res.json({ materials });
    };
    getDownloadUrl = async (req, res) => {
        const { id } = req.params;
        const material = await this.materialRepo.findById(id);
        if (!material)
            throw AppError_1.AppError.notFound('Material não encontrado');
        const url = await this.minioService.presignedDownloadUrl(material.url);
        res.json({ url, filename: material.title });
    };
    delete = async (req, res) => {
        const { id } = req.params;
        const material = await this.materialRepo.findById(id);
        if (material) {
            await this.minioService.deleteObject(material.url);
        }
        await this.materialRepo.delete(id);
        res.status(204).send();
    };
}
exports.MaterialController = MaterialController;
