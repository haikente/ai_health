import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/health_data_point.dart';
import '../../providers/health_provider.dart';
import '../../utils/app_theme.dart';

class ManualInputScreen extends StatefulWidget {
  const ManualInputScreen({super.key});

  @override
  State<ManualInputScreen> createState() => _ManualInputScreenState();
}

class _ManualInputScreenState extends State<ManualInputScreen> {
  HealthMetricType _selectedType = HealthMetricType.heartRate;
  final _valueController = TextEditingController();
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();

  @override
  void dispose() {
    _valueController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Nhập dữ liệu thủ công',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Chọn loại chỉ số',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // Metric type selector
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                HealthMetricType.heartRate,
                HealthMetricType.bloodPressure,
                HealthMetricType.bloodGlucose,
                HealthMetricType.spo2,
                HealthMetricType.bodyTemperature,
              ].map((type) {
                final isSelected = _selectedType == type;
                final color = AppTheme.getMetricColor(type);
                return ChoiceChip(
                  label: Text('${type.icon} ${type.displayName}'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedType = type);
                      _valueController.clear();
                      _systolicController.clear();
                      _diastolicController.clear();
                    }
                  },
                  selectedColor: color.withValues(alpha: 0.2),
                  labelStyle: TextStyle(
                    color: isSelected ? color : AppTheme.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Value input
            if (_selectedType == HealthMetricType.bloodPressure) ...[
              _buildInputField(
                controller: _systolicController,
                label: 'Huyết áp tâm thu (Systolic)',
                hint: 'VD: 120',
                unit: 'mmHg',
              ),
              const SizedBox(height: 12),
              _buildInputField(
                controller: _diastolicController,
                label: 'Huyết áp tâm trương (Diastolic)',
                hint: 'VD: 80',
                unit: 'mmHg',
              ),
            ] else
              _buildInputField(
                controller: _valueController,
                label: _selectedType.displayName,
                hint: _getHint(),
                unit: _selectedType.unit,
              ),

            const SizedBox(height: 24),

            // Normal range info
            _buildNormalRangeInfo(),

            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveData,
                icon: const Icon(Icons.save),
                label: const Text(
                  'Lưu dữ liệu',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required String unit,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixText: unit,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      style: const TextStyle(fontSize: 18),
    );
  }

  Widget _buildNormalRangeInfo() {
    String range;
    switch (_selectedType) {
      case HealthMetricType.heartRate:
        range = '60 - 100 bpm';
        break;
      case HealthMetricType.bloodPressure:
        range = '90/60 - 120/80 mmHg';
        break;
      case HealthMetricType.bloodGlucose:
        range = '3.9 - 5.6 mmol/L (lúc đói)';
        break;
      case HealthMetricType.spo2:
        range = '95% - 100%';
        break;
      case HealthMetricType.bodyTemperature:
        range = '36.1°C - 37.2°C';
        break;
      default:
        range = '';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.infoColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.infoColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppTheme.infoColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Khoảng bình thường: $range',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.infoColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getHint() {
    switch (_selectedType) {
      case HealthMetricType.heartRate:
        return 'VD: 72';
      case HealthMetricType.bloodGlucose:
        return 'VD: 5.2';
      case HealthMetricType.spo2:
        return 'VD: 97';
      case HealthMetricType.bodyTemperature:
        return 'VD: 36.6';
      default:
        return '';
    }
  }

  void _saveData() async {
    final now = DateTime.now();
    HealthDataPoint? dataPoint;

    if (_selectedType == HealthMetricType.bloodPressure) {
      final sys = double.tryParse(_systolicController.text);
      final dia = double.tryParse(_diastolicController.text);
      if (sys == null || dia == null) {
        _showError('Vui lòng nhập giá trị hợp lệ');
        return;
      }
      dataPoint = HealthDataPoint(
        type: _selectedType,
        value: sys,
        valueSystolic: sys,
        valueDiastolic: dia,
        unit: _selectedType.unit,
        dateFrom: now,
        dateTo: now,
        source: 'AI Health App',
      );
    } else {
      final value = double.tryParse(_valueController.text);
      if (value == null) {
        _showError('Vui lòng nhập giá trị hợp lệ');
        return;
      }
      dataPoint = HealthDataPoint(
        type: _selectedType,
        value: value,
        unit: _selectedType.unit,
        dateFrom: now,
        dateTo: now,
        source: 'AI Health App',
      );
    }

    // Show loading
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text('Đang lưu vào Health Connect...'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 1),
      ),
    );

    await context.read<HealthProvider>().addManualDataPoint(dataPoint);

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '✅ Đã lưu ${_selectedType.displayName}: ${dataPoint.displayValue}'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.accentColor,
      ),
    );

    _valueController.clear();
    _systolicController.clear();
    _diastolicController.clear();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.dangerColor,
      ),
    );
  }
}
