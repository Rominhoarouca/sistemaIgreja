import { Router } from 'express';
import type { KidsController } from '../controllers/KidsController';
import { requireAdmin } from '../middlewares/auth.middleware';
import { requireGuardian, requireKidsStaff } from '../middlewares/kids.middleware';

type RoomAccessFactory = (
  source: 'roomId' | 'sessionId' | 'checkinId',
  paramName?: string,
) => import('express').RequestHandler;

/**
 * Rotas do módulo Kids. O `authMiddleware` e o gating por plano são aplicados
 * em `app.ts`, antes deste router.
 *
 * Duas famílias de rota convivem aqui: as da equipe (`requireKidsStaff` +
 * acesso à sala) e as do responsável (`requireGuardian`), que só enxerga os
 * próprios filhos.
 */
export function kidsRoutes(
  controller: KidsController,
  requireRoomAccess: RoomAccessFactory,
): Router {
  const router = Router();

  // ── Responsável (app do pai) ──────────────────────────────────────────────
  router.get('/my-qr', requireGuardian, controller.myQr);
  router.get('/my-children', requireGuardian, controller.myChildren);
  router.get('/my-alerts', requireGuardian, controller.myAlerts);

  // ── Salas ─────────────────────────────────────────────────────────────────
  router.get('/rooms', requireKidsStaff, controller.listRooms);
  router.post('/rooms', requireAdmin, controller.createRoom);
  router.patch('/rooms/:id', requireAdmin, controller.updateRoom);
  router.delete('/rooms/:id', requireAdmin, controller.deactivateRoom);
  router.put('/rooms/:id/teachers', requireAdmin, controller.setTeachers);

  // ── Sessões ───────────────────────────────────────────────────────────────
  router.post(
    '/rooms/:id/sessions',
    requireKidsStaff,
    requireRoomAccess('roomId'),
    controller.openSession,
  );
  router.get('/sessions', requireKidsStaff, controller.listSessions);
  router.get(
    '/sessions/:id',
    requireKidsStaff,
    requireRoomAccess('sessionId'),
    controller.getSession,
  );
  router.patch(
    '/sessions/:id',
    requireKidsStaff,
    requireRoomAccess('sessionId'),
    controller.updateSession,
  );
  router.post(
    '/sessions/:id/close',
    requireKidsStaff,
    requireRoomAccess('sessionId'),
    controller.closeSession,
  );
  router.post(
    '/sessions/:id/notes',
    requireKidsStaff,
    requireRoomAccess('sessionId'),
    controller.createNote,
  );

  // ── Crianças ──────────────────────────────────────────────────────────────
  router.get('/children/search', requireKidsStaff, controller.searchChildren);
  router.post('/children/quick', requireKidsStaff, controller.quickRegisterChild);
  // Sem `requireKidsStaff`: o responsável também abre a ficha do próprio filho.
  // O controller decide o que cada papel enxerga (`assertChildVisible`).
  router.get('/children/:id', controller.getChild);
  router.patch('/children/:id', controller.updateChild);
  router.post('/children/:id/guardians', controller.addGuardian);
  router.get('/children/:id/history', controller.childHistory);
  router.get('/children/:id/notes', controller.childNotes);

  // ── Check-in / check-out ──────────────────────────────────────────────────
  router.post('/checkins/resolve-qr', requireKidsStaff, controller.resolveQr);
  router.post('/checkins', requireKidsStaff, controller.checkIn);
  router.get(
    '/checkins/:id',
    requireKidsStaff,
    requireRoomAccess('checkinId'),
    controller.getCheckin,
  );
  router.post(
    '/checkins/:id/checkout',
    requireKidsStaff,
    requireRoomAccess('checkinId'),
    controller.checkOut,
  );
  router.post(
    '/checkins/:id/regenerate-code',
    requireKidsStaff,
    requireRoomAccess('checkinId'),
    controller.regenerateCode,
  );
  router.post(
    '/checkins/:id/alerts',
    requireKidsStaff,
    requireRoomAccess('checkinId'),
    controller.createAlert,
  );

  // ── Anotações ─────────────────────────────────────────────────────────────
  router.patch('/notes/:id', requireKidsStaff, controller.updateNote);
  router.delete('/notes/:id', requireAdmin, controller.deleteNote);

  // ── Alertas ───────────────────────────────────────────────────────────────
  router.get('/alerts', requireKidsStaff, controller.listAlerts);
  router.post('/alerts/:id/acknowledge', controller.acknowledgeAlert);
  router.post('/alerts/:id/resolve', requireKidsStaff, controller.resolveAlert);
  router.post('/alerts/:id/deliveries/call', requireKidsStaff, controller.registerCall);

  // ── Relatórios ────────────────────────────────────────────────────────────
  router.get('/reports/overview', requireAdmin, controller.overview);

  return router;
}
