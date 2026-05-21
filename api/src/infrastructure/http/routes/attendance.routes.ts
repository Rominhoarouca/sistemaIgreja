import { Router } from 'express';
import type { AttendanceController } from '../controllers/AttendanceController';
import { authMiddleware } from '../middlewares/auth.middleware';

export function attendanceRoutes(controller: AttendanceController): Router {
  const router = Router();
  router.use(authMiddleware);
  router.post('/', controller.register);
  router.get('/cell/:cellId', controller.findByCellAndDate);
  return router;
}
