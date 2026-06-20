import 'package:flutter/material.dart';
import 'package:mmwelconn/widgets/app_brand.dart';

class AuthLandingScreen extends StatefulWidget {
  final VoidCallback onLoginTap;
  final VoidCallback onRegisterTap;

  const AuthLandingScreen({
    super.key,
    required this.onLoginTap,
    required this.onRegisterTap,
  });

  @override
  State<AuthLandingScreen> createState() => _AuthLandingScreenState();
}

class _AuthLandingScreenState extends State<AuthLandingScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.10), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _scale = Tween<double>(begin: 0.94, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SoftGlowBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double width = constraints.maxWidth;
              return SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: width *0.06,
                    vertical: 18,
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      FadeTransition(
                        opacity: _fade,
                        child: SlideTransition(
                          position: _slide,
                          child: ScaleTransition(
                            scale: _scale,
                            child: Column(
                              children: [
                                const BrandLogo(size: 300),
                                const SizedBox(height: 28),
                                Text(
                                  'MMWELCONN',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 2,
                                        color: AppTheme.ink,
                                      ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Connect mood, moments, and people in a calm, elegant space.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        color: AppTheme.ink.withValues(alpha: 0.7),
                                        height: 1.5,
                                      ),
                                ),
                                const SizedBox(height: 22),
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: const [
                                    FeaturePill(icon: Icons.favorite, label: 'Mood sharing', color: AppTheme.pink),
                                    FeaturePill(icon: Icons.chat_bubble_rounded, label: 'Private chat', color: AppTheme.violet),
                                    FeaturePill(icon: Icons.location_on_rounded, label: 'Live presence', color: AppTheme.sky),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: HoverCard(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          child: Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              color: Colors.white.withValues(alpha: 0.72),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.violet.withValues(alpha: 0.12),
                                  blurRadius: 32,
                                  offset: const Offset(0, 18),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Begin your experience',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: AppTheme.ink,
                                      ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Choose the path that fits you best.',
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: AppTheme.ink.withValues(alpha: 0.68),
                                      ),
                                ),
                                const SizedBox(height: 20),
                                HoverActionButton(
                                  label: 'Login',
                                  icon: Icons.login_rounded,
                                  colors: const [Color(0xFF4E8DFF), Color(0xFF7B61FF)],
                                  onPressed: widget.onLoginTap,
                                ),
                                const SizedBox(height: 14),
                                HoverActionButton(
                                  label: 'Create account',
                                  icon: Icons.person_add_alt_1_rounded,
                                  colors: const [Color(0xFFFF6F91), Color(0xFFFF8A65)],
                                  outlined: true,
                                  onPressed: widget.onRegisterTap,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Designed for elegant first impressions on web and mobile.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.ink.withValues(alpha: 0.55),
                            ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}