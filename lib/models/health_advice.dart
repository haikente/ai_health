class HealthAdvice {
  final String title;
  final String content;
  final AdviceLevel level;
  final DateTime createdAt;
  final List<String> metrics;

  HealthAdvice({
    required this.title,
    required this.content,
    required this.level,
    required this.createdAt,
    this.metrics = const [],
  });
}

enum AdviceLevel {
  info,
  suggestion,
  warning,
  urgent,
}

extension AdviceLevelExt on AdviceLevel {
  String get label {
    switch (this) {
      case AdviceLevel.info:
        return 'Thông tin';
      case AdviceLevel.suggestion:
        return 'Gợi ý';
      case AdviceLevel.warning:
        return 'Cảnh báo';
      case AdviceLevel.urgent:
        return 'Khẩn cấp';
    }
  }
}
