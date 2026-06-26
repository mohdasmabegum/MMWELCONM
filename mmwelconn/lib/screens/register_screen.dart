import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mmwelconn/screens/login_screen.dart';
import 'package:mmwelconn/services/auth_service.dart';
import 'package:mmwelconn/widgets/app_brand.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(-0.04, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all registration fields')),
      );
      return;
    }
    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final user = await _authService.signUp(
        _emailController.text.trim(),
        _passwordController.text,
        _nameController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _loading = false);
      if (user != null) {
        await showAccountCreatedDialog(
          context,
          onGoToLogin: () {
            Navigator.of(context).pop();
            if (!mounted) return;
            Navigator.of(context).pushReplacement(buildPageRoute(const LoginScreen()));
          },
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      final msg = switch (e.code) {
        'email-already-in-use' => 'An account already exists for this email.',
        'weak-password' => 'Password is too weak. Use at least 6 characters.',
        'invalid-email' => 'Please enter a valid email address.',
        'network-request-failed' => 'Network error. Check your connection.',
        _ => e.message ?? 'Registration failed. Please try again.',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An unexpected error occurred.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SoftGlowBackground(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: FadeTransition(
                  opacity: _fade,
                  child: SlideTransition(
                    position: _slide,
                    child: HoverCard(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30),
                          color: Colors.white.withValues(alpha: 0.74),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Center(child: BrandLogo(size: 180)),
                            const SizedBox(height: 18),
                            Text(
                              'Create account',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.ink,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start your MMWELCONN experience in a few seconds.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.ink.withValues(alpha: 0.65),
                                  ),
                            ),
                            const SizedBox(height: 26),
                            AuthField(
                              controller: _nameController,
                              label: 'Full name',
                              icon: Icons.person_rounded,
                            ),
                            const SizedBox(height: 16),
                            AuthField(
                              controller: _emailController,
                              label: 'Email address',
                              icon: Icons.email_rounded,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 16),
                            AuthField(
                              controller: _passwordController,
                              label: 'Password',
                              icon: Icons.lock_rounded,
                              obscureText: true,
                            ),
                            const SizedBox(height: 22),
                            HoverActionButton(
                              label: _loading ? 'Creating...' : 'Register',
                              icon: Icons.person_add_alt_1_rounded,
                              colors: const [Color(0xFFFF6F91), Color(0xFFFF8A65)],
                              onPressed: _loading ? () {} : _register,
                            ),
                            const SizedBox(height: 14),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  buildPageRoute(const LoginScreen()),
                                );
                              },
                              child: const Text('Already have an account? Login'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}