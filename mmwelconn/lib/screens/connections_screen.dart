import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mmwelconm/models/chat_model.dart';
import 'package:mmwelconm/models/contact_model.dart';
import 'package:mmwelconm/models/user_model.dart';
import 'package:mmwelconm/screens/profile_screen.dart';
import 'package:mmwelconm/screens/chat_detail_screen.dart';
import 'package:mmwelconm/services/firestore_service.dart';
import 'package:mmwelconm/widgets/app_brand.dart';

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

  Future<RelationshipType?> _showRelationDialog(String name) =>
      _showRelationDialogGlobal(context, name);

  Future<void> _addContact(UserModel user) async {
    final senderUid = FirebaseAuth.instance.currentUser!.uid;
    final sender = await fs.getUser(senderUid);
    if (sender == null) return;

    final type = await _showRelationDialog(user.name);
    if (type == null) return;

    await fs.sendContactRequest(
      senderUid: senderUid,
      senderName: sender.name,
      senderMmId: sender.mmId,
      senderPhotoUrl: sender.profilePicture,
      recipientUid: user.uid,
      recipientName: user.name,
      recipientMmId: user.mmId,
      recipientPhotoUrl: user.profilePicture,
      relationship: type,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request sent to ${user.name} as ${_pretty(type.name)}')),
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
    return Scaffold(
      body: SoftGlowBackground(
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Connections',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.normal,
                                color: AppTheme.ink,
                              ),
                        ),
                      ],
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
    ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  final List<UserModel> results;
  final bool searching;
  final void Function(UserModel) onAdd;

  const _SearchResults({required this.results, required this.searching, required this.onAdd});

  String _maskMmId(String mmId) {
    if (mmId.isEmpty) return 'N/A';
    if (mmId.length <= 3) return mmId;
    final firstTwo = mmId.substring(0, 2);
    final lastOne = mmId.substring(mmId.length - 1);
    final maskedLength = mmId.length - 3;
    return '$firstTwo${'*' * maskedLength}$lastOne';
  }

  void _showSearchProfileDetails(BuildContext context, UserModel u) {
    final maskedId = _maskMmId(u.mmId);
    final isPublic = u.publicProfileVisible;
    final displayPhoto = isPublic ? u.profilePicture : "";
    final displayName = isPublic ? u.name : "Private User";
    final joinedDate = isPublic ? _formatDate(u.createdAt) : "Private";

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: displayPhoto.isNotEmpty ? NetworkImage(displayPhoto) : null,
                  backgroundColor: AppTheme.violet.withValues(alpha: 0.18),
                  child: displayPhoto.isEmpty
                      ? Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                          style: const TextStyle(color: AppTheme.violet, fontSize: 32, fontWeight: FontWeight.bold))
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  displayName,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.ink),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'MM ID: ',
                      style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      maskedId,
                      style: const TextStyle(color: AppTheme.violet, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.calendar_month_rounded, color: AppTheme.sky),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Joined On', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(
                            joinedDate,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.ink),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (!isPublic)
                  Text(
                    'This user profile is private.',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                  ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.violet,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Close'),
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
        final displayName = u.publicProfileVisible ? u.name : "Private User";
        final displayPhoto = u.publicProfileVisible ? u.profilePicture : "";
        final maskedId = _maskMmId(u.mmId);

        return _ContactTile(
          name: displayName,
          photoUrl: displayPhoto,
          subtitle: 'MM ID: $maskedId',
          onTap: () => _showSearchProfileDetails(context, u),
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

  void _showConnectionDetailsSheet(BuildContext context, ContactModel c, String currentUid) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StreamBuilder<UserModel?>(
          stream: fs.watchUser(c.contactUid),
          builder: (context, snap) {
            final user = snap.data;
            final isOnline = user?.status == 'online';
            
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  CircleAvatar(
                    radius: 40,
                    backgroundImage: c.contactPhotoUrl.isNotEmpty ? NetworkImage(c.contactPhotoUrl) : null,
                    backgroundColor: AppTheme.violet.withValues(alpha: 0.18),
                    child: c.contactPhotoUrl.isEmpty
                        ? Text(c.contactName.isNotEmpty ? c.contactName[0].toUpperCase() : '?',
                            style: const TextStyle(color: AppTheme.violet, fontSize: 32, fontWeight: FontWeight.bold))
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    c.contactName,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.ink),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'MM ID: ',
                        style: TextStyle(color: AppTheme.ink.withValues(alpha: 0.6), fontWeight: FontWeight.w600),
                      ),
                      Text(
                        c.contactMmId.isNotEmpty ? c.contactMmId : 'N/A',
                        style: const TextStyle(color: AppTheme.violet, fontWeight: FontWeight.bold),
                      ),
                      if (c.contactMmId.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: c.contactMmId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('MM ID copied!')),
                            );
                          },
                          child: const Icon(Icons.copy_rounded, size: 14, color: AppTheme.violet),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isOnline ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: isOnline ? Colors.green : Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            color: isOnline ? Colors.green.shade700 : Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final newType = await _showRelationDialogGlobal(context, c.contactName);
                      if (newType != null && newType != c.relationshipType) {
                        await fs.updateContactRelationship(uid, c.contactUid, newType);
                        await fs.updateContactRelationship(c.contactUid, uid, newType);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Relationship updated to ${_pretty(newType.name)}!')),
                          );
                          Navigator.pop(context); // Close sheet to refresh list
                        }
                      }
                    },
                    child: Row(
                      children: [
                        Icon(_getRelationIcon(c.relationshipType), color: _getRelationColor(c.relationshipType)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Relationship (Tap to Edit)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                              Text(
                                _pretty(c.relationshipType.name),
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.ink),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.edit_rounded, size: 16, color: AppTheme.violet),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, color: AppTheme.sky),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Connected On', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            Text(
                              _formatDate(c.addedAt),
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.ink),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ProfileScreen(
                                  userId: c.contactUid,
                                  viewerUid: currentUid,
                                  contact: c,
                                ),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('View Profile'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            final nav = Navigator.of(context);
                            nav.pop(); // Pop the bottom sheet
                            
                            // Construct shell chat instantly in memory
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

                            // Background create direct chat in Firestore
                            fs.getOrCreateDirectChat(currentUid, c.contactUid);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.violet,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('Send Message'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _getRelationBgColor(RelationshipType? type) {
    if (type == null) return Colors.white.withValues(alpha: 0.72);
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

  Color _getRelationBorderColor(RelationshipType? type) {
    if (type == null) return Colors.transparent;
    switch (type) {
      case RelationshipType.family:
        return const Color(0xFFA7F3D0); // Soft green border
      case RelationshipType.partner:
        return const Color(0xFFFFE4E6);
      case RelationshipType.friend:
        return const Color(0xFFDDD6FE);
      case RelationshipType.other:
        return const Color(0xFFE2E8F0);
    }
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

        if (status == ContactStatus.accepted) {
          final grouped = <RelationshipType, List<ContactModel>>{};
          for (var type in RelationshipType.values) {
            grouped[type] = [];
          }
          for (var c in contacts) {
            grouped[c.relationshipType]?.add(c);
          }
          final activeTypes = RelationshipType.values.where((type) => grouped[type]!.isNotEmpty).toList();

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            itemCount: activeTypes.length,
            itemBuilder: (context, typeIdx) {
              final type = activeTypes[typeIdx];
              final list = grouped[type]!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
                    child: Row(
                      children: [
                        Icon(_getRelationIcon(type), color: _getRelationColor(type), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          '${_pretty(type.name)} (${list.length})',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                            color: _getRelationColor(type),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...list.map((c) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ContactTile(
                        name: c.contactName,
                        photoUrl: c.contactPhotoUrl,
                        subtitle: '',
                        relationshipType: c.relationshipType,
                        onTap: () => _showConnectionDetailsSheet(context, c, uid),
                      ),
                    );
                  }),
                ],
              );
            },
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
              relationshipType: c.relationshipType,
              relation: _pretty(c.relationshipType.name),
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
  final RelationshipType? relationshipType;
  final String? relation;
  final String? detail;
  final String? status;
  final VoidCallback? onTap;
  final Widget? trailing;

  const _ContactTile({
    required this.name,
    required this.photoUrl,
    required this.subtitle,
    this.relationshipType,
    this.relation,
    this.detail,
    this.status,
    this.onTap,
    this.trailing,
  });

  Color _getRelationBgColor(RelationshipType? type) {
    if (type == null) return Colors.white.withValues(alpha: 0.72);
    switch (type) {
      case RelationshipType.family:
        return const Color(0xFFECFDF5); // Soft emerald/mint
      case RelationshipType.partner:
        return const Color(0xFFFFF0F3);
      case RelationshipType.friend:
        return const Color(0xFFF5F3FF);
      case RelationshipType.other:
        return const Color(0xFFF1F5F9);
    }
  }

  Color _getRelationBorderColor(RelationshipType? type) {
    if (type == null) return Colors.transparent;
    switch (type) {
      case RelationshipType.family:
        return const Color(0xFFA7F3D0); // Soft green border
      case RelationshipType.partner:
        return const Color(0xFFFFE4E6);
      case RelationshipType.friend:
        return const Color(0xFFDDD6FE);
      case RelationshipType.other:
        return const Color(0xFFE2E8F0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: HoverCard(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _getRelationBgColor(relationshipType),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _getRelationBorderColor(relationshipType),
              width: 1,
            ),
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
                    Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.ink)),
                    if (subtitle.isNotEmpty)
                      Text(subtitle, style: TextStyle(fontSize: 12, color: AppTheme.ink.withValues(alpha: 0.5))),
                    if (relation != null && relation!.isNotEmpty)
                      Text('Relation: $relation', style: TextStyle(fontSize: 12, color: AppTheme.ink.withValues(alpha: 0.48))),
                    if (detail != null && detail!.isNotEmpty)
                      Text(detail!, style: TextStyle(fontSize: 12, color: AppTheme.ink.withValues(alpha: 0.45))),
                    if (status != null && status!.isNotEmpty)
                      Text(status!, style: TextStyle(fontSize: 12, color: AppTheme.ink.withValues(alpha: 0.45))),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) => '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

String _pretty(String value) =>
  value.isEmpty ? 'Unknown' : value[0].toUpperCase() + value.substring(1);

IconData _getRelationIcon(RelationshipType type) {
  switch (type) {
    case RelationshipType.family:
      return Icons.family_restroom_rounded;
    case RelationshipType.partner:
      return Icons.favorite_rounded;
    case RelationshipType.friend:
      return Icons.group_rounded;
    case RelationshipType.other:
      return Icons.star_rounded;
  }
}

Color _getRelationColor(RelationshipType type) {
  switch (type) {
    case RelationshipType.family:
      return const Color(0xFF059669); // Dark emerald green for contrast
    case RelationshipType.partner:
      return Colors.pink;
    case RelationshipType.friend:
      return AppTheme.violet;
    case RelationshipType.other:
      return Colors.blueGrey;
  }
}

Future<RelationshipType?> _showRelationDialogGlobal(BuildContext context, String name) async {
  return showDialog<RelationshipType>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('Select relation for $name', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.ink)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: RelationshipType.values.map((type) {
            return ListTile(
              leading: Icon(_getRelationIcon(type), color: _getRelationColor(type)),
              title: Text(_pretty(type.name), style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.ink)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onTap: () => Navigator.of(context).pop(type),
            );
          }).toList(),
        ),
      );
    },
  );
}
