import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mmwelconm/models/chat_model.dart';
import 'package:mmwelconm/models/mood_model.dart';
import 'package:mmwelconm/models/user_model.dart';
import 'package:mmwelconm/screens/chats_screen.dart';
import 'package:mmwelconm/screens/connections_screen.dart';
import 'package:mmwelconm/screens/photos_screen.dart';
import 'package:mmwelconm/screens/settings_screen.dart';
import 'package:mmwelconm/screens/profile_screen.dart';
import 'package:mmwelconm/screens/chat_detail_screen.dart';
import 'package:mmwelconm/screens/reminders_screen.dart';
import 'package:mmwelconm/screens/todo_screen.dart';
import 'package:mmwelconm/screens/teen_hub_screen.dart';
import 'package:mmwelconm/screens/adult_suite_screen.dart';
import 'package:mmwelconm/screens/kids_playground_screen.dart';
import 'package:mmwelconm/screens/elder_companion_screen.dart';
import 'package:mmwelconm/screens/professional_hub_screen.dart';
import 'package:mmwelconm/models/reminder_model.dart';
import 'package:mmwelconm/models/contact_model.dart';
import 'package:mmwelconm/services/firestore_service.dart';
import 'package:mmwelconm/services/notification_service.dart';
import 'package:mmwelconm/widgets/app_brand.dart';

