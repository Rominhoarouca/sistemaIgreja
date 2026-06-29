"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.locationRoutes = locationRoutes;
const express_1 = require("express");
const auth_middleware_1 = require("@infrastructure/http/middlewares/auth.middleware");
function locationRoutes(controller) {
    const router = (0, express_1.Router)();
    // Public GET — location data is not sensitive (used by self-register form too)
    router.get('/estados', controller.listEstados);
    router.get('/estados/:estadoId/cidades', controller.listCidadesByEstado);
    router.get('/cidades/:cidadeId/bairros', controller.listBairrosByCidade);
    // UI convenience endpoints
    router.get('/cities', controller.listAllCidades);
    router.get('/neighborhoods', controller.listNeighborhoodsByCidade);
    // Admin: create/delete reference data (requires auth)
    router.post('/estados', auth_middleware_1.authMiddleware, controller.createEstado);
    router.delete('/estados/:id', auth_middleware_1.authMiddleware, controller.deleteEstado);
    router.post('/cidades', auth_middleware_1.authMiddleware, controller.createCidade);
    router.delete('/cidades/:id', auth_middleware_1.authMiddleware, controller.deleteCidade);
    router.post('/bairros', auth_middleware_1.authMiddleware, controller.createBairro);
    router.delete('/bairros/:id', auth_middleware_1.authMiddleware, controller.deleteBairro);
    return router;
}
