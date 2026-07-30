import { PrismaClient } from '@prisma/client';
import { applyTenantGuard } from '@infrastructure/database/tenant-guard';
import { makePublicTenantMiddleware } from '@infrastructure/http/middlewares/public-tenant.middleware';

// SaaS repositories
import { PrismaChurchRepository } from '@infrastructure/database/repositories/PrismaChurchRepository';
import { PrismaPlanRepository } from '@infrastructure/database/repositories/PrismaPlanRepository';
import { PrismaSubscriptionRepository } from '@infrastructure/database/repositories/PrismaSubscriptionRepository';

// SaaS services + billing
import { FeatureResolver } from '@application/services/FeatureResolver';
import { createPaymentGateway } from '@infrastructure/billing/PaymentGatewayFactory';

// SaaS use cases
import { UpdateChurchUseCase } from '@application/usecases/church/UpdateChurchUseCase';
import { UploadChurchLogoUseCase } from '@application/usecases/church/UploadChurchLogoUseCase';
import { GetChurchContextUseCase } from '@application/usecases/church/GetChurchContextUseCase';
import { GetPublicChurchUseCase } from '@application/usecases/church/GetPublicChurchUseCase';
import { AssignPlanManuallyUseCase } from '@application/usecases/billing/AssignPlanManuallyUseCase';
import { CreateCheckoutUseCase } from '@application/usecases/billing/CreateCheckoutUseCase';
import { HandleWebhookUseCase } from '@application/usecases/billing/HandleWebhookUseCase';
import { RegisterChurchUseCase } from '@application/usecases/signup/RegisterChurchUseCase';
import { GetSaasUsageUseCase } from '@application/usecases/church/GetSaasUsageUseCase';

// SaaS controllers
import { ChurchController } from '@infrastructure/http/controllers/ChurchController';
import { PlanController } from '@infrastructure/http/controllers/PlanController';
import { BillingController } from '@infrastructure/http/controllers/BillingController';
import { SignupController } from '@infrastructure/http/controllers/SignupController';
import { SuperAdminController } from '@infrastructure/http/controllers/SuperAdminController';
import { makeRequireFeature } from '@infrastructure/http/middlewares/feature.middleware';

// Repositories
import { PrismaUserRepository } from '@infrastructure/database/repositories/PrismaUserRepository';
import { PrismaRefreshTokenRepository } from '@infrastructure/database/repositories/PrismaRefreshTokenRepository';
import { PrismaVisitorRepository } from '@infrastructure/database/repositories/PrismaVisitorRepository';
import { PrismaCellRepository } from '@infrastructure/database/repositories/PrismaCellRepository';
import { PrismaCellMemberRepository } from '@infrastructure/database/repositories/PrismaCellMemberRepository';
import { PrismaDemographicsRepository } from '@infrastructure/database/repositories/PrismaDemographicsRepository';
import { PrismaAttendanceRepository } from '@infrastructure/database/repositories/PrismaAttendanceRepository';
import { PrismaSpiritualHistoryRepository } from '@infrastructure/database/repositories/PrismaSpiritualHistoryRepository';
import { PrismaMaterialRepository } from '@infrastructure/database/repositories/PrismaMaterialRepository';
import { PrismaCoordenacaoRepository } from '@infrastructure/database/repositories/PrismaCoordenacaoRepository';
import { PrismaLocationRepository } from '@infrastructure/database/repositories/PrismaLocationRepository';

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
import { GetDemographicsUseCase } from '@application/usecases/dashboard/GetDemographicsUseCase';
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
import { CoordenacaoController } from '@infrastructure/http/controllers/CoordenacaoController';
import { LocationController } from '@infrastructure/http/controllers/LocationController';
import { CellTypeController } from '@infrastructure/http/controllers/CellTypeController';

// User use cases
import { GetProfileUseCase } from '@application/usecases/user/GetProfileUseCase';
import { UpdateProfileUseCase } from '@application/usecases/user/UpdateProfileUseCase';

export interface Container {
  prisma: PrismaClient;
  authController: AuthController;
  visitorController: VisitorController;
  cellController: CellController;
  cellTypeController: CellTypeController;
  attendanceController: AttendanceController;
  spiritualHistoryController: SpiritualHistoryController;
  dashboardController: DashboardController;
  materialController: MaterialController;
  userController: UserController;
  coordenacaoController: CoordenacaoController;
  locationController: LocationController;
  churchController: ChurchController;
  planController: PlanController;
  billingController: BillingController;
  signupController: SignupController;
  superAdminController: SuperAdminController;
  requireFeature: ReturnType<typeof makeRequireFeature>;
  publicTenantRequired: ReturnType<typeof makePublicTenantMiddleware>;
}