class HomeScreen extends StatefulWidget {
  final int initialTab;
  const HomeScreen({super.key, this.initialTab = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late int _selectedIndex;
  final FirestoreService _fs = FirestoreService();
  StreamSubscription<UserModel?>? _userSub;
  UserModel? _userModel;
  StreamSubscription<List<ChatModel>>? _chatsSub;
  StreamSubscription<List<ReminderModel>>? _remindersSub;
  StreamSubscription<List<ContactModel>>? _contactsSub;
  StreamSubscription<List<ContactModel>>? _incomingRequestsSub;
  final Map<String, Timer> _reminderTimers = {};
  final Map<String, DateTime> _lastSeenMessageTimes = {};
  bool _isReminderDialogShowing = false;
  bool _streakChecked = false;
  bool _birthdayWishesTriggeredToday = false;
  final List<ReminderModel> _reminderQueue = [];

  void _goToTab(int index) => setState(() => _selectedIndex = index);

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTab;
    WidgetsBinding.instance.addObserver(this);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _userSub = _fs.watchUser(uid).listen((user) {
        if (mounted) {
          setState(() {
            _userModel = user;
            if (user != null) {
              AppTheme.updateVibe(user.ageGroup, user.customTheme, forceHighContrast: user.highContrastEnabled);
              AppTheme.fontSizeFactor.value = user.fontSizeScale;
              AppTheme.highContrast.value = user.highContrastEnabled;

              if (!_streakChecked) {
                _streakChecked = true;
                _checkAndUpdateStreak(user);
              }

              _checkAndAutoUpdateAgeGroup(user);
              _checkAndTriggerBirthdayWishes(user);

              if (user.deletionScheduledAt != null) {
                final diff = DateTime.now().difference(user.deletionScheduledAt!);
                if (diff.inHours >= 24) {
                  _performAccountDeletionCleanup(user.uid);
                } else {
                  _showRestoreAccountDialog(user);
                }
              }
            }
          });
        }
      });

      // Request/update notification permission & save FCM token
      NotificationService().requestPermissionAndSaveToken();

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
              if (!_lastSeenMessageTimes.containsKey(chatId)) {
                _lastSeenMessageTimes[chatId] = lastTime;
                if ((chat.unreadCount[uid] ?? 0) > 0 && chatId != ChatDetailScreen.activeChatId) {
                  final senderName = chat.participantNames[chat.lastSenderId] ?? 'Someone';
                  final messageText = (chat.lastMessage != null && chat.lastMessage!.isNotEmpty)
                      ? chat.lastMessage!
                      : 'Sent an image 📷';
                  NotificationService().show(InAppNotification(
                    title: senderName,
                    body: messageText,
                    type: NotifType.newMessage,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatDetailScreen(
                            chat: chat,
                            currentUid: uid,
                          ),
                        ),
                      );
                    },
                  ));
                }
              } else {
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
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatDetailScreen(
                              chat: chat,
                              currentUid: uid,
                            ),
                          ),
                        );
                      },
                    ));
                  }
                }
                _lastSeenMessageTimes[chatId] = lastTime;
              }
            }
          }
        }
      });

      _setupReminderScheduler(uid);

      final Set<String> _existingAcceptedContactUids = {};
      _contactsSub = _fs.watchContacts(uid, status: ContactStatus.accepted).listen((contacts) {
        final currentUids = contacts.map((c) => c.contactUid).toSet();
        if (_existingAcceptedContactUids.isEmpty) {
          _existingAcceptedContactUids.addAll(currentUids);
        } else {
          for (var c in contacts) {
            if (!_existingAcceptedContactUids.contains(c.contactUid)) {
              NotificationService().show(InAppNotification(
                title: 'Connection Accepted 🎉',
                body: 'You are now connected with ${c.contactName}!',
                type: NotifType.accepted,
              ));
              _existingAcceptedContactUids.add(c.contactUid);
            }
          }
          _existingAcceptedContactUids.retainAll(currentUids);
        }
      });

      final Set<String> _existingIncomingRequestUids = {};
      _incomingRequestsSub = _fs.watchContacts(uid, status: ContactStatus.pending, direction: ContactDirection.incoming).listen((requests) {
        final currentUids = requests.map((c) => c.contactUid).toSet();
        if (_existingIncomingRequestUids.isEmpty) {
          _existingIncomingRequestUids.addAll(currentUids);
        } else {
          for (var r in requests) {
            if (!_existingIncomingRequestUids.contains(r.contactUid)) {
              NotificationService().show(InAppNotification(
                title: 'New Connection Request 👤',
                body: '${r.contactName} sent you a connection request!',
                type: NotifType.newRequest,
              ));
              _existingIncomingRequestUids.add(r.contactUid);
            }
          }
          _existingIncomingRequestUids.retainAll(currentUids);
        }
      });
    }
  }

  void _setupReminderScheduler(String uid) {
    _remindersSub = _fs.watchUpcomingReminders(uid).listen((reminders) {
      final now = DateTime.now();

      // Cancel timers and system notifications for reminders no longer in upcoming list
      final currentIds = reminders.map((r) => r.id).toSet();
      _reminderTimers.keys.toList().forEach((id) {
        if (!currentIds.contains(id)) {
          _reminderTimers[id]?.cancel();
          _reminderTimers.remove(id);
          NotificationService().cancelScheduledNotification(id.hashCode);
        }
      });

      for (final reminder in reminders) {
        if (reminder.remindAt.isAfter(now)) {
          // Reschedule if exists or schedule new timer
          _reminderTimers[reminder.id]?.cancel();

          final duration = reminder.remindAt.difference(now);
          final timer = Timer(duration, () {
            _triggerFullScreenReminder(reminder);
            _reminderTimers.remove(reminder.id);
          });
          _reminderTimers[reminder.id] = timer;

          // Sync with local background system notification tray scheduler
          NotificationService().scheduleLocalNotification(
            id: reminder.id.hashCode,
            title: 'Schedule Alert: ${reminder.title}',
            body: reminder.description.isNotEmpty ? reminder.description : 'Reminder is active.',
            scheduledDate: reminder.remindAt,
          );
        } else {
          // Missed/immediate: trigger within last 1 hour
          if (now.difference(reminder.remindAt).inHours < 1) {
            _triggerFullScreenReminder(reminder);
          }
          // Mark completed to avoid duplicate firing
          _fs.updateReminder(reminder.id, {'isCompleted': true});
        }
      }
    }, onError: (e) {
      debugPrint('Error watching upcoming reminders: $e');
    });
  }

  void _triggerFullScreenReminder(ReminderModel reminder) {
    if (_isReminderDialogShowing) {
      if (!_reminderQueue.any((r) => r.id == reminder.id)) {
        _reminderQueue.add(reminder);
      }
      return;
    }
    _isReminderDialogShowing = true;

    // Immediately mark as completed when alerting, so it won't fire again on load
    _fs.updateReminder(reminder.id, {'isCompleted': true});

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.violet.withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.violet.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.alarm_on_rounded, color: AppTheme.violet, size: 36),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'SCHEDULE REMINDER',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 1.5,
                      color: AppTheme.violet,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    reminder.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 22,
                      color: AppTheme.ink,
                    ),
                  ),
                  if (reminder.description.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      reminder.description,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.ink.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            final snoozeTime = DateTime.now().add(const Duration(minutes: 5));
                            _fs.updateReminder(reminder.id, {'remindAt': snoozeTime, 'isCompleted': false});
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.violet),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Snooze (5m)', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.violet)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            _fs.updateReminder(reminder.id, {'isCompleted': true});
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            elevation: 0,
                          ),
                          child: const Text('Complete', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      _isReminderDialogShowing = false;
      if (_reminderQueue.isNotEmpty && mounted) {
        final next = _reminderQueue.removeAt(0);
        _triggerFullScreenReminder(next);
      }
    });
  }

  bool _showingRestoreDialog = false;

  Future<void> _performAccountDeletionCleanup(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }

  void _showRestoreAccountDialog(UserModel user) {
    if (_showingRestoreDialog) return;
    _showingRestoreDialog = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Restore Account? 🛠️', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          'Your account is currently scheduled for deletion. If you continue, the scheduled deletion will be cancelled and your account will be restored.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              _showingRestoreDialog = false;
              Navigator.pop(context);
              await FirebaseAuth.instance.signOut();
            },
            child: const Text('Log out', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () async {
              _showingRestoreDialog = false;
              Navigator.pop(context);
              await _fs.updateUser(user.uid, {
                'deletionScheduledAt': FieldValue.delete(),
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Account restored successfully! 🎉')),
                );
              }
            },
            child: const Text('Restore Account', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _checkAndUpdateStreak(UserModel user) async {
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (user.lastActiveDate == todayStr) return;

    int newStreak = user.streakCount;
    if (user.lastActiveDate.isNotEmpty) {
      try {
        final lastDate = DateTime.parse(user.lastActiveDate);
        final difference = DateTime(now.year, now.month, now.day).difference(DateTime(lastDate.year, lastDate.month, lastDate.day)).inDays;
        if (difference == 1) {
          newStreak++;
        } else if (difference > 1) {
          newStreak = 1;
        }
      } catch (_) {
        newStreak = 1;
      }
    } else {
      newStreak = 1;
    }

    final updatedBadges = List<String>.from(user.badges);
    if (newStreak >= 5 && !updatedBadges.contains('Mood Master 🏆')) {
      updatedBadges.add('Mood Master 🏆');
    }
    if (newStreak >= 3 && !updatedBadges.contains('Happy Kid 🌟')) {
      updatedBadges.add('Happy Kid 🌟');
    }
    if (!updatedBadges.contains('Good Friend 🤝')) {
      updatedBadges.add('Good Friend 🤝');
    }

    await _fs.updateUser(user.uid, {
      'streakCount': newStreak,
      'lastActiveDate': todayStr,
      'badges': updatedBadges,
    });
  }

  void _checkAndAutoUpdateAgeGroup(UserModel user) async {
    if (user.dateOfBirth == null) return;

    final now = DateTime.now();
    int age = now.year - user.dateOfBirth!.year;
    if (now.month < user.dateOfBirth!.month ||
        (now.month == user.dateOfBirth!.month && now.day < user.dateOfBirth!.day)) {
      age--;
    }

    String targetGroup = 'adult';
    if (age < 13) {
      targetGroup = 'kid';
    } else if (age < 20) {
      targetGroup = 'teen';
    } else if (age < 55) {
      targetGroup = 'adult';
    } else {
      targetGroup = 'elder';
    }

    if (user.ageGroup != targetGroup && user.ageGroup != 'professional') {
      await _fs.updateUser(user.uid, {
        'ageGroup': targetGroup,
        if (targetGroup != 'kid') 'kidsModeLocked': false,
      });
      NotificationService().show(InAppNotification(
        title: 'Vibe Level Up! 🚀',
        body: 'You are now $age years old! Your theme updated to ${targetGroup.toUpperCase()} mode.',
        type: NotifType.welcome,
      ));
    }
  }

  void _checkAndTriggerBirthdayWishes(UserModel user) async {
    if (user.dateOfBirth == null || _birthdayWishesTriggeredToday) return;

    final now = DateTime.now();
    if (now.month == user.dateOfBirth!.month && now.day == user.dateOfBirth!.day) {
      _birthdayWishesTriggeredToday = true;

      int yearsJoined = now.year - user.createdAt.year;
      if (yearsJoined < 1) yearsJoined = 1;

      final ordinal = yearsJoined == 1
          ? '1st'
          : yearsJoined == 2
              ? '2nd'
              : yearsJoined == 3
                  ? '3rd'
                  : '${yearsJoined}th';
      final badgeName = '$ordinal Birthday 🎂';

      if (!user.badges.contains(badgeName)) {
        final updatedBadges = List<String>.from(user.badges)..add(badgeName);
        await _fs.updateUser(user.uid, {'badges': updatedBadges});
      }

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _showBirthdayCelebrationDialog(user, yearsJoined);
        }
      });
    }
  }

  void _showBirthdayCelebrationDialog(UserModel user, int yearsJoined) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Birthday',
      barrierColor: Colors.black.withOpacity(0.85),
      transitionDuration: const Duration(milliseconds: 550),
      pageBuilder: (context, anim1, anim2) {
        final ordinal = yearsJoined == 1
            ? '1st'
            : yearsJoined == 2
                ? '2nd'
                : yearsJoined == 3
                    ? '3rd'
                    : '${yearsJoined}th';
        final badgeName = '$ordinal Birthday 🎂';

        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.elasticOut),
          child: AlertDialog(
            backgroundColor: const Color(0xFF1E1B4B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(32),
              side: const BorderSide(color: Colors.amberAccent, width: 2),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉🎂🎈', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                const Text(
                  'HAPPY BIRTHDAY!',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Colors.amberAccent,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  user.name.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Wishing you a grand celebration and a wonderful year ahead! ✨',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.amberAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amberAccent.withOpacity(0.4)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.workspace_premium_rounded, color: Colors.amberAccent, size: 36),
                      const SizedBox(height: 8),
                      const Text(
                        'New Badge Earned! 🏆',
                        style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        badgeName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    HapticFeedback.heavyImpact();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amberAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  ),
                  child: const Text('Thank you! 🥳', style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _userSub?.cancel();
    _chatsSub?.cancel();
    _remindersSub?.cancel();
    _contactsSub?.cancel();
    _incomingRequestsSub?.cancel();
    for (final t in _reminderTimers.values) {
      t.cancel();
    }
    _reminderTimers.clear();
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
    final ageGroup = _userModel?.ageGroup ?? 'teen';

    final pages = [
      _HomePage(onGoToChats: () => _goToTab(1), onGoToContacts: () => _goToTab(5)),
      const ChatsScreen(),
      const RemindersScreen(),
      const TodoScreen(),
      if (ageGroup == 'teen')
        const TeenHubScreen()
      else if (ageGroup == 'kid')
        const KidsPlaygroundScreen()
      else if (ageGroup == 'elder')
        const ElderCompanionScreen()
      else if (ageGroup == 'professional')
        const ProfessionalHubScreen()
      else
        const AdultSuiteScreen(),
      const ConnectionsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.only(left: 88),
              child: pages[_selectedIndex < pages.length ? _selectedIndex : 0],
            ),
          ),
          Positioned(
            left: 12,
            top: MediaQuery.of(context).size.height * 0.05,
            bottom: MediaQuery.of(context).size.height * 0.05,
            child: _buildSideNav(ageGroup),
          ),
        ],
      ),
    );
  }

  Widget _buildSideNav(String ageGroup) {
    final tabs = [
      {'icon': Icons.home_rounded, 'label': 'Home'},
      {'icon': Icons.chat_rounded, 'label': 'Chats'},
      {'icon': Icons.calendar_today_rounded, 'label': 'Schedules'},
      {'icon': Icons.checklist_rtl_rounded, 'label': 'Tasks'},
      if (ageGroup == 'teen')
        {'icon': Icons.bolt_rounded, 'label': 'Teen Hub'}
      else if (ageGroup == 'kid')
        {'icon': Icons.bubble_chart_rounded, 'label': 'Playground'}
      else if (ageGroup == 'elder')
        {'icon': Icons.health_and_safety_rounded, 'label': 'Companion'}
      else
        {'icon': Icons.business_center_rounded, 'label': 'Adult Suite'},
      {'icon': Icons.people_alt_rounded, 'label': 'Contacts'},
      {'icon': Icons.settings_rounded, 'label': 'Settings'},
    ];

    const double itemHeight = 64.0;
    const double paddingOffset = 16.0;

    return Container(
      width: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        color: const Color(0xFF13141F).withValues(alpha: 0.92),
        border: Border.all(
          color: const Color(0xFFC084FC).withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
            blurRadius: 30,
            spreadRadius: 3,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: Stack(
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            left: 6,
            right: 6,
            top: paddingOffset + (_selectedIndex * itemHeight) + 4,
            height: 56,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFFC084FC)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFC084FC).withValues(alpha: 0.4),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: paddingOffset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(tabs.length, (idx) {
                final isSelected = _selectedIndex == idx;
                final item = tabs[idx];
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _goToTab(idx);
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    height: itemHeight,
                    width: double.infinity,
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedScale(
                          scale: isSelected ? 1.15 : 1.0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            item['icon'] as IconData,
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.45),
                            size: 22,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item['label'] as String,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 7.5,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.45),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
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
      }, onError: (e) {
        debugPrint('Error watching user profile: $e');
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
                        _VibeSwitcherBanner(userModel: _userModel, fs: _fs),
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
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          margin: const EdgeInsets.only(left: -24, right: -24, top: 48),
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
                          child: Center(
                            child: Text(
                              '© ${DateTime.now().year} MMWelconm by MRA',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.vibe.textColor.withValues(alpha: 0.65),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
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

class _VibeSwitcherBanner extends StatelessWidget {
  final UserModel? userModel;
  final FirestoreService fs;

  const _VibeSwitcherBanner({required this.userModel, required this.fs});

  @override
  Widget build(BuildContext context) {
    if (userModel == null) return const SizedBox();
    final activeGroup = userModel!.ageGroup;
    final vibe = AppTheme.vibe;

    return HoverCard(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: vibe.cardColor,
          border: Border.all(color: vibe.borderColor.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.palette_rounded, color: vibe.primaryColor, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Experience Multi-Generational Vibes! 🎨',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: vibe.textColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Select an age group below to adapt backgrounds, styling, legibility scales, and custom hubs.',
                        style: TextStyle(fontSize: 11, color: vibe.textColor.withValues(alpha: 0.65)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildVibeChip('Kids 🧸', 'kid', 'bubblegum', activeGroup, vibe),
                _buildVibeChip('Teens ⚡', 'teen', 'neon', activeGroup, vibe),
                _buildVibeChip('Adults 💼', 'adult', 'slate', activeGroup, vibe),
                _buildVibeChip('Elders 👵', 'elder', 'cream', activeGroup, vibe),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildVibeChip(String label, String groupKey, String defaultTheme, String activeGroup, VibeTheme vibe) {
    final active = activeGroup == groupKey;
    return GestureDetector(
      onTap: () async {
        await fs.updateUser(userModel!.uid, {
          'ageGroup': groupKey,
          'customTheme': defaultTheme,
          'fontSizeScale': groupKey == 'elder' ? 1.4 : 1.0,
          'highContrastEnabled': false,
        });
        AppTheme.updateVibe(groupKey, defaultTheme);
        AppTheme.fontSizeFactor.value = groupKey == 'elder' ? 1.4 : 1.0;
        AppTheme.highContrast.value = false;
        HapticFeedback.mediumImpact();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? vibe.primaryColor : vibe.textColor.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? vibe.primaryColor : vibe.borderColor.withValues(alpha: 0.1)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: active ? (vibe.isDark && vibe.primaryColor == const Color(0xFFFCEE09) ? Colors.black : Colors.white) : vibe.textColor.withValues(alpha: 0.8),
          ),
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
    final vibe = AppTheme.vibe;
    return HoverCard(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          color: vibe.cardColor,
          border: Border.all(color: vibe.borderColor.withValues(alpha: 0.35)),
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
                            border: Border.all(color: vibe.isDark ? Colors.black : Colors.white, width: 2),
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
                          'MMWELCONM',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: vibe.textColor,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'A calm social space for mood, chat, and connection.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: vibe.textColor.withValues(alpha: 0.7),
                              ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'MM ID: ',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: vibe.textColor.withValues(alpha: 0.6),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            Text(
                              userModel?.mmId ?? '...',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: vibe.primaryColor,
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
                                child: Icon(
                                  Icons.copy_rounded,
                                  size: 14,
                                  color: vibe.primaryColor,
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
                          color: vibe.textColor,
                        ),
                  ),
                ),
                Switch.adaptive(
                  value: isOnline,
                  onChanged: onStatusChanged,
                  activeColor: vibe.primaryColor,
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
                    color: vibe.textColor.withValues(alpha: 0.7),
                    height: 1.45,
                  ),
            ),
          ],
        ),
      ),
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
    final vibe = AppTheme.vibe;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Quick Actions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: vibe.textColor,
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
                    color: AppTheme.vibe.textColor.withValues(alpha: 0.75))),
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

  void _detectMoodAI() {
    final note = _noteCtrl.text.toLowerCase();
    if (note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please type some text first so the AI can analyze it! 🤖')),
      );
      return;
    }

    String detectedEmoji = '😌';
    String detectedLabel = 'Calm';

    final happyKeywords = ['happy', 'glad', 'awesome', 'great', 'good', 'love', 'perfect', 'smile', 'blessed', 'fun', 'joy'];
    final sadKeywords = ['sad', 'down', 'blue', 'hurt', 'unhappy', 'cry', 'lonely', 'miss', 'bad', 'sorry'];
    final angryKeywords = ['angry', 'mad', 'frustrated', 'annoyed', 'hate', 'stupid', 'shut up', 'crazy'];
    final tiredKeywords = ['tired', 'sleepy', 'exhausted', 'sleep', 'bed', 'zzz', 'lazy'];
    final excitedKeywords = ['excited', 'woohoo', 'party', 'celebrate', 'hype', 'yes', 'yay'];
    final anxiousKeywords = ['anxious', 'scared', 'worry', 'afraid', 'stressed', 'nervous'];

    if (happyKeywords.any((k) => note.contains(k))) {
      detectedEmoji = '😊';
      detectedLabel = 'Happy';
    } else if (sadKeywords.any((k) => note.contains(k))) {
      detectedEmoji = '😔';
      detectedLabel = 'Sad';
    } else if (angryKeywords.any((k) => note.contains(k))) {
      detectedEmoji = '😤';
      detectedLabel = 'Frustrated';
    } else if (excitedKeywords.any((k) => note.contains(k))) {
      detectedEmoji = '🥳';
      detectedLabel = 'Excited';
    } else if (tiredKeywords.any((k) => note.contains(k))) {
      detectedEmoji = '😴';
      detectedLabel = 'Tired';
    } else if (anxiousKeywords.any((k) => note.contains(k))) {
      detectedEmoji = '😰';
      detectedLabel = 'Anxious';
    }

    setState(() {
      _selectedEmoji = detectedEmoji;
      _selectedLabel = detectedLabel;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('AI Vibe detected: $detectedEmoji $detectedLabel! 🤖✨'),
        backgroundColor: AppTheme.violet,
      ),
    );
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
                suffixIcon: IconButton(
                  icon: const Icon(Icons.psychology, color: AppTheme.violet),
                  tooltip: 'AI Detect Mood',
                  onPressed: _detectMoodAI,
                ),
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
