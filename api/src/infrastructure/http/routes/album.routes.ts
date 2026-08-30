import { Router } from 'express';
import type { AlbumController } from '../controllers/AlbumController';
import { authMiddleware, requireStaff } from '../middlewares/auth.middleware';

/**
 * Álbum de fotos dos encontros, agrupado pela cadeia de gestão.
 * `requireStaff` já barra líder, kids e responsável; o recorte fino
 * (coordenação/supervisão) fica no controller.
 */
export function albumRoutes(controller: AlbumController): Router {
  const router = Router();
  router.use(authMiddleware, requireStaff);

  router.get('/days', controller.listDays);
  router.get('/:date', controller.getDay);

  return router;
}
