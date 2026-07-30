import { Router } from 'express';
import multer from 'multer';
import type { AttendanceController } from '../controllers/AttendanceController';
import { authMiddleware } from '../middlewares/auth.middleware';

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB
});

export function attendanceRoutes(controller: AttendanceController): Router {
  const router = Router();
  router.use(authMiddleware);
  router.post('/', controller.register);
  router.get('/cell/:cellId', controller.findByCellAndDate);
  router.get('/cell/:cellId/attendees', controller.findAttendeesByCell);
  router.get('/cell/:cellId/meetings', controller.findMeetingsByCell);
  router.post('/cell/:cellId/meetings', controller.createMeeting);
  router.post('/cell/:cellId/meetings/:meetingDate/photo', upload.single('photo'), controller.uploadMeetingPhoto);
  router.get('/cell/:cellId/meetings/:meetingDate/photo', controller.getMeetingPhoto);
  return router;
}
