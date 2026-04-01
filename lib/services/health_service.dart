import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/health_data_point.dart' as app;

/// Service to interact with HealthKit (iOS) and Health Connect (Android)
class HealthService {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  final Health _health = Health();
  bool _isAuthorized = false;

  bool get isMobilePlatform => Platform.isAndroid || Platform.isIOS;

  static final List<HealthDataType> _readTypes = [
    HealthDataType.HEART_RATE,
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    HealthDataType.BLOOD_GLUCOSE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.BODY_TEMPERATURE,
    HealthDataType.STEPS,
    HealthDataType.WEIGHT,
    HealthDataType.HEIGHT,
  ];

  static final List<HealthDataType> _writeTypes = [
    HealthDataType.HEART_RATE,
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    HealthDataType.BLOOD_GLUCOSE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.BODY_TEMPERATURE,
    HealthDataType.STEPS,
  ];

  bool get isAuthorized => _isAuthorized;


  Future<void> configure() async {
    if (!isMobilePlatform) return;
    await _health.configure();
  }

  Future<bool> requestAuthorization() async {
    if (!isMobilePlatform) {
      debugPrint('Health: Not a mobile platform, skipping authorization.');
      _isAuthorized = false;
      return false;
    }

    try {
      await configure();

      // On Android: request ACTIVITY_RECOGNITION permission first (needed for Steps)
      if (Platform.isAndroid) {
        debugPrint('Health: Requesting ACTIVITY_RECOGNITION runtime permission...');
        final activityStatus = await Permission.activityRecognition.request();
        debugPrint('Health: ACTIVITY_RECOGNITION status: $activityStatus');
      }

      // Build a deduplicated list: types that are read-only + types that are read+write
      final List<HealthDataType> allTypes = [];
      final List<HealthDataAccess> permissions = [];

      // First add all write types as READ_WRITE
      for (final type in _writeTypes) {
        allTypes.add(type);
        permissions.add(HealthDataAccess.READ_WRITE);
      }

      // Then add read-only types (those not in _writeTypes)
      for (final type in _readTypes) {
        if (!_writeTypes.contains(type)) {
          allTypes.add(type);
          permissions.add(HealthDataAccess.READ);
        }
      }

      debugPrint('Health: Requesting authorization for ${allTypes.length} types...');
      for (int i = 0; i < allTypes.length; i++) {
        debugPrint('  [${i + 1}] ${allTypes[i].name} → ${permissions[i]}');
      }

      // Request all permissions at once
      _isAuthorized = await _health.requestAuthorization(
        allTypes,
        permissions: permissions,
      );
      debugPrint('Health authorization result: $_isAuthorized');

      // If that failed, try requesting in smaller groups
      if (!_isAuthorized) {
        debugPrint('Health: Full request failed, trying individual groups...');
        _isAuthorized = await _requestAuthorizationInGroups();
      }

      return _isAuthorized;
    } catch (e) {
      debugPrint('Error requesting health authorization: $e');
      _isAuthorized = false;
      return false;
    }
  }

