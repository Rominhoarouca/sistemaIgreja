"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.MaterialController = void 0;
const zod_1 = require("zod");
const AppError_1 = require("@shared/errors/AppError");
class MaterialController {
    uploadUseCase;
    materialRepo;
    minioService;
    cellRepo;
    prisma;
    constructor(uploadUseCase, materialRepo, minioService, cellRepo, prisma) {
        this.uploadUseCase = uploadUseCase;
        this.materialRepo = materialRepo;
        this.minioService = minioService;
        this.cellRepo = cellRepo;
        this.prisma = prisma;
    }
    upload = async (req, res) => {
        const file = req.file;
        if (!file)
            throw new AppError_1.AppError('Nenhum arquivo enviado', 400);
        // Accept either a single cellId, a JSON array 'cellIds' (when sending via multipart/form-data),
        // the 'allCells' flag, or a 'cellTypeId' to target all cells of a specific type.
        const bodySchema = zod_1.z.object({
            cellId: zod_1.z.string().uuid().optional(),
            cellIds: zod_1.z.string().optional(), // JSON encoded array coming from FormData
            allCells: zod_1.z.string().optional(), // may arrive as 'true' string from form
            cellTypeId: zod_1.z.string().uuid().optional(), // target all cells of this type
        });
        const parsed = bodySchema.parse(req.body);
        const title = req.body.title ?? file.originalname;
        const description = req.body.description;
        // resolve target cell ids
        let targetCellIds = [];
        if (parsed.cellTypeId) {
            // All cells of a given type
            const cells = await this.prisma.cell.findMany({ where: { cellTypeId: parsed.cellTypeId }, select: { id: true } });
            targetCellIds = cells.map((c) => c.id);
        }
        else if (parsed.allCells && parsed.allCells === 'true') {
            const cells = await this.cellRepo.findAll();
            targetCellIds = cells.map((c) => c.id);
        }
        else if (parsed.cellIds) {
            try {
                const arr = JSON.parse(parsed.cellIds);
                if (Array.isArray(arr))
                    targetCellIds = arr;
            }
            catch (e) {
                // ignore, will fall back to cellId
            }
        }
        if (targetCellIds.length === 0 && parsed.cellId) {
            targetCellIds = [parsed.cellId];
        }
        if (targetCellIds.length === 0)
            throw new AppError_1.AppError('Nenhuma célula alvo informada', 400);
        const created = [];
        for (const cellId of targetCellIds) {
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
            created.push(material);
        }
        // If only one created, keep backward compatibility with previous response
        if (created.length === 1) {
            res.status(201).json({ material: created[0] });
        }
        else {
            res.status(201).json({ materials: created });
        }
    };
    findByCell = async (req, res) => {
        const { cellId } = zod_1.z.object({ cellId: zod_1.z.string().uuid().optional() }).parse(req.query);
        if (cellId) {
            const materials = await this.materialRepo.findByCell(cellId);
            res.json({ materials });
            return;
        }
        // Leader without cellId: return materials for all their cells
        if (req.userRole === 'LIDER') {
            const cells = await this.cellRepo.findByLeaderId(req.userId);
            const allMaterials = [];
            for (const cell of cells) {
                const mats = await this.materialRepo.findByCell(cell.id);
                allMaterials.push(...mats);
            }
            res.json({ materials: allMaterials });
            return;
        }
        const materials = await this.materialRepo.findAll();
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
