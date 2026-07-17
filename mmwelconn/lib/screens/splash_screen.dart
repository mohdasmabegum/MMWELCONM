import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mmwelconm/widgets/app_brand.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({super.key, required this.onComplete});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _scaleController;
  late final AnimationController _floatController;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _scaleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _floatController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat(reverse: true);
    _fade = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _scale = CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut);
    _fadeController.forward();
    _scaleController.forward();

    Timer(const Duration(seconds: 2), widget.onComplete);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF6F8FF), Color(0xFFF7F1FF), Color(0xFFFFF3F6)],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: AnimatedBuilder(
              animation: _floatController,
              builder: (context, child) {
                final double drift = (_floatController.value - 0.5) * 14;
                return Transform.translate(offset: Offset(0, drift), child: child);
              },
              child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const BrandLogo(size: 240),
                    const SizedBox(height: 26),
                    Text(
                      'mmwelconm',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: AppTheme.ink,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Connect your mood with style',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppTheme.ink.withValues(alpha: 0.66),
                          ),
                    ),
                    const SizedBox(height: 30),
                    Container(
                      width: 180,
                      height: 5,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4E8DFF), Color(0xFF9B6DFF), Color(0xFFFF6F91)],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}