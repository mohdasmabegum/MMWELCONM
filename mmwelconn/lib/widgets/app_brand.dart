import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

class VibeTheme {
  final bool isDark;
  final List<Color> backgroundGradient;
  final List<Color> blobColors;
  final Color textColor;
  final Color subtitleColor;
  final Color cardColor;
  final Color borderColor;
  final Color primaryColor;
  final Color accentColor;

  const VibeTheme({
    required this.isDark,
    required this.backgroundGradient,
    required this.blobColors,
    required this.textColor,
    required this.subtitleColor,
    required this.cardColor,
    required this.borderColor,
    required this.primaryColor,
    required this.accentColor,
  });

  static VibeTheme get(String ageGroup, String customTheme) {
    if (ageGroup == 'teen') {
      if (customTheme == 'cyberpunk') {
        return const VibeTheme(
          isDark: true,
          backgroundGradient: [Color(0xFF0A0A0E), Color(0xFF14141F), Color(0xFF0A0A0E)],
          blobColors: [Color(0x33FCEE09), Color(0x3300FF66), Color(0x33E60067), Color(0x1100F0FF)],
          textColor: Colors.white,
          subtitleColor: Colors.white70,
          cardColor: Color(0x331E1E2E),
          borderColor: Color(0x55FCEE09),
          primaryColor: Color(0xFFFCEE09),
          accentColor: Color(0xFF00FF66),
        );
      } else if (customTheme == 'pastel') {
        return const VibeTheme(
          isDark: false,
          backgroundGradient: [Color(0xFFFFF4F8), Color(0xFFF3EFFF), Color(0xFFE8F5FF)],
          blobColors: [Color(0x44FFB6C1), Color(0x44B0E0E6), Color(0x44E6E6FA), Color(0x22FFF0F5)],
          textColor: Color(0xFF191B2C),
          subtitleColor: Colors.black54,
          cardColor: Color(0xBCFFFFFF),
          borderColor: Color(0x44FF6F91),
          primaryColor: Color(0xFFFF6F91),
          accentColor: Color(0xFF9B6DFF),
        );
      } else {
        // 'neon' or default
        return const VibeTheme(
          isDark: true,
          backgroundGradient: [Color(0xFF0C0A1A), Color(0xFF160D2D), Color(0xFF0A0714)],
          blobColors: [Color(0x44FF007F), Color(0x4400F0FF), Color(0x448A2BE2), Color(0x22FF8A65)],
          textColor: Colors.white,
          subtitleColor: Colors.white70,
          cardColor: Color(0x3F2B1F4D),
          borderColor: Color(0x559B6DFF),
          primaryColor: Color(0xFF9B6DFF),
          accentColor: Color(0xFFFF6F91),
        );
      }
    } else if (ageGroup == 'kid') {
      if (customTheme == 'forest') {
        return const VibeTheme(
          isDark: false,
          backgroundGradient: [Color(0xFFE8F5E9), Color(0xFFFFF3E0), Color(0xFFE8F5E9)],
          blobColors: [Color(0x4481C784), Color(0x44FFF176), Color(0x44FFB74D), Color(0x22C8E6C9)],
          textColor: Color(0xFF2E7D32),
          subtitleColor: Colors.black54,
          cardColor: Color(0xBCFFFFFF),
          borderColor: Color(0x5581C784),
          primaryColor: Color(0xFF4CAF50),
          accentColor: Color(0xFFFF9800),
        );
      } else {
        // 'bubblegum' or default
        return const VibeTheme(
          isDark: false,
          backgroundGradient: [Color(0xFFFFF0F5), Color(0xFFE6F2FF), Color(0xFFFFF5FD)],
          blobColors: [Color(0x55FFA6C9), Color(0x55B3E5FC), Color(0x55FFE0B2), Color(0x22F8BBD0)],
          textColor: Color(0xFFC2185B),
          subtitleColor: Colors.black54,
          cardColor: Color(0xBCFFFFFF),
          borderColor: Color(0x55FFA6C9),
          primaryColor: Color(0xFFFF4081),
          accentColor: Color(0xFF00E5FF),
        );
      }
    } else if (ageGroup == 'elder') {
      if (customTheme == 'high_contrast_dark') {
        return const VibeTheme(
          isDark: true,
          backgroundGradient: [Color(0xFF000000), Color(0xFF121212), Color(0xFF000000)],
          blobColors: [Color(0x33FCEE09), Color(0x3300F0FF), Color(0x22FFFFFF), Color(0x11FCEE09)],
          textColor: Colors.white,
          subtitleColor: Color(0xFFFCEE09),
          cardColor: Color(0xFF121212),
          borderColor: Color(0xFFFCEE09),
          primaryColor: Color(0xFFFCEE09),
          accentColor: Colors.white,
        );
      } else if (customTheme == 'parchment') {
        return const VibeTheme(
          isDark: false,
          backgroundGradient: [Color(0xFFF5E6D3), Color(0xFFEAD5C3), Color(0xFFF5E6D3)],
          blobColors: [Color(0x44BCAAA4), Color(0x44B0BEC5), Color(0x33D7CCC8), Color(0x22EAD5C3)],
          textColor: Color(0xFF3E2723),
          subtitleColor: Colors.black87,
          cardColor: Color(0xBCFFFFFF),
          borderColor: Color(0x55BCAAA4),
          primaryColor: Color(0xFF8D6E63),
          accentColor: Color(0xFF78909C),
        );
      } else {
        // 'cream' or default
        return const VibeTheme(
          isDark: false,
          backgroundGradient: [Color(0xFFFCF8F2), Color(0xFFF9F3EB), Color(0xFFFCF8F2)],
          blobColors: [Color(0x44D7CCC8), Color(0x44FFE0B2), Color(0x44CFD8DC), Color(0x22F5F5F5)],
          textColor: Color(0xFF263238),
          subtitleColor: Colors.black54,
          cardColor: Color(0xBCFFFFFF),
          borderColor: Color(0x55D7CCC8),
          primaryColor: Color(0xFF795548),
          accentColor: Color(0xFF607D8B),
        );
      }
    } else {
      // adult
      if (customTheme == 'navy_sage') {
        return const VibeTheme(
          isDark: true,
          backgroundGradient: [Color(0xFF080D1D), Color(0xFF0F1B35), Color(0xFF080D1D)],
          blobColors: [Color(0x338E9B90), Color(0x333D5A80), Color(0x33293241), Color(0x118E9B90)],
          textColor: Colors.white,
          subtitleColor: Colors.white70,
          cardColor: Color(0x331C2541),
          borderColor: Color(0x448E9B90),
          primaryColor: Color(0xFF8E9B90),
          accentColor: Color(0xFF3D5A80),
        );
      } else if (customTheme == 'warm_onyx') {
        return const VibeTheme(
          isDark: true,
          backgroundGradient: [Color(0xFF121212), Color(0xFF1F1F1F), Color(0xFF121212)],
          blobColors: [Color(0x33D4AF37), Color(0x338B5A2B), Color(0x33FFBF00), Color(0x11D4AF37)],
          textColor: Colors.white,
          subtitleColor: Colors.white70,
          cardColor: Color(0x332A2A2A),
          borderColor: Color(0x44D4AF37),
          primaryColor: Color(0xFFD4AF37),
          accentColor: Color(0xFFFFBF00),
        );
      } else {
        // 'slate' or default
        return const VibeTheme(
          isDark: false,
          backgroundGradient: [Color(0xFFF2F5FA), Color(0xFFE6ECF4), Color(0xFFEEF2F7)],
          blobColors: [Color(0x334A6984), Color(0x338F94A8), Color(0x335C7E9C), Color(0x114A6984)],
          textColor: Color(0xFF191B2C),
          subtitleColor: Colors.black54,
          cardColor: Color(0xBCFFFFFF),
          borderColor: Color(0x444A6984),
          primaryColor: Color(0xFF4A6984),
          accentColor: Color(0xFF8F94A8),
        );
      }
    }
  }
}

