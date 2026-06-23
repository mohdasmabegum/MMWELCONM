import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mmwelconn/models/chat_model.dart';
import 'package:mmwelconn/models/contact_model.dart';
import 'package:mmwelconn/models/user_model.dart';
import 'package:mmwelconn/services/firestore_service.dart';
import 'package:mmwelconn/screens/chat_detail_screen.dart';
import 'package:mmwelconn/widgets/app_brand.dart';

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final fs = FirestoreService();

    return SoftGlowBackground(
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                  child: Text('Chats',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900, color: AppTheme.ink)),
                ),
                Expanded(
                  child: StreamBuilder<List<ChatModel>>(
                    stream: fs.watchMyChats(uid),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final chats = snap.data ?? [];
                      if (chats.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_bubble_outline_rounded,
                                  size: 56, color: AppTheme.ink.withValues(alpha: 0.2)),
                              const SizedBox(height: 14),
                              Text('No chats yet',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.ink.withValues(alpha: 0.4))),
                              const SizedBox(height: 6),
                              Text('Tap + to start a conversation',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.ink.withValues(alpha: 0.3))),
                            ],
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                        itemCount: chats.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => _ChatTile(chat: chats[i], uid: uid),
                      );
                    },
                  ),
                ),
              ],
            ),
            Positioned(
              right: 20,
              bottom: 20,
              child: _NewChatFab(uid: uid, fs: fs),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final ChatModel chat;
  final String uid;

  const _ChatTile({required this.chat, required this.uid});

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final otherName = chat.chatType == ChatType.group
        ? (chat.groupName ?? 'Group')
        : chat.participantNames.entries
            .firstWhere((e) => e.key != uid, orElse: () => const MapEntry('', 'Unknown'))
            .value;
    final unread = chat.unreadCount[uid] ?? 0;
    final initials = otherName.isNotEmpty ? otherName[0].toUpperCase() : '?';

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
          buildPageRoute(ChatDetailScreen(chat: chat, currentUid: uid))),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppTheme.violet.withValues(alpha: 0.15),
              child: Text(initials,
                  style: const TextStyle(
                      color: AppTheme.violet, fontWeight: FontWeight.w800, fontSize: 18)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(otherName,
                          style: TextStyle(
                              fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w600,
                              color: AppTheme.ink,
                              fontSize: 15)),
                      Text(_formatTime(chat.lastMessageAt),
                          style: TextStyle(
                              fontSize: 11,
                              color: unread > 0
                                  ? AppTheme.violet
                                  : AppTheme.ink.withValues(alpha: 0.4))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.lastMessage ?? 'No messages yet',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.normal,
                              color: unread > 0
                                  ? AppTheme.ink.withValues(alpha: 0.75)
                                  : AppTheme.ink.withValues(alpha: 0.45)),
                        ),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.violet,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text('$unread',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ],
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

class _NewChatFab extends StatelessWidget {
  final String uid;
  final FirestoreService fs;

  const _NewChatFab({required this.uid, required this.fs});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showContactPicker(context),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
              colors: [Color(0xFF9B6DFF), Color(0xFF7B61FF)]),
          boxShadow: [
            BoxShadow(
                color: AppTheme.violet.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6))
          ],
        ),
        child: const Icon(Icons.edit_rounded, color: Colors.white, size: 22),
      ),
    );
  }

  void _showContactPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ContactPickerSheet(uid: uid, fs: fs),
    );
  }
}

class _ContactPickerSheet extends StatelessWidget {
  final String uid;
  final FirestoreService fs;

  const _ContactPickerSheet({required this.uid, required this.fs});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.65),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: Color(0xFFF6F8FF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppTheme.ink.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999))),
          ),
          const SizedBox(height: 16),
          const Text('New Chat',
              style: TextStyle(
                  fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.ink)),
          const SizedBox(height: 14),
          Expanded(
            child: StreamBuilder<List<ContactModel>>(
              stream: fs.watchContacts(uid, status: ContactStatus.accepted),
              builder: (context, snap) {
                final contacts = snap.data ?? [];
                if (contacts.isEmpty) {
                  return Center(
                    child: Text('No accepted contacts yet.\nAdd contacts first.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.ink.withValues(alpha: 0.4))),
                  );
                }
                return ListView.separated(
                  itemCount: contacts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final c = contacts[i];
                    return GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);
                        final chatId = await fs.getOrCreateDirectChat(
                            uid, '', c.contactUid, c.contactName);
                        final chat = await fs.getChat(chatId);
                        if (chat != null && context.mounted) {
                          Navigator.of(context).push(
                              buildPageRoute(ChatDetailScreen(chat: chat, currentUid: uid)));
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppTheme.violet.withValues(alpha: 0.15),
                              child: Text(
                                c.contactName.isNotEmpty
                                    ? c.contactName[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    color: AppTheme.violet, fontWeight: FontWeight.w800),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(c.contactName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, color: AppTheme.ink)),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
