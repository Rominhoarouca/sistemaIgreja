import { Router } from 'express';
import type { PlanController } from '../controllers/PlanController';
import { authMiddleware } from '../middlewares/auth.middleware';

export function planRoutes(controller: PlanController): Router {
  const router = Router();
  router.use(authMiddleware);
  // Planos ativos p/ tela de assinatura (qualquer usuário autenticado).
  router.get('/', controller.listActive);
  return router;
}
