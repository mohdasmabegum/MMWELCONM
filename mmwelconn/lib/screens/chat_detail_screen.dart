import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mmwelconn/models/chat_model.dart';
import 'package:mmwelconn/models/mood_model.dart';
import 'package:mmwelconn/models/user_model.dart';
import 'package:mmwelconn/services/firestore_service.dart';
import 'package:mmwelconn/services/storage_service.dart';
import 'package:mmwelconn/widgets/app_brand.dart';

class ChatDetailScreen extends StatefulWidget {
  final ChatModel chat;
  final String currentUid;

  const ChatDetailScreen({super.key, required this.chat, required this.currentUid});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final FirestoreService _fs = FirestoreService();
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final GlobalKey<_InputBarState> _inputBarKey = GlobalKey();
  StreamSubscription<List<MessageModel>>? _msgSub;
  StreamSubscription<UserModel?>? _otherUserSub;
  StreamSubscription<MoodModel?>? _otherMoodSub;
  List<MessageModel> _messages = [];
  bool _loading = true;
  bool _otherOnline = false;
  MoodModel? _otherMood;
  String? _watchedMoodId;

  String get _myName => widget.chat.participantNames[widget.currentUid] ?? 'Me';

  String get _otherUid => widget.chat.participantIds
      .firstWhere((id) => id != widget.currentUid, orElse: () => '');

  String get _otherName {
    if (widget.chat.chatType == ChatType.group) return widget.chat.groupName ?? 'Group';
    return widget.chat.participantNames[_otherUid] ?? 'Unknown';
  }

