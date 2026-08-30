import { Router } from 'express';
import multer from 'multer';
import type { UserController } from '../controllers/UserController';
import { authMiddleware, requireAdmin, requireSupervisorOrAdmin, requireStaff, restoreTenantContext } from '../middlewares/auth.middleware';

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB for profile photo
});

export function userRoutes(controller: UserController): Router {
  const router = Router();
  router.use(authMiddleware);

  router.get('/me', controller.getProfile);
  router.patch('/me', upload.single('photo'), restoreTenantContext, controller.updateProfile);
  router.get('/leaders', requireSupervisorOrAdmin, controller.findLeaders);
  router.get('/supervisors', requireAdmin, controller.findSupervisors);
  router.get('/coordinadores', requireAdmin, controller.findCoordinadores);
  router.get('/', requireAdmin, controller.listUsers);
  router.get('/search', requireAdmin, controller.searchUsers);
  router.get('/my-leaders', requireStaff, controller.getMyLeaders);
  router.get('/my-supervisors', requireStaff, controller.getMySupervisors);
  router.post('/create', requireAdmin, controller.createUser);
  router.patch('/leaders/:leaderId/supervisor', requireAdmin, controller.assignLeaderSupervisor);
  router.patch('/leaders/:leaderId/promote', requireAdmin, controller.promoteLeader);
  router.patch('/leaders/:leaderId', requireAdmin, controller.updateLeaderDescription);
  router.patch('/supervisors/:supervisorId/coordenacao', requireAdmin, controller.assignSupervisorCoordenacao);
  router.patch('/:userId/password', requireStaff, controller.resetUserPassword);
  router.patch('/:userId/roles', requireAdmin, controller.setUserRoles);

  return router;
}
