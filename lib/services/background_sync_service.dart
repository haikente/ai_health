import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:workmanager/workmanager.dart';
import '../models/health_data_point.dart' as app;
import 'database_helper.dart';

/// Tên task đăng ký với WorkManager
const String healthConnectSyncTaskName = 'healthConnectPeriodicSync';
const String healthConnectSyncTaskTag = 'health_connect_sync';

/// Callback dispatcher — chạy ở top-level, không truy cập UI
///
/// WorkManager gọi hàm này trong một isolate riêng khi đến lịch chạy.
/// Hàm phải là top-level function (không nằm trong class).
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    debugPrint('WorkManager: executing task "$taskName"');

    if (taskName == healthConnectSyncTaskName ||
        taskName == Workmanager.iOSBackgroundTask) {
      try {
        await _syncHealthConnectInBackground();
        debugPrint('WorkManager: task "$taskName" completed successfully');
        return true;
      } catch (e) {
        debugPrint('WorkManager: task "$taskName" failed: $e');
        return false;
      }
    }

    return true;
  });
}

/// Logic đồng bộ Health Connect chạy nền — không cần UI
Future<void> _syncHealthConnectInBackground() async {
  if (!Platform.isAndroid) return;

  final health = Health();
  await health.configure();

  // Kiểm tra xem Health Connect có sẵn không
  final status = await health.getHealthConnectSdkStatus();
  if (status != HealthConnectSdkStatus.sdkAvailable) {
    debugPrint('WorkManager: Health Connect not available (status=$status)');
    return;
  }

  // Kiểm tra quyền đã được cấp chưa
  final types = [
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

  final hasPerms = await health.hasPermissions(types) ?? false;
  if (!hasPerms) {
    debugPrint('WorkManager: No health permissions, skipping sync');
    return;
  }

  // Lấy dữ liệu 24h gần nhất
  final now = DateTime.now();
  final start = now.subtract(const Duration(hours: 24));

  debugPrint('WorkManager: Fetching health data from $start to $now');

  final healthData = await health.getHealthDataFromTypes(
    types: types,
    startTime: start,
    endTime: now,
  );

  debugPrint('WorkManager: Fetched ${healthData.length} raw records');

  if (healthData.isEmpty) return;

  // Chuyển đổi sang model của app và lưu vào SQLite
  final points = <app.HealthDataPoint>[];

  // Nhóm Blood Pressure (cần ghép cặp systolic + diastolic)
  final systolicList = <HealthDataPoint>[];
  final diastolicList = <HealthDataPoint>[];

  for (final dp in healthData) {
    final val = _extractValue(dp.value);

    switch (dp.type) {
      case HealthDataType.HEART_RATE:
        points.add(
          app.HealthDataPoint(
            type: app.HealthMetricType.heartRate,
            value: val,
            unit: app.HealthMetricType.heartRate.unit,
            dateFrom: dp.dateFrom,
            dateTo: dp.dateTo,
            source: dp.sourceName,
          ),
        );
        break;

      case HealthDataType.BLOOD_PRESSURE_SYSTOLIC:
        systolicList.add(dp);
        break;

      case HealthDataType.BLOOD_PRESSURE_DIASTOLIC:
        diastolicList.add(dp);
        break;

      case HealthDataType.BLOOD_GLUCOSE:
        // Health Connect trả về mg/dL, chuyển sang mmol/L nếu > 30
        double glucose = val;
        if (glucose > 30) glucose = glucose / 18.0182;
        points.add(
          app.HealthDataPoint(
            type: app.HealthMetricType.bloodGlucose,
            value: glucose,
            unit: app.HealthMetricType.bloodGlucose.unit,
            dateFrom: dp.dateFrom,
            dateTo: dp.dateTo,
            source: dp.sourceName,
          ),
        );
        break;

      case HealthDataType.BLOOD_OXYGEN:
        double spo2 = val;
        if (spo2 > 0 && spo2 <= 1.0) spo2 = spo2 * 100;
        points.add(
          app.HealthDataPoint(
            type: app.HealthMetricType.spo2,
            value: spo2,
            unit: app.HealthMetricType.spo2.unit,
            dateFrom: dp.dateFrom,
            dateTo: dp.dateTo,
            source: dp.sourceName,
          ),
        );
        break;

      case HealthDataType.BODY_TEMPERATURE:
        points.add(
          app.HealthDataPoint(
            type: app.HealthMetricType.bodyTemperature,
            value: val,
            unit: app.HealthMetricType.bodyTemperature.unit,
            dateFrom: dp.dateFrom,
            dateTo: dp.dateTo,
            source: dp.sourceName,
          ),
        );
        break;

      case HealthDataType.STEPS:
        points.add(
          app.HealthDataPoint(
            type: app.HealthMetricType.steps,
            value: val,
            unit: app.HealthMetricType.steps.unit,
            dateFrom: dp.dateFrom,
            dateTo: dp.dateTo,
            source: dp.sourceName,
          ),
        );
        break;

      case HealthDataType.WEIGHT:
        points.add(
          app.HealthDataPoint(
            type: app.HealthMetricType.weight,
            value: val,
            unit: app.HealthMetricType.weight.unit,
            dateFrom: dp.dateFrom,
            dateTo: dp.dateTo,
            source: dp.sourceName,
          ),
        );
        break;

      case HealthDataType.HEIGHT:
        double height = val;
        if (height > 0 && height < 3) height = height * 100; // m → cm
        points.add(
          app.HealthDataPoint(
            type: app.HealthMetricType.height,
            value: height,
            unit: app.HealthMetricType.height.unit,
            dateFrom: dp.dateFrom,
            dateTo: dp.dateTo,
            source: dp.sourceName,
          ),
        );
        break;

      default:
        break;
    }
  }

  // Ghép cặp Blood Pressure
  final diaMap = <int, HealthDataPoint>{};
  for (final d in diastolicList) {
    diaMap[d.dateFrom.millisecondsSinceEpoch ~/ 60000] = d;
  }
  for (final sys in systolicList) {
    final key = sys.dateFrom.millisecondsSinceEpoch ~/ 60000;
    final dia = diaMap[key];
    if (dia != null) {
      final sysVal = _extractValue(sys.value);
      final diaVal = _extractValue(dia.value);
      points.add(
        app.HealthDataPoint(
          type: app.HealthMetricType.bloodPressure,
          value: sysVal,
          valueSystolic: sysVal,
          valueDiastolic: diaVal,
          unit: app.HealthMetricType.bloodPressure.unit,
          dateFrom: sys.dateFrom,
          dateTo: sys.dateTo,
          source: sys.sourceName,
        ),
      );
    }
  }

  // Lưu vào SQLite
  if (points.isNotEmpty) {
    await DatabaseHelper.instance.insertDataPoints(points);
    debugPrint('WorkManager: Saved ${points.length} points to SQLite');
  }
}

double _extractValue(HealthValue value) {
  if (value is NumericHealthValue) {
    return value.numericValue.toDouble();
  }
  return double.tryParse(value.toString()) ?? 0.0;
}

/// Helper class để đăng ký/huỷ WorkManager tasks từ UI
class BackgroundSyncManager {
  BackgroundSyncManager._();

  /// Khởi tạo WorkManager — gọi 1 lần trong main()
  static Future<void> initialize() async {
    await Workmanager().initialize(
      callbackDispatcher,
      // ignore: deprecated_member_use
      isInDebugMode: kDebugMode,
    );
    debugPrint('BackgroundSyncManager: WorkManager initialized');
  }

  /// Đăng ký periodic sync cho Health Connect (mỗi 15 phút — minimum của Android)
  static Future<void> registerHealthConnectSync() async {
    await Workmanager().registerPeriodicTask(
      healthConnectSyncTaskName,
      healthConnectSyncTaskName,
      tag: healthConnectSyncTaskTag,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 5),
    );
    debugPrint(
      'BackgroundSyncManager: Health Connect periodic sync registered (every 15 min)',
    );
  }

  /// Huỷ periodic sync (khi chuyển sang Samsung Health hoặc reset nguồn)
  static Future<void> cancelHealthConnectSync() async {
    await Workmanager().cancelByTag(healthConnectSyncTaskTag);
    debugPrint('BackgroundSyncManager: Health Connect periodic sync cancelled');
  }

  /// Chạy sync 1 lần ngay lập tức
  static Future<void> runOnceNow() async {
    await Workmanager().registerOneOffTask(
      'healthConnectOneTimeSync',
      healthConnectSyncTaskName,
      tag: healthConnectSyncTaskTag,
      constraints: Constraints(networkType: NetworkType.notRequired),
    );
    debugPrint('BackgroundSyncManager: One-time sync task registered');
  }
}
