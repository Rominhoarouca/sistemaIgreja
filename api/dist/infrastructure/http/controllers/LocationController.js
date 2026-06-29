"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.LocationController = void 0;
const zod_1 = require("zod");
const AppError_1 = require("@shared/errors/AppError");
const createEstadoSchema = zod_1.z.object({
    name: zod_1.z.string().min(2),
    uf: zod_1.z.string().length(2),
});
const createCidadeSchema = zod_1.z.object({
    name: zod_1.z.string().min(2),
    estadoId: zod_1.z.string().uuid(),
});
const createBairroSchema = zod_1.z.object({
    name: zod_1.z.string().min(2),
    cidadeId: zod_1.z.string().uuid(),
});
class LocationController {
    locationRepo;
    constructor(locationRepo) {
        this.locationRepo = locationRepo;
    }
    // ── Estados ────────────────────────────────────────────────────────────────
    listEstados = async (_req, res) => {
        const estados = await this.locationRepo.findAllEstados();
        res.json({ estados });
    };
    createEstado = async (req, res) => {
        const data = createEstadoSchema.parse(req.body);
        const estado = await this.locationRepo.createEstado(data);
        res.status(201).json({ estado });
    };
    deleteEstado = async (req, res) => {
        const { id } = req.params;
        const exists = await this.locationRepo.findEstadoById(id);
        if (!exists)
            throw AppError_1.AppError.notFound('Estado não encontrado');
        await this.locationRepo.deleteEstado(id);
        res.status(204).send();
    };
    // ── Cidades ────────────────────────────────────────────────────────────────
    listCidadesByEstado = async (req, res) => {
        const { estadoId } = req.params;
        const estado = await this.locationRepo.findEstadoById(estadoId);
        if (!estado)
            throw AppError_1.AppError.notFound('Estado não encontrado');
        const cidades = await this.locationRepo.findCidadesByEstado(estadoId);
        res.json({ cidades });
    };
    createCidade = async (req, res) => {
        const data = createCidadeSchema.parse(req.body);
        const estado = await this.locationRepo.findEstadoById(data.estadoId);
        if (!estado)
            throw AppError_1.AppError.notFound('Estado não encontrado');
        const cidade = await this.locationRepo.createCidade(data);
        res.status(201).json({ cidade });
    };
    deleteCidade = async (req, res) => {
        const { id } = req.params;
        const exists = await this.locationRepo.findCidadeById(id);
        if (!exists)
            throw AppError_1.AppError.notFound('Cidade não encontrada');
        await this.locationRepo.deleteCidade(id);
        res.status(204).send();
    };
    // ── Bairros ────────────────────────────────────────────────────────────────
    listBairrosByCidade = async (req, res) => {
        const { cidadeId } = req.params;
        const cidade = await this.locationRepo.findCidadeById(cidadeId);
        if (!cidade)
            throw AppError_1.AppError.notFound('Cidade não encontrada');
        const bairros = await this.locationRepo.findBairrosByCidade(cidadeId);
        res.json({ bairros });
    };
    createBairro = async (req, res) => {
        const data = createBairroSchema.parse(req.body);
        const cidade = await this.locationRepo.findCidadeById(data.cidadeId);
        if (!cidade)
            throw AppError_1.AppError.notFound('Cidade não encontrada');
        const bairro = await this.locationRepo.createBairro(data);
        res.status(201).json({ bairro });
    };
    deleteBairro = async (req, res) => {
        const { id } = req.params;
        const exists = await this.locationRepo.findBairroById(id);
        if (!exists)
            throw AppError_1.AppError.notFound('Bairro não encontrado');
        await this.locationRepo.deleteBairro(id);
        res.status(204).send();
    };
    // ── Helpers (List all) ─────────────────────────────────────────────────────
    listAllCidades = async (_req, res) => {
        const cidades = await this.locationRepo.findAllCidades();
        res.json({ data: cidades });
    };
    listNeighborhoodsByCidade = async (req, res) => {
        const { cidadeId } = req.query;
        if (!cidadeId)
            throw new AppError_1.AppError('cidadeId é obrigatório', 400, 'BAD_REQUEST');
        const cidade = await this.locationRepo.findCidadeById(cidadeId);
        if (!cidade)
            throw AppError_1.AppError.notFound('Cidade não encontrada');
        const bairros = await this.locationRepo.findBairrosByCidade(cidadeId);
        res.json({ data: bairros });
    };
}
exports.LocationController = LocationController;
