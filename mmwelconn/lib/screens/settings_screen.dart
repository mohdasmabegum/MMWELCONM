import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mmwelconm/models/user_model.dart';
import 'package:mmwelconm/screens/connections_screen.dart';
import 'package:mmwelconm/screens/photos_screen.dart';
import 'package:mmwelconm/screens/requests_screen.dart';
import 'package:mmwelconm/screens/profile_screen.dart';
import 'package:mmwelconm/screens/privacy_settings_screen.dart';
import 'package:mmwelconm/services/auth_service.dart';
import 'package:mmwelconm/services/firestore_service.dart';
import 'package:mmwelconm/services/notification_service.dart';
import 'package:mmwelconm/widgets/app_brand.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirestoreService _fs = FirestoreService();
  final AuthService _auth = AuthService();
  bool _changingStatus = false;

  Future<void> _setPref(String uid, String key, bool value) {
    return _fs.updateUser(uid, {key: value});
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }

  Future<void> _setShowOnline(String uid, bool showOnline) async {
    setState(() => _changingStatus = true);
    try {
      await _fs.setShowOnline(uid, showOnline);
    } finally {
      if (mounted) setState(() => _changingStatus = false);
    }
  }

  void _changePasscodePin(String uid) {
    final pinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Passcode PIN', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.ink)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: TextField(
          controller: pinCtrl,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter new 4-digit PIN',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newPin = pinCtrl.text.trim();
              if (newPin.length == 4 && int.tryParse(newPin) != null) {
                await _fs.updateUser(uid, {'chatLockPin': newPin});
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN updated successfully!')),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid 4-digit PIN.')),
                );
              }
            },
            child: const Text('Save', style: TextStyle(color: AppTheme.violet, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _changeLockPattern(String uid) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PatternSetupDialog(
        onSaved: (pattern) async {
          await _fs.updateUser(uid, {'chatLockPattern': pattern});
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Lock pattern updated successfully!')),
            );
          }
        },
      ),
    );
  }

  Future<void> _resetSecurityLocks(String uid) async {
    await _fs.updateUser(uid, {
      'chatLockPin': '1234',
      'chatLockPattern': '',
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Locks reset: custom pattern removed, PIN set to 1234.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return SoftGlowBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: uid == null
              ? const Center(child: Text('No user session'))
              : StreamBuilder<UserModel?>(
                  stream: _fs.watchUser(uid),
                  builder: (context, snap) {
                    final user = snap.data;
                    return ListView(
                      children: [
                        Text(
                          'Settings',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.normal,
                                color: AppTheme.ink,
                              ),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () {
                            if (uid != null) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ProfileScreen(
                                    userId: uid,
                                    viewerUid: uid,
                                    editable: true,
                                  ),
                                ),
                              );
                            }
                          },
                          child: HoverCard(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(28),
                                color: Colors.white.withValues(alpha: 0.72),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 38,
                                    backgroundImage: (user?.profilePicture != null && user!.profilePicture.isNotEmpty)
                                        ? NetworkImage(user.profilePicture)
                                        : null,
                                    backgroundColor: AppTheme.violet.withValues(alpha: 0.18),
                                    child: (user?.profilePicture == null || user!.profilePicture.isEmpty)
                                        ? Text(
                                            (user?.name != null && user!.name.isNotEmpty)
                                                ? user.name[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              color: AppTheme.violet,
                                              fontWeight: FontWeight.w800,
                                              fontSize: 28,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          user?.name ?? 'Account',
                                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                color: AppTheme.ink,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          user?.email ?? '',
                                          style: TextStyle(
                                            color: AppTheme.ink.withValues(alpha: 0.6),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'MM ID: ',
                                              style: TextStyle(
                                                color: AppTheme.ink.withValues(alpha: 0.7),
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              user?.mmId ?? '',
                                              style: const TextStyle(
                                                color: AppTheme.violet,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            if (user?.mmId != null && user!.mmId.isNotEmpty) ...[
                                              const SizedBox(width: 6),
                                              GestureDetector(
                                                onTap: () {
                                                  Clipboard.setData(ClipboardData(text: user.mmId));
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('MM ID copied to clipboard!')),
                                                  );
                                                },
                                                child: const Icon(
                                                  Icons.copy_rounded,
                                                  size: 14,
                                                  color: AppTheme.violet,
                                                ),
                                              ),
                                            ]
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _SettingsSection(
                          title: 'Account',
                          children: [
                            ListTile(
                              leading: const Icon(Icons.people_alt_rounded, color: AppTheme.violet),
                              title: const Text('Connections'),
                              subtitle: const Text('View your accepted contacts'),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const ConnectionsScreen()),
                                );
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.pending_actions_rounded, color: AppTheme.pink),
                              title: const Text('Requests'),
                              subtitle: const Text('Open pending and sent requests'),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const RequestsScreen()),
                                );
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.photo_library_rounded, color: AppTheme.sky),
                              title: const Text('My photos'),
                              subtitle: const Text('Open your saved photo gallery'),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const PhotosScreen()),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _SettingsSection(
                          title: 'Preferences',
                          children: [
                            SwitchListTile(
                              value: user?.notificationsEnabled ?? true,
                              onChanged: uid == null
                                  ? null
                                  : (value) async {
                                      await _setPref(uid, 'notificationsEnabled', value);
                                      if (value) {
                                        await NotificationService().requestPermissionAndSaveToken();
                                      } else {
                                        await _fs.updateUser(uid, {'fcmToken': FieldValue.delete()});
                                      }
                                    },
                              title: const Text('Notifications'),
                              subtitle: const Text('Receive app alerts and updates'),
                              activeColor: AppTheme.violet,
                            ),
                            SwitchListTile(
                              value: user?.autoUpdate ?? true,
                              onChanged: uid == null
                                  ? null
                                  : (value) {
                                      _setPref(uid, 'autoUpdate', value);
                                    },
                              title: const Text('Auto update'),
                              subtitle: const Text('Keep your app data in sync automatically'),
                              activeColor: AppTheme.pink,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _SettingsSection(
                          title: 'Privacy',
                          children: [
                            ListTile(
                              leading: const Icon(Icons.privacy_tip_rounded, color: AppTheme.violet),
                              title: const Text('Privacy Settings'),
                              subtitle: const Text('Manage your account privacy and security locks'),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const PrivacySettingsScreen()),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        HoverActionButton(
                          label: 'Log out',
                          icon: Icons.logout_rounded,
                          colors: const [Color(0xFFFF6F91), Color(0xFFFF8A65)],
                          onPressed: _logout,
                        ),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class PatternSetupDialog extends StatefulWidget {
  final ValueChanged<String> onSaved;
  const PatternSetupDialog({super.key, required this.onSaved});

  @override
  State<PatternSetupDialog> createState() => PatternSetupDialogState();
}

class PatternSetupDialogState extends State<PatternSetupDialog> {
  final List<int> _selectedIndices = [];

  void _onDotTap(int index) {
    if (_selectedIndices.contains(index)) return;
    setState(() {
      _selectedIndices.add(index);
    });
  }

  void _clear() {
    setState(() {
      _selectedIndices.clear();
    });
  }

  void _save() {
    if (_selectedIndices.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pattern must connect at least 3 dots.')),
      );
      return;
    }
    final pattern = _selectedIndices.join('');
    widget.onSaved(pattern);
    Navigator.pop(context);
  }

  void _checkPosition(Offset localPos) {
    final x = localPos.dx;
    final y = localPos.dy;
    if (x >= 0 && x <= 200 && y >= 0 && y <= 200) {
      final col = (x / (200 / 3)).floor().clamp(0, 2);
      final row = (y / (200 / 3)).floor().clamp(0, 2);
      final idx = row * 3 + col;
      _onDotTap(idx);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Setup Lock Pattern', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.ink)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Tap or drag the dots in sequence to create your pattern.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 20),
          GestureDetector(
            onPanStart: (details) => _checkPosition(details.localPosition),
            onPanUpdate: (details) => _checkPosition(details.localPosition),
            child: SizedBox(
              width: 200,
              height: 200,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 9,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                ),
                itemBuilder: (context, idx) {
                  final isSelected = _selectedIndices.contains(idx);
                  final selectionOrder = _selectedIndices.indexOf(idx) + 1;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? AppTheme.pink.withValues(alpha: 0.15) : Colors.white,
                      border: Border.all(
                        color: isSelected ? AppTheme.pink : Colors.grey.shade300,
                        width: isSelected ? 3 : 1.5,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: AppTheme.pink.withValues(alpha: 0.3), blurRadius: 8)]
                          : null,
                    ),
                    child: Center(
                      child: isSelected
                          ? Text(
                              '$selectionOrder',
                              style: const TextStyle(color: AppTheme.pink, fontWeight: FontWeight.bold, fontSize: 16),
                            )
                          : Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey.shade400)),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _clear,
          child: const Text('Clear'),
        ),
        TextButton(
          onPressed: _save,
          child: const Text('Save', style: TextStyle(color: AppTheme.pink, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: Colors.white.withValues(alpha: 0.72),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.normal,
                      color: AppTheme.ink,
                    ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}
