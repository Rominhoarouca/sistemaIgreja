import type { Request, Response } from 'express';
import { z } from 'zod';
import type { RegisterAttendanceUseCase } from '@application/usecases/attendance/RegisterAttendanceUseCase';
import type { IAttendanceRepository } from '@domain/repositories/IAttendanceRepository';
import type { MinioService } from '@infrastructure/storage/MinioService';
import { randomUUID } from 'crypto';
import { AppError } from '@shared/errors/AppError';

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

/** Campo de texto vindo de formulário: em branco vira `null` (campo limpo). */
const optionalText = (max: number) =>
  z
    .string()
    .max(max)
    .nullish()
    .transform((v) => {
      if (v === undefined) return undefined;
      const trimmed = v?.trim() ?? '';
      return trimmed === '' ? null : trimmed;
    });

const createMeetingSchema = z.object({
  meetingDate: z.coerce.date(),
  lesson: optionalText(300),
  ministrante: optionalText(150),
});

const attendeeHistoryQuerySchema = z.object({
  kind: z.enum(['MEMBER', 'VISITOR']).default('MEMBER'),
});

export class AttendanceController {
  constructor(
    private readonly registerUseCase: RegisterAttendanceUseCase,
    private readonly attendanceRepo: IAttendanceRepository,
    private readonly minioService: MinioService,
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
    const { meetingDate, lesson, ministrante } = createMeetingSchema.parse(req.body);
    const createdById = req.userId!;
    await this.attendanceRepo.createMeeting(cellId, meetingDate, createdById, {
      lesson,
      ministrante,
    });
    res.status(201).json({ message: 'Encontro criado com sucesso' });
  };

  findAttendeesByCell = async (req: Request, res: Response): Promise<void> => {
    const { cellId } = req.params as { cellId: string };
    const attendees = await this.attendanceRepo.findAttendeesByCellId(cellId);
    res.json({ attendees });
  };

  /** Histórico de encontros de uma pessoa — alimenta o calendário de frequência. */
  findAttendeeHistory = async (req: Request, res: Response): Promise<void> => {
    const { cellId, personId } = req.params as { cellId: string; personId: string };
    const { kind } = attendeeHistoryQuerySchema.parse(req.query);
    const history = await this.attendanceRepo.findAttendeeHistory(cellId, personId, kind);
    res.json({ history });
  };

  uploadMeetingPhoto = async (req: Request, res: Response): Promise<void> => {
    const { cellId, meetingDate: meetingDateParam } = req.params as {
      cellId: string;
      meetingDate: string;
    };

    if (!req.file) throw new AppError('Nenhuma foto enviada', 400, 'NO_FILE');

    const meetingDate = new Date(meetingDateParam);
    if (isNaN(meetingDate.getTime())) throw new AppError('Data inválida', 400, 'INVALID_DATE');

    const ext = req.file.originalname.split('.').pop() ?? 'jpg';
    const objectName = `meetings/${cellId}/${meetingDateParam.slice(0, 10)}_${randomUUID()}.${ext}`;

    await this.minioService.uploadFile({
      objectName,
      buffer: req.file.buffer,
      mimeType: req.file.mimetype,
      size: req.file.size,
    });

    await this.attendanceRepo.updateMeetingPhoto(cellId, meetingDate, objectName);

    const photoUrl = await this.minioService.presignedDownloadUrl(objectName);
    res.json({ photoUrl });
  };

  getMeetingPhoto = async (req: Request, res: Response): Promise<void> => {
    const { cellId, meetingDate: meetingDateParam } = req.params as {
      cellId: string;
      meetingDate: string;
    };
    const meetingDate = new Date(meetingDateParam);
    const photoKey = await this.attendanceRepo.getMeetingPhotoKey(cellId, meetingDate);
    if (!photoKey) {
      res.json({ photoUrl: null });
      return;
    }
    const photoUrl = await this.minioService.presignedDownloadUrl(photoKey);
    res.json({ photoUrl });
  };
}
