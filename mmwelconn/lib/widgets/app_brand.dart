import 'dart:math' as math;

import 'package:flutter/material.dart';

class AppTheme {
  static const Color ink = Color(0xFF191B2C);
  static const Color midnight = Color(0xFF101426);
  static const Color violet = Color(0xFF9B6DFF);
  static const Color pink = Color(0xFFFF6F91);
  static const Color coral = Color(0xFFFF8A65);
  static const Color sky = Color(0xFF57A8FF);
}

class SoftGlowBackground extends StatelessWidget {
  final Widget child;

  const SoftGlowBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF9FBFF), Color(0xFFF4F0FF), Color(0xFFFFF2F5)],
        ),
      ),
      child: Stack(
        children: [
          const _GlowBlob(
            alignment: Alignment(-0.95, -0.92),
            size: 240,
            colors: [Color(0x3357A8FF), Color(0x0057A8FF)],
          ),
          const _GlowBlob(
            alignment: Alignment(0.95, -0.85),
            size: 300,
            colors: [Color(0x33FF6F91), Color(0x00FF6F91)],
          ),
          const _GlowBlob(
            alignment: Alignment(-0.8, 0.95),
            size: 260,
            colors: [Color(0x229B6DFF), Color(0x009B6DFF)],
          ),
          const _GlowBlob(
            alignment: Alignment(0.95, 0.9),
            size: 220,
            colors: [Color(0x22FF8A65), Color(0x00FF8A65)],
          ),
          Container(color: Colors.white.withValues(alpha: 0.18)),
          child,
        ],
      ),
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

class BrandLogo extends StatefulWidget {
  final double size;

  const BrandLogo({super.key, this.size = 260});

  @override
  State<BrandLogo> createState() => _BrandLogoState();
}

class _BrandLogoState extends State<BrandLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double size = widget.size;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final double lift = math.sin(_controller.value * math.pi * 2) * 8;
        final double scale = 1 + (_controller.value * 0.015);
        return Transform.translate(
          offset: Offset(0, lift),
          child: Transform.scale(
            scale: scale,
            child: child,
          ),
        );
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFDFEFF), Color(0xFFF5F2FF)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF7B61FF).withValues(alpha: 0.16),
              blurRadius: 30,
              offset: const Offset(0, 20),
            ),
            BoxShadow(
              color: const Color(0xFFFF6F91).withValues(alpha: 0.12),
              blurRadius: 40,
              offset: const Offset(0, 26),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(child: CustomPaint(painter: _BrandGlowPainter())),
            Positioned(top: size * 0.12, child: _ArcDots(size: size)),
            Positioned(
              top: size * 0.34,
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF4E8DFF), Color(0xFF9B6DFF), Color(0xFFFF6F91)],
                ).createShader(bounds),
                child: Text(
                  'MM',
                  style: TextStyle(
                    fontSize: size * 0.29,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    height: 0.9,
                    letterSpacing: -8,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: size * 0.24,
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF4E8DFF), Color(0xFF7B61FF), Color(0xFFFF6F91), Color(0xFFFF8A65)],
                ).createShader(bounds),
                child: Text(
                  'WELCONN',
                  style: TextStyle(
                    fontSize: size * 0.095,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 6,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: size * 0.12,
              child: SizedBox(
                width: size * 0.38,
                height: size * 0.09,
                child: CustomPaint(painter: _SmilePainter()),
              ),
            ),
            Positioned(
              bottom: size * 0.06,
              child: Container(
                width: size * 0.07,
                height: size * 0.07,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFF6F91), Color(0xFFFF8A65)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF6F91).withValues(alpha: 0.35),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandGlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..shader = const RadialGradient(
        colors: [Color(0x11FFFFFF), Color(0x00FFFFFF)],
      ).createShader(Rect.fromCircle(center: Offset(size.width * 0.5, size.height * 0.25), radius: size.shortestSide * 0.5));

    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.2),
      size.shortestSide * 0.26,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ArcDots extends StatelessWidget {
  final double size;

  const _ArcDots({required this.size});

  @override
  Widget build(BuildContext context) {
    final double radius = size * 0.35;
    final int count = 13;
    return SizedBox(
      width: size * 0.82,
      height: size * 0.28,
      child: Stack(
        children: [
          for (int i = 0; i < count; i++)
            _ArcDot(
              index: i,
              count: count,
              radius: radius,
              center: Offset(size * 0.41, size * 0.11),
            ),
        ],
      ),
    );
  }
}

class _ArcDot extends StatelessWidget {
  final int index;
  final int count;
  final double radius;
  final Offset center;

  const _ArcDot({
    required this.index,
    required this.count,
    required this.radius,
    required this.center,
  });

  @override
  Widget build(BuildContext context) {
    final double t = index / (count - 1);
    final double angle = math.pi + (math.pi * t);
    final double x = center.dx + math.cos(angle) * radius;
    final double y = center.dy + math.sin(angle) * radius * 0.76;
    final List<Color> palette = const [
      Color(0xFF4E8DFF),
      Color(0xFF57A8FF),
      Color(0xFF7B61FF),
      Color(0xFF9B6DFF),
      Color(0xFFFF6F91),
      Color(0xFFFF8A65),
    ];

    final Color color = palette[(index * (palette.length - 1) / (count - 1)).round()];
    final double dotSize = index == count ~/ 2 ? 28 : 12 + (index.isEven ? 3 : 0);

    return Positioned(
      left: x,
      top: y,
      child: Container(
        width: dotSize,
        height: dotSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.98), color.withValues(alpha: 0.6)],
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.28),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _SmilePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height * 0.22
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(
        colors: [Color(0xFF4E8DFF), Color(0xFF9B6DFF), Color(0xFFFF6F91)],
      ).createShader(Offset.zero & size);

    final path = Path()
      ..moveTo(size.width * 0.06, size.height * 0.25)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 1.15,
        size.width * 0.94,
        size.height * 0.25,
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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

  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
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