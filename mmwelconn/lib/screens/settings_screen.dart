import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mmwelconn/models/user_model.dart';
import 'package:mmwelconn/screens/crud_test_screen.dart';
import 'package:mmwelconn/services/auth_service.dart';
import 'package:mmwelconn/services/firestore_service.dart';
import 'package:mmwelconn/widgets/app_brand.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirestoreService _fs = FirestoreService();
  final AuthService _auth = AuthService();
  UserModel? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final u = await _fs.getUser(uid);
    if (mounted) setState(() => _user = u);
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log out?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('You will be returned to the login screen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) await _auth.logout();
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    final name = _user?.name ?? email.split('@').first;
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return SoftGlowBackground(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
            Text('Settings', style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900, color: AppTheme.ink)),
            const SizedBox(height: 24),

            // Profile card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppTheme.violet.withValues(alpha: 0.18),
                    child: Text(initials, style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.violet)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 17, color: AppTheme.ink)),
                        const SizedBox(height: 4),
                        Text(email, style: TextStyle(
                            fontSize: 13, color: AppTheme.ink.withValues(alpha: 0.5))),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(_user?.status ?? 'online',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.green, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            _SectionLabel('Account'),
            _SettingsTile(
              icon: Icons.person_outline_rounded,
              label: 'Edit Profile',
              color: AppTheme.violet,
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.lock_outline_rounded,
              label: 'Change Password',
              color: AppTheme.sky,
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.phone_android_rounded,
              label: 'Phone & MFA',
              color: AppTheme.pink,
              subtitle: _user?.mfaEnabled == true ? 'Enabled' : 'Disabled',
              onTap: () {},
            ),
            const SizedBox(height: 20),

            _SectionLabel('Preferences'),
            _SettingsTile(
              icon: Icons.notifications_none_rounded,
              label: 'Notifications',
              color: AppTheme.coral,
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.palette_outlined,
              label: 'Appearance',
              color: AppTheme.violet,
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.privacy_tip_outlined,
              label: 'Privacy',
              color: AppTheme.sky,
              onTap: () {},
            ),
            const SizedBox(height: 20),

            _SectionLabel('Developer'),
            _SettingsTile(
              icon: Icons.developer_mode_rounded,
              label: 'CRUD Test Panel',
              color: AppTheme.ink,
              subtitle: 'Test Firestore operations',
              onTap: () => Navigator.of(context).push(buildPageRoute(const CrudTestScreen())),
            ),
            const SizedBox(height: 20),

            _SectionLabel('Support'),
            _SettingsTile(
              icon: Icons.help_outline_rounded,
              label: 'Help & FAQ',
              color: AppTheme.sky,
              onTap: () {},
            ),
            _SettingsTile(
              icon: Icons.info_outline_rounded,
              label: 'About MMWELCONN',
              color: AppTheme.violet,
              subtitle: 'Version 1.0.0',
              onTap: () {},
            ),
            const SizedBox(height: 20),

            // Logout
            GestureDetector(
              onTap: _logout,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.pink.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.pink.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.pink.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.logout_rounded, color: AppTheme.pink, size: 20),
                    ),
                    const SizedBox(width: 16),
                    const Text('Log Out', style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.pink)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Text(label.toUpperCase(),
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppTheme.ink.withValues(alpha: 0.4))),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.ink)),
                  if (subtitle != null)
                    Text(subtitle!, style: TextStyle(
                        fontSize: 12, color: AppTheme.ink.withValues(alpha: 0.45))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppTheme.ink.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }
}
