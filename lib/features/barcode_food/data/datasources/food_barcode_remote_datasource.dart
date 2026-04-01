import 'package:dio/dio.dart';

import 'package:ai_health/features/barcode_food/data/datasources/barcode_exceptions.dart';
import 'package:ai_health/features/barcode_food/data/models/barcode_food_model.dart';

class FoodBarcodeRemoteDataSource {
  final Dio _dio;

  FoodBarcodeRemoteDataSource(this._dio);

  // Nguồn 1: Open Food Facts
  Future<BarcodeFoodModel> fetchFromOpenFoodFacts(String barcode) async {
    final response = await _dio.get(
      'https://world.openfoodfacts.org/api/v0/product/$barcode.json',
    );

    final data = response.data;
    if (data is! Map) {
      throw const ProductNotFoundException();
    }

    if (data['status'] == 0 || data['product'] == null) {
      throw const ProductNotFoundException();
    }

    return BarcodeFoodModel.fromOpenFoodFacts(
      (data['product'] as Map).cast<String, dynamic>(),
      scannedBarcode: barcode,
    );
  }
}
