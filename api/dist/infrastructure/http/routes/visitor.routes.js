"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.visitorRoutes = visitorRoutes;
const express_1 = require("express");
const auth_middleware_1 = require("../middlewares/auth.middleware");
function visitorRoutes(controller) {
    const router = (0, express_1.Router)();
    router.use(auth_middleware_1.authMiddleware);
    router.post('/', controller.create);
    router.get('/', controller.findAll);
    router.get('/:id', controller.findById);
    router.patch('/:id/status', controller.updateStatus);
    router.patch('/:id/convert-member', controller.convertToMember);
    return router;
}