export function createContainer(): Container {
  const prisma = new PrismaClient();
  // Guard-rail multi-tenant: injeta church_id automaticamente por contexto.
  applyTenantGuard(prisma);

  // Storage
  const minioService = new MinioService();

  // Repositories
  const userRepo = new PrismaUserRepository(prisma);
  const refreshTokenRepo = new PrismaRefreshTokenRepository(prisma);
  const visitorRepo = new PrismaVisitorRepository(prisma);
  const cellRepo = new PrismaCellRepository(prisma);
  const cellMemberRepo = new PrismaCellMemberRepository(prisma);
  const demographicsRepo = new PrismaDemographicsRepository(prisma);
  const attendanceRepo = new PrismaAttendanceRepository(prisma);
  const spiritualHistoryRepo = new PrismaSpiritualHistoryRepository(prisma);
  const materialRepo = new PrismaMaterialRepository(prisma);
  const coordenacaoRepo = new PrismaCoordenacaoRepository(prisma);
  const locationRepo = new PrismaLocationRepository(prisma);
  const churchRepo = new PrismaChurchRepository(prisma);
  const planRepo = new PrismaPlanRepository(prisma);
  const subscriptionRepo = new PrismaSubscriptionRepository(prisma);

  // Tenant público: resolve a igreja pelo slug em rotas sem login.
  // Obrigatório na escrita (auto-cadastro) para o registro não nascer órfão.
  const publicTenantRequired = makePublicTenantMiddleware(churchRepo, { required: true });

  // SaaS services
  const featureResolver = new FeatureResolver(prisma);
  const paymentGateway = createPaymentGateway();
  const requireFeature = makeRequireFeature(featureResolver);

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
  const getDemographicsUseCase = new GetDemographicsUseCase(demographicsRepo);

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
  const attendanceController = new AttendanceController(registerAttendanceUseCase, attendanceRepo, minioService);
  const spiritualHistoryController = new SpiritualHistoryController(addSpiritualEventUseCase, spiritualHistoryRepo);
  const dashboardController = new DashboardController(
    getDashboardStatsUseCase,
    visitorRepo,
    attendanceRepo,
    getDemographicsUseCase,
  );
  const materialController = new MaterialController(uploadMaterialUseCase, materialRepo, minioService, cellRepo, prisma);
  const userController = new UserController(getProfileUseCase, updateProfileUseCase, userRepo);
  const coordenacaoController = new CoordenacaoController(coordenacaoRepo, userRepo);
  const locationController = new LocationController(locationRepo);
  const cellTypeController = new CellTypeController(prisma);

  // SaaS use cases
  const updateChurchUseCase = new UpdateChurchUseCase(churchRepo);
  const uploadChurchLogoUseCase = new UploadChurchLogoUseCase(churchRepo, minioService);
  const getChurchContextUseCase = new GetChurchContextUseCase(churchRepo, subscriptionRepo, minioService);
  const getPublicChurchUseCase = new GetPublicChurchUseCase(churchRepo, minioService);
  const assignPlanManuallyUseCase = new AssignPlanManuallyUseCase(
    churchRepo,
    planRepo,
    subscriptionRepo,
    featureResolver,
  );
  const createCheckoutUseCase = new CreateCheckoutUseCase(
    churchRepo,
    planRepo,
    subscriptionRepo,
    paymentGateway,
  );
  const handleWebhookUseCase = new HandleWebhookUseCase(
    subscriptionRepo,
    paymentGateway,
    featureResolver,
  );
  const registerChurchUseCase = new RegisterChurchUseCase(prisma);
  const getSaasUsageUseCase = new GetSaasUsageUseCase(prisma, minioService);

  // SaaS controllers
  const churchController = new ChurchController(
    updateChurchUseCase,
    uploadChurchLogoUseCase,
    getChurchContextUseCase,
    getPublicChurchUseCase,
  );
  const planController = new PlanController(planRepo, featureResolver);
  const billingController = new BillingController(
    assignPlanManuallyUseCase,
    createCheckoutUseCase,
    handleWebhookUseCase,
  );
  const signupController = new SignupController(registerChurchUseCase, loginUseCase);
  const superAdminController = new SuperAdminController(
    churchRepo,
    subscriptionRepo,
    registerChurchUseCase,
    getSaasUsageUseCase,
  );

  return {
    prisma,
    authController,
    visitorController,
    cellController,
    cellTypeController,
    attendanceController,
    spiritualHistoryController,
    dashboardController,
    materialController,
    userController,
    coordenacaoController,
    locationController,
    churchController,
    planController,
    billingController,
    signupController,
    superAdminController,
    requireFeature,
    publicTenantRequired,
  };
}

