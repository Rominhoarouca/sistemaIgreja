"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.RegisterAttendanceUseCase = void 0;
const AppError_1 = require("@shared/errors/AppError");
class RegisterAttendanceUseCase {
    attendanceRepo;
    cellRepo;
    constructor(attendanceRepo, cellRepo) {
        this.attendanceRepo = attendanceRepo;
        this.cellRepo = cellRepo;
    }
    async execute(data) {
        const cell = await this.cellRepo.findById(data.cellId);
        if (!cell)
            throw AppError_1.AppError.notFound('Célula não encontrada');
        return this.attendanceRepo.register(data);
    }
}
exports.RegisterAttendanceUseCase = RegisterAttendanceUseCase;
