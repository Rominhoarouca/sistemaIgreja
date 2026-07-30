import { Router, raw } from 'express';
import type { BillingController } from '../controllers/BillingController';
import { authMiddleware, requireAdmin } from '../middlewares/auth.middleware';

export function billingRoutes(controller: BillingController): Router {
  const router = Router();

  // Webhook do gateway — público, corpo cru p/ verificação de assinatura.
  router.post('/webhook', raw({ type: '*/*' }), controller.webhook);

  // Checkout — ADMIN da igreja.
  router.post('/checkout', authMiddleware, requireAdmin, controller.checkout);

  return router;
}
