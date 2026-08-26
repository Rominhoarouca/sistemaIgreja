import { Router } from 'express';
import type { DeviceController } from '../controllers/DeviceController';
import { authMiddleware } from '../middlewares/auth.middleware';

/** Registro de aparelhos para push. Qualquer papel autenticado registra o seu. */
export function deviceRoutes(controller: DeviceController): Router {
  const router = Router();
  router.use(authMiddleware);

  router.post('/', controller.register);
  router.delete('/', controller.unregister);

  return router;
}
