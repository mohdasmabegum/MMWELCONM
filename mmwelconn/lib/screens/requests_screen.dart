import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mmwelconm/models/contact_model.dart';
import 'package:mmwelconm/services/firestore_service.dart';
import 'package:mmwelconm/widgets/app_brand.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen>
    with SingleTickerProviderStateMixin {
  final FirestoreService _fs = FirestoreService();
  late final TabController _tabController;
  final String _uid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Requests',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.normal,
                            color: AppTheme.ink,
                          ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.violet,
                  unselectedLabelColor: AppTheme.ink.withValues(alpha: 0.45),
                  indicatorColor: AppTheme.violet,
                  tabs: const [Tab(text: 'Pending'), Tab(text: 'Sent')],
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _RequestList(
                      uid: _uid,
                      fs: _fs,
                      direction: ContactDirection.incoming,
                    ),
                    _RequestList(
                      uid: _uid,
                      fs: _fs,
                      direction: ContactDirection.outgoing,
                    ),
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

class _RequestList extends StatelessWidget {
  final String uid;
  final FirestoreService fs;
  final ContactDirection direction;

  const _RequestList({
    required this.uid,
    required this.fs,
    required this.direction,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ContactModel>>(
      stream: fs.watchContacts(uid, status: ContactStatus.pending, direction: direction),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snap.data ?? [];
        if (requests.isEmpty) {
          return Center(
            child: Text(
              direction == ContactDirection.incoming ? 'No pending requests' : 'No sent requests',
              style: TextStyle(color: AppTheme.ink.withValues(alpha: 0.45)),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          itemCount: requests.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final request = requests[index];
            final subtitle = direction == ContactDirection.incoming
                ? 'Incoming request'
                : 'Sent request';

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.74),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundImage: request.contactPhotoUrl.isNotEmpty
                        ? NetworkImage(request.contactPhotoUrl)
                        : null,
                    backgroundColor: AppTheme.violet.withValues(alpha: 0.18),
                    child: request.contactPhotoUrl.isEmpty
                        ? Text(
                            request.contactName.isNotEmpty
                                ? request.contactName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: AppTheme.violet,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.contactName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: AppTheme.ink.withValues(alpha: 0.55),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (direction == ContactDirection.incoming)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          onPressed: () => fs.acceptContact(uid, request.contactUid),
                          icon: const Icon(Icons.check_circle_rounded, color: Colors.green),
                        ),
                        IconButton(
                          onPressed: () => fs.declineContact(uid, request.contactUid),
                          icon: const Icon(Icons.cancel_rounded, color: AppTheme.pink),
                        ),
                      ],
                    )
                  else
                    TextButton(
                      onPressed: () => fs.cancelContactRequest(uid, request.contactUid),
                      child: const Text('Cancel'),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
