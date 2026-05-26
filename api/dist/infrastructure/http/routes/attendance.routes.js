"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.attendanceRoutes = attendanceRoutes;
const express_1 = require("express");
const auth_middleware_1 = require("../middlewares/auth.middleware");
function attendanceRoutes(controller) {
    const router = (0, express_1.Router)();
    router.use(auth_middleware_1.authMiddleware);
    router.post('/', controller.register);
    router.get('/cell/:cellId', controller.findByCellAndDate);
    router.get('/cell/:cellId/meetings', controller.findMeetingsByCell);
    router.post('/cell/:cellId/meetings', controller.createMeeting);
    return router;
}
