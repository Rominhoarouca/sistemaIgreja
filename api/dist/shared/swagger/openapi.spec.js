"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.openApiSpec = void 0;
// ─── Shared schemas ──────────────────────────────────────────────────────────
const UserSchema = {
    type: 'object',
    properties: {
        id: { type: 'string', format: 'uuid' },
        name: { type: 'string', example: 'João Silva' },
        email: { type: 'string', format: 'email', example: 'joao@igreja.com' },
        role: { type: 'string', enum: ['ADMIN', 'LIDER'], example: 'LIDER' },
        phone: { type: 'string', example: '(11) 99999-0001', nullable: true },
        cellId: { type: 'string', format: 'uuid', nullable: true },
        createdAt: { type: 'string', format: 'date-time' },
        updatedAt: { type: 'string', format: 'date-time' },
    },
};
const VisitorSchema = {
    type: 'object',
    properties: {
        id: { type: 'string', format: 'uuid' },
        name: { type: 'string', example: 'Maria Oliveira' },
        phone: { type: 'string', example: '(11) 98888-0001' },
        email: { type: 'string', format: 'email', nullable: true },
        address: { type: 'string', nullable: true },
        neighborhood: { type: 'string', nullable: true },
        city: { type: 'string', nullable: true },
        originChurch: { type: 'string', nullable: true },
        status: {
            type: 'string',
            enum: ['novo', 'em_acompanhamento', 'integrado', 'inativo'],
            example: 'novo',
        },
        leaderId: { type: 'string', format: 'uuid', nullable: true },
        cellId: { type: 'string', format: 'uuid', nullable: true },
        referredById: { type: 'string', format: 'uuid', nullable: true },
        createdAt: { type: 'string', format: 'date-time' },
        updatedAt: { type: 'string', format: 'date-time' },
    },
};
const CellSchema = {
    type: 'object',
    properties: {
        id: { type: 'string', format: 'uuid' },
        name: { type: 'string', example: 'Célula Centro' },
        address: { type: 'string', example: 'Rua das Flores, 100' },
        neighborhood: { type: 'string', example: 'Centro' },
        city: { type: 'string', example: 'São Paulo' },
        state: { type: 'string', example: 'SP' },
        latitude: { type: 'number', format: 'double', example: -23.5505 },
        longitude: { type: 'number', format: 'double', example: -46.6333 },
        meetingDay: {
            type: 'string',
            enum: ['SEGUNDA', 'TERCA', 'QUARTA', 'QUINTA', 'SEXTA', 'SABADO', 'DOMINGO'],
        },
        meetingTime: { type: 'string', example: '19:30' },
        leaderId: { type: 'string', format: 'uuid' },
        maxCapacity: { type: 'integer', example: 20 },
        currentCount: { type: 'integer', example: 12 },
        createdAt: { type: 'string', format: 'date-time' },
        updatedAt: { type: 'string', format: 'date-time' },
    },
};
const AttendanceSchema = {
    type: 'object',
    properties: {
        id: { type: 'string', format: 'uuid' },
        visitorId: { type: 'string', format: 'uuid' },
        cellId: { type: 'string', format: 'uuid' },
        meetingDate: { type: 'string', format: 'date-time' },
        isPresent: { type: 'boolean' },
        notes: { type: 'string', nullable: true },
        createdAt: { type: 'string', format: 'date-time' },
    },
};
const SpiritualHistorySchema = {
    type: 'object',
    properties: {
        id: { type: 'string', format: 'uuid' },
        visitorId: { type: 'string', format: 'uuid' },
        eventType: {
            type: 'string',
            enum: [
                'enviado_batismo',
                'batizado',
                'enviado_treinamento_lider',
                'concluiu_treinamento',
                'tornou_se_lider',
            ],
        },
        description: { type: 'string', nullable: true },
        date: { type: 'string', format: 'date' },
        recordedById: { type: 'string', format: 'uuid' },
        createdAt: { type: 'string', format: 'date-time' },
    },
};
const ErrorSchema = {
    type: 'object',
    properties: {
        message: { type: 'string', example: 'Recurso não encontrado' },
        code: { type: 'string', example: 'NOT_FOUND' },
    },
};
const ValidationErrorSchema = {
    type: 'object',
    properties: {
        message: { type: 'string', example: 'Erro de validação' },
        errors: {
            type: 'array',
            items: {
                type: 'object',
                properties: {
                    field: { type: 'string' },
                    message: { type: 'string' },
                },
            },
        },
    },
};
const PaginatedVisitorsSchema = {
    type: 'object',
    properties: {
        data: { type: 'array', items: VisitorSchema },
        total: { type: 'integer', example: 42 },
        page: { type: 'integer', example: 1 },
        pageSize: { type: 'integer', example: 20 },
        totalPages: { type: 'integer', example: 3 },
    },
};
const DashboardStatsSchema = {
    type: 'object',
    properties: {
        totalVisitors: { type: 'integer', example: 120 },
        newThisMonth: { type: 'integer', example: 14 },
        integrated: { type: 'integer', example: 55 },
        inFollowUp: { type: 'integer', example: 30 },
        totalCells: { type: 'integer', example: 8 },
        averageAttendanceRate: { type: 'number', format: 'double', example: 0.72 },
        activeCells: {
            type: 'array',
            items: {
                type: 'object',
                properties: {
                    id: { type: 'string', format: 'uuid' },
                    name: { type: 'string' },
                    attendanceRate: { type: 'number', format: 'double' },
                },
            },
        },
    },
};
// ─── Security ────────────────────────────────────────────────────────────────
const bearerAuth = {
    type: 'http',
    scheme: 'bearer',
    bearerFormat: 'JWT',
    description: 'Token JWT obtido via `POST /v1/auth/login`. Informe no formato: `Bearer <token>`',
};
// ─── Spec ────────────────────────────────────────────────────────────────────
exports.openApiSpec = {
    openapi: '3.0.3',
    info: {
        title: 'Sistema Igreja API',
        version: '1.0.0',
        description: `
## API REST do Sistema de Recepção e Integração de Igreja

Gerencia visitantes, células, presença, histórico espiritual e dashboard.

### Autenticação
A maioria dos endpoints requer um token JWT. Faça login em \`POST /v1/auth/login\`
e use o **accessToken** retornado no header \`Authorization: Bearer <token>\`.

### Roles
| Role    | Descrição |
|---------|-----------|
| \`ADMIN\` | Acesso total a todos os recursos |
| \`LIDER\` | Acesso restrito aos seus próprios visitantes e célula |
    `,
        contact: {
            name: 'Sistema Igreja',
            email: 'admin@sistemaigreja.com.br',
        },
        license: {
            name: 'MIT',
        },
    },
    servers: [
        {
            url: 'http://localhost:3000',
            description: 'Desenvolvimento local',
        },
        {
            url: 'http://localhost:3001',
            description: 'Docker dev (api_dev)',
        },
    ],
    tags: [
        { name: 'Health', description: 'Status da aplicação' },
        { name: 'Auth', description: 'Autenticação e sessão' },
        { name: 'Visitors', description: 'Gerenciamento de visitantes' },
        { name: 'Cells', description: 'Células da igreja' },
        { name: 'Attendance', description: 'Registro de presença nas reuniões' },
        { name: 'Spiritual History', description: 'Histórico espiritual do visitante' },
        { name: 'Dashboard', description: 'Estatísticas gerais (ADMIN)' },
    ],
    components: {
        securitySchemes: {
            bearerAuth,
        },
        schemas: {
            User: UserSchema,
            Visitor: VisitorSchema,
            Cell: CellSchema,
            Attendance: AttendanceSchema,
            SpiritualHistory: SpiritualHistorySchema,
            Error: ErrorSchema,
            ValidationError: ValidationErrorSchema,
            PaginatedVisitors: PaginatedVisitorsSchema,
            DashboardStats: DashboardStatsSchema,
        },
        responses: {
            Unauthorized: {
                description: 'Token inválido ou ausente',
                content: {
                    'application/json': { schema: { $ref: '#/components/schemas/Error' } },
                },
            },
            Forbidden: {
                description: 'Sem permissão para este recurso',
                content: {
                    'application/json': { schema: { $ref: '#/components/schemas/Error' } },
                },
            },
            NotFound: {
                description: 'Recurso não encontrado',
                content: {
                    'application/json': { schema: { $ref: '#/components/schemas/Error' } },
                },
            },
            Conflict: {
                description: 'Recurso já existe',
                content: {
                    'application/json': { schema: { $ref: '#/components/schemas/Error' } },
                },
            },
            ValidationError: {
                description: 'Dados inválidos',
                content: {
                    'application/json': { schema: { $ref: '#/components/schemas/ValidationError' } },
                },
            },
        },
    },
    paths: {
        // ── Health ──────────────────────────────────────────────────────────────
        '/health': {
            get: {
                tags: ['Health'],
                summary: 'Verificar status da API',
                responses: {
                    '200': {
                        description: 'API operacional',
                        content: {
                            'application/json': {
                                schema: {
                                    type: 'object',
                                    properties: {
                                        status: { type: 'string', example: 'ok' },
                                        timestamp: { type: 'string', format: 'date-time' },
                                    },
                                },
                            },
                        },
                    },
                },
            },
        },
        // ── Auth ─────────────────────────────────────────────────────────────────
        '/v1/auth/login': {
            post: {
                tags: ['Auth'],
                summary: 'Realizar login',
                description: 'Autentica um usuário e retorna par de tokens JWT.',
                requestBody: {
                    required: true,
                    content: {
                        'application/json': {
                            schema: {
                                type: 'object',
                                required: ['email', 'password'],
                                properties: {
                                    email: { type: 'string', format: 'email', example: 'admin@sistemaigreja.com.br' },
                                    password: { type: 'string', minLength: 6, example: 'admin123' },
                                },
                            },
                        },
                    },
                },
                responses: {
                    '200': {
                        description: 'Login realizado com sucesso',
                        content: {
                            'application/json': {
                                schema: {
                                    type: 'object',
                                    properties: {
                                        user: { $ref: '#/components/schemas/User' },
                                        accessToken: {
                                            type: 'string',
                                            description: 'Token JWT de acesso (expira em 15min)',
                                        },
                                        refreshToken: {
                                            type: 'string',
                                            description: 'Token de renovação (expira em 7 dias)',
                                        },
                                    },
                                },
                            },
                        },
                    },
                    '401': { $ref: '#/components/responses/Unauthorized' },
                    '422': { $ref: '#/components/responses/ValidationError' },
                },
            },
        },
        '/v1/auth/register': {
            post: {
                tags: ['Auth'],
                summary: 'Criar usuário (público)',
                description: 'Cria um usuário sem necessidade de JWT.',
                requestBody: {
                    required: true,
                    content: {
                        'application/json': {
                            schema: {
                                type: 'object',
                                required: ['name', 'email', 'password', 'role'],
                                properties: {
                                    name: { type: 'string', minLength: 2, example: 'Administrador' },
                                    email: { type: 'string', format: 'email', example: 'admin@sistemaigreja.com.br' },
                                    password: { type: 'string', minLength: 6, example: 'admin123' },
                                    role: { type: 'string', enum: ['ADMIN', 'LIDER'], example: 'ADMIN' },
                                },
                            },
                        },
                    },
                },
                responses: {
                    '201': {
                        description: 'Usuário criado',
                        content: {
                            'application/json': {
                                schema: {
                                    type: 'object',
                                    properties: { user: { $ref: '#/components/schemas/User' } },
                                },
                            },
                        },
                    },
                    '409': { $ref: '#/components/responses/Conflict' },
                    '422': { $ref: '#/components/responses/ValidationError' },
                },
            },
        },
        '/v1/auth/refresh': {
            post: {
                tags: ['Auth'],
                summary: 'Renovar access token',
                description: 'Usa o refreshToken para emitir um novo par de tokens (token rotation).',
                requestBody: {
                    required: true,
                    content: {
                        'application/json': {
                            schema: {
                                type: 'object',
                                required: ['refreshToken'],
                                properties: {
                                    refreshToken: { type: 'string' },
                                },
                            },
                        },
                    },
                },
                responses: {
                    '200': {
                        description: 'Tokens renovados',
                        content: {
                            'application/json': {
                                schema: {
                                    type: 'object',
                                    properties: {
                                        user: { $ref: '#/components/schemas/User' },
                                        accessToken: { type: 'string' },
                                        refreshToken: { type: 'string' },
                                    },
                                },
                            },
                        },
                    },
                    '401': { $ref: '#/components/responses/Unauthorized' },
                    '422': { $ref: '#/components/responses/ValidationError' },
                },
            },
        },
        '/v1/auth/logout': {
            post: {
                tags: ['Auth'],
                summary: 'Encerrar sessão',
                description: 'Invalida o refreshToken do usuário.',
                security: [{ bearerAuth: [] }],
                requestBody: {
                    required: true,
                    content: {
                        'application/json': {
                            schema: {
                                type: 'object',
                                required: ['refreshToken'],
                                properties: {
                                    refreshToken: { type: 'string' },
                                },
                            },
                        },
                    },
                },
                responses: {
                    '204': { description: 'Logout realizado com sucesso' },
                    '401': { $ref: '#/components/responses/Unauthorized' },
                },
            },
        },
        '/v1/auth/me': {
            get: {
                tags: ['Auth'],
                summary: 'Dados do usuário autenticado',
                security: [{ bearerAuth: [] }],
                responses: {
                    '200': {
                        description: 'Dados do usuário logado',
                        content: {
                            'application/json': {
                                schema: {
                                    type: 'object',
                                    properties: { user: { $ref: '#/components/schemas/User' } },
                                },
                            },
                        },
                    },
                    '401': { $ref: '#/components/responses/Unauthorized' },
                    '404': { $ref: '#/components/responses/NotFound' },
                },
            },
        },
        // ── Visitors ─────────────────────────────────────────────────────────────
        '/v1/visitors': {
            post: {
                tags: ['Visitors'],
                summary: 'Cadastrar visitante',
                security: [{ bearerAuth: [] }],
                requestBody: {
                    required: true,
                    content: {
                        'application/json': {
                            schema: {
                                type: 'object',
                                required: ['name', 'phone'],
                                properties: {
                                    name: { type: 'string', minLength: 2, example: 'Maria Oliveira' },
                                    phone: { type: 'string', minLength: 8, example: '(11) 98888-0001' },
                                    email: { type: 'string', format: 'email', example: 'maria@email.com' },
                                    address: { type: 'string', example: 'Rua das Flores, 55' },
                                    neighborhood: { type: 'string', example: 'Jardim Paulista' },
                                    city: { type: 'string', example: 'São Paulo' },
                                    originChurch: { type: 'string', example: 'Igreja Batista Central' },
                                    leaderId: { type: 'string', format: 'uuid' },
                                    cellId: { type: 'string', format: 'uuid' },
                                    referredById: { type: 'string', format: 'uuid' },
                                },
                            },
                        },
                    },
                },
                responses: {
                    '201': {
                        description: 'Visitante criado',
                        content: {
                            'application/json': {
                                schema: {
                                    type: 'object',
                                    properties: { visitor: { $ref: '#/components/schemas/Visitor' } },
                                },
                            },
                        },
                    },
                    '401': { $ref: '#/components/responses/Unauthorized' },
                    '422': { $ref: '#/components/responses/ValidationError' },
                },
            },
            get: {
                tags: ['Visitors'],
                summary: 'Listar visitantes',
                description: 'Líderes (`LIDER`) visualizam apenas seus próprios visitantes. Admins veem todos.',
                security: [{ bearerAuth: [] }],
                parameters: [
                    {
                        name: 'search',
                        in: 'query',
                        description: 'Busca por nome, e-mail ou telefone',
                        schema: { type: 'string' },
                    },
                    {
                        name: 'status',
                        in: 'query',
                        schema: {
                            type: 'string',
                            enum: ['novo', 'em_acompanhamento', 'integrado', 'inativo'],
                        },
                    },
                    {
                        name: 'leaderId',
                        in: 'query',
                        schema: { type: 'string', format: 'uuid' },
                    },
                    {
                        name: 'cellId',
                        in: 'query',
                        schema: { type: 'string', format: 'uuid' },
                    },
                    {
                        name: 'page',
                        in: 'query',
                        schema: { type: 'integer', default: 1, minimum: 1 },
                    },
                    {
                        name: 'pageSize',
                        in: 'query',
                        schema: { type: 'integer', default: 20, minimum: 1, maximum: 100 },
                    },
                ],
                responses: {
                    '200': {
                        description: 'Lista paginada de visitantes',
                        content: {
                            'application/json': {
                                schema: { $ref: '#/components/schemas/PaginatedVisitors' },
                            },
                        },
                    },
                    '401': { $ref: '#/components/responses/Unauthorized' },
                },
            },
        },
        '/v1/visitors/{id}': {
            get: {
                tags: ['Visitors'],
                summary: 'Buscar visitante por ID',
                security: [{ bearerAuth: [] }],
                parameters: [
                    {
                        name: 'id',
                        in: 'path',
                        required: true,
                        schema: { type: 'string', format: 'uuid' },
                    },
                ],
                responses: {
                    '200': {
                        description: 'Dados do visitante',
                        content: {
                            'application/json': {
                                schema: {
                                    type: 'object',
                                    properties: { visitor: { $ref: '#/components/schemas/Visitor' } },
                                },
                            },
                        },
                    },
                    '401': { $ref: '#/components/responses/Unauthorized' },
                    '403': { $ref: '#/components/responses/Forbidden' },
                    '404': { $ref: '#/components/responses/NotFound' },
                },
            },
        },
        '/v1/visitors/{id}/status': {
            patch: {
                tags: ['Visitors'],
                summary: 'Atualizar status do visitante',
                security: [{ bearerAuth: [] }],
                parameters: [
                    {
                        name: 'id',
                        in: 'path',
                        required: true,
                        schema: { type: 'string', format: 'uuid' },
                    },
                ],
                requestBody: {
                    required: true,
                    content: {
                        'application/json': {
                            schema: {
                                type: 'object',
                                required: ['status'],
                                properties: {
                                    status: {
                                        type: 'string',
                                        enum: ['novo', 'em_acompanhamento', 'integrado', 'inativo'],
                                    },
                                    leaderId: { type: 'string', format: 'uuid' },
                                    cellId: { type: 'string', format: 'uuid' },
                                },
                            },
                        },
                    },
                },
                responses: {
                    '200': {
                        description: 'Status atualizado',
                        content: {
                            'application/json': {
                                schema: {
                                    type: 'object',
                                    properties: { visitor: { $ref: '#/components/schemas/Visitor' } },
                                },
                            },
                        },
                    },
                    '401': { $ref: '#/components/responses/Unauthorized' },
                    '404': { $ref: '#/components/responses/NotFound' },
                    '422': { $ref: '#/components/responses/ValidationError' },
                },
            },
        },
        // ── Cells ────────────────────────────────────────────────────────────────
        '/v1/cells': {
            get: {
                tags: ['Cells'],
                summary: 'Listar todas as células',
                security: [{ bearerAuth: [] }],
                responses: {
                    '200': {
                        description: 'Lista de células',
                        content: {
                            'application/json': {
                                schema: {
                                    type: 'object',
                                    properties: {
                                        cells: { type: 'array', items: { $ref: '#/components/schemas/Cell' } },
                                    },
                                },
                            },
                        },
                    },
                    '401': { $ref: '#/components/responses/Unauthorized' },
                },
            },
        },
        '/v1/cells/nearby': {
            get: {
                tags: ['Cells'],
                summary: 'Buscar células próximas (geolocalização)',
                description: 'Retorna células ordenadas pela distância usando a fórmula de Haversine.',
                security: [{ bearerAuth: [] }],
                parameters: [
                    {
                        name: 'lat',
                        in: 'query',
                        required: true,
                        description: 'Latitude (-90 a 90)',
                        schema: { type: 'number', format: 'double', minimum: -90, maximum: 90, example: -23.5505 },
                    },
                    {
                        name: 'lng',
                        in: 'query',
                        required: true,
                        description: 'Longitude (-180 a 180)',
                        schema: { type: 'number', format: 'double', minimum: -180, maximum: 180, example: -46.6333 },
                    },
                    {
                        name: 'radius',
                        in: 'query',
                        description: 'Raio de busca em km (padrão: 10, máximo: 100)',
                        schema: { type: 'number', default: 10, maximum: 100 },
                    },
                ],
                responses: {
                    '200': {
                        description: 'Células próximas',
                        content: {
                            'application/json': {
                                schema: {
                                    type: 'object',
                                    properties: {
                                        cells: {
                                            type: 'array',
                                            items: {
                                                allOf: [
                                                    { $ref: '#/components/schemas/Cell' },
                                                    {
                                                        type: 'object',
                                                        properties: {
                                                            distanceKm: {
                                                                type: 'number',
                                                                format: 'double',
                                                                description: 'Distância em km até o ponto informado',
                                                                example: 2.34,
                                                            },
                                                        },
                                                    },
                                                ],
                                            },
                                        },
                                    },
                                },
                            },
                        },
                    },
                    '401': { $ref: '#/components/responses/Unauthorized' },
                    '422': { $ref: '#/components/responses/ValidationError' },
                },
            },
        },
        '/v1/cells/{id}': {
            get: {
                tags: ['Cells'],
                summary: 'Buscar célula por ID',
                security: [{ bearerAuth: [] }],
                parameters: [
                    {
                        name: 'id',
                        in: 'path',
                        required: true,
                        schema: { type: 'string', format: 'uuid' },
                    },
                ],
                responses: {
                    '200': {
                        description: 'Dados da célula',
                        content: {
                            'application/json': {
                                schema: {
                                    type: 'object',
                                    properties: { cell: { $ref: '#/components/schemas/Cell' } },
                                },
                            },
                        },
                    },
                    '401': { $ref: '#/components/responses/Unauthorized' },
                    '404': { $ref: '#/components/responses/NotFound' },
                },
            },
        },
        // ── Attendance ───────────────────────────────────────────────────────────
        '/v1/attendance': {
            post: {
                tags: ['Attendance'],
                summary: 'Registrar presença',
                description: 'Registra ou atualiza a presença de um visitante em uma reunião (upsert por visitante + célula + data).',
                security: [{ bearerAuth: [] }],
                requestBody: {
                    required: true,
                    content: {
                        'application/json': {
                            schema: {
                                type: 'object',
                                required: ['visitorId', 'cellId', 'meetingDate'],
                                properties: {
                                    visitorId: { type: 'string', format: 'uuid' },
                                    cellId: { type: 'string', format: 'uuid' },
                                    meetingDate: {
                                        type: 'string',
                                        format: 'date',
                                        example: '2025-01-15',
                                        description: 'Data da reunião (ISO 8601)',
                                    },
                                    isPresent: { type: 'boolean', default: true },
                                    notes: { type: 'string', example: 'Chegou no final da reunião' },
                                },
                            },
                        },
                    },
                },
                responses: {
                    '201': {
                        description: 'Presença registrada',
                        content: {
                            'application/json': {
                                schema: {
                                    type: 'object',
                                    properties: { attendance: { $ref: '#/components/schemas/Attendance' } },
                                },
                            },
                        },
                    },
                    '401': { $ref: '#/components/responses/Unauthorized' },
                    '404': { $ref: '#/components/responses/NotFound' },
                    '422': { $ref: '#/components/responses/ValidationError' },
                },
            },
        },
        '/v1/attendance/cell/{cellId}': {
            get: {
                tags: ['Attendance'],
                summary: 'Listar presenças de uma célula por data',
                security: [{ bearerAuth: [] }],
                parameters: [
                    {
                        name: 'cellId',
                        in: 'path',
                        required: true,
                        schema: { type: 'string', format: 'uuid' },
                    },
                    {
                        name: 'date',
                        in: 'query',
                        description: 'Data da reunião (ISO 8601). Padrão: hoje',
                        schema: { type: 'string', format: 'date', example: '2025-01-15' },
                    },
                ],
                responses: {
                    '200': {
                        description: 'Lista de presenças',
                        content: {
                            'application/json': {
                                schema: {
                                    type: 'object',
                                    properties: {
                                        attendances: {
                                            type: 'array',
                                            items: { $ref: '#/components/schemas/Attendance' },
                                        },
                                    },
                                },
                            },
                        },
                    },
                    '401': { $ref: '#/components/responses/Unauthorized' },
                },
            },
        },
        // ── Spiritual History ────────────────────────────────────────────────────
        '/v1/spiritual-history': {
            post: {
                tags: ['Spiritual History'],
                summary: 'Registrar evento espiritual',
                description: 'Adiciona um marco na jornada espiritual do visitante (batismo, treinamento, liderança, etc.).',
                security: [{ bearerAuth: [] }],
                requestBody: {
                    required: true,
                    content: {
                        'application/json': {
                            schema: {
                                type: 'object',
                                required: ['visitorId', 'eventType', 'date'],
                                properties: {
                                    visitorId: { type: 'string', format: 'uuid' },
                                    eventType: {
                                        type: 'string',
                                        enum: [
                                            'enviado_batismo',
                                            'batizado',
                                            'enviado_treinamento_lider',
                                            'concluiu_treinamento',
                                            'tornou_se_lider',
                                        ],
                                        example: 'batizado',
                                    },
                                    description: { type: 'string', example: 'Batizado na água no culto especial' },
                                    date: { type: 'string', format: 'date', example: '2025-01-12' },
                                },
                            },
                        },
                    },
                },
                responses: {
                    '201': {
                        description: 'Evento registrado',
                        content: {
                            'application/json': {
                                schema: {
                                    type: 'object',
                                    properties: { event: { $ref: '#/components/schemas/SpiritualHistory' } },
                                },
                            },
                        },
                    },
                    '401': { $ref: '#/components/responses/Unauthorized' },
                    '404': { $ref: '#/components/responses/NotFound' },
                    '422': { $ref: '#/components/responses/ValidationError' },
                },
            },
        },
        '/v1/spiritual-history/visitor/{visitorId}': {
            get: {
                tags: ['Spiritual History'],
                summary: 'Histórico espiritual de um visitante',
                security: [{ bearerAuth: [] }],
                parameters: [
                    {
                        name: 'visitorId',
                        in: 'path',
                        required: true,
                        schema: { type: 'string', format: 'uuid' },
                    },
                ],
                responses: {
                    '200': {
                        description: 'Lista de eventos espirituais',
                        content: {
                            'application/json': {
                                schema: {
                                    type: 'object',
                                    properties: {
                                        history: {
                                            type: 'array',
                                            items: { $ref: '#/components/schemas/SpiritualHistory' },
                                        },
                                    },
                                },
                            },
                        },
                    },
                    '401': { $ref: '#/components/responses/Unauthorized' },
                },
            },
        },
        // ── Dashboard ────────────────────────────────────────────────────────────
        '/v1/dashboard/stats': {
            get: {
                tags: ['Dashboard'],
                summary: 'Estatísticas gerais (apenas ADMIN)',
                description: 'Retorna métricas consolidadas: total de visitantes, taxa de integração, células ativas, presença média.',
                security: [{ bearerAuth: [] }],
                responses: {
                    '200': {
                        description: 'Estatísticas do dashboard',
                        content: {
                            'application/json': {
                                schema: {
                                    type: 'object',
                                    properties: { stats: { $ref: '#/components/schemas/DashboardStats' } },
                                },
                            },
                        },
                    },
                    '401': { $ref: '#/components/responses/Unauthorized' },
                    '403': { $ref: '#/components/responses/Forbidden' },
                },
            },
        },
    },
};
