import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mmwelconn/models/chat_model.dart';
import 'package:mmwelconn/models/mood_model.dart';
import 'package:mmwelconn/services/cloudinary_service.dart';
import 'package:mmwelconn/services/firestore_service.dart';
import 'package:mmwelconn/widgets/app_brand.dart';
import 'package:share_plus/share_plus.dart';

class PhotosScreen extends StatefulWidget {
  const PhotosScreen({super.key});

  @override
  State<PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends State<PhotosScreen> {
  final FirestoreService _fs = FirestoreService();
  final ImagePicker _picker = ImagePicker();
  final String _uid = FirebaseAuth.instance.currentUser!.uid;
  bool _uploading = false;

  Future<void> _pickAndUpload(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 80);
      if (file == null) return;
      setState(() => _uploading = true);
      final bytes = await file.readAsBytes();
      final url = await CloudinaryService.uploadBytes(bytes, _uid, file.name);
      final user = await _fs.getUser(_uid);
      await _fs.postMood(MoodModel(
        id: '',
        userId: _uid,
        userDisplayName: user?.name ?? '',
        userPhotoUrl: user?.profilePicture ?? '',
        emoji: '📷',
        label: 'Photo',
        moodPhotoUrl: url,
        isPublic: false,
        createdAt: DateTime.now(),
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo saved to your account ✓')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _viewLargeImage(BuildContext context, MoodModel mood) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: InteractiveViewer(
                  child: Image.network(
                    mood.moodPhotoUrl!,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator(color: Colors.white));
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Share to Chat'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _sharePhoto(context, mood);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.violet,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.ios_share_rounded),
                    label: const Text('Share External'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      Share.share(mood.moodPhotoUrl!, subject: 'MMWelConn Photo');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.pink,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _sharePhoto(BuildContext context, MoodModel mood) async {
    final chats = await _fs.watchMyChats(_uid).first;
    if (!context.mounted) return;
    if (chats.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No chats available')),
      );
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: const BoxDecoration(
          color: Color(0xFFF6F8FF),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Share to Chat',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.ink),
            ),
            const SizedBox(height: 12),
            ...chats.map((chat) {
              final name = chat.chatType == ChatType.group
                  ? (chat.groupName ?? 'Group')
                  : chat.participantNames.entries
                      .firstWhere((e) => e.key != _uid, orElse: () => const MapEntry('', 'Unknown'))
                      .value;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.violet.withValues(alpha: 0.15),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(color: AppTheme.violet, fontWeight: FontWeight.w800),
                  ),
                ),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: () async {
                  Navigator.pop(context);
                  final user = await _fs.getUser(_uid);
                  await _fs.sendMessage(
                    chat.id,
                    MessageModel(
                      id: '',
                      senderId: _uid,
                      senderName: user?.name ?? '',
                      text: '',
                      imageUrl: mood.moodPhotoUrl,
                      createdAt: DateTime.now(),
                    ),
                    chat.participantIds,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Photo shared to $name ✓')),
                    );
                  }
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SoftGlowBackground(
        child: SafeArea(
          child: ListView(
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
                    'My Photos',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.normal,
                          color: AppTheme.ink,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              HoverCard(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Save photos to your account',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.ink,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Choose from camera or gallery. Your saved photos live here, separate from the home screen.',
                        style: TextStyle(color: AppTheme.ink.withValues(alpha: 0.62)),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: HoverActionButton(
                              label: _uploading ? 'Uploading...' : 'Camera',
                              icon: Icons.camera_alt_rounded,
                              colors: const [Color(0xFF4E8DFF), Color(0xFF7B61FF)],
                              onPressed: _uploading ? () {} : () => _pickAndUpload(ImageSource.camera),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: HoverActionButton(
                              label: _uploading ? 'Uploading...' : 'Gallery',
                              icon: Icons.photo_library_rounded,
                              colors: const [Color(0xFFFF6F91), Color(0xFFFF8A65)],
                              onPressed: _uploading ? () {} : () => _pickAndUpload(ImageSource.gallery),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              StreamBuilder<List<MoodModel>>(
                stream: _fs.watchUserMoodPhotos(_uid),
                builder: (context, snap) {
                  final photos = snap.data ?? [];
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(),
                    ));
                  }
                  if (photos.isEmpty) {
                    return Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.68),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Center(
                        child: Text(
                          'No saved photos yet',
                          style: TextStyle(color: AppTheme.ink.withValues(alpha: 0.48)),
                        ),
                      ),
                    );
                  }
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: photos.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.0,
                    ),
                    itemBuilder: (context, index) {
                      final mood = photos[index];
                      return GestureDetector(
                        onTap: () => _viewLargeImage(context, mood),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(
                                mood.moodPhotoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: AppTheme.violet.withValues(alpha: 0.1),
                                  child: const Icon(Icons.broken_image_rounded, color: AppTheme.violet),
                                ),
                              ),
                              Align(
                                alignment: Alignment.bottomLeft,
                                child: Container(
                                  margin: const EdgeInsets.all(6),
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'View',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 10),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
