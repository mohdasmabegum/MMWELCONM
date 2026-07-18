import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mmwelconm/models/user_model.dart';
import 'package:mmwelconm/models/reminder_model.dart';
import 'package:mmwelconm/services/firestore_service.dart';
import 'package:mmwelconm/widgets/app_brand.dart';

class AdultSuiteScreen extends StatefulWidget {
  const AdultSuiteScreen({super.key});

  @override
  State<AdultSuiteScreen> createState() => _AdultSuiteScreenState();
}

class _AdultSuiteScreenState extends State<AdultSuiteScreen> with TickerProviderStateMixin {
  final FirestoreService _fs = FirestoreService();
  final uid = FirebaseAuth.instance.currentUser?.uid;

  // Tabs: 0=Work & Commute, 1=Family & Chores, 2=Health & Wellness, 3=Finance
  int _activeTab = 0;

  // Theme settings (Default Dark Mode, clean Blue/Gray scheme)
  bool _isDarkMode = true;

  // Quick Actions States
  String _activeMood = 'Happy'; // Happy, Busy, Tired
  String _activeLocation = 'Work'; // Home, Work, Out
  String _activeStatus = 'Available'; // Available, Busy, Away

  // Work Schedule & Commute
  final List<Map<String, dynamic>> _workShifts = [
    {'title': 'Annual Board Meeting 💼', 'time': '10:00 AM', 'room': 'Boardroom A'},
    {'title': 'Code Review Sync 💻', 'time': '02:30 PM', 'room': 'Zoom Link'},
  ];
  String _commuteStatus = 'Office Office hum 🚗';
  String _commuteEta = '30 mins';
  bool _trafficAlert = true;

  // Vacation Planner
  int _vacationDaysRemaining = 32;

  // Shared Family Calendar
  final List<Map<String, dynamic>> _familyEvents = [
    {'title': 'Soccer Practice ⚽', 'time': '05:00 PM', 'member': 'Timmy'},
    {'title': 'Dentist Appointment 🦷', 'time': '09:30 AM', 'member': 'Mom'},
    {'title': 'Parent-Teacher Meeting 🏫', 'time': '04:00 PM', 'member': 'Dad'},
  ];

  // Shared Grocery List
  final List<Map<String, dynamic>> _groceries = [
    {'item': 'Whole Milk 🥛', 'done': false},
    {'item': 'Organic Eggs 🥚', 'done': true},
    {'item': 'Sourdough Bread 🍞', 'done': false},
  ];
  final TextEditingController _groceryCtrl = TextEditingController();

  // Chore Schedule rotation
  final List<Map<String, dynamic>> _chores = [
    {'chore': 'Clean Kitchen Counter 🧼', 'member': 'Dad', 'status': 'Pending'},
    {'chore': 'Water garden plants 🌻', 'member': 'Timmy', 'status': 'Done'},
    {'chore': 'Cook dinner night 🍲', 'member': 'Mom', 'status': 'Pending'},
  ];

  // Parent-Teen Mood Check logs
  final List<String> _moodAlerts = [
    'Teen Timmy: Seems stressed today. Talk to them? 💬',
    'Daughter Lily: Feeling happy today! 🌟',
  ];

  // Mood + Food & Exercise logs
  final List<Map<String, dynamic>> _meals = [
    {'meal': 'Breakfast (Avocado Toast)', 'healthy': true, 'logged': true},
    {'meal': 'Lunch (Quinoa Salad)', 'healthy': true, 'logged': true},
    {'meal': 'Dinner (Grilled Salmon)', 'healthy': true, 'logged': false},
  ];
  int _workoutStreak = 5;
  double _waterDrankGlasses = 5.0; // target 8

  // Breathing meditation exercise state
  late AnimationController _breathingController;
  bool _isMeditating = false;

  // Financial Features
  final List<Map<String, dynamic>> _bills = [
    {'bill': 'Electricity Bill ⚡', 'amount': 120.0, 'dueDate': '25th', 'paid': false},
    {'bill': 'Apartment Rent 🏠', 'amount': 1500.0, 'dueDate': '1st', 'paid': true},
    {'bill': 'Credit Card Payment 💳', 'amount': 340.0, 'dueDate': '28th', 'paid': false},
  ];
  double _monthlyBudget = 1000.0;
  double _amountSpent = 800.0;

