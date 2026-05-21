import type { IAttendanceRepository } from '@domain/repositories/IAttendanceRepository';
import type { ICellRepository } from '@domain/repositories/ICellRepository';
import type { Attendance, RegisterAttendanceData } from '@domain/entities/Attendance';
import { AppError } from '@shared/errors/AppError';

export class RegisterAttendanceUseCase {
  constructor(
    private readonly attendanceRepo: IAttendanceRepository,
    private readonly cellRepo: ICellRepository,
  ) {}

  async execute(data: RegisterAttendanceData): Promise<Attendance> {
    const cell = await this.cellRepo.findById(data.cellId);
    if (!cell) throw AppError.notFound('Célula não encontrada');
    return this.attendanceRepo.register(data);
  }
}
