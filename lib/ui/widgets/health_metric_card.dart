import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/health_data_point.dart';
import '../../utils/app_theme.dart';

class HealthMetricCard extends StatelessWidget {
  final HealthMetricType metricType;
  final HealthDataPoint? latestValue;
  final List<HealthDataPoint> dataPoints;
  final VoidCallback onTap;

  const HealthMetricCard({
    super.key,
    required this.metricType,
    this.latestValue,
    required this.dataPoints,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.getMetricColor(metricType);
    final hasData = latestValue != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      metricType.icon,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      metricType.displayName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Value
              if (hasData) ...[
                Text(
                  latestValue!.displayValue,
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  metricType.unit,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textLight,
                  ),
                ),
              ] else ...[
                const Text(
                  '--',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textLight,
                  ),
                ),
                const Text(
                  'Chưa có dữ liệu',
                  style: TextStyle(fontSize: 11, color: AppTheme.textLight),
                ),
              ],

              const Spacer(),

              // Mini chart or status
              if (dataPoints.length > 2)
                SizedBox(
                  height: 26,
                  child: _buildMiniChart(color),
                )
              else if (hasData)
                _buildStatusBadge(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniChart(Color color) {
    final spots = <FlSpot>[];
    for (int i = 0; i < dataPoints.length; i++) {
      spots.add(FlSpot(i.toDouble(), dataPoints[i].value));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineTouchData: const LineTouchData(enabled: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    if (latestValue == null) return const SizedBox.shrink();

    final status = latestValue!.status;
    final statusColor = AppTheme.getStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: statusColor,
        ),
      ),
    );
  }
}
