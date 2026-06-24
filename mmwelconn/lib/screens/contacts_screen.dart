import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
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
  UserModel? _myUser;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _loadMyUser();
  }

  Future<void> _loadMyUser() async {
    final u = await _fs.getUser(_uid);
    if (mounted) setState(() => _myUser = u);
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

  Future<void> _sendRequest(UserModel user, RelationshipType relationship) async {
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
      contactMmId: user.mmId,
      contactName: user.name,
      contactPhotoUrl: user.profilePicture,
      status: ContactStatus.pending,
      relationshipType: relationship,
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

  void _showAddDialog(UserModel user) {
    RelationshipType selected = RelationshipType.friend;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Add ${user.name}',
              style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.ink)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MM ID: ${user.mmId}',
                  style: TextStyle(fontSize: 13, color: AppTheme.ink.withValues(alpha: 0.5))),
              const SizedBox(height: 16),
              const Text('Relationship type',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.ink)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: RelationshipType.values.map((r) {
                  final isSelected = selected == r;
                  return GestureDetector(
                    onTap: () => setS(() => selected = r),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: isSelected
                            ? _relationshipColor(r).withValues(alpha: 0.15)
                            : Colors.grey.withValues(alpha: 0.08),
                        border: Border.all(
                          color: isSelected
                              ? _relationshipColor(r)
                              : Colors.grey.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(_relationshipEmoji(r), style: const TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(_relationshipLabel(r),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? _relationshipColor(r) : AppTheme.ink.withValues(alpha: 0.6),
                            )),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _sendRequest(user, selected);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.violet,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Send Request', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SoftGlowBackground(
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Contacts',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900, color: AppTheme.ink)),
                        if (_myUser?.mmId.isNotEmpty == true)
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: _myUser!.mmId));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('MM ID copied to clipboard')),
                              );
                            },
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text('Your ID: ${_myUser!.mmId}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.violet,
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(width: 4),
                              Icon(Icons.copy_rounded, size: 12, color: AppTheme.violet),
                            ]),
                          ),
                      ],
                    ),
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
                    hintText: 'Search by name or MM ID (e.g. MM1A2B3C)...',
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
                onAdd: _showAddDialog,
              )),
            ] else ...[
              TabBar(
                controller: _tab,
                labelColor: AppTheme.violet,
                unselectedLabelColor: AppTheme.ink.withValues(alpha: 0.45),
                indicatorColor: AppTheme.violet,
                tabs: const [
                  Tab(text: 'Contacts'),
                  Tab(text: 'Pending'),
                  Tab(text: 'Device'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _ContactList(uid: _uid, fs: _fs, onChat: _startChat),
                    _PendingList(uid: _uid, fs: _fs),
                    _DeviceContactsList(onSearchByPhone: (phone) {
                      setState(() => _showSearch = true);
                      _searchCtrl.text = phone;
                      _search(phone);
                    }),
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

// ── Relationship helpers ──────────────────────────────────────────────────────

Color _relationshipColor(RelationshipType r) => switch (r) {
      RelationshipType.friend => AppTheme.violet,
      RelationshipType.family => AppTheme.sky,
      RelationshipType.partner => AppTheme.pink,
      RelationshipType.other => AppTheme.coral,
    };

String _relationshipEmoji(RelationshipType r) => switch (r) {
      RelationshipType.friend => '👥',
      RelationshipType.family => '🏠',
      RelationshipType.partner => '❤️',
      RelationshipType.other => '🤝',
    };

String _relationshipLabel(RelationshipType r) => switch (r) {
      RelationshipType.friend => 'Friend',
      RelationshipType.family => 'Family',
      RelationshipType.partner => 'Partner',
      RelationshipType.other => 'Other',
    };

// ── Search results ────────────────────────────────────────────────────────────

class _SearchResults extends StatelessWidget {
  final List<UserModel> results;
  final bool searching;
  final void Function(UserModel) onAdd;

  const _SearchResults({required this.results, required this.searching, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    if (searching) return const Center(child: CircularProgressIndicator());
    if (results.isEmpty) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.search_off_rounded, size: 48, color: AppTheme.ink.withValues(alpha: 0.2)),
          const SizedBox(height: 10),
          Text('No users found', style: TextStyle(color: AppTheme.ink.withValues(alpha: 0.4))),
          const SizedBox(height: 6),
          Text('Try searching by name or MM ID',
              style: TextStyle(fontSize: 12, color: AppTheme.ink.withValues(alpha: 0.3))),
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
          subtitle: u.mmId.isNotEmpty ? 'ID: ${u.mmId}' : u.email,
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

// ── Contact list ──────────────────────────────────────────────────────────────

class _ContactList extends StatelessWidget {
  final String uid;
  final FirestoreService fs;
  final void Function(ContactModel) onChat;

  const _ContactList({required this.uid, required this.fs, required this.onChat});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ContactModel>>(
      stream: fs.watchContacts(uid, status: ContactStatus.accepted),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final contacts = snap.data ?? [];
        if (contacts.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.people_outline_rounded, size: 56, color: AppTheme.ink.withValues(alpha: 0.2)),
              const SizedBox(height: 14),
              Text('No contacts yet',
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.ink.withValues(alpha: 0.4))),
              const SizedBox(height: 6),
              Text('Tap 🔍 to search and add people',
                  style: TextStyle(fontSize: 13, color: AppTheme.ink.withValues(alpha: 0.3))),
            ]),
          );
        }

        // Group by relationship type
        final grouped = <RelationshipType, List<ContactModel>>{};
        for (final c in contacts) {
          grouped.putIfAbsent(c.relationshipType, () => []).add(c);
        }

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: grouped.entries.map((entry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8, top: 4),
                  child: Row(children: [
                    Text(_relationshipEmoji(entry.key), style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(_relationshipLabel(entry.key).toUpperCase(),
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: _relationshipColor(entry.key))),
                  ]),
                ),
                ...entry.value.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ContactTile(
                        name: c.contactName,
                        subtitle: c.contactMmId.isNotEmpty ? 'ID: ${c.contactMmId}' : 'Tap to message',
                        relationshipType: c.relationshipType,
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(
                            icon: const Icon(Icons.chat_bubble_outline_rounded,
                                color: AppTheme.violet, size: 20),
                            onPressed: () => onChat(c),
                          ),
                          _RelationshipChip(type: c.relationshipType),
                        ]),
                        onTap: () => onChat(c),
                      ),
                    )),
                const SizedBox(height: 8),
              ],
            );
          }).toList(),
        );
      },
    );
  }
}

