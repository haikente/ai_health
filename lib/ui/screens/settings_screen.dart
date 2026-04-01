import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/health_provider.dart';
import '../../utils/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HealthProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Cài đặt',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Connection status
              _buildSectionTitle('Kết nối sức khỏe'),
              _buildStatusCard(provider),

              const SizedBox(height: 24),

              // Data management
              _buildSectionTitle('Quản lý dữ liệu'),
              _buildSettingsTile(
                icon: Icons.refresh,
                title: 'Làm mới dữ liệu',
                subtitle: 'Tải lại dữ liệu từ HealthKit/Health Connect',
                onTap: () => provider.fetchHealthData(),
              ),
              _buildSettingsTile(
                icon: Icons.date_range,
                title: 'Khoảng thời gian',
                subtitle: 'Thay đổi khoảng thời gian thu thập dữ liệu',
                onTap: () => _showDateRangePicker(context, provider),
              ),

              const SizedBox(height: 24),

              // AI Settings
              _buildSectionTitle('AI Tư vấn'),
              _buildSettingsTile(
                icon: Icons.key,
                title: 'API Key Gemini',
                subtitle: 'Cấu hình Google Gemini API key',
                onTap: () => _showApiKeyDialog(context),
              ),

              const SizedBox(height: 24),

              // About
              _buildSectionTitle('Thông tin'),
              _buildSettingsTile(
                icon: Icons.info_outline,
                title: 'Về ứng dụng',
                subtitle: 'AI Health v1.0.0',
                onTap: () => _showAboutDialog(context),
              ),
              _buildSettingsTile(
                icon: Icons.security,
                title: 'Quyền riêng tư',
                subtitle: 'Dữ liệu của bạn được bảo mật tuyệt đối',
                onTap: () {},
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildStatusCard(HealthProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildStatusRow(
            'HealthKit / Health Connect',
            provider.isHealthAvailable ? 'Có sẵn' : 'Không khả dụng',
            provider.isHealthAvailable
                ? AppTheme.accentColor
                : AppTheme.dangerColor,
          ),
          const Divider(height: 20),
          _buildStatusRow(
            'Quyền truy cập',
            provider.isAuthorized ? 'Đã cấp quyền' : 'Chưa cấp quyền',
            provider.isAuthorized
                ? AppTheme.accentColor
                : AppTheme.warningColor,
          ),
          const Divider(height: 20),
          _buildStatusRow(
            'Dữ liệu',
            '${_totalDataPoints(provider)} điểm dữ liệu',
            AppTheme.infoColor,
          ),
          if (!provider.isAuthorized) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => provider.requestPermissions(),
                icon: const Icon(Icons.lock_open, size: 18),
                label: const Text('Cấp quyền truy cập'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: AppTheme.textLight),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  int _totalDataPoints(HealthProvider provider) {
    int total = 0;
    provider.healthData.forEach((_, data) => total += data.length);
    return total;
  }

  void _showDateRangePicker(
    BuildContext context,
    HealthProvider provider,
  ) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: provider.dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(seedColor: AppTheme.primaryColor),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      await provider.updateDateRange(picked);
    }
  }

  void _showApiKeyDialog(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cấu hình Gemini API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Nhập Google Gemini API Key để sử dụng tính năng AI tư vấn sức khỏe.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'AIza...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key),
              ),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              // Save API key (implement with SharedPreferences)
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã lưu API Key'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.health_and_safety, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('AI Health'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Phiên bản 1.0.0',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              'Ứng dụng theo dõi sức khỏe thông minh với AI.\n\n'
              '• Kết nối HealthKit (iOS) & Health Connect (Android)\n'
              '• Theo dõi nhịp tim, huyết áp, SpO2, đường huyết, nhiệt độ\n'
              '• AI phân tích và đưa ra lời khuyên sức khỏe\n'
              '• Biểu đồ xu hướng trực quan\n\n'
              '⚠️ Lưu ý: Ứng dụng chỉ cung cấp thông tin tham khảo, '
              'không thay thế cho tư vấn y tế chuyên nghiệp.',
              style: TextStyle(fontSize: 13, height: 1.6),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }
}
