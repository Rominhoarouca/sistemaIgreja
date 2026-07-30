import { Router } from 'express';
import type { SuperAdminController } from '../controllers/SuperAdminController';
import type { PlanController } from '../controllers/PlanController';
import type { BillingController } from '../controllers/BillingController';
import { authMiddleware, requireSuperAdmin } from '../middlewares/auth.middleware';

export function superAdminRoutes(
  superAdmin: SuperAdminController,
  plan: PlanController,
  billing: BillingController,
): Router {
  const router = Router();
  router.use(authMiddleware, requireSuperAdmin);

  // Igrejas (tenants)
  router.get('/churches', superAdmin.listChurches);
  router.post('/churches', superAdmin.createChurch);
  router.patch('/churches/:id/active', superAdmin.setActive);

  // Uso do sistema (dashboard superadmin)
  router.get('/usage', superAdmin.usage);

  // Planos
  router.get('/plans', plan.listAll);
  router.put('/plans', plan.upsert);
  router.get('/features', plan.catalog);

  // Atribuição manual de plano
  router.post('/subscriptions/assign', billing.assign);

  return router;
}
