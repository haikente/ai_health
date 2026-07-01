import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/health_data_point.dart';
import '../models/health_advice.dart';
import '../services/health_service.dart';
import '../services/ai_health_advisor.dart';
import '../services/samsung_health_service.dart';
import '../services/database_helper.dart';
import '../services/background_sync_service.dart';

class HealthProvider extends ChangeNotifier {
  final HealthService _healthService = HealthService();
  final AIHealthAdvisor _aiAdvisor = AIHealthAdvisor();

  StreamSubscription<SamsungHeartRateData>? _hrStreamSub;

  // State
  bool _isLoading = false;
  bool _isAuthorized = false;
  bool _isHealthAvailable = false;
  bool _isAnalyzing = false;
  String? _errorMessage;

  @override
  void dispose() {
    _hrStreamSub?.cancel();
    super.dispose();
  }

  // Selected Sync Source ('samsung' or 'health_connect' or null)
  String? _selectedSyncSource;
  bool _isSamsungDevice = false;
  bool _needsSyncSourceSelection = false;

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

  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;

  // Getters
  bool get isLoading => _isLoading;
  bool get isAuthorized => _isAuthorized;
  bool get isHealthAvailable => _isHealthAvailable;
  bool get isAnalyzing => _isAnalyzing;
  String? get errorMessage => _errorMessage;
  String? get selectedSyncSource => _selectedSyncSource;
  bool get isSamsungDevice => _isSamsungDevice;
  bool get needsSyncSourceSelection => _needsSyncSourceSelection;
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

      if (Platform.isAndroid) {
        // Check Samsung device manufacturer
        final manufacturer = await SamsungHealthService.instance
            .getDeviceManufacturer();
        _isSamsungDevice = manufacturer.toLowerCase().contains('samsung');
        debugPrint(
          'Device manufacturer: $manufacturer (isSamsungDevice: $_isSamsungDevice)',
        );

        // Load sync source selection from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        _selectedSyncSource = prefs.getString('selected_sync_source');
        debugPrint('Loaded selected sync source: $_selectedSyncSource');

        final lastSyncMs = prefs.getInt('last_sync_time');
        if (lastSyncMs != null) {
          _lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSyncMs);
          debugPrint('Loaded last sync time: $_lastSyncTime');
        }

        if (_selectedSyncSource == null) {
          // Chưa chọn phương thức đồng bộ → yêu cầu người dùng chọn, không tự động xin quyền
          _needsSyncSourceSelection = true;
          debugPrint(
            'No sync source selected yet. Prompting user selection...',
          );
          return;
        }

        _needsSyncSourceSelection = false;

