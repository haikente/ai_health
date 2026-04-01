import 'package:ai_health/features/barcode_food/domain/entities/barcode_food.dart';

class BarcodeFoodModel {
  final String barcode;
  final String name;
  final String? brand;
  final String? imageUrl;
  final double? calories;
  final double? protein;
  final double? carbs;
  final double? fat;
  final double? fiber;
  final String? servingSize;
  final String source;

  const BarcodeFoodModel({
    required this.barcode,
    required this.name,
    required this.source,
    this.brand,
    this.imageUrl,
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.fiber,
    this.servingSize,
  });

  BarcodeFood toEntity() => BarcodeFood(
        barcode: barcode,
        name: name,
        brand: brand,
        imageUrl: imageUrl,
        calories: calories ?? 0,
        protein: protein ?? 0,
        carbs: carbs ?? 0,
        fat: fat ?? 0,
        fiber: fiber,
        servingSize: servingSize ?? 'Unknown',
        source: source,
      );

  static String _asString(dynamic v) => (v == null) ? '' : v.toString();

  static double? _asDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final parsed = double.tryParse(v.toString());
    return parsed;
  }

  /// Open Food Facts: https://world.openfoodfacts.org/api/v0/product/{barcode}.json
  /// [scannedBarcode] là mã vạch từ camera — dùng làm fallback nếu API không trả về "code".
  factory BarcodeFoodModel.fromOpenFoodFacts(
    Map<String, dynamic> product, {
    required String scannedBarcode,
  }) {
    final nutriments = (product['nutriments'] is Map)
        ? (product['nutriments'] as Map).cast<String, dynamic>()
        : <String, dynamic>{};

    // OFF thường có thể trả "energy-kcal_100g", "energy-kcal_serving"...
    final calories = _asDouble(
          nutriments['energy-kcal_serving'],
        ) ??
        _asDouble(nutriments['energy-kcal_100g']);

    // Macro thường dạng *_serving hoặc *_100g
    double? pickNutrient(String base) {
      return _asDouble(nutriments['${base}_serving']) ??
          _asDouble(nutriments['${base}_100g']);
    }

    final name = _asString(product['product_name']).trim().isNotEmpty
        ? _asString(product['product_name']).trim()
        : (_asString(product['generic_name']).trim().isNotEmpty
            ? _asString(product['generic_name']).trim()
            : 'Unknown product');

    final codeFromApi = _asString(product['code']).trim();

    return BarcodeFoodModel(
      barcode: codeFromApi.isNotEmpty ? codeFromApi : scannedBarcode,
      name: name,
      brand: _asString(product['brands']).trim().isEmpty
          ? null
          : _asString(product['brands']).trim(),
      imageUrl: _asString(product['image_url']).trim().isEmpty
          ? null
          : _asString(product['image_url']).trim(),
      calories: calories,
      protein: pickNutrient('proteins'),
      carbs: pickNutrient('carbohydrates'),
      fat: pickNutrient('fat'),
      fiber: pickNutrient('fiber'),
      servingSize: _asString(product['serving_size']).trim().isEmpty
          ? null
          : _asString(product['serving_size']).trim(),
      source: 'openfoodfacts',
    );
  }
}
