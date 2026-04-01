import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/health_provider.dart';
import '../../models/health_advice.dart';
import '../../utils/app_theme.dart';

class AIAdviceScreen extends StatefulWidget {
  const AIAdviceScreen({super.key});

  @override
  State<AIAdviceScreen> createState() => _AIAdviceScreenState();
}

class _AIAdviceScreenState extends State<AIAdviceScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;
  bool _isAdviceExpanded = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HealthProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF1F5F9),
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // --- Gradient Header ---
              SliverAppBar(
                centerTitle: true,
                expandedHeight: 180,
                floating: false,
                pinned: true,
                backgroundColor: AppTheme.primaryDark,
                flexibleSpace: FlexibleSpaceBar(
                  centerTitle: true,
                  titlePadding: const EdgeInsets.only(bottom: 16),
                  title: const Text(
                    'AI Tư vấn sức khỏe',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF1E3A8A),
                          Color(0xFF3B82F6),
                          Color(0xFF7C3AED),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // Decorative circles
                        Positioned(
                          top: -30,
                          right: -30,
                          child: Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 10,
                          left: -40,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.04),
                            ),
                          ),
                        ),
                        // Center AI icon
                        Center(
                          child: AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withValues(alpha: 0.12),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.psychology_rounded,
                                    size: 44,
                                    color: Colors.white70,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // --- Content ---
              SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // AI Analysis Action
                        _buildAnalysisCard(provider),

                        const SizedBox(height: 24),

                        // --- Advice Result ---
                        if (provider.latestAdvice != null) ...[
                          _buildSectionHeader(
                            icon: Icons.assignment_rounded,
                            title: 'Kết quả phân tích',
                            subtitle:
                                'Cập nhật: ${_formatDateTime(provider.latestAdvice!.createdAt)}',
                          ),
                          const SizedBox(height: 12),
                          _buildAdviceCard(provider.latestAdvice!),
                        ] else ...[
                          _buildEmptyAdviceCard(),
                        ],

                        const SizedBox(height: 28),

                        // --- Health Tips ---
                        _buildSectionHeader(
                          icon: Icons.tips_and_updates_rounded,
                          title: 'Mẹo sức khỏe hàng ngày',
                          subtitle: 'Thói quen tốt cho cơ thể',
                        ),
                        const SizedBox(height: 12),
                        ..._buildHealthTips(),

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Section Header ─────────────────────────────────────────
  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primaryColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textLight,
                    height: 1.5,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Analysis Card (CTA) ────────────────────────────────────
  Widget _buildAnalysisCard(HealthProvider provider) {
    final hasData = provider.healthData.values.any((l) => l.isNotEmpty);
    final isAnalyzing = provider.isAnalyzing;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF6D28D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background pattern
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              Icons.auto_awesome,
              size: 120,
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          Positioned(
            left: -15,
            bottom: -15,
            child: Icon(
              Icons.health_and_safety_rounded,
              size: 80,
              color: Colors.white.withValues(alpha: 0.04),
            ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Status row
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Phân tích toàn diện',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'AI phân tích chỉ số & đưa lời khuyên',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Data status chips
                if (hasData)
                  _buildDataStatusRow(provider)
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.white54,
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Cần có dữ liệu sức khỏe để phân tích',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 18),

                // Analyze button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isAnalyzing || !hasData
                        ? null
                        : () => provider.getAIAdvice(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1E3A8A),
                      disabledBackgroundColor: Colors.white.withValues(
                        alpha: 0.3,
                      ),
                      disabledForegroundColor: Colors.white.withValues(
                        alpha: 0.5,
                      ),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: isAnalyzing
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: const Color(
                                    0xFF1E3A8A,
                                  ).withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'AI đang phân tích...',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_arrow_rounded, size: 22),
                              SizedBox(width: 8),
                              Text(
                                'Bắt đầu phân tích',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Data Status Row ────────────────────────────────────────
  Widget _buildDataStatusRow(HealthProvider provider) {
    final metricsWithData = provider.healthData.entries
        .where((e) => e.value.isNotEmpty)
        .toList();
    final count = metricsWithData.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF34D399),
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            '$count chỉ số sẵn sàng phân tích',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF34D399).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Sẵn sàng',
              style: TextStyle(
                color: const Color(0xFF34D399),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Advice Result Card ─────────────────────────────────────
  Widget _buildAdviceCard(HealthAdvice advice) {
    final levelConfig = _getLevelConfig(advice.level);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Level indicator header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: levelConfig.bgColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: levelConfig.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    levelConfig.icon,
                    color: levelConfig.color,
                    size: 22,
                  ),
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
                          fontWeight: FontWeight.w700,
                          color: levelConfig.color,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDateTime(advice.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: levelConfig.color.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                // Level badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: levelConfig.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: levelConfig.color.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    advice.level.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: levelConfig.color,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Metrics chips
          if (advice.metrics.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: advice.metrics.map((m) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: levelConfig.color.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: levelConfig.color.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle, size: 6, color: levelConfig.color),
                        const SizedBox(width: 6),
                        Text(
                          m,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: levelConfig.color,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          // Content body
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: GestureDetector(
              onTap: () =>
                  setState(() => _isAdviceExpanded = !_isAdviceExpanded),
              child: Row(
                children: [
                  Icon(
                    Icons.article_rounded,
                    size: 16,
                    color: AppTheme.textLight,
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Nội dung phân tích',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _isAdviceExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.textLight,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          AnimatedCrossFade(
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: _buildRichContent(advice.content),
            ),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Text(
                _getPreviewText(advice.content),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.6,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            crossFadeState: _isAdviceExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  // ── Rich Content Parser ────────────────────────────────────
  Widget _buildRichContent(String content) {
    final lines = content.split('\n');
    final widgets = <Widget>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 6));
        continue;
      }

      // Section headers (bold markdown-like **header**)
      if (line.startsWith('**') && line.endsWith('**')) {
        final headerText = line.replaceAll('**', '');
        if (widgets.isNotEmpty) widgets.add(const SizedBox(height: 14));
        widgets.add(_buildContentSectionHeader(headerText));
        widgets.add(const SizedBox(height: 6));
        continue;
      }

      // Numbered lines (e.g. "1. **Title**: content")
      final numberedMatch = RegExp(r'^(\d+)\.\s*(.*)$').firstMatch(line);
      if (numberedMatch != null) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.only(right: 10, top: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text(
                      numberedMatch.group(1)!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _buildInlineStyledText(numberedMatch.group(2)!),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // Bullet points
      if (line.startsWith('- ') || line.startsWith('• ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 3, bottom: 1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.only(right: 10, top: 7),
                  decoration: const BoxDecoration(
                    color: AppTheme.textLight,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(child: _buildInlineStyledText(line.substring(2))),
              ],
            ),
          ),
        );
        continue;
      }

      // Normal text
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: _buildInlineStyledText(line),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildContentSectionHeader(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: AppTheme.primaryColor.withValues(alpha: 0.6),
            width: 3,
          ),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  /// Parse inline bold (**text**) within a line
  Widget _buildInlineStyledText(String text) {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'\*\*(.*?)\*\*');
    int lastEnd = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 13.5,
          height: 1.65,
          color: AppTheme.textPrimary,
        ),
        children: spans.isEmpty ? [TextSpan(text: text)] : spans,
      ),
    );
  }

  String _getPreviewText(String content) {
    return content
        .replaceAll(RegExp(r'\*\*'), '')
        .replaceAll(RegExp(r'\n{2,}'), '\n');
  }

  // ── Level Config ───────────────────────────────────────────
  _LevelConfig _getLevelConfig(AdviceLevel level) {
    switch (level) {
      case AdviceLevel.urgent:
        return _LevelConfig(
          color: const Color(0xFFDC2626),
          bgColor: const Color(0xFFFEF2F2),
          icon: Icons.warning_rounded,
        );
      case AdviceLevel.warning:
        return _LevelConfig(
          color: const Color(0xFFD97706),
          bgColor: const Color(0xFFFFFBEB),
          icon: Icons.error_rounded,
        );
      case AdviceLevel.suggestion:
        return _LevelConfig(
          color: const Color(0xFF059669),
          bgColor: const Color(0xFFF0FDF4),
          icon: Icons.lightbulb_rounded,
        );
      case AdviceLevel.info:
        return _LevelConfig(
          color: const Color(0xFF2563EB),
          bgColor: const Color(0xFFEFF6FF),
          icon: Icons.check_circle_rounded,
        );
    }
  }

  // ── Empty Advice Card ──────────────────────────────────────
  Widget _buildEmptyAdviceCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.psychology_alt_rounded,
              size: 48,
              color: AppTheme.textLight,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Chưa có phân tích AI',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Nhấn "Bắt đầu phân tích" ở trên để AI\nđưa ra lời khuyên dựa trên dữ liệu của bạn.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: AppTheme.textLight,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Health Tips ────────────────────────────────────────────
  List<Widget> _buildHealthTips() {
    final tips = [
      _TipData(
        Icons.water_drop_rounded,
        'Uống đủ nước',
        'Uống 2-3 lít nước mỗi ngày để duy trì sức khỏe.',
        Color(0xFF0EA5E9),
      ),
      _TipData(
        Icons.bedtime_rounded,
        'Ngủ đủ giấc',
        'Ngủ 7-8 tiếng mỗi đêm giúp cơ thể phục hồi.',
        Color(0xFF8B5CF6),
      ),
      _TipData(
        Icons.directions_walk_rounded,
        'Vận động thường xuyên',
        'Đi bộ ít nhất 30 phút mỗi ngày.',
        Color(0xFF10B981),
      ),
      _TipData(
        Icons.restaurant_rounded,
        'Ăn uống cân bằng',
        'Bổ sung đầy đủ rau xanh, protein và trái cây.',
        Color(0xFFF59E0B),
      ),
      _TipData(
        Icons.self_improvement_rounded,
        'Giảm stress',
        'Thiền định, yoga hoặc hít thở sâu mỗi ngày.',
        Color(0xFFEC4899),
      ),
    ];

    return tips.asMap().entries.map((entry) {
      final i = entry.key;
      final tip = entry.value;
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: Duration(milliseconds: 400 + i * 100),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Opacity(
            opacity: value,
            child: Transform.translate(
              offset: Offset(0, 20 * (1 - value)),
              child: child,
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: tip.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(tip.icon, color: tip.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tip.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tip.description,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textLight,
                size: 20,
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  String _formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$day/$month/${dt.year} $hour:$minute';
  }
}

// ── Helper Classes ─────────────────────────────────────────────
class _LevelConfig {
  final Color color;
  final Color bgColor;
  final IconData icon;

  const _LevelConfig({
    required this.color,
    required this.bgColor,
    required this.icon,
  });
}

class _TipData {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _TipData(this.icon, this.title, this.description, this.color);
}
