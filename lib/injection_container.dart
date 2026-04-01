import 'package:ai_health/features/barcode_food/data/datasources/food_barcode_remote_datasource.dart';
import 'package:ai_health/features/barcode_food/data/repositories/food_barcode_repository_impl.dart';
import 'package:ai_health/features/barcode_food/domain/repositories/food_barcode_repository.dart';
import 'package:dio/dio.dart';

late final FoodBarcodeRepository foodBarcodeRepository;

void initDependencies() {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  final remote = FoodBarcodeRemoteDataSource(dio);
  foodBarcodeRepository = FoodBarcodeRepositoryImpl(remote);
}
