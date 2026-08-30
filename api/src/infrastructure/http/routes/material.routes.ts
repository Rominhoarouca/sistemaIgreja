import { Router } from 'express';
import multer from 'multer';
import type { MaterialController } from '../controllers/MaterialController';
import { authMiddleware, restoreTenantContext } from '../middlewares/auth.middleware';

// Store files in memory (buffer) — they are immediately forwarded to MinIO
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 100 * 1024 * 1024 }, // 100 MB
});

export function materialRoutes(controller: MaterialController): Router {
  const router = Router();
  router.use(authMiddleware);

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
  router.post('/', upload.single('file'), restoreTenantContext, controller.upload);

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
