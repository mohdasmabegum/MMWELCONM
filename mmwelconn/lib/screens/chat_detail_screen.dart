import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mmwelconn/models/chat_model.dart';
import 'package:mmwelconn/models/user_model.dart';
import 'package:mmwelconn/services/firestore_service.dart';
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
  StreamSubscription<List<MessageModel>>? _msgSub;
  StreamSubscription<UserModel?>? _otherUserSub;
  List<MessageModel> _messages = [];
  bool _loading = true;
  bool _otherOnline = false;

  String get _myName =>
      widget.chat.participantNames[widget.currentUid] ?? 'Me';

  String get _otherUid => widget.chat.participantIds
      .firstWhere((id) => id != widget.currentUid, orElse: () => '');

  String get _otherName {
    if (widget.chat.chatType == ChatType.group) {
      return widget.chat.groupName ?? 'Group';
    }
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
    // Watch other user's real status
    if (_otherUid.isNotEmpty) {
      _otherUserSub = _fs.watchUser(_otherUid).listen((u) {
        if (mounted) setState(() => _otherOnline = u?.status == 'online');
      });
    }
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _otherUserSub?.cancel();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SoftGlowBackground(
        child: SafeArea(
          child: Column(
            children: [
              _AppBar(title: _otherName, isOnline: _otherOnline),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _messages.isEmpty
                        ? Center(
                            child: Text(
                              'Say hello! 👋',
                              style: TextStyle(
                                  color: AppTheme.ink.withValues(alpha: 0.45)),
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
                                  !_isSameDay(
                                      msg.createdAt, _messages[i + 1].createdAt);
                              final showSender = !isMe &&
                                  widget.chat.chatType == ChatType.group &&
                                  (i == _messages.length - 1 ||
                                      _messages[i + 1].senderId != msg.senderId);
                              return Column(
                                children: [
                                  if (showDate)
                                    _DateSeparator(date: msg.createdAt),
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
              _InputBar(controller: _msgCtrl, onSend: _send),
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
          Expanded(
              child: Divider(
                  color: AppTheme.ink.withValues(alpha: 0.12), thickness: 1)),
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
          Expanded(
              child: Divider(
                  color: AppTheme.ink.withValues(alpha: 0.12), thickness: 1)),
        ],
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  final String title;
  final bool isOnline;
  const _AppBar({required this.title, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        border: Border(
            bottom: BorderSide(
                color: AppTheme.ink.withValues(alpha: 0.06))),
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
                  style: const TextStyle(
                      color: AppTheme.violet, fontWeight: FontWeight.w800),
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
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppTheme.ink)),
                Text(isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                        fontSize: 11,
                        color: isOnline
                            ? Colors.green.withValues(alpha: 0.9)
                            : Colors.grey,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              decoration: BoxDecoration(
                gradient: isMe
                    ? const LinearGradient(
                        colors: [Color(0xFF9B6DFF), Color(0xFF7B61FF)])
                    : null,
                color: isMe ? null : Colors.white.withValues(alpha: 0.88),
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
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.text,
                    style: TextStyle(
                      color: isMe ? Colors.white : AppTheme.ink,
                      fontSize: 15,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 4),
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
    );
  }
}

class _InputBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _InputBar({required this.controller, required this.onSend});

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() {
      final has = widget.controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        border: Border(
            top: BorderSide(color: AppTheme.ink.withValues(alpha: 0.06))),
      ),
      child: Row(
        children: [
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
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 10),
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
    );
  }
}
