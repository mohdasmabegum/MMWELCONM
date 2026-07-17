import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mmwelconn/services/firestore_service.dart';
import 'package:mmwelconn/widgets/app_brand.dart';

enum NotifType { welcome, newRequest, accepted, newMessage }

class InAppNotification {
  final String title;
  final String body;
  final NotifType type;
  final VoidCallback? onTap;

  const InAppNotification({
    required this.title,
    required this.body,
    required this.type,
    this.onTap,
  });
}

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final StreamController<InAppNotification> _controller =
      StreamController<InAppNotification>.broadcast();

  Stream<InAppNotification> get stream => _controller.stream;

  void show(InAppNotification notification) {
    _controller.add(notification);
  }

  Future<void> init() async {
    // Listen to foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        show(InAppNotification(
          title: notification.title ?? 'New Message',
          body: notification.body ?? '',
          type: NotifType.newMessage,
        ));
      }
    });

    // Listen to notification taps when app is backgrounded
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Notification opened app: ${message.messageId}');
    });

    // Automatically update the token in backend (Firestore) when it is refreshed by Firebase
    FirebaseMessaging.instance.onTokenRefresh.listen((token) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirestoreService().updateUser(user.uid, {'fcmToken': token});
        debugPrint('FCM Token automatically refreshed and updated in backend: $token');
      }
    });
  }

  Future<void> requestPermissionAndSaveToken() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        final token = await messaging.getToken();
        if (token != null) {
          await FirestoreService().updateUser(user.uid, {'fcmToken': token});
          debugPrint('FCM Token successfully saved: $token');
        }
      }
    } catch (e) {
      debugPrint('Error requesting notification permission or fetching FCM token: $e');
    }
  }

  void dispose() {
    _controller.close();
  }
}

// ── Overlay widget — wrap around your app or inject into HomeScreen ───────────

class NotificationOverlay extends StatefulWidget {
  final Widget child;
  const NotificationOverlay({super.key, required this.child});

  @override
  State<NotificationOverlay> createState() => _NotificationOverlayState();
}

class _NotificationOverlayState extends State<NotificationOverlay> {
  final List<_NotifEntry> _queue = [];
  StreamSubscription<InAppNotification>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = NotificationService().stream.listen(_onNotification);
  }

  void _onNotification(InAppNotification notif) {
    if (!mounted) return;
    final entry = _NotifEntry(notif: notif, key: UniqueKey());
    setState(() => _queue.add(entry));
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _queue.remove(entry));
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          top: MediaQuery.of(context).padding.top + 12,
          left: 16,
          right: 16,
          child: Column(
            children: _queue
                .map((e) => _NotifBanner(key: e.key, entry: e, onDismiss: () {
                      if (mounted) setState(() => _queue.remove(e));
                    }))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _NotifEntry {
  final InAppNotification notif;
  final Key key;
  _NotifEntry({required this.notif, required this.key});
}

class _NotifBanner extends StatefulWidget {
  final _NotifEntry entry;
  final VoidCallback onDismiss;

  const _NotifBanner({super.key, required this.entry, required this.onDismiss});

  @override
  State<_NotifBanner> createState() => _NotifBannerState();
}

class _NotifBannerState extends State<_NotifBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 380));
    _slide = Tween<Offset>(begin: const Offset(0, -1.2), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    await _ctrl.reverse();
    widget.onDismiss();
  }

  (IconData, Color) get _iconAndColor => switch (widget.entry.notif.type) {
        NotifType.welcome => (Icons.celebration_rounded, AppTheme.violet),
        NotifType.newRequest => (Icons.person_add_rounded, AppTheme.sky),
        NotifType.accepted => (Icons.check_circle_rounded, Colors.green),
        NotifType.newMessage => (Icons.chat_bubble_rounded, AppTheme.pink),
      };

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _iconAndColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: MouseRegion(
            onEnter: (_) => setState(() => _isHovered = true),
            onExit: (_) => setState(() => _isHovered = false),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutQuad,
              transform: Matrix4.identity()
                ..translate(0.0, _isHovered ? -4.0 : 0.0)
                ..scale(_isHovered ? 1.015 : 1.0),
              child: Material(
                type: MaterialType.transparency,
                child: GestureDetector(
                  onTap: () {
                    widget.entry.notif.onTap?.call();
                    _dismiss();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _isHovered ? color.withValues(alpha: 0.7) : color.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: _isHovered ? 0.22 : 0.12),
                          blurRadius: _isHovered ? 24 : 16,
                          offset: Offset(0, _isHovered ? 10 : 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.entry.notif.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      decoration: TextDecoration.none,
                                      color: AppTheme.ink)),
                              const SizedBox(height: 3),
                              Text(widget.entry.notif.body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12,
                                      decoration: TextDecoration.none,
                                      fontWeight: FontWeight.normal,
                                      color: AppTheme.ink.withValues(alpha: 0.55))),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _dismiss,
                          child: Icon(Icons.close_rounded,
                              size: 18, color: AppTheme.ink.withValues(alpha: 0.35)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
