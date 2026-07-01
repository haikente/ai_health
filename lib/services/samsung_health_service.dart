// lib/services/samsung_health_service.dart
// Flutter-side MethodChannel client — Samsung Health App → Your App

import 'dart:async';
import 'package:flutter/services.dart';

class SamsungStepData {
  final int steps;
  final double distanceKm;
  final int calories;
  final DateTime date;
  final String source;

  const SamsungStepData({
    required this.steps,
    required this.distanceKm,
    required this.calories,
    required this.date,
    required this.source,
  });

  factory SamsungStepData.fromMap(Map<dynamic, dynamic> map) => SamsungStepData(
    steps: map['steps'] as int,
    distanceKm: (map['distance_km'] as num).toDouble(),
    calories: map['calories'] as int,
    date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
    source: map['source'] as String? ?? 'Unknown',
  );

  bool get isReal =>
      source.contains('Real') ||
      source.contains('PROVIDER') ||
      source.contains('Sensor');
}

class SamsungHeartRateData {
  final int bpm;
  final String status;
  final DateTime timestamp;
  final String source;

  const SamsungHeartRateData({
    required this.bpm,
    required this.status,
    required this.timestamp,
    required this.source,
  });

  factory SamsungHeartRateData.fromMap(Map<dynamic, dynamic> map) =>
      SamsungHeartRateData(
        bpm: map['bpm'] as int,
        status: map['status'] as String? ?? '-',
        timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
        source: map['source'] as String? ?? 'Unknown',
      );

  bool get isReal =>
      source.contains('Real') ||
      source.contains('PROVIDER') ||
      source.contains('Sensor');
}

class SamsungSleepData {
  final int totalMinutes;
  final int deepMinutes;
  final int remMinutes;
  final int lightMinutes;
  final String quality;
  final String source;

  const SamsungSleepData({
    required this.totalMinutes,
    required this.deepMinutes,
    required this.remMinutes,
    required this.lightMinutes,
    required this.quality,
    required this.source,
  });

  factory SamsungSleepData.fromMap(Map<dynamic, dynamic> map) =>
      SamsungSleepData(
        totalMinutes: map['total_minutes'] as int,
        deepMinutes: map['deep_minutes'] as int,
        remMinutes: map['rem_minutes'] as int,
        lightMinutes: map['light_minutes'] as int,
        quality: map['quality'] as String? ?? '-',
        source: map['source'] as String? ?? 'Unknown',
      );

  String get totalFormatted {
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return '${h}g ${m}ph';
  }

  bool get isReal =>
      source.contains('Real') ||
      source.contains('PROVIDER') ||
      source.contains('Sensor');
}

class SamsungCalorieData {
  final int totalCalories;
  final int activeCalories;
  final int bmrCalories;
  final String source;

  const SamsungCalorieData({
    required this.totalCalories,
    required this.activeCalories,
    required this.bmrCalories,
    required this.source,
  });

  factory SamsungCalorieData.fromMap(Map<dynamic, dynamic> map) =>
      SamsungCalorieData(
        totalCalories: map['total_calories'] as int,
        activeCalories: map['active_calories'] as int,
        bmrCalories: map['bmr_calories'] as int,
        source: map['source'] as String? ?? 'Unknown',
      );

  bool get isReal =>
      source.contains('Real') ||
      source.contains('PROVIDER') ||
      source.contains('Sensor');
}

class SamsungBloodPressureData {
  final int systolic;
  final int diastolic;
  final DateTime timestamp;
  final String source;

  const SamsungBloodPressureData({
    required this.systolic,
    required this.diastolic,
    required this.timestamp,
    required this.source,
  });

  factory SamsungBloodPressureData.fromMap(Map<dynamic, dynamic> map) =>
      SamsungBloodPressureData(
        systolic: map['systolic'] as int,
        diastolic: map['diastolic'] as int,
        timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
        source: map['source'] as String? ?? 'Unknown',
      );

  bool get isReal =>
      source.contains('Real') ||
      source.contains('PROVIDER') ||
      source.contains('Sensor');
}

class SamsungBloodGlucoseData {
  final double glucose;
  final DateTime timestamp;
  final String source;

  const SamsungBloodGlucoseData({
    required this.glucose,
    required this.timestamp,
    required this.source,
  });

  factory SamsungBloodGlucoseData.fromMap(Map<dynamic, dynamic> map) =>
      SamsungBloodGlucoseData(
        glucose: (map['glucose'] as num).toDouble(),
        timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
        source: map['source'] as String? ?? 'Unknown',
      );

  bool get isReal =>
      source.contains('Real') ||
      source.contains('PROVIDER') ||
      source.contains('Sensor');
}

