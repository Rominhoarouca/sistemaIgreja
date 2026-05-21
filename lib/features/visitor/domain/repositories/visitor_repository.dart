import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../entities/visitor_entity.dart';

abstract class VisitorRepository {
  Future<Either<Failure, VisitorEntity>> registerVisitor(VisitorEntity visitor);
  Future<Either<Failure, List<VisitorEntity>>> getVisitors({
    int page = 1,
    int limit = 20,
  });
  Future<Either<Failure, VisitorEntity>> getVisitorById(String id);
  Future<Either<Failure, VisitorEntity>> updateVisitorStatus({
    required String id,
    required VisitorStatus status,
  });
  Future<Either<Failure, List<VisitorEntity>>> getVisitorsByLeader(
    String leaderId,
  );
  Future<Either<Failure, int>> getVisitorCount();
}
