import { Router } from 'express';
import type { VisitorController } from '../controllers/VisitorController';
import { authMiddleware } from '../middlewares/auth.middleware';

export function visitorRoutes(controller: VisitorController): Router {
  const router = Router();
  // Public endpoint — no auth required
  router.post('/self-register', controller.selfRegister);
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
