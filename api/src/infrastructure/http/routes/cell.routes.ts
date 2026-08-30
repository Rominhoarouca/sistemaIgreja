import { Router } from 'express';
import multer from 'multer';
import type { CellController } from '../controllers/CellController';
import { authMiddleware, requireStaff, restoreTenantContext } from '../middlewares/auth.middleware';
import type { RequestHandler } from 'express';

// Fotos de perfil já chegam reduzidas do app; o teto é uma rede de segurança.
const photoUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 }, // 5 MB
});

export function cellRoutes(
  controller: CellController,
  publicTenant: RequestHandler,
): Router {
  const router = Router();
  // Público (sem login), usado pelo formulário de auto-cadastro. Exige o slug
  // da igreja: sem tenant no contexto a lista devolveria células de todas as
  // igrejas do SaaS.
  router.get('/public', publicTenant, controller.findAll);
  // All other routes require authentication
  router.get('/nearby', authMiddleware, controller.findNearby);
  // Antes de '/:id': senão "pending-links" seria lido como um id de célula.
  router.get('/pending-links', authMiddleware, requireStaff, controller.findPendingLinks);
  router.get('/my-cell', authMiddleware, controller.findByLeader);
  router.get('/', authMiddleware, controller.findAll);
  router.post('/', authMiddleware, controller.create);
  router.get('/:id', authMiddleware, controller.findById);
  router.patch('/:id', authMiddleware, controller.update);
  router.delete('/:id', authMiddleware, controller.delete);
  router.get('/:id/members', authMiddleware, controller.listMembers);
  router.post('/:id/members', authMiddleware, controller.addMember);
  router.patch('/:id/members/:memberId', authMiddleware, controller.updateMember);
  router.delete('/:id/members/:memberId', authMiddleware, controller.deleteMember);
  router.post(
    '/:id/members/:memberId/photo',
    authMiddleware,
    photoUpload.single('photo'),
    restoreTenantContext,
    controller.uploadMemberPhoto,
  );
  return router;
}
