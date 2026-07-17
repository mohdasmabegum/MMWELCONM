import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mmwelconn/models/chat_model.dart';
import 'package:mmwelconn/models/contact_model.dart';
import 'package:mmwelconn/models/user_model.dart';
import 'package:mmwelconn/services/cloudinary_service.dart';
import 'package:mmwelconn/services/firestore_service.dart';
import 'package:mmwelconn/screens/profile_screen.dart';
import 'package:mmwelconn/screens/reminders_screen.dart';
import 'package:mmwelconn/screens/home_screen.dart';
import 'package:mmwelconn/widgets/app_brand.dart';
import 'package:share_plus/share_plus.dart';

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
  bool _selectionMode = false;
  final Set<String> _selectedMessageIds = {};
  XFile? _attachedImage;
  bool _isUploadingImage = false;
  Timer? _typingTimer;
  bool _isTyping = false;
  bool _showGroupDetails = false;
  bool _showDirectDetails = false;
  bool _editingDesc = false;
  bool _editingName = false;
  final TextEditingController _descEditCtrl = TextEditingController();
  final TextEditingController _nameEditCtrl = TextEditingController();
  final TextEditingController _customCatCtrl = TextEditingController();

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

  RelationshipType? _relationshipType;
  StreamSubscription<ContactModel?>? _contactSub;

  @override
  void initState() {
    super.initState();
    ChatDetailScreen.activeChatId = widget.chat.id;
    _fs.clearUnread(widget.chat.id, widget.currentUid);
    _fs.markMessagesAsSeen(widget.chat.id, widget.currentUid);

    if (_otherUid.isNotEmpty) {
      _contactSub = _fs.watchContact(widget.currentUid, _otherUid).listen((contact) {
        if (mounted) {
          setState(() {
            _relationshipType = contact?.relationshipType;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    if (ChatDetailScreen.activeChatId == widget.chat.id) {
      ChatDetailScreen.activeChatId = null;
    }
    _contactSub?.cancel();
    _typingTimer?.cancel();
    _fs.setTypingStatus(widget.chat.id, widget.currentUid, false);
    _msgCtrl.dispose();
    _scroll.dispose();
    _descEditCtrl.dispose();
    _nameEditCtrl.dispose();
    _customCatCtrl.dispose();
    super.dispose();
  }

  void _onTextChanged(String text) {
    if (text.isEmpty) {
      if (_isTyping) {
        _isTyping = false;
        _fs.setTypingStatus(widget.chat.id, widget.currentUid, false);
      }
      _typingTimer?.cancel();
      return;
    }

    if (!_isTyping) {
      _isTyping = true;
      _fs.setTypingStatus(widget.chat.id, widget.currentUid, true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && _isTyping) {
        setState(() {
          _isTyping = false;
        });
        _fs.setTypingStatus(widget.chat.id, widget.currentUid, false);
      }
    });
  }

  Future<void> _sendImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    setState(() {
      _attachedImage = file;
    });
  }

  Future<void> _sendFromCamera() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (file == null) return;
    setState(() {
      _attachedImage = file;
    });
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty && _attachedImage == null) return;
    if (_isUploadingImage) return;

    if (_attachedImage != null) {
      setState(() => _isUploadingImage = true);
      try {
        final bytes = await _attachedImage!.readAsBytes();
        final url = await CloudinaryService.uploadBytes(bytes, widget.currentUid, _attachedImage!.name);
        
        await _fs.sendMessage(
          widget.chat.id,
          MessageModel(
            id: '',
            senderId: widget.currentUid,
            senderName: _myName,
            text: text,
            imageUrl: url,
            createdAt: DateTime.now(),
          ),
          widget.chat.participantIds,
        );
        
        setState(() {
          _attachedImage = null;
        });
        _msgCtrl.clear();
        if (_isTyping) {
          _isTyping = false;
          _fs.setTypingStatus(widget.chat.id, widget.currentUid, false);
        }
        _typingTimer?.cancel();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send image: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isUploadingImage = false);
        }
      }
    } else {
      _msgCtrl.clear();
      if (_isTyping) {
        _isTyping = false;
        _fs.setTypingStatus(widget.chat.id, widget.currentUid, false);
      }
      _typingTimer?.cancel();
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
  }

  void _confirmDeleteChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chat?'),
        content: const Text('Are you sure you want to delete this entire chat and all its messages? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _fs.deleteChat(widget.chat.id);
              if (mounted) {
                Navigator.pop(context); // close dialog
                Navigator.pop(context); // close chat screen
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showMessageOptions(MessageModel msg) {
    final bool isMe = msg.senderId == widget.currentUid;
    final bool canEdit = isMe && (msg.imageUrl == null || msg.imageUrl!.isEmpty) &&
        DateTime.now().difference(msg.createdAt).inMinutes < 15;

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
              if (canEdit)
                ListTile(
                  leading: const Icon(Icons.edit_rounded, color: AppTheme.violet),
                  title: const Text('Edit message'),
                  onTap: () {
                    Navigator.pop(context);
                    _showEditDialog(msg);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.delete_rounded, color: Colors.red),
                title: const Text('Delete message'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteMessage(msg);
                },
              ),
              ListTile(
                leading: const Icon(Icons.checklist_rounded, color: AppTheme.violet),
                title: const Text('Select multiple'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectionMode = true;
                    _selectedMessageIds.add(msg.id);
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month_rounded, color: AppTheme.violet),
                title: const Text('Add to Schedules'),
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => AddReminderSheet(
                      prefilledDescription: msg.text,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded, color: AppTheme.violet),
                title: const Text('Message info'),
                onTap: () {
                  Navigator.pop(context);
                  _showMessageInfo(msg);
                },
              ),
              if (msg.imageUrl != null && msg.imageUrl!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.ios_share_rounded, color: AppTheme.violet),
                  title: const Text('Share image'),
                  onTap: () {
                    Navigator.pop(context);
                    Share.share(msg.imageUrl!, subject: 'Shared Photo');
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessageInfo(MessageModel msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(24),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Message Info',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.ink),
              ),
              const SizedBox(height: 16),
              _InfoRow(label: 'Sender', value: msg.senderName),
              _InfoRow(label: 'Content', value: msg.text.isNotEmpty ? msg.text : 'Photo 📷'),
              _InfoRow(
                label: 'Sent',
                value: '${msg.createdAt.day}/${msg.createdAt.month}/${msg.createdAt.year} at ${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}',
              ),
              _InfoRow(
                label: 'Status',
                value: msg.status == 'seen'
                    ? 'Read (Seen)'
                    : msg.status == 'delivered'
                        ? 'Delivered'
                        : 'Sent',
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.violet,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(MessageModel msg) {
    final editCtrl = TextEditingController(text: msg.text);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit message'),
        content: TextField(
          controller: editCtrl,
          decoration: const InputDecoration(
            hintText: 'Enter new message...',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newText = editCtrl.text.trim();
              if (newText.isNotEmpty && newText != msg.text) {
                await _fs.editMessage(widget.chat.id, msg.id, newText);
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Save', style: TextStyle(color: AppTheme.violet)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteMessage(MessageModel msg) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text('Are you sure you want to delete this message? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await _fs.deleteMessage(widget.chat.id, msg.id);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmBulkDelete() {
    if (_selectedMessageIds.isEmpty) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Messages?'),
        content: Text('Are you sure you want to delete ${_selectedMessageIds.length} selected messages? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final ids = List<String>.from(_selectedMessageIds);
              setState(() {
                _selectionMode = false;
                _selectedMessageIds.clear();
              });
              Navigator.pop(context);
              for (var id in ids) {
                await _fs.deleteMessage(widget.chat.id, id);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _toggleMessageSelection(String msgId) {
    setState(() {
      if (_selectedMessageIds.contains(msgId)) {
        _selectedMessageIds.remove(msgId);
        if (_selectedMessageIds.isEmpty) {
          _selectionMode = false;
        }
      } else {
        _selectedMessageIds.add(msgId);
      }
    });
  }

  String _formatLastActive(DateTime lastActive) {
    final now = DateTime.now();
    final diff = now.difference(lastActive);
    if (diff.inSeconds < 60) {
      return 'Last active just now';
    } else if (diff.inMinutes < 60) {
      return 'Last active ${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return 'Last active ${diff.inHours}h ago';
    } else {
      return 'Last active ${diff.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatingChatBackground(
        relationshipType: _relationshipType,
        child: SafeArea(
          child: Column(
            children: [
              if (_selectionMode)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.88),
                    border: Border(bottom: BorderSide(color: Colors.black.withValues(alpha: 0.08))),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppTheme.ink),
                        onPressed: () {
                          setState(() {
                            _selectionMode = false;
                            _selectedMessageIds.clear();
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_selectedMessageIds.length} Selected',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.ink),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.delete_rounded, color: Colors.red),
                        onPressed: _confirmBulkDelete,
                      ),
                    ],
                  ),
                )
              else
                StreamBuilder<ChatModel?>(
                  stream: _fs.watchChat(widget.chat.id),
                  initialData: widget.chat,
                  builder: (context, chatSnap) {
                    final chat = chatSnap.data ?? widget.chat;
                    final discloseSelf = chat.discloseOnlineStatus[widget.currentUid] ?? true;
                    final discloseOther = chat.discloseOnlineStatus[_otherUid] ?? true;

                    final typingUsers = chat.typingStatus.entries
                        .where((e) => e.key != widget.currentUid && e.value == true)
                        .map((e) => chat.participantNames[e.key] ?? 'Someone')
                        .toList();
                    final bool isSomeoneTyping = typingUsers.isNotEmpty;

                    if (_otherUid.isEmpty) {
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _AppBar(
                            title: _otherName,
                            subtitle: isSomeoneTyping ? '${typingUsers.join(', ')} typing...' : null,
                            onDeleteChat: _confirmDeleteChat,
                            discloseOnline: discloseSelf,
                            onToggleDisclose: (val) => _fs.updateOnlineDisclosure(chat.id, widget.currentUid, val),
                            isOnline: false,
                            relationshipType: null,
                            onTitleTap: () => setState(() => _showGroupDetails = !_showGroupDetails),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            child: _showGroupDetails
                                ? _buildGroupDetailsPanel(context, chat)
                                : const SizedBox.shrink(),
                          ),
                        ],
                      );
                    }

                    return StreamBuilder<UserModel?>(
                      stream: _fs.watchUser(_otherUid),
                      builder: (context, snap) {
                        final user = snap.data;
                        final bool isOnline = user?.status == 'online';
                        final String finalStatus;
                        if (!discloseOther) {
                          finalStatus = 'Offline';
                        } else {
                          finalStatus = user == null
                              ? 'Offline'
                              : isOnline
                                  ? 'Online'
                                  : _formatLastActive(user.lastActive);
                        }
                        
                        final subtitle = isSomeoneTyping
                            ? 'Typing...'
                            : (user != null && user.hasActiveMood && user.currentMoodId != null
                                ? 'Mood: ${user.currentMoodId} • $finalStatus'
                                : finalStatus);

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _AppBar(
                              title: _otherName,
                              subtitle: subtitle,
                              photoUrl: chat.participantProfileImageUrls[_otherUid] ?? user?.profileImageUrl ?? '',
                              onDeleteChat: _confirmDeleteChat,
                              discloseOnline: discloseSelf,
                              onToggleDisclose: (val) => _fs.updateOnlineDisclosure(chat.id, widget.currentUid, val),
                              isOnline: isOnline,
                              relationshipType: _relationshipType,
                              onTitleTap: () {
                                setState(() => _showDirectDetails = !_showDirectDetails);
                              },
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                              child: _showDirectDetails && user != null
                                  ? StreamBuilder<ContactModel?>(
                                      stream: _fs.watchContact(widget.currentUid, _otherUid),
                                      builder: (context, contactSnap) {
                                        return _buildDirectDetailsPanel(context, chat, user, contactSnap.data);
                                      },
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
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
                      itemBuilder: (_, i) {
                        final msg = msgs[i];
                        final isSelected = _selectedMessageIds.contains(msg.id);
                        return GestureDetector(
                          onTap: _selectionMode ? () => _toggleMessageSelection(msg.id) : null,
                          onLongPress: _selectionMode 
                              ? () => _toggleMessageSelection(msg.id) 
                              : () => _showMessageOptions(msg),
                          onDoubleTap: _selectionMode 
                              ? null 
                              : () => _showMessageOptions(msg),
                          child: FadeInSlideWidget(
                            child: _MessageBubble(
                              msg: msg,
                              isMe: msg.senderId == widget.currentUid,
                              selectionMode: _selectionMode,
                              isSelected: isSelected,
                              relationshipType: _relationshipType,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              if (_attachedImage != null)
                Padding(
                  padding: const EdgeInsets.only(left: 20, bottom: 8),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.violet.withValues(alpha: 0.3)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: kIsWeb
                                  ? FutureBuilder<Uint8List>(
                                      future: _attachedImage!.readAsBytes(),
                                      builder: (context, snapshot) {
                                        if (snapshot.hasData) {
                                          return Image.memory(
                                            snapshot.data!,
                                            width: 80,
                                            height: 80,
                                            fit: BoxFit.cover,
                                          );
                                        }
                                        return const Center(child: CircularProgressIndicator());
                                      },
                                    )
                                  : Image.file(
                                      File(_attachedImage!.path),
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                          Positioned(
                            right: 4,
                            top: 4,
                            child: GestureDetector(
                              onTap: _isUploadingImage
                                  ? null
                                  : () {
                                      setState(() {
                                        _attachedImage = null;
                                      });
                                    },
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ),
                          if (_isUploadingImage)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black38,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(color: Colors.white),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              _InputBar(
                controller: _msgCtrl,
                onSend: _isUploadingImage ? () {} : _send,
                onSendImage: _isUploadingImage ? () {} : _sendImage,
                onSendCamera: _isUploadingImage ? () {} : _sendFromCamera,
                onChanged: _onTextChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGroupDetailsPanel(BuildContext context, ChatModel chat) {
    final createdDateStr = chat.groupCreatedAt != null
        ? '${chat.groupCreatedAt!.day} ${_getMonthName(chat.groupCreatedAt!.month)} ${chat.groupCreatedAt!.year}'
        : 'N/A';

    final category = chat.groupCategory ?? 'Friends';
    final creatorId = chat.groupCreatedBy ?? '';
    final creatorName = chat.participantNames[creatorId] ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.violet.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.group_rounded, color: AppTheme.violet, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: _editingName
                    ? TextField(
                        controller: _nameEditCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Group Name',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 4),
                        ),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.ink),
                      )
                    : Text(
                        chat.groupName ?? 'Group',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.ink),
                      ),
              ),
              IconButton(
                icon: Icon(_editingName ? Icons.check_circle_rounded : Icons.edit_rounded,
                    color: AppTheme.violet, size: 20),
                onPressed: () async {
                  if (_editingName) {
                    final newName = _nameEditCtrl.text.trim();
                    if (newName.isNotEmpty) {
                      await _fs.updateGroupDetails(chat.id, name: newName);
                    }
                    setState(() => _editingName = false);
                  } else {
                    _nameEditCtrl.text = chat.groupName ?? '';
                    setState(() => _editingName = true);
                  }
                },
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('Description:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
              const Spacer(),
              IconButton(
                icon: Icon(_editingDesc ? Icons.check_circle_rounded : Icons.edit_rounded,
                    color: AppTheme.violet, size: 18),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
                onPressed: () async {
                  if (_editingDesc) {
                    await _fs.updateGroupDetails(chat.id, description: _descEditCtrl.text.trim());
                    setState(() => _editingDesc = false);
                  } else {
                    _descEditCtrl.text = chat.groupDescription ?? '';
                    setState(() => _editingDesc = true);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          _editingDesc
              ? TextField(
                  controller: _descEditCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Enter group description...',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.all(8),
                  ),
                  style: const TextStyle(fontSize: 13, color: AppTheme.ink),
                )
              : Text(
                  chat.groupDescription == null || chat.groupDescription!.isEmpty
                      ? 'No description added yet.'
                      : chat.groupDescription!,
                  style: TextStyle(fontSize: 13, color: AppTheme.ink.withValues(alpha: 0.8)),
                ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Text(
                'Created on: $createdDateStr',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              if (creatorName.isNotEmpty) ...[
                const SizedBox(width: 12),
                const Icon(Icons.person_rounded, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  'By: $creatorName',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          const Text('Category:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: ['Professional', 'Friends', 'Family', 'Others'].contains(category) ? category : 'Others',
                      isExpanded: true,
                      style: const TextStyle(color: AppTheme.ink, fontSize: 13),
                      items: ['Professional', 'Friends', 'Family', 'Others']
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (val) async {
                        if (val != null) {
                          if (val == 'Others') {
                            _customCatCtrl.text = '';
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Custom Category', style: TextStyle(fontWeight: FontWeight.bold)),
                                content: TextField(
                                  controller: _customCatCtrl,
                                  decoration: const InputDecoration(hintText: 'Enter custom category name...'),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                                  TextButton(
                                    onPressed: () async {
                                      final customVal = _customCatCtrl.text.trim();
                                      if (customVal.isNotEmpty) {
                                        await _fs.updateGroupDetails(chat.id, category: '$customVal (Others)');
                                      }
                                      if (context.mounted) Navigator.pop(context);
                                    },
                                    child: const Text('Save', style: TextStyle(color: AppTheme.violet, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            );
                          } else {
                            await _fs.updateGroupDetails(chat.id, category: val);
                          }
                        }
                      },
                    ),
                  ),
                ),
              ),
              if (!['Professional', 'Friends', 'Family', 'Others'].contains(category)) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: AppTheme.pink.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                  child: Text(category, style: const TextStyle(color: AppTheme.pink, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'People (${chat.participantIds.length}):',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: chat.participantIds.length,
              itemBuilder: (context, idx) {
                final pId = chat.participantIds[idx];
                final name = chat.participantNames[pId] ?? 'Unknown';
                final photoUrl = chat.participantProfileImageUrls[pId] ?? '';
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Tooltip(
                    message: name,
                    child: CircleAvatar(
                      radius: 20,
                      backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      backgroundColor: AppTheme.violet.withValues(alpha: 0.1),
                      child: photoUrl.isEmpty
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: const TextStyle(color: AppTheme.violet, fontSize: 12, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getRelationColor(RelationshipType? type) {
    if (type == null) return Colors.grey;
    switch (type) {
      case RelationshipType.family:
        return const Color(0xFF059669); // Dark emerald green
      case RelationshipType.friend:
        return AppTheme.violet;
      case RelationshipType.partner:
        return AppTheme.pink;
      case RelationshipType.other:
        return Colors.blueGrey;
    }
  }

  Widget _buildDirectDetailsPanel(BuildContext context, ChatModel chat, UserModel user, ContactModel? contact) {
    final joinedDateStr = '${user.createdAt.day} ${_getMonthName(user.createdAt.month)} ${user.createdAt.year}';
    final relationship = contact?.relationshipType.name ?? 'friend';
    final isLocked = chat.lockedBy[widget.currentUid] ?? false;
    final isHidden = chat.hiddenBy[widget.currentUid] ?? false;
    final isBlocked = contact?.status == ContactStatus.blocked;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.violet.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () {
              if (user.profilePicture.isNotEmpty) {
                showDialog(
                  context: context,
                  builder: (context) => Dialog(
                    backgroundColor: Colors.transparent,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(user.profilePicture, fit: BoxFit.contain),
                        ),
                      ],
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No profile picture uploaded')),
                );
              }
            },
            child: CircleAvatar(
              radius: 40,
              backgroundImage: user.profilePicture.isNotEmpty ? NetworkImage(user.profilePicture) : null,
              backgroundColor: AppTheme.violet.withValues(alpha: 0.1),
              child: user.profilePicture.isEmpty
                  ? Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                      style: const TextStyle(color: AppTheme.violet, fontSize: 24, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user.name,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.ink),
          ),
          const SizedBox(height: 4),
          Text(
            'MM ID: ${user.mmId}',
            style: const TextStyle(color: AppTheme.violet, fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'Joined on: $joinedDateStr',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            'Relation: ${relationship.toUpperCase()}',
            style: TextStyle(color: _getRelationColor(contact?.relationshipType ?? RelationshipType.friend), fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  if (isBlocked) {
                    await _fs.updateContactStatus(widget.currentUid, _otherUid, ContactStatus.accepted);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User unblocked.')));
                  } else {
                    await _fs.updateContactStatus(widget.currentUid, _otherUid, ContactStatus.blocked);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User blocked.')));
                  }
                },
                icon: Icon(isBlocked ? Icons.check_circle_outline : Icons.block_flipped, size: 16),
                label: Text(isBlocked ? 'Unblock' : 'Block'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isBlocked ? Colors.green : Colors.red.shade50,
                  foregroundColor: isBlocked ? Colors.white : Colors.red,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  await _fs.removeContact(widget.currentUid, _otherUid);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection removed.')));
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => HomeScreen(initialTab: 1)),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.person_remove_rounded, size: 16),
                label: const Text('Remove'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  await _fs.toggleChatHide(chat.id, widget.currentUid, !isHidden);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isHidden ? 'Chat unhidden.' : 'Chat hidden.')));
                },
                icon: Icon(isHidden ? Icons.visibility_rounded : Icons.visibility_off_rounded, size: 16),
                label: Text(isHidden ? 'Unhide' : 'Hide'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade100,
                  foregroundColor: AppTheme.ink,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _promptLockChat(context, chat, isLocked),
                icon: Icon(isLocked ? Icons.lock_open_rounded : Icons.lock_rounded, size: 16),
                label: Text(isLocked ? 'Unlock' : 'Lock Chat'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.violet.withValues(alpha: 0.1),
                  foregroundColor: AppTheme.violet,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _promptLockChat(BuildContext context, ChatModel chat, bool isCurrentlyLocked) async {
    if (isCurrentlyLocked) {
      await _fs.toggleChatLock(chat.id, widget.currentUid, false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat unlocked.')));
      return;
    }

    final pinCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Lock PIN to Lock Chat', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.ink)),
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
            onPressed: () async {
              final userDoc = await _fs.getUser(widget.currentUid);
              final correctPin = userDoc?.chatLockPin ?? '1234';
              if (pinCtrl.text == correctPin) {
                await _fs.toggleChatLock(chat.id, widget.currentUid, true);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat added to locked chats.')));
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect PIN!')));
                }
              }
            },
            child: const Text('Lock', style: TextStyle(color: AppTheme.violet, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return (month >= 1 && month <= 12) ? months[month - 1] : '';
  }
}

class HoverOutlineButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const HoverOutlineButton({super.key, required this.child, required this.onTap});

  @override
  State<HoverOutlineButton> createState() => _HoverOutlineButtonState();
}

class _HoverOutlineButtonState extends State<HoverOutlineButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      onShowHoverHighlight: (v) => setState(() => _isHovered = v),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _isHovered ? AppTheme.violet.withValues(alpha: 0.5) : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: widget.child,
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
  final VoidCallback? onDeleteChat;
  final bool discloseOnline;
  final ValueChanged<bool>? onToggleDisclose;
  final bool isOnline;
  final RelationshipType? relationshipType;
  
  final GlobalKey<PopupMenuButtonState<String>> _menuKey = GlobalKey<PopupMenuButtonState<String>>();
  
  _AppBar({
    required this.title,
    this.subtitle,
    this.photoUrl,
    this.onTitleTap,
    this.onDeleteChat,
    this.discloseOnline = true,
    this.onToggleDisclose,
    this.isOnline = false,
    this.relationshipType,
  });

  void _viewProfilePicture(BuildContext context) {
    if (photoUrl == null || photoUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No profile picture uploaded')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(photoUrl!, fit: BoxFit.contain),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRelationBgColor(RelationshipType? type) {
    if (type == null) return Colors.white.withValues(alpha: 0.85);
    switch (type) {
      case RelationshipType.family:
        return const Color(0xFFECFDF5); // Soft emerald/mint
      case RelationshipType.partner:
        return const Color(0xFFFFF0F3); // Soft rose
      case RelationshipType.friend:
        return const Color(0xFFF5F3FF); // Soft lavender
      case RelationshipType.other:
        return const Color(0xFFF1F5F9); // Soft slate
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _getRelationBgColor(relationshipType);
    return Container(
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.ink),
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => HomeScreen(initialTab: 1)),
                (route) => false,
              );
            },
          ),
          Expanded(
            child: GestureDetector(
              onTap: onTitleTap,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _viewProfilePicture(context),
                    child: Stack(
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
                        if (isOnline && discloseOnline)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 11,
                              height: 11,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withValues(alpha: 0.5),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.ink)),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(subtitle!, style: TextStyle(color: AppTheme.ink.withValues(alpha: 0.56), fontSize: 12)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onDeleteChat != null)
            PopupMenuButton<String>(
              key: _menuKey,
              onSelected: (value) {
                if (value == 'delete') {
                  onDeleteChat!();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_rounded, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Text('Delete Chat', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              icon: const Icon(Icons.more_vert_rounded, color: AppTheme.ink),
            ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatefulWidget {
  final MessageModel msg;
  final bool isMe;
  final bool selectionMode;
  final bool isSelected;
  final RelationshipType? relationshipType;

  const _MessageBubble({
    required this.msg,
    required this.isMe,
    this.selectionMode = false,
    this.isSelected = false,
    this.relationshipType,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  bool _hovering = false;

  String _formatTime(DateTime dt) {
    final hr = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$hr:$min';
  }

  Widget _buildStatusTicks(String status) {
    return GlowingStatusIndicator(status: status);
  }

  LinearGradient _getSenderGradient(RelationshipType? type) {
    if (type == null) {
      return const LinearGradient(colors: [Color(0xFF9B6DFF), Color(0xFF7B61FF)]);
    }
    switch (type) {
      case RelationshipType.family:
        return const LinearGradient(colors: [Color(0xFF047857), Color(0xFF10B981)]);
      case RelationshipType.partner:
        return const LinearGradient(colors: [Color(0xFFE11D48), Color(0xFFF43F5E)]);
      case RelationshipType.friend:
        return const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF8B5CF6)]);
      case RelationshipType.other:
        return const LinearGradient(colors: [Color(0xFF475569), Color(0xFF64748B)]);
    }
  }

  Color _getRecipientBgColor(RelationshipType? type) {
    if (type == null) return Colors.white.withValues(alpha: 0.82);
    switch (type) {
      case RelationshipType.family:
        return const Color(0xFFECFDF5);
      case RelationshipType.partner:
        return const Color(0xFFFFF0F3);
      case RelationshipType.friend:
        return const Color(0xFFF5F3FF);
      case RelationshipType.other:
        return const Color(0xFFF1F5F9);
    }
  }

  Color _getRecipientTextColor(RelationshipType? type) {
    if (type == null) return AppTheme.ink;
    switch (type) {
      case RelationshipType.family:
        return const Color(0xFF065F46);
      case RelationshipType.partner:
        return const Color(0xFF9D174D);
      case RelationshipType.friend:
        return const Color(0xFF5B21B6);
      case RelationshipType.other:
        return const Color(0xFF1E293B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.msg.imageUrl != null && widget.msg.imageUrl!.isNotEmpty;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(widget.isMe ? 18 : 4),
      bottomRight: Radius.circular(widget.isMe ? 4 : 18),
    );
    final bubble = Align(
      alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutQuad,
          margin: const EdgeInsets.symmetric(vertical: 4),
          transform: Matrix4.identity()..translate(0.0, _hovering ? -2.0 : 0.0),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
          decoration: BoxDecoration(
            gradient: (!hasImage && widget.isMe)
                ? _getSenderGradient(widget.relationshipType)
                : null,
            color: hasImage ? Colors.transparent : (widget.isMe ? null : _getRecipientBgColor(widget.relationshipType)),
            borderRadius: borderRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _hovering ? 0.12 : 0.06),
                blurRadius: _hovering ? 12 : 8,
                offset: Offset(0, _hovering ? 4 : 2),
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
                        widget.msg.imageUrl!,
                        width: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(Icons.broken_image_rounded),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTime(widget.msg.createdAt),
                            style: TextStyle(
                              color: (widget.isMe ? Colors.white : _getRecipientTextColor(widget.relationshipType)).withValues(alpha: 0.55),
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (widget.msg.isEdited) ...[
                            Text(
                              'edited',
                              style: TextStyle(
                                color: (widget.isMe ? Colors.white : _getRecipientTextColor(widget.relationshipType)).withValues(alpha: 0.55),
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (widget.isMe) _buildStatusTicks(widget.msg.status),
                        ],
                      ),
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
                        widget.msg.text,
                        style: TextStyle(
                          color: widget.isMe ? Colors.white : _getRecipientTextColor(widget.relationshipType),
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatTime(widget.msg.createdAt),
                            style: TextStyle(
                              color: (widget.isMe ? Colors.white : _getRecipientTextColor(widget.relationshipType)).withValues(alpha: 0.55),
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (widget.msg.isEdited) ...[
                            Text(
                              'edited',
                              style: TextStyle(
                                color: (widget.isMe ? Colors.white : _getRecipientTextColor(widget.relationshipType)).withValues(alpha: 0.55),
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (widget.isMe) _buildStatusTicks(widget.msg.status),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );

    if (widget.selectionMode) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!widget.isMe) ...[
              Checkbox(
                value: widget.isSelected,
                shape: const CircleBorder(),
                activeColor: AppTheme.violet,
                onChanged: (_) {}, // handled by parent GestureDetector tap
              ),
              const SizedBox(width: 4),
            ],
            Expanded(child: bubble),
            if (widget.isMe) ...[
              const SizedBox(width: 4),
              Checkbox(
                value: widget.isSelected,
                shape: const CircleBorder(),
                activeColor: AppTheme.violet,
                onChanged: (_) {}, // handled by parent GestureDetector tap
              ),
            ],
          ],
        ),
      );
    }
    return bubble;
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onSendImage;
  final VoidCallback onSendCamera;
  final ValueChanged<String>? onChanged;

  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.onSendImage,
    required this.onSendCamera,
    this.onChanged,
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
              onChanged: onChanged,
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

class FadeInSlideWidget extends StatelessWidget {
  final Widget child;
  final Duration duration;
  const FadeInSlideWidget({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 300),
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: duration,
      curve: Curves.easeOutQuad,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1.0 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.ink.withValues(alpha: 0.6)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppTheme.ink, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

class GlowingStatusIndicator extends StatefulWidget {
  final String status;
  const GlowingStatusIndicator({super.key, required this.status});

  @override
  State<GlowingStatusIndicator> createState() => _GlowingStatusIndicatorState();
}

class _GlowingStatusIndicatorState extends State<GlowingStatusIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    if (status == 'seen') {
      return RotationTransition(
        turns: _controller,
        child: Container(
          width: 12,
          height: 12,
          decoration: const BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Color(0xFF00F5FF),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
          child: CustomPaint(
            painter: _FourPointedStarPainter(color: const Color(0xFF00F5FF)),
          ),
        ),
      );
    } else if (status == 'delivered') {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final scale = 0.9 + (math.sin(_controller.value * math.pi * 2) * 0.1);
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFE0F7FA).withValues(alpha: 0.3),
                    blurRadius: 3,
                  ),
                ],
              ),
              child: CustomPaint(
                painter: _DiamondPainter(color: const Color(0xFFE0F7FA)),
              ),
            ),
          );
        },
      );
    } else {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final double opacity = 0.4 + (math.sin(_controller.value * math.pi * 2).abs() * 0.5);
          return Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: opacity), width: 1.5),
            ),
          );
        },
      );
    }
  }
}

class _FourPointedStarPainter extends CustomPainter {
  final Color color;
  _FourPointedStarPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final path = Path();
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2;

    path.moveTo(cx, cy - r);
    path.quadraticBezierTo(cx, cy, cx + r, cy);
    path.quadraticBezierTo(cx, cy, cx, cy + r);
    path.quadraticBezierTo(cx, cy, cx - r, cy);
    path.quadraticBezierTo(cx, cy, cx, cy - r);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FourPointedStarPainter oldDelegate) => oldDelegate.color != color;
}

class _DiamondPainter extends CustomPainter {
  final Color color;
  _DiamondPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final path = Path();
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2;

    path.moveTo(cx, cy - r);
    path.lineTo(cx + r, cy);
    path.lineTo(cx, cy + r);
    path.lineTo(cx - r, cy);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DiamondPainter oldDelegate) => oldDelegate.color != color;
}

class AnimatingChatBackground extends StatefulWidget {
  final RelationshipType? relationshipType;
  final Widget child;
  const AnimatingChatBackground({super.key, this.relationshipType, required this.child});

  @override
  State<AnimatingChatBackground> createState() => _AnimatingChatBackgroundState();
}

class _AnimatingChatBackgroundState extends State<AnimatingChatBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: _BackgroundPainter(
                  animationValue: _controller.value,
                  relationshipType: widget.relationshipType,
                ),
              );
            },
          ),
        ),
        Positioned.fill(child: widget.child),
      ],
    );
  }
}

class _BackgroundPainter extends CustomPainter {
  final double animationValue;
  final RelationshipType? relationshipType;

  _BackgroundPainter({required this.animationValue, this.relationshipType});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint bgPaint = Paint();
    final Rect rect = Offset.zero & size;

    Color bgStart, bgEnd;
    switch (relationshipType) {
      case RelationshipType.family:
        bgStart = const Color(0xFFFFF7ED);
        bgEnd = const Color(0xFFFFEDD5);
        break;
      case RelationshipType.partner:
        bgStart = const Color(0xFFF0FDF4);
        bgEnd = const Color(0xFFECFDF5);
        break;
      case RelationshipType.friend:
        bgStart = const Color(0xFFFEFCE8);
        bgEnd = const Color(0xFFFEF9C3);
        break;
      case RelationshipType.other:
      default:
        bgStart = const Color(0xFFFFF1F2);
        bgEnd = const Color(0xFFFFE4E6);
        break;
    }

    bgPaint.shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [bgStart, bgEnd],
    ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    final double w = size.width;
    final double h = size.height;

    switch (relationshipType) {
      case RelationshipType.family:
        final paint = Paint()..color = const Color(0xFFFFD1A9).withValues(alpha: 0.15);
        for (int i = 0; i < 6; i++) {
          final double progress = (animationValue + (i * 0.16)) % 1.0;
          final double cx = (w * 0.15) + (w * 0.7 * ((i * 37) % 100) / 100);
          final double cy = h - (progress * h);
          final double r = 20 + (15 * (i % 3));
          canvas.drawCircle(Offset(cx, cy), r, paint);
        }
        break;
      case RelationshipType.partner:
        final paint = Paint()..color = const Color(0xFFFFC0CB).withValues(alpha: 0.2);
        for (int i = 0; i < 4; i++) {
          final double progress = (animationValue + (i * 0.25)) % 1.0;
          final double cx = (w * 0.2) + (w * 0.6 * ((i * 73) % 100) / 100);
          final double cy = h * 0.8 - (progress * h * 0.7);
          final double scale = math.sin(progress * math.pi) * 20;
          if (scale > 0) {
            canvas.drawCircle(Offset(cx, cy), scale + 10, paint);
          }
        }
        break;
      case RelationshipType.friend:
        final paint = Paint()
          ..color = const Color(0xFFC084FC).withValues(alpha: 0.15)
          ..style = PaintingStyle.fill;
        for (int i = 0; i < 8; i++) {
          final double progress = (animationValue + (i * 0.12)) % 1.0;
          final double cx = (w * 0.1) + (w * 0.8 * ((i * 59) % 100) / 100);
          final double cy = h - (progress * h);
          final double size = 8.0 + (i % 3) * 4.0;
          _drawStar(canvas, Offset(cx, cy), size, paint);
        }
        break;
      case RelationshipType.other:
      default:
        final paint = Paint()
          ..color = const Color(0xFF94A3B8).withValues(alpha: 0.08)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        final double spacing = 60.0;
        final double shift = animationValue * spacing;
        for (double x = shift; x < w; x += spacing) {
          canvas.drawLine(Offset(x, 0), Offset(x, h), paint);
        }
        for (double y = shift; y < h; y += spacing) {
          canvas.drawLine(Offset(0, y), Offset(w, y), paint);
        }
        break;
    }
  }

  void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    for (int i = 0; i < 4; i++) {
      final double angle = (i * math.pi / 2);
      final double nextAngle = angle + (math.pi / 4);
      final double r1 = size;
      final double r2 = size / 2.5;

      final double x1 = center.dx + r1 * math.cos(angle);
      final double y1 = center.dy + r1 * math.sin(angle);
      final double x2 = center.dx + r2 * math.cos(nextAngle);
      final double y2 = center.dy + r2 * math.sin(nextAngle);

      if (i == 0) {
        path.moveTo(x1, y1);
      } else {
        path.lineTo(x1, y1);
      }
      path.lineTo(x2, y2);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BackgroundPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.relationshipType != relationshipType;
  }
}
