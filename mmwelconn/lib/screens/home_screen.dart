import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mmwelconn/models/chat_model.dart';
import 'package:mmwelconn/models/mood_model.dart';
import 'package:mmwelconn/models/user_model.dart';
import 'package:mmwelconn/screens/chats_screen.dart';
import 'package:mmwelconn/screens/connections_screen.dart';
import 'package:mmwelconn/screens/photos_screen.dart';
import 'package:mmwelconn/screens/settings_screen.dart';
import 'package:mmwelconn/screens/profile_screen.dart';
import 'package:mmwelconn/screens/chat_detail_screen.dart';
import 'package:mmwelconn/services/cloudinary_service.dart';
import 'package:mmwelconn/services/firestore_service.dart';
import 'package:mmwelconn/services/notification_service.dart';
import 'package:mmwelconn/widgets/app_brand.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final FirestoreService _fs = FirestoreService();
  StreamSubscription<List<ChatModel>>? _chatsSub;
  final Map<String, DateTime> _lastSeenMessageTimes = {};

  void _goToTab(int index) => setState(() => _selectedIndex = index);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _fs.getUser(uid).then((userDoc) {
        if (userDoc != null) {
          final isOnline = userDoc.showOnline;
          _fs.setUserStatus(uid, isOnline ? 'online' : 'offline');
        }
      });

      _chatsSub = _fs.watchMyChats(uid).listen((chats) {
        for (var chat in chats) {
          if (chat.lastMessage != null && chat.lastSenderId != uid) {
            _fs.markMessagesAsDelivered(chat.id, uid);

            final chatId = chat.id;
            final lastTime = chat.lastMessageAt;
            if (lastTime != null) {
              final prevTime = _lastSeenMessageTimes[chatId];
              if (prevTime != null && lastTime.isAfter(prevTime)) {
                if (chatId != ChatDetailScreen.activeChatId) {
                  final senderName = chat.participantNames[chat.lastSenderId] ?? 'Someone';
                  final messageText = (chat.lastMessage != null && chat.lastMessage!.isNotEmpty)
                      ? chat.lastMessage!
                      : 'Sent an image 📷';
                  NotificationService().show(InAppNotification(
                    title: senderName,
                    body: messageText,
                    type: NotifType.newMessage,
                  ));
                }
              }
              _lastSeenMessageTimes[chatId] = lastTime;
            }
          }
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _chatsSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    
    if (state == AppLifecycleState.resumed) {
      _fs.getUser(uid).then((userDoc) {
        if (userDoc != null && userDoc.showOnline) {
          _fs.setUserStatus(uid, 'online');
        }
      });
    } else {
      _fs.setUserStatus(uid, 'offline');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomePage(onGoToChats: () => _goToTab(1), onGoToContacts: () => _goToTab(2)),
      const ChatsScreen(),
      const ConnectionsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Colors.white.withValues(alpha: 0.78),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _goToTab,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppTheme.violet,
          unselectedItemColor: AppTheme.ink.withValues(alpha: 0.52),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.chat_rounded), label: 'Chats'),
            BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: 'Contacts'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}

// ── Home tab ──────────────────────────────────────────────────────────────────

class _HomePage extends StatefulWidget {
  final VoidCallback onGoToChats;
  final VoidCallback onGoToContacts;

  const _HomePage({required this.onGoToChats, required this.onGoToContacts});

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  final FirestoreService _fs = FirestoreService();
  UserModel? _userModel;
  StreamSubscription<UserModel?>? _userSub;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _userSub = _fs.watchUser(uid).listen((user) {
        if (mounted) setState(() => _userModel = user);
      });
    }
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }

  Future<void> _setStatus(bool online) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _fs.setShowOnline(uid, online);
  }

  void _showMoodSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _MoodSheet(userModel: _userModel),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _userModel?.name ?? '...';
    return SoftGlowBackground(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool desktop = constraints.maxWidth > 900;
            return Center(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 140),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: desktop ? 56 : 20,
                      vertical: 24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _TopHero(
                          displayName: displayName,
                          userModel: _userModel,
                          onStatusChanged: _setStatus,
                        ),
                        const SizedBox(height: 26),
                        _StatsRow(userModel: _userModel),
                        const SizedBox(height: 26),
                        _QuickActions(
                          onStartChat: widget.onGoToChats,
                          onOpenMood: _showMoodSheet,
                          onOpenPhotos: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const PhotosScreen()),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Top hero ──────────────────────────────────────────────────────────────────

class _TopHero extends StatelessWidget {
  final String displayName;
  final UserModel? userModel;
  final ValueChanged<bool> onStatusChanged;

  const _TopHero({required this.displayName, required this.userModel, required this.onStatusChanged});

  @override
  Widget build(BuildContext context) {
    final isOnline = userModel?.showOnline ?? true;
    return HoverCard(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          color: Colors.white.withValues(alpha: 0.68),
          border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid == null) return;
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
              child: Row(
                children: [
                  Stack(
                    children: [
                      const BrandLogo(size: 92),
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: isOnline ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MMWELCONN',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: AppTheme.ink,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'A calm social space for mood, chat, and connection.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.ink.withValues(alpha: 0.66),
                              ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'MM ID: ',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.ink.withValues(alpha: 0.58),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            Text(
                              userModel?.mmId ?? '...',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppTheme.violet,
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            if (userModel?.mmId != null && userModel!.mmId.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: userModel!.mmId));
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
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Welcome back, $displayName 👋',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.ink,
                        ),
                  ),
                ),
                Switch.adaptive(
                  value: isOnline,
                  onChanged: onStatusChanged,
                  activeColor: AppTheme.violet,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOnline
                        ? Colors.green.withValues(alpha: 0.12)
                        : Colors.grey.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isOnline ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isOnline ? Colors.green : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Everything feels smoother from here. Send a mood, start a conversation, or invite someone new.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.ink.withValues(alpha: 0.68),
                    height: 1.45,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final UserModel? userModel;
  const _StatsRow({required this.userModel});

  @override
  Widget build(BuildContext context) {
    final tiles = [
      ('Status', (userModel?.status ?? 'online').toUpperCase(), AppTheme.sky, Icons.circle),
    ];

    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: tiles.map((tile) => HoverCard(
        child: Container(
          width: 160,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: Colors.white.withValues(alpha: 0.7),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(tile.$4, color: tile.$3),
              const SizedBox(height: 18),
              Text(tile.$1,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.ink.withValues(alpha: 0.62),
                      )),
              const SizedBox(height: 6),
              Text(tile.$2,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppTheme.ink,
                        fontSize: 18,
                      )),
            ],
          ),
        ),
      )).toList(),
    );
  }
}

