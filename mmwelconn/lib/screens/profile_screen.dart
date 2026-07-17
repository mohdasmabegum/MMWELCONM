import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mmwelconn/models/contact_model.dart';
import 'package:mmwelconn/models/user_model.dart';
import 'package:mmwelconn/services/cloudinary_service.dart';
import 'package:mmwelconn/services/firestore_service.dart';
import 'package:mmwelconn/screens/chat_detail_screen.dart';
import 'package:mmwelconn/widgets/app_brand.dart';

class ProfileScreen extends StatefulWidget {
  final String userId;
  final String viewerUid;
  final ContactModel? contact;
  final bool editable;

  const ProfileScreen({
    super.key,
    required this.userId,
    required this.viewerUid,
    this.contact,
    this.editable = false,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirestoreService _fs = FirestoreService();
  final ImagePicker _picker = ImagePicker();
  bool _updatingPhoto = false;
  bool _editingStatus = false;

  bool get _isMe => widget.userId == widget.viewerUid;

  Future<void> _changePhoto() async {
    if (!_isMe) return;
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (file == null) return;
      setState(() => _updatingPhoto = true);
      final bytes = await file.readAsBytes();
      final url = await CloudinaryService.uploadBytes(bytes, widget.userId, file.name);
      await _fs.updateUser(widget.userId, {'profilePicture': url});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated ✓')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update profile photo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingPhoto = false);
    }
  }

  Future<void> _setShowOnline(bool showOnline) async {
    setState(() => _editingStatus = true);
    try {
      await _fs.setShowOnline(widget.userId, showOnline);
    } finally {
      if (mounted) setState(() => _editingStatus = false);
    }
  }

  void _editUsername(BuildContext context, String currentName) {
    final ctrl = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Name', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.ink)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'Enter your name...',
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
              final newName = ctrl.text.trim();
              if (newName.isNotEmpty) {
                await _fs.updateUser(widget.userId, {'name': newName});
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Save', style: TextStyle(color: AppTheme.violet, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contact = widget.contact;
    return Scaffold(
      body: SoftGlowBackground(
        child: SafeArea(
          child: StreamBuilder<UserModel?>(
            stream: _fs.watchUser(widget.userId),
            builder: (context, snap) {
              final user = snap.data;
              if (user == null) {
                return const Center(child: CircularProgressIndicator());
              }
              final hasMood = user.hasActiveMood;
              final expiresAt = user.currentMoodExpiresAt;
              final remaining = expiresAt != null
                  ? expiresAt.difference(DateTime.now())
                  : Duration.zero;
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Profile',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppTheme.ink,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  HoverCard(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        color: Colors.white.withValues(alpha: 0.74),
                      ),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 54,
                                backgroundColor: AppTheme.violet.withValues(alpha: 0.18),
                                backgroundImage: user.profilePicture.isNotEmpty
                                    ? NetworkImage(user.profilePicture)
                                    : null,
                                child: user.profilePicture.isEmpty
                                    ? Text(
                                        user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                                        style: const TextStyle(
                                          color: AppTheme.violet,
                                          fontSize: 28,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      )
                                    : null,
                              ),
                              if (_isMe)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: GestureDetector(
                                    onTap: _updatingPhoto ? null : _changePhoto,
                                    child: Container(
                                      width: 34,
                                      height: 34,
                                      decoration: const BoxDecoration(
                                        color: AppTheme.violet,
                                        shape: BoxShape.circle,
                                      ),
                                      child: _updatingPhoto
                                          ? const Padding(
                                              padding: EdgeInsets.all(7),
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(Icons.edit_rounded, color: Colors.white, size: 18),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                user.name,
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.ink,
                                    ),
                              ),
                              if (_isMe && widget.editable) ...[
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _editUsername(context, user.name),
                                  child: const Icon(Icons.edit_rounded, size: 18, color: AppTheme.violet),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.email,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.ink.withValues(alpha: 0.62)),
                          ),
                          const SizedBox(height: 4),                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'MM ID: ',
                                style: TextStyle(
                                  color: AppTheme.ink.withValues(alpha: 0.72),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                user.mmId,
                                style: const TextStyle(
                                  color: AppTheme.violet,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: user.mmId));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('MM ID copied to clipboard!')),
                                  );
                                },
                                child: const Icon(
                                  Icons.copy_rounded,
                                  size: 14,
                                  color: AppTheme.violet,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: [
                              _InfoChip(
                                icon: user.status == 'online' ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                                label: user.status == 'online' ? 'Online' : 'Offline',
                                color: user.status == 'online' ? Colors.green : Colors.grey,
                              ),
                              _InfoChip(
                                icon: Icons.badge_rounded,
                                label: user.mmId,
                                color: AppTheme.sky,
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: user.mmId));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('MM ID copied to clipboard!')),
                                  );
                                },
                              ),
                              if (hasMood)
                                _InfoChip(
                                  icon: Icons.favorite_rounded,
                                  label: '${user.currentMoodId}',
                                  color: AppTheme.pink,
                                ),
                              _InfoChip(
                                icon: Icons.calendar_month_rounded,
                                label: 'Joined ${_shortDate(user.createdAt)}',
                                color: AppTheme.sky,
                              ),
                            ],
                          ),
                          if (_isMe && widget.editable) ...[
                            const SizedBox(height: 16),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              value: user.showOnline,
                              onChanged: _editingStatus
                                  ? null
                                  : (value) => _setShowOnline(value),
                              title: const Text('Manual status'),
                              subtitle: const Text('Show yourself online or offline'),
                              activeColor: AppTheme.violet,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (hasMood)
                    HoverCard(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current mood',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.ink,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${user.currentMoodId}',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.ink,
                                  ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Expires in ${remaining.inHours.clamp(0, 23)}h ${remaining.inMinutes.remainder(60).clamp(0, 59)}m',
                              style: TextStyle(color: AppTheme.ink.withValues(alpha: 0.62)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (contact != null) ...[
                    const SizedBox(height: 16),
                    if (!_isMe) ...[
                      HoverCard(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final chatId = await _fs.getOrCreateDirectChat(widget.viewerUid, widget.userId);
                            final chat = await _fs.getChat(chatId);
                            if (chat != null && mounted) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ChatDetailScreen(
                                    chat: chat,
                                    currentUid: widget.viewerUid,
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.message_rounded, color: Colors.white),
                          label: const Text('Send Message', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.violet,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    HoverCard(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Connection details',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.ink,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            _DetailRow(label: 'Type', value: _pretty(contact.relationshipType.name)),
                            _DetailRow(label: 'Relation status', value: _pretty(contact.status.name)),
                            _DetailRow(label: 'Current status', value: _pretty(user.status)),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (_isMe) ...[
                    const SizedBox(height: 16),
                    HoverCard(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quick actions',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.ink,
                                  ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: HoverActionButton(
                                    label: 'Set online',
                                    icon: Icons.wifi_rounded,
                                    colors: const [Color(0xFF4CAF50), Color(0xFF81C784)],
                                    onPressed: _editingStatus ? () {} : () => _setShowOnline(true),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: HoverActionButton(
                                    label: 'Set offline',
                                    icon: Icons.wifi_off_rounded,
                                    colors: const [Color(0xFFEF5350), Color(0xFFFF8A80)],
                                    onPressed: _editingStatus ? () {} : () => _setShowOnline(false),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _pretty(String value) =>
      value.isEmpty ? 'Unknown' : value[0].toUpperCase() + value.substring(1);

  String _shortDate(DateTime date) => '${date.day}/${date.month}/${date.year}';
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _InfoChip({required this.icon, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(color: AppTheme.ink.withValues(alpha: 0.58), fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppTheme.ink, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
