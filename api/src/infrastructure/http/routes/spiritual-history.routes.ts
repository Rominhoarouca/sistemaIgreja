import { Router } from 'express';
import type { SpiritualHistoryController } from '../controllers/SpiritualHistoryController';
import { authMiddleware } from '../middlewares/auth.middleware';

export function spiritualHistoryRoutes(controller: SpiritualHistoryController): Router {
  const router = Router();
  router.use(authMiddleware);
  router.post('/', controller.addEvent);
  router.get('/visitor/:visitorId', controller.findByVisitor);
  return router;
}
