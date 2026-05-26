"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.UpdateVisitorStatusUseCase = void 0;
const AppError_1 = require("@shared/errors/AppError");
class UpdateVisitorStatusUseCase {
    visitorRepo;
    constructor(visitorRepo) {
        this.visitorRepo = visitorRepo;
    }
    async execute(id, data) {
        const visitor = await this.visitorRepo.findById(id);
        if (!visitor)
            throw AppError_1.AppError.notFound('Visitante não encontrado');
        return this.visitorRepo.updateStatus(id, data);
    }
}
exports.UpdateVisitorStatusUseCase = UpdateVisitorStatusUseCase;
