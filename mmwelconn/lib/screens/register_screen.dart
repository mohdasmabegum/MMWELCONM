import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mmwelconm/screens/login_screen.dart';
import 'package:mmwelconm/services/auth_service.dart';
import 'package:mmwelconm/widgets/app_brand.dart';

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
  String _selectedAgeGroup = 'adult';
  DateTime? _selectedDob;

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select Date of Birth';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _onDobSelected(DateTime date) {
    setState(() {
      _selectedDob = date;
      final now = DateTime.now();
      int age = now.year - date.year;
      if (now.month < date.month || (now.month == date.month && now.day < date.day)) {
        age--;
      }
      
      if (age < 13) {
        _selectedAgeGroup = 'kid';
      } else if (age < 20) {
        _selectedAgeGroup = 'teen';
      } else if (age < 55) {
        _selectedAgeGroup = 'adult';
      } else {
        _selectedAgeGroup = 'elder';
      }
    });
  }

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

    if (_selectedDob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your Date of Birth')),
      );
      return;
    }

    setState(() => _loading = true);
    final user = await _authService.signUp(
      _emailController.text.trim(),
      _passwordController.text,
      _nameController.text.trim(),
      ageGroup: _selectedAgeGroup,
      dateOfBirth: _selectedDob,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration failed. Try again.')),
      );
    } else {
      // Sign out so AuthGate doesn't auto-redirect to home
      TextInput.finishAutofillContext();
      await _authService.logout();
      if (!mounted) return;
      await showAccountCreatedDialog(
        context,
        onGoToLogin: () {
          Navigator.of(context).pop(); // close dialog
          Navigator.of(context).pushReplacement(buildPageRoute(const LoginScreen()));
        },
      );
    }
  }

  Widget _buildModeSelector() {
    final List<Map<String, dynamic>> groups = [
      {'id': 'kid', 'label': 'Kid', 'sub': 'Age 5-12', 'icon': Icons.child_care_rounded, 'color': Colors.blue},
      {'id': 'teen', 'label': 'Teen', 'sub': 'Age 13-19', 'icon': Icons.bolt_rounded, 'color': Colors.purple},
      {'id': 'adult', 'label': 'Adult', 'sub': 'Age 20-55', 'icon': Icons.person_rounded, 'color': Colors.pink},
      {'id': 'elder', 'label': 'Elder', 'sub': 'Age 55+', 'icon': Icons.elderly_rounded, 'color': Colors.teal},
      {'id': 'professional', 'label': 'Professional', 'sub': 'Work Hub', 'icon': Icons.business_center_rounded, 'color': Colors.indigo},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Select App Mode',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.2,
          ),
          itemCount: groups.length,
          itemBuilder: (context, index) {
            final group = groups[index];
            final id = group['id'] as String;
            final label = group['label'] as String;
            final sub = group['sub'] as String;
            final icon = group['icon'] as IconData;
            final color = group['color'] as Color;
            final isSelected = _selectedAgeGroup == id;

            return GestureDetector(
              onTap: () {
                setState(() => _selectedAgeGroup = id);
                HapticFeedback.lightImpact();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? color.withOpacity(0.12) : Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? color : Colors.black12,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: color.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 4))]
                      : [],
                ),
                child: Row(
                  children: [
                    Icon(icon, color: isSelected ? color : Colors.black54, size: 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? color : Colors.black87,
                            ),
                          ),
                          Text(
                            sub,
                            style: const TextStyle(fontSize: 10, color: Colors.black45),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
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
                            const Center(child: BrandLogo(size: 180, circular: true)),
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
                              'Start your MMWELCONM experience in a few seconds.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.ink.withValues(alpha: 0.65),
                                  ),
                            ),
                            const SizedBox(height: 26),
                            AutofillGroup(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AuthField(
                                    controller: _nameController,
                                    label: 'Full name',
                                    icon: Icons.person_rounded,
                                    autofillHints: const [AutofillHints.name],
                                  ),
                                  const SizedBox(height: 16),
                                  AuthField(
                                    controller: _emailController,
                                    label: 'Email address',
                                    icon: Icons.email_rounded,
                                    keyboardType: TextInputType.emailAddress,
                                    autofillHints: const [AutofillHints.username, AutofillHints.email],
                                  ),
                                  const SizedBox(height: 16),
                                  AuthField(
                                    controller: _passwordController,
                                    label: 'Password',
                                    icon: Icons.lock_rounded,
                                    obscureText: true,
                                    autofillHints: const [AutofillHints.newPassword],
                                  ),
                                  const SizedBox(height: 16),
                                  GestureDetector(
                                    onTap: () async {
                                      final now = DateTime.now();
                                      final selected = await showDatePicker(
                                        context: context,
                                        initialDate: _selectedDob ?? DateTime(now.year - 18, now.month, now.day),
                                        firstDate: DateTime(now.year - 120),
                                        lastDate: now,
                                      );
                                      if (selected != null) {
                                        _onDobSelected(selected);
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.03),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          )
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.cake_rounded, color: AppTheme.violet),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              _selectedDob == null
                                                  ? 'Date of Birth'
                                                  : 'Birthday: ${_formatDate(_selectedDob)}',
                                              style: TextStyle(
                                                color: _selectedDob == null ? Colors.black38 : AppTheme.ink,
                                                fontWeight: _selectedDob == null ? FontWeight.normal : FontWeight.bold,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                          const Icon(Icons.chevron_right_rounded, color: Colors.black26),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildModeSelector(),
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

/// Placeholder for a success dialog.
Future<void> showAccountCreatedDialog(
  BuildContext context, {
  required VoidCallback onGoToLogin,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF4CAF50), Color(0xFF81C784)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x334CAF50),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 38,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Account Created!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your account has been successfully created. Please log in to continue.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onGoToLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.violet,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Go to Login'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}