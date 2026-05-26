"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AddSpiritualEventUseCase = void 0;
const AppError_1 = require("@shared/errors/AppError");
class AddSpiritualEventUseCase {
    spiritualHistoryRepo;
    visitorRepo;
    constructor(spiritualHistoryRepo, visitorRepo) {
        this.spiritualHistoryRepo = spiritualHistoryRepo;
        this.visitorRepo = visitorRepo;
    }
    async execute(data) {
        const visitor = await this.visitorRepo.findById(data.visitorId);
        if (!visitor)
            throw AppError_1.AppError.notFound('Visitante não encontrado');
        return this.spiritualHistoryRepo.add(data);
    }
}
exports.AddSpiritualEventUseCase = AddSpiritualEventUseCase;
