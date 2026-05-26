"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AttendanceController = void 0;
const zod_1 = require("zod");
const registerSchema = zod_1.z.object({
    visitorId: zod_1.z.string().uuid(),
    cellId: zod_1.z.string().uuid(),
    meetingDate: zod_1.z.string().datetime({ offset: true }).or(zod_1.z.string().date()),
    isPresent: zod_1.z.boolean().default(true),
    notes: zod_1.z.string().optional(),
});
const createMeetingSchema = zod_1.z.object({
    meetingDate: zod_1.z.string().datetime({ offset: true }).or(zod_1.z.string().date()),
});
class AttendanceController {
    registerUseCase;
    attendanceRepo;
    constructor(registerUseCase, attendanceRepo) {
        this.registerUseCase = registerUseCase;
        this.attendanceRepo = attendanceRepo;
    }
    register = async (req, res) => {
        const data = registerSchema.parse(req.body);
        const attendance = await this.registerUseCase.execute({
            ...data,
            meetingDate: new Date(data.meetingDate),
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
        await this.attendanceRepo.createMeeting(cellId, new Date(meetingDate), createdById);
        res.status(201).json({ message: 'Encontro criado com sucesso' });
    };
}
exports.AttendanceController = AttendanceController;
