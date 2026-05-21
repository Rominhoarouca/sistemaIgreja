import 'package:equatable/equatable.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

/// Check stored tokens and restore session on app start.
class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

/// User submitted login credentials.
class AuthLoginRequested extends AuthEvent {
  const AuthLoginRequested({required this.email, required this.password});

  final String email;
  final String password;

  @override
  List<Object?> get props => [email, password];
}

/// User submitted registration form.
class AuthRegisterRequested extends AuthEvent {
  const AuthRegisterRequested({
    required this.name,
    required this.email,
    required this.password,
  });

  final String name;
  final String email;
  final String password;

  @override
  List<Object?> get props => [name, email, password];
}

/// User tapped logout.
class AuthLogoutRequested extends AuthEvent {
  const AuthLogoutRequested();
}

/// Triggered by the Dio interceptor when the refresh token is invalid/expired.
class AuthForceLogout extends AuthEvent {
  const AuthForceLogout();
}
