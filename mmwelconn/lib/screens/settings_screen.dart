import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mmwelconn/models/user_model.dart';
import 'package:mmwelconn/services/auth_service.dart';
import 'package:mmwelconn/services/cloudinary_service.dart';
import 'package:mmwelconn/services/firestore_service.dart';
import 'package:mmwelconn/widgets/app_brand.dart';

const String _currentVersion = '1.1.0';

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
  bool _autoUpdate = true;
  StreamSubscription<UserModel?>? _userSub;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _userSub = _fs.watchUser(uid).listen((u) {
        if (mounted) {
          setState(() {
            _user = u;
            if (u != null) {
              _notificationsEnabled = u.notificationsEnabled;
              _autoUpdate = u.autoUpdate;
            }
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }

  bool _uploadingPhoto = false;

  Future<void> _uploadPhoto() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final picker = ImagePicker();
    XFile? picked;
    if (kIsWeb) {
      picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, imageQuality: 85);
    } else {
      picked = await picker.pickImage(source: ImageSource.gallery, maxWidth: 512, imageQuality: 85);
    }
    if (picked == null) return;
    setState(() => _uploadingPhoto = true);
    try {
      String url;
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        url = await CloudinaryService.uploadBytes(bytes, uid, picked.name);
      } else {
        url = await CloudinaryService.uploadFile(File(picked.path), uid);
      }
      await _fs.updateUser(uid, {'profilePicture': url});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated ✓')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
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
    if (confirm != true) return;
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) await _fs.setUserStatus(uid, 'offline');
    } catch (_) {}
    await _auth.logout();
  }

  Future<void> _toggleVisibility(bool isOnline) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    // Optimistically update UI immediately
    setState(() {
      if (_user != null) {
        _user = UserModel(
          uid: _user!.uid,
          mmId: _user!.mmId,
          name: _user!.name,
          email: _user!.email,
          profilePicture: _user!.profilePicture,
          status: isOnline ? 'online' : 'offline',
          currentMoodId: _user!.currentMoodId,
          notificationsEnabled: _user!.notificationsEnabled,
          autoUpdate: _user!.autoUpdate,
          createdAt: _user!.createdAt,
          lastActive: _user!.lastActive,
        );
      }
    });
    try {
      await _fs.setUserStatus(uid, isOnline ? 'online' : 'offline');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isOnline ? '🟢 Now visible as Online' : '⚫ Now appearing Offline'),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update status')),
      );
    }
  }

  void _showEditProfile() {
    final nameCtrl = TextEditingController(text: _user?.name ?? '');
    final scaffoldCtx = context;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _BottomSheet(
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
              if (!sheetCtx.mounted) return;
              Navigator.pop(sheetCtx);
              ScaffoldMessenger.of(scaffoldCtx).showSnackBar(
                const SnackBar(content: Text('Profile updated ✓')),
              );
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
    final scaffoldCtx = context;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _BottomSheet(
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
                ScaffoldMessenger.of(scaffoldCtx).showSnackBar(
                  const SnackBar(content: Text('Passwords do not match')),
                );
                return;
              }
              if (newCtrl.text.length < 6) {
                ScaffoldMessenger.of(scaffoldCtx).showSnackBar(
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
                if (!sheetCtx.mounted) return;
                Navigator.pop(sheetCtx);
                ScaffoldMessenger.of(scaffoldCtx).showSnackBar(
                  const SnackBar(content: Text('Password changed ✓')),
                );
              } on FirebaseAuthException catch (e) {
                ScaffoldMessenger.of(scaffoldCtx).showSnackBar(
                  SnackBar(content: Text(e.message ?? 'Failed to update')),
                );
              }
            }),
          ],
        ),
      ),
    );
  }

  void _showPrivacy() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _BottomSheet(
        title: 'Privacy',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _privacyTile(
              'Who can send me connection requests',
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
            _sheetBtn('Save', AppTheme.violet, () => Navigator.pop(sheetCtx)),
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
            const SizedBox(height: 16),
            FutureBuilder<String?>(
              future: FirebaseMessaging.instance.getToken(),
              builder: (context, snap) {
                if (!snap.hasData) return const SizedBox.shrink();
                return GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: snap.data!));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('FCM token copied ✓')),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.violet.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.violet.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.copy_rounded, size: 14, color: AppTheme.violet),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            snap.data!,
                            style: const TextStyle(fontSize: 9, color: AppTheme.violet),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
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
    final isOnline = _user?.status == 'online';

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
                  GestureDetector(
                    onTap: _uploadingPhoto ? null : _uploadPhoto,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: AppTheme.violet.withValues(alpha: 0.18),
                          backgroundImage: _user?.profilePicture.isNotEmpty == true
                              ? NetworkImage(_user!.profilePicture)
                              : null,
                          child: _user?.profilePicture.isNotEmpty == true
                              ? null
                              : Text(initials,
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
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                        if (_uploadingPhoto)
                          Positioned.fill(
                            child: CircleAvatar(
                              radius: 32,
                              backgroundColor: Colors.black.withValues(alpha: 0.4),
                              child: const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              ),
                            ),
                          ),
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: AppTheme.violet,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            child: const Icon(Icons.edit_rounded,
                                size: 10, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
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
                        if (_user?.mmId.isNotEmpty == true)
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: _user!.mmId));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('MM ID copied: ${_user!.mmId}')),
                              );
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'ID: ${_user!.mmId}',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppTheme.violet,
                                      fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.copy_rounded,
                                    size: 11, color: AppTheme.violet),
                              ],
                            ),
                          ),
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
            if (_user == null)
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(),
              ))
            else
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
                              ? 'Visible to connections'
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
                    activeThumbColor: Colors.green,
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
                    onChanged: (v) async {
                      setState(() => _notificationsEnabled = v);
                      final uid = FirebaseAuth.instance.currentUser?.uid;
                      if (uid != null) {
                        await _fs.updateUser(uid, {'notificationsEnabled': v});
                      }
                    },
                    activeThumbColor: AppTheme.coral,
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

            // ── App Updates ───────────────────────────────────────────
            _SectionLabel('App Updates'),
            _AppUpdatesTile(autoUpdate: _autoUpdate, onAutoUpdateChanged: (v) async {
              setState(() => _autoUpdate = v);
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid != null) await _fs.updateAutoUpdate(uid, v);
            }),
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

