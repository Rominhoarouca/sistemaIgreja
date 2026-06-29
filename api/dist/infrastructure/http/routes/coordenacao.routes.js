"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.coordenacaoRoutes = coordenacaoRoutes;
const express_1 = require("express");
const auth_middleware_1 = require("../middlewares/auth.middleware");
function coordenacaoRoutes(controller) {
    const router = (0, express_1.Router)();
    router.use(auth_middleware_1.authMiddleware);
    router.get('/', auth_middleware_1.requireAdmin, controller.listAll);
    router.post('/', auth_middleware_1.requireAdmin, controller.create);
    router.patch('/:id', auth_middleware_1.requireAdmin, controller.update);
    router.delete('/:id', auth_middleware_1.requireAdmin, controller.remove);
    return router;
}