  // Savings Goal
  double _vacationFundSaved = 1450.0;
  double _vacationFundGoal = 2000.0;

  // Payments State
  final List<Map<String, String>> _linkedBanks = [
    {'name': 'Capital One Venture', 'account': '**** 4040'},
  ];
  final List<String> _linkedUpis = ['adult@upi'];
  final TextEditingController _bankNameCtrl = TextEditingController();
  final TextEditingController _bankAccCtrl = TextEditingController();
  final TextEditingController _upiIdCtrl = TextEditingController();
  final TextEditingController _sendUpiCtrl = TextEditingController();
  final TextEditingController _sendAmtCtrl = TextEditingController();
  double _dailySpentSoFar = 3500.0;
  bool _isTransferring = false;
  double _transferProgress = 0.0;
  bool _transferSuccess = false;

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _groceryCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankAccCtrl.dispose();
    _upiIdCtrl.dispose();
    _sendUpiCtrl.dispose();
    _sendAmtCtrl.dispose();
    super.dispose();
  }

  void _triggerBreathingMeditation() {
    if (_isMeditating) {
      _breathingController.stop();
      setState(() => _isMeditating = false);
    } else {
      _breathingController.repeat(reverse: true);
      setState(() => _isMeditating = true);
    }
  }

  void _linkBank() {
    if (_bankNameCtrl.text.trim().isEmpty || _bankAccCtrl.text.trim().isEmpty) return;
    setState(() {
      _linkedBanks.add({
        'name': _bankNameCtrl.text.trim(),
        'account': '**** ${_bankAccCtrl.text.trim()}',
      });
      _bankNameCtrl.clear();
      _bankAccCtrl.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bank platinum Card Linked! 💳')),
    );
  }

  void _linkUpi() {
    if (_upiIdCtrl.text.trim().isEmpty) return;
    setState(() {
      _linkedUpis.add(_upiIdCtrl.text.trim());
      _upiIdCtrl.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('UPI Address Added! 📱')),
    );
  }

  void _executeTransfer() {
    final amtStr = _sendAmtCtrl.text.trim();
    final upi = _sendUpiCtrl.text.trim();
    if (amtStr.isEmpty || upi.isEmpty) return;

    final amt = double.tryParse(amtStr) ?? 0.0;
    if (amt <= 0) return;

    // Daily limit check for Major accounts is 100,000 INR
    const double limit = 100000.0;
    if (_dailySpentSoFar + amt > limit) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('⚠️ Daily Limit Exceeded'),
          content: const Text(
            'Transfer failed. Daily Limit is 100,000 INR for Major Accounts.\nRemaining limit: 96,500 INR',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    setState(() {
      _isTransferring = true;
      _transferProgress = 0.0;
      _transferSuccess = false;
    });

    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_transferProgress < 1.0) {
        setState(() {
          _transferProgress += 0.2;
        });
      } else {
        timer.cancel();
        setState(() {
          _isTransferring = false;
          _transferSuccess = true;
          _dailySpentSoFar += amt;
        });
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _transferSuccess = false;
              _sendAmtCtrl.clear();
              _sendUpiCtrl.clear();
            });
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vibe = AppTheme.vibe;
    final cardBgColor = _isDarkMode ? const Color(0xFF1E293B) : Colors.white;
    final textColor = _isDarkMode ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: _isDarkMode ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Column(
          children: [
            // Head Section (Dark mode toggler)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '💼 ADULT SUITE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: vibe.primaryColor,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Work-Life Synergy',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: textColor),
                      ),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(_isDarkMode ? Icons.wb_sunny : Icons.nights_stay, color: vibe.primaryColor),
                    onPressed: () {
                      setState(() {
                        _isDarkMode = !_isDarkMode;
                      });
                    },
                  )
                ],
              ),
            ),

            // One-Tap Quick Actions bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Quick Actions widget (Home Screen 2x2)', style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Mood selector
                      _buildQuickDropdown(
                        'Mood',
                        _activeMood,
                        ['Happy', 'Busy', 'Tired'],
                        (val) => setState(() => _activeMood = val),
                        Colors.orangeAccent,
                      ),
                      // Location selector
                      _buildQuickDropdown(
                        'Location',
                        _activeLocation,
                        ['Home', 'Work', 'Out'],
                        (val) => setState(() => _activeLocation = val),
                        Colors.blueAccent,
                      ),
                      // Status selector
                      _buildQuickDropdown(
                        'Status',
                        _activeStatus,
                        ['Available', 'Busy', 'Away'],
                        (val) => setState(() => _activeStatus = val),
                        Colors.greenAccent,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Tab bar switcher
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  _buildTabBtn(0, '💼 Work'),
                  _buildTabBtn(1, '👪 Family'),
                  _buildTabBtn(2, '🧘 Wellness'),
                  _buildTabBtn(3, '💳 Finance'),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Tab View Contents
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildActiveTabContent(cardBgColor, textColor),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildQuickDropdown(String label, String value, List<String> options, ValueChanged<String> onChanged, Color iconCol) {
    final textColor = _isDarkMode ? Colors.white : Colors.black;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.adjust, color: iconCol, size: 12),
          const SizedBox(width: 4),
          DropdownButton<String>(
            value: value,
            underline: const SizedBox(),
            dropdownColor: _isDarkMode ? const Color(0xFF1E293B) : Colors.white,
            style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold),
            items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          )
        ],
      ),
    );
  }

  Widget _buildTabBtn(int idx, String label) {
    final active = _activeTab == idx;
    final color = AppTheme.vibe.primaryColor;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _activeTab = idx);
          HapticFeedback.lightImpact();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: active ? Border.all(color: color, width: 1.5) : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: active ? Colors.white : Colors.white60,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveTabContent(Color cardBg, Color textCol) {
    switch (_activeTab) {
      case 0:
        return _buildWorkTab(cardBg, textCol);
      case 1:
        return _buildFamilyTab(cardBg, textCol);
      case 2:
        return _buildWellnessTab(cardBg, textCol);
      case 3:
        return _buildFinanceTab(cardBg, textCol);
      default:
        return const SizedBox();
    }
  }

  // Tab 1: Work Schedule & Commute
  Widget _buildWorkTab(Color cardBg, Color textCol) {
    return Column(
      children: [
        // Work Shifts List
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('💼 Work Schedule Shifts', style: TextStyle(color: textCol, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ..._workShifts.map((sh) {
                return ListTile(
                  dense: true,
                  title: Text(sh['title']!, style: TextStyle(color: textCol, fontWeight: FontWeight.bold)),
                  subtitle: Text('Time: ${sh['time']} • Room: ${sh['room']}', style: TextStyle(color: textCol.withValues(alpha: 0.6))),
                  trailing: const Icon(Icons.alarm, color: Colors.blueAccent),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Commute Location Map Widget
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('🚗 Commute & ETA Status', style: TextStyle(color: textCol, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              // Map representation container
              Container(
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                ),
                child: const Center(
                  child: Text('🗺️ Commute Map showing route', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              Text('Commute State: $_commuteStatus', style: TextStyle(color: textCol, fontSize: 13, fontWeight: FontWeight.bold)),
              Text('ETA: $_commuteEta', style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold)),
              if (_trafficAlert)
                const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.redAccent, size: 14),
                    SizedBox(width: 4),
                    Text('Traffic Alert: Heavy traffic, 15 min delay on Route 4', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                  ],
                )
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Vacation countdown
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('✈️ Vacation Planner', style: TextStyle(color: textCol, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text('Family trip trip next month: $_vacationDaysRemaining Days Remaining! 🎉', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              const Text('Leave Request: Off Dec 20-25 (Approved ✓)', style: TextStyle(color: Colors.green, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }

  // Tab 2: Family Management & Chores
  Widget _buildFamilyTab(Color cardBg, Color textCol) {
    return Column(
      children: [
        // Shared family calendar events
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('👪 Shared Family Calendar', style: TextStyle(color: textCol, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ..._familyEvents.map((e) {
                return ListTile(
                  dense: true,
                  title: Text(e['title']!, style: TextStyle(color: textCol, fontWeight: FontWeight.bold)),
                  subtitle: Text('Member: ${e['member']} • Time: ${e['time']}', style: TextStyle(color: textCol.withValues(alpha: 0.6))),
                  trailing: const Icon(Icons.family_restroom, color: Colors.purpleAccent),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Shared Grocery shopping list
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('🛒 Shared Grocery List', style: TextStyle(color: textCol, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ..._groceries.map((item) {
                return CheckboxListTile(
                  value: item['done'],
                  activeColor: AppTheme.vibe.primaryColor,
                  title: Text(item['item']!, style: TextStyle(color: textCol, decoration: item['done'] ? TextDecoration.lineThrough : null, fontSize: 12)),
                  onChanged: (val) {
                    setState(() {
                      item['done'] = val ?? false;
                    });
                  },
                );
              }),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _groceryCtrl,
                      style: TextStyle(color: textCol, fontSize: 12),
                      decoration: const InputDecoration(hintText: 'Add grocery item...'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.greenAccent),
                    onPressed: () {
                      if (_groceryCtrl.text.trim().isNotEmpty) {
                        setState(() {
                          _groceries.add({'item': _groceryCtrl.text.trim(), 'done': false});
                          _groceryCtrl.clear();
                        });
                      }
                    },
                  )
                ],
              )
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Chore schedule rotation
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('🧹 Chore Schedule Rotation', style: TextStyle(color: textCol, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ..._chores.map((ch) {
                return ListTile(
                  dense: true,
                  title: Text(ch['chore']!, style: TextStyle(color: textCol, fontWeight: FontWeight.bold)),
                  subtitle: Text('Assigned: ${ch['member']} • Status: ${ch['status']}', style: TextStyle(color: textCol.withValues(alpha: 0.6))),
                  trailing: Icon(ch['status'] == 'Done' ? Icons.check_circle : Icons.circle_outlined, color: Colors.green),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Parent-Teen Mood Check logs
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('🚨 Parent-Teen Mood Check Alerts', style: TextStyle(color: textCol, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ..._moodAlerts.map((al) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(al, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // Tab 3: Health, Wellness & Meditation breathing
  Widget _buildWellnessTab(Color cardBg, Color textCol) {
    return Column(
      children: [
        // Breathing meditation widget
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(24)),
          child: Column(
            children: [
              Text('🧘 Meditation & Breathing Exercise', style: TextStyle(color: textCol, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              // Breathing grow/shrink animation
              Center(
                child: AnimatedBuilder(
                  animation: _breathingController,
                  builder: (context, child) {
                    final size = 80 + 60 * _breathingController.value;
                    return Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.15 + 0.3 * _breathingController.value),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blueAccent, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          _breathingController.value > 0.5 ? 'Breathe Out 💨' : 'Breathe In 🧘',
                          style: TextStyle(color: textCol, fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _triggerBreathingMeditation,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                child: Text(_isMeditating ? 'Pause Meditation' : 'Start 5 min Meditation'),
              )
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Mood + Food meal logs
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('🍱 Meal & Food Logging', style: TextStyle(color: textCol, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ..._meals.map((m) {
                return CheckboxListTile(
                  value: m['logged'],
                  activeColor: Colors.blueAccent,
                  title: Text(m['meal']!, style: TextStyle(color: textCol, fontSize: 12)),
                  subtitle: Text('Healthy Meal? ${m['healthy'] ? "Yes ✓" : "No"}', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                  onChanged: (val) {
                    setState(() {
                      m['logged'] = val ?? false;
                    });
                  },
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Gym tracker logs
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('🏃 Gym & Exercise logs', style: TextStyle(color: textCol, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text('Workout Streak: $_workoutStreak days! 🔥', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              const Text('Scheduled: Gym at 6:00 PM tonight (Gym alert active)', style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  // Tab 4: Financial Bills & Budgets
  Widget _buildFinanceTab(Color cardBg, Color textCol) {
    return Column(
      children: [
        // Bill reminders
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('💳 Bill Reminders Scheduler', style: TextStyle(color: textCol, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ..._bills.map((b) {
                return ListTile(
                  dense: true,
                  title: Text(b['bill']!, style: TextStyle(color: textCol, fontWeight: FontWeight.bold)),
                  subtitle: Text('Amount: \$${b['amount']} • Due on ${b['dueDate']}', style: TextStyle(color: textCol.withValues(alpha: 0.6))),
                  trailing: Checkbox(
                    value: b['paid'],
                    activeColor: Colors.green,
                    onChanged: (val) {
                      setState(() {
                        b['paid'] = val ?? false;
                      });
                    },
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Expense tracker budget limits
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('📊 Monthly Budget limit: \$${_monthlyBudget.toInt()}', style: TextStyle(color: textCol, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: _amountSpent / _monthlyBudget,
                backgroundColor: Colors.white12,
                color: _amountSpent >= _monthlyBudget ? Colors.redAccent : Colors.greenAccent,
                minHeight: 10,
              ),
              const SizedBox(height: 6),
              Text('Spent so far: \$${_amountSpent.toInt()} / \$${_monthlyBudget.toInt()}', style: TextStyle(color: textCol.withValues(alpha: 0.7), fontSize: 11)),
              if (_amountSpent >= _monthlyBudget)
                const Text('⚠️ Warning: You are over budget!', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Savings Fund
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('💰 Vacation Savings Goal progress', style: TextStyle(color: textCol, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: _vacationFundSaved / _vacationFundGoal,
                backgroundColor: Colors.white12,
                color: Colors.amberAccent,
                minHeight: 8,
              ),
              const SizedBox(height: 6),
              Text('Saved: \$${_vacationFundSaved.toInt()} / \$${_vacationFundGoal.toInt()}', style: TextStyle(color: textCol.withValues(alpha: 0.7), fontSize: 11)),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Payments Limits Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('💳 Linked Bank Cards', style: TextStyle(color: textCol, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._linkedBanks.map((b) => ListTile(
                    dense: true,
                    title: Text(b['name']!, style: TextStyle(color: textCol, fontWeight: FontWeight.bold)),
                    subtitle: Text(b['account']!, style: TextStyle(color: textCol.withValues(alpha: 0.6))),
                  )),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _bankNameCtrl,
                      style: TextStyle(color: textCol, fontSize: 12),
                      decoration: const InputDecoration(hintText: 'Card Name...'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _bankAccCtrl,
                      style: TextStyle(color: textCol, fontSize: 12),
                      decoration: const InputDecoration(hintText: 'Last 4 digits...'),
                    ),
                  ),
                  IconButton(onPressed: _linkBank, icon: const Icon(Icons.add, color: Colors.greenAccent)),
                ],
              ),
              const Divider(color: Colors.white12),
              Text('📱 Linked UPI IDs', style: TextStyle(color: textCol, fontWeight: FontWeight.bold)),
              ..._linkedUpis.map((u) => Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: Text(u, style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  )),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _upiIdCtrl,
                      style: TextStyle(color: textCol, fontSize: 12),
                      decoration: const InputDecoration(hintText: 'Link new UPI ID...'),
                    ),
                  ),
                  IconButton(onPressed: _linkUpi, icon: const Icon(Icons.add, color: Colors.greenAccent)),
                ],
              )
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Send Money Form
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('💸 Send Money Transfer (Speed)', style: TextStyle(color: textCol, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: _sendUpiCtrl,
                style: TextStyle(color: textCol),
                decoration: const InputDecoration(labelText: 'Recipient UPI ID', labelStyle: TextStyle(color: Colors.grey)),
              ),
              TextField(
                controller: _sendAmtCtrl,
                style: TextStyle(color: textCol),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (INR)', labelStyle: TextStyle(color: Colors.grey)),
              ),
              const SizedBox(height: 16),
              if (_isTransferring) ...[
                const Text('Executing Speed Transfer... ⚡', style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: _transferProgress, color: AppTheme.vibe.primaryColor),
              ] else if (_transferSuccess) ...[
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.greenAccent),
                    SizedBox(width: 8),
                    Text('Transfer Success! 🚀 Sent in seconds.', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
                  ],
                ),
              ] else ...[
                ElevatedButton(
                  onPressed: _executeTransfer,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.vibe.primaryColor),
                  child: const Text('Send Money', style: TextStyle(color: Colors.white)),
                )
              ]
            ],
          ),
        ),
      ],
    );
  }
}
