import 'package:ai_health/features/barcode_food/presentation/page/screen/barcode_scanner_screen.dart';
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

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  int _refreshTick = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HealthProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('AI Health',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primaryColor,
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BarcodeScannerScreen(
                      repository: foodBarcodeRepository,
                    ),
                  ),
                );
              },
              child: const Icon(Icons.qr_code_2_outlined, color: Colors.white),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        key: ValueKey('tabs_$_refreshTick'),
        index: _currentIndex,
        children: [
          _HomeTab(
            onSynced: () {
              setState(() => _refreshTick++);
            },
          ),
          const AIAdviceScreen(),
          const SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
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
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({this.onSynced});

  final VoidCallback? onSynced;

  @override
  Widget build(BuildContext context) {
    return Consumer<HealthProvider>(
      builder: (context, provider, _) {
        final dataSignature = provider.healthData.entries
            .map(
              (e) =>
                  '${e.key.name}:${e.value.length}:${e.value.isNotEmpty ? e.value.last.dateFrom.millisecondsSinceEpoch : 0}',
            )
            .join('|');

        return CustomScrollView(
          key: ValueKey(dataSignature),
          slivers: [
            SliverToBoxAdapter(child: HealthSummaryHeader(provider: provider)),

            if (!provider.isAuthorized && !provider.isLoading)
              SliverToBoxAdapter(
                child: _buildPermissionCard(context, provider),
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
                              onPressed: () async {
                                try {
                                  await provider.fetchHealthData();
                                  onSynced?.call();

                                  if (context.mounted) {
                                    final total = provider.healthData.values
                                        .fold<int>(0, (s, l) => s + l.length);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Đồng bộ xong • $total bản ghi',
                                        ),
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
                              icon: const Icon(
                                Icons.sync,
                                size: 18,
                                color: Colors.black,
                              ),
                              label: const Text(
                                'Đồng bộ',
                                style: TextStyle(color: Colors.black),
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
            if (provider.isLoading)
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
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
            ],
          ),
        ],
      ),
    );
  }
}