class AppTheme {
  static const Color ink = Color(0xFF191B2C);
  static const Color midnight = Color(0xFF101426);
  static const Color violet = Color(0xFF9B6DFF);
  static const Color pink = Color(0xFFFF6F91);
  static const Color coral = Color(0xFFFF8A65);
  static const Color sky = Color(0xFF57A8FF);

  static final ValueNotifier<VibeTheme> vibeThemeNotifier = ValueNotifier<VibeTheme>(
    VibeTheme.get('teen', 'neon'),
  );

  static final ValueNotifier<double> fontSizeFactor = ValueNotifier<double>(1.0);
  static final ValueNotifier<bool> highContrast = ValueNotifier<bool>(false);

  static VibeTheme get vibe => vibeThemeNotifier.value;

  static void updateVibe(String ageGroup, String customTheme, {bool forceHighContrast = false}) {
    final theme = (forceHighContrast && ageGroup == 'elder') ? 'high_contrast_dark' : customTheme;
    vibeThemeNotifier.value = VibeTheme.get(ageGroup, theme);
  }
}

class SoftGlowBackground extends StatelessWidget {
  final Widget child;

  const SoftGlowBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VibeTheme>(
      valueListenable: AppTheme.vibeThemeNotifier,
      builder: (context, vibe, _) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: vibe.backgroundGradient,
            ),
          ),
          child: Stack(
            children: [
              _GlowBlob(
                alignment: const Alignment(-0.95, -0.92),
                size: 240,
                colors: [vibe.blobColors[0], vibe.blobColors[0].withValues(alpha: 0)],
              ),
              _GlowBlob(
                alignment: const Alignment(0.95, -0.85),
                size: 300,
                colors: [vibe.blobColors[1], vibe.blobColors[1].withValues(alpha: 0)],
              ),
              _GlowBlob(
                alignment: const Alignment(-0.8, 0.95),
                size: 260,
                colors: [vibe.blobColors[2], vibe.blobColors[2].withValues(alpha: 0)],
              ),
              _GlowBlob(
                alignment: const Alignment(0.95, 0.9),
                size: 220,
                colors: [vibe.blobColors[3], vibe.blobColors[3].withValues(alpha: 0)],
              ),
              Container(color: vibe.isDark ? Colors.black.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.18)),
              child,
            ],
          ),
        );
      },
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final Alignment alignment;
  final double size;
  final List<Color> colors;

  const _GlowBlob({
    required this.alignment,
    required this.size,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors),
        ),
      ),
    );
  }
}