class SamsungSpO2Data {
  final int spo2;
  final DateTime timestamp;
  final String source;

  const SamsungSpO2Data({
    required this.spo2,
    required this.timestamp,
    required this.source,
  });

  factory SamsungSpO2Data.fromMap(Map<dynamic, dynamic> map) => SamsungSpO2Data(
    spo2: map['spo2'] as int,
    timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
    source: map['source'] as String? ?? 'Unknown',
  );

  bool get isReal =>
      source.contains('Real') ||
      source.contains('PROVIDER') ||
      source.contains('Sensor');
}

class SamsungBodyTemperatureData {
  final double temperature;
  final DateTime timestamp;
  final String source;

  const SamsungBodyTemperatureData({
    required this.temperature,
    required this.timestamp,
    required this.source,
  });

  factory SamsungBodyTemperatureData.fromMap(Map<dynamic, dynamic> map) =>
      SamsungBodyTemperatureData(
        temperature: (map['temperature'] as num).toDouble(),
        timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
        source: map['source'] as String? ?? 'Unknown',
      );

  bool get isReal =>
      source.contains('Real') ||
      source.contains('PROVIDER') ||
      source.contains('Sensor');
}

class SamsungWeightData {
  final double weight;
  final DateTime timestamp;
  final String source;

  const SamsungWeightData({
    required this.weight,
    required this.timestamp,
    required this.source,
  });

  factory SamsungWeightData.fromMap(Map<dynamic, dynamic> map) =>
      SamsungWeightData(
        weight: (map['weight'] as num).toDouble(),
        timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
        source: map['source'] as String? ?? 'Unknown',
      );

  bool get isReal =>
      source.contains('Real') ||
      source.contains('PROVIDER') ||
      source.contains('Sensor');
}

class SamsungHeightData {
  final double height;
  final DateTime timestamp;
  final String source;

  const SamsungHeightData({
    required this.height,
    required this.timestamp,
    required this.source,
  });

  factory SamsungHeightData.fromMap(Map<dynamic, dynamic> map) =>
      SamsungHeightData(
        height: (map['height'] as num).toDouble(),
        timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
        source: map['source'] as String? ?? 'Unknown',
      );

  bool get isReal =>
      source.contains('Real') ||
      source.contains('PROVIDER') ||
      source.contains('Sensor');
}

// ─── Connection State ─────────────────────────────────────────────────────────

enum SamsungHealthState {
  disconnected,
  connecting,
  connected,
  permissionPending,
  ready,
  error,
}

enum SamsungHealthMode {
  demo, // simulated data
  sensor, // reading from Android hardware Step Counter sensor
  provider, // reading from Samsung Health ContentProvider
  real, // reading via Samsung Health SDK (requires AAR)
}

// ─── Service ──────────────────────────────────────────────────────────────────

class SamsungHealthService {
  SamsungHealthService._();
  static final SamsungHealthService instance = SamsungHealthService._();

  static const _channel = MethodChannel('com.example.ai_health/samsung_health');
  static const _eventChannel = EventChannel(
    'com.example.ai_health/samsung_health_events',
  );

  // State
  SamsungHealthState _state = SamsungHealthState.disconnected;
  SamsungHealthState get state => _state;

  SamsungHealthMode _mode = SamsungHealthMode.demo;
  SamsungHealthMode get mode => _mode;

  String get modeLabel => switch (_mode) {
    SamsungHealthMode.real => 'Real SDK',
    SamsungHealthMode.provider => 'ContentProvider',
    SamsungHealthMode.sensor => 'Cảm biến HW',
    SamsungHealthMode.demo => 'DEMO',
  };

  String get modeEmoji => switch (_mode) {
    SamsungHealthMode.real => '📱',
    SamsungHealthMode.provider => '🔗',
    SamsungHealthMode.sensor => '📡',
    SamsungHealthMode.demo => '🧪',
  };

  // Streams
  StreamSubscription? _eventSubscription;
  final _hrController = StreamController<SamsungHeartRateData>.broadcast();
  Stream<SamsungHeartRateData> get heartRateStream => _hrController.stream;

