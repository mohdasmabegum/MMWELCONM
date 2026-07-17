import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mmwelconn/models/chat_model.dart';
import 'package:mmwelconn/models/contact_model.dart';
import 'package:mmwelconn/services/firestore_service.dart';
import 'package:mmwelconn/screens/chat_detail_screen.dart';
import 'package:mmwelconn/screens/create_group_screen.dart';
import 'package:mmwelconn/widgets/app_brand.dart';
import 'package:transparent_image/transparent_image.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  bool _showLockedChats = false;
  int _failedUnlockAttempts = 0;

  void _handleUnlockFailure(String uid) async {
    _failedUnlockAttempts++;
    final left = 3 - _failedUnlockAttempts;
    if (_failedUnlockAttempts >= 3) {
      _failedUnlockAttempts = 0;
      await _selfDestructLockedChats(uid);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('🚨 Security Alert', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            content: const Text('Maximum passcode attempts reached. All locked chats and messages have been permanently deleted from this account.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } else {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Incorrect Passcode', style: TextStyle(fontWeight: FontWeight.bold)),
            content: Text('The passcode you entered is incorrect.\nAttempts left: $left/3.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _selfDestructLockedChats(String uid) async {
    final fs = FirestoreService();
    // Fetch current list of chats to delete locked ones
    final chats = await fs.watchMyChats(uid).first;
    for (var chat in chats) {
      if (chat.lockedBy[uid] == true) {
        await fs.deleteChat(chat.id);
      }
    }
  }

  Future<void> _toggleLockedChats() async {
    if (_showLockedChats) {
      setState(() => _showLockedChats = false);
      return;
    }

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userDoc = await FirestoreService().getUser(uid);
    final pin = userDoc?.chatLockPin ?? '1234';
    final pattern = userDoc?.chatLockPattern ?? '';

    if (!mounted) return;

    if (pattern.isNotEmpty) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => PatternUnlockDialog(
          correctPattern: pattern,
          onResult: (success) {
            Navigator.pop(context);
            if (success) {
              _failedUnlockAttempts = 0;
              setState(() => _showLockedChats = true);
            } else {
              _handleUnlockFailure(uid);
            }
          },
        ),
      );
    } else {
      _showPinUnlockDialog(pin, uid);
    }
  }

  void _showPinUnlockDialog(String correctPin, String uid) {
    final pinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Lock PIN', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.ink)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: TextField(
          controller: pinCtrl,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter 4-digit PIN',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (pinCtrl.text == correctPin) {
                _failedUnlockAttempts = 0;
                setState(() => _showLockedChats = true);
              } else {
                _handleUnlockFailure(uid);
              }
            },
            child: const Text('Verify', style: TextStyle(color: AppTheme.violet, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showStartChatSheet(BuildContext context, String currentUid) {
    final fs = FirestoreService();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'Start Chat',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.ink),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: StreamBuilder<List<ContactModel>>(
                    stream: fs.watchContacts(currentUid, status: ContactStatus.accepted),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final contacts = snap.data ?? [];
                      if (contacts.isEmpty) {
                        return Center(
                          child: Text(
                            'No connections found.\nAdd contacts on Connections screen!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.ink.withValues(alpha: 0.45)),
                          ),
                        );
                      }
                      return ListView.separated(
                        itemCount: contacts.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, idx) {
                          final c = contacts[idx];
                          return HoverCard(
                            child: ListTile(
                              onTap: () {
                                final nav = Navigator.of(context);
                                nav.pop(); // Pop bottom sheet
                                
                                final ids = [currentUid, c.contactUid]..sort();
                                final chatId = ids.join('_');
                                final chatShell = ChatModel(
                                  id: chatId,
                                  chatType: ChatType.direct,
                                  participantIds: [currentUid, c.contactUid],
                                  participantNames: {
                                    currentUid: 'Me',
                                    c.contactUid: c.contactName,
                                  },
                                  participantProfileImageUrls: {
                                    currentUid: '',
                                    c.contactUid: c.contactPhotoUrl,
                                  },
                                );

                                nav.push(
                                  MaterialPageRoute(
                                    builder: (_) => ChatDetailScreen(
                                      chat: chatShell,
                                      currentUid: currentUid,
                                    ),
                                  ),
                                );

                                fs.getOrCreateDirectChat(currentUid, c.contactUid);
                              },
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              tileColor: Colors.grey.shade50,
                              leading: CircleAvatar(
                                radius: 20,
                                backgroundImage: c.contactPhotoUrl.isNotEmpty ? NetworkImage(c.contactPhotoUrl) : null,
                                backgroundColor: AppTheme.violet.withValues(alpha: 0.18),
                                child: c.contactPhotoUrl.isEmpty
                                    ? Text(
                                        c.contactName.isNotEmpty ? c.contactName[0].toUpperCase() : '?',
                                        style: const TextStyle(color: AppTheme.violet, fontWeight: FontWeight.bold),
                                      )
                                    : null,
                              ),
                              title: Text(c.contactName, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.ink)),
                              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

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
              padding: const EdgeInsets.fromLTRB(16, 20, 20, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (_showLockedChats)
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.ink),
                          onPressed: () => setState(() => _showLockedChats = false),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      if (_showLockedChats) const SizedBox(width: 8),
                      Text(
                        _showLockedChats ? 'Locked Chats' : 'Chats',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppTheme.ink,
                            ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _showLockedChats ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                          color: AppTheme.violet,
                        ),
                        onPressed: _toggleLockedChats,
                        tooltip: 'Locked Chats',
                      ),
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppTheme.violet),
                        onPressed: () => _showStartChatSheet(context, uid),
                        tooltip: 'New Chat',
                      ),
                      IconButton(
                        icon: const Icon(Icons.group_add_rounded, color: AppTheme.violet),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const CreateGroupScreen(),
                            ),
                          );
                        },
                        tooltip: 'Create Group Chat',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<List<ChatModel>>(
                stream: fs.watchMyChats(uid),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final allChats = snap.data ?? [];
                  final chats = allChats.where((chat) {
                    final isLocked = chat.lockedBy[uid] ?? false;
                    final isHidden = chat.hiddenBy[uid] ?? false;
                    if (_showLockedChats) {
                      return isLocked;
                    } else {
                      return !isLocked && !isHidden;
                    }
                  }).toList();

                  if (chats.isEmpty) {
                    return Center(
                      child: Text(
                        _showLockedChats
                            ? 'No locked chats.'
                            : 'No chats yet.\nStart one from Contacts!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.ink.withValues(alpha: 0.45)),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: chats.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => HoverCard(
                      child: _ChatTile(chat: chats[i], uid: uid),
                    ),
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
    final bool isLocked = chat.lockedBy[uid] ?? false;
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
                leading: Icon(
                  isLocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                  color: AppTheme.violet,
                ),
                title: Text(isLocked ? 'Unlock chat' : 'Lock/Hide chat'),
                onTap: () async {
                  Navigator.pop(context);
                  await FirestoreService().toggleChatLock(chat.id, uid, !isLocked);
                },
              ),
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
    final otherUserId = chat.chatType == ChatType.group
        ? ''
        : chat.participantIds.firstWhere((id) => id != uid, orElse: () => '');
    final otherName = chat.chatType == ChatType.group
        ? (chat.groupName ?? 'Group')
        : chat.participantNames[otherUserId] ?? 'Unknown';
    
    final profileImageUrl = chat.chatType == ChatType.group
        ? null
        : chat.participantProfileImageUrls[otherUserId];

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

class PatternUnlockDialog extends StatefulWidget {
  final String correctPattern;
  final ValueChanged<bool> onResult;

  const PatternUnlockDialog({super.key, required this.correctPattern, required this.onResult});

  @override
  State<PatternUnlockDialog> createState() => _PatternUnlockDialogState();
}

class _PatternUnlockDialogState extends State<PatternUnlockDialog> {
  final List<int> _selectedIndices = [];

  void _onDotTap(int index) {
    if (_selectedIndices.contains(index)) return;
    setState(() {
      _selectedIndices.add(index);
    });
  }

  void _clear() {
    setState(() {
      _selectedIndices.clear();
    });
  }

  void _verify() {
    final drawn = _selectedIndices.join('');
    widget.onResult(drawn == widget.correctPattern);
  }

  void _checkPosition(Offset localPos) {
    final x = localPos.dx;
    final y = localPos.dy;
    if (x >= 0 && x <= 200 && y >= 0 && y <= 200) {
      final col = (x / (200 / 3)).floor().clamp(0, 2);
      final row = (y / (200 / 3)).floor().clamp(0, 2);
      final idx = row * 3 + col;
      _onDotTap(idx);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Draw Lock Pattern', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.ink)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Tap or drag the dots in sequence to unlock.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 20),
          GestureDetector(
            onPanStart: (details) => _checkPosition(details.localPosition),
            onPanUpdate: (details) => _checkPosition(details.localPosition),
            child: SizedBox(
              width: 200,
              height: 200,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 9,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                ),
                itemBuilder: (context, idx) {
                  final isSelected = _selectedIndices.contains(idx);
                  final selectionOrder = _selectedIndices.indexOf(idx) + 1;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? AppTheme.violet.withValues(alpha: 0.15) : Colors.white,
                      border: Border.all(
                        color: isSelected ? AppTheme.violet : Colors.grey.shade300,
                        width: isSelected ? 3 : 1.5,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(color: AppTheme.violet.withValues(alpha: 0.3), blurRadius: 8)]
                          : null,
                    ),
                    child: Center(
                      child: isSelected
                          ? Text(
                              '$selectionOrder',
                              style: const TextStyle(color: AppTheme.violet, fontWeight: FontWeight.bold, fontSize: 16),
                            )
                          : Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey.shade400)),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => widget.onResult(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _clear,
          child: const Text('Clear'),
        ),
        TextButton(
          onPressed: _verify,
          child: const Text('Verify', style: TextStyle(color: AppTheme.violet, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
