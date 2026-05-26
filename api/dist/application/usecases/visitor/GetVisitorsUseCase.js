"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.GetVisitorsUseCase = void 0;
class GetVisitorsUseCase {
    visitorRepo;
    constructor(visitorRepo) {
        this.visitorRepo = visitorRepo;
    }
    async execute(filters) {
        return this.visitorRepo.findMany(filters);
    }
}
exports.GetVisitorsUseCase = GetVisitorsUseCase;
