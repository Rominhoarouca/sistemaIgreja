import 'package:get_it/get_it.dart';
import '../core/network/auth_storage.dart';
import '../core/network/dio_client.dart';
import '../features/auth/data/datasources/auth_remote_datasource.dart';
import '../features/auth/data/repositories/auth_repository_impl.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';

final getIt = GetIt.instance;

/// Dependency injection setup.
Future<void> setupInjection() async {
  // ── Core ──────────────────────────────────────────────────────────────────
  final authStorage = AuthStorage();
  getIt.registerSingleton<AuthStorage>(authStorage);

  final dioClient = DioClient(authStorage);
  getIt.registerSingleton<DioClient>(dioClient);

  // ── Auth ──────────────────────────────────────────────────────────────────
  getIt.registerSingleton<AuthRemoteDatasource>(
    AuthRemoteDatasourceImpl(dioClient.dio),
  );

  getIt.registerSingleton<AuthRepository>(
    AuthRepositoryImpl(
      remote: getIt<AuthRemoteDatasource>(),
      storage: authStorage,
    ),
  );

  getIt.registerSingleton<AuthBloc>(
    AuthBloc(repository: getIt<AuthRepository>()),
  );

  // Wire force-logout from Dio interceptor → AuthBloc
  dioClient.onForceLogout = () {
    final bloc = getIt<AuthBloc>();
    if (!bloc.isClosed) bloc.add(const AuthForceLogout());
  };
}