  Future<bool> _requestAuthorizationInGroups() async {
    bool anySuccess = false;

    // Group 1: Heart Rate
    try {
      final ok = await _health.requestAuthorization(
        [HealthDataType.HEART_RATE],
        permissions: [HealthDataAccess.READ_WRITE],
      );
      debugPrint('  Group Heart Rate: $ok');
      if (ok) anySuccess = true;
    } catch (e) {
      debugPrint('  Group Heart Rate error: $e');
    }

    // Group 2: Blood Pressure (systolic + diastolic together)
    try {
      final ok = await _health.requestAuthorization(
        [HealthDataType.BLOOD_PRESSURE_SYSTOLIC, HealthDataType.BLOOD_PRESSURE_DIASTOLIC],
        permissions: [HealthDataAccess.READ_WRITE, HealthDataAccess.READ_WRITE],
      );
      debugPrint('  Group Blood Pressure: $ok');
      if (ok) anySuccess = true;
    } catch (e) {
      debugPrint('  Group Blood Pressure error: $e');
    }

    // Group 3: Blood Glucose
    try {
      final ok = await _health.requestAuthorization(
        [HealthDataType.BLOOD_GLUCOSE],
        permissions: [HealthDataAccess.READ_WRITE],
      );
      debugPrint('  Group Blood Glucose: $ok');
      if (ok) anySuccess = true;
    } catch (e) {
      debugPrint('  Group Blood Glucose error: $e');
    }

    // Group 4: SpO2
    try {
      final ok = await _health.requestAuthorization(
        [HealthDataType.BLOOD_OXYGEN],
        permissions: [HealthDataAccess.READ_WRITE],
      );
      debugPrint('  Group SpO2: $ok');
      if (ok) anySuccess = true;
    } catch (e) {
      debugPrint('  Group SpO2 error: $e');
    }

    // Group 5: Body Temperature
    try {
      final ok = await _health.requestAuthorization(
        [HealthDataType.BODY_TEMPERATURE],
        permissions: [HealthDataAccess.READ_WRITE],
      );
      debugPrint('  Group Body Temp: $ok');
      if (ok) anySuccess = true;
    } catch (e) {
      debugPrint('  Group Body Temp error: $e');
    }

    // Group 6: Steps (requires ACTIVITY_RECOGNITION)
    try {
      final ok = await _health.requestAuthorization(
        [HealthDataType.STEPS],
        permissions: [HealthDataAccess.READ_WRITE],
      );
      debugPrint('  Group Steps: $ok');
      if (ok) anySuccess = true;
    } catch (e) {
      debugPrint('  Group Steps error: $e');
    }

    // Group 7: Weight + Height (read only)
    try {
      final ok = await _health.requestAuthorization(
        [HealthDataType.WEIGHT, HealthDataType.HEIGHT],
        permissions: [HealthDataAccess.READ, HealthDataAccess.READ],
      );
      debugPrint('  Group Weight/Height: $ok');
      if (ok) anySuccess = true;
    } catch (e) {
      debugPrint('  Group Weight/Height error: $e');
    }

    debugPrint('Health: Group authorization result: anySuccess=$anySuccess');
    return anySuccess;
  }

  /// Check if Health Connect (Android) or HealthKit (iOS) is available
  Future<bool> isHealthAvailable() async {
    if (!isMobilePlatform) return false;

    try {
      if (Platform.isAndroid) {
        final status = await _health.getHealthConnectSdkStatus();
        debugPrint('Health Connect SDK status: $status');
        return status == HealthConnectSdkStatus.sdkAvailable;
      }
      // HealthKit is always available on iOS devices
      return Platform.isIOS;
    } catch (e) {
      debugPrint('Error checking health availability: $e');
      return false;
    }
  }

  /// Install Health Connect on Android if not installed
  Future<void> installHealthConnect() async {
    if (Platform.isAndroid) {
      await _health.installHealthConnect();
    }
  }

  /// Fetch heart rate data
  Future<List<app.HealthDataPoint>> fetchHeartRate({
    DateTime? start,
    DateTime? end,
  }) async {
    return _fetchData(
      type: HealthDataType.HEART_RATE,
      metricType: app.HealthMetricType.heartRate,
      start: start,
      end: end,
    );
  }

  /// Fetch blood pressure data (systolic & diastolic)
  Future<List<app.HealthDataPoint>> fetchBloodPressure({
    DateTime? start,
    DateTime? end,
  }) async {
    final now = end ?? DateTime.now();
    final startDate = start ?? now.subtract(const Duration(days: 7));

    try {
      final systolicData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.BLOOD_PRESSURE_SYSTOLIC],
        startTime: startDate,
        endTime: now,
      );

