import 'package:flutter/material.dart';
import '../../models/health_advice.dart';
import '../../utils/app_theme.dart';

class AIAdviceCard extends StatelessWidget {
  final HealthAdvice advice;

  const AIAdviceCard({super.key, required this.advice});

  @override
  Widget build(BuildContext context) {
    final (bgColor, iconColor, icon) = _getAdviceStyle();

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: iconColor.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        advice.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: iconColor,
                        ),
                      ),
                      Text(
                        '${advice.level.label} • Cập nhật lúc ${_formatTime(advice.createdAt)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              advice.content.length > 200
                  ? '${advice.content.substring(0, 200)}...'
                  : advice.content,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textPrimary,
                height: 1.5,
              ),
            ),
            if (advice.metrics.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: advice.metrics
                    .map((m) => Chip(
                          label: Text(m, style: const TextStyle(fontSize: 11)),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  (Color, Color, IconData) _getAdviceStyle() {
    switch (advice.level) {
      case AdviceLevel.urgent:
        return (
          const Color(0xFFFEF2F2),
          AppTheme.dangerColor,
          Icons.warning_rounded,
        );
      case AdviceLevel.warning:
        return (
          const Color(0xFFFFFBEB),
          AppTheme.warningColor,
          Icons.info_rounded,
        );
      case AdviceLevel.suggestion:
        return (
          const Color(0xFFF0FDF4),
          AppTheme.accentColor,
          Icons.lightbulb_rounded,
        );
      case AdviceLevel.info:
        return (
          const Color(0xFFEFF6FF),
          AppTheme.infoColor,
          Icons.check_circle_rounded,
        );
    }
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
