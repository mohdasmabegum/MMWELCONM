import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mmwelconn/models/contact_model.dart';
import 'package:mmwelconn/models/user_model.dart';
import 'package:mmwelconn/screens/profile_screen.dart';
import 'package:mmwelconn/services/firestore_service.dart';
import 'package:mmwelconn/widgets/app_brand.dart';

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService fs = FirestoreService();
  final String _uid = FirebaseAuth.instance.currentUser!.uid;
  final TextEditingController _searchCtrl = TextEditingController();
  late final TabController _tab;
  List<UserModel> _searchResults = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
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
    final results = await fs.searchUsers(q.trim());
    if (mounted) {
      setState(() {
        _searchResults = results.where((u) => u.uid != _uid).toList();
        _searching = false;
      });
    }
  }

  Future<void> _addContact(UserModel user) async {
    final senderUid = FirebaseAuth.instance.currentUser!.uid;
    final sender = await fs.getUser(senderUid);
    if (sender == null) return;

    await fs.sendContactRequest(
      senderUid: senderUid,
      senderName: sender.name,
      senderMmId: sender.mmId,
      senderPhotoUrl: sender.profilePicture,
      recipientUid: user.uid,
      recipientName: user.name,
      recipientMmId: user.mmId,
      recipientPhotoUrl: user.profilePicture,
      relationship: RelationshipType.friend,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request sent to ${user.name}')),
      );
      await _updateWidget(user.name, 'Request Sent');
    }
  }

  Future<void> _updateWidget(String name, String status) async {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;
    try {
      final hw = await _loadHomeWidget();
      if (hw == null) return;
      await hw.saveWidgetData<String>('contact_name', name);
      await hw.saveWidgetData<String>('contact_status', status);
      await hw.updateWidget(name: 'ConnectionsWidgetReceiver', iOSName: 'ConnectionsWidget');
    } catch (_) {}
  }

  Future<dynamic> _loadHomeWidget() async {
    return Future.value();
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
                    'Connections',
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
                tabs: const [Tab(text: 'Connections'), Tab(text: 'Pending'), Tab(text: 'Sent')],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tab,
                  children: [
                    _ContactList(uid: _uid, fs: fs, status: ContactStatus.accepted, onUpdate: _updateWidget),
                    _ContactList(uid: _uid, fs: fs, status: ContactStatus.pending, direction: ContactDirection.incoming, onUpdate: _updateWidget),
                    _ContactList(uid: _uid, fs: fs, status: ContactStatus.pending, direction: ContactDirection.outgoing, onUpdate: _updateWidget),
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
      separatorBuilder: (_, _) => const SizedBox(height: 8),
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
  final ContactDirection? direction;
  final Future<void> Function(String, String) onUpdate;

  const _ContactList({required this.uid, required this.fs, required this.status, this.direction, required this.onUpdate});

  String getEmptyListMessage() {
    if (status == ContactStatus.accepted) {
      return 'No connections yet';
    }
    if (status == ContactStatus.pending) {
      if (direction == ContactDirection.incoming) {
        return 'No pending requests';
      }
      if (direction == ContactDirection.outgoing) {
        return 'No sent requests';
      }
    }
    return 'No items';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ContactModel>>(
      stream: fs.watchContacts(uid, status: status, direction: direction),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final contacts = snap.data ?? [];
        if (contacts.isEmpty) {
          return Center(
            child: Text(
              getEmptyListMessage(),
              style: TextStyle(color: AppTheme.ink.withValues(alpha: 0.45)),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          itemCount: contacts.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final c = contacts[i];
            Widget? trailing;
            String subtitle = 'Connection';

            if (status == ContactStatus.pending) {
              if (direction == ContactDirection.incoming) {
                subtitle = 'Incoming Request';
                trailing = Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle_rounded, color: Colors.green),
                    onPressed: () => fs.acceptContact(uid, c.contactUid).then((_) => onUpdate(c.contactName, 'Connection Accepted')),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel_rounded, color: AppTheme.pink),
                    onPressed: () => fs.declineContact(uid, c.contactUid).then((_) => onUpdate(c.contactName, 'Request Declined')),
                  ),
                ]);
              } else if (direction == ContactDirection.outgoing) {
                subtitle = 'Sent Request';
                trailing = Text('Pending', style: TextStyle(color: AppTheme.ink.withValues(alpha: 0.5), fontSize: 12, fontWeight: FontWeight.w600));
              }
            }
            return _ContactTile(
              name: c.contactName,
              photoUrl: c.contactPhotoUrl,
              subtitle: subtitle,
              detail: 'Connected on ${_formatDate(c.addedAt)}',
              status: status == ContactStatus.accepted ? 'Connection' : subtitle,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(
                    userId: c.contactUid,
                    viewerUid: uid,
                    contact: c,
                  ),
                ),
              ),
              trailing: trailing,
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
  final String? detail;
  final String? status;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _ContactTile({required this.name, required this.photoUrl, required this.subtitle, this.detail, this.status, this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                if (detail != null)
                  Text(detail!, style: TextStyle(fontSize: 12, color: AppTheme.ink.withValues(alpha: 0.45))),
                if (status != null)
                  Text(status!, style: TextStyle(fontSize: 12, color: AppTheme.ink.withValues(alpha: 0.45))),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    ),
    );
  }
}

String _formatDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
