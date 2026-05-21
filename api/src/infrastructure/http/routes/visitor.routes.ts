import { Router } from 'express';
import type { VisitorController } from '../controllers/VisitorController';
import { authMiddleware } from '../middlewares/auth.middleware';

export function visitorRoutes(controller: VisitorController): Router {
  const router = Router();
  router.use(authMiddleware);
  router.post('/', controller.create);
  router.get('/', controller.findAll);
  router.get('/:id', controller.findById);
  router.patch('/:id/status', controller.updateStatus);
  router.patch('/:id/convert-member', controller.convertToMember);
  return router;
}
