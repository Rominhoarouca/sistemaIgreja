import type { Request, Response } from 'express';
import { z } from 'zod';
import type { RegisterAttendanceUseCase } from '@application/usecases/attendance/RegisterAttendanceUseCase';
import type { IAttendanceRepository } from '@domain/repositories/IAttendanceRepository';

const registerSchema = z.object({
  visitorId: z.string().uuid(),
  cellId: z.string().uuid(),
  meetingDate: z.string().datetime({ offset: true }).or(z.string().date()),
  isPresent: z.boolean().default(true),
  notes: z.string().optional(),
});

export class AttendanceController {
  constructor(
    private readonly registerUseCase: RegisterAttendanceUseCase,
    private readonly attendanceRepo: IAttendanceRepository,
  ) {}

  register = async (req: Request, res: Response): Promise<void> => {
    const data = registerSchema.parse(req.body);
    const attendance = await this.registerUseCase.execute({
      ...data,
      meetingDate: new Date(data.meetingDate),
    });
    res.status(201).json({ attendance });
  };

  findByCellAndDate = async (req: Request, res: Response): Promise<void> => {
    const { cellId } = req.params as { cellId: string };
    const { date } = req.query as { date?: string };
    const meetingDate = date ? new Date(date) : new Date();
    const attendances = await this.attendanceRepo.findByCellAndDate(cellId, meetingDate);
    res.json({ attendances });
  };
}
