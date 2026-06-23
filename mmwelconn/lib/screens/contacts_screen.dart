import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mmwelconn/models/contact_model.dart';
import 'package:mmwelconn/models/user_model.dart';
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

  Future<void> _addContact(UserModel user) async {
    await _fs.addContact(ContactModel(
      id: '',
      ownerUid: _uid,
      contactUid: user.uid,
      contactName: user.name,
      contactPhotoUrl: user.profilePicture,
      status: ContactStatus.pending,
      addedAt: DateTime.now(),
    ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request sent to ${user.name}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SoftGlowBackground(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contacts',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppTheme.ink,
                        ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _searchCtrl,
                    onChanged: _search,
                    decoration: InputDecoration(
                      hintText: 'Search people...',
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
                ],
              ),
            ),
            if (_searchCtrl.text.isNotEmpty) ...[
              const SizedBox(height: 12),
              Expanded(child: _SearchResults(
                results: _searchResults,
                searching: _searching,
                onAdd: _addContact,
              )),
            ] else ...[
              TabBar(
                controller: _tab,
                labelColor: AppTheme.violet,
                unselectedLabelColor: AppTheme.ink.withValues(alpha: 0.45),
                indicatorColor: AppTheme.violet,
                tabs: const [Tab(text: 'My Contacts'), Tab(text: 'Pending')],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _ContactList(uid: _uid, fs: _fs, status: ContactStatus.accepted),
                    _ContactList(uid: _uid, fs: _fs, status: ContactStatus.pending),
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

  const _SearchResults({required this.results, required this.searching, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    if (searching) return const Center(child: CircularProgressIndicator());
    if (results.isEmpty) {
      return Center(
        child: Text('No users found', style: TextStyle(color: AppTheme.ink.withValues(alpha: 0.45))),
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
          photoUrl: u.profilePicture,
          subtitle: u.email,
          trailing: IconButton(
            icon: const Icon(Icons.person_add_rounded, color: AppTheme.violet),
            onPressed: () => onAdd(u),
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

  const _ContactList({required this.uid, required this.fs, required this.status});

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
            child: Text(
              status == ContactStatus.accepted ? 'No contacts yet' : 'No pending requests',
              style: TextStyle(color: AppTheme.ink.withValues(alpha: 0.45)),
            ),
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
              photoUrl: c.contactPhotoUrl,
              subtitle: status == ContactStatus.pending ? 'Pending' : 'Contact',
              trailing: status == ContactStatus.pending
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle_rounded, color: Colors.green),
                        onPressed: () => fs.updateContactStatus(uid, c.contactUid, ContactStatus.accepted),
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel_rounded, color: AppTheme.pink),
                        onPressed: () => fs.updateContactStatus(uid, c.contactUid, ContactStatus.declined),
                      ),
                    ])
                  : null,
            );
          },
        );
      },
    );
  }
}

class _ContactTile extends StatelessWidget {
  final String name;
  final String photoUrl;
  final String subtitle;
  final Widget? trailing;

  const _ContactTile({required this.name, required this.photoUrl, required this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
            backgroundColor: AppTheme.violet.withValues(alpha: 0.18),
            child: photoUrl.isEmpty ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: AppTheme.violet, fontWeight: FontWeight.w800)) : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.ink)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: AppTheme.ink.withValues(alpha: 0.5))),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
