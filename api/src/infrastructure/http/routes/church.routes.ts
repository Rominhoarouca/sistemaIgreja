import { Router } from 'express';
import multer from 'multer';
import type { ChurchController } from '../controllers/ChurchController';
import { authMiddleware, requireAdmin, restoreTenantContext } from '../middlewares/auth.middleware';

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 }, // 5 MB
});

export function churchRoutes(controller: ChurchController): Router {
  const router = Router();

  // Público — usado pela tela de auto-cadastro do visitante para exibir de qual
  // igreja é o formulário. Registrado antes do authMiddleware de propósito.
  router.get('/public/:slug', controller.getPublicBySlug);

  router.use(authMiddleware);

  // Contexto (tema + plano + features) — qualquer usuário autenticado.
  router.get('/me', controller.getMine);

  // Edição dos dados da igreja — apenas ADMIN (ou SUPERADMIN).
  router.patch('/me', requireAdmin, controller.update);
  router.post(
    '/me/logo',
    requireAdmin,
    upload.single('logo'),
    restoreTenantContext,
    controller.uploadLogoHandler,
  );

  return router;
}