  Future<bool> isSamsungHealthInstalled() async {
    try {
      return await _channel.invokeMethod<bool>('isSamsungHealthInstalled') ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<String> getDeviceManufacturer() async {
    try {
      return await _channel.invokeMethod<String>('getDeviceManufacturer') ??
          'unknown';
    } catch (_) {
      return 'unknown';
    }
  }

  Future<Map<String, dynamic>> connect() async {
    _state = SamsungHealthState.connecting;
    try {
      final raw = await _channel.invokeMethod<Map>('connect');
      final map = Map<String, dynamic>.from(raw ?? {});
      if (map['success'] == true) {
        final modeStr = map['mode'] as String?;
        _mode = _parseMode(modeStr);
        if (modeStr == 'REAL' || modeStr == 'DEMO') {
          _state = SamsungHealthState.ready;
          _startEventStream(); // ← thêm dòng này
        } else {
          _state = SamsungHealthState.connected;
        }
      } else {
        _state = SamsungHealthState.error;
      }
      return map;
    } on PlatformException catch (e) {
      _state = SamsungHealthState.error;
      return {'success': false, 'message': e.message};
    }
  }

  Future<Map<String, dynamic>> requestPermission() async {
    _state = SamsungHealthState.permissionPending;
    try {
      final raw = await _channel.invokeMethod<Map>('requestPermission');
      final map = Map<String, dynamic>.from(raw ?? {});
      if (map['granted'] == true) {
        _state = SamsungHealthState.ready;
        _mode = _parseMode(map['mode'] as String?);
        _startEventStream();
      } else {
        _state = SamsungHealthState.connected;
      }
      return map;
    } on PlatformException catch (e) {
      _state = SamsungHealthState.connected;
      return {'granted': false, 'message': e.message};
    }
  }

  Future<SamsungStepData?> getSteps() async {
    final raw = await _channel.invokeMethod<Map>('getSteps');
    return raw == null ? null : SamsungStepData.fromMap(raw);
  }

  Future<SamsungHeartRateData?> getHeartRate() async {
    final raw = await _channel.invokeMethod<Map>('getHeartRate');
    return raw == null ? null : SamsungHeartRateData.fromMap(raw);
  }

  Future<SamsungSleepData?> getSleep() async {
    final raw = await _channel.invokeMethod<Map>('getSleep');
    return raw == null ? null : SamsungSleepData.fromMap(raw);
  }

  Future<SamsungCalorieData?> getCalories() async {
    final raw = await _channel.invokeMethod<Map>('getCalories');
    return raw == null ? null : SamsungCalorieData.fromMap(raw);
  }

  Future<SamsungBloodPressureData?> getBloodPressure() async {
    final raw = await _channel.invokeMethod<Map>('getBloodPressure');
    return raw == null ? null : SamsungBloodPressureData.fromMap(raw);
  }

  Future<SamsungBloodGlucoseData?> getBloodGlucose() async {
    final raw = await _channel.invokeMethod<Map>('getBloodGlucose');
    return raw == null ? null : SamsungBloodGlucoseData.fromMap(raw);
  }

  Future<SamsungSpO2Data?> getSpO2() async {
    final raw = await _channel.invokeMethod<Map>('getSpO2');
    return raw == null ? null : SamsungSpO2Data.fromMap(raw);
  }

  Future<SamsungBodyTemperatureData?> getBodyTemperature() async {
    final raw = await _channel.invokeMethod<Map>('getBodyTemperature');
    return raw == null ? null : SamsungBodyTemperatureData.fromMap(raw);
  }

  Future<SamsungWeightData?> getWeight() async {
    final raw = await _channel.invokeMethod<Map>('getWeight');
    return raw == null ? null : SamsungWeightData.fromMap(raw);
  }

  Future<SamsungHeightData?> getHeight() async {
    final raw = await _channel.invokeMethod<Map>('getHeight');
    return raw == null ? null : SamsungHeightData.fromMap(raw);
  }

  Future<Map<String, dynamic>> openSamsungHealth() async {
    try {
      final raw = await _channel.invokeMethod<Map>('openSamsungHealth');
      return Map<String, dynamic>.from(raw ?? {});
    } on PlatformException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }

  Future<void> disconnect() async {
    _eventSubscription?.cancel();
    _eventSubscription = null;
    try {
      await _channel.invokeMethod('disconnect');
    } catch (_) {}
    _state = SamsungHealthState.disconnected;
    _mode = SamsungHealthMode.demo;
  }

  SamsungHealthMode _parseMode(String? raw) => switch (raw) {
    'REAL' => SamsungHealthMode.real,
    'PROVIDER' => SamsungHealthMode.provider,
    'SENSOR' => SamsungHealthMode.sensor,
    'NEED_PERM' => SamsungHealthMode.sensor,
    _ => SamsungHealthMode.demo,
  };

  void _startEventStream() {
    _eventSubscription?.cancel();
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen((event) {
      final map = Map<dynamic, dynamic>.from(event as Map);
      if (map['type'] == 'HEART_RATE') {
        _hrController.add(SamsungHeartRateData.fromMap(map));
      }
    }, onError: (e) => print('EventChannel error: $e'));
  }

  void dispose() {
    _eventSubscription?.cancel();
    _hrController.close();
  }
}
