import { Router } from 'express';
import type { LocationController } from '@infrastructure/http/controllers/LocationController';
import { authMiddleware } from '@infrastructure/http/middlewares/auth.middleware';

export function locationRoutes(controller: LocationController): Router {
  const router = Router();

  // Public GET — location data is not sensitive (used by self-register form too)
  router.get('/estados', controller.listEstados);
  router.get('/estados/:estadoId/cidades', controller.listCidadesByEstado);
  router.get('/cidades/:cidadeId/bairros', controller.listBairrosByCidade);
  
  // UI convenience endpoints
  router.get('/cities', controller.listAllCidades);
  router.get('/neighborhoods', controller.listNeighborhoodsByCidade);

  // Admin: create/delete reference data (requires auth)
  router.post('/estados', authMiddleware, controller.createEstado);
  router.delete('/estados/:id', authMiddleware, controller.deleteEstado);
  router.post('/cidades', authMiddleware, controller.createCidade);
  router.delete('/cidades/:id', authMiddleware, controller.deleteCidade);
  router.post('/bairros', authMiddleware, controller.createBairro);
  router.delete('/bairros/:id', authMiddleware, controller.deleteBairro);

  return router;
}