class _WavyCirclePainter extends CustomPainter {
  final double animationValue;
  final Color color;

  _WavyCirclePainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final center = Offset(size.width / 2, size.height / 2);
    // Outer wave radius slightly larger than avatar border
    final baseRadius = (size.width / 2) + 6;

    final path = Path();
    const int pointsCount = 180;
    for (int i = 0; i <= pointsCount; i++) {
      final double angle = (i * 2 * math.pi) / pointsCount;
      // Beautiful wavy modulation with 8 peaks rotating with animation
      final double wave = math.sin(angle * 8 + animationValue * 2 * math.pi) * 4;
      final double r = baseRadius + wave;
      final double x = center.dx + r * math.cos(angle);
      final double y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavyCirclePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.color != color;
  }
}

class _PulseGlowPainter extends CustomPainter {
  final double animationValue;
  final Color color;

  _PulseGlowPainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double pulse = 1.0 + (math.sin(animationValue * 2 * math.pi) * 0.05);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.8 * (1.0 - (math.sin(animationValue * 2 * math.pi).abs() * 0.35)))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0 + (math.sin(animationValue * 2 * math.pi).abs() * 2.0);

    final center = Offset(size.width / 2, size.height / 2);
    final radius = ((size.width / 2) + 6) * pulse;

    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _PulseGlowPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.color != color;
  }
}

class _OrbitingDotsPainter extends CustomPainter {
  final double animationValue;
  final Color color;

  _OrbitingDotsPainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) + 6;

    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius, trackPaint);

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Dot 1 clockwise
    final angle1 = animationValue * 2 * math.pi;
    final x1 = center.dx + radius * math.cos(angle1);
    final y1 = center.dy + radius * math.sin(angle1);
    canvas.drawCircle(Offset(x1, y1), 4.5, dotPaint);

    // Dot 2 counter-clockwise
    final angle2 = -angle1;
    final x2 = center.dx + radius * math.cos(angle2);
    final y2 = center.dy + radius * math.sin(angle2);
    canvas.drawCircle(Offset(x2, y2), 4.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _OrbitingDotsPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.color != color;
  }
}

class _SpokeRingPainter extends CustomPainter {
  final double animationValue;
  final Color color;

  _SpokeRingPainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) + 6;

    const int spokesCount = 12;
    final rotationAngle = animationValue * 2 * math.pi;

    for (int i = 0; i < spokesCount; i++) {
      final double angle = ((i * 2 * math.pi) / spokesCount) + rotationAngle;
      final double startR = radius - 3.0;
      final double endR = radius + 3.0;

      final x1 = center.dx + startR * math.cos(angle);
      final y1 = center.dy + startR * math.sin(angle);
      final x2 = center.dx + endR * math.cos(angle);
      final y2 = center.dy + endR * math.sin(angle);

      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpokeRingPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.color != color;
  }
}

class _ConcentricRipplesPainter extends CustomPainter {
  final double animationValue;
  final Color color;

  _ConcentricRipplesPainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = (size.width / 2) + 2;

    const int rippleCount = 3;
    for (int i = 0; i < rippleCount; i++) {
      final double offset = i / rippleCount;
      final double progress = (animationValue + offset) % 1.0;
      final double radius = baseRadius + (progress * 16.0);
      final double opacity = (1.0 - progress).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = color.withValues(alpha: opacity * 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConcentricRipplesPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.color != color;
  }
}

class _SpiralVortexPainter extends CustomPainter {
  final double animationValue;
  final Color color;

  _SpiralVortexPainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = (size.width / 2) + 2;

    const int spiralCount = 3;
    final rotation = animationValue * 2 * math.pi;

