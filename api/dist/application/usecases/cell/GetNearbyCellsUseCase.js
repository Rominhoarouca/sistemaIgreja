"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.GetNearbyCellsUseCase = void 0;
class GetNearbyCellsUseCase {
    cellRepo;
    constructor(cellRepo) {
        this.cellRepo = cellRepo;
    }
    async execute(params) {
        return this.cellRepo.findNearby(params);
    }
}
exports.GetNearbyCellsUseCase = GetNearbyCellsUseCase;
