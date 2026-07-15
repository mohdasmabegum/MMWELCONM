import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mmwelconn/models/chat_model.dart';
import 'package:mmwelconn/models/contact_model.dart';
import 'package:mmwelconn/models/user_model.dart';
import 'package:mmwelconn/services/cloudinary_service.dart';
import 'package:mmwelconn/services/firestore_service.dart';
import 'package:mmwelconn/screens/profile_screen.dart';
import 'package:mmwelconn/widgets/app_brand.dart';

class ChatDetailScreen extends StatefulWidget {
  static String? activeChatId;
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

  String get _myName =>
      widget.chat.participantNames[widget.currentUid] ?? 'Me';

  String get _otherName {
    if (widget.chat.chatType == ChatType.group) {
      return widget.chat.groupName ?? 'Group';
    }
    return widget.chat.participantNames.entries
        .firstWhere((e) => e.key != widget.currentUid,
            orElse: () => const MapEntry('', 'Unknown'))
        .value;
  }

  String get _otherUid {
    if (widget.chat.chatType == ChatType.group) return '';
    return widget.chat.participantIds.firstWhere(
      (id) => id != widget.currentUid,
      orElse: () => '',
    );
  }

  @override
  void initState() {
    super.initState();
    ChatDetailScreen.activeChatId = widget.chat.id;
    _fs.clearUnread(widget.chat.id, widget.currentUid);
    _fs.markMessagesAsSeen(widget.chat.id, widget.currentUid);
  }

  @override
  void dispose() {
    if (ChatDetailScreen.activeChatId == widget.chat.id) {
      ChatDetailScreen.activeChatId = null;
    }
    _msgCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _sendImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    try {
      final bytes = await file.readAsBytes();
      final url = await CloudinaryService.uploadBytes(bytes, widget.currentUid, file.name);
      await _fs.sendMessage(
        widget.chat.id,
        MessageModel(
          id: '',
          senderId: widget.currentUid,
          senderName: _myName,
          text: '',
          imageUrl: url,
          createdAt: DateTime.now(),
        ),
        widget.chat.participantIds,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send image: $e')),
      );
    }
  }

