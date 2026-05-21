import 'package:dartz/dartz.dart';
import '../errors/failures.dart';

/// Base use case with single param
abstract class UseCase<T, Params> {
  Future<Either<Failure, T>> call(Params params);
}

/// Base use case with no params
abstract class UseCaseNoParams<T> {
  Future<Either<Failure, T>> call();
}

/// No-params placeholder
class NoParams {
  const NoParams();
}
