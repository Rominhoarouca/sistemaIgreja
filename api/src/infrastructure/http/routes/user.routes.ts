import { Router } from 'express';
import multer from 'multer';
import type { UserController } from '../controllers/UserController';
import { authMiddleware, requireAdmin, requireSupervisorOrAdmin } from '../middlewares/auth.middleware';

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB for profile photo
});

export function userRoutes(controller: UserController): Router {
  const router = Router();
  router.use(authMiddleware);

  router.get('/me', controller.getProfile);
  router.patch('/me', upload.single('photo'), controller.updateProfile);
  router.get('/leaders', requireSupervisorOrAdmin, controller.findLeaders);
  router.get('/supervisors', requireAdmin, controller.findSupervisors);
  router.get('/my-leaders', requireSupervisorOrAdmin, controller.getMyLeaders);
  router.patch('/leaders/:leaderId/supervisor', requireAdmin, controller.assignLeaderSupervisor);
  router.patch('/leaders/:leaderId', requireAdmin, controller.updateLeaderDescription);

  return router;
}
