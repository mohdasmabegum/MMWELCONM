import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mmwelconm/models/user_model.dart';
import 'package:mmwelconm/services/firestore_service.dart';
import 'package:mmwelconm/widgets/app_brand.dart';
import 'package:mmwelconm/screens/settings_screen.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final FirestoreService _fs = FirestoreService();
  bool _changingStatus = false;

  Future<void> _setShowOnline(String uid, bool showOnline) async {
    setState(() => _changingStatus = true);
    try {
      await _fs.setShowOnline(uid, showOnline);
    } finally {
      if (mounted) setState(() => _changingStatus = false);
    }
  }

  Future<void> _setPref(String uid, String key, dynamic value) async {
    await _fs.updateUser(uid, {key: value});
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

    return Scaffold(
      body: SoftGlowBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 20, 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.ink),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Privacy',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppTheme.ink,
                          ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: uid == null
                    ? const Center(child: Text('No user session'))
                    : StreamBuilder<UserModel?>(
                        stream: _fs.watchUser(uid),
                        builder: (context, snap) {
                          final user = snap.data;
                          if (user == null) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          return ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            children: [
                              // Account Privacy Card
                              Card(
                                elevation: 0,
                                color: Colors.white.withValues(alpha: 0.74),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                child: Theme(
                                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    leading: const Icon(Icons.account_circle_rounded, color: AppTheme.violet),
                                    title: const Text('Account Privacy', style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.ink)),
                                    subtitle: const Text('Online status and search profile visibility'),
                                    childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    children: [
                                      SwitchListTile(
                                        contentPadding: EdgeInsets.zero,
                                        value: user.showOnline,
                                        onChanged: _changingStatus
                                            ? null
                                            : (value) => _setShowOnline(uid, value),
                                        title: const Text('Manual online status'),
                                        subtitle: const Text('Change how others see you'),
                                        activeColor: AppTheme.violet,
                                      ),
                                      SwitchListTile(
                                        contentPadding: EdgeInsets.zero,
                                        value: user.publicProfileVisible,
                                        onChanged: (value) {
                                          _setPref(uid, 'publicProfileVisible', value);
                                        },
                                        title: const Text('Public Profile Visibility'),
                                        subtitle: const Text('Allow non-connections to see your profile in search'),
                                        activeColor: AppTheme.violet,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              // Locked Chats Privacy Card
                              Card(
                                elevation: 0,
                                color: Colors.white.withValues(alpha: 0.74),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                child: Theme(
                                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    leading: const Icon(Icons.lock_rounded, color: AppTheme.pink),
                                    title: const Text('Locked Chats Privacy', style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.ink)),
                                    subtitle: const Text('Manage chat lock passcode, pattern, and resets'),
                                    childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    children: [
                                      ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: const Icon(Icons.lock_outline_rounded, color: AppTheme.violet),
                                        title: const Text('Set Passcode PIN'),
                                        subtitle: const Text('Configure a 4-digit code to unlock chats'),
                                        trailing: const Icon(Icons.chevron_right_rounded),
                                        onTap: () => _changePasscodePin(uid),
                                      ),
                                      ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: const Icon(Icons.grid_3x3_rounded, color: AppTheme.pink),
                                        title: const Text('Set Lock Pattern'),
                                        subtitle: const Text('Configure a dot grid pattern to unlock chats'),
                                        trailing: const Icon(Icons.chevron_right_rounded),
                                        onTap: () => _changeLockPattern(uid),
                                      ),
                                      ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        leading: const Icon(Icons.lock_reset_rounded, color: Colors.grey),
                                        title: const Text('Reset Security Locks'),
                                        subtitle: const Text('Remove custom pattern and restore default PIN'),
                                        onTap: () => _resetSecurityLocks(uid),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
