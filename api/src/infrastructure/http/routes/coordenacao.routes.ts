import { Router } from 'express';
import type { CoordenacaoController } from '../controllers/CoordenacaoController';
import { authMiddleware, requireAdmin } from '../middlewares/auth.middleware';

export function coordenacaoRoutes(controller: CoordenacaoController): Router {
  const router = Router();
  router.use(authMiddleware);

  router.get('/', requireAdmin, controller.listAll);
  router.post('/', requireAdmin, controller.create);
  router.patch('/:id', requireAdmin, controller.update);
  router.delete('/:id', requireAdmin, controller.remove);

  return router;
}
