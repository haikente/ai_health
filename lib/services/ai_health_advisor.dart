import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/health_data_point.dart';
import '../models/health_advice.dart';

class AIHealthAdvisor {
  static const String _apiKey = 'AIzaSyD1aj7xobzLja-xvsd5m1bSe14LZs3Stt8';

  late final GenerativeModel _model;

  AIHealthAdvisor() {
    _model = GenerativeModel(model: 'gemini-2.5-flash', apiKey: _apiKey);
  }

  Future<HealthAdvice> getHealthAdvice({
    required Map<HealthMetricType, List<HealthDataPoint>> healthData,
  }) async {
    try {
      final prompt = _buildPrompt(healthData);
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      final text = response.text ?? 'Không thể tạo lời khuyên lúc này.';

      return _parseAdvice(text, healthData);
    } catch (e) {
      debugPrint('Error getting AI advice: $e');
      return HealthAdvice(
        title: 'Lỗi kết nối AI',
        content:
            'Không thể kết nối với AI để phân tích. Vui lòng kiểm tra kết nối mạng và thử lại.\n\nChi tiết lỗi: $e',
        level: AdviceLevel.info,
        createdAt: DateTime.now(),
      );
    }
  }

  Future<String> getQuickAnalysis({
    required HealthMetricType metricType,
    required List<HealthDataPoint> data,
  }) async {
    if (data.isEmpty) return 'Chưa có dữ liệu để phân tích.';

    try {
      final prompt = _buildSingleMetricPrompt(metricType, data);
      final content = [Content.text(prompt)];
      final response = await _model.generateContent(content);

      return response.text ?? 'Không thể phân tích lúc này.';
    } catch (e) {
      debugPrint('Error getting quick analysis: $e');
      return 'Không thể kết nối AI. Vui lòng thử lại sau.';
    }
  }

  /// Build prompt for comprehensive health analysis
  String _buildPrompt(Map<HealthMetricType, List<HealthDataPoint>> healthData) {
    final buffer = StringBuffer();

    buffer.writeln('''
Bạn là một trợ lý AI chuyên về sức khỏe. Hãy phân tích các chỉ số sức khỏe sau đây của bệnh nhân và đưa ra lời khuyên chi tiết bằng tiếng Việt.

QUAN TRỌNG: Đây chỉ là lời khuyên tham khảo, không thay thế cho tư vấn y tế chuyên nghiệp.

=== DỮ LIỆU SỨC KHỎE ===
''');

    healthData.forEach((type, dataPoints) {
      if (dataPoints.isNotEmpty) {
        buffer.writeln('\n--- ${type.displayName} ---');

        // Latest value
        final latest = dataPoints.last;

        if (type == HealthMetricType.bloodPressure) {
          final sys = latest.valueSystolic;
          final dia = latest.valueDiastolic;
          buffer.writeln(
            'Giá trị mới nhất: Huyết áp tâm thu/tâm trương = '
            '${sys?.toStringAsFixed(0) ?? '-'} / ${dia?.toStringAsFixed(0) ?? '-'} mmHg',
          );
        } else {
          buffer.writeln(
            'Giá trị mới nhất: ${latest.displayValue} ${type.unit}',
          );
        }
        buffer.writeln('Thời gian: ${latest.dateFrom.toIso8601String()}');

        // Statistics
        if (dataPoints.length > 1) {
          final values = dataPoints.map((d) => d.value).toList();
          final avg = values.reduce((a, b) => a + b) / values.length;
          final max = values.reduce((a, b) => a > b ? a : b);
          final min = values.reduce((a, b) => a < b ? a : b);

          buffer.writeln(
            'Trung bình (${dataPoints.length} lần đo): ${avg.toStringAsFixed(1)}',
          );
          buffer.writeln('Cao nhất: ${max.toStringAsFixed(1)}');
          buffer.writeln('Thấp nhất: ${min.toStringAsFixed(1)}');
        }

        buffer.writeln('Trạng thái: ${latest.status.label}');
      }
    });

    buffer.writeln('''

=== YÊU CẦU PHÂN TÍCH ===
Hãy cung cấp:
1. **Tổng quan sức khỏe**: Đánh giá tổng thể các chỉ số
2. **Phân tích chi tiết**: Phân tích từng chỉ số bất thường (nếu có)
3. **Nguy cơ**: Các nguy cơ sức khỏe tiềm ẩn dựa trên dữ liệu
4. **Lời khuyên**: 
   - Chế độ ăn uống phù hợp
   - Hoạt động thể chất khuyến nghị
   - Thói quen sinh hoạt cần điều chỉnh
5. **Cảnh báo**: Chỉ số nào cần đến gặp bác sĩ ngay

Hãy trả lời ngắn gọn, dễ hiểu, sử dụng emoji phù hợp.
''');

    return buffer.toString();
  }

