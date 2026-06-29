"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AttendanceController = void 0;
const zod_1 = require("zod");
const crypto_1 = require("crypto");
const AppError_1 = require("@shared/errors/AppError");
const registerSchema = zod_1.z
    .object({
    visitorId: zod_1.z.string().uuid().optional(),
    memberId: zod_1.z.string().uuid().optional(),
    cellId: zod_1.z.string().uuid(),
    meetingDate: zod_1.z.coerce.date(),
    isPresent: zod_1.z.boolean().default(true),
    notes: zod_1.z.string().optional(),
})
    .refine((d) => d.visitorId !== undefined || d.memberId !== undefined, {
    message: 'visitorId or memberId is required',
});
const createMeetingSchema = zod_1.z.object({
    meetingDate: zod_1.z.coerce.date(),
});
class AttendanceController {
    registerUseCase;
    attendanceRepo;
    minioService;
    constructor(registerUseCase, attendanceRepo, minioService) {
        this.registerUseCase = registerUseCase;
        this.attendanceRepo = attendanceRepo;
        this.minioService = minioService;
    }
    register = async (req, res) => {
        const data = registerSchema.parse(req.body);
        const attendance = await this.registerUseCase.execute({
            ...data,
            meetingDate: data.meetingDate,
        });
        res.status(201).json({ attendance });
    };
    findByCellAndDate = async (req, res) => {
        const { cellId } = req.params;
        const { date } = req.query;
        const meetingDate = date ? new Date(date) : new Date();
        const attendances = await this.attendanceRepo.findByCellAndDate(cellId, meetingDate);
        res.json({ attendances });
    };
    findMeetingsByCell = async (req, res) => {
        const { cellId } = req.params;
        const meetings = await this.attendanceRepo.findMeetingsByCellId(cellId);
        res.json({ meetings });
    };
    createMeeting = async (req, res) => {
        const { cellId } = req.params;
        const { meetingDate } = createMeetingSchema.parse(req.body);
        const createdById = req.userId;
        await this.attendanceRepo.createMeeting(cellId, meetingDate, createdById);
        res.status(201).json({ message: 'Encontro criado com sucesso' });
    };
    uploadMeetingPhoto = async (req, res) => {
        const { cellId, meetingDate: meetingDateParam } = req.params;
        if (!req.file)
            throw new AppError_1.AppError('Nenhuma foto enviada', 400, 'NO_FILE');
        const meetingDate = new Date(meetingDateParam);
        if (isNaN(meetingDate.getTime()))
            throw new AppError_1.AppError('Data inválida', 400, 'INVALID_DATE');
        const ext = req.file.originalname.split('.').pop() ?? 'jpg';
        const objectName = `meetings/${cellId}/${meetingDateParam.slice(0, 10)}_${(0, crypto_1.randomUUID)()}.${ext}`;
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
    getMeetingPhoto = async (req, res) => {
        const { cellId, meetingDate: meetingDateParam } = req.params;
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
exports.AttendanceController = AttendanceController;
