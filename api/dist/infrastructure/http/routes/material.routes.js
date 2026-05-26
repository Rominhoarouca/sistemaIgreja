"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.materialRoutes = materialRoutes;
const express_1 = require("express");
const multer_1 = __importDefault(require("multer"));
const auth_middleware_1 = require("../middlewares/auth.middleware");
// Store files in memory (buffer) — they are immediately forwarded to MinIO
const upload = (0, multer_1.default)({
    storage: multer_1.default.memoryStorage(),
    limits: { fileSize: 100 * 1024 * 1024 }, // 100 MB
});
function materialRoutes(controller) {
    const router = (0, express_1.Router)();
    router.use(auth_middleware_1.authMiddleware);
    /**
     * @openapi
     * /v1/materials:
     *   get:
     *     summary: Listar materiais de uma célula
     *     tags: [Materials]
     *     parameters:
     *       - in: query
     *         name: cellId
     *         required: true
     *         schema: { type: string, format: uuid }
     *     responses:
     *       200:
     *         description: Lista de materiais
     *   post:
     *     summary: Upload de material (multipart)
     *     tags: [Materials]
     */
    router.get('/', controller.findByCell);
    router.post('/', upload.single('file'), controller.upload);
    /**
     * @openapi
     * /v1/materials/{id}/download-url:
     *   get:
     *     summary: Obter URL de download (presigned)
     *     tags: [Materials]
     */
    router.get('/:id/download-url', controller.getDownloadUrl);
    router.delete('/:id', controller.delete);
    return router;
}
