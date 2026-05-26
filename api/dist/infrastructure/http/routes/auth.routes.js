"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.authRoutes = authRoutes;
const express_1 = require("express");
const auth_middleware_1 = require("../middlewares/auth.middleware");
function authRoutes(controller) {
    const router = (0, express_1.Router)();
    router.post('/register', controller.register);
    router.post('/login', controller.login);
    router.post('/refresh', controller.refresh);
    router.post('/logout', auth_middleware_1.authMiddleware, controller.logout);
    router.get('/me', auth_middleware_1.authMiddleware, controller.me);
    return router;
}
