import { Router } from 'express';
import type { SignupController } from '../controllers/SignupController';

export function signupRoutes(controller: SignupController): Router {
  const router = Router();
  // Cadastro público de nova igreja (self-service).
  router.post('/church', controller.signup);
  return router;
}
