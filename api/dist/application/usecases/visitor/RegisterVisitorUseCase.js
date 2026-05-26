"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.RegisterVisitorUseCase = void 0;
class RegisterVisitorUseCase {
    visitorRepo;
    constructor(visitorRepo) {
        this.visitorRepo = visitorRepo;
    }
    async execute(data) {
        return this.visitorRepo.create(data);
    }
}
exports.RegisterVisitorUseCase = RegisterVisitorUseCase;
