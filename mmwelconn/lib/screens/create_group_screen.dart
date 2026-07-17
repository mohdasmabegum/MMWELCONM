import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mmwelconn/models/contact_model.dart';
import 'package:mmwelconn/models/chat_model.dart';
import 'package:mmwelconn/services/firestore_service.dart';
import 'package:mmwelconn/screens/chat_detail_screen.dart';
import 'package:mmwelconn/widgets/app_brand.dart';
import 'package:transparent_image/transparent_image.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final FirestoreService _fs = FirestoreService();
  final String _currentUid = FirebaseAuth.instance.currentUser!.uid;
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  final TextEditingController _customCategoryCtrl = TextEditingController();
  String _selectedCategory = 'Friends';
  final Set<String> _selectedUids = {};
  bool _creating = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _customCategoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    final groupName = _nameCtrl.text.trim();
    if (groupName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name.')),
      );
      return;
    }
    if (_selectedUids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one contact.')),
      );
      return;
    }

    setState(() => _creating = true);
    try {
      final category = _selectedCategory == 'Others' && _customCategoryCtrl.text.trim().isNotEmpty
          ? '${_customCategoryCtrl.text.trim()} (Others)'
          : _selectedCategory;

      final chatId = await _fs.createGroupChat(
        creatorUid: _currentUid,
        groupName: groupName,
        participantIds: _selectedUids.toList(),
        groupDescription: _descCtrl.text.trim(),
        groupCategory: category,
      );

      final chat = await _fs.getChat(chatId);
      if (!mounted) return;
      
      if (chat != null) {
        // Replace current screen with the new group chat detail screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ChatDetailScreen(
              chat: chat,
              currentUid: _currentUid,
            ),
          ),
        );
      } else {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _creating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create group: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SoftGlowBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 20, 12),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.ink),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Create Group Chat',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppTheme.ink,
                          ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        hintText: 'Enter group name...',
                        labelText: 'Group Name',
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.88),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _descCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Enter group description...',
                        labelText: 'Description',
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.88),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButtonFormField<String>(
                          value: _selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Group Category',
                            border: InputBorder.none,
                          ),
                          items: ['Professional', 'Friends', 'Family', 'Others']
                              .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedCategory = val);
                          },
                        ),
                      ),
                    ),
                    if (_selectedCategory == 'Others') ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _customCategoryCtrl,
                        decoration: InputDecoration(
                          hintText: 'Enter custom category name...',
                          labelText: 'Custom Category',
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.88),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Text(
                      'Select Contacts (${_selectedUids.length} selected)',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.ink,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<ContactModel>>(
                  stream: _fs.watchContacts(_currentUid, status: ContactStatus.accepted),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final contacts = snap.data ?? [];
                    if (contacts.isEmpty) {
                      return Center(
                        child: Text(
                          'No connections available.',
                          style: TextStyle(color: AppTheme.ink.withValues(alpha: 0.45)),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: contacts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final c = contacts[idx];
                        final isSelected = _selectedUids.contains(c.contactUid);
                        return HoverCard(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedUids.remove(c.contactUid);
                                } else {
                                  _selectedUids.add(c.contactUid);
                                }
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected 
                                    ? AppTheme.violet.withValues(alpha: 0.08)
                                    : Colors.white.withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected 
                                      ? AppTheme.violet.withValues(alpha: 0.4)
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundImage: c.contactPhotoUrl.isNotEmpty 
                                        ? NetworkImage(c.contactPhotoUrl) 
                                        : null,
                                    backgroundColor: AppTheme.violet.withValues(alpha: 0.18),
                                    child: c.contactPhotoUrl.isEmpty
                                        ? Text(
                                            c.contactName.isNotEmpty ? c.contactName[0].toUpperCase() : '?',
                                            style: const TextStyle(
                                              color: AppTheme.violet, 
                                              fontWeight: FontWeight.w800,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      c.contactName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700, 
                                        color: AppTheme.ink,
                                      ),
                                    ),
                                  ),
                                  Checkbox(
                                    value: isSelected,
                                    activeColor: AppTheme.violet,
                                    shape: const CircleBorder(),
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedUids.add(c.contactUid);
                                        } else {
                                          _selectedUids.remove(c.contactUid);
                                        }
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                child: ElevatedButton(
                  onPressed: _creating ? null : _createGroup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.violet,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.violet.withValues(alpha: 0.4),
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _creating 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Create Group Chat',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
