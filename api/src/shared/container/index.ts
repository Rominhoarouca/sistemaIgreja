import { PrismaClient } from '@prisma/client';

// Repositories
import { PrismaUserRepository } from '@infrastructure/database/repositories/PrismaUserRepository';
import { PrismaRefreshTokenRepository } from '@infrastructure/database/repositories/PrismaRefreshTokenRepository';
import { PrismaVisitorRepository } from '@infrastructure/database/repositories/PrismaVisitorRepository';
import { PrismaCellRepository } from '@infrastructure/database/repositories/PrismaCellRepository';
import { PrismaCellMemberRepository } from '@infrastructure/database/repositories/PrismaCellMemberRepository';
import { PrismaAttendanceRepository } from '@infrastructure/database/repositories/PrismaAttendanceRepository';
import { PrismaSpiritualHistoryRepository } from '@infrastructure/database/repositories/PrismaSpiritualHistoryRepository';
import { PrismaMaterialRepository } from '@infrastructure/database/repositories/PrismaMaterialRepository';

// Storage
import { MinioService } from '@infrastructure/storage/MinioService';

// Use Cases
import { LoginUseCase } from '@application/usecases/auth/LoginUseCase';
import { RefreshTokenUseCase } from '@application/usecases/auth/RefreshTokenUseCase';
import { RegisterUserUseCase } from '@application/usecases/auth/RegisterUserUseCase';
import { RegisterVisitorUseCase } from '@application/usecases/visitor/RegisterVisitorUseCase';
import { GetVisitorsUseCase } from '@application/usecases/visitor/GetVisitorsUseCase';
import { UpdateVisitorStatusUseCase } from '@application/usecases/visitor/UpdateVisitorStatusUseCase';
import { GetNearbyCellsUseCase } from '@application/usecases/cell/GetNearbyCellsUseCase';
import { RegisterAttendanceUseCase } from '@application/usecases/attendance/RegisterAttendanceUseCase';
import { AddSpiritualEventUseCase } from '@application/usecases/spiritual-history/AddSpiritualEventUseCase';
import { GetDashboardStatsUseCase } from '@application/usecases/dashboard/GetDashboardStatsUseCase';
import { UploadMaterialUseCase } from '@application/usecases/material/UploadMaterialUseCase';

// Controllers
import { AuthController } from '@infrastructure/http/controllers/AuthController';
import { VisitorController } from '@infrastructure/http/controllers/VisitorController';
import { CellController } from '@infrastructure/http/controllers/CellController';
import { AttendanceController } from '@infrastructure/http/controllers/AttendanceController';
import { SpiritualHistoryController } from '@infrastructure/http/controllers/SpiritualHistoryController';
import { DashboardController } from '@infrastructure/http/controllers/DashboardController';
import { MaterialController } from '@infrastructure/http/controllers/MaterialController';
import { UserController } from '@infrastructure/http/controllers/UserController';

// User use cases
import { GetProfileUseCase } from '@application/usecases/user/GetProfileUseCase';
import { UpdateProfileUseCase } from '@application/usecases/user/UpdateProfileUseCase';

export interface Container {
  prisma: PrismaClient;
  authController: AuthController;
  visitorController: VisitorController;
  cellController: CellController;
  attendanceController: AttendanceController;
  spiritualHistoryController: SpiritualHistoryController;
  dashboardController: DashboardController;
  materialController: MaterialController;
  userController: UserController;
}

export function createContainer(): Container {
  const prisma = new PrismaClient();

  // Storage
  const minioService = new MinioService();

  // Repositories
  const userRepo = new PrismaUserRepository(prisma);
  const refreshTokenRepo = new PrismaRefreshTokenRepository(prisma);
  const visitorRepo = new PrismaVisitorRepository(prisma);
  const cellRepo = new PrismaCellRepository(prisma);
  const cellMemberRepo = new PrismaCellMemberRepository(prisma);
  const attendanceRepo = new PrismaAttendanceRepository(prisma);
  const spiritualHistoryRepo = new PrismaSpiritualHistoryRepository(prisma);
  const materialRepo = new PrismaMaterialRepository(prisma);

  // Auth use cases
  const loginUseCase = new LoginUseCase(userRepo, refreshTokenRepo);
  const refreshTokenUseCase = new RefreshTokenUseCase(userRepo, refreshTokenRepo);
  const registerUserUseCase = new RegisterUserUseCase(userRepo);

  // Visitor use cases
  const registerVisitorUseCase = new RegisterVisitorUseCase(visitorRepo);
  const getVisitorsUseCase = new GetVisitorsUseCase(visitorRepo);
  const updateVisitorStatusUseCase = new UpdateVisitorStatusUseCase(visitorRepo);

  // Cell use cases
  const getNearbyCellsUseCase = new GetNearbyCellsUseCase(cellRepo);

  // Attendance use cases
  const registerAttendanceUseCase = new RegisterAttendanceUseCase(attendanceRepo, cellRepo);

  // Spiritual history use cases
  const addSpiritualEventUseCase = new AddSpiritualEventUseCase(spiritualHistoryRepo, visitorRepo);

  // Dashboard use cases
  const getDashboardStatsUseCase = new GetDashboardStatsUseCase(
    visitorRepo,
    cellRepo,
    attendanceRepo,
    userRepo,
  );

  // Material use cases
  const uploadMaterialUseCase = new UploadMaterialUseCase(materialRepo, minioService);

  // User use cases
  const getProfileUseCase = new GetProfileUseCase(userRepo, minioService);
  const updateProfileUseCase = new UpdateProfileUseCase(userRepo, minioService);

  // Controllers
  const authController = new AuthController(
    loginUseCase,
    refreshTokenUseCase,
    registerUserUseCase,
    refreshTokenRepo,
    userRepo,
  );
  const visitorController = new VisitorController(
    registerVisitorUseCase,
    getVisitorsUseCase,
    updateVisitorStatusUseCase,
    visitorRepo,
    cellMemberRepo,
  );
  const cellController = new CellController(getNearbyCellsUseCase, cellRepo, cellMemberRepo);
  const attendanceController = new AttendanceController(registerAttendanceUseCase, attendanceRepo);
  const spiritualHistoryController = new SpiritualHistoryController(addSpiritualEventUseCase, spiritualHistoryRepo);
  const dashboardController = new DashboardController(getDashboardStatsUseCase, visitorRepo);
  const materialController = new MaterialController(uploadMaterialUseCase, materialRepo, minioService, cellRepo);
  const userController = new UserController(getProfileUseCase, updateProfileUseCase, userRepo);

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

