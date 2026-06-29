"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SpiritualHistoryController = void 0;
const zod_1 = require("zod");
const addEventSchema = zod_1.z.object({
    visitorId: zod_1.z.string().uuid(),
    eventType: zod_1.z.enum([
        'enviado_batismo',
        'batizado',
        'enviado_treinamento_lider',
        'concluiu_treinamento',
        'tornou_se_lider',
    ]),
    description: zod_1.z.string().optional(),
    // Accept both "YYYY-MM-DD" and full ISO datetime strings
    date: zod_1.z.string().transform((val) => val.substring(0, 10)).pipe(zod_1.z.string().date()),
});
class SpiritualHistoryController {
    addEventUseCase;
    spiritualHistoryRepo;
    constructor(addEventUseCase, spiritualHistoryRepo) {
        this.addEventUseCase = addEventUseCase;
        this.spiritualHistoryRepo = spiritualHistoryRepo;
    }
    addEvent = async (req, res) => {
        const data = addEventSchema.parse(req.body);
        const event = await this.addEventUseCase.execute({
            ...data,
            date: new Date(data.date),
            recordedById: req.userId,
        });
        res.status(201).json({ event });
    };
    findByVisitor = async (req, res) => {
        const { visitorId } = req.params;
        const history = await this.spiritualHistoryRepo.findByVisitor(visitorId);
        res.json({ history });
    };
    findByCell = async (req, res) => {
        const { cellId } = req.params;
        const history = await this.spiritualHistoryRepo.findByCellId(cellId);
        res.json({ history });
    };
}
exports.SpiritualHistoryController = SpiritualHistoryController;
