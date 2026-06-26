import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mmwelconn/models/chat_model.dart';
import 'package:mmwelconn/models/contact_model.dart';
import 'package:mmwelconn/models/user_model.dart';
import 'package:mmwelconn/services/firestore_service.dart';
import 'package:mmwelconn/widgets/app_brand.dart';

class CrudTestScreen extends StatefulWidget {
  const CrudTestScreen({super.key});

  @override
  State<CrudTestScreen> createState() => _CrudTestScreenState();
}

class _CrudTestScreenState extends State<CrudTestScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _fs = FirestoreService();
  final String _uid = FirebaseAuth.instance.currentUser!.uid;
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SoftGlowBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.ink),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'CRUD Test Panel',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppTheme.ink,
                          ),
                    ),
                  ],
                ),
              ),
              TabBar(
                controller: _tab,
                labelColor: AppTheme.violet,
                unselectedLabelColor: AppTheme.ink.withValues(alpha: 0.45),
                indicatorColor: AppTheme.violet,
                tabs: const [
                  Tab(text: 'Users'),
                  Tab(text: 'Contacts'),
                  Tab(text: 'Chats'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _UserCrud(fs: _fs, uid: _uid),
                    _ContactCrud(fs: _fs, uid: _uid),
                    _ChatCrud(fs: _fs, uid: _uid),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

void _toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
}

Widget _sectionCard({required String title, required List<Widget> children}) {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.78),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: AppTheme.ink)),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  );
}

Widget _actionBtn(String label, Color color, VoidCallback onTap) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    ),
  );
}

Widget _resultBox(String content) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F4FF),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(content,
        style: const TextStyle(fontSize: 12, fontFamily: 'monospace', color: AppTheme.ink)),
  );
}

// ── USER CRUD ─────────────────────────────────────────────────────────────────

class _UserCrud extends StatefulWidget {
  final FirestoreService fs;
  final String uid;
  const _UserCrud({required this.fs, required this.uid});

  @override
  State<_UserCrud> createState() => _UserCrudState();
}

class _UserCrudState extends State<_UserCrud> {
  final _nameCtrl = TextEditingController();
  String _result = 'Result will appear here...';

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _sectionCard(
          title: '📖 READ — Fetch current user',
          children: [
            _actionBtn('Read My User Doc', AppTheme.sky, () async {
              final u = await widget.fs.getUser(widget.uid);
              if (!context.mounted) return;
              setState(() {
                _result = u != null
                    ? 'uid: ${u.uid}\nname: ${u.name}\nemail: ${u.email}\nstatus: ${u.status}\ncreatedAt: ${u.createdAt}'
                    : 'No user found';
              });
              _toast(context, u != null ? 'User read ✓' : 'Not found');
            }),
            _resultBox(_result),
          ],
        ),
        _sectionCard(
          title: '✏️ UPDATE — Change display name',
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                hintText: 'New display name',
                filled: true,
                fillColor: const Color(0xFFF5F7FF),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
            const SizedBox(height: 8),
            _actionBtn('Update Name', AppTheme.violet, () async {
              if (_nameCtrl.text.trim().isEmpty) {
                _toast(context, 'Enter a name first');
                return;
              }
              await widget.fs.updateUser(widget.uid, {'name': _nameCtrl.text.trim()});
              if (!context.mounted) return;
              setState(() => _result = 'Updated name → ${_nameCtrl.text.trim()}');
              _toast(context, 'Name updated ✓');
            }),
            _resultBox(_result),
          ],
        ),
        _sectionCard(
          title: '🔴 DELETE — (Soft) Set status to offline',
          children: [
            _actionBtn('Set Status: offline', AppTheme.pink, () async {
              await widget.fs.setUserStatus(widget.uid, 'offline');
              if (!context.mounted) return;
              setState(() => _result = 'Status set to offline');
              _toast(context, 'Status updated ✓');
            }),
            _actionBtn('Set Status: online', const Color(0xFF4CAF50), () async {
              await widget.fs.setUserStatus(widget.uid, 'online');
              if (!context.mounted) return;
              setState(() => _result = 'Status set to online');
              _toast(context, 'Status updated ✓');
            }),
            _resultBox(_result),
          ],
        ),
        _sectionCard(
          title: '📡 STREAM — Live user updates',
          children: [
            StreamBuilder<UserModel?>(
              stream: widget.fs.watchUser(widget.uid),
              builder: (context, snap) {
                if (!snap.hasData) return _resultBox('Listening...');
                final u = snap.data!;
                return _resultBox(
                    'LIVE ✦\nname: ${u.name}\nstatus: ${u.status}\nlastActive: ${u.lastActive}');
              },
            ),
          ],
        ),
      ],
    );
  }
}

// ── CONTACT CRUD ──────────────────────────────────────────────────────────────

