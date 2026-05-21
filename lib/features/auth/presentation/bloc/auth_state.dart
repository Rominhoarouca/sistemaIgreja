import 'package:equatable/equatable.dart';
import '../../domain/entities/user_entity.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

/// Initial state before the auth check runs.
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// An async operation is in progress.
class AuthLoading extends AuthState {
  const AuthLoading();
}

/// User is authenticated.
class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);

  final UserEntity user;

  @override
  List<Object?> get props => [user];
}

/// User is not authenticated (never logged in, logged out, or session expired).
class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// An error occurred during login or register.
class AuthError extends AuthState {
  const AuthError(this.message);

  final String message;

  @override
  List<Object?> get props => [message];
}