// ── Pending list ──────────────────────────────────────────────────────────────

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
              subtitle: '${_relationshipEmoji(c.relationshipType)} ${_relationshipLabel(c.relationshipType)} · Pending',
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  icon: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 22),
                  onPressed: () => fs.updateContactStatus(uid, c.contactUid, ContactStatus.accepted),
                ),
                IconButton(
                  icon: const Icon(Icons.cancel_rounded, color: AppTheme.pink, size: 22),
                  onPressed: () => fs.updateContactStatus(uid, c.contactUid, ContactStatus.declined),
                ),
              ]),
            );
          },
        );
      },
    );
  }
}

// ── Device contacts ───────────────────────────────────────────────────────────

class _DeviceContactsList extends StatefulWidget {
  final void Function(String phone) onSearchByPhone;
  const _DeviceContactsList({required this.onSearchByPhone});

  @override
  State<_DeviceContactsList> createState() => _DeviceContactsListState();
}

class _DeviceContactsListState extends State<_DeviceContactsList> {
  List<fc.Contact> _contacts = [];
  bool _loading = false;
  bool _permissionDenied = false;
  String _filter = '';

  Future<void> _loadContacts() async {
    setState(() => _loading = true);
    final granted = await fc.FlutterContacts.requestPermission();
    if (!granted) {
      setState(() { _loading = false; _permissionDenied = true; });
      return;
    }
    final contacts = await fc.FlutterContacts.getContacts(withProperties: true);
    if (mounted) setState(() { _contacts = contacts; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_contacts.isEmpty && !_permissionDenied) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.contacts_rounded, size: 56, color: AppTheme.ink.withValues(alpha: 0.2)),
          const SizedBox(height: 14),
          Text('Access your device contacts',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.ink.withValues(alpha: 0.5))),
          const SizedBox(height: 6),
          Text('Find friends already on MMWELCONN',
              style: TextStyle(fontSize: 13, color: AppTheme.ink.withValues(alpha: 0.35))),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadContacts,
            icon: const Icon(Icons.contacts_rounded),
            label: const Text('Load Contacts', style: TextStyle(fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.violet,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ]),
      );
    }

    if (_permissionDenied) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.no_cell_rounded, size: 48, color: AppTheme.ink.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          Text('Permission denied',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.ink.withValues(alpha: 0.5))),
          const SizedBox(height: 6),
          Text('Enable contacts permission in your device settings',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.ink.withValues(alpha: 0.35))),
        ]),
      );
    }

    final filtered = _filter.isEmpty
        ? _contacts
        : _contacts.where((c) =>
            c.displayName.toLowerCase().contains(_filter.toLowerCase())).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: TextField(
            onChanged: (v) => setState(() => _filter = v),
            decoration: InputDecoration(
              hintText: 'Filter contacts...',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.88),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            itemCount: filtered.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final c = filtered[i];
              final phone = c.phones.isNotEmpty ? c.phones.first.number : '';
              return _ContactTile(
                name: c.displayName,
                subtitle: phone.isNotEmpty ? phone : 'No phone number',
                trailing: phone.isNotEmpty
                    ? TextButton.icon(
                        onPressed: () => widget.onSearchByPhone(phone.replaceAll(' ', '')),
                        icon: const Icon(Icons.search_rounded, size: 16),
                        label: const Text('Find'),
                        style: TextButton.styleFrom(foregroundColor: AppTheme.sky),
                      )
                    : const SizedBox.shrink(),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _RelationshipChip extends StatelessWidget {
  final RelationshipType type;
  const _RelationshipChip({required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _relationshipColor(type).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _relationshipColor(type).withValues(alpha: 0.3)),
      ),
      child: Text(
        '${_relationshipEmoji(type)} ${_relationshipLabel(type)}',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _relationshipColor(type)),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final String name;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;
  final RelationshipType? relationshipType;

  const _ContactTile({
    required this.name,
    required this.subtitle,
    required this.trailing,
    this.onTap,
    this.relationshipType,
  });

  @override
  Widget build(BuildContext context) {
    final color = relationshipType != null ? _relationshipColor(relationshipType!) : AppTheme.violet;
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
              backgroundColor: color.withValues(alpha: 0.15),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.ink)),
                  Text(subtitle,
                      style: TextStyle(fontSize: 12, color: AppTheme.ink.withValues(alpha: 0.45))),
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