      final diastolicData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.BLOOD_PRESSURE_DIASTOLIC],
        startTime: startDate,
        endTime: now,
      );

      final results = <app.HealthDataPoint>[];

      for (int i = 0;
          i < systolicData.length && i < diastolicData.length;
          i++) {
        final sys = _extractNumericValue(systolicData[i].value);
        final dia = _extractNumericValue(diastolicData[i].value);
        results.add(app.HealthDataPoint(
          type: app.HealthMetricType.bloodPressure,
          value: sys,
          valueSystolic: sys,
          valueDiastolic: dia,
          unit: 'mmHg',
          dateFrom: systolicData[i].dateFrom,
          dateTo: systolicData[i].dateTo,
          source: systolicData[i].sourceName,
        ));
      }

      return results;
    } catch (e) {
      debugPrint('Error fetching blood pressure: $e');
      return [];
    }
  }

  /// Fetch blood glucose data
  /// Health Connect stores blood glucose in mg/dL, we convert to mmol/L
  Future<List<app.HealthDataPoint>> fetchBloodGlucose({
    DateTime? start,
    DateTime? end,
  }) async {
    final now = end ?? DateTime.now();
    final startDate = start ?? now.subtract(const Duration(days: 7));

    try {
      final healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.BLOOD_GLUCOSE],
        startTime: startDate,
        endTime: now,
      );

      debugPrint('Fetched BLOOD_GLUCOSE: ${healthData.length} raw records');

      return healthData.map((dp) {
        double val = _extractNumericValue(dp.value);

        // Health Connect returns mg/dL — convert to mmol/L if value > 30
        // (mmol/L values are typically 2-30, mg/dL values are typically 36-540)
        if (val > 30) {
          val = val / 18.0182;
          debugPrint('  -> BLOOD_GLUCOSE: converted ${_extractNumericValue(dp.value)} mg/dL → ${val.toStringAsFixed(1)} mmol/L');
        } else {
          debugPrint('  -> BLOOD_GLUCOSE: $val mmol/L (already in mmol/L)');
        }

        return app.HealthDataPoint(
          type: app.HealthMetricType.bloodGlucose,
          value: val,
          unit: 'mmol/L',
          dateFrom: dp.dateFrom,
          dateTo: dp.dateTo,
          source: dp.sourceName,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching blood glucose: $e');
      return [];
    }
  }

  /// Fetch SpO2 data
  Future<List<app.HealthDataPoint>> fetchSpO2({
    DateTime? start,
    DateTime? end,
  }) async {
    return _fetchData(
      type: HealthDataType.BLOOD_OXYGEN,
      metricType: app.HealthMetricType.spo2,
      start: start,
      end: end,
    );
  }

  /// Fetch body temperature data
  Future<List<app.HealthDataPoint>> fetchBodyTemperature({
    DateTime? start,
    DateTime? end,
  }) async {
    return _fetchData(
      type: HealthDataType.BODY_TEMPERATURE,
      metricType: app.HealthMetricType.bodyTemperature,
      start: start,
      end: end,
    );
  }

  /// Fetch steps data
  Future<List<app.HealthDataPoint>> fetchSteps({
    DateTime? start,
    DateTime? end,
  }) async {
    return _fetchData(
      type: HealthDataType.STEPS,
      metricType: app.HealthMetricType.steps,
      start: start,
      end: end,
    );
  }

  /// Fetch all health data for a given period
  Future<Map<app.HealthMetricType, List<app.HealthDataPoint>>>
      fetchAllHealthData({
    DateTime? start,
    DateTime? end,
  }) async {
    final results = <app.HealthMetricType, List<app.HealthDataPoint>>{};

    debugPrint('=== FETCHING ALL HEALTH DATA ===');
    debugPrint('Period: ${start ?? "7 days ago"} → ${end ?? "now"}');

    final futures = await Future.wait([
      fetchHeartRate(start: start, end: end),
      fetchBloodPressure(start: start, end: end),
      fetchBloodGlucose(start: start, end: end),
      fetchSpO2(start: start, end: end),
      fetchBodyTemperature(start: start, end: end),
      fetchSteps(start: start, end: end),
    ]);

    results[app.HealthMetricType.heartRate] = futures[0];
    results[app.HealthMetricType.bloodPressure] = futures[1];
    results[app.HealthMetricType.bloodGlucose] = futures[2];
    results[app.HealthMetricType.spo2] = futures[3];
    results[app.HealthMetricType.bodyTemperature] = futures[4];
    results[app.HealthMetricType.steps] = futures[5];

    // Log summary
    int total = 0;
    results.forEach((type, list) {
      debugPrint('  ${type.displayName}: ${list.length} records');
      total += list.length;
    });
    debugPrint('=== TOTAL: $total records from Health Connect ===');

    return results;
  }

  /// Generic fetch method for a single data type
  Future<List<app.HealthDataPoint>> _fetchData({
    required HealthDataType type,
    required app.HealthMetricType metricType,
    DateTime? start,
    DateTime? end,
  }) async {
    final now = end ?? DateTime.now();
    final startDate = start ?? now.subtract(const Duration(days: 7));

    try {
      final healthData = await _health.getHealthDataFromTypes(
        types: [type],
        startTime: startDate,
        endTime: now,
      );

      debugPrint('Fetched ${type.name}: ${healthData.length} raw records');

      return healthData.map((dp) {
        final val = _extractNumericValue(dp.value);
        debugPrint('  -> ${type.name}: $val ${metricType.unit} at ${dp.dateFrom} from ${dp.sourceName}');
        return app.HealthDataPoint(
          type: metricType,
          value: _extractNumericValue(dp.value),
          unit: metricType.unit,
          dateFrom: dp.dateFrom,
          dateTo: dp.dateTo,
          source: dp.sourceName,
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching $type: $e');
      return [];
    }
  }

  /// ===== WRITE DATA TO HEALTH CONNECT / HEALTHKIT =====

  /// Write heart rate data
  Future<bool> writeHeartRate(double value, {DateTime? time}) async {
    return _writeData(HealthDataType.HEART_RATE, value, time: time);
  }

  /// Write blood pressure data (systolic + diastolic)
  Future<bool> writeBloodPressure(double systolic, double diastolic,
      {DateTime? time}) async {
    if (!isMobilePlatform) return false;

    // Use writeBloodPressure API from the health plugin
    final t = time ?? DateTime.now();
    try {
      final success = await _health.writeBloodPressure(
        systolic: systolic.toInt(),
        diastolic: diastolic.toInt(),
        startTime: t,
        endTime: t,
      );
      debugPrint('Write BP: $systolic/$diastolic = $success');
      return success;
    } catch (e) {
      // Fallback: write separately
      debugPrint('writeBloodPressure API failed ($e), trying separate writes...');
      try {
        final sysBool = await _health.writeHealthData(
          value: systolic,
          type: HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
          startTime: t,
          endTime: t,
        );
        final diaBool = await _health.writeHealthData(
          value: diastolic,
          type: HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
          startTime: t,
          endTime: t,
        );
        debugPrint('Write BP fallback: sys=$sysBool, dia=$diaBool');
        return sysBool && diaBool;
      } catch (e2) {
        debugPrint('Error writing blood pressure: $e2');
        return false;
      }
    }
  }

  /// Write blood glucose data
  /// App uses mmol/L but Health Connect stores mg/dL, so we convert
  Future<bool> writeBloodGlucose(double valueInMmol, {DateTime? time}) async {
    // Convert mmol/L → mg/dL for Health Connect
    final valueInMgDl = valueInMmol * 18.0182;
    debugPrint('Write BLOOD_GLUCOSE: $valueInMmol mmol/L → $valueInMgDl mg/dL');
    return _writeData(HealthDataType.BLOOD_GLUCOSE, valueInMgDl, time: time);
  }

  /// Write SpO2 data
  Future<bool> writeSpO2(double value, {DateTime? time}) async {
    return _writeData(HealthDataType.BLOOD_OXYGEN, value, time: time);
  }

  /// Write body temperature data
  Future<bool> writeBodyTemperature(double value, {DateTime? time}) async {
    return _writeData(HealthDataType.BODY_TEMPERATURE, value, time: time);
  }

  /// Write steps data
  Future<bool> writeSteps(double value, {DateTime? time}) async {
    if (!isMobilePlatform) {
      debugPrint('Health: Not a mobile platform, skipping write.');
      return false;
    }

    // Steps is an INTERVAL type — startTime must be BEFORE endTime
    final end = time ?? DateTime.now();
    final start = end.subtract(const Duration(minutes: 10));
    try {
      final success = await _health.writeHealthData(
        value: value,
        type: HealthDataType.STEPS,
        startTime: start,
        endTime: end,
      );
      debugPrint('Write STEPS = $value ($start → $end): $success');
      return success;
    } catch (e) {
      debugPrint('Error writing STEPS: $e');
      return false;
    }
  }

  /// Generic write method for a single data type
  Future<bool> _writeData(HealthDataType type, double value,
      {DateTime? time}) async {
    if (!isMobilePlatform) {
      debugPrint('Health: Not a mobile platform, skipping write.');
      return false;
    }

    final t = time ?? DateTime.now();
    try {
      final success = await _health.writeHealthData(
        value: value,
        type: type,
        startTime: t,
        endTime: t,
      );
      debugPrint('Write $type = $value: $success');
      return success;
    } catch (e) {
      debugPrint('Error writing $type: $e');
      return false;
    }
  }

  /// Extract numeric value from HealthValue
  double _extractNumericValue(HealthValue value) {
    if (value is NumericHealthValue) {
      return value.numericValue.toDouble();
    }
    // Fallback: try to parse from string
    return double.tryParse(value.toString()) ?? 0.0;
  }
}
