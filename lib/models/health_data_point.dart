/// Represents a single health data measurement
class HealthDataPoint {
  final HealthMetricType type;
  final double value;
  final double? valueSystolic; // For blood pressure
  final double? valueDiastolic; // For blood pressure
  final String unit;
  final DateTime dateFrom;
  final DateTime dateTo;
  final String source;

  HealthDataPoint({
    required this.type,
    required this.value,
    this.valueSystolic,
    this.valueDiastolic,
    required this.unit,
    required this.dateFrom,
    required this.dateTo,
    this.source = 'Unknown',
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'value': value,
        if (valueSystolic != null) 'systolic': valueSystolic,
        if (valueDiastolic != null) 'diastolic': valueDiastolic,
        'unit': unit,
        'dateFrom': dateFrom.toIso8601String(),
        'dateTo': dateTo.toIso8601String(),
        'source': source,
      };

  String get displayValue {
    switch (type) {
      case HealthMetricType.bloodPressure:
        return '${valueSystolic?.toInt() ?? '-'}/${valueDiastolic?.toInt() ?? '-'}';
      case HealthMetricType.bloodGlucose:
        return value.toStringAsFixed(1);
      case HealthMetricType.bodyTemperature:
        return value.toStringAsFixed(1);
      case HealthMetricType.heartRate:
        return value.toInt().toString();
      case HealthMetricType.spo2:
        return '${value.toStringAsFixed(1)}%';
      default:
        return value.toStringAsFixed(1);
    }
  }

  /// Get a status level for the value
  HealthStatus get status {
    switch (type) {
      case HealthMetricType.heartRate:
        if (value < 60) return HealthStatus.low;
        if (value <= 100) return HealthStatus.normal;
        return HealthStatus.high;

      case HealthMetricType.spo2:
        if (value >= 95) return HealthStatus.normal;
        if (value >= 90) return HealthStatus.warning;
        return HealthStatus.critical;

      case HealthMetricType.bloodGlucose:
        // Fasting glucose in mmol/L
        if (value < 3.9) return HealthStatus.low;
        if (value <= 5.6) return HealthStatus.normal;
        if (value <= 7.0) return HealthStatus.warning;
        return HealthStatus.high;

      case HealthMetricType.bodyTemperature:
        if (value < 36.1) return HealthStatus.low;
        if (value <= 37.2) return HealthStatus.normal;
        if (value <= 38.0) return HealthStatus.warning;
        return HealthStatus.high;

      case HealthMetricType.bloodPressure:
        final sys = valueSystolic ?? value;
        if (sys < 90) return HealthStatus.low;
        if (sys <= 120) return HealthStatus.normal;
        if (sys <= 140) return HealthStatus.warning;
        return HealthStatus.high;

      default:
        return HealthStatus.normal;
    }
  }
}

enum HealthMetricType {
  heartRate,
  bloodPressure,
  bloodGlucose,
  spo2,
  bodyTemperature,
  steps,
  weight,
  height,
}

enum HealthStatus {
  normal,
  low,
  warning,
  high,
  critical,
}

extension HealthMetricTypeExt on HealthMetricType {
  String get displayName {
    switch (this) {
      case HealthMetricType.heartRate:
        return 'Nhịp tim';
      case HealthMetricType.bloodPressure:
        return 'Huyết áp';
      case HealthMetricType.bloodGlucose:
        return 'Đường huyết';
      case HealthMetricType.spo2:
        return 'SpO2';
      case HealthMetricType.bodyTemperature:
        return 'Nhiệt độ';
      case HealthMetricType.steps:
        return 'Bước chân';
      case HealthMetricType.weight:
        return 'Cân nặng';
      case HealthMetricType.height:
        return 'Chiều cao';
    }
  }

  String get unit {
    switch (this) {
      case HealthMetricType.heartRate:
        return 'bpm';
      case HealthMetricType.bloodPressure:
        return 'mmHg';
      case HealthMetricType.bloodGlucose:
        return 'mmol/L';
      case HealthMetricType.spo2:
        return '%';
      case HealthMetricType.bodyTemperature:
        return '°C';
      case HealthMetricType.steps:
        return 'bước';
      case HealthMetricType.weight:
        return 'kg';
      case HealthMetricType.height:
        return 'cm';
    }
  }

  String get icon {
    switch (this) {
      case HealthMetricType.heartRate:
        return '❤️';
      case HealthMetricType.bloodPressure:
        return '🩸';
      case HealthMetricType.bloodGlucose:
        return '🍬';
      case HealthMetricType.spo2:
        return '🫁';
      case HealthMetricType.bodyTemperature:
        return '🌡️';
      case HealthMetricType.steps:
        return '👟';
      case HealthMetricType.weight:
        return '⚖️';
      case HealthMetricType.height:
        return '📏';
    }
  }
}

extension HealthStatusExt on HealthStatus {
  String get label {
    switch (this) {
      case HealthStatus.normal:
        return 'Bình thường';
      case HealthStatus.low:
        return 'Thấp';
      case HealthStatus.warning:
        return 'Cảnh báo';
      case HealthStatus.high:
        return 'Cao';
      case HealthStatus.critical:
        return 'Nguy hiểm';
    }
  }
}
