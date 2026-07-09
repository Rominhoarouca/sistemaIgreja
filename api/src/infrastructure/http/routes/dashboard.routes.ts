import { Router } from 'express';
import type { DashboardController } from '../controllers/DashboardController';
import { authMiddleware, requireAdmin } from '../middlewares/auth.middleware';

export function dashboardRoutes(controller: DashboardController): Router {
  const router = Router();
  router.use(authMiddleware, requireAdmin);
  router.get('/stats', controller.getStats);
  router.get('/monthly-stats', controller.getMonthlyStats);
  router.get('/attendance-by-cell', controller.getAttendanceByCell);
  return router;
}
