"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.PrismaRefreshTokenRepository = void 0;
class PrismaRefreshTokenRepository {
    prisma;
    constructor(prisma) {
        this.prisma = prisma;
    }
    async create(data) {
        return this.prisma.refreshToken.create({ data });
    }
    async findByToken(token) {
        return this.prisma.refreshToken.findUnique({ where: { token } });
    }
    async deleteByToken(token) {
        await this.prisma.refreshToken.deleteMany({ where: { token } });
    }
    async deleteByUserId(userId) {
        await this.prisma.refreshToken.deleteMany({ where: { userId } });
    }
}
exports.PrismaRefreshTokenRepository = PrismaRefreshTokenRepository;
