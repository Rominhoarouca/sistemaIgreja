"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.cellRoutes = cellRoutes;
const express_1 = require("express");
const auth_middleware_1 = require("../middlewares/auth.middleware");
function cellRoutes(controller) {
    const router = (0, express_1.Router)();
    router.get('/nearby', auth_middleware_1.authMiddleware, controller.findNearby);
    router.get('/my-cell', auth_middleware_1.authMiddleware, controller.findByLeader);
    router.get('/', auth_middleware_1.authMiddleware, controller.findAll);
    router.post('/', auth_middleware_1.authMiddleware, controller.create);
    router.get('/:id', auth_middleware_1.authMiddleware, controller.findById);
    router.patch('/:id', auth_middleware_1.authMiddleware, controller.update);
    router.delete('/:id', auth_middleware_1.authMiddleware, controller.delete);
    router.get('/:id/members', auth_middleware_1.authMiddleware, controller.listMembers);
    router.post('/:id/members', auth_middleware_1.authMiddleware, controller.addMember);
    return router;
}