        if (_selectedSyncSource == 'samsung') {
          // Tự động kết nối Samsung Health khi khởi động
          _autoConnectSamsungHealth();
          _isHealthAvailable = true;
          _isAuthorized = true;
          await fetchHealthData();
        } else {
          // Health Connect
          _isHealthAvailable = await _healthService.isHealthAvailable();
          debugPrint('Health Connect available: $_isHealthAvailable');

          if (_isHealthAvailable) {
            _isAuthorized = await _healthService.hasPermissions();
            debugPrint('Health Connect has permissions: $_isAuthorized');
            if (_isAuthorized) {
              // Đảm bảo WorkManager periodic sync luôn được đăng ký
              await BackgroundSyncManager.registerHealthConnectSync();
              await fetchHealthData();
            }
          }
        }
      } else {
        // iOS: Mặc định là HealthKit (không có lựa chọn khác)
        _selectedSyncSource = 'health_connect';
        _needsSyncSourceSelection = false;
        _isHealthAvailable = await _healthService.isHealthAvailable();
        if (_isHealthAvailable) {
          _isAuthorized = await _healthService.hasPermissions();
          debugPrint('iOS HealthKit has permissions: $_isAuthorized');
          if (_isAuthorized) {
            await fetchHealthData();
          }
        }
      }
    } catch (e) {
      _errorMessage = 'Không thể khởi tạo dịch vụ sức khỏe: $e';
      debugPrint('Initialize error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _autoConnectSamsungHealth() {
    final svc = SamsungHealthService.instance;
    if (svc.state != SamsungHealthState.disconnected) return;

    Future(() async {
      try {
        final connectResult = await svc.connect();
        debugPrint('Samsung Health auto-connect: ${connectResult['message']}');
        notifyListeners();

        if (svc.state == SamsungHealthState.connected) {
          await svc.requestPermission(); // ← đảm bảo có gọi requestPermission
        }
        if (svc.state == SamsungHealthState.ready) {
          _listenSamsungHeartRateStream(); // ← thêm dòng này
          await fetchHealthData();
        }
      } catch (e) {
        debugPrint('Samsung Health auto-connect failed (non-fatal): $e');
      }
    });
  }

  /// Chọn phương thức đồng bộ sức khỏe
  Future<void> selectSyncSource(String source) async {
    _isLoading = true;
    _needsSyncSourceSelection = false;
    _selectedSyncSource = source;
    _errorMessage = null;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_sync_source', source);
      debugPrint('Saved selected sync source: $source');

      if (source == 'samsung') {
        // Huỷ WorkManager nếu đang chạy cho Health Connect
        await BackgroundSyncManager.cancelHealthConnectSync();

        final svc = SamsungHealthService.instance;
        await svc.connect();
        if (svc.state == SamsungHealthState.connected) {
          await svc.requestPermission();
        }
        _isHealthAvailable = true;
        _isAuthorized = true;
      } else {
        _isHealthAvailable = await _healthService.isHealthAvailable();
        if (_isHealthAvailable) {
          _isAuthorized = await _healthService.requestAuthorization();

          // Đăng ký WorkManager periodic sync cho Health Connect
          if (_isAuthorized) {
            await BackgroundSyncManager.registerHealthConnectSync();
          }
        } else {
          _errorMessage = 'Thiết bị không hỗ trợ Health Connect.';
        }
      }

      await fetchHealthData();
    } catch (e) {
      _errorMessage = 'Lỗi thiết lập phương thức đồng bộ: $e';
      debugPrint('selectSyncSource error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Reset phương thức đồng bộ (cho phép người dùng chọn lại)
  Future<void> resetSyncSource() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('selected_sync_source');
      _selectedSyncSource = null;
      _needsSyncSourceSelection = true;
      _isAuthorized = false;
      _healthData = {};
      _errorMessage = null;

      // Huỷ WorkManager nếu đang chạy
      await BackgroundSyncManager.cancelHealthConnectSync();

      // Giữ lại dữ liệu cũ trong SQLite — không xoá khi đổi nguồn
      debugPrint('Reset sync source selection (data preserved in SQLite)');
    } catch (e) {
      debugPrint('resetSyncSource error: $e');
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

  bool _isSyncing = false;

  /// Tải dữ liệu từ SQLite ra cache memory và cập nhật UI
  Future<void> _loadFromLocalDatabase() async {
    final dbPoints = await DatabaseHelper.instance.getDataPoints(
      start: _dateRange.start,
      end: _dateRange.end,
    );

    // Group by HealthMetricType
    final Map<HealthMetricType, List<HealthDataPoint>> groupedData = {};
    for (final pt in dbPoints) {
      groupedData.putIfAbsent(pt.type, () => []).add(pt);
    }

    // Sắp xếp dữ liệu theo trình tự thời gian
    groupedData.forEach((type, list) {
      list.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
    });

    _healthData = groupedData;
    notifyListeners();
  }

  Future<void> fetchHealthData() async {
    // Tránh gọi trùng lặp khi sync đang chạy
    if (_isSyncing) {
      debugPrint('fetchHealthData: already syncing, skipping');
      return;
    }
    _isSyncing = true;

    // Cập nhật khoảng thời gian đến thời điểm hiện tại nếu đang ở chế độ xem thời gian thực
    final nowTime = DateTime.now();
    if (nowTime.difference(_dateRange.end).inHours.abs() < 24) {
      final duration = _dateRange.end.difference(_dateRange.start);
      _dateRange = DateTimeRange(
        start: nowTime.subtract(duration),
        end: nowTime,
      );
      debugPrint('fetchHealthData: slid dateRange to end at $nowTime');
    }

    // ── 1. Tải ngay lập tức dữ liệu hiện có từ SQLite lên UI (tránh màn hình trắng) ───
    try {
      await _loadFromLocalDatabase();
    } catch (e) {
      debugPrint('fetchHealthData: error loading initial local cache: $e');
    }

    // Chỉ hiện loading spinner nếu bộ nhớ RAM đang trống hoàn toàn
    final hasExistingData = _healthData.values.any((list) => list.isNotEmpty);
    if (!hasExistingData) {
      _isLoading = true;
      notifyListeners();
    }
    _errorMessage = null;

    try {
      debugPrint(
        'fetchHealthData: syncing remote data (range: ${_dateRange.start} → ${_dateRange.end})',
      );

      // Load last sync time từ SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final lastSyncMs = prefs.getInt('last_sync_time');
      final lastSync = lastSyncMs != null
          ? DateTime.fromMillisecondsSinceEpoch(lastSyncMs)
          : null;

      // ── 2. Đồng bộ dữ liệu mới từ Health Connect / HealthKit (với timeout và lastSync) ──
      if (_selectedSyncSource == 'health_connect' || !Platform.isAndroid) {
        // Query từ lastSync trừ đi 24 giờ để đề phòng ghi nhận muộn, tối thiểu vẫn là _dateRange.start
        final startQuery = lastSync != null
            ? lastSync.subtract(const Duration(hours: 24))
            : _dateRange.start;
        final finalStart = startQuery.isBefore(_dateRange.start)
            ? startQuery
            : _dateRange.start;

        debugPrint(
          'Health Connect: syncing from $finalStart to ${_dateRange.end}',
        );
        final remoteData = await _healthService
            .fetchAllHealthData(start: finalStart, end: _dateRange.end)
            .timeout(const Duration(seconds: 15));

        final List<HealthDataPoint> newFetchedPoints = [];
        remoteData.forEach((type, list) {
          newFetchedPoints.addAll(list);
        });
        if (newFetchedPoints.isNotEmpty) {
          await DatabaseHelper.instance.insertDataPoints(newFetchedPoints);
          debugPrint(
            'Health Connect: inserted ${newFetchedPoints.length} points to SQLite',
          );
        }
      }

      // ── 3. Đồng bộ dữ liệu mới từ Samsung Health (với timeout) ───────────────
      if (_selectedSyncSource == 'samsung' && Platform.isAndroid) {
        final svc = SamsungHealthService.instance;
        // Chỉ connect() nếu chưa kết nối — tránh gọi lại mỗi vòng poll
        if (svc.state == SamsungHealthState.disconnected ||
            svc.state == SamsungHealthState.error) {
          debugPrint('Samsung Health: (re)connecting...');
          await svc.connect().timeout(const Duration(seconds: 10));
          if (svc.state == SamsungHealthState.connected) {
            await svc.requestPermission().timeout(const Duration(seconds: 10));
          }
        }
        debugPrint('Samsung Health: syncing...');
        await _autoSyncSamsungHealth().timeout(const Duration(seconds: 15));
      }

      // Lưu mốc thời gian đồng bộ thành công
      _lastSyncTime = DateTime.now();
      await prefs.setInt(
        'last_sync_time',
        _lastSyncTime!.millisecondsSinceEpoch,
      );

      // ── 4. Cập nhật lại UI sau khi đã thêm dữ liệu mới thành công ───
      await _loadFromLocalDatabase();

      final totalRecords = _healthData.values.fold<int>(
        0,
        (sum, list) => sum + list.length,
      );
      debugPrint(
        'fetchHealthData complete: $totalRecords total records from local SQLite',
      );
    } catch (e) {
      _errorMessage = 'Không thể tải dữ liệu sức khỏe: $e';
      debugPrint('fetchHealthData error: $e');
    } finally {
      _isLoading = false;
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<List<HealthDataPoint>> _fetchSamsungHealthPointsList() async {
    final svc = SamsungHealthService.instance;
    final points = <HealthDataPoint>[];

    debugPrint('Samsung Health: fetching current data points...');

    // Hàm helper để gọi từng SDK call mà không làm hỏng toàn bộ nếu 1 chỉ số lỗi
    Future<T?> safeFetch<T>(Future<T?> Function() fetch, String name) async {
      try {
        return await fetch();
      } catch (e) {
        debugPrint('Samsung Health: skipping $name (error: $e)');
        return null;
      }
    }

    // Steps
    final steps = await safeFetch(() => svc.getSteps(), 'Steps');
    if (steps != null && steps.isReal) {
      points.add(
        HealthDataPoint(
          type: HealthMetricType.steps,
          value: steps.steps.toDouble(),
          unit: HealthMetricType.steps.unit,
          dateFrom: steps.date,
          dateTo: steps.date,
          source: steps.source,
        ),
      );
    }

    // Heart Rate
    final hr = await safeFetch(() => svc.getHeartRate(), 'HeartRate');
    if (hr != null && hr.isReal) {
      points.add(
        HealthDataPoint(
          type: HealthMetricType.heartRate,
          value: hr.bpm.toDouble(),
          unit: HealthMetricType.heartRate.unit,
          dateFrom: hr.timestamp,
          dateTo: hr.timestamp,
          source: hr.source,
        ),
      );
    }

    // Blood Pressure
    final bp = await safeFetch(() => svc.getBloodPressure(), 'BloodPressure');
    if (bp != null && bp.isReal) {
      points.add(
        HealthDataPoint(
          type: HealthMetricType.bloodPressure,
          value: bp.systolic.toDouble(),
          valueSystolic: bp.systolic.toDouble(),
          valueDiastolic: bp.diastolic.toDouble(),
          unit: HealthMetricType.bloodPressure.unit,
          dateFrom: bp.timestamp,
          dateTo: bp.timestamp,
          source: bp.source,
        ),
      );
    }

    // Blood Glucose
    final glucose = await safeFetch(
      () => svc.getBloodGlucose(),
      'BloodGlucose',
    );
    if (glucose != null && glucose.isReal) {
      points.add(
        HealthDataPoint(
          type: HealthMetricType.bloodGlucose,
          value: glucose.glucose,
          unit: HealthMetricType.bloodGlucose.unit,
          dateFrom: glucose.timestamp,
          dateTo: glucose.timestamp,
          source: glucose.source,
        ),
      );
    }

    // SpO2
    final spo2 = await safeFetch(() => svc.getSpO2(), 'SpO2');
    if (spo2 != null && spo2.isReal) {
      points.add(
        HealthDataPoint(
          type: HealthMetricType.spo2,
          value: spo2.spo2.toDouble(),
          unit: HealthMetricType.spo2.unit,
          dateFrom: spo2.timestamp,
          dateTo: spo2.timestamp,
          source: spo2.source,
        ),
      );
    }

    // Body Temperature
    final temp = await safeFetch(
      () => svc.getBodyTemperature(),
      'BodyTemperature',
    );
    if (temp != null && temp.isReal) {
      points.add(
        HealthDataPoint(
          type: HealthMetricType.bodyTemperature,
          value: temp.temperature,
          unit: HealthMetricType.bodyTemperature.unit,
          dateFrom: temp.timestamp,
          dateTo: temp.timestamp,
          source: temp.source,
        ),
      );
    }

    // Weight
    final weight = await safeFetch(() => svc.getWeight(), 'Weight');
    if (weight != null && weight.isReal) {
      points.add(
        HealthDataPoint(
          type: HealthMetricType.weight,
          value: weight.weight,
          unit: HealthMetricType.weight.unit,
          dateFrom: weight.timestamp,
          dateTo: weight.timestamp,
          source: weight.source,
        ),
      );
    }

    // Height
    final height = await safeFetch(() => svc.getHeight(), 'Height');
    if (height != null && height.isReal) {
      points.add(
        HealthDataPoint(
          type: HealthMetricType.height,
          value: height.height,
          unit: HealthMetricType.height.unit,
          dateFrom: height.timestamp,
          dateTo: height.timestamp,
          source: height.source,
        ),
      );
    }

    debugPrint('Samsung Health: fetched ${points.length} real data points');
    return points;
  }

  /// Tự động kéo dữ liệu từ Samsung Health và lưu vào SQLite.
  /// Tự động kéo dữ liệu từ Samsung Health và lưu vào SQLite.
  /// Chạy khi Samsung Health ở trạng thái sẵn sàng (ready) hoặc đã kết nối (connected).
  Future<void> _autoSyncSamsungHealth() async {
    final svc = SamsungHealthService.instance;
    if (svc.state != SamsungHealthState.ready &&
        svc.state != SamsungHealthState.connected) {
      debugPrint(
        'Samsung Health: not ready or connected (${svc.state}), skipping auto-sync',
      );
      return;
    }

    debugPrint('Samsung Health: auto-sync starting (mode=${svc.modeLabel})...');

    try {
      final samsungPoints = await _fetchSamsungHealthPointsList();
      if (samsungPoints.isNotEmpty) {
        await DatabaseHelper.instance.insertDataPoints(samsungPoints);
        debugPrint(
          'Samsung Health: auto-sync complete, saved ${samsungPoints.length} points to SQLite',
        );
      }
    } catch (e) {
      debugPrint('Samsung Health: auto-sync error (non-fatal): $e');
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

    // Save to local SQLite database so it's not lost on restart
    await DatabaseHelper.instance.insertDataPoint(dataPoint);

    // Also add to local state immediately
    final list = _healthData[dataPoint.type] ?? [];
    list.add(dataPoint);
    list.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
    _healthData[dataPoint.type] = list;
    notifyListeners();
  }

  void _listenSamsungHeartRateStream() {
    _hrStreamSub?.cancel();
    _hrStreamSub = SamsungHealthService.instance.heartRateStream.listen((
      hr,
    ) async {
      if (!hr.isReal) {
        debugPrint('_listenSamsungHeartRateStream: ignoring non-real heart rate event (${hr.source})');
        return;
      }
      final point = HealthDataPoint(
        type: HealthMetricType.heartRate,
        value: hr.bpm.toDouble(),
        unit: HealthMetricType.heartRate.unit,
        dateFrom: hr.timestamp,
        dateTo: hr.timestamp,
        source: hr.source,
      );
      await DatabaseHelper.instance.insertDataPoint(point);
      final list = _healthData[HealthMetricType.heartRate] ?? [];
      list.add(point);
      list.sort((a, b) => a.dateFrom.compareTo(b.dateFrom));
      _healthData[HealthMetricType.heartRate] = list;
      notifyListeners();
    });
  }
}
