import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mmwelconn/models/chat_model.dart';
import 'package:mmwelconn/services/firestore_service.dart';
import 'package:mmwelconn/screens/chat_detail_screen.dart';
import 'package:mmwelconn/widgets/app_brand.dart';
import 'package:transparent_image/transparent_image.dart';

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final fs = FirestoreService();

    return SoftGlowBackground(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
              child: Text(
                'Chats',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppTheme.ink,
                    ),
              ),
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
                      child: Text(
                        'No chats yet.\nStart one from Contacts!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.ink.withValues(alpha: 0.45)),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: chats.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _ChatTile(chat: chats[i], uid: uid),
                  );
                },
              ),
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

  void _showChatOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: Colors.red),
                title: const Text('Delete chat'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteChat(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteChat(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat?'),
        content: const Text('Are you sure you want to delete this chat and all its messages? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await FirestoreService().deleteChat(chat.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final otherUserId = chat.participantIds.firstWhere((id) => id != uid, orElse: () => '');
    final otherName = chat.chatType == ChatType.group
        ? (chat.groupName ?? 'Group')
        : chat.participantNames[otherUserId] ?? 'Unknown';
    
    final profileImageUrl = chat.participantProfileImageUrls[otherUserId];

    final unread = chat.unreadCount[uid] ?? 0;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(buildPageRoute(
        ChatDetailScreen(chat: chat, currentUid: uid),
      )),
      onLongPress: () => _showChatOptions(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppTheme.violet.withValues(alpha: 0.18),
              child: profileImageUrl != null && profileImageUrl.isNotEmpty
                  ? ClipOval(
                      child: FadeInImage.memoryNetwork(
                        placeholder: kTransparentImage,
                        image: profileImageUrl,
                        fit: BoxFit.cover,
                        width: 48,
                        height: 48,
                      ),
                    )
                  : Text(
                      otherName.isNotEmpty ? otherName[0].toUpperCase() : '?',
                      style: const TextStyle(color: AppTheme.violet, fontWeight: FontWeight.w800, fontSize: 18),
                    ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(otherName, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.ink)),
                  const SizedBox(height: 3),
                  Text(
                    chat.lastMessage ?? 'No messages yet',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: AppTheme.ink.withValues(alpha: 0.5)),
                  ),
                ],
              ),
            ),
            if (unread > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.violet,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$unread',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
