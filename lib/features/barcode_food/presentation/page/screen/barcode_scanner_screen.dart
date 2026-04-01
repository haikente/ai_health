import 'package:ai_health/features/barcode_food/domain/repositories/food_barcode_repository.dart';
import 'package:ai_health/features/barcode_food/presentation/bloc/bloc/barcode_bloc.dart';
import 'package:ai_health/features/barcode_food/presentation/bloc/bloc/barcode_event.dart';
import 'package:ai_health/features/barcode_food/presentation/bloc/bloc/barcode_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:ai_health/features/barcode_food/domain/entities/barcode_food.dart';
import 'package:ai_health/features/barcode_food/domain/failures/barcode_failure.dart';

class BarcodeScannerScreen extends StatefulWidget {
  final FoodBarcodeRepository repository;

  const BarcodeScannerScreen({
    super.key,
    required this.repository,
  });

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with WidgetsBindingObserver {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _controller.stop();
    }
    if (state == AppLifecycleState.resumed) {
      _controller.start();
    }
  }

  Future<void> _openSheet(BuildContext context, Widget child) async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    _controller.stop();

    // Capture bloc trước async gap tránh dùng context đã deactivated
    final bloc = context.read<BarcodeScanBloc>();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => child,
    );

    _sheetOpen = false;
    if (mounted) {
      bloc.add(ResetScannerEvent());
      _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocProvider(
      create: (_) => BarcodeScanBloc(widget.repository),
      child: BlocConsumer<BarcodeScanBloc, BarcodeScanState>(
        listener: (context, state) {
          if (state is BarcodeScanSuccess) {
            _openSheet(context, ProductDetailSheet(food: state.food));
          }
          if (state is BarcodeScanFailure) {
            _openSheet(context, BarcodeNotFoundSheet(failure: state.failure));
          }
        },
        builder: (context, state) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Stack(
              children: [
                // Camera
                Positioned.fill(
                  child: MobileScanner(
                    controller: _controller,
                    errorBuilder: (context, error) {
                      return _CameraErrorView(message: error.errorDetails?.message);
                    },
                    onDetect: (capture) {
                      final barcode = capture.barcodes.firstOrNull?.rawValue;
                      if (barcode != null && barcode.trim().isNotEmpty) {
                        context
                            .read<BarcodeScanBloc>()
                            .add(BarcodeDetectedEvent(barcode.trim()));
                      }
                    },
                  ),
                ),

                // Overlay
                const _ScannerOverlay(),

                // Top bar
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        _RoundIconButton(
                          icon: Icons.arrow_back,
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Quét mã vạch',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ValueListenableBuilder(
                          valueListenable: _controller,
                          builder: (_, state, _) {
                            final torchOn =
                                state.torchState == TorchState.on;
                            return _RoundIconButton(
                              icon: torchOn
                                  ? Icons.flash_on
                                  : Icons.flash_off,
                              onTap: () => _controller.toggleTorch(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Status pill
                Positioned(
                  bottom: 24,
                  left: 16,
                  right: 16,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ScanStatusPill(state: state),
                      const SizedBox(height: 10),
                      Text(
                        'Đưa mã vạch vào khung ngắm',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),

                if (state is BarcodeScanLoading)
                  const Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: Color(0x22000000),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}

class _ScanStatusPill extends StatelessWidget {
  final BarcodeScanState state;

  const _ScanStatusPill({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (icon, title, subtitle) = switch (state) {
      BarcodeScanLoading(:final barcode) => (
          Icons.qr_code_scanner,
          'Đang tra cứu mã vạch…',
          barcode,
        ),
      BarcodeScanFailure() => (
          Icons.error_outline,
          'Không tìm thấy',
          'Thử mã khác hoặc kiểm tra Internet',
        ),
      BarcodeScanSuccess(:final food) => (
          Icons.check_circle_outline,
          'Đã tìm thấy',
          food.name,
        ),
      _ => (
          Icons.center_focus_strong,
          'Sẵn sàng quét',
          'Giữ máy ổn định trong 1–2 giây',
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.80),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CameraErrorView extends StatelessWidget {
  final String? message;

  const _CameraErrorView({this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off, color: Colors.white, size: 44),
            const SizedBox(height: 12),
            Text(
              'Không thể mở camera',
              style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              message ?? 'Vui lòng cấp quyền camera trong Cài đặt và thử lại.',
              textAlign: TextAlign.center,
              style:
                  theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final scanSize = (size.shortestSide * 0.72).clamp(240.0, 340.0);

    return IgnorePointer(
      child: Stack(
        children: [
          // Dim
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.52)),
          ),

          // Cutout + border
          Center(
            child: Container(
              width: scanSize,
              height: scanSize,
              decoration: ShapeDecoration(
                color: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.85),
                    width: 2,
                  ),
                ),
              ),
              child: Stack(
                children: [
                  // subtle gradient
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.06),
                            Colors.transparent,
                            Colors.transparent,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                  ),

                  // Corner accents
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _CornerPainter(
                        color: Colors.white.withValues(alpha: 0.95),
                      ),
                    ),
                  ),

                  // Scan line
                  Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _ScanLine(width: scanSize - 36),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanLine extends StatefulWidget {
  final double width;
  const _ScanLine({required this.width});

  @override
  State<_ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<_ScanLine> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Opacity(
          opacity: 0.9,
          child: Transform.translate(
            offset: Offset(0, _c.value * 190),
            child: Container(
              width: widget.width,
              height: 2,
              decoration: BoxDecoration(
                color: const Color(0xFF4CC9F0),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4CC9F0).withValues(alpha: 0.55),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;

  const _CornerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const corner = 26.0;
    const padding = 10.0;

    // top-left
    canvas.drawPath(
      Path()
        ..moveTo(padding, padding + corner)
        ..lineTo(padding, padding)
        ..lineTo(padding + corner, padding),
      paint,
    );

    // top-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - padding - corner, padding)
        ..lineTo(size.width - padding, padding)
        ..lineTo(size.width - padding, padding + corner),
      paint,
    );

    // bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(padding, size.height - padding - corner)
        ..lineTo(padding, size.height - padding)
        ..lineTo(padding + corner, size.height - padding),
      paint,
    );

    // bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - padding - corner, size.height - padding)
        ..lineTo(size.width - padding, size.height - padding)
        ..lineTo(size.width - padding, size.height - padding - corner),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _CornerPainter oldDelegate) =>
      oldDelegate.color != color;
}

class ProductDetailSheet extends StatelessWidget {
  final BarcodeFood food;

  const ProductDetailSheet({
    super.key,
    required this.food,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return _SheetSurface(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SheetGrabber(),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _FoodThumb(url: food.imageUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        food.name,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (food.brand != null) ...[
                        const SizedBox(height: 2),
                        Text(food.brand!, style: theme.textTheme.bodyMedium),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _Chip(icon: Icons.local_fire_department, text: '${food.calories.toStringAsFixed(0)} kcal'),
                          _Chip(icon: Icons.fitness_center, text: 'P ${food.protein.toStringAsFixed(1)}g'),
                          _Chip(icon: Icons.bakery_dining, text: 'C ${food.carbs.toStringAsFixed(1)}g'),
                          _Chip(icon: Icons.opacity, text: 'F ${food.fat.toStringAsFixed(1)}g'),
                          if (food.fiber != null) _Chip(icon: Icons.grass, text: 'Fiber ${food.fiber!.toStringAsFixed(1)}g'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _KeyValue(label: 'Mã vạch', value: food.barcode),
            _KeyValue(label: 'Khẩu phần', value: food.servingSize),
            _KeyValue(label: 'Nguồn', value: food.source),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Xong'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BarcodeNotFoundSheet extends StatelessWidget {
  final BarcodeFailure failure;

  const BarcodeNotFoundSheet({
    super.key,
    required this.failure,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (icon, title, message) = switch (failure) {
      ProductNotFoundFailure() => (
          Icons.search_off,
          'Không tìm thấy sản phẩm',
          'Mã vạch này chưa có trong dữ liệu. Thử mã khác hoặc nhập tay.',
        ),
      NetworkFailure() => (
          Icons.wifi_off,
          'Lỗi mạng',
          'Không có kết nối Internet. Vui lòng thử lại.',
        ),
      _ => (
          Icons.error_outline,
          'Có lỗi xảy ra',
          'Vui lòng thử lại sau.',
        ),
    };

    return _SheetSurface(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SheetGrabber(),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: theme.colorScheme.onErrorContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(message, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Thử lại'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetSurface extends StatelessWidget {
  final Widget child;

  const _SheetSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
         ),
        child: child,
      ),
    );
  }
}

class _SheetGrabber extends StatelessWidget {
  const _SheetGrabber();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Container(
        width: 44,
        height: 4,
        decoration: BoxDecoration(
          color: theme.colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _FoodThumb extends StatelessWidget {
  final String? url;

  const _FoodThumb({this.url});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 84,
        height: 84,
        color: theme.colorScheme.surfaceContainerHighest,
        child: (url == null || url!.trim().isEmpty)
            ? Icon(Icons.fastfood, color: theme.colorScheme.onSurfaceVariant)
            : Image.network(
                url!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  Icons.fastfood,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Chip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  final String label;
  final String value;

  const _KeyValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

