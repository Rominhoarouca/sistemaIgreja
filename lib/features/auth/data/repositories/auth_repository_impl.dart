import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/network/auth_storage.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDatasource _remote;
  final AuthStorage _storage;

  AuthRepositoryImpl({
    required AuthRemoteDatasource remote,
    required AuthStorage storage,
  }) : _remote = remote,
       _storage = storage;

  @override
  Future<Either<Failure, UserEntity>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _remote.login(email: email, password: password);
      await _storage.saveTokens(
        access: response.accessToken,
        refresh: response.refreshToken,
      );
      await _storage.saveUserProfile(response.user.toJsonString());
      return Right(response.user);
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _remote.register(
        name: name,
        email: email,
        password: password,
      );
      await _storage.saveTokens(
        access: response.accessToken,
        refresh: response.refreshToken,
      );
      await _storage.saveUserProfile(response.user.toJsonString());
      return Right(response.user);
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() async {
    try {
      final hasToken = await _storage.hasAccessToken();
      if (!hasToken) return const Left(AuthFailure());

      final profileJson = await _storage.getUserProfile();
      if (profileJson != null) {
        return Right(UserModel.fromJsonString(profileJson));
      }

      final user = await _remote.getMe();
      await _storage.saveUserProfile(user.toJsonString());
      return Right(user);
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    await _storage.clear();
    return const Right(null);
  }

  @override
  Future<Either<Failure, String>> refreshToken() async {
    // Handled transparently by DioClient interceptor.
    return const Left(AuthFailure('Refresh handled by interceptor.'));
  }

  @override
  Future<Either<Failure, void>> forgotPassword(String email) async {
    return const Left(
      ServerFailure('Funcionalidade não disponível no momento.'),
    );
  }

  @override
  Future<Either<Failure, void>> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    return const Left(
      ServerFailure('Funcionalidade não disponível no momento.'),
    );
  }

  Failure _mapError(Object error) {
    if (error is DioException) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 401) return const AuthFailure();
      if (statusCode == 409) {
        final message = error.response?.data is Map<String, dynamic>
            ? (error.response!.data['message'] as String? ??
                  'E-mail já cadastrado.')
            : 'E-mail já cadastrado.';
        return ValidationFailure(message);
      }
      if (statusCode != null && statusCode >= 500) {
        return const ServerFailure();
      }
      final message = error.response?.data is Map<String, dynamic>
          ? (error.response!.data['message'] as String? ?? 'Erro no servidor.')
          : 'Erro no servidor.';
      return ServerFailure(message);
    }
    if (error.toString().contains('SocketException') ||
        error.toString().contains('HandshakeException')) {
      return const NetworkFailure();
    }
    return const ServerFailure();
  }
}