class _ContactCrud extends StatefulWidget {
  final FirestoreService fs;
  final String uid;
  const _ContactCrud({required this.fs, required this.uid});

  @override
  State<_ContactCrud> createState() => _ContactCrudState();
}

class _ContactCrudState extends State<_ContactCrud> {
  final _contactUidCtrl = TextEditingController();
  final _contactNameCtrl = TextEditingController();
  String _result = 'Result will appear here...';

  @override
  void dispose() {
    _contactUidCtrl.dispose();
    _contactNameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _sectionCard(
          title: '➕ CREATE — Add a test contact',
          children: [
            TextField(
              controller: _contactUidCtrl,
              decoration: _inputDeco('Contact UID'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _contactNameCtrl,
              decoration: _inputDeco('Contact Name'),
            ),
            const SizedBox(height: 8),
            _actionBtn('Add Contact', AppTheme.sky, () async {
              if (_contactUidCtrl.text.trim().isEmpty ||
                  _contactNameCtrl.text.trim().isEmpty) {
                if (!context.mounted) return;
                _toast(context, 'Fill both fields');
                return;
              }
              await widget.fs.sendContactRequest(
                senderUid: widget.uid,
                senderName: 'Test',
                senderMmId: '',
                senderPhotoUrl: '',
                recipientUid: _contactUidCtrl.text.trim(),
                recipientName: _contactNameCtrl.text.trim(),
                recipientMmId: '',
                recipientPhotoUrl: '',
                relationship: RelationshipType.friend,
              );
              setState(() =>
                  _result = 'Created contact: ${_contactNameCtrl.text.trim()} (${_contactUidCtrl.text.trim()})');
              if (!context.mounted) return;
              _toast(context, 'Contact added ✓');
            }),
            _resultBox(_result),
          ],
        ),
        _sectionCard(
          title: '📖 READ — Fetch a contact',
          children: [
            _actionBtn('Read Contact', AppTheme.violet, () async {
              if (_contactUidCtrl.text.trim().isEmpty) {
                _toast(context, 'Enter Contact UID above first');
                return;
              }
              final c = await widget.fs.getContact(
                  widget.uid, _contactUidCtrl.text.trim());
              if (!context.mounted) return;
              setState(() {
                _result = c != null
                    ? 'name: ${c.contactName}\nstatus: ${c.status.name}\naddedAt: ${c.addedAt}'
                    : 'Contact not found';
              });
              _toast(context, c != null ? 'Contact read ✓' : 'Not found');
            }),
            _resultBox(_result),
          ],
        ),
        _sectionCard(
          title: '✏️ UPDATE — Change contact status',
          children: [
            Row(children: [
              Expanded(
                  child: _actionBtn('→ Accepted', const Color(0xFF4CAF50), () async {
                if (_contactUidCtrl.text.trim().isEmpty) {
                  _toast(context, 'Enter Contact UID above');
                  return;
                }
                await widget.fs.updateContactStatus(
                    widget.uid, _contactUidCtrl.text.trim(), ContactStatus.accepted);
                if (!context.mounted) return;
                setState(() => _result = 'Status → accepted');
                _toast(context, 'Updated ✓');
              })),
              const SizedBox(width: 8),
              Expanded(
                  child: _actionBtn('→ Blocked', AppTheme.pink, () async {
                if (_contactUidCtrl.text.trim().isEmpty) {
                  _toast(context, 'Enter Contact UID above');
                  return;
                }
                await widget.fs.updateContactStatus(
                    widget.uid, _contactUidCtrl.text.trim(), ContactStatus.blocked);
                if (!context.mounted) return;
                setState(() => _result = 'Status → blocked');
                _toast(context, 'Updated ✓');
              })),
            ]),
            _resultBox(_result),
          ],
        ),
        _sectionCard(
          title: '🗑️ DELETE — Remove contact',
          children: [
            _actionBtn('Delete Contact', AppTheme.pink, () async {
              if (_contactUidCtrl.text.trim().isEmpty) {
                _toast(context, 'Enter Contact UID above');
                return;
              }
              await widget.fs.removeContact(
                  widget.uid, _contactUidCtrl.text.trim());
              if (!context.mounted) return;
              setState(() => _result = 'Deleted contact: ${_contactUidCtrl.text.trim()}');
              _toast(context, 'Deleted ✓');
            }),
            _resultBox(_result),
          ],
        ),
        _sectionCard(
          title: '📡 STREAM — Live contact list',
          children: [
            StreamBuilder<List<ContactModel>>(
              stream: widget.fs.watchContacts(widget.uid),
              builder: (context, snap) {
                if (!snap.hasData) return _resultBox('Listening...');
                final list = snap.data!;
                if (list.isEmpty) return _resultBox('No contacts yet');
                return _resultBox(
                    list.map((c) => '${c.contactName} → ${c.status.name}').join('\n'));
              },
            ),
          ],
        ),
      ],
    );
  }
}

