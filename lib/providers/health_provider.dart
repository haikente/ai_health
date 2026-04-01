import 'dart:io';
import 'package:flutter/material.dart';
import '../models/health_data_point.dart';
import '../models/health_advice.dart';
import '../services/health_service.dart';
import '../services/ai_health_advisor.dart';

/// Main state management provider for health data
class HealthProvider extends ChangeNotifier {
  final HealthService _healthService = HealthService();
  final AIHealthAdvisor _aiAdvisor = AIHealthAdvisor();

  // State
  bool _isLoading = false;
  bool _isAuthorized = false;
  bool _isHealthAvailable = false;
  bool _isAnalyzing = false;
  String? _errorMessage;

  // Health data
  Map<HealthMetricType, List<HealthDataPoint>> _healthData = {};

  // AI Advice
  HealthAdvice? _latestAdvice;
  String? _quickAnalysis;

  // Time range
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );

  // Getters
  bool get isLoading => _isLoading;
  bool get isAuthorized => _isAuthorized;
  bool get isHealthAvailable => _isHealthAvailable;
  bool get isAnalyzing => _isAnalyzing;
  String? get errorMessage => _errorMessage;
  Map<HealthMetricType, List<HealthDataPoint>> get healthData => _healthData;
  HealthAdvice? get latestAdvice => _latestAdvice;
  String? get quickAnalysis => _quickAnalysis;
  DateTimeRange get dateRange => _dateRange;

  /// Get the latest data point for a metric type
  HealthDataPoint? getLatest(HealthMetricType type) {
    final data = _healthData[type];
    if (data == null || data.isEmpty) return null;
    return data.last;
  }

  /// Get data for a specific metric
  List<HealthDataPoint> getMetricData(HealthMetricType type) {
    return _healthData[type] ?? [];
  }

  /// Whether we're running on a mobile platform
  bool get _isMobile => Platform.isAndroid || Platform.isIOS;

  /// Initialize the health service — chỉ dùng dữ liệu thật từ Health Connect
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (!_isMobile) {
        // Desktop không có Health Connect
        debugPrint('Desktop platform — Health Connect không khả dụng.');
        _isHealthAvailable = false;
        return;
      }

      _isHealthAvailable = await _healthService.isHealthAvailable();
      debugPrint('Health available: $_isHealthAvailable');

      if (!_isHealthAvailable) {
        // Chưa cài Health Connect — UI hiện nút "Cài đặt HC"
        debugPrint('Health Connect chưa được cài đặt.');
        return;
      }

      _isAuthorized = await _healthService.requestAuthorization();
      debugPrint('Authorized: $_isAuthorized');

      // Dù auth trả về gì, vẫn thử fetch (user có thể đã cấp quyền thủ công)
      await fetchHealthData();

      final hasData = _healthData.values.any((l) => l.isNotEmpty);
      if (hasData) {
        _isAuthorized = true;
        // IMPORTANT: do NOT auto-run AI analysis on app start.
      } else if (!_isAuthorized) {
        _errorMessage =
            'Chưa được cấp quyền truy cập dữ liệu sức khỏe.\n'
            'Vui lòng mở Health Connect → Quyền ứng dụng → AI Health → Cho phép tất cả.';
      }
    } catch (e) {
      _errorMessage = 'Không thể khởi tạo dịch vụ sức khỏe: $e';
      debugPrint('Initialize error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Request health permissions
  Future<void> requestPermissions() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _isAuthorized = await _healthService.requestAuthorization();

      await fetchHealthData();
      final hasData = _healthData.values.any((list) => list.isNotEmpty);

      if (hasData) {
        _isAuthorized = true;
        // IMPORTANT: do NOT auto-run AI analysis after requesting permissions.
      } else if (!_isAuthorized) {
        _errorMessage =
            'Chưa được cấp quyền truy cập dữ liệu sức khỏe.\n'
            'Vui lòng mở Health Connect → Quyền ứng dụng → AI Health → Cho phép tất cả.';
      }
    } catch (e) {
      _errorMessage = 'Lỗi yêu cầu quyền: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> installHealthConnect() async {
    await _healthService.installHealthConnect();
  }

  Future<void> fetchHealthData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      debugPrint(
        'Fetching health data for range: ${_dateRange.start} → ${_dateRange.end}',
      );

      final localData = <HealthMetricType, List<HealthDataPoint>>{};
      _healthData.forEach((type, list) {
        final manualEntries = list
            .where(
              (dp) => dp.source == 'AI Health App' || dp.source == 'Manual',
            )
            .toList();
        if (manualEntries.isNotEmpty) {
          localData[type] = manualEntries;
        }
      });

      // Fetch from Health Connect
      final remoteData = await _healthService.fetchAllHealthData(
        start: _dateRange.start,
        end: _dateRange.end,
      );
      _healthData = remoteData;
      localData.forEach((type, localList) {
        final existing = _healthData[type] ?? [];
        for (final localDp in localList) {
          final isDuplicate = existing.any(
            (remoteDp) =>
                remoteDp.dateFrom.difference(localDp.dateFrom).inSeconds.abs() <
                    60 &&
                (remoteDp.value - localDp.value).abs() < 0.1,
          );
          if (!isDuplicate) {
            existing.add(localDp);
          }
        }
  
        existing.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
        _healthData[type] = existing;
      });

      final totalRecords = _healthData.values.fold<int>(
        0,
        (sum, list) => sum + list.length,
      );
      debugPrint('fetchHealthData complete: $totalRecords total records');
      _healthData.forEach((type, list) {
        if (list.isNotEmpty) {
          debugPrint(
            '  ${type.displayName}: ${list.length} records, latest=${list.last.displayValue} (source: ${list.last.source})',
          );
        }
      });
    } catch (e) {
      _errorMessage = 'Không thể tải dữ liệu sức khỏe: $e';
      debugPrint('fetchHealthData error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update date range and refetch data
  Future<void> updateDateRange(DateTimeRange range) async {
    _dateRange = range;
    notifyListeners();
    await fetchHealthData();
  }

  /// Get AI health advice
  Future<void> getAIAdvice() async {
    _isAnalyzing = true;
    _quickAnalysis = null;
    notifyListeners();

    try {
      _latestAdvice = await _aiAdvisor.getHealthAdvice(healthData: _healthData);
    } catch (e) {
      _latestAdvice = HealthAdvice(
        title: 'Lỗi phân tích',
        content: 'Không thể kết nối AI: $e',
        level: AdviceLevel.info,
        createdAt: DateTime.now(),
      );
    } finally {
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  /// Get quick analysis for a specific metric
  Future<void> getQuickMetricAnalysis(HealthMetricType type) async {
    _isAnalyzing = true;
    _quickAnalysis = null;
    notifyListeners();

    try {
      final data = _healthData[type] ?? [];
      _quickAnalysis = await _aiAdvisor.getQuickAnalysis(
        metricType: type,
        data: data,
      );
    } catch (e) {
      _quickAnalysis = 'Không thể phân tích: $e';
    } finally {
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  /// Add manual health data point — also writes to Health Connect/HealthKit
  Future<void> addManualDataPoint(HealthDataPoint dataPoint) async {
    // Write to Health Connect / HealthKit if on mobile
    if (_isMobile && _isAuthorized) {
      bool written = false;
      switch (dataPoint.type) {
        case HealthMetricType.heartRate:
          written = await _healthService.writeHeartRate(dataPoint.value);
          break;
        case HealthMetricType.bloodPressure:
          written = await _healthService.writeBloodPressure(
            dataPoint.valueSystolic ?? dataPoint.value,
            dataPoint.valueDiastolic ?? 80,
          );
          break;
        case HealthMetricType.bloodGlucose:
          written = await _healthService.writeBloodGlucose(dataPoint.value);
          break;
        case HealthMetricType.spo2:
          written = await _healthService.writeSpO2(dataPoint.value);
          break;
        case HealthMetricType.bodyTemperature:
          written = await _healthService.writeBodyTemperature(dataPoint.value);
          break;
        case HealthMetricType.steps:
          written = await _healthService.writeSteps(dataPoint.value);
          break;
        default:
          break;
      }
      debugPrint(
        'Wrote ${dataPoint.type.displayName} to Health Connect: $written',
      );
    }

    // Also add to local state immediately
    final list = _healthData[dataPoint.type] ?? [];
    list.add(dataPoint);
    _healthData[dataPoint.type] = list;
    notifyListeners();
  }
}
