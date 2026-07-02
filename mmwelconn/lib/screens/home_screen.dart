import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:mmwelconn/models/chat_model.dart';
import 'package:mmwelconn/models/contact_model.dart';
import 'package:mmwelconn/models/mood_model.dart';
import 'package:mmwelconn/models/user_model.dart';
import 'package:mmwelconn/screens/chats_screen.dart';
import 'package:mmwelconn/screens/contacts_screen.dart';
import 'package:mmwelconn/screens/settings_screen.dart';
import 'package:mmwelconn/services/firestore_service.dart';
import 'package:mmwelconn/services/notification_service.dart';
import 'package:mmwelconn/widgets/app_brand.dart';

const String _appVersion = '1.2.2';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  final FirestoreService _fs = FirestoreService();
  StreamSubscription<List<ContactModel>>? _pendingSub;
  StreamSubscription<List<ContactModel>>? _acceptedSub;
  StreamSubscription<List<ChatModel>>? _chatsSub;
  Set<String> _knownPending = {};
  Set<String> _knownAccepted = {};
  Map<String, String?> _knownLastMsg = {};
  bool _initialPendingLoaded = false;
  bool _initialAcceptedLoaded = false;
  bool _initialChatsLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initFcm();
    _initNotificationListeners();
    _checkForUpdate();
  }

  Future<void> _checkForUpdate() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    // Wait a moment so the UI is fully loaded
    await Future.delayed(const Duration(seconds: 2));
    final versionData = await _fs.watchAppVersion().first;
    final latest = versionData['latest'] ?? _appVersion;
    final releaseNotes = versionData['releaseNotes'] ?? '';
    final releaseDate = versionData['releaseDate'] ?? '';
    if (latest != _appVersion) {
      final user = await _fs.getUser(uid);
      final autoUpdate = user?.autoUpdate ?? true;
      NotificationService().show(InAppNotification(
        title: autoUpdate ? 'Update Available 🚀 v$latest' : 'New Update v$latest',
        body: '${autoUpdate ? 'Auto-updating — ' : 'Tap to update — '}${releaseDate.isNotEmpty ? 'Released $releaseDate. ' : ''}$releaseNotes'.trim(),
        type: NotifType.welcome,
        onTap: () => setState(() => _selectedIndex = 3),
      ));
    }
  }

  void _initNotificationListeners() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final ns = NotificationService();

    // Listen for incoming contact requests
    _pendingSub = _fs
        .watchContacts(uid, status: ContactStatus.pending, direction: ContactDirection.incoming)
        .listen((contacts) {
      final ids = contacts.map((c) => c.contactUid).toSet();
      if (_initialPendingLoaded) {
        for (final c in contacts) {
          if (!_knownPending.contains(c.contactUid)) {
            ns.show(InAppNotification(
              title: 'New Connection Request',
              body: '${c.contactName} wants to connect with you',
              type: NotifType.newRequest,
              onTap: () => setState(() => _selectedIndex = 2),
            ));
          }
        }
      }
      _knownPending = ids;
      _initialPendingLoaded = true;
    });

    // Listen for accepted connections
    _acceptedSub = _fs
        .watchContacts(uid, status: ContactStatus.accepted)
        .listen((contacts) {
      final ids = contacts.map((c) => c.contactUid).toSet();
      if (_initialAcceptedLoaded) {
        for (final c in contacts) {
          if (!_knownAccepted.contains(c.contactUid)) {
            ns.show(InAppNotification(
              title: 'Connection Accepted! 🎉',
              body: '${c.contactName} accepted your connection request',
              type: NotifType.accepted,
              onTap: () => setState(() => _selectedIndex = 1),
            ));
          }
        }
      }
      _knownAccepted = ids;
      _initialAcceptedLoaded = true;
    });

    // Listen for new messages
    _chatsSub = _fs.watchMyChats(uid).listen((chats) {
      if (_initialChatsLoaded) {
        for (final chat in chats) {
          final prev = _knownLastMsg[chat.id];
          final curr = chat.lastMessage;
          final isNewMsg = curr != null && curr != prev;
          final notFromMe = chat.lastSenderId != uid && chat.lastSenderId != null;
          if (isNewMsg && notFromMe) {
            final senderName = chat.participantNames.entries
                .firstWhere((e) => e.key != uid, orElse: () => const MapEntry('', 'Someone'))
                .value;
            ns.show(InAppNotification(
              title: 'New Message from $senderName',
              body: curr,
              type: NotifType.newMessage,
              onTap: () => setState(() => _selectedIndex = 1),
            ));
          }
        }
      }
      _knownLastMsg = {for (final c in chats) c.id: c.lastMessage};
      _initialChatsLoaded = true;
    });
  }

  Future<void> _initFcm() async {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission();
    final token = await messaging.getToken();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && token != null) {
      await FirestoreService().updateUser(uid, {'fcmToken': token});
    }
    // Refresh token when it changes
    messaging.onTokenRefresh.listen((newToken) async {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirestoreService().updateUser(uid, {'fcmToken': newToken});
      }
    });
    // Show in-app popup for foreground FCM messages (fallback for push)
    FirebaseMessaging.onMessage.listen((message) {
      if (!mounted) return;
      final title = message.notification?.title ?? '';
      final body = message.notification?.body ?? '';
      if (title.isEmpty && body.isEmpty) return;
      NotificationService().show(InAppNotification(
        title: title,
        body: body,
        type: NotifType.newMessage,
      ));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pendingSub?.cancel();
    _acceptedSub?.cancel();
    _chatsSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final fs = FirestoreService();
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      fs.setUserStatus(uid, 'offline');
    } else if (state == AppLifecycleState.resumed) {
      fs.setUserStatus(uid, 'online');
    }
  }

  void _goToTab(int index) => setState(() => _selectedIndex = index);

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomePage(onGoToChats: () => _goToTab(1), onGoToContacts: () => _goToTab(2)),
      const ChatsScreen(),
      const ContactsScreen(),
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
            BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: 'Connections'),
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

  Future<void> _toggleStatus(bool isOnline) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirestoreService().setUserStatus(uid, isOnline ? 'online' : 'offline');
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
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _TopHero(displayName: displayName, userModel: _userModel),
                        const SizedBox(height: 26),
                        _StatsRow(
                          userModel: _userModel,
                          onToggleStatus: _toggleStatus,
                        ),
                        const SizedBox(height: 26),
                        _QuickActions(
                          onStartChat: widget.onGoToChats,
                          onAddContact: widget.onGoToContacts,
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

  const _TopHero({required this.displayName, required this.userModel});

  @override
  Widget build(BuildContext context) {
    final isOnline = userModel?.status == 'online';
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
            Row(
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
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back, $displayName 👋',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.ink,
                            ),
                      ),
                      if (userModel?.mmId.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.violet.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.violet.withValues(alpha: 0.25)),
                          ),
                          child: Text(
                            'ID: ${userModel!.mmId}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.violet,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
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

class _StatsRow extends StatefulWidget {
  final UserModel? userModel;
  final ValueChanged<bool> onToggleStatus;

  const _StatsRow({
    required this.userModel,
    required this.onToggleStatus,
  });

  @override
  State<_StatsRow> createState() => _StatsRowState();
}

class _StatsRowState extends State<_StatsRow> {
  final FirestoreService _fs = FirestoreService();
  MoodModel? _currentMood;
  StreamSubscription<MoodModel?>? _moodSub;
  String? _watchedMoodId;

  void _subscribeMood(String? moodId) {
    if (moodId == _watchedMoodId) return;
    _moodSub?.cancel();
    _watchedMoodId = moodId;
    if (moodId != null) {
      _moodSub = _fs.watchMoodById(moodId).listen((m) {
        if (!mounted) return;
        // Auto-clear mood if older than 24 hours
        if (m != null && DateTime.now().difference(m.createdAt).inHours >= 24) {
          final uid = widget.userModel?.uid;
          if (uid != null) _fs.clearCurrentMood(uid);
          setState(() => _currentMood = null);
        } else {
          setState(() => _currentMood = m);
        }
      });
    } else {
      if (mounted) setState(() => _currentMood = null);
    }
  }

  @override
  void initState() {
    super.initState();
    _subscribeMood(widget.userModel?.currentMoodId);
  }

  @override
  void didUpdateWidget(_StatsRow old) {
    super.didUpdateWidget(old);
    _subscribeMood(widget.userModel?.currentMoodId);
  }

  bool _moodExpanded = false;
  String? _pendingEmoji;
  String? _pendingLabel;
  bool _posting = false;

  static const _moods = [
    ('😊', 'Happy'), ('😔', 'Sad'), ('😌', 'Calm'), ('😤', 'Frustrated'),
    ('🥳', 'Excited'), ('😴', 'Tired'), ('🤩', 'Inspired'), ('😰', 'Anxious'),
  ];

  Future<void> _postMood() async {
    if (_pendingEmoji == null) return;
    final uid = widget.userModel?.uid;
    if (uid == null) return;
    setState(() => _posting = true);
    try {
      final moodId = await _fs.postMood(MoodModel(
        id: '',
        userId: uid,
        userDisplayName: widget.userModel?.name ?? '',
        userPhotoUrl: widget.userModel?.profilePicture ?? '',
        emoji: _pendingEmoji!,
        label: _pendingLabel!,
        isPublic: true,
        createdAt: DateTime.now(),
      ));
      await _fs.updateUser(uid, {'currentMoodId': moodId});
      if (!mounted) return;
      setState(() { _moodExpanded = false; _pendingEmoji = null; _pendingLabel = null; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mood updated ✓'), backgroundColor: AppTheme.violet),
      );
    } catch (_) {
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  void dispose() {
    _moodSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = widget.userModel?.status == 'online';
    final moodDisplay = _currentMood != null
        ? '${_currentMood!.emoji} ${_currentMood!.label}'
        : widget.userModel?.currentMoodId != null ? '...' : 'None';

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 14,
            alignment: WrapAlignment.center,
            children: [
              // Status tile with toggle
              HoverCard(
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(Icons.circle, color: isOnline ? Colors.green : Colors.grey, size: 20),
                          Transform.scale(
                            scale: 0.75,
                            child: Switch(
                              value: isOnline,
                              onChanged: widget.userModel != null ? widget.onToggleStatus : null,
                              activeThumbColor: Colors.green,
                              activeTrackColor: Colors.green.withValues(alpha: 0.3),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Status',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppTheme.ink.withValues(alpha: 0.62),
                              )),
                      const SizedBox(height: 4),
                      Text(
                        isOnline ? 'ONLINE' : 'OFFLINE',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: isOnline ? Colors.green : Colors.grey,
                              fontSize: 14,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              // Mood tile — tap to expand picker
              GestureDetector(
                onTap: () => setState(() => _moodExpanded = !_moodExpanded),
                child: HoverCard(
                  child: Container(
                    width: 160,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      color: _moodExpanded
                          ? AppTheme.violet.withValues(alpha: 0.08)
                          : Colors.white.withValues(alpha: 0.7),
                      border: _moodExpanded
                          ? Border.all(color: AppTheme.violet.withValues(alpha: 0.3))
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Icon(Icons.favorite_rounded, color: AppTheme.violet, size: 20),
                            Icon(
                              _moodExpanded ? Icons.expand_less_rounded : Icons.edit_rounded,
                              size: 16,
                              color: AppTheme.violet.withValues(alpha: 0.7),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Mood',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.ink.withValues(alpha: 0.62),
                                )),
                        const SizedBox(height: 4),
                        Text(
                          moodDisplay,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: AppTheme.ink,
                                fontSize: 14,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Inline mood picker — expands below tiles
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _moodExpanded
                ? Container(
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppTheme.violet.withValues(alpha: 0.18)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text('How are you feeling?',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.ink)),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: _moods.map((m) {
                            final sel = _pendingEmoji == m.$1;
                            return GestureDetector(
                              onTap: () => setState(() { _pendingEmoji = m.$1; _pendingLabel = m.$2; }),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: sel ? AppTheme.violet.withValues(alpha: 0.15) : Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: sel ? AppTheme.violet : Colors.transparent, width: 2),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Text(m.$1, style: const TextStyle(fontSize: 18)),
                                  const SizedBox(width: 5),
                                  Text(m.$2,
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: sel ? AppTheme.violet : AppTheme.ink.withValues(alpha: 0.7))),
                                ]),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _pendingEmoji == null || _posting ? null : _postMood,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.violet,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: AppTheme.violet.withValues(alpha: 0.35),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              elevation: 0,
                            ),
                            child: Text(_posting ? 'Updating...' : 'Update Mood',
                                style: const TextStyle(fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ── Quick actions ─────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  final VoidCallback onStartChat;
  final VoidCallback onAddContact;

  const _QuickActions({
    required this.onStartChat,
    required this.onAddContact,
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
                  icon: Icons.person_add_rounded,
                  label: 'Add Connection',
                  color: AppTheme.violet,
                  onTap: onAddContact,
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
