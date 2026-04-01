class BarcodeFood {
  final String barcode;
  final String name;
  final String? brand;
  final String? imageUrl;
  final double calories;    // per serving nếu có, fallback per 100g
  final double protein;
  final double carbs;
  final double fat;
  final double? fiber;
  final String servingSize; // "75g", "1 gói"
  final String source;      // "Open Food Facts" | "Nutritionix"

  const BarcodeFood({
    required this.barcode,
    required this.name,
    this.brand,
    this.imageUrl,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber,
    required this.servingSize,
    required this.source,
  });
}