// ── Quick actions ─────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  final VoidCallback onStartChat;
  final VoidCallback onOpenMood;
  final VoidCallback onOpenPhotos;

  const _QuickActions({
    required this.onStartChat,
    required this.onOpenMood,
    required this.onOpenPhotos,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Quick Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                  )),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ActionCard(
                  icon: Icons.chat_rounded,
                  label: 'New Chat',
                  color: AppTheme.sky,
                  onTap: onStartChat,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionCard(
                  icon: Icons.favorite_rounded,
                  label: 'Current Mood',
                  color: AppTheme.pink,
                  onTap: onOpenMood,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionCard(
                  icon: Icons.photo_library_rounded,
                  label: 'My Photos',
                  color: AppTheme.violet,
                  onTap: onOpenPhotos,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink.withValues(alpha: 0.75))),
          ],
        ),
      ),
    );
  }
}

// ── Mood bottom sheet ─────────────────────────────────────────────────────────

class _MoodSheet extends StatefulWidget {
  final UserModel? userModel;
  const _MoodSheet({required this.userModel});

  @override
  State<_MoodSheet> createState() => _MoodSheetState();
}

class _MoodSheetState extends State<_MoodSheet> {
  final FirestoreService _fs = FirestoreService();
  final TextEditingController _noteCtrl = TextEditingController();
  String? _selectedEmoji;
  String? _selectedLabel;
  bool _isPublic = true;
  bool _posting = false;

  static const _moods = [
    ('😊', 'Happy'),
    ('😔', 'Sad'),
    ('😌', 'Calm'),
    ('😤', 'Frustrated'),
    ('🥳', 'Excited'),
    ('😴', 'Tired'),
    ('🤩', 'Inspired'),
    ('😰', 'Anxious'),
  ];

  Future<void> _post() async {
    if (_selectedEmoji == null) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _posting = true);
    try {
      await _fs.postMood(MoodModel(
        id: '',
        userId: uid,
        userDisplayName: widget.userModel?.name ?? '',
        userPhotoUrl: widget.userModel?.profilePicture ?? '',
        emoji: _selectedEmoji!,
        label: _selectedLabel!,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        isPublic: _isPublic,
        createdAt: DateTime.now(),
      ));
      await _fs.setCurrentMood(uid, _selectedLabel!);
      if (!mounted) return;
      final emoji = _selectedEmoji;
      final label = _selectedLabel;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mood shared: $emoji $label ✓'),
          backgroundColor: AppTheme.violet,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _posting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share mood: $e')),
      );
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
            const Text('How are you feeling?',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: AppTheme.ink)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _moods.map((m) {
                final selected = _selectedEmoji == m.$1;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedEmoji = m.$1;
                    _selectedLabel = m.$2;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.violet.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: selected
                              ? AppTheme.violet
                              : Colors.transparent,
                          width: 2),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(m.$1, style: const TextStyle(fontSize: 20)),
                      const SizedBox(width: 6),
                      Text(m.$2,
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: selected
                                  ? AppTheme.violet
                                  : AppTheme.ink.withValues(alpha: 0.7))),
                    ]),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Add a note (optional)...',
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.9),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Switch(
                  value: _isPublic,
                  onChanged: (v) => setState(() => _isPublic = v),
                  activeThumbColor: AppTheme.violet,
                ),
                const SizedBox(width: 8),
                Text(_isPublic ? 'Visible to everyone' : 'Only me',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.ink.withValues(alpha: 0.6))),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _selectedEmoji == null || _posting ? null : _post,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.violet,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppTheme.violet.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
              child: Text(_posting ? 'Sharing...' : 'Share Mood',
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}