  Future<void> _sendFromCamera() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (file == null) return;
    try {
      final bytes = await file.readAsBytes();
      final url = await CloudinaryService.uploadBytes(bytes, widget.currentUid, file.name);
      await _fs.sendMessage(
        widget.chat.id,
        MessageModel(
          id: '',
          senderId: widget.currentUid,
          senderName: _myName,
          text: '',
          imageUrl: url,
          createdAt: DateTime.now(),
        ),
        widget.chat.participantIds,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send image: $e')),
      );
    }
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
              if (_otherUid.isEmpty)
                _AppBar(title: _otherName)
              else
                StreamBuilder<UserModel?>(
                  stream: _fs.watchUser(_otherUid),
                  builder: (context, snap) {
                    final user = snap.data;
                    return _AppBar(
                      title: _otherName,
                      subtitle: user == null
                          ? 'Offline'
                          : user.hasActiveMood && user.currentMoodId != null
                              ? 'Mood: ${user.currentMoodId} • ${user.status}'
                              : user.status == 'online'
                                  ? 'Online'
                                  : 'Offline',
                      photoUrl: widget.chat.participantProfileImageUrls[_otherUid] ?? user?.profileImageUrl ?? '',
                      onTitleTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProfileScreen(
                              userId: _otherUid,
                              viewerUid: widget.currentUid,
                              contact: ContactModel(
                                id: _otherUid,
                                ownerUid: widget.currentUid,
                                contactUid: _otherUid,
                                contactName: _otherName,
                                contactPhotoUrl: widget.chat.participantProfileImageUrls[_otherUid] ?? user?.profileImageUrl ?? '',
                                addedAt: DateTime.now(),
                                relationshipType: RelationshipType.friend,
                                status: ContactStatus.accepted,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              Expanded(
                child: StreamBuilder<List<MessageModel>>(
                  stream: _fs.watchMessages(widget.chat.id),
                  builder: (context, snap) {
                    final msgs = snap.data ?? [];
                    if (msgs.isNotEmpty) {
                      _fs.markMessagesAsSeen(widget.chat.id, widget.currentUid);
                    }
                    if (msgs.isEmpty && snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (msgs.isEmpty) {
                      return Center(
                        child: Text(
                          'Say hello! 👋',
                          style: TextStyle(color: AppTheme.ink.withValues(alpha: 0.45)),
                        ),
                      );
                    }
                    return ListView.builder(
                      controller: _scroll,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: msgs.length,
                      itemBuilder: (_, i) => _MessageBubble(
                        msg: msgs[i],
                        isMe: msgs[i].senderId == widget.currentUid,
                      ),
                    );
                  },
                ),
              ),
              _InputBar(
                controller: _msgCtrl,
                onSend: _send,
                onSendImage: _sendImage,
                onSendCamera: _sendFromCamera,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? photoUrl;
  final VoidCallback? onTitleTap;
  const _AppBar({required this.title, this.subtitle, this.photoUrl, this.onTitleTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.ink),
            onPressed: () => Navigator.of(context).pop(),
          ),
          GestureDetector(
            onTap: onTitleTap,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty) ? NetworkImage(photoUrl!) : null,
                  backgroundColor: AppTheme.violet.withValues(alpha: 0.18),
                  child: (photoUrl == null || photoUrl!.isEmpty)
                      ? Text(
                          title.isNotEmpty ? title[0].toUpperCase() : '?',
                          style: const TextStyle(color: AppTheme.violet, fontWeight: FontWeight.w800),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.ink)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!, style: TextStyle(color: AppTheme.ink.withValues(alpha: 0.56), fontSize: 12)),
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

class _MessageBubble extends StatelessWidget {
  final MessageModel msg;
  final bool isMe;

  const _MessageBubble({required this.msg, required this.isMe});

  Widget _buildStatusTicks(String status) {
    final bool seen = status == 'seen';
    final bool delivered = status == 'delivered' || seen;
    
    final Color color = seen ? const Color(0xFF00E5FF) : Colors.white.withValues(alpha: 0.7);
    
    if (delivered) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1),
            ),
            child: Icon(Icons.check, size: 7, color: color),
          ),
          const SizedBox(width: 2),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1),
            ),
            child: Icon(Icons.check, size: 7, color: color),
          ),
        ],
      );
    } else {
      return Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1),
        ),
        child: Icon(Icons.check, size: 7, color: color),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = msg.imageUrl != null && msg.imageUrl!.isNotEmpty;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isMe ? 18 : 4),
      bottomRight: Radius.circular(isMe ? 4 : 18),
    );
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
        decoration: BoxDecoration(
          gradient: (!hasImage && isMe)
              ? const LinearGradient(colors: [Color(0xFF9B6DFF), Color(0xFF7B61FF)])
              : null,
          color: hasImage ? Colors.transparent : (isMe ? null : Colors.white.withValues(alpha: 0.82)),
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: hasImage
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ClipRRect(
                    borderRadius: borderRadius,
                    child: Image.network(
                      msg.imageUrl!,
                      width: 200,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(Icons.broken_image_rounded),
                      ),
                    ),
                  ),
                  if (isMe)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 4, 8, 4),
                      child: _buildStatusTicks(msg.status),
                    ),
                ],
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      msg.text,
                      style: TextStyle(
                        color: isMe ? Colors.white : AppTheme.ink,
                        fontSize: 15,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(height: 6),
                      _buildStatusTicks(msg.status),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onSendImage;
  final VoidCallback onSendCamera;

  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.onSendImage,
    required this.onSendCamera,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.camera_alt_rounded, color: AppTheme.violet),
            onPressed: onSendCamera,
            tooltip: 'Camera',
          ),
          IconButton(
            icon: const Icon(Icons.photo_library_rounded, color: AppTheme.sky),
            onPressed: onSendImage,
            tooltip: 'Gallery',
          ),
          Expanded(
            child: TextField(
              controller: controller,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.88),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF9B6DFF), Color(0xFF7B61FF)],
                ),
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
