import { Router } from 'express';
import multer from 'multer';
import type { UserController } from '../controllers/UserController';
import { authMiddleware } from '../middlewares/auth.middleware';

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB for profile photo
});

export function userRoutes(controller: UserController): Router {
  const router = Router();
  router.use(authMiddleware);

  /**
   * @openapi
   * /v1/users/me:
   *   get:
   *     summary: Retorna o perfil do usuário autenticado
   *     tags: [Users]
   *   patch:
   *     summary: Atualiza o perfil (com foto opcional)
   *     tags: [Users]
   */
  router.get('/me', controller.getProfile);
  router.get('/leaders', controller.findLeaders);
  router.patch('/me', upload.single('photo'), controller.updateProfile);

  return router;
}
