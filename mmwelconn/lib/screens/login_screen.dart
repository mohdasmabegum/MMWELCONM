import 'package:flutter/material.dart';
import 'package:mmwelconn/screens/register_screen.dart';
import 'package:mmwelconn/services/auth_service.dart';
import 'package:mmwelconn/widgets/app_brand.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _loading = false;
  bool _showOtpSection = false;
  String? _verificationId;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0.04, 0.05), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp(String phoneNumber) async {
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
        setState(() {
          _loading = false;
          _showOtpSection = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP sent! Check your phone.')),
        );
      } else {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send OTP. Try again.')),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_verificationId == null || _otpController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the OTP code')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final user = await _authService.signInWithPhone(_verificationId!, _otpController.text);
      if (!mounted) return;
      if (user != null) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid OTP. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in email and password')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final user = await _authService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login failed. Check your details.')),
        );
      } else {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
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
                constraints: const BoxConstraints(maxWidth: 520),
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
                              'Welcome back',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.ink,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Sign in to continue your MMWELCONN journey.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.ink.withValues(alpha: 0.65),
                                  ),
                            ),
                            const SizedBox(height: 26),
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
                              label: _loading ? 'Signing in...' : 'Login',
                              icon: Icons.login_rounded,
                              colors: const [Color(0xFF4E8DFF), Color(0xFF7B61FF)],
                              onPressed: _loading ? () {} : _login,
                            ),
                            const SizedBox(height: 16),
                            const Divider(height: 24, thickness: 1, color: Color(0xFFE0E0E0)),
                            const SizedBox(height: 8),
                            Text(
                              'Or sign in with Mobile OTP',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppTheme.ink.withValues(alpha: 0.55),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 14),
                            AuthField(
                              controller: _showOtpSection ? _otpController : _emailController,
                              label: _showOtpSection ? 'Enter OTP code' : 'Phone number',
                              icon: Icons.phone_android_rounded,
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 16),
                            HoverActionButton(
                              label: _loading
                                  ? 'Processing...'
                                  : (_showOtpSection ? 'Verify OTP' : 'Send OTP'),
                              icon: _showOtpSection ? Icons.check_circle_rounded : Icons.sms_rounded,
                              colors: const [Color(0xFF00C853), Color(0xFF69F0AE)],
                              onPressed: _loading
                                  ? () {}
                                  : (_showOtpSection ? _verifyOtp : () => _sendOtp(_emailController.text)),
                            ),
                            if (!_showOtpSection) ...[
                              const SizedBox(height: 10),
                              Text(
                                'We\'ll send a verification code to your phone',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppTheme.ink.withValues(alpha: 0.45),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  buildPageRoute(const RegisterScreen()),
                                );
                              },
                              child: const Text('No account yet? Create one here'),
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
