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
  final TextEditingController _phoneController = TextEditingController();
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _loading = false;
  bool _showMfaSection = false;
  String? _verificationId;

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
    _phoneController.dispose();
    super.dispose();
  }

  void _toggleMfaSection() {
    setState(() => _showMfaSection = !_showMfaSection);
  }

  Future<void> _sendVerificationCode(String phoneNumber) async {
    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter phone number')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      _verificationId = await _authService.sendPhoneVerificationCode(phoneNumber);
      if (!mounted) return;
      if (_verificationId != null) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification code sent!')),
        );
      } else {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send code. Try again.')),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _verifyAndCompleteRegistration() async {
    if (_verificationId == null || _phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter verification code')),
      );
      return;
    }

    // First complete email/pass registration, then link phone
    setState(() => _loading = true);
    try {
      final user = await _authService.signUp(
        _emailController.text.trim(),
        _passwordController.text,
        _nameController.text.trim(),
      );
      if (!mounted) return;

      if (user != null) {
        // Link phone number to account
        await _authService.verifyAndLinkPhone(_verificationId!, _phoneController.text);
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration failed. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all registration fields')),
      );
      return;
    }

    setState(() => _loading = true);
    final user = await _authService.signUp(
      _emailController.text.trim(),
      _passwordController.text,
      _nameController.text.trim(),
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration failed. Try again.')),
      );
    } else {
      await showAuthSuccess(
        context,
        title: 'Account Created!',
        subtitle: 'Welcome to MMWELCONN 🎉',
        colors: const [Color(0xFFFF6F91), Color(0xFFFF8A65)],
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
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
                            const SizedBox(height: 18),
                            // MFA toggle section
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F9FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF4E8DFF).withValues(alpha: 0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.security_rounded,
                                        color: const Color(0xFF4E8DFF),
                                        size: 22,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Enable Mobile OTP (MFA)',
                                          style: TextStyle(
                                            color: const Color(0xFF4E8DFF),
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                      Switch(
                                        value: _showMfaSection,
                                        onChanged: (_) => _toggleMfaSection(),
                                        activeColor: const Color(0xFF4E8DFF),
                                      ),
                                    ],
                                  ),
                                  if (_showMfaSection) ...[
                                    const SizedBox(height: 14),
                                    Text(
                                      'Add an extra layer of security by linking your phone number.',
                                      style: TextStyle(
                                        color: AppTheme.ink.withValues(alpha: 0.6),
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    AuthField(
                                      controller: _phoneController,
                                      label: 'Phone number',
                                      icon: Icons.phone_android_rounded,
                                      keyboardType: TextInputType.phone,
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      height: 44,
                                      child: HoverActionButton(
                                        label: _loading ? 'Sending...' : 'Send Code',
                                        icon: Icons.sms_rounded,
                                        colors: const [Color(0xFF4E8DFF), Color(0xFF7B61FF)],
                                        onPressed: _loading
                                            ? () {}
                                            : () => _sendVerificationCode(_phoneController.text),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
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