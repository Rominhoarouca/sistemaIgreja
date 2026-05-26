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
    /**
     * @openapi
     * /v1/users/me:
     *   get:
     *     summary: Retorna o perfil do usuário autenticado
     *     tags: [Users]
     *   patch:
     *     summary: Atualiza o perfil (com foto opcional)
     *     tags: [Users]
     */
    router.get('/me', controller.getProfile);
    router.get('/leaders', controller.findLeaders);
    router.patch('/me', upload.single('photo'), controller.updateProfile);
    return router;
}
