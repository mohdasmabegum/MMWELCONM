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

  void _confirmAccountDeletion(String uid) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Schedule Deletion? ⚠️', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Are you sure you want to delete your account? It will take 24 hours to completely remove your profile from the cloud. You can log back in within 24 hours to cancel this process.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _fs.updateUser(uid, {
                'deletionScheduledAt': Timestamp.fromDate(DateTime.now()),
              });
              await _auth.logout();
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
            child: const Text('Delete Account', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _linkParent(String uid, String parentMmId) async {
    final parentMmIdClean = parentMmId.trim().toUpperCase();
    if (parentMmIdClean.isEmpty) return;

    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('mmId', isEqualTo: parentMmIdClean)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parent MM ID not found!')),
        );
      }
      return;
    }

    final parentDoc = snap.docs.first;
    if (parentDoc.id == uid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You cannot link to your own account!')),
        );
      }
      return;
    }

    await _fs.updateUser(uid, {'parentId': parentDoc.id});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Linked to Parent successfully! 🎉')),
      );
    }
  }

  Future<void> _unlinkParent(String uid) async {
    await _fs.updateUser(uid, {
      'parentId': '',
      'kidsModeLocked': false,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unlinked from Parent.')),
      );
    }
  }

  void _showLinkParentDialog(String childUid) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Link Parent Account 🔗', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter your parent\'s MM ID below to link accounts:'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'e.g. MM123456',
                border: OutlineInputBorder(),
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
            onPressed: () async {
              final mmId = ctrl.text.trim();
              Navigator.pop(context);
              await _linkParent(childUid, mmId);
            },
            child: const Text('Link Account', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _manageChildrenSheet(String parentUid) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '👶 Managed Child Accounts',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.ink),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'View and configure linked kids account settings including limits and safety locks.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .where('parentId', isEqualTo: parentUid)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final docs = snapshot.data?.docs ?? [];
                        if (docs.isEmpty) {
                          return const Center(
                            child: Text(
                              'No children linked yet.\nHave your child enter your MM ID in their settings.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black38, fontSize: 13),
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final childDoc = docs[index];
                            final childData = childDoc.data() as Map<String, dynamic>;
                            final childUid = childDoc.id;
                            final childName = childData['name'] ?? 'Child';
                            final childMmId = childData['mmId'] ?? '';
                            final double limitHours = (childData['kidsScreenTimeLimitHours'] as num?)?.toDouble() ?? 1.0;
                            final int bedtime = childData['kidsBedtimeHour'] ?? 20;
                            final bool isLocked = childData['kidsModeLocked'] ?? false;
                            final childMood = childData['currentMoodId'] ?? 'N/A';

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blue.shade100,
                                    child: const Text('👶'),
                                  ),
                                  title: Text(childName, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  subtitle: Text('MM ID: $childMmId | Mood: $childMood'),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.link_off_rounded, color: Colors.red),
                                    onPressed: () async {
                                      await FirebaseFirestore.instance
                                          .collection('users')
                                          .doc(childUid)
                                          .update({'parentId': '', 'kidsModeLocked': false});
                                    },
                                  ),
                                ),
                                SwitchListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Lock settings for this child', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  subtitle: const Text('Prevents child from changing their mode or settings.', style: TextStyle(fontSize: 10)),
                                  value: isLocked,
                                  onChanged: (val) async {
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(childUid)
                                        .update({'kidsModeLocked': val});
                                    setSheetState(() {});
                                  },
                                ),
                                const SizedBox(height: 8),
                                Text('Screen Time Limit: ${limitHours} hours', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                Slider(
                                  value: limitHours,
                                  min: 0.5,
                                  max: 4.0,
                                  divisions: 7,
                                  onChanged: (val) async {
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(childUid)
                                        .update({'kidsScreenTimeLimitHours': val});
                                    setSheetState(() {});
                                  },
                                ),
                                Text(
                                  'Bedtime Lock: ${bedtime % 12 == 0 ? 12 : bedtime % 12} ${bedtime >= 12 ? 'PM' : 'AM'}',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                Slider(
                                  value: bedtime.toDouble(),
                                  min: 17, // 5 PM
                                  max: 23, // 11 PM
                                  divisions: 6,
                                  onChanged: (val) async {
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(childUid)
                                        .update({'kidsBedtimeHour': val.toInt()});
                                    setSheetState(() {});
                                  },
                                ),
                                const SizedBox(height: 12),
                                const Text('Pending Friend Requests:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(childUid)
                                      .collection('contacts')
                                      .where('status', isEqualTo: 'pending')
                                      .where('direction', isEqualTo: 'incoming')
                                      .snapshots(),
                                  builder: (context, contactsSnap) {
                                    final reqs = contactsSnap.data?.docs ?? [];
                                    if (reqs.isEmpty) {
                                      return const Text('No pending requests for this child.', style: TextStyle(fontSize: 10, color: Colors.black38));
                                    }
                                    return Column(
                                      children: reqs.map((rDoc) {
                                        final rData = rDoc.data() as Map<String, dynamic>;
                                        final contactUid = rDoc.id;
                                        final contactName = rData['contactName'] ?? 'Someone';
                                        return ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          dense: true,
                                          title: Text(contactName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                          subtitle: const Text('Wants to connect with child', style: TextStyle(fontSize: 10)),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                                onPressed: () async {
                                                  await _fs.acceptContact(childUid, contactUid);
                                                },
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.cancel, color: Colors.red, size: 20),
                                                onPressed: () async {
                                                  await _fs.declineContact(childUid, contactUid);
                                                },
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                const Text('Child Sent Requests Pending Approval:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(childUid)
                                      .collection('contacts')
                                      .where('status', isEqualTo: 'pending_parent')
                                      .where('direction', isEqualTo: 'outgoing')
                                      .snapshots(),
                                  builder: (context, contactsSnap) {
                                    final reqs = contactsSnap.data?.docs ?? [];
                                    if (reqs.isEmpty) {
                                      return const Text('No outgoing requests waiting for approval.', style: TextStyle(fontSize: 10, color: Colors.black38));
                                    }
                                    return Column(
                                      children: reqs.map((rDoc) {
                                        final rData = rDoc.data() as Map<String, dynamic>;
                                        final contactUid = rDoc.id;
                                        final contactName = rData['contactName'] ?? 'Someone';
                                        return ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          dense: true,
                                          title: Text(contactName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                          subtitle: const Text('Child wants to connect', style: TextStyle(fontSize: 10)),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                icon: const Icon(Icons.check_circle, color: Colors.green, size: 20),
                                                onPressed: () async {
                                                  await _fs.approveChildOutgoingRequest(childUid, contactUid);
                                                },
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.cancel, color: Colors.red, size: 20),
                                                onPressed: () async {
                                                  await _fs.declineContact(childUid, contactUid);
                                                },
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    );
                                  },
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
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
                                color: AppTheme.vibe.textColor,
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
                                color: AppTheme.vibe.cardColor,
                                border: Border.all(color: AppTheme.vibe.borderColor.withValues(alpha: 0.35)),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 38,
                                    backgroundImage: (user?.profilePicture != null && user!.profilePicture.isNotEmpty)
                                        ? NetworkImage(user.profilePicture)
                                        : null,
                                    backgroundColor: AppTheme.vibe.primaryColor.withValues(alpha: 0.18),
                                    child: (user?.profilePicture == null || user!.profilePicture.isEmpty)
                                        ? Text(
                                            (user?.name != null && user!.name.isNotEmpty)
                                                ? user.name[0].toUpperCase()
                                                : '?',
                                            style: TextStyle(
                                              color: AppTheme.vibe.primaryColor,
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
                                                color: AppTheme.vibe.textColor,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          user?.email ?? '',
                                          style: TextStyle(
                                            color: AppTheme.vibe.textColor.withValues(alpha: 0.7),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'MM ID: ',
                                              style: TextStyle(
                                                color: AppTheme.vibe.textColor.withValues(alpha: 0.6),
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            Text(
                                              user?.mmId ?? '',
                                              style: TextStyle(
                                                color: AppTheme.vibe.primaryColor,
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
                                        const SizedBox(height: 10),
                                        Row(
                                          children: [
                                            Text('🔥 Streak: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.vibe.textColor)),
                                            Text('${user?.streakCount ?? 0} Days', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 13)),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        if (user?.badges != null && user!.badges.isNotEmpty) ...[
                                          Text('🏆 Badges:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.vibe.textColor.withValues(alpha: 0.6))),
                                          const SizedBox(height: 4),
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            children: user!.badges.map((b) => Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: AppTheme.vibe.primaryColor.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(b, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.vibe.textColor)),
                                            )).toList(),
                                          )
                                        ],
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
                            if ((user?.ageGroup ?? 'teen') == 'kid') ...[
                              ListTile(
                                leading: const Icon(Icons.supervisor_account_rounded, color: Colors.blue),
                                title: const Text('Parent Link'),
                                subtitle: Text(user!.parentId.isNotEmpty ? 'Linked to parent account' : 'Link parent using MM ID'),
                                trailing: user.kidsModeLocked
                                    ? const Icon(Icons.lock, color: Colors.orange, size: 18)
                                    : (user.parentId.isNotEmpty ? const Icon(Icons.link_off, color: Colors.red) : const Icon(Icons.link)),
                                onTap: user.kidsModeLocked
                                    ? null
                                    : () {
                                        if (user.parentId.isNotEmpty) {
                                          _unlinkParent(uid!);
                                        } else {
                                          _showLinkParentDialog(uid!);
                                        }
                                      },
                              ),
                            ],
                            if ((user?.ageGroup ?? 'teen') == 'adult') ...[
                              ListTile(
                                leading: const Icon(Icons.child_care_rounded, color: Colors.purple),
                                title: const Text('Manage Kids Accounts'),
                                subtitle: const Text('Configure limits and settings for child accounts'),
                                trailing: const Icon(Icons.chevron_right_rounded),
                                onTap: () => _manageChildrenSheet(uid!),
                              ),
                            ],
                            ListTile(
                              leading: const Icon(Icons.delete_forever, color: Colors.red),
                              title: const Text('Delete Account', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                              subtitle: const Text('Schedule account for deletion in 24 hours'),
                              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.red),
                              onTap: () {
                                _confirmAccountDeletion(uid);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _SettingsSection(
                          title: 'Vibe & Themes',
                          children: [
                            ListTile(
                              leading: Icon(
                                (user?.ageGroup ?? 'teen') == 'teen'
                                    ? Icons.bolt_rounded
                                    : (user?.ageGroup == 'kid'
                                        ? Icons.bubble_chart_rounded
                                        : (user?.ageGroup == 'elder'
                                            ? Icons.health_and_safety_rounded
                                            : (user?.ageGroup == 'professional'
                                                ? Icons.business_center_rounded
                                                : Icons.badge_rounded))),
                                color: AppTheme.vibe.primaryColor,
                              ),
                              title: const Text('Age Group Vibe'),
                              subtitle: Text(
                                (user?.kidsModeLocked ?? false)
                                    ? 'Locked by Parent 🔒'
                                    : ((user?.ageGroup ?? 'teen') == 'teen'
                                        ? 'Teens (13-19) - Neon & Focus'
                                        : (user?.ageGroup == 'kid'
                                            ? 'Kids (5-12) - Playful & Safe'
                                            : (user?.ageGroup == 'elder'
                                                ? 'Elders (55+) - Large & Clear'
                                                : (user?.ageGroup == 'professional'
                                                    ? 'Professional Mode - Neat & Admin'
                                                    : 'Adults (20-55) - Work & Family')))),
                              ),
                              trailing: DropdownButton<String>(
                                value: user?.ageGroup ?? 'teen',
                                underline: const SizedBox(),
                                dropdownColor: Colors.white,
                                style: const TextStyle(color: AppTheme.ink, fontWeight: FontWeight.bold, fontSize: 13),
                                items: const [
                                  DropdownMenuItem(value: 'kid', child: Text('Kids (5-12)')),
                                  DropdownMenuItem(value: 'teen', child: Text('Teens (13-19)')),
                                  DropdownMenuItem(value: 'adult', child: Text('Adults (20-55)')),
                                  DropdownMenuItem(value: 'elder', child: Text('Elders (55+)')),
                                  DropdownMenuItem(value: 'professional', child: Text('Professional')),
                                ],
                                onChanged: (uid == null || (user?.kidsModeLocked ?? false))
                                    ? null
                                    : (val) async {
                                        if (val != null) {
                                          final defaultTheme = val == 'kid'
                                              ? 'bubblegum'
                                              : (val == 'teen'
                                                  ? 'neon'
                                                  : (val == 'elder' ? 'cream' : 'slate'));
                                          await _fs.updateUser(uid, {
                                            'ageGroup': val,
                                            'customTheme': defaultTheme,
                                            if (val == 'elder') 'fontSizeScale': 1.4 else 'fontSizeScale': 1.0,
                                            if (val == 'elder') 'highContrastEnabled': false,
                                          });
                                          AppTheme.updateVibe(val, defaultTheme);
                                          AppTheme.fontSizeFactor.value = val == 'elder' ? 1.4 : 1.0;
                                          AppTheme.highContrast.value = false;
                                          HapticFeedback.mediumImpact();
                                        }
                                      },
                              ),
                            ),
                            ListTile(
                              leading: const Icon(Icons.palette_outlined, color: AppTheme.pink),
                              title: const Text('Sub-Theme Color'),
                              subtitle: Text('Current: ${(user?.customTheme != null && user!.customTheme.isNotEmpty) ? user.customTheme.toUpperCase() : "DEFAULT"}'),
                              trailing: DropdownButton<String>(
                                value: (user?.customTheme != null && user!.customTheme.isNotEmpty)
                                    ? user.customTheme
                                    : ((user?.ageGroup ?? 'teen') == 'teen'
                                        ? 'neon'
                                        : ((user?.ageGroup ?? 'teen') == 'kid'
                                            ? 'bubblegum'
                                            : ((user?.ageGroup ?? 'teen') == 'elder' ? 'cream' : 'slate'))),
                                underline: const SizedBox(),
                                dropdownColor: Colors.white,
                                style: const TextStyle(color: AppTheme.ink, fontWeight: FontWeight.bold, fontSize: 13),
                                items: (user?.ageGroup ?? 'teen') == 'teen'
                                    ? const [
                                        DropdownMenuItem(value: 'neon', child: Text('Neon Dream')),
                                        DropdownMenuItem(value: 'cyberpunk', child: Text('Cyberpunk')),
                                        DropdownMenuItem(value: 'pastel', child: Text('Pastel Cloud')),
                                      ]
                                    : ((user?.ageGroup ?? 'teen') == 'kid'
                                        ? const [
                                            DropdownMenuItem(value: 'bubblegum', child: Text('Bubblegum Pink')),
                                            DropdownMenuItem(value: 'forest', child: Text('Forest Green')),
                                          ]
                                        : ((user?.ageGroup ?? 'teen') == 'elder'
                                            ? const [
                                                DropdownMenuItem(value: 'cream', child: Text('Classic Cream')),
                                                DropdownMenuItem(value: 'high_contrast_dark', child: Text('High Contrast')),
                                                DropdownMenuItem(value: 'parchment', child: Text('Parchment Paper')),
                                              ]
                                            : const [
                                                DropdownMenuItem(value: 'slate', child: Text('Slate Professional')),
                                                DropdownMenuItem(value: 'navy_sage', child: Text('Navy & Sage')),
                                                DropdownMenuItem(value: 'warm_onyx', child: Text('Warm Onyx')),
                                              ])),
                                onChanged: uid == null
                                    ? null
                                    : (val) async {
                                        if (val != null) {
                                          final isHighContrast = val == 'high_contrast_dark';
                                          await _fs.updateUser(uid, {
                                            'customTheme': val,
                                            if (user?.ageGroup == 'elder') 'highContrastEnabled': isHighContrast,
                                          });
                                          AppTheme.updateVibe(user?.ageGroup ?? 'teen', val, forceHighContrast: isHighContrast);
                                          AppTheme.highContrast.value = isHighContrast;
                                          HapticFeedback.mediumImpact();
                                        }
                                      },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Text Size Scale: ${(AppTheme.fontSizeFactor.value * 100).toInt()}%',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.ink),
                                  ),
                                  Slider.adaptive(
                                    value: user?.fontSizeScale ?? 1.0,
                                    min: 1.0,
                                    max: 2.2,
                                    divisions: 6,
                                    activeColor: AppTheme.vibe.primaryColor,
                                    onChanged: (v) async {
                                      AppTheme.fontSizeFactor.value = v;
                                      await _fs.updateUser(uid!, {'fontSizeScale': v});
                                    },
                                  ),
                                  if ((user?.ageGroup ?? 'teen') == 'elder')
                                    SwitchListTile(
                                      title: const Text('High Contrast Screen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.ink)),
                                      value: user?.highContrastEnabled ?? false,
                                      activeColor: AppTheme.vibe.primaryColor,
                                      onChanged: (v) async {
                                        AppTheme.highContrast.value = v;
                                        final targetTheme = v ? 'high_contrast_dark' : 'cream';
                                        await _fs.updateUser(uid!, {
                                          'highContrastEnabled': v,
                                          'customTheme': targetTheme,
                                        });
                                        AppTheme.updateVibe('elder', targetTheme, forceHighContrast: v);
                                      },
                                    )
                                ],
                              ),
                            )
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
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          margin: const EdgeInsets.only(left: -20, right: -20, top: 24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF1E1E2E).withValues(alpha: 0.01),
                                const Color(0xFF7C3AED).withValues(alpha: 0.08),
                                const Color(0xFF1E1E2E).withValues(alpha: 0.01),
                              ],
                            ),
                            border: Border(
                              top: BorderSide(
                                color: const Color(0xFFC084FC).withValues(alpha: 0.15),
                                width: 1.0,
                              ),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '© ${DateTime.now().year} MMWelconm by MRA',
                                style: TextStyle(
                                  color: AppTheme.vibe.textColor.withValues(alpha: 0.65),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'All rights reserved.',
                                style: TextStyle(
                                  color: AppTheme.ink.withValues(alpha: 0.4),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
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
