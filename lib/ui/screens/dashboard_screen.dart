import 'dart:async';
import 'package:ai_health/features/barcode_food/presentation/page/screen/barcode_scanner_screen.dart';
import 'package:ai_health/ui/screens/samsung_health_demo_screen.dart';
import '../../services/samsung_health_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai_health/injection_container.dart';
import '../../providers/health_provider.dart';
import '../../models/health_data_point.dart';
import '../../utils/app_theme.dart';
import '../widgets/health_metric_card.dart';
import '../widgets/health_summary_header.dart';
import '../widgets/ai_advice_card.dart';
import '../screens/metric_detail_screen.dart';
import '../screens/ai_advice_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/manual_input_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HealthProvider>().initialize();
    });
    // Tự động đồng bộ dữ liệu sau mỗi 20 giây
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) {
        context.read<HealthProvider>().fetchHealthData();
      }
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _resumeDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Timer? _resumeDebounce;

  /// Refresh when app comes back to foreground from background
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // Debounce: đợi 1 giây sau khi resume để tránh gọi trùng lặp
      _resumeDebounce?.cancel();
      _resumeDebounce = Timer(const Duration(seconds: 1), () {
        if (mounted) {
          debugPrint('App resumed → syncing health data silently');
          context.read<HealthProvider>().fetchHealthData();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'AI Health',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.primaryColor,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: GestureDetector(
              onTap: () => _showSyncGuide(context),
              child: const Icon(Icons.help_outline, color: Colors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        BarcodeScannerScreen(repository: foodBarcodeRepository),
                  ),
                );
              },
              child: const Icon(Icons.qr_code_2_outlined, color: Colors.white),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _HomeTab(onSynced: () {}),
          const AIAdviceScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
          if (index == 0) {
            context.read<HealthProvider>().fetchHealthData();
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Tổng quan',
          ),
          NavigationDestination(
            icon: Icon(Icons.psychology_outlined),
            selectedIcon: Icon(Icons.psychology),
            label: 'AI Tư vấn',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Cài đặt',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ManualInputScreen()),
          );
        },
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showSyncGuide(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          height: MediaQuery.of(context).size.height * 0.82,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hướng Dẫn Đồng Bộ Dữ Liệu',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Quy trình nạp dữ liệu sức khỏe vào AI Health',
                        style: TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 32),

              // Flow Visual Diagram
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🗺️ Sơ đồ luồng dữ liệu tổng quan',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildDiagramWidget(),
                      const SizedBox(height: 24),
                      const Text(
                        '⚙️ Hướng dẫn kết nối chi tiết',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildGuideSteps(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDiagramWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildDiagramNode(
                '⌚ Thiết bị đeo',
                'Galaxy/Apple Watch\nCảm biến máy',
                Icons.watch,
              ),
              const Icon(Icons.arrow_forward_rounded, color: Colors.grey),
              _buildDiagramNode(
                '🔄 Cổng hệ thống',
                'Health Connect\nApple HealthKit',
                Icons.swap_horiz,
              ),
              const Icon(Icons.arrow_forward_rounded, color: Colors.grey),
              _buildDiagramNode(
                '📲 AI Health',
                'Dashboard &\nAI Tư vấn',
                Icons.dashboard_customize,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Đặc biệt cho Samsung Health: App hỗ trợ đồng bộ trực tiếp qua SDK (AAR) sau đó tự động ghi ngược (Back-write) lại vào Health Connect để đồng bộ ra Dashboard chính.',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiagramNode(String title, String desc, IconData icon) {
    return Column(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
          child: Icon(icon, color: AppTheme.primaryColor, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 2),
        Text(
          desc,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildGuideSteps() {
    return Column(
      children: [
        _buildStepItem(
          '1',
          'Dành cho iOS (Apple HealthKit)',
          'Khi lần đầu mở ứng dụng trên iPhone, chọn đồng ý cấp quyền Apple Health. Ứng dụng sẽ tự động tải các dữ liệu Nhịp tim, Bước chân, Giấc ngủ trực tiếp từ HealthKit của Apple.',
          Icons.apple,
        ),
        const SizedBox(height: 16),
        _buildStepItem(
          '2',
          'Dành cho Android (Health Connect)',
          '1. Cài đặt app "Health Connect" từ CH Play (nếu máy chưa có).\n2. Cấp quyền truy cập cho ứng dụng "AI Health" trong cài đặt Health Connect.\n3. Các ứng dụng khác như Google Fit, Samsung Health... cũng cần được cấp quyền ghi vào Health Connect.',
          Icons.android,
        ),
        const SizedBox(height: 16),
        _buildStepItem(
          '3',
          'Đồng bộ trực tiếp Samsung Health (Đặc quyền)',
          'Nhấn biểu tượng nhọt máu (❤️) góc phải AppBar chính để truy cập trình Samsung Health SDK chuyên biệt. Bấm "Bắt đầu kết nối", cấp quyền Android, và nhấn "Bắt đầu đồng bộ" để kéo dữ liệu trực tiếp bằng AAR SDK.',
          Icons.favorite,
        ),
      ],
    );
  }

  Widget _buildStepItem(
    String step,
    String title,
    String description,
    IconData icon,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: Colors.grey[700]),
                  const SizedBox(width: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  color: Colors.grey[800],
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeTab extends StatefulWidget {
  const _HomeTab({this.onSynced});

  final VoidCallback? onSynced;

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  VoidCallback? get onSynced => widget.onSynced;

  @override
  Widget build(BuildContext context) {
    return Consumer<HealthProvider>(
      builder: (context, provider, _) {
        return RefreshIndicator(
          color: AppTheme.primaryColor,
          onRefresh: () async {
            try {
              await provider.fetchHealthData();
              onSynced?.call();
              if (context.mounted) {
                final total = provider.healthData.values.fold<int>(
                  0,
                  (s, l) => s + l.length,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Đồng bộ xong • $total bản ghi'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Lỗi đồng bộ: $e'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          },
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: HealthSummaryHeader(provider: provider),
              ),

              if (provider.needsSyncSourceSelection)
                SliverToBoxAdapter(
                  child: _buildSyncSourceSelector(context, provider),
                ),

              if (!provider.needsSyncSourceSelection &&
                  provider.selectedSyncSource == 'health_connect' &&
                  !provider.isAuthorized &&
                  !provider.isLoading)
                SliverToBoxAdapter(
                  child: _buildPermissionCard(context, provider),
                ),

              // Samsung Health Card
              if (!provider.needsSyncSourceSelection &&
                  provider.selectedSyncSource == 'samsung')
                SliverToBoxAdapter(
                  child: _buildSamsungHealthCard(context, provider),
                ),

              // tải dữ liệu và phân tích AI
              if (provider.isAnalyzing)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.blue,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text('🤖 AI đang phân tích dữ liệu sức khỏe...'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Quick AI Advice Card
              if (provider.latestAdvice != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: AIAdviceCard(advice: provider.latestAdvice!),
                  ),
                ),

              // Section: Health Metrics
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Chỉ số sức khỏe',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: provider.isLoading
                                    ? null
                                    : () async {
                                        try {
                                          await provider.fetchHealthData();
                                          onSynced?.call();

                                          if (context.mounted) {
                                            final total = provider
                                                .healthData
                                                .values
                                                .fold<int>(
                                                  0,
                                                  (s, l) => s + l.length,
                                                );
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Đồng bộ xong • $total bản ghi',
                                                ),
                                                behavior:
                                                    SnackBarBehavior.floating,
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Lỗi đồng bộ: $e',
                                                ),
                                                behavior:
                                                    SnackBarBehavior.floating,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                icon: provider.isLoading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.sync,
                                        size: 18,
                                        color: Colors.black,
                                      ),
                                label: Text(
                                  provider.isLoading
                                      ? 'Đang đồng bộ...'
                                      : 'Đồng bộ',
                                  style: const TextStyle(color: Colors.black),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Show data source info
                      if (provider.healthData.values.any((l) => l.isNotEmpty))
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _getDataSourceInfo(provider),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textSecondary.withValues(
                                alpha: 0.9,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Metric cards grid
              if (provider.isLoading &&
                  provider.healthData.values.every((list) => list.isEmpty))
                const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1.1,
                        ),
                    delegate: SliverChildListDelegate(
                      _buildMetricCards(context, provider),
                    ),
                  ),
                ),

              // Bottom padding
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildMetricCards(
    BuildContext context,
    HealthProvider provider,
  ) {
    final metrics = [
      HealthMetricType.heartRate,
      HealthMetricType.bloodPressure,
      HealthMetricType.bloodGlucose,
      HealthMetricType.spo2,
      HealthMetricType.bodyTemperature,
      HealthMetricType.steps,
    ];

    return metrics.map((type) {
      final dataPoints = provider.getMetricData(type);
      final latest = provider.getLatest(type);

      return HealthMetricCard(
        metricType: type,
        latestValue: latest,
        dataPoints: dataPoints,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MetricDetailScreen(metricType: type),
            ),
          );
        },
      );
    }).toList();
  }

  String _getDataSourceInfo(HealthProvider provider) {
    final sources = <String>{};
    for (final list in provider.healthData.values) {
      for (final dp in list) {
        if (dp.source.isNotEmpty) sources.add(dp.source);
      }
    }
    final total = provider.healthData.values.fold<int>(
      0,
      (s, l) => s + l.length,
    );
    return '$total bản ghi';
  }

  Widget _buildSyncSourceSelector(
    BuildContext context,
    HealthProvider provider,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: AppTheme.primaryLight.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sync_lock, color: AppTheme.primaryColor, size: 26),
              const SizedBox(width: 10),
              const Text(
                'Chọn nguồn đồng bộ',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Chọn nguồn dữ liệu sức khỏe chính của bạn để bắt đầu.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),

          // Option 1: Samsung Health
          _buildOptionTile(
            context: context,
            title: 'Samsung Health (SDK)',
            subtitle: 'Đọc trực tiếp từ Samsung SDK & Galaxy Watch.',
            icon: Icons.watch,
            color: const Color(0xFF1565C0),
            badgeText: provider.isSamsungDevice
                ? 'Khuyên dùng cho máy Samsung ✨'
                : null,
            onTap: () => provider.selectSyncSource('samsung'),
          ),

          const SizedBox(height: 12),

          // Option 2: Health Connect
          _buildOptionTile(
            context: context,
            title: 'Google Health Connect',
            subtitle: 'Đồng bộ cho các dòng máy Android khác.',
            icon: Icons.swap_horiz,
            color: Colors.green.shade700,
            badgeText: !provider.isSamsungDevice
                ? 'Khuyên dùng cho máy khác ✨'
                : null,
            onTap: () => provider.selectSyncSource('health_connect'),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    String? badgeText,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2), width: 1.2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  if (badgeText != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badgeText,
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14, color: color),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionCard(BuildContext context, HealthProvider provider) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryLight.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.health_and_safety,
            size: 48,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(height: 12),
          const Text(
            'Kết nối dữ liệu sức khỏe',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            provider.isHealthAvailable
                ? 'Cho phép ứng dụng truy cập dữ liệu từ HealthKit/Health Connect để theo dõi sức khỏe.'
                : 'Thiết bị không hỗ trợ Health Connect. Vui lòng cài đặt Health Connect từ Google Play.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!provider.isHealthAvailable)
                ElevatedButton.icon(
                  onPressed: () => provider.installHealthConnect(),
                  icon: const Icon(Icons.download),
                  label: const Text('Cài đặt HC'),
                ),
              if (provider.isHealthAvailable)
                ElevatedButton.icon(
                  onPressed: () => provider.requestPermissions(),
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Cấp quyền'),
                ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => provider.resetSyncSource(),
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Đổi nguồn'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade700,
                  side: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSamsungHealthCard(
    BuildContext context,
    HealthProvider provider,
  ) {
    final svc = SamsungHealthService.instance;
    final state = svc.state;
    final isConnected =
        state == SamsungHealthState.connected ||
        state == SamsungHealthState.ready;
    final isReady = state == SamsungHealthState.ready;

    // Status color & label
    Color statusColor;
    String statusLabel;
    if (isReady) {
      statusColor = Colors.green;
      statusLabel = '● Đã kết nối · ${svc.modeEmoji} ${svc.modeLabel}';
    } else if (isConnected) {
      statusColor = Colors.orange;
      statusLabel = '● Chưa cấp quyền';
    } else {
      statusColor = Colors.grey;
      statusLabel = '○ Chưa kết nối';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              const Icon(Icons.monitor_heart, color: Colors.white, size: 28),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Samsung Health',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor == Colors.green
                        ? Colors.greenAccent
                        : Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isReady
                ? 'Đang đọc dữ liệu thực từ Samsung Health. Nhấn đồng bộ để cập nhật chỉ số mới nhất.'
                : isConnected
                ? 'Đã kết nối. Cấp quyền cho phép ứng dụng đọc dữ liệu sức khoẻ từ Samsung Health.'
                : 'Kết nối Samsung Health để đọc nhịp tim, bước chân, huyết áp và các chỉ số khác từ Galaxy Watch.',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          // Action buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!isConnected)
                _samsungActionButton(
                  label: 'Kết nối',
                  icon: Icons.link,
                  onTap: () async {
                    await svc.connect();
                    if (mounted) setState(() {});
                  },
                ),
              if (isConnected && !isReady)
                _samsungActionButton(
                  label: 'Cấp quyền',
                  icon: Icons.lock_open,
                  onTap: () async {
                    await svc.requestPermission();
                    if (mounted) setState(() {});
                  },
                ),
              if (isReady)
                _samsungActionButton(
                  label: 'Đồng bộ ngay',
                  icon: Icons.sync,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SamsungHealthDemoScreen(),
                      ),
                    );
                    if (context.mounted) {
                      await provider.fetchHealthData();
                    }
                  },
                ),
              _samsungActionButton(
                label: 'Chi tiết',
                icon: Icons.open_in_new,
                outline: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const SamsungHealthDemoScreen(),
                    ),
                  ).then((_) {
                    if (context.mounted) provider.fetchHealthData();
                  });
                },
              ),
              _samsungActionButton(
                label: 'Đổi nguồn',
                icon: Icons.swap_horiz,
                outline: true,
                onTap: () => provider.resetSyncSource(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _samsungActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool outline = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: outline ? Colors.transparent : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: outline ? Border.all(color: Colors.white54) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: outline ? Colors.white : const Color(0xFF1565C0),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: outline ? Colors.white : const Color(0xFF1565C0),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
