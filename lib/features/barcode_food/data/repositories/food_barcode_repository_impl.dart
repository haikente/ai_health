import 'package:dio/dio.dart';

import 'package:ai_health/features/barcode_food/data/datasources/barcode_exceptions.dart';
import 'package:ai_health/features/barcode_food/data/datasources/food_barcode_remote_datasource.dart';
import 'package:ai_health/features/barcode_food/domain/entities/barcode_food.dart';
import 'package:ai_health/features/barcode_food/domain/failures/barcode_failure.dart';
import 'package:ai_health/features/barcode_food/domain/repositories/food_barcode_repository.dart';
import 'package:ai_health/shared/either.dart';

class FoodBarcodeRepositoryImpl implements FoodBarcodeRepository {
  final FoodBarcodeRemoteDataSource _remote;

  FoodBarcodeRepositoryImpl(this._remote);

  @override
  Future<Either<BarcodeFailure, BarcodeFood>> lookupBarcode(
    String barcode,
  ) async {
    try {
      final food = await _remote.fetchFromOpenFoodFacts(barcode);
      return Either.right(food.toEntity());
    } on ProductNotFoundException {
      return const Either.left(ProductNotFoundFailure());
    } on DioException catch (e) {
      return Either.left(_mapDioError(e));
    }
  }

  BarcodeFailure _mapDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return const NetworkFailure();
      default:
        return const ServerFailure();
    }
  }
}
