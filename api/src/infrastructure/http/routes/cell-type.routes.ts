import { Router } from 'express';
import type { CellTypeController } from '../controllers/CellTypeController';
import { authMiddleware } from '../middlewares/auth.middleware';

export function cellTypeRoutes(controller: CellTypeController): Router {
  const router = Router();
  router.use(authMiddleware);

  router.get('/', controller.findAll);
  router.post('/', controller.create);
  router.patch('/:id', controller.update);
  router.delete('/:id', controller.delete);

  return router;
}
