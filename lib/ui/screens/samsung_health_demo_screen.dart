// lib/ui/screens/samsung_health_demo_screen.dart
// Demo: Luồng Samsung Health App → App của bạn

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/samsung_health_service.dart';
import '../../providers/health_provider.dart';
import '../../models/health_data_point.dart';

class SamsungHealthDemoScreen extends StatefulWidget {
  const SamsungHealthDemoScreen({super.key});

  @override
  State<SamsungHealthDemoScreen> createState() =>
      _SamsungHealthDemoScreenState();
}

class _SamsungHealthDemoScreenState extends State<SamsungHealthDemoScreen>
    with TickerProviderStateMixin {
  final _svc = SamsungHealthService.instance;

  bool _loading = false;
  bool? _installed;
  List<String> _logs = [];

  SamsungStepData? _steps;
  SamsungHeartRateData? _hr;
  SamsungSleepData? _sleep;
  SamsungCalorieData? _calories;
  SamsungBloodPressureData? _bp;
  SamsungBloodGlucoseData? _bg;
  SamsungSpO2Data? _spo2;
  SamsungBodyTemperatureData? _temp;
  SamsungWeightData? _weight;
  SamsungHeightData? _height;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.94,
      end: 1.06,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));

    _checkInstall();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  void _addLog(String msg) {
    setState(() => _logs.insert(0, '${_ts()} $msg'));
  }

  String _ts() {
    final now = DateTime.now();
    return '[${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}]';
  }

  Future<void> _checkInstall() async {
    final v = await _svc.isSamsungHealthInstalled();
    setState(() => _installed = v);
    _addLog(
      v
          ? '✅ Samsung Health đã được cài trên thiết bị này'
          : '⚠️  Samsung Health chưa được cài → sẽ dùng DEMO data',
    );
  }

  Future<void> _connect() async {
    setState(() => _loading = true);
    final r = await _svc.connect();
    _addLog('🔗 Kết nối: ${r['message']}');
    setState(() => _loading = false);
    _slideCtrl.forward();
  }

  Future<void> _requestPerm() async {
    setState(() => _loading = true);
    final r = await _svc.requestPermission();
    if (r['granted'] == true) {
      _addLog('🔑 Quyền được cấp: ${(r['permissions'] as List).join(', ')}');
    } else {
      _addLog('❌ Quyền bị từ chối: ${r['message']}');
    }
    setState(() => _loading = false);
  }

  Future<void> _fetchAll() async {
    setState(() => _loading = true);
    _addLog('📡 Đang đọc dữ liệu từ Samsung Health...');
    try {
      final steps = await _svc.getSteps();
      final hr = await _svc.getHeartRate();
      final sleep = await _svc.getSleep();
      final cal = await _svc.getCalories();
      final bp = await _svc.getBloodPressure();
      final bg = await _svc.getBloodGlucose();
      final spo2 = await _svc.getSpO2();
      final temp = await _svc.getBodyTemperature();
      final weight = await _svc.getWeight();
      final height = await _svc.getHeight();
      setState(() {
        _steps = steps;
        _hr = hr;
        _sleep = sleep;
        _calories = cal;
        _bp = bp;
        _bg = bg;
        _spo2 = spo2;
        _temp = temp;
        _weight = weight;
        _height = height;
      });
      _addLog('👟 Bước chân: ${steps?.steps} [Nguồn: ${steps?.source}]');
      _addLog('❤️ Nhịp tim: ${hr?.bpm} bpm [Nguồn: ${hr?.source}]');
      _addLog(
        '🛌 Giấc ngủ: ${sleep?.totalFormatted} [Nguồn: ${sleep?.source}]',
      );
      _addLog(
        '🔥 Calories: ${cal?.totalCalories} kcal [Nguồn: ${cal?.source}]',
      );
      _addLog(
        '🩸 Huyết áp: ${bp?.systolic}/${bp?.diastolic} [Nguồn: ${bp?.source}]',
      );
      _addLog('🍬 Đường huyết: ${bg?.glucose} [Nguồn: ${bg?.source}]');
      _addLog('🫁 SpO2: ${spo2?.spo2}% [Nguồn: ${spo2?.source}]');
      _addLog('🌡️ Nhiệt độ: ${temp?.temperature}°C [Nguồn: ${temp?.source}]');
      _addLog('⚖️ Cân nặng: ${weight?.weight} kg [Nguồn: ${weight?.source}]');
      _addLog('📏 Chiều cao: ${height?.height} cm [Nguồn: ${height?.source}]');

      if (mounted) {
        final provider = context.read<HealthProvider>();

        if (steps != null) {
          await provider.addManualDataPoint(
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
        if (hr != null) {
          await provider.addManualDataPoint(
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
        if (bp != null) {
          await provider.addManualDataPoint(
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
        if (bg != null) {
          await provider.addManualDataPoint(
            HealthDataPoint(
              type: HealthMetricType.bloodGlucose,
              value: bg.glucose,
              unit: HealthMetricType.bloodGlucose.unit,
              dateFrom: bg.timestamp,
              dateTo: bg.timestamp,
              source: bg.source,
            ),
          );
        }
        if (spo2 != null) {
          await provider.addManualDataPoint(
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
        if (temp != null) {
          await provider.addManualDataPoint(
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
        if (weight != null) {
          await provider.addManualDataPoint(
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
        if (height != null) {
          await provider.addManualDataPoint(
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

        _addLog('💾 Đã lưu dữ liệu vào Dashboard!');
      }
    } catch (e) {
      _addLog('❌ Lỗi: $e');
    }
    setState(() => _loading = false);
  }

  Future<void> _openSHealth() async {
    final r = await _svc.openSamsungHealth();
    _addLog(
      r['success'] == true
          ? '📱 Mở Samsung Health thành công'
          : '❌ ${r['message']}',
    );
  }

  Future<void> _disconnect() async {
    await _svc.disconnect();
    setState(() {
      _steps = null;
      _hr = null;
      _sleep = null;
      _calories = null;
      _bp = null;
      _bg = null;
      _spo2 = null;
      _temp = null;
      _weight = null;
      _height = null;
    });
    _addLog('🔌 Đã ngắt kết nối');
    _slideCtrl.reverse();
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white70,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Samsung Health',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Direct Integration Demo',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
        actions: [
          if (_installed == true)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: _openSHealth,
                icon: const Icon(
                  Icons.open_in_new,
                  size: 14,
                  color: Color(0xFF10B981),
                ),
                label: const Text(
                  'Mở SHealth',
                  style: TextStyle(color: Color(0xFF10B981), fontSize: 12),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (_svc.state == SamsungHealthState.ready) {
            await _fetchAll();
          } else {
            _addLog(
              '⚠️ Thiết bị chưa kết nối hoặc chưa cấp quyền. Vui lòng hoàn thành các bước bên dưới.',
            );
          }
        },
        color: const Color(0xFF10B981),
        backgroundColor: const Color(0xFF1E293B),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFlowDiagram(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildStatusCard(),
                    const SizedBox(height: 16),
                    _buildStepButtons(),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(
                          backgroundColor: Color(0xFF1E293B),
                          color: Color(0xFF10B981),
                        ),
                      ),
                    const SizedBox(height: 16),
                    // Data cards
                    if (_steps != null ||
                        _hr != null ||
                        _sleep != null ||
                        _calories != null ||
                        _bp != null ||
                        _bg != null ||
                        _spo2 != null ||
                        _temp != null ||
                        _weight != null ||
                        _height != null) ...[
                      SlideTransition(
                        position: _slideAnim,
                        child: _buildDataGrid(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildLog(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Flow Diagram ──────────────────────────────────────────────────────────
  Widget _buildFlowDiagram() {
    final isReady = _svc.state == SamsungHealthState.ready;
    const activeColor = Color(0xFF10B981);
    final inactiveColor = Colors.white.withOpacity(0.08);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E293B),
            const Color(0xFF0F172A).withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.hub_outlined, color: Colors.blueAccent, size: 14),
              SizedBox(width: 6),
              Text(
                'SƠ ĐỒ LUỒNG ĐỒNG BỘ DỮ LIỆU',
                style: TextStyle(
                  color: Colors.white30,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _flowBox(
                  icon: Icons.favorite_rounded,
                  label: 'Samsung\nHealth',
                  color: isReady ? activeColor : inactiveColor,
                  iconColor: isReady ? const Color(0xFFEF4444) : Colors.white30,
                  isActive: isReady,
                ),
              ),
              _flowArrow(isReady),
              Expanded(
                child: _flowBox(
                  icon: _svc.mode == SamsungHealthMode.sensor
                      ? Icons.settings_input_antenna
                      : Icons.cloud_done_rounded,
                  label: _svc.mode == SamsungHealthMode.sensor
                      ? 'Cảm Biến\nPhần Cứng'
                      : 'Dữ Liệu\nMô Phỏng',
                  color: isReady ? const Color(0xFF3B82F6) : inactiveColor,
                  iconColor: isReady ? const Color(0xFF60A5FA) : Colors.white30,
                  isActive: isReady,
                ),
              ),
              _flowArrow(isReady),
              Expanded(
                child: _flowBox(
                  icon: Icons.check_circle_rounded,
                  label: 'App\nCủa Bạn',
                  color: isReady ? activeColor : inactiveColor,
                  iconColor: isReady ? const Color(0xFF10B981) : Colors.white30,
                  isActive: isReady,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _flowBox({
    required IconData icon,
    required String label,
    required Color color,
    required Color iconColor,
    required bool isActive,
  }) {
    return ScaleTransition(
      scale: isActive ? _pulseAnim : const AlwaysStoppedAnimation(1.0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isActive
              ? color.withOpacity(0.08)
              : Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? color.withOpacity(0.3)
                : Colors.white.withOpacity(0.05),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 22),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white30,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _flowArrow(bool isActive) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chevron_right_rounded,
            color: isActive ? const Color(0xFF10B981) : Colors.white12,
            size: 20,
          ),
        ],
      ),
    );
  }

  // ─── Status Card ──────────────────────────────────────────────────────────
  Widget _buildStatusCard() {
    final stateColor =
        {
          SamsungHealthState.disconnected: Colors.white30,
          SamsungHealthState.connecting: Colors.orange,
          SamsungHealthState.connected: Colors.blue,
          SamsungHealthState.permissionPending: Colors.yellow,
          SamsungHealthState.ready: const Color(0xFF10B981),
          SamsungHealthState.error: Colors.red,
        }[_svc.state] ??
        Colors.white30;

    final stateLabel =
        {
          SamsungHealthState.disconnected: 'Chưa kết nối',
          SamsungHealthState.connecting: 'Đang kết nối...',
          SamsungHealthState.connected: 'Đã kết nối',
          SamsungHealthState.permissionPending: 'Đang xin quyền...',
          SamsungHealthState.ready: 'Đồng bộ sẵn sàng ✓',
          SamsungHealthState.error: 'Lỗi kết nối',
        }[_svc.state] ??
        '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: stateColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: stateColor.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: stateColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: stateColor.withOpacity(0.8),
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                stateLabel,
                style: TextStyle(
                  color: stateColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              if (_svc.state != SamsungHealthState.disconnected) _modeBadge(),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: Colors.white.withOpacity(0.08), height: 1),
          const SizedBox(height: 10),
          _statusRow(
            'Ứng dụng Samsung Health:',
            _installed == null
                ? 'Đang kiểm tra...'
                : (_installed! ? 'Đã phát hiện trên máy ✅' : 'Chưa cài đặt ❌'),
          ),
          _statusRow('Chế độ đồng bộ:', '${_svc.modeEmoji} ${_svc.modeLabel}'),
          _statusRow(
            'Nguồn dữ liệu hiện tại:',
            _svc.mode == SamsungHealthMode.sensor
                ? '📡 Cảm biến bước chân phần cứng (HW)'
                : _svc.mode == SamsungHealthMode.provider
                ? '🔗 Samsung Health ContentProvider'
                : _svc.mode == SamsungHealthMode.real
                ? '📱 Samsung Health SDK'
                : '🧪 Dữ liệu mô phỏng (Demo)',
          ),
        ],
      ),
    );
  }

  Widget _modeBadge() {
    final (color, label) = switch (_svc.mode) {
      SamsungHealthMode.real => (const Color(0xFF10B981), '📱 SDK THẬT'),
      SamsungHealthMode.provider => (Colors.blue, '🔗 REAL DATA'),
      SamsungHealthMode.sensor => (const Color(0xFF00BCD4), '📡 CẢM BIẾN'),
      SamsungHealthMode.demo => (Colors.orange, '🧪 DEMO'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _statusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Step Buttons / Stepper ───────────────────────────────────────────────
  Widget _buildStepButtons() {
    final state = _svc.state;

    // Step 1 status
    bool step1Active =
        state == SamsungHealthState.disconnected ||
        state == SamsungHealthState.connecting;
    bool step1Done =
        state != SamsungHealthState.disconnected &&
        state != SamsungHealthState.connecting;

    // Step 2 status
    bool step2Active =
        state == SamsungHealthState.connected ||
        state == SamsungHealthState.error;
    bool step2Done =
        state == SamsungHealthState.permissionPending ||
        state == SamsungHealthState.ready;

    // Step 3 status
    bool step3Active =
        state == SamsungHealthState.permissionPending ||
        state == SamsungHealthState.ready;
    bool step3Done = _steps != null || _hr != null; // data loaded

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '🛠️ CÁC BƯỚC THỰC HIỆN ĐỒNG BỘ',
          style: TextStyle(
            color: Colors.white30,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 12),
        _stepTimelineItem(
          stepNumber: 1,
          title: 'Kết nối thiết bị & Cảm biến',
          description:
              'Kiểm tra phần cứng cảm biến đếm bước (Step Counter) và ứng dụng Samsung Health.',
          isActive: step1Active,
          isDone: step1Done,
          btnLabel: 'Bắt đầu kết nối',
          icon: Icons.link_rounded,
          color: const Color(0xFF3B82F6),
          onTap: _connect,
        ),
        _stepTimelineDivider(isDone: step1Done),
        _stepTimelineItem(
          stepNumber: 2,
          title: 'Cấp quyền hoạt động thể chất',
          description:
              'Cấp quyền ACTIVITY_RECOGNITION để ứng dụng đọc số bước trực tiếp từ chip cảm biến đếm bước phần cứng.',
          isActive: step2Active,
          isDone: step2Done,
          btnLabel: 'Cấp quyền hệ thống',
          icon: Icons.security_rounded,
          color: const Color(0xFF8B5CF6),
          onTap: _requestPerm,
        ),
        _stepTimelineDivider(isDone: step2Done),
        _stepTimelineItem(
          stepNumber: 3,
          title: 'Đồng bộ chỉ số sức khỏe',
          description:
              'Đồng bộ toàn bộ các chỉ số sức khỏe thực tế (bước chân, nhịp tim, giấc ngủ, huyết áp, đường huyết, SpO2, nhiệt độ, cân nặng, chiều cao) trực tiếp từ Samsung Health SDK.',
          isActive: step3Active,
          isDone: step3Done,
          btnLabel: 'Bắt đầu đồng bộ',
          icon: Icons.sync_rounded,
          color: const Color(0xFF10B981),
          onTap: _fetchAll,
        ),
        if (state != SamsungHealthState.disconnected) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _loading ? null : _disconnect,
              icon: const Icon(
                Icons.link_off_rounded,
                size: 14,
                color: Colors.redAccent,
              ),
              label: const Text(
                'Ngắt kết nối & Reset',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _stepTimelineItem({
    required int stepNumber,
    required String title,
    required String description,
    required bool isActive,
    required bool isDone,
    required String btnLabel,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final statusColor = isDone
        ? const Color(0xFF10B981)
        : (isActive ? color : Colors.white24);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF1E293B)
            : const Color(0xFF161B22).withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? color.withOpacity(0.5)
              : (isDone
                    ? const Color(0xFF10B981).withOpacity(0.3)
                    : Colors.white.withOpacity(0.05)),
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: color.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step circle badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDone
                  ? const Color(0xFF10B981).withOpacity(0.1)
                  : (isActive
                        ? color.withOpacity(0.1)
                        : Colors.white.withOpacity(0.03)),
              shape: BoxShape.circle,
              border: Border.all(color: statusColor),
            ),
            child: Center(
              child: isDone
                  ? const Icon(Icons.check, color: Color(0xFF10B981), size: 16)
                  : Text(
                      '$stepNumber',
                      style: TextStyle(
                        color: isActive ? color : Colors.white30,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isActive
                        ? Colors.white
                        : (isDone ? Colors.white70 : Colors.white30),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    color: isActive ? Colors.white70 : Colors.white38,
                    fontSize: 11,
                    height: 1.3,
                  ),
                ),
                if (isActive) ...[
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: _loading ? null : onTap,
                    icon: Icon(icon, size: 14, color: Colors.white),
                    label: Text(
                      btnLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepTimelineDivider({required bool isDone}) {
    return Container(
      height: 12,
      margin: const EdgeInsets.only(
        left: 27,
      ), // align with center of 32px badge
      width: 2,
      decoration: BoxDecoration(
        color: isDone
            ? const Color(0xFF10B981).withOpacity(0.3)
            : Colors.white.withOpacity(0.05),
      ),
    );
  }

  // ─── Data Grid ────────────────────────────────────────────────────────────
  Widget _buildDataGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '📊 DỮ LIỆU SỨC KHỎE ĐÃ ĐỒNG BỘ',
              style: TextStyle(
                color: Colors.white30,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
            const Spacer(),
            Text(
              'Nguồn: ${_steps?.source ?? "Cảm biến"}',
              style: const TextStyle(color: Colors.white38, fontSize: 10),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.15,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          children: [
            if (_steps != null)
              _dataCard(
                icon: Icons.directions_walk_rounded,
                colors: [const Color(0xFF10B981), const Color(0xFF059669)],
                title: 'Số bước',
                value: _formatNum(_steps!.steps),
                sub1: 'Quãng đường: ${_steps!.distanceKm} km',
                sub2: 'Năng lượng: ${_steps!.calories} kcal',
                isReal: _steps!.isReal,
              ),
            if (_hr != null)
              _dataCard(
                icon: Icons.favorite_rounded,
                colors: [const Color(0xFFEF4444), const Color(0xFFDC2626)],
                title: 'Nhịp tim',
                value: '${_hr!.bpm} bpm',
                sub1: 'Trạng thái: ${_hr!.status}',
                sub2: 'Đo lúc: ${_formatTime(_hr!.timestamp)}',
                isReal: _hr!.isReal,
              ),
            if (_sleep != null)
              _dataCard(
                icon: Icons.bedtime_rounded,
                colors: [const Color(0xFF6366F1), const Color(0xFF4F46E5)],
                title: 'Giấc ngủ',
                value: _sleep!.totalFormatted,
                sub1:
                    'Sâu: ${_sleep!.deepMinutes}ph | REM: ${_sleep!.remMinutes}ph',
                sub2: 'Chất lượng: ${_sleep!.quality}',
                isReal: _sleep!.isReal,
              ),
            if (_calories != null)
              _dataCard(
                icon: Icons.local_fire_department_rounded,
                colors: [const Color(0xFFF59E0B), const Color(0xFFD97706)],
                title: 'Calories',
                value: '${_calories!.totalCalories} kcal',
                sub1: 'Hoạt động: ${_calories!.activeCalories} kcal',
                sub2: 'BMR (Tĩnh): ${_calories!.bmrCalories} kcal',
                isReal: _calories!.isReal,
              ),
            if (_bp != null)
              _dataCard(
                icon: Icons.heart_broken_rounded,
                colors: [const Color(0xFFFF5252), const Color(0xFFFF1744)],
                title: 'Huyết áp',
                value: '${_bp!.systolic}/${_bp!.diastolic}',
                sub1: 'Đơn vị: mmHg',
                sub2: 'Đo lúc: ${_formatTime(_bp!.timestamp)}',
                isReal: _bp!.isReal,
              ),
            if (_bg != null)
              _dataCard(
                icon: Icons.bloodtype_rounded,
                colors: [const Color(0xFFFF7043), const Color(0xFFF4511E)],
                title: 'Đường huyết',
                value: '${_bg!.glucose} mmol/L',
                sub1: 'Trạng thái: Bình thường',
                sub2: 'Đo lúc: ${_formatTime(_bg!.timestamp)}',
                isReal: _bg!.isReal,
              ),
            if (_spo2 != null)
              _dataCard(
                icon: Icons.opacity_rounded,
                colors: [const Color(0xFF00E5FF), const Color(0xFF00B0FF)],
                title: 'SpO2',
                value: '${_spo2!.spo2}%',
                sub1: 'Độ bão hòa oxy',
                sub2: 'Đo lúc: ${_formatTime(_spo2!.timestamp)}',
                isReal: _spo2!.isReal,
              ),
            if (_temp != null)
              _dataCard(
                icon: Icons.thermostat_rounded,
                colors: [const Color(0xFFFFD740), const Color(0xFFFFC400)],
                title: 'Nhiệt độ',
                value: '${_temp!.temperature}°C',
                sub1: 'Nhiệt độ cơ thể',
                sub2: 'Đo lúc: ${_formatTime(_temp!.timestamp)}',
                isReal: _temp!.isReal,
              ),
            if (_weight != null)
              _dataCard(
                icon: Icons.monitor_weight_rounded,
                colors: [const Color(0xFFAB47BC), const Color(0xFF8E24AA)],
                title: 'Cân nặng',
                value: '${_weight!.weight} kg',
                sub1: 'Hồ sơ cá nhân',
                sub2: 'Đo lúc: ${_formatTime(_weight!.timestamp)}',
                isReal: _weight!.isReal,
              ),
            if (_height != null)
              _dataCard(
                icon: Icons.height_rounded,
                colors: [const Color(0xFF26A69A), const Color(0xFF00897B)],
                title: 'Chiều cao',
                value: '${_height!.height} cm',
                sub1: 'Hồ sơ cá nhân',
                sub2: 'Đo lúc: ${_formatTime(_height!.timestamp)}',
                isReal: _height!.isReal,
              ),
          ],
        ),
      ],
    );
  }

  Widget _dataCard({
    required IconData icon,
    required List<Color> colors,
    required String title,
    required String value,
    required String sub1,
    required String sub2,
    required bool isReal,
  }) {
    final primaryColor = colors.first;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: primaryColor, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: isReal
                      ? const Color(0xFF10B981).withOpacity(0.1)
                      : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isReal
                        ? const Color(0xFF10B981).withOpacity(0.3)
                        : Colors.orange.withOpacity(0.3),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  isReal ? 'REAL' : 'DEMO',
                  style: TextStyle(
                    color: isReal ? const Color(0xFF10B981) : Colors.orange,
                    fontSize: 7,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: primaryColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            sub1,
            style: const TextStyle(color: Colors.white70, fontSize: 9),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            sub2,
            style: const TextStyle(color: Colors.white38, fontSize: 9),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ─── Log Console ──────────────────────────────────────────────────────────
  Widget _buildLog() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Terminal Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
              ),
            ),
            child: Row(
              children: [
                // macOS style window controls
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                const Text(
                  'developer_console.sh',
                  style: TextStyle(
                    color: Colors.white38,
                    fontSize: 10,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _logs = []),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'CLEAR',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 8,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Terminal Body
          Container(
            padding: const EdgeInsets.all(12),
            height: 180,
            color: const Color(0xFF0F172A),
            child: _logs.isEmpty
                ? const Center(
                    child: Text(
                      'Chưa có log. Thực hiện các bước phía trên để bắt đầu...',
                      style: TextStyle(
                        color: Colors.white24,
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        fontFamily: 'monospace',
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (context, idx) {
                      final log = _logs[idx];
                      Color textColor = Colors.white70;
                      if (log.contains('✅') ||
                          log.contains('thành công') ||
                          log.contains('Sẵn sàng')) {
                        textColor = const Color(0xFF34D399); // emerald-400
                      } else if (log.contains('❌') ||
                          log.contains('Lỗi') ||
                          log.contains('bị từ chối')) {
                        textColor = const Color(0xFFF87171); // red-400
                      } else if (log.contains('⚠️') || log.contains('chưa')) {
                        textColor = const Color(0xFFFBBF24); // amber-400
                      } else if (log.contains('🔗') || log.contains('📡')) {
                        textColor = const Color(0xFF60A5FA); // blue-400
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          log,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 10,
                            fontFamily: 'monospace',
                            height: 1.4,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ─── Utils ────────────────────────────────────────────────────────────────
  String _formatNum(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );

  String _formatTime(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
