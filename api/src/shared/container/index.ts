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
import { AlbumController } from '@infrastructure/http/controllers/AlbumController';
import { GetAlbumUseCase } from '@application/usecases/album/GetAlbumUseCase';
import { PrismaAlbumRepository } from '@infrastructure/database/repositories/PrismaAlbumRepository';
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
import { PrismaNotificationRepository } from '@infrastructure/database/repositories/PrismaNotificationRepository';
import { PrismaKidsRepository } from '@infrastructure/database/repositories/PrismaKidsRepository';

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
import { CreateNotificationUseCase } from '@application/usecases/notification/CreateNotificationUseCase';
import { UpdateNotificationUseCase } from '@application/usecases/notification/UpdateNotificationUseCase';
import { CheckInChildrenUseCase } from '@application/usecases/kids/CheckInChildrenUseCase';
import { CheckOutChildUseCase } from '@application/usecases/kids/CheckOutChildUseCase';
import { CreateAlertUseCase } from '@application/usecases/kids/CreateAlertUseCase';
import { KidsQrService } from '@application/services/KidsQrService';
import { PickupCodeService } from '@application/services/PickupCodeService';
import {
  InAppAlertChannel,
  PushAlertChannel,
  KidsAlertDispatcher,
  ManualCallChannel,
  WhatsappAlertChannel,
} from '@application/services/KidsAlertDispatcher';

// Controllers
import { AuthController } from '@infrastructure/http/controllers/AuthController';
import { VisitorController } from '@infrastructure/http/controllers/VisitorController';
import { CellController } from '@infrastructure/http/controllers/CellController';
import { AttendanceController } from '@infrastructure/http/controllers/AttendanceController';
import { SpiritualHistoryController } from '@infrastructure/http/controllers/SpiritualHistoryController';
import { DashboardController } from '@infrastructure/http/controllers/DashboardController';
import { MaterialController } from '@infrastructure/http/controllers/MaterialController';
import { UserController } from '@infrastructure/http/controllers/UserController';
import { DeviceController } from '@infrastructure/http/controllers/DeviceController';
import { FcmSender } from '@application/services/FcmSender';
import { AckNotifier } from '@application/services/AckNotifier';
import { CoordenacaoController } from '@infrastructure/http/controllers/CoordenacaoController';
import { LocationController } from '@infrastructure/http/controllers/LocationController';
import { CellTypeController } from '@infrastructure/http/controllers/CellTypeController';
import { NotificationController } from '@infrastructure/http/controllers/NotificationController';
import { KidsController } from '@infrastructure/http/controllers/KidsController';
import { makeRequireRoomAccess } from '@infrastructure/http/middlewares/kids.middleware';

// User use cases
import { GetProfileUseCase } from '@application/usecases/user/GetProfileUseCase';
import { UpdateProfileUseCase } from '@application/usecases/user/UpdateProfileUseCase';

export interface Container {
  prisma: PrismaClient;
  minioService: MinioService;
  authController: AuthController;
  visitorController: VisitorController;
  cellController: CellController;
  cellTypeController: CellTypeController;
  attendanceController: AttendanceController;
  albumController: AlbumController;
  spiritualHistoryController: SpiritualHistoryController;
  dashboardController: DashboardController;
  materialController: MaterialController;
  userController: UserController;
  deviceController: DeviceController;
  coordenacaoController: CoordenacaoController;
  locationController: LocationController;
  notificationController: NotificationController;
  kidsController: KidsController;
  requireRoomAccess: ReturnType<typeof makeRequireRoomAccess>;
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
  const notificationRepo = new PrismaNotificationRepository(prisma);
  const kidsRepo = new PrismaKidsRepository(prisma);
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
  const addSpiritualEventUseCase = new AddSpiritualEventUseCase(spiritualHistoryRepo, visitorRepo, cellMemberRepo);

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

  // Notification use cases
  const createNotificationUseCase = new CreateNotificationUseCase(notificationRepo, minioService);
  const updateNotificationUseCase = new UpdateNotificationUseCase(notificationRepo, minioService);

  // Kids
  const kidsQrService = new KidsQrService(prisma);
  const pickupCodeService = new PickupCodeService();
  // Ordem dos canais não importa: o dispatcher escolhe pelo tipo da entrega.
  // O canal in-app é o único que funciona sem credencial externa; o WhatsApp
  // registra FAILED com o motivo enquanto a Cloud API não estiver configurada.
  const fcmSender = new FcmSender();
  const inAppChannel = new InAppAlertChannel(prisma);
  const kidsAlertDispatcher = new KidsAlertDispatcher(kidsRepo, [
    // PushAlertChannel antes: o dispatcher usa o primeiro canal que casa, e
    // este faz in-app + FCM. O InAppAlertChannel puro fica como dependência
    // dele, não mais como canal registrado.
    new PushAlertChannel(prisma, inAppChannel, fcmSender),
    new WhatsappAlertChannel(),
    new ManualCallChannel(),
  ]);
  const checkInChildrenUseCase = new CheckInChildrenUseCase(kidsRepo, pickupCodeService);
  const checkOutChildUseCase = new CheckOutChildUseCase(
    kidsRepo,
    pickupCodeService,
    kidsQrService,
  );
  const createKidsAlertUseCase = new CreateAlertUseCase(kidsRepo, kidsAlertDispatcher);
  const requireRoomAccess = makeRequireRoomAccess(kidsRepo);

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
    minioService,
  );
  const cellController = new CellController(
    getNearbyCellsUseCase,
    cellRepo,
    cellMemberRepo,
    userRepo,
    minioService,
  );
  const attendanceController = new AttendanceController(registerAttendanceUseCase, attendanceRepo, minioService);
  const spiritualHistoryController = new SpiritualHistoryController(addSpiritualEventUseCase, spiritualHistoryRepo);
  const dashboardController = new DashboardController(
    getDashboardStatsUseCase,
    visitorRepo,
    attendanceRepo,
    getDemographicsUseCase,
  );
  const albumRepo = new PrismaAlbumRepository(prisma);
  const albumController = new AlbumController(
    new GetAlbumUseCase(albumRepo, minioService),
  );
  const materialController = new MaterialController(uploadMaterialUseCase, materialRepo, minioService, cellRepo, prisma);
  const userController = new UserController(getProfileUseCase, updateProfileUseCase, userRepo, kidsRepo);
  const deviceController = new DeviceController(prisma);
  const coordenacaoController = new CoordenacaoController(coordenacaoRepo, userRepo);
  const locationController = new LocationController(locationRepo);
  const cellTypeController = new CellTypeController(prisma);
  const ackNotifier = new AckNotifier(prisma, fcmSender);
  const kidsController = new KidsController(
    kidsRepo,
    checkInChildrenUseCase,
    checkOutChildUseCase,
    createKidsAlertUseCase,
    kidsQrService,
    pickupCodeService,
    ackNotifier,
  );
  const notificationController = new NotificationController(
    createNotificationUseCase,
    updateNotificationUseCase,
    notificationRepo,
    minioService,
    prisma,
  );

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
    paymentGateway,
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
    minioService,
    authController,
    visitorController,
    cellController,
    cellTypeController,
    attendanceController,
    albumController,
    spiritualHistoryController,
    dashboardController,
    materialController,
    userController,
    deviceController,
    coordenacaoController,
    locationController,
    notificationController,
    kidsController,
    requireRoomAccess,
    churchController,
    planController,
    billingController,
    signupController,
    superAdminController,
    requireFeature,
    publicTenantRequired,
  };
}