  @override
  void initState() {
    super.initState();
    _fs.clearUnread(widget.chat.id, widget.currentUid);
    _msgSub = _fs.watchMessages(widget.chat.id).listen((msgs) {
      if (!mounted) return;
      final wasAtBottom = !_scroll.hasClients ||
          _scroll.offset <= _scroll.position.minScrollExtent + 80;
      setState(() {
        _messages = msgs;
        _loading = false;
      });
      if (wasAtBottom) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.animateTo(
              _scroll.position.minScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
    if (_otherUid.isNotEmpty) {
      _otherUserSub = _fs.watchUser(_otherUid).listen((u) {
        if (!mounted) return;
        setState(() => _otherOnline = u?.status == 'online');
        final moodId = u?.currentMoodId;
        if (moodId != _watchedMoodId) {
          _otherMoodSub?.cancel();
          _watchedMoodId = moodId;
          if (moodId != null) {
            _otherMoodSub = _fs.watchMoodById(moodId).listen((m) {
              if (!mounted) return;
              if (m != null && DateTime.now().difference(m.createdAt).inHours >= 24) {
                setState(() => _otherMood = null);
              } else {
                setState(() => _otherMood = m);
              }
            });
          } else {
            setState(() => _otherMood = null);
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _otherUserSub?.cancel();
    _otherMoodSub?.cancel();
    _msgCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();
    await _fs.sendMessage(
      widget.chat.id,
      MessageModel(
        id: '',
        senderId: widget.currentUid,
        senderName: _myName,
        text: text,
        createdAt: DateTime.now(),
      ),
      widget.chat.participantIds,
    );
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 75);
    if (picked == null || !mounted) return;
    _inputBarKey.currentState?.uploadAndSend(File(picked.path));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SoftGlowBackground(
        child: SafeArea(
          child: Column(
            children: [
              _AppBar(title: _otherName, isOnline: _otherOnline, mood: _otherMood),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _messages.isEmpty
                        ? Center(
                            child: Text(
                              'Say hello! 👋',
                              style: TextStyle(color: AppTheme.ink.withValues(alpha: 0.45)),
                            ),
                          )
                        : ListView.builder(
                            controller: _scroll,
                            reverse: true,
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            itemCount: _messages.length,
                            itemBuilder: (_, i) {
                              final msg = _messages[i];
                              final isMe = msg.senderId == widget.currentUid;
                              final showDate = i == _messages.length - 1 ||
                                  !_isSameDay(msg.createdAt, _messages[i + 1].createdAt);
                              final showSender = !isMe &&
                                  widget.chat.chatType == ChatType.group &&
                                  (i == _messages.length - 1 ||
                                      _messages[i + 1].senderId != msg.senderId);
                              return Column(
                                children: [
                                  if (showDate) _DateSeparator(date: msg.createdAt),
                                  _MessageBubble(
                                    msg: msg,
                                    isMe: isMe,
                                    showSenderName: showSender,
                                  ),
                                ],
                              );
                            },
                          ),
              ),
              _InputBar(
                key: _inputBarKey,
                controller: _msgCtrl,
                onSend: _send,
                onPickImage: _pickAndSendImage,
                chatId: widget.chat.id,
                senderId: widget.currentUid,
                senderName: _myName,
                participantIds: widget.chat.participantIds,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _formatTime(DateTime dt) {
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String _formatDate(DateTime dt) {
  final now = DateTime.now();
  if (_isSameDay(dt, now)) return 'Today';
  final yesterday = now.subtract(const Duration(days: 1));
  if (_isSameDay(dt, yesterday)) return 'Yesterday';
  return '${dt.day}/${dt.month}/${dt.year}';
}

class _DateSeparator extends StatelessWidget {
  final DateTime date;
  const _DateSeparator({required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppTheme.ink.withValues(alpha: 0.12), thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              _formatDate(date),
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.ink.withValues(alpha: 0.4),
                  letterSpacing: 0.5),
            ),
          ),
          Expanded(child: Divider(color: AppTheme.ink.withValues(alpha: 0.12), thickness: 1)),
        ],
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  final String title;
  final bool isOnline;
  final MoodModel? mood;
  const _AppBar({required this.title, required this.isOnline, this.mood});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        border: Border(bottom: BorderSide(color: AppTheme.ink.withValues(alpha: 0.06))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.ink),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.violet.withValues(alpha: 0.18),
                child: Text(
                  title.isNotEmpty ? title[0].toUpperCase() : '?',
                  style: const TextStyle(color: AppTheme.violet, fontWeight: FontWeight.w800),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                    color: isOnline ? Colors.green : Colors.grey,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.ink)),
                Row(
                  children: [
                    Text(isOnline ? 'Online' : 'Offline',
                        style: TextStyle(
                            fontSize: 11,
                            color: isOnline ? Colors.green.withValues(alpha: 0.9) : Colors.grey,
                            fontWeight: FontWeight.w600)),
                    if (mood != null) ...[
                      Text('  •  ',
                          style: TextStyle(
                              fontSize: 11, color: AppTheme.ink.withValues(alpha: 0.3))),
                      Text(
                        '${mood!.emoji} ${mood!.label}',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.violet.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Message Bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final MessageModel msg;
  final bool isMe;
  final bool showSenderName;

  const _MessageBubble({
    required this.msg,
    required this.isMe,
    this.showSenderName = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = msg.imageUrl != null && msg.imageUrl!.isNotEmpty;
    final hasText = msg.text.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        top: 2,
        bottom: 2,
        left: isMe ? 48 : 0,
        right: isMe ? 0 : 48,
      ),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (showSenderName)
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 2),
                child: Text(
                  msg.senderName,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.violet.withValues(alpha: 0.8)),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: isMe && !hasImage
                    ? const LinearGradient(
                        colors: [Color(0xFF9B6DFF), Color(0xFF7B61FF)])
                    : null,
                color: hasImage ? null : (isMe ? null : Colors.white.withValues(alpha: 0.88)),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              clipBehavior: Clip.hardEdge,
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (hasImage)
                    GestureDetector(
                      onTap: () => _showFullImage(context, msg.imageUrl!),
                      child: ClipRRect(
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(18),
                          topRight: const Radius.circular(18),
                          bottomLeft: Radius.circular(hasText ? 0 : (isMe ? 18 : 4)),
                          bottomRight: Radius.circular(hasText ? 0 : (isMe ? 4 : 18)),
                        ),
                        child: Image.network(
                          msg.imageUrl!,
                          width: 220,
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, progress) => progress == null
                              ? child
                              : Container(
                                  width: 220,
                                  height: 160,
                                  color: AppTheme.violet.withValues(alpha: 0.08),
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value: progress.expectedTotalBytes != null
                                          ? progress.cumulativeBytesLoaded /
                                              progress.expectedTotalBytes!
                                          : null,
                                      color: AppTheme.violet,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                          errorBuilder: (_, __, ___) => Container(
                            width: 220,
                            height: 100,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      hasImage ? 10 : 14,
                      hasImage && hasText ? 6 : (hasImage ? 4 : 10),
                      hasImage ? 10 : 14,
                      8,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        if (hasText)
                          Text(
                            msg.text,
                            style: TextStyle(
                              color: isMe ? Colors.white : AppTheme.ink,
                              fontSize: 15,
                              height: 1.35,
                            ),
                          ),
                        if (hasText) const SizedBox(height: 4),
                        Text(
                          _formatTime(msg.createdAt),
                          style: TextStyle(
                            fontSize: 10,
                            color: isMe
                                ? Colors.white.withValues(alpha: 0.65)
                                : AppTheme.ink.withValues(alpha: 0.38),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullImage(BuildContext context, String url) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (_, __, ___) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    ));
  }
}

// ── Input Bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final void Function(ImageSource) onPickImage;
  final String chatId;
  final String senderId;
  final String senderName;
  final List<String> participantIds;

  const _InputBar({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onPickImage,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.participantIds,
  });

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  bool _hasText = false;
  bool _uploading = false;
  double _uploadProgress = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() {
      final has = widget.controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  Future<void> uploadAndSend(File file) async {
    setState(() { _uploading = true; _uploadProgress = 0; });
    try {
      final url = await StorageService().uploadChatImage(
        widget.chatId,
        file,
        onProgress: (p) { if (mounted) setState(() => _uploadProgress = p); },
      );
      await FirestoreService().sendMessage(
        widget.chatId,
        MessageModel(
          id: '',
          senderId: widget.senderId,
          senderName: widget.senderName,
          text: '',
          imageUrl: url,
          createdAt: DateTime.now(),
        ),
        widget.participantIds,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send image: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() { _uploading = false; _uploadProgress = 0; });
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.violet.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt_rounded, color: AppTheme.violet),
                ),
                title: const Text('Take a photo',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.pop(context);
                  widget.onPickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.sky.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.photo_library_rounded, color: AppTheme.sky),
                ),
                title: const Text('Choose from gallery',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.pop(context);
                  widget.onPickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_uploading)
          LinearProgressIndicator(
            value: _uploadProgress > 0 ? _uploadProgress : null,
            backgroundColor: AppTheme.violet.withValues(alpha: 0.1),
            color: AppTheme.violet,
            minHeight: 3,
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.55),
            border: Border(top: BorderSide(color: AppTheme.ink.withValues(alpha: 0.06))),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: _uploading ? null : _showImageSourceSheet,
                icon: Icon(
                  Icons.add_photo_alternate_rounded,
                  color: _uploading
                      ? Colors.grey.shade400
                      : AppTheme.violet.withValues(alpha: 0.8),
                  size: 26,
                ),
              ),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  onSubmitted: (_) => widget.onSend(),
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.88),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedScale(
                scale: _hasText ? 1.0 : 0.85,
                duration: const Duration(milliseconds: 150),
                child: GestureDetector(
                  onTap: widget.onSend,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: _hasText
                            ? [const Color(0xFF9B6DFF), const Color(0xFF7B61FF)]
                            : [Colors.grey.shade300, Colors.grey.shade300],
                      ),
                    ),
                    child: Icon(
                      Icons.send_rounded,
                      color: _hasText ? Colors.white : Colors.grey.shade500,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
