import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' show Vector3;

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
      child: ClipOval(
        child: Image.asset(
          'assets/logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
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
        transform: Matrix4.translationValues(0.0, _hovering ? -8.0 : 0.0, 0.0)
          ..scaleByVector3(Vector3.all(_hovering ? 1.012 : 1.0)),
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
          transform: Matrix4.translationValues(0.0, _hovering ? -5.0 : 0.0, 0.0)
            ..scaleByVector3(Vector3.all(_hovering ? 1.02 : 1.0)),
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

Future<void> showAuthSuccess(BuildContext context, {required String title, required String subtitle, required List<Color> colors}) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (ctx) => _SimpleSuccessDialog(title: title, subtitle: subtitle, colors: colors),
  );
}

class _SimpleSuccessDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<Color> colors;
  const _SimpleSuccessDialog({required this.title, required this.subtitle, required this.colors});
  @override
  State<_SimpleSuccessDialog> createState() => _SimpleSuccessDialogState();
}

class _SimpleSuccessDialogState extends State<_SimpleSuccessDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    Future.delayed(const Duration(milliseconds: 1800), () { if (mounted) Navigator.of(context).pop(); });
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 300,
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [BoxShadow(color: widget.colors.first.withValues(alpha: 0.22), blurRadius: 40, offset: const Offset(0, 16))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _scale,
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: widget.colors),
                    boxShadow: [BoxShadow(color: widget.colors.first.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 8))],
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 44),
                ),
              ),
              const SizedBox(height: 22),
              Text(widget.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppTheme.ink)),
              const SizedBox(height: 8),
              Text(widget.subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppTheme.ink.withValues(alpha: 0.55), fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showAccountCreatedDialog(BuildContext context, {required VoidCallback onGoToLogin}) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    builder: (_) => _AccountCreatedDialog(onGoToLogin: onGoToLogin),
  );
}

class _AccountCreatedDialog extends StatefulWidget {
  final VoidCallback onGoToLogin;
  const _AccountCreatedDialog({required this.onGoToLogin});

  @override
  State<_AccountCreatedDialog> createState() => _AccountCreatedDialogState();
}

class _AccountCreatedDialogState extends State<_AccountCreatedDialog> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
    _scale = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              width: 320,
              padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF9B6DFF).withValues(alpha: 0.18),
                    blurRadius: 44,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF9B6DFF), Color(0xFFFF6F91)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF9B6DFF).withValues(alpha: 0.32),
                          blurRadius: 22,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 42),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Welcome to MMWELCONN! 🎉',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.ink),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Your account has been created successfully.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppTheme.ink.withValues(alpha: 0.55), fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ready to connect your mood with style?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppTheme.ink.withValues(alpha: 0.42)),
                  ),
                  const SizedBox(height: 26),
                  const Divider(height: 1),
                  const SizedBox(height: 18),
                  GestureDetector(
                    onTap: widget.onGoToLogin,
                    child: RichText(
                      text: TextSpan(
                        text: 'Already have your account? ',
                        style: TextStyle(fontSize: 14, color: AppTheme.ink.withValues(alpha: 0.55)),
                        children: const [
                          TextSpan(
                            text: 'Log in',
                            style: TextStyle(
                              color: Color(0xFF4E8DFF),
                              fontWeight: FontWeight.w800,
                              decoration: TextDecoration.underline,
                              decorationColor: Color(0xFF4E8DFF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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