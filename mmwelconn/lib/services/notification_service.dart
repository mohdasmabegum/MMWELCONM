import 'dart:async';
import 'package:flutter/material.dart';
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
          child: GestureDetector(
            onTap: () {
              widget.entry.notif.onTap?.call();
              _dismiss();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withValues(alpha: 0.25)),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
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
                                color: AppTheme.ink)),
                        const SizedBox(height: 2),
                        Text(widget.entry.notif.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.ink.withValues(alpha: 0.55))),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _dismiss,
                    child: Icon(Icons.close_rounded,
                        size: 16, color: AppTheme.ink.withValues(alpha: 0.3)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
