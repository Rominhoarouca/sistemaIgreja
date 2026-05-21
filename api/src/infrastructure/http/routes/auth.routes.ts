import { Router } from 'express';
import type { AuthController } from '../controllers/AuthController';
import { authMiddleware } from '../middlewares/auth.middleware';

export function authRoutes(controller: AuthController): Router {
  const router = Router();
  router.post('/register', controller.register);
  router.post('/login', controller.login);
  router.post('/refresh', controller.refresh);
  router.post('/logout', authMiddleware, controller.logout);
  router.get('/me', authMiddleware, controller.me);
  return router;
}
