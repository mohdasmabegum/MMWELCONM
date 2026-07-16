import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mmwelconn/models/reminder_model.dart';
import 'package:mmwelconn/services/firestore_service.dart';
import 'package:mmwelconn/widgets/app_brand.dart';

class OverlayPermissionHelper {
  static const _channel = MethodChannel('com.mmwelconn.mmwelconn/overlay');

  static Future<bool> checkPermission() async {
    if (kIsWeb) return true;
    if (defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      final bool granted = await _channel.invokeMethod('checkOverlayPermission');
      return granted;
    } catch (_) {
      return true;
    }
  }

  static Future<void> requestPermission() async {
    if (kIsWeb) return;
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (_) {}
  }
}

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final FirestoreService _fs = FirestoreService();
  bool _overlayPermissionGranted = true;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final granted = await OverlayPermissionHelper.checkPermission();
    if (mounted) {
      setState(() => _overlayPermissionGranted = granted);
    }
  }

  Future<void> _requestPermission() async {
    await OverlayPermissionHelper.requestPermission();
    // Re-check after returning from settings
    Future.delayed(const Duration(seconds: 1), _checkPermission);
  }

  void _showAddReminderSheet([String? prefilledDescription]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddReminderSheet(
        prefilledDescription: prefilledDescription,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return SoftGlowBackground(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Schedules',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppTheme.ink,
                        ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded, color: AppTheme.violet, size: 28),
                    onPressed: () => _showAddReminderSheet(),
                    tooltip: 'Add Schedule',
                  ),
                ],
              ),
            ),
            if (!_overlayPermissionGranted && defaultTargetPlatform == TargetPlatform.android)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: HoverCard(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.violet.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.violet.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppTheme.violet),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Draw Over Other Apps',
                                style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.ink, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Allow permission to display full-screen event alerts even when backgrounded.',
                                style: TextStyle(fontSize: 11, color: AppTheme.ink.withValues(alpha: 0.6)),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _requestPermission,
                          child: const Text('Enable', style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.violet)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(
              child: uid == null
                  ? const Center(child: Text('Please log in.'))
                  : StreamBuilder<List<ReminderModel>>(
                      stream: _fs.watchMyReminders(uid),
                      builder: (context, snap) {
                        if (snap.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final reminders = snap.data ?? [];
                        if (reminders.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.calendar_today_rounded, size: 48, color: AppTheme.ink.withValues(alpha: 0.3)),
                                const SizedBox(height: 12),
                                Text(
                                  'No schedules created yet.',
                                  style: TextStyle(color: AppTheme.ink.withValues(alpha: 0.45)),
                                ),
                              ],
                            ),
                          );
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: reminders.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _ReminderTile(reminder: reminders[i]),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  final ReminderModel reminder;
  const _ReminderTile({required this.reminder});

  String _formatDateTime(DateTime dt) {
    final String dayName = switch (dt.weekday) {
      1 => 'Mon',
      2 => 'Tue',
      3 => 'Wed',
      4 => 'Thu',
      5 => 'Fri',
      6 => 'Sat',
      7 => 'Sun',
      _ => '',
    };
    final String monthName = switch (dt.month) {
      1 => 'Jan',
      2 => 'Feb',
      3 => 'Mar',
      4 => 'Apr',
      5 => 'May',
      6 => 'Jun',
      7 => 'Jul',
      8 => 'Aug',
      9 => 'Sep',
      10 => 'Oct',
      11 => 'Nov',
      12 => 'Dec',
      _ => '',
    };
    final String h = dt.hour.toString().padLeft(2, '0');
    final String m = dt.minute.toString().padLeft(2, '0');
    return '$dayName, $monthName ${dt.day} @ $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService();
    final bool isPast = reminder.remindAt.isBefore(DateTime.now());

    return HoverCard(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(20),
          border: reminder.isCompleted
              ? Border.all(color: Colors.green.withValues(alpha: 0.2))
              : isPast
                  ? Border.all(color: Colors.red.withValues(alpha: 0.15))
                  : null,
        ),
        child: Row(
          children: [
            Checkbox(
              value: reminder.isCompleted,
              activeColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              onChanged: (value) {
                if (value != null) {
                  fs.updateReminder(reminder.id, {'isCompleted': value});
                }
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reminder.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: reminder.isCompleted ? AppTheme.ink.withValues(alpha: 0.45) : AppTheme.ink,
                      decoration: reminder.isCompleted ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (reminder.description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      reminder.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: reminder.isCompleted
                            ? AppTheme.ink.withValues(alpha: 0.35)
                            : AppTheme.ink.withValues(alpha: 0.55),
                        decoration: reminder.isCompleted ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 13,
                        color: reminder.isCompleted
                            ? Colors.grey.withValues(alpha: 0.5)
                            : isPast
                                ? Colors.red.withValues(alpha: 0.7)
                                : AppTheme.violet.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatDateTime(reminder.remindAt),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: reminder.isCompleted
                              ? Colors.grey
                              : isPast
                                  ? Colors.red
                                  : AppTheme.violet,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.delete_outline_rounded, color: Colors.red.withValues(alpha: 0.55), size: 20),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Delete Schedule?'),
                    content: const Text('Are you sure you want to delete this scheduled reminder?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () {
                          fs.deleteReminder(reminder.id);
                          Navigator.pop(context);
                        },
                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class AddReminderSheet extends StatefulWidget {
  final String? prefilledDescription;
  const AddReminderSheet({super.key, this.prefilledDescription});

  @override
  State<AddReminderSheet> createState() => _AddReminderSheetState();
}

class _AddReminderSheetState extends State<AddReminderSheet> {
  final _titleCtrl = TextEditingController();
  late final TextEditingController _descCtrl;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _descCtrl = TextEditingController(text: widget.prefilledDescription ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title for the schedule.')),
      );
      return;
    }

    final remindAt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirestoreService().createReminder(ReminderModel(
          id: '',
          userId: uid,
          title: title,
          description: _descCtrl.text.trim(),
          remindAt: remindAt,
          createdAt: DateTime.now(),
        ));
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save reminder: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: const BoxDecoration(
          color: Color(0xFFF6F8FF),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.ink.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.prefilledDescription != null ? 'Create Schedule from Chat' : 'Add New Schedule',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppTheme.ink),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: 'Schedule Title',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Description',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded, color: AppTheme.violet, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _pickTime,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_rounded, color: AppTheme.pink, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _selectedTime.format(context),
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.violet,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppTheme.violet.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
              child: Text(_saving ? 'Scheduling...' : 'Create Schedule', style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}
