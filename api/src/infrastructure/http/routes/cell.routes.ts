import { Router } from 'express';
import type { CellController } from '../controllers/CellController';
import { authMiddleware } from '../middlewares/auth.middleware';

export function cellRoutes(controller: CellController): Router {
  const router = Router();
  router.get('/nearby', authMiddleware, controller.findNearby);
  router.get('/', authMiddleware, controller.findAll);
  router.post('/', authMiddleware, controller.create);
  router.get('/:id', authMiddleware, controller.findById);
  router.patch('/:id', authMiddleware, controller.update);
  router.delete('/:id', authMiddleware, controller.delete);
  router.get('/:id/members', authMiddleware, controller.listMembers);
  router.post('/:id/members', authMiddleware, controller.addMember);
  return router;
}
