"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.createContainer = createContainer;
const client_1 = require("@prisma/client");
// Repositories
const PrismaUserRepository_1 = require("@infrastructure/database/repositories/PrismaUserRepository");
const PrismaRefreshTokenRepository_1 = require("@infrastructure/database/repositories/PrismaRefreshTokenRepository");
const PrismaVisitorRepository_1 = require("@infrastructure/database/repositories/PrismaVisitorRepository");
const PrismaCellRepository_1 = require("@infrastructure/database/repositories/PrismaCellRepository");
const PrismaCellMemberRepository_1 = require("@infrastructure/database/repositories/PrismaCellMemberRepository");
const PrismaAttendanceRepository_1 = require("@infrastructure/database/repositories/PrismaAttendanceRepository");
const PrismaSpiritualHistoryRepository_1 = require("@infrastructure/database/repositories/PrismaSpiritualHistoryRepository");
const PrismaMaterialRepository_1 = require("@infrastructure/database/repositories/PrismaMaterialRepository");
// Storage
const MinioService_1 = require("@infrastructure/storage/MinioService");
// Use Cases
const LoginUseCase_1 = require("@application/usecases/auth/LoginUseCase");
const RefreshTokenUseCase_1 = require("@application/usecases/auth/RefreshTokenUseCase");
const RegisterUserUseCase_1 = require("@application/usecases/auth/RegisterUserUseCase");
const RegisterVisitorUseCase_1 = require("@application/usecases/visitor/RegisterVisitorUseCase");
const GetVisitorsUseCase_1 = require("@application/usecases/visitor/GetVisitorsUseCase");
const UpdateVisitorStatusUseCase_1 = require("@application/usecases/visitor/UpdateVisitorStatusUseCase");
const GetNearbyCellsUseCase_1 = require("@application/usecases/cell/GetNearbyCellsUseCase");
const RegisterAttendanceUseCase_1 = require("@application/usecases/attendance/RegisterAttendanceUseCase");
const AddSpiritualEventUseCase_1 = require("@application/usecases/spiritual-history/AddSpiritualEventUseCase");
const GetDashboardStatsUseCase_1 = require("@application/usecases/dashboard/GetDashboardStatsUseCase");
const UploadMaterialUseCase_1 = require("@application/usecases/material/UploadMaterialUseCase");
// Controllers
const AuthController_1 = require("@infrastructure/http/controllers/AuthController");
const VisitorController_1 = require("@infrastructure/http/controllers/VisitorController");
const CellController_1 = require("@infrastructure/http/controllers/CellController");
const AttendanceController_1 = require("@infrastructure/http/controllers/AttendanceController");
const SpiritualHistoryController_1 = require("@infrastructure/http/controllers/SpiritualHistoryController");
const DashboardController_1 = require("@infrastructure/http/controllers/DashboardController");
const MaterialController_1 = require("@infrastructure/http/controllers/MaterialController");
const UserController_1 = require("@infrastructure/http/controllers/UserController");
// User use cases
const GetProfileUseCase_1 = require("@application/usecases/user/GetProfileUseCase");
const UpdateProfileUseCase_1 = require("@application/usecases/user/UpdateProfileUseCase");
function createContainer() {
    const prisma = new client_1.PrismaClient();
    // Storage
    const minioService = new MinioService_1.MinioService();
    // Repositories
    const userRepo = new PrismaUserRepository_1.PrismaUserRepository(prisma);
    const refreshTokenRepo = new PrismaRefreshTokenRepository_1.PrismaRefreshTokenRepository(prisma);
    const visitorRepo = new PrismaVisitorRepository_1.PrismaVisitorRepository(prisma);
    const cellRepo = new PrismaCellRepository_1.PrismaCellRepository(prisma);
    const cellMemberRepo = new PrismaCellMemberRepository_1.PrismaCellMemberRepository(prisma);
    const attendanceRepo = new PrismaAttendanceRepository_1.PrismaAttendanceRepository(prisma);
    const spiritualHistoryRepo = new PrismaSpiritualHistoryRepository_1.PrismaSpiritualHistoryRepository(prisma);
    const materialRepo = new PrismaMaterialRepository_1.PrismaMaterialRepository(prisma);
    // Auth use cases
    const loginUseCase = new LoginUseCase_1.LoginUseCase(userRepo, refreshTokenRepo);
    const refreshTokenUseCase = new RefreshTokenUseCase_1.RefreshTokenUseCase(userRepo, refreshTokenRepo);
    const registerUserUseCase = new RegisterUserUseCase_1.RegisterUserUseCase(userRepo);
    // Visitor use cases
    const registerVisitorUseCase = new RegisterVisitorUseCase_1.RegisterVisitorUseCase(visitorRepo);
    const getVisitorsUseCase = new GetVisitorsUseCase_1.GetVisitorsUseCase(visitorRepo);
    const updateVisitorStatusUseCase = new UpdateVisitorStatusUseCase_1.UpdateVisitorStatusUseCase(visitorRepo);
    // Cell use cases
    const getNearbyCellsUseCase = new GetNearbyCellsUseCase_1.GetNearbyCellsUseCase(cellRepo);
    // Attendance use cases
    const registerAttendanceUseCase = new RegisterAttendanceUseCase_1.RegisterAttendanceUseCase(attendanceRepo, cellRepo);
    // Spiritual history use cases
    const addSpiritualEventUseCase = new AddSpiritualEventUseCase_1.AddSpiritualEventUseCase(spiritualHistoryRepo, visitorRepo);
    // Dashboard use cases
    const getDashboardStatsUseCase = new GetDashboardStatsUseCase_1.GetDashboardStatsUseCase(visitorRepo, cellRepo, attendanceRepo, userRepo);
    // Material use cases
    const uploadMaterialUseCase = new UploadMaterialUseCase_1.UploadMaterialUseCase(materialRepo, minioService);
    // User use cases
    const getProfileUseCase = new GetProfileUseCase_1.GetProfileUseCase(userRepo, minioService);
    const updateProfileUseCase = new UpdateProfileUseCase_1.UpdateProfileUseCase(userRepo, minioService);
    // Controllers
    const authController = new AuthController_1.AuthController(loginUseCase, refreshTokenUseCase, registerUserUseCase, refreshTokenRepo, userRepo);
    const visitorController = new VisitorController_1.VisitorController(registerVisitorUseCase, getVisitorsUseCase, updateVisitorStatusUseCase, visitorRepo, cellMemberRepo);
    const cellController = new CellController_1.CellController(getNearbyCellsUseCase, cellRepo, cellMemberRepo);
    const attendanceController = new AttendanceController_1.AttendanceController(registerAttendanceUseCase, attendanceRepo);
    const spiritualHistoryController = new SpiritualHistoryController_1.SpiritualHistoryController(addSpiritualEventUseCase, spiritualHistoryRepo);
    const dashboardController = new DashboardController_1.DashboardController(getDashboardStatsUseCase, visitorRepo);
    const materialController = new MaterialController_1.MaterialController(uploadMaterialUseCase, materialRepo, minioService);
    const userController = new UserController_1.UserController(getProfileUseCase, updateProfileUseCase, userRepo);
    return {
        prisma,
        authController,
        visitorController,
        cellController,
        attendanceController,
        spiritualHistoryController,
        dashboardController,
        materialController,
        userController,
    };
}
