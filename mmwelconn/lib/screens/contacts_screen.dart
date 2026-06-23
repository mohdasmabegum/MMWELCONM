import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mmwelconn/models/contact_model.dart';
import 'package:mmwelconn/models/user_model.dart';
import 'package:mmwelconn/models/chat_model.dart';
import 'package:mmwelconn/screens/chat_detail_screen.dart';
import 'package:mmwelconn/services/firestore_service.dart';
import 'package:mmwelconn/widgets/app_brand.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _fs = FirestoreService();
  final String _uid = FirebaseAuth.instance.currentUser!.uid;
  final TextEditingController _searchCtrl = TextEditingController();
  late final TabController _tab;
  List<UserModel> _searchResults = [];
  bool _searching = false;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    setState(() => _searching = true);
    final results = await _fs.searchUsers(q.trim());
    if (mounted) {
      setState(() {
        _searchResults = results.where((u) => u.uid != _uid).toList();
        _searching = false;
      });
    }
  }

  Future<void> _sendRequest(UserModel user) async {
    final existing = await _fs.getContact(_uid, user.uid);
    if (existing != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${user.name} is already in your contacts')),
      );
      return;
    }
    await _fs.addContact(ContactModel(
      id: '',
      ownerUid: _uid,
      contactUid: user.uid,
      contactName: user.name,
      contactPhotoUrl: user.profilePicture,
      status: ContactStatus.pending,
      addedAt: DateTime.now(),
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Contact request sent to ${user.name} ✓')),
    );
    setState(() {
      _searchCtrl.clear();
      _searchResults = [];
      _showSearch = false;
    });
  }

  Future<void> _startChat(ContactModel c) async {
    final myUser = await _fs.getUser(_uid);
    final myName = myUser?.name ?? 'Me';
    final chatId = await _fs.getOrCreateDirectChat(_uid, myName, c.contactUid, c.contactName);
    final chat = await _fs.getChat(chatId);
    if (chat != null && mounted) {
      Navigator.of(context).push(buildPageRoute(
        ChatDetailScreen(chat: chat, currentUid: _uid),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SoftGlowBackground(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Contacts',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900, color: AppTheme.ink)),
                  ),
                  IconButton(
                    icon: Icon(
                      _showSearch ? Icons.close_rounded : Icons.person_search_rounded,
                      color: AppTheme.violet,
                    ),
                    onPressed: () {
                      setState(() {
                        _showSearch = !_showSearch;
                        if (!_showSearch) {
                          _searchCtrl.clear();
                          _searchResults = [];
                        }
                      });
                    },
                  ),
                ],
              ),
            ),

            if (_showSearch) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  onChanged: _search,
                  decoration: InputDecoration(
                    hintText: 'Search by name...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.88),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: _SearchResults(
                results: _searchResults,
                searching: _searching,
                onAdd: _sendRequest,
              )),
            ] else ...[
              TabBar(
                controller: _tab,
                labelColor: AppTheme.violet,
                unselectedLabelColor: AppTheme.ink.withValues(alpha: 0.45),
                indicatorColor: AppTheme.violet,
                tabs: const [Tab(text: 'Contacts'), Tab(text: 'Pending')],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _ContactList(
                      uid: _uid,
                      fs: _fs,
                      status: ContactStatus.accepted,
                      onChat: _startChat,
                    ),
                    _PendingList(uid: _uid, fs: _fs),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  final List<UserModel> results;
  final bool searching;
  final void Function(UserModel) onAdd;

  const _SearchResults(
      {required this.results, required this.searching, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    if (searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (results.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_off_rounded, size: 48, color: AppTheme.ink.withValues(alpha: 0.2)),
          const SizedBox(height: 10),
          Text('No users found',
              style: TextStyle(color: AppTheme.ink.withValues(alpha: 0.4))),
        ]),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final u = results[i];
        return _ContactTile(
          name: u.name,
          subtitle: u.email,
          trailing: TextButton.icon(
            onPressed: () => onAdd(u),
            icon: const Icon(Icons.person_add_rounded, size: 16),
            label: const Text('Add'),
            style: TextButton.styleFrom(foregroundColor: AppTheme.violet),
          ),
        );
      },
    );
  }
}

class _ContactList extends StatelessWidget {
  final String uid;
  final FirestoreService fs;
  final ContactStatus status;
  final void Function(ContactModel) onChat;

  const _ContactList(
      {required this.uid, required this.fs, required this.status, required this.onChat});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ContactModel>>(
      stream: fs.watchContacts(uid, status: status),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final contacts = snap.data ?? [];
        if (contacts.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.people_outline_rounded,
                  size: 56, color: AppTheme.ink.withValues(alpha: 0.2)),
              const SizedBox(height: 14),
              Text('No contacts yet',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink.withValues(alpha: 0.4))),
              const SizedBox(height: 6),
              Text('Tap 🔍 to search and add people',
                  style: TextStyle(fontSize: 13, color: AppTheme.ink.withValues(alpha: 0.3))),
            ]),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          itemCount: contacts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final c = contacts[i];
            return _ContactTile(
              name: c.contactName,
              subtitle: 'Tap to message',
              trailing: IconButton(
                icon: const Icon(Icons.chat_bubble_outline_rounded,
                    color: AppTheme.violet, size: 20),
                onPressed: () => onChat(c),
              ),
              onTap: () => onChat(c),
            );
          },
        );
      },
    );
  }
}

class _PendingList extends StatelessWidget {
  final String uid;
  final FirestoreService fs;

  const _PendingList({required this.uid, required this.fs});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ContactModel>>(
      stream: fs.watchContacts(uid, status: ContactStatus.pending),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final contacts = snap.data ?? [];
        if (contacts.isEmpty) {
          return Center(
            child: Text('No pending requests',
                style: TextStyle(color: AppTheme.ink.withValues(alpha: 0.4))),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          itemCount: contacts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final c = contacts[i];
            return _ContactTile(
              name: c.contactName,
              subtitle: 'Pending request',
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  icon: const Icon(Icons.check_circle_rounded,
                      color: Colors.green, size: 22),
                  onPressed: () => fs.updateContactStatus(
                      uid, c.contactUid, ContactStatus.accepted),
                ),
                IconButton(
                  icon: const Icon(Icons.cancel_rounded,
                      color: AppTheme.pink, size: 22),
                  onPressed: () => fs.updateContactStatus(
                      uid, c.contactUid, ContactStatus.declined),
                ),
              ]),
            );
          },
        );
      },
    );
  }
}

class _ContactTile extends StatelessWidget {
  final String name;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _ContactTile({
    required this.name,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.78),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppTheme.violet.withValues(alpha: 0.15),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: AppTheme.violet, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: AppTheme.ink)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.ink.withValues(alpha: 0.45))),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}
