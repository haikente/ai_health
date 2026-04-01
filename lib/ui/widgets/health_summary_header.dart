import 'package:flutter/material.dart';
import '../../providers/health_provider.dart';
import '../../models/health_data_point.dart';
import '../../utils/app_theme.dart';

class HealthSummaryHeader extends StatelessWidget {
  final HealthProvider provider;

  const HealthSummaryHeader({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final hasData = provider.healthData.values.any((list) => list.isNotEmpty);
    final abnormalCount = _getAbnormalCount();

    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: const BoxDecoration(
        gradient: AppTheme.headerGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App bar row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Health',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Theo dõi sức khỏe thông minh',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: const Icon(Icons.person, color: Colors.white),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Status cards
            Row(
              children: [
                Expanded(
                  child: _buildStatusChip(
                    icon: Icons.favorite,
                    label: hasData ? 'Đang theo dõi' : 'Chưa kết nối',
                    color: hasData ? AppTheme.accentColor : Colors.white54,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatusChip(
                    icon: abnormalCount > 0
                        ? Icons.warning_amber
                        : Icons.check_circle,
                    label: abnormalCount > 0
                        ? '$abnormalCount chỉ số bất thường'
                        : 'Tất cả bình thường',
                    color: abnormalCount > 0
                        ? AppTheme.warningColor
                        : AppTheme.accentColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // AI Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: provider.isAnalyzing
                    ? null
                    : () => provider.getAIAdvice(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primaryDark,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: provider.isAnalyzing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome, size: 20),
                label: Text(
                  provider.isAnalyzing
                      ? 'AI đang phân tích...'
                      : '🤖 Phân tích sức khỏe bằng AI',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getAbnormalCount() {
    int count = 0;
    provider.healthData.forEach((type, data) {
      if (data.isNotEmpty) {
        final status = data.last.status;
        if (status != HealthStatus.normal) count++;
      }
    });
    return count;
  }

  Widget _buildStatusChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