// ── App Updates tile ───────────────────────────────────────────────────

class _AppUpdatesTile extends StatefulWidget {
  final bool autoUpdate;
  final ValueChanged<bool> onAutoUpdateChanged;
  const _AppUpdatesTile({required this.autoUpdate, required this.onAutoUpdateChanged});

  @override
  State<_AppUpdatesTile> createState() => _AppUpdatesTileState();
}

class _AppUpdatesTileState extends State<_AppUpdatesTile> {
  final FirestoreService _fs = FirestoreService();
  Map<String, dynamic> _versionData = {};
  StreamSubscription<Map<String, dynamic>>? _versionSub;

  @override
  void initState() {
    super.initState();
    _versionSub = _fs.watchAppVersion().listen((data) {
      if (mounted) setState(() => _versionData = data);
    });
  }

  @override
  void dispose() {
    _versionSub?.cancel();
    super.dispose();
  }

  String get _latestVersion => _versionData['latest'] ?? _currentVersion;
  String get _releaseNotes => _versionData['releaseNotes'] ?? 'No release notes available.';
  bool get _hasUpdate => _latestVersion != _currentVersion;

  void _showUpdateDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: AppTheme.violet.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.system_update_rounded, color: AppTheme.violet, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('App Update', style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.ink)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Current: ', style: TextStyle(fontSize: 13, color: AppTheme.ink.withValues(alpha: 0.5))),
                Text(_currentVersion, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.ink)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('Latest: ', style: TextStyle(fontSize: 13, color: AppTheme.ink.withValues(alpha: 0.5))),
                Text(_latestVersion, style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: _hasUpdate ? Colors.green : AppTheme.ink,
                )),
                if (_hasUpdate) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text('NEW', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.green)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Text('What\'s new:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.ink.withValues(alpha: 0.6))),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.violet.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(_releaseNotes, style: TextStyle(fontSize: 13, color: AppTheme.ink.withValues(alpha: 0.75), height: 1.5)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          if (_hasUpdate)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please refresh/reload the app to apply the latest update ✅'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 5),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Update Now', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: _showUpdateDialog,
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
                    color: (_hasUpdate ? Colors.green : AppTheme.violet).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _hasUpdate ? Icons.system_update_rounded : Icons.check_circle_rounded,
                    color: _hasUpdate ? Colors.green : AppTheme.violet,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('App Version', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.ink)),
                      Text(
                        _hasUpdate ? 'Update available: v$_latestVersion' : 'Up to date • v$_currentVersion',
                        style: TextStyle(
                          fontSize: 12,
                          color: _hasUpdate ? Colors.green : AppTheme.ink.withValues(alpha: 0.45),
                          fontWeight: _hasUpdate ? FontWeight.w700 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_hasUpdate)
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                  ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: AppTheme.ink.withValues(alpha: 0.3)),
              ],
            ),
          ),
        ),
        Container(
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
                  color: AppTheme.sky.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.autorenew_rounded, color: AppTheme.sky, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Auto Update', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: AppTheme.ink)),
                    Text(
                      widget.autoUpdate ? 'Updates apply automatically' : 'Manual updates only',
                      style: TextStyle(fontSize: 12, color: AppTheme.ink.withValues(alpha: 0.45)),
                    ),
                  ],
                ),
              ),
              Switch(
                value: widget.autoUpdate,
                onChanged: widget.onAutoUpdateChanged,
                activeThumbColor: AppTheme.sky,
              ),
            ],
          ),
        ),
      ],
    );
  }
}