// ── CHAT CRUD ─────────────────────────────────────────────────────────────────

class _ChatCrud extends StatefulWidget {
  final FirestoreService fs;
  final String uid;
  const _ChatCrud({required this.fs, required this.uid});

  @override
  State<_ChatCrud> createState() => _ChatCrudState();
}

class _ChatCrudState extends State<_ChatCrud> {
  final _otherUidCtrl = TextEditingController();
  final _otherNameCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  String _result = 'Result will appear here...';
  String? _chatId;

  @override
  void dispose() {
    _otherUidCtrl.dispose();
    _otherNameCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  String get _myName =>
      FirebaseAuth.instance.currentUser?.displayName ??
      FirebaseAuth.instance.currentUser?.email?.split('@').first ??
      'Me';

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _sectionCard(
          title: '➕ CREATE — Start a direct chat',
          children: [
            TextField(controller: _otherUidCtrl, decoration: _inputDeco('Other User UID')),
            const SizedBox(height: 8),
            TextField(controller: _otherNameCtrl, decoration: _inputDeco('Other User Name')),
            const SizedBox(height: 8),
            _actionBtn('Create / Get Chat', AppTheme.sky, () async {
              if (_otherUidCtrl.text.trim().isEmpty ||
                  _otherNameCtrl.text.trim().isEmpty) {
                _toast(context, 'Fill both fields');
                return;
              }
              final id = await widget.fs.getOrCreateDirectChat(
                widget.uid,
                _myName,
                _otherUidCtrl.text.trim(),
                _otherNameCtrl.text.trim(),
              );
              if (!context.mounted) return;
              setState(() {
                _chatId = id;
                _result = 'Chat ID: $id';
              });
              _toast(context, 'Chat ready ✓');
            }),
            _resultBox(_result),
          ],
        ),
        _sectionCard(
          title: '📖 READ — Fetch chat doc',
          children: [
            _actionBtn('Read Chat', AppTheme.violet, () async {
              if (_chatId == null) {
                _toast(context, 'Create a chat first');
                return;
              }
              final chat = await widget.fs.getChat(_chatId!);
              if (!context.mounted) return;
              setState(() {
                _result = chat != null
                    ? 'id: ${chat.id}\ntype: ${chat.chatType.name}\nparticipants: ${chat.participantNames.values.join(', ')}\nlastMessage: ${chat.lastMessage ?? 'none'}'
                    : 'Chat not found';
              });
              _toast(context, chat != null ? 'Chat read ✓' : 'Not found');
            }),
            _resultBox(_result),
          ],
        ),
        _sectionCard(
          title: '✉️ UPDATE — Send a message',
          children: [
            TextField(controller: _msgCtrl, decoration: _inputDeco('Message text')),
            const SizedBox(height: 8),
            _actionBtn('Send Message', const Color(0xFF4CAF50), () async {
              if (_chatId == null) {
                _toast(context, 'Create a chat first');
                return;
              }
              if (_msgCtrl.text.trim().isEmpty) {
                _toast(context, 'Type a message');
                return;
              }
              await widget.fs.sendMessage(
                _chatId!,
                MessageModel(
                  id: '',
                  senderId: widget.uid,
                  senderName: _myName,
                  text: _msgCtrl.text.trim(),
                  createdAt: DateTime.now(),
                ),
                [widget.uid, _otherUidCtrl.text.trim()],
              );
              if (!context.mounted) return;
              setState(() => _result = 'Message sent: "${_msgCtrl.text.trim()}"');
              _msgCtrl.clear();
              _toast(context, 'Message sent ✓');
            }),
            _resultBox(_result),
          ],
        ),
        _sectionCard(
          title: '🗑️ DELETE — Clear unread count',
          children: [
            _actionBtn('Clear My Unread', AppTheme.pink, () async {
              if (_chatId == null) {
                _toast(context, 'Create a chat first');
                return;
              }
              await widget.fs.clearUnread(_chatId!, widget.uid);
              if (!context.mounted) return;
              setState(() => _result = 'Unread cleared for $_chatId');
              _toast(context, 'Cleared ✓');
            }),
            _resultBox(_result),
          ],
        ),
        _sectionCard(
          title: '📡 STREAM — Live messages',
          children: [
            if (_chatId == null)
              _resultBox('Create a chat first to stream messages')
            else
              StreamBuilder<List<MessageModel>>(
                stream: widget.fs.watchMessages(_chatId!),
                builder: (context, snap) {
                  if (!snap.hasData) return _resultBox('Listening...');
                  final msgs = snap.data!;
                  if (msgs.isEmpty) return _resultBox('No messages yet');
                  return _resultBox(
                      msgs.map((m) => '[${m.senderName}]: ${m.text}').join('\n'));
                },
              ),
          ],
        ),
      ],
    );
  }
}

InputDecoration _inputDeco(String hint) => InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF5F7FF),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    );