    for (int i = 0; i < spiralCount; i++) {
      final double baseAngle = (i * 2 * math.pi) / spiralCount + rotation;
      final path = Path();

      for (int step = 0; step <= 60; step++) {
        final double angle = baseAngle + (step * math.pi / 90.0);
        final double r = baseRadius + (step * 0.25);
        final double x = center.dx + r * math.cos(angle);
        final double y = center.dy + r * math.sin(angle);

        if (step == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpiralVortexPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue || oldDelegate.color != color;
  }
}

class BrandLogo extends StatefulWidget {
  final double size;
  final bool circular;

  const BrandLogo({super.key, this.size = 260, this.circular = true});

  @override
  State<BrandLogo> createState() => _BrandLogoState();
}

class _BrandLogoState extends State<BrandLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _currentIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    _currentIndex = (DateTime.now().minute ~/ 3) % 6;

    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      final newIdx = (DateTime.now().minute ~/ 3) % 6;
      if (newIdx != _currentIndex) {
        if (mounted) {
          setState(() {
            _currentIndex = newIdx;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  CustomPainter? _getPainter(double animationValue) {
    if (!widget.circular) return null;
    switch (_currentIndex) {
      case 0:
        return _WavyCirclePainter(animationValue: animationValue, color: AppTheme.violet);
      case 1:
        return _PulseGlowPainter(animationValue: animationValue, color: AppTheme.violet);
      case 2:
        return _OrbitingDotsPainter(animationValue: animationValue, color: AppTheme.violet);
      case 3:
        return _SpokeRingPainter(animationValue: animationValue, color: AppTheme.violet);
      case 4:
        return _ConcentricRipplesPainter(animationValue: animationValue, color: AppTheme.violet);
      case 5:
        return _SpiralVortexPainter(animationValue: animationValue, color: AppTheme.violet);
      default:
        return _WavyCirclePainter(animationValue: animationValue, color: AppTheme.violet);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double size = widget.size;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double lift = math.sin(_controller.value * math.pi * 2) * 8;
        final double scale = 0.9 + (_controller.value * 0.1);
        return Transform.translate(
          offset: Offset(0, lift),
          child: Transform.scale(
            scale: scale,
            child: CustomPaint(
              painter: _getPainter(_controller.value),
              child: child,
            ),
          ),
        );
      },
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        // Remove inner padding and gradient to let the logo occupy the full circle
        decoration: BoxDecoration(
          shape: widget.circular ? BoxShape.circle : BoxShape.rectangle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 22,
              offset: const Offset(0, 14),
            ),
            BoxShadow(
              color: AppTheme.violet.withValues(alpha: 0.12),
              blurRadius: 26,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/logo.png',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

class HoverCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;

  const HoverCard({super.key, required this.child, this.margin = EdgeInsets.zero});

  @override
  State<HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<HoverCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        margin: widget.margin,
        transform: Matrix4.identity()
          ..translate(0.0, _hovering ? -8.0 : 0.0)
          ..scale(_hovering ? 1.012 : 1.0),
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _hovering ? 0.12 : 0.06),
              blurRadius: _hovering ? 28 : 18,
              offset: Offset(0, _hovering ? 18 : 10),
            ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}

class HoverActionButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final IconData icon;
  final List<Color> colors;
  final bool outlined;

  const HoverActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.icon,
    required this.colors,
    this.outlined = false,
  });

  @override
  State<HoverActionButton> createState() => _HoverActionButtonState();
}

class _HoverActionButtonState extends State<HoverActionButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final bool dark = widget.outlined;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          transform: Matrix4.identity()
            ..translate(0.0, _hovering ? -5.0 : 0.0)
            ..scale(_hovering ? 1.02 : 1.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: dark
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.colors,
                  ),
            color: dark ? Colors.white.withValues(alpha: 0.58) : null,
            border: dark ? Border.all(color: widget.colors.first.withValues(alpha: 0.28)) : null,
            boxShadow: [
              BoxShadow(
                color: widget.colors.first.withValues(alpha: _hovering ? 0.34 : 0.18),
                blurRadius: _hovering ? 24 : 16,
                offset: Offset(0, _hovering ? 14 : 10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: dark ? widget.colors.first : Colors.white),
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: TextStyle(
                  color: dark ? AppTheme.ink : Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType keyboardType;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;

  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.onSubmitted,
    this.textInputAction,
    this.autofillHints,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onSubmitted: onSubmitted,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.88),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const FeaturePill({super.key, required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: AppTheme.ink.withValues(alpha: 0.82),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

PageRoute<T> buildPageRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, animation, secondaryAnimation) => page,
    transitionsBuilder: (_, animation, secondaryAnimation, child) {
      final slide = Tween<Offset>(begin: const Offset(0.06, 0.08), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeOutCubic))
          .animate(animation);
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(position: slide, child: child),
      );
    },
  );
}
