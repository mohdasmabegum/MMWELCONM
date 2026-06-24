import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mmwelconn/models/user_model.dart';
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
  bool _notificationsEnabled = true;

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
        title: const Text('Log out?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('You will be returned to the login screen.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Log out',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) await _fs.setUserStatus(uid, 'offline');
      await _auth.logout();
    }
  }

  Future<void> _toggleVisibility(bool isOnline) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final newStatus = isOnline ? 'online' : 'offline';
    await _fs.setUserStatus(uid, newStatus);
    await _loadUser();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isOnline
              ? '🟢 You are now visible as Online'
              : '⚫ You are now appearing Offline'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showEditProfile() {
    final nameCtrl =
        TextEditingController(text: _user?.name ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BottomSheet(
        title: 'Edit Profile',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sheetField(nameCtrl, 'Display name', Icons.person_outline_rounded),
            const SizedBox(height: 20),
            _sheetBtn('Save Changes', AppTheme.violet, () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid == null) return;
              await _fs.updateUser(uid, {'name': name});
              await _loadUser();
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile updated ✓')),
                );
              }
            }),
          ],
        ),
      ),
    );
  }

  void _showChangePassword() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BottomSheet(
        title: 'Change Password',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sheetField(currentCtrl, 'Current password',
                Icons.lock_outline_rounded,
                obscure: true),
            const SizedBox(height: 12),
            _sheetField(
                newCtrl, 'New password', Icons.lock_reset_rounded,
                obscure: true),
            const SizedBox(height: 12),
            _sheetField(confirmCtrl, 'Confirm new password',
                Icons.lock_rounded,
                obscure: true),
            const SizedBox(height: 20),
            _sheetBtn('Update Password', AppTheme.sky, () async {
              if (newCtrl.text != confirmCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match')),
                );
                return;
              }
              if (newCtrl.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Password must be at least 6 characters')),
                );
                return;
              }
              try {
                final user = FirebaseAuth.instance.currentUser!;
                final cred = EmailAuthProvider.credential(
                    email: user.email!, password: currentCtrl.text);
                await user.reauthenticateWithCredential(cred);
                await user.updatePassword(newCtrl.text);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password changed ✓')),
                  );
                }
              } on FirebaseAuthException catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.message ?? 'Failed to update')),
                  );
                }
              }
            }),
          ],
        ),
      ),
    );
  }

  void _showPhoneMfa() {
    final phoneCtrl = TextEditingController(
        text: _user?.phoneNumber ?? '');
    final otpCtrl = TextEditingController();
    String? verificationId;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => _BottomSheet(
          title: 'Phone & MFA',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sheetField(phoneCtrl, 'Phone number (+country code)',
                  Icons.phone_android_rounded,
                  type: TextInputType.phone),
              const SizedBox(height: 12),
              if (verificationId != null) ...[
                _sheetField(otpCtrl, 'Enter OTP code', Icons.sms_rounded,
                    type: TextInputType.number),
                const SizedBox(height: 12),
                _sheetBtn('Verify & Link', AppTheme.violet, () async {
                  final user = await _auth.verifyAndLinkPhone(
                      verificationId!, otpCtrl.text.trim());
                  if (user != null && mounted) {
                    await _loadUser();
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Phone linked & MFA enabled ✓')),
                    );
                  }
                }),
              ] else
                _sheetBtn('Send OTP', AppTheme.sky, () async {
                  final id = await _auth.sendPhoneVerificationCode(
                      phoneCtrl.text.trim());
                  if (id != null) {
                    setS(() => verificationId = id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('OTP sent ✓')),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to send OTP')),
                    );
                  }
                }),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrivacy() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BottomSheet(
        title: 'Privacy',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _privacyTile(
              'Who can send me contact requests',
              'Everyone',
              Icons.people_outline_rounded,
            ),
            const SizedBox(height: 10),
            _privacyTile(
              'Who can see my last active',
              'My Contacts',
              Icons.access_time_rounded,
            ),
            const SizedBox(height: 10),
            _privacyTile(
              'Who can see my mood',
              'Everyone',
              Icons.favorite_outline_rounded,
            ),
            const SizedBox(height: 20),
            _sheetBtn('Save', AppTheme.violet, () => Navigator.pop(context)),
          ],
        ),
      ),
    );
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BrandLogo(size: 80),
            const SizedBox(height: 16),
            const Text('MMWELCONN',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: AppTheme.ink)),
            const SizedBox(height: 6),
            Text('Version 1.0.0',
                style: TextStyle(
                    color: AppTheme.ink.withValues(alpha: 0.5),
                    fontSize: 13)),
            const SizedBox(height: 10),
            Text(
              'A calm social space for mood sharing, chat, status updates, and friend connection.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppTheme.ink.withValues(alpha: 0.65),
                  fontSize: 13,
                  height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    final name = _user?.name ?? email.split('@').first;
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final isOnline = (_user?.status ?? 'online') == 'online';

    return SoftGlowBackground(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
            Text('Settings',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900, color: AppTheme.ink)),
            const SizedBox(height: 24),

            // ── Profile card ─────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor:
                            AppTheme.violet.withValues(alpha: 0.18),
                        child: Text(initials,
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.violet)),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: isOnline ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 17,
                                color: AppTheme.ink)),
                        const SizedBox(height: 4),
                        Text(email,
                            style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.ink
                                    .withValues(alpha: 0.5))),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: isOnline
                                ? Colors.green.withValues(alpha: 0.12)
                                : Colors.grey.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            isOnline ? 'Online' : 'Offline',
                            style: TextStyle(
                                fontSize: 11,
                                color:
                                    isOnline ? Colors.green : Colors.grey,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ── Visibility ───────────────────────────────────────────────
            _SectionLabel('Visibility'),
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: (isOnline ? Colors.green : Colors.grey)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isOnline
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      color: isOnline ? Colors.green : Colors.grey,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Online Status',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppTheme.ink)),
                        Text(
                          isOnline
                              ? 'Visible to contacts'
                              : 'Appearing offline',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.ink.withValues(alpha: 0.45)),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: isOnline,
                    onChanged: _toggleVisibility,
                    activeColor: Colors.green,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // ── Account ──────────────────────────────────────────────────
            _SectionLabel('Account'),
            _SettingsTile(
              icon: Icons.person_outline_rounded,
              label: 'Edit Profile',
              subtitle: 'Change your display name',
              color: AppTheme.violet,
              onTap: _showEditProfile,
            ),
            _SettingsTile(
              icon: Icons.lock_outline_rounded,
              label: 'Change Password',
              subtitle: 'Update your login password',
              color: AppTheme.sky,
              onTap: _showChangePassword,
            ),
            _SettingsTile(
              icon: Icons.phone_android_rounded,
              label: 'Phone & MFA',
              subtitle: _user?.mfaEnabled == true
                  ? '✓ MFA Enabled'
                  : 'Not configured',
              color: AppTheme.pink,
              onTap: _showPhoneMfa,
            ),
            const SizedBox(height: 10),

            // ── Preferences ──────────────────────────────────────────────
            _SectionLabel('Preferences'),
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.coral.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.notifications_none_rounded,
                        color: AppTheme.coral, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Notifications',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppTheme.ink)),
                        Text(
                          _notificationsEnabled ? 'Enabled' : 'Disabled',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.ink.withValues(alpha: 0.45)),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _notificationsEnabled,
                    onChanged: (v) =>
                        setState(() => _notificationsEnabled = v),
                    activeColor: AppTheme.coral,
                  ),
                ],
              ),
            ),
            _SettingsTile(
              icon: Icons.privacy_tip_outlined,
              label: 'Privacy',
              subtitle: 'Manage who sees your info',
              color: AppTheme.sky,
              onTap: _showPrivacy,
            ),
            const SizedBox(height: 10),

            // ── Support ──────────────────────────────────────────────────
            _SectionLabel('Support'),
            _SettingsTile(
              icon: Icons.info_outline_rounded,
              label: 'About MMWELCONN',
              subtitle: 'Version 1.0.0',
              color: AppTheme.violet,
              onTap: _showAbout,
            ),
            const SizedBox(height: 20),

            // ── Logout ───────────────────────────────────────────────────
            GestureDetector(
              onTap: _logout,
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppTheme.pink.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: AppTheme.pink.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.pink.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.logout_rounded,
                          color: AppTheme.pink, size: 20),
                    ),
                    const SizedBox(width: 16),
                    const Text('Log Out',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppTheme.pink)),
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

// ── Shared sheet helpers ──────────────────────────────────────────────────────

class _BottomSheet extends StatelessWidget {
  final String title;
  final Widget child;
  const _BottomSheet({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: const BoxDecoration(
          color: Color(0xFFF6F8FF),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppTheme.ink.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999))),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: AppTheme.ink)),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

Widget _sheetField(
  TextEditingController ctrl,
  String hint,
  IconData icon, {
  bool obscure = false,
  TextInputType type = TextInputType.text,
}) =>
    TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: type,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.9),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );

Widget _sheetBtn(String label, Color color, VoidCallback onTap) =>
    ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 14),
        elevation: 0,
      ),
      child:
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );

Widget _privacyTile(String label, String value, IconData icon) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.violet),
          const SizedBox(width: 14),
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppTheme.ink))),
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.ink.withValues(alpha: 0.45))),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded,
              size: 18, color: AppTheme.ink.withValues(alpha: 0.3)),
        ],
      ),
    );

// ── Reusable widgets ──────────────────────────────────────────────────────────

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
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
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
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppTheme.ink)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.ink.withValues(alpha: 0.45))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: AppTheme.ink.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }
}
