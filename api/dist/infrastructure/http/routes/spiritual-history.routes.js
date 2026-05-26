"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.spiritualHistoryRoutes = spiritualHistoryRoutes;
const express_1 = require("express");
const auth_middleware_1 = require("../middlewares/auth.middleware");
function spiritualHistoryRoutes(controller) {
    const router = (0, express_1.Router)();
    router.use(auth_middleware_1.authMiddleware);
    router.post('/', controller.addEvent);
    router.get('/visitor/:visitorId', controller.findByVisitor);
    router.get('/cell/:cellId', controller.findByCell);
    return router;
}
