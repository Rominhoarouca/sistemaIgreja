"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.cellTypeRoutes = cellTypeRoutes;
const express_1 = require("express");
const auth_middleware_1 = require("../middlewares/auth.middleware");
function cellTypeRoutes(controller) {
    const router = (0, express_1.Router)();
    router.use(auth_middleware_1.authMiddleware);
    router.get('/', controller.findAll);
    router.post('/', controller.create);
    router.patch('/:id', controller.update);
    router.delete('/:id', controller.delete);
    return router;
}
