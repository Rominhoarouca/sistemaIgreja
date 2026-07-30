import { Router } from 'express';
import type { VisitorController } from '../controllers/VisitorController';
import { authMiddleware } from '../middlewares/auth.middleware';
import type { RequestHandler } from 'express';

export function visitorRoutes(
  controller: VisitorController,
  publicTenant: RequestHandler,
): Router {
  const router = Router();
  // Público (sem login). O publicTenant resolve a igreja pelo slug do link/QR
  // Code — sem ele o visitante seria gravado sem church_id e ficaria invisível
  // para a própria igreja.
  router.post('/self-register', publicTenant, controller.selfRegister);
  // All other routes require authentication
  router.use(authMiddleware);
  router.post('/', controller.create);
  router.get('/', controller.findAll);
  router.get('/:id', controller.findById);
  router.patch('/:id/status', controller.updateStatus);
  router.patch('/:id/assign-cell', controller.assignCell);
  router.patch('/:id/convert-member', controller.convertToMember);
  return router;
}
