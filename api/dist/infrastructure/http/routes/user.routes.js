"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.userRoutes = userRoutes;
const express_1 = require("express");
const multer_1 = __importDefault(require("multer"));
const auth_middleware_1 = require("../middlewares/auth.middleware");
const upload = (0, multer_1.default)({
    storage: multer_1.default.memoryStorage(),
    limits: { fileSize: 10 * 1024 * 1024 }, // 10 MB for profile photo
});
function userRoutes(controller) {
    const router = (0, express_1.Router)();
    router.use(auth_middleware_1.authMiddleware);
    router.get('/me', controller.getProfile);
    router.patch('/me', upload.single('photo'), controller.updateProfile);
    router.get('/leaders', auth_middleware_1.requireSupervisorOrAdmin, controller.findLeaders);
    router.get('/supervisors', auth_middleware_1.requireAdmin, controller.findSupervisors);
    router.get('/coordinadores', auth_middleware_1.requireAdmin, controller.findCoordinadores);
    router.get('/my-leaders', auth_middleware_1.requireSupervisorOrAdmin, controller.getMyLeaders);
    router.post('/create', auth_middleware_1.requireAdmin, controller.createUser);
    router.patch('/leaders/:leaderId/supervisor', auth_middleware_1.requireAdmin, controller.assignLeaderSupervisor);
    router.patch('/leaders/:leaderId/promote', auth_middleware_1.requireAdmin, controller.promoteLeader);
    router.patch('/leaders/:leaderId', auth_middleware_1.requireAdmin, controller.updateLeaderDescription);
    router.patch('/supervisors/:supervisorId/coordenacao', auth_middleware_1.requireAdmin, controller.assignSupervisorCoordenacao);
    return router;
}
