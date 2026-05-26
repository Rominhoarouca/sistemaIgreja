"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.dashboardRoutes = dashboardRoutes;
const express_1 = require("express");
const auth_middleware_1 = require("../middlewares/auth.middleware");
function dashboardRoutes(controller) {
    const router = (0, express_1.Router)();
    router.use(auth_middleware_1.authMiddleware, auth_middleware_1.requireAdmin);
    router.get('/stats', controller.getStats);
    router.get('/monthly-stats', controller.getMonthlyStats);
    return router;
}
