"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.attendanceRoutes = attendanceRoutes;
const express_1 = require("express");
const multer_1 = __importDefault(require("multer"));
const auth_middleware_1 = require("../middlewares/auth.middleware");
const upload = (0, multer_1.default)({
    storage: multer_1.default.memoryStorage(),
    limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB
});
function attendanceRoutes(controller) {
    const router = (0, express_1.Router)();
    router.use(auth_middleware_1.authMiddleware);
    router.post('/', controller.register);
    router.get('/cell/:cellId', controller.findByCellAndDate);
    router.get('/cell/:cellId/meetings', controller.findMeetingsByCell);
    router.post('/cell/:cellId/meetings', controller.createMeeting);
    router.post('/cell/:cellId/meetings/:meetingDate/photo', upload.single('photo'), controller.uploadMeetingPhoto);
    router.get('/cell/:cellId/meetings/:meetingDate/photo', controller.getMeetingPhoto);
    return router;
}
