import 'package:dartz/dartz.dart';
import '../../../../../core/errors/failures.dart';
import '../entities/cell_entity.dart';

abstract class CellRepository {
  Future<Either<Failure, List<CellEntity>>> getCells();
  Future<Either<Failure, CellEntity>> getCellById(String id);
  Future<Either<Failure, List<CellEntity>>> getNearbyCells({
    required double latitude,
    required double longitude,
    double radiusKm = 10.0,
  });
  Future<Either<Failure, CellEntity>> createCell(CellEntity cell);
  Future<Either<Failure, CellEntity>> updateCell(CellEntity cell);
  Future<Either<Failure, void>> deleteCell(String id);
  Future<Either<Failure, List<CellEntity>>> getCellsByLeader(String leaderId);
}
