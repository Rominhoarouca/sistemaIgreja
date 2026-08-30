import { Router } from 'express';
import multer from 'multer';
import type { NotificationController } from '../controllers/NotificationController';
import { authMiddleware, requireAdmin, restoreTenantContext } from '../middlewares/auth.middleware';

// Imagem opcional anexada à notificação — não é vídeo, limite pequeno.
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB
});

export function notificationRoutes(controller: NotificationController): Router {
  const router = Router();
  router.use(authMiddleware);

  // Rotas de gestão do admin (todas as notificações da igreja, não só as
  // recebidas) — registradas antes de '/:id' pra "admin" não ser capturado
  // como um id.
  router.get('/admin', requireAdmin, controller.listAllForAdmin);
  router.get('/admin/:id', requireAdmin, controller.getDetailForAdmin);
  router.patch(
    '/admin/:id',
    requireAdmin,
    upload.single('image'),
    restoreTenantContext,
    controller.updateForAdmin,
  );

  router.get('/', controller.listMine);
  router.post('/', requireAdmin, upload.single('image'), restoreTenantContext, controller.create);
  router.get('/:id', controller.getDetail);
  router.patch('/read-all', controller.markAllRead);
  router.patch('/:id/read', controller.markRead);

  return router;
}
