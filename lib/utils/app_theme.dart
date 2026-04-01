import 'package:flutter/material.dart';
import '../models/health_data_point.dart';

/// App theme and color constants
class AppTheme {
  // Primary colors
  static const Color primaryColor = Color(0xFF2563EB);
  static const Color primaryLight = Color(0xFF60A5FA);
  static const Color primaryDark = Color(0xFF1D4ED8);

  // Accent colors
  static const Color accentColor = Color(0xFF10B981);
  static const Color accentLight = Color(0xFF34D399);

  // Background colors
  static const Color backgroundColor = Color(0xFFF8FAFC);
  static const Color surfaceColor = Colors.white;
  static const Color cardColor = Colors.white;

  // Text colors
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textLight = Color(0xFF94A3B8);

  // Status colors
  static const Color normalColor = Color(0xFF10B981);
  static const Color warningColor = Color(0xFFF59E0B);
  static const Color dangerColor = Color(0xFFEF4444);
  static const Color infoColor = Color(0xFF3B82F6);
  static const Color lowColor = Color(0xFF6366F1);

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF7C3AED)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient headerGradient = LinearGradient(
    colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static Color getStatusColor(HealthStatus status) {
    switch (status) {
      case HealthStatus.normal:
        return normalColor;
      case HealthStatus.low:
        return lowColor;
      case HealthStatus.warning:
        return warningColor;
      case HealthStatus.high:
        return dangerColor;
      case HealthStatus.critical:
        return dangerColor;
    }
  }

  static Color getMetricColor(HealthMetricType type) {
    switch (type) {
      case HealthMetricType.heartRate:
        return const Color(0xFFEF4444);
      case HealthMetricType.bloodPressure:
        return const Color(0xFFF97316);
      case HealthMetricType.bloodGlucose:
        return const Color(0xFF8B5CF6);
      case HealthMetricType.spo2:
        return const Color(0xFF3B82F6);
      case HealthMetricType.bodyTemperature:
        return const Color(0xFFF59E0B);
      case HealthMetricType.steps:
        return const Color(0xFF10B981);
      case HealthMetricType.weight:
        return const Color(0xFF6366F1);
      case HealthMetricType.height:
        return const Color(0xFF14B8A6);
    }
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: cardColor,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      fontFamily: 'SF Pro Display',
    );
  }
}
