import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mmwelconn/models/user_model.dart';
import 'package:mmwelconn/screens/connections_screen.dart';
import 'package:mmwelconn/screens/photos_screen.dart';
import 'package:mmwelconn/screens/requests_screen.dart';
import 'package:mmwelconn/screens/profile_screen.dart';
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
  bool _changingStatus = false;

  Future<void> _setPref(String uid, String key, bool value) {
    return _fs.updateUser(uid, {key: value});
  }

  Future<void> _logout() async {
    await _auth.logout();
  }

  Future<void> _setStatus(String uid, String status) async {
    setState(() => _changingStatus = true);
    try {
      await _fs.setUserStatus(uid, status);
    } finally {
      if (mounted) setState(() => _changingStatus = false);
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
                                fontWeight: FontWeight.w900,
                                color: AppTheme.ink,
                              ),
                        ),
                        const SizedBox(height: 16),
                        HoverCard(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              color: Colors.white.withValues(alpha: 0.72),
                            ),
                            child: Row(
                              children: [
                                const BrandLogo(size: 76),
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
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        _SettingsSection(
                          title: 'Account',
                          children: [
                            ListTile(
                              leading: const Icon(Icons.person_rounded, color: AppTheme.sky),
                              title: const Text('Preview profile'),
                              subtitle: const Text('Open your profile and edit your photo/status'),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ProfileScreen(
                                      userId: uid,
                                      viewerUid: uid,
                                      editable: true,
                                    ),
                                  ),
                                );
                              },
                            ),
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
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _SettingsSection(
                                SwitchListTile(
                                  value: user?.status == 'online',
                                  onChanged: _changingStatus || uid == null
                                      ? null
                                      : (value) => _setStatus(uid, value ? 'online' : 'offline'),
                                  title: const Text('Manual online status'),
                                  subtitle: const Text('Change how others see you'),
                                  activeColor: AppTheme.violet,
                                ),
                          title: 'Preferences',
                          children: [
                            SwitchListTile(
                              value: user?.notificationsEnabled ?? true,
                              onChanged: uid == null
                                  ? null
                                  : (value) {
                                      _setPref(uid, 'notificationsEnabled', value);
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
                        HoverActionButton(
                          label: 'Sign out',
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
                      fontWeight: FontWeight.w800,
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
