import 'package:ai_health/features/barcode_food/domain/entities/barcode_food.dart';
import 'package:ai_health/features/barcode_food/domain/failures/barcode_failure.dart';

import 'package:ai_health/shared/either.dart';

abstract class FoodBarcodeRepository {
  /// Lấy thông tin thực phẩm từ mã vạch
  Future<Either<BarcodeFailure, BarcodeFood>> lookupBarcode(String barcode);
}