  /// Build prompt for a single metric analysis
  String _buildSingleMetricPrompt(
    HealthMetricType metricType,
    List<HealthDataPoint> data,
  ) {
    final buffer = StringBuffer();

    buffer.writeln('''
Phân tích ngắn gọn chỉ số ${metricType.displayName} của bệnh nhân bằng tiếng Việt:
''');

    for (final dp in data.take(20)) {
      buffer.writeln(
        '- ${dp.displayValue} ${metricType.unit} lúc ${dp.dateFrom}',
      );
    }

    buffer.writeln('''

Hãy:
1. Đánh giá chỉ số này ở mức nào (bình thường, cần theo dõi, nguy hiểm)
2. Xu hướng thay đổi
3. Lời khuyên cụ thể (2-3 câu)

Trả lời ngắn gọn, rõ ràng, dùng emoji.
''');

    return buffer.toString();
  }

  /// Parse AI response into structured HealthAdvice
  HealthAdvice _parseAdvice(
    String text,
    Map<HealthMetricType, List<HealthDataPoint>> healthData,
  ) {
    AdviceLevel level = AdviceLevel.info;
    final affectedMetrics = <String>[];

    void promoteLevel(AdviceLevel newLevel) {
      // Urgent > warning > suggestion > info
      if (newLevel == AdviceLevel.urgent) {
        level = AdviceLevel.urgent;
        return;
      }
      if (level == AdviceLevel.urgent) return;

      if (newLevel == AdviceLevel.warning) {
        level = AdviceLevel.warning;
        return;
      }
      if (level == AdviceLevel.warning) return;

      if (newLevel == AdviceLevel.suggestion && level == AdviceLevel.info) {
        level = AdviceLevel.suggestion;
      }
    }

    healthData.forEach((type, dataPoints) {
      if (dataPoints.isEmpty) return;
      final latest = dataPoints.last;

      switch (latest.status) {
        case HealthStatus.critical:
          promoteLevel(AdviceLevel.urgent);
          affectedMetrics.add(type.displayName);
          break;

        case HealthStatus.high:
        case HealthStatus.warning:
          promoteLevel(AdviceLevel.warning);
          affectedMetrics.add(type.displayName);
          break;

        case HealthStatus.low:
          switch (type) {
            case HealthMetricType.bloodGlucose:
              promoteLevel(AdviceLevel.urgent);
              affectedMetrics.add(type.displayName);
              break;
            case HealthMetricType.spo2:
              promoteLevel(AdviceLevel.urgent);
              affectedMetrics.add(type.displayName);
              break;
            case HealthMetricType.heartRate:
            case HealthMetricType.bodyTemperature:
            case HealthMetricType.bloodPressure:
              promoteLevel(AdviceLevel.warning);
              affectedMetrics.add(type.displayName);
              break;
            default:
              promoteLevel(AdviceLevel.suggestion);
              break;
          }
          break;

        case HealthStatus.normal:
          break;
      }
    });

    String title;
    switch (level) {
      case AdviceLevel.urgent:
        title = '⚠️ Cảnh báo sức khỏe khẩn cấp';
        break;
      case AdviceLevel.warning:
        title = '⚡ Một số chỉ số cần lưu ý';
        break;
      case AdviceLevel.suggestion:
        title = '💡 Gợi ý cải thiện sức khỏe';
        break;
      case AdviceLevel.info:
        title = '✅ Báo cáo sức khỏe';
        break;
    }

    return HealthAdvice(
      title: title,
      content: text,
      level: level,
      createdAt: DateTime.now(),
      metrics: affectedMetrics,
    );
  }
}
