import type { Request, Response } from 'express';
import { z } from 'zod';
import type { RegisterAttendanceUseCase } from '@application/usecases/attendance/RegisterAttendanceUseCase';
import type { IAttendanceRepository } from '@domain/repositories/IAttendanceRepository';

const registerSchema = z
  .object({
    visitorId: z.string().uuid().optional(),
    memberId: z.string().uuid().optional(),
    cellId: z.string().uuid(),
    meetingDate: z.coerce.date(),
    isPresent: z.boolean().default(true),
    notes: z.string().optional(),
  })
  .refine((d) => d.visitorId !== undefined || d.memberId !== undefined, {
    message: 'visitorId or memberId is required',
  });

const createMeetingSchema = z.object({
  meetingDate: z.coerce.date(),
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
      meetingDate: data.meetingDate,
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

  findMeetingsByCell = async (req: Request, res: Response): Promise<void> => {
    const { cellId } = req.params as { cellId: string };
    const meetings = await this.attendanceRepo.findMeetingsByCellId(cellId);
    res.json({ meetings });
  };

  createMeeting = async (req: Request, res: Response): Promise<void> => {
    const { cellId } = req.params as { cellId: string };
    const { meetingDate } = createMeetingSchema.parse(req.body);
    const createdById = req.userId!;
    await this.attendanceRepo.createMeeting(cellId, meetingDate, createdById);
    res.status(201).json({ message: 'Encontro criado com sucesso' });
  };
}
