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

class TeenHubScreen extends StatefulWidget {
  const TeenHubScreen({super.key});

  @override
  State<TeenHubScreen> createState() => _TeenHubScreenState();
}

class _TeenHubScreenState extends State<TeenHubScreen> with TickerProviderStateMixin {
  final FirestoreService _fs = FirestoreService();
  final uid = FirebaseAuth.instance.currentUser?.uid;

  // Tabs: 0=Hub & Profile, 1=Stories & Squad, 2=Study & Focus, 3=Health & Music
  int _activeTab = 0;

  // Theme states
  String _teenTheme = 'neon'; // neon, anime, gaming, pastel

  // Profile Customization state
  int _avatarIndex = 0;
  final List<String> _profileAvatars = [
    'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150',
  ];
  final TextEditingController _bioCtrl = TextEditingController(text: "I'm a gamer 🎮 | Music lover 🎵");
  final List<String> _interests = ['Gaming', 'Music', 'Sports', 'Art'];
  final List<String> _allInterests = ['Gaming', 'Music', 'Sports', 'Art', 'Coding', 'Anime', 'K-Pop', 'Skating'];
  final List<String> _moodPhotos = [
    'https://images.unsplash.com/photo-1511512578047-dfb367046420?w=200', // Gaming setup
    'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=200', // DJ/Music
  ];
  final List<String> _moodQuotes = [
    "Keep grindin' 🚀",
    "Life is like a game, leveling up every day. 🎮",
  ];

  // Animated Moods particles
  bool _showHearts = false;
  bool _showStars = false;
  String _emojiMashupResult = '😊';
  String _selectedMash1 = '😊';
  String _selectedMash2 = '🔥';

  // Gradient Chat Bubble palette
  Color _bubbleColor1 = Colors.purple;
  Color _bubbleColor2 = Colors.pinkAccent;

  // Social Features (Stories)
  final List<Map<String, dynamic>> _stories = [
    {'sender': 'Alex 🛹', 'photo': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=80', 'song': 'Starboy - The Weeknd 🎵', 'text': 'Skating session at downtown park!', 'views': 12, 'reactions': 4},
    {'sender': 'Sarah 🌸', 'photo': 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=80', 'song': 'Dynamite - BTS 🎵', 'text': 'Studying with matcha latte 🍵', 'views': 18, 'reactions': 7},
  ];

  // Group Mood averages
  final Map<String, dynamic> _groupMoods = {
    'Gaming Squad': {'emoji': '😎', 'label': 'Hyped'},
    'Class of 2028': {'emoji': '😴', 'label': 'Tired (Exam stress)'},
    'Besties Group': {'emoji': '🥳', 'label': 'Excited'},
  };

  // Weekly Mood statistics
  final List<double> _weeklyMoodStats = [70, 80, 50, 40, 90, 100, 85]; // Mon - Sun

  // Focus Timer Pomodoro State
  late AnimationController _timerController;
  bool _isTimerRunning = false;
  int _secondsRemaining = 25 * 60;
  Timer? _timer;
  String _focusAmbientSound = 'Rain';
  bool _isPlayingAmbient = false;
  late AnimationController _eqController;
  int _totalFocusedHours = 4;

  // Homework Tracker
  final List<Map<String, dynamic>> _homeworks = [
    {'title': 'Math Chapter 5 Quiz', 'priority': 'High', 'done': false, 'subject': 'Math'},
    {'title': 'Chemistry Lab Report', 'priority': 'Medium', 'done': true, 'subject': 'Science'},
    {'title': 'English Essay Draft', 'priority': 'Low', 'done': false, 'subject': 'English'},
  ];

  // Subject mood tracking
  final Map<String, String> _subjectMoods = {
    'Math': '😊 I love Math!',
    'Science': '😅 Hard but interesting',
    'English': '😴 Boring lectures...',
  };

  // Sleep log
  int _sleepRatingStars = 4;
  final List<int> _sleepHistoryHours = [7, 6, 8, 5, 7, 8, 6];

  // Mental Health check-ins
  String _dailyStressLevel = 'Medium';
  int _monthlyAnxietyScale = 5;

  // Screen time tracking
  double _screenTimeHours = 2.4;
  bool _detoxActive = false;

  // Payments State (Minor Limit = 5k)
  final List<Map<String, String>> _linkedBanks = [
    {'name': 'Youth Card Account', 'account': '**** 1120'},
  ];
  final List<String> _linkedUpis = ['timmy@upi'];
  final TextEditingController _bankNameCtrl = TextEditingController();
  final TextEditingController _bankAccCtrl = TextEditingController();
  final TextEditingController _upiIdCtrl = TextEditingController();
  final TextEditingController _sendUpiCtrl = TextEditingController();
  final TextEditingController _sendAmtCtrl = TextEditingController();
  double _dailySpentSoFar = 400.0;
  bool _isTransferring = false;
  double _transferProgress = 0.0;
  bool _transferSuccess = false;

  @override
  void initState() {
    super.initState();
    _timerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25 * 60),
    );
    _eqController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    // Default chat bubble colors
    _updateBubbleColors();
  }

  void _updateBubbleColors() {
    if (_teenTheme == 'neon') {
      _bubbleColor1 = Colors.deepPurple;
      _bubbleColor2 = Colors.purpleAccent;
    } else if (_teenTheme == 'pastel') {
      _bubbleColor1 = Colors.pink.shade200;
      _bubbleColor2 = Colors.orange.shade200;
    } else {
      _bubbleColor1 = Colors.teal;
      _bubbleColor2 = Colors.greenAccent;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timerController.dispose();
    _eqController.dispose();
    _bioCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankAccCtrl.dispose();
    _upiIdCtrl.dispose();
    _sendUpiCtrl.dispose();
    _sendAmtCtrl.dispose();
    super.dispose();
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

    // Daily Limit check: Minor account, limit is 5000 INR per day
    const double limit = 5000.0;
    if (_dailySpentSoFar + amt > limit) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('⚠️ Minor Daily Limit Exceeded'),
          content: const Text(
            'Transfer failed. Daily Limit is 5,000 INR for Minor Accounts.\nRemaining limit: 4,600 INR',
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

  // Focus Timer Logic
  void _startTimer() {
    if (_timer != null) _timer!.cancel();
    setState(() => _isTimerRunning = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
          _timerController.value = 1.0 - (_secondsRemaining / (25 * 60));
        });
      } else {
        _timer?.cancel();
        setState(() {
          _isTimerRunning = false;
          _secondsRemaining = 25 * 60;
          _timerController.value = 0.0;
        });
        HapticFeedback.heavyImpact();
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('🎯 Focused Reward!'),
            content: const Text("You've been focused for another interval. Study Star badge unlocked! ⭐"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Awesome')),
            ],
          ),
        );
      }
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() => _isTimerRunning = false);
  }

  // Emoji Mashup calculator
  void _createMashup() {
    setState(() {
      if (_selectedMash1 == '😊' && _selectedMash2 == '🔥') {
        _emojiMashupResult = '🥵 (Hot smile)';
      } else if (_selectedMash1 == '😊' && _selectedMash2 == '🎉') {
        _emojiMashupResult = '🥳 (Party face)';
      } else if (_selectedMash1 == '😴' && _selectedMash2 == '🔥') {
        _emojiMashupResult = '💥 (Burnout)';
      } else {
        _emojiMashupResult = '🤪 (Custom Crazy)';
      }
    });
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    final vibe = AppTheme.vibe;

    // Digital Detox lockout page
    if (_detoxActive) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('📵', style: TextStyle(fontSize: 80)),
                const SizedBox(height: 20),
                const Text('Digital Detox Active!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 12),
                const Text(
                  'Disconnecting helps clear your mind. Challenge yourself to stay off the screen for 24 hours!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => setState(() => _detoxActive = false),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
                  child: const Text('Stop Detox Challenge', style: TextStyle(color: Colors.white)),
                )
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _getTeenBgColor(),
      body: SafeArea(
        child: Column(
          children: [
            // Teen Mode Custom Navigation header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '⚡ TEEN ZONE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: vibe.primaryColor,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Connect & Focus',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Top Theme Selector
                  DropdownButton<String>(
                    value: _teenTheme,
                    dropdownColor: Colors.black87,
                    underline: const SizedBox(),
                    items: ['neon', 'anime', 'gaming', 'pastel'].map((theme) {
                      return DropdownMenuItem(
                        value: theme,
                        child: Text(
                          theme.toUpperCase(),
                          style: TextStyle(color: vibe.primaryColor, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _teenTheme = val;
                          _updateBubbleColors();
                        });
                        AppTheme.updateVibe('teen', val);
                      }
                    },
                  )
                ],
              ),
            ),

            // Tabs layout bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  _buildTabBtn(0, '🎮 Hub'),
                  _buildTabBtn(1, '👥 Squad'),
                  _buildTabBtn(2, '📚 Study'),
                  _buildTabBtn(3, '🧘 Health'),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Tab Workspace Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Stack(
                  children: [
                    _buildActiveTabContent(),
                    // Particle effects elements overlay
                    if (_showHearts) ..._buildHeartParticles(),
                    if (_showStars) ..._buildStarParticles(),
                  ],
                ),
              ),
            )
          ],
        ),
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

  Widget _buildActiveTabContent() {
    switch (_activeTab) {
      case 0:
        return _buildHubTab();
      case 1:
        return _buildSquadTab();
      case 2:
        return _buildStudyTab();
      case 3:
        return _buildHealthTab();
      default:
        return const SizedBox();
    }
  }

  // 1. Hub & Profile Tab
  Widget _buildHubTab() {
    final vibe = AppTheme.vibe;
    return Column(
      children: [
        // profile picture carousel card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              const Text('Customizable Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              // Picture carousel
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white54, size: 16),
                    onPressed: () {
                      setState(() {
                        _avatarIndex = (_avatarIndex - 1 + _profileAvatars.length) % _profileAvatars.length;
                      });
                    },
                  ),
                  CircleAvatar(
                    radius: 48,
                    backgroundImage: NetworkImage(_profileAvatars[_avatarIndex]),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                    onPressed: () {
                      setState(() {
                        _avatarIndex = (_avatarIndex + 1) % _profileAvatars.length;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Bio field
              TextField(
                controller: _bioCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Your Bio',
                  labelStyle: TextStyle(color: Colors.white60),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              // Interests Tags
              const Align(alignment: Alignment.centerLeft, child: Text('Your Interests:', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold))),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _interests.map((intName) {
                  return Chip(
                    backgroundColor: vibe.primaryColor.withValues(alpha: 0.2),
                    label: Text(intName, style: const TextStyle(color: Colors.white, fontSize: 11)),
                    onDeleted: () {
                      setState(() {
                        _interests.remove(intName);
                      });
                    },
                  );
                }).toList(),
              ),
              TextButton.icon(
                onPressed: _showAddInterestsDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Interest Tags'),
              )
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Animated Moods card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              const Text('Animated Moods & Mashups', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() => _showStars = true);
                      Future.delayed(const Duration(seconds: 2), () => setState(() => _showStars = false));
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                    child: const Text('Sparkle Mood 🌟'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() => _showHearts = true);
                      Future.delayed(const Duration(seconds: 2), () => setState(() => _showHearts = false));
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
                    child: const Text('Love Vibe ❤️'),
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 24),
              const Text('Emoji Mashup Creator', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DropdownButton<String>(
                    value: _selectedMash1,
                    dropdownColor: Colors.black87,
                    items: ['😊', '😴', '😭', '😎'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 20)))).toList(),
                    onChanged: (v) => setState(() => _selectedMash1 = v!),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('+', style: TextStyle(color: Colors.white, fontSize: 20)),
                  ),
                  DropdownButton<String>(
                    value: _selectedMash2,
                    dropdownColor: Colors.black87,
                    items: ['🔥', '🎉', '💔', '👽'].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 20)))).toList(),
                    onChanged: (v) => setState(() => _selectedMash2 = v!),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _createMashup,
                    style: ElevatedButton.styleFrom(backgroundColor: vibe.primaryColor),
                    child: const Text('Mash!'),
                  )
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Result: $_emojiMashupResult',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.yellowAccent),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Gradient Chat Bubbles Picker
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Gradient Chat Bubbles preview', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 12),
              // Gradient Chat Bubble demo
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [_bubbleColor1, _bubbleColor2]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Yo! This is a preview of my gradient chat bubble. It looks super fresh!',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildColorDot(Colors.purple, Colors.pinkAccent),
                  _buildColorDot(Colors.teal, Colors.greenAccent),
                  _buildColorDot(Colors.orange, Colors.redAccent),
                  _buildColorDot(Colors.indigo, Colors.blueAccent),
                ],
              )
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Teen Payments Section (Minor 5k limit)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('💵 Minor Wallet & Daily Limits', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 6),
              const Text('Daily Limit: 5,000 INR (Minor Account)', style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _dailySpentSoFar / 5000.0,
                backgroundColor: Colors.white12,
                color: Colors.amberAccent,
                minHeight: 6,
              ),
              const SizedBox(height: 6),
              Text('Spent Today: ${_dailySpentSoFar.toInt()} / 5,000 INR', style: const TextStyle(color: Colors.white70, fontSize: 11)),
              const Divider(color: Colors.white12),
              const Text('💳 Linked Bank Cards', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ..._linkedBanks.map((b) => ListTile(
                    dense: true,
                    title: Text(b['name']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    subtitle: Text(b['account']!, style: const TextStyle(color: Colors.white60, fontSize: 11)),
                  )),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _bankNameCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: const InputDecoration(hintText: 'Card Name...', labelStyle: TextStyle(color: Colors.white60)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _bankAccCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: const InputDecoration(hintText: 'Last 4 digits...', labelStyle: TextStyle(color: Colors.white60)),
                    ),
                  ),
                  IconButton(onPressed: _linkBank, icon: const Icon(Icons.add_circle, color: Colors.greenAccent)),
                ],
              ),
              const Divider(color: Colors.white12),
              const Text('📱 Linked UPI IDs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ..._linkedUpis.map((u) => Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Text(u, style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  )),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _upiIdCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: const InputDecoration(hintText: 'Link new UPI ID...', labelStyle: TextStyle(color: Colors.white60)),
                    ),
                  ),
                  IconButton(onPressed: _linkUpi, icon: const Icon(Icons.add_circle, color: Colors.greenAccent)),
                ],
              ),
              const Divider(color: Colors.white12),
              const Text('💸 Send Money Transfer (Speed)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              TextField(
                controller: _sendUpiCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: const InputDecoration(labelText: 'Recipient UPI ID', labelStyle: TextStyle(color: Colors.white60)),
              ),
              TextField(
                controller: _sendAmtCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (INR)', labelStyle: TextStyle(color: Colors.white60)),
              ),
              const SizedBox(height: 12),
              if (_isTransferring) ...[
                const Text('Executing Speed Transfer... ⚡', style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: _transferProgress, color: vibe.primaryColor),
              ] else if (_transferSuccess) ...[
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                    SizedBox(width: 8),
                    Text('Transfer Success! 🚀 Sent in seconds.', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ] else ...[
                ElevatedButton(
                  onPressed: _executeTransfer,
                  style: ElevatedButton.styleFrom(backgroundColor: vibe.primaryColor),
                  child: const Text('Send Money', style: TextStyle(color: Colors.white)),
                )
              ]
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildColorDot(Color c1, Color c2) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _bubbleColor1 = c1;
          _bubbleColor2 = c2;
        });
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [c1, c2]),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
        ),
      ),
    );
  }

  void _showAddInterestsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Select Interests', style: TextStyle(color: Colors.white)),
        content: Wrap(
          spacing: 8,
          children: _allInterests.map((interest) {
            final active = _interests.contains(interest);
            return FilterChip(
              selected: active,
              label: Text(interest),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _interests.add(interest);
                  } else {
                    _interests.remove(interest);
                  }
                });
                Navigator.pop(context);
                _showAddInterestsDialog();
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
        ],
      ),
    );
  }

  // 2. Social & Stories & Trends Tab
  Widget _buildSquadTab() {
    return Column(
      children: [
        // 24 Hour Stories Log
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('🔥 Mood Stories (24h)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ..._stories.map((st) {
                return Card(
                  color: Colors.white.withValues(alpha: 0.05),
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: CircleAvatar(backgroundImage: NetworkImage(st['photo']!)),
                    title: Text(st['sender']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(st['text']!, style: const TextStyle(color: Colors.white70)),
                        const SizedBox(height: 4),
                        Text(st['song']!, style: const TextStyle(color: Colors.amberAccent, fontSize: 11)),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('👁️ ${st['views']}', style: const TextStyle(color: Colors.white38, fontSize: 10)),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: ['😍', '🔥', '👍'].map((react) {
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  st['reactions']++;
                                });
                                HapticFeedback.lightImpact();
                              },
                              child: Text(react, style: const TextStyle(fontSize: 14)),
                            );
                          }).toList(),
                        )
                      ],
                    ),
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Group Squad Mood Badge
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('👥 Group Squad Mood', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ..._groupMoods.keys.map((group) {
                final data = _groupMoods[group];
                return ListTile(
                  dense: true,
                  title: Text(group, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text('Vibe: ${data['label']}', style: const TextStyle(color: Colors.white60)),
                  trailing: Text(data['emoji'], style: const TextStyle(fontSize: 24)),
                );
              }),
              const Divider(color: Colors.white12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.military_tech, color: Colors.amber),
                  Text(' Badge: Squad is Happy Today! 🎉', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
                ],
              )
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Weekly Mood Trends graph
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('📈 Weekly Mood Trends', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(_weeklyMoodStats.length, (idx) {
                    final heightFactor = _weeklyMoodStats[idx] / 100.0;
                    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('${_weeklyMoodStats[idx].toInt()}%', style: const TextStyle(color: Colors.white54, fontSize: 8)),
                        const SizedBox(height: 4),
                        Container(
                          width: 14,
                          height: 60 * heightFactor,
                          decoration: BoxDecoration(
                            color: Colors.purpleAccent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(days[idx], style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    );
                  }),
                ),
              ),
              const SizedBox(height: 12),
              const Text('💡 Best Mood Day: Saturday (100% happy)', style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
              const Text('💡 Worst Mood Day: Thursday (40% tired - Exam Stress?)', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  // 3. Study Countdown & Focus Timer Tab
  Widget _buildStudyTab() {
    final vibe = AppTheme.vibe;
    final minStr = (_secondsRemaining ~/ 60).toString().padLeft(2, '0');
    final secStr = (_secondsRemaining % 60).toString().padLeft(2, '0');

    return Column(
      children: [
        // Exam count downs
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('⏰ Upcoming Exams Countdown', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Text('📐 Math Algebra Exam', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Spacer(),
                    Text('3 Days Left! 😰 (Nervous)', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              )
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Focus mode Pomodoro timer
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.hourglass_empty, color: Colors.purpleAccent),
                  const SizedBox(width: 8),
                  const Text('Focus mode Pomodoro timer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 16),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: CircularProgressIndicator(
                      value: _timerController.value,
                      strokeWidth: 8,
                      backgroundColor: Colors.white12,
                      color: Colors.purpleAccent,
                    ),
                  ),
                  Column(
                    children: [
                      Text('$minStr:$secStr', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                      Text(_isTimerRunning ? 'FOCUS' : 'PAUSE', style: const TextStyle(color: Colors.purpleAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  )
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _isTimerRunning ? _pauseTimer : _startTimer,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
                    child: Text(_isTimerRunning ? 'Pause' : 'Start'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: () {
                      _pauseTimer();
                      setState(() {
                        _secondsRemaining = 25 * 60;
                        _timerController.value = 0.0;
                      });
                    },
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white30)),
                    child: const Text('Reset', style: TextStyle(color: Colors.white)),
                  )
                ],
              ),
              const SizedBox(height: 10),
              // Ambient loop audio picker
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Ambient Sound loop:', style: TextStyle(color: Colors.white70, fontSize: 11)),
                  if (_isPlayingAmbient)
                    AnimatedBuilder(
                      animation: _eqController,
                      builder: (context, child) => Row(
                        children: List.generate(4, (idx) {
                          final val = math.sin((_eqController.value + idx / 4) * math.pi).abs();
                          return Container(width: 2, height: 4 + 10 * val, color: Colors.purpleAccent, margin: const EdgeInsets.symmetric(horizontal: 1));
                        }),
                      ),
                    )
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['Rain 🌧️', 'Lofi 🎵', 'Cafe ☕', 'None 🔇'].map((sound) {
                  final active = _focusAmbientSound == sound && _isPlayingAmbient;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (sound == 'None 🔇') {
                          _isPlayingAmbient = false;
                        } else {
                          _focusAmbientSound = sound;
                          _isPlayingAmbient = true;
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: active ? Colors.purpleAccent.withValues(alpha: 0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: active ? Colors.purpleAccent : Colors.white24),
                      ),
                      child: Text(sound, style: const TextStyle(color: Colors.white, fontSize: 10)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Text('Focus Log completed today: $_totalFocusedHours hours! 🎯 (Badge unlocked)', style: const TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Homework Tracker checklist
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('📚 Homework Tracker checklist', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ..._homeworks.map((hw) {
                return CheckboxListTile(
                  value: hw['done'],
                  activeColor: Colors.purpleAccent,
                  title: Text(hw['title']!, style: TextStyle(color: Colors.white, fontSize: 12, decoration: hw['done'] ? TextDecoration.lineThrough : null)),
                  subtitle: Text('Priority: ${hw['priority']} • Subject: ${hw['subject']}', style: TextStyle(color: hw['priority'] == 'High' ? Colors.redAccent : Colors.white54, fontSize: 10)),
                  onChanged: (val) {
                    setState(() {
                      hw['done'] = val ?? false;
                    });
                  },
                );
              }).toList(),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Subject moods tracker
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('🎭 Subject-by-Subject Mood Tracker', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ..._subjectMoods.keys.map((sub) {
                final mood = _subjectMoods[sub];
                return ListTile(
                  dense: true,
                  title: Text(sub, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text(mood!, style: const TextStyle(color: Colors.white70)),
                  trailing: const Icon(Icons.edit_note, color: Colors.purpleAccent),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // 4. Health & Wellness Tab
  Widget _buildHealthTab() {
    return Column(
      children: [
        // Sleep Tracker Log
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('💤 Sleep Tracker Log', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (idx) {
                  final active = idx < _sleepRatingStars;
                  return IconButton(
                    icon: Icon(active ? Icons.star : Icons.star_border, color: Colors.amber, size: 28),
                    onPressed: () {
                      setState(() {
                        _sleepRatingStars = idx + 1;
                      });
                    },
                  );
                }),
              ),
              const Text('Goal: Aim for 8 hours • Avg: 6.8 hours', textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 8),
              const Text('💡 Suggestion: "You sleep 6.2 hours avg. You are tired, take a 20 min nap!"', style: TextStyle(color: Colors.yellowAccent, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Mood + Music suggestions
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('🎵 Mood + Music Suggestion', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("You're feeling tired, listen to energetic tunes:", style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 10),
              // Spotify mockup
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFF1DB954), borderRadius: BorderRadius.circular(16)),
                child: const Row(
                  children: [
                    Icon(Icons.music_note, color: Colors.white),
                    SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Lofi Energy Boost Mix ⚡', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        Text('Spotify Integration playlist (10 happy songs)', style: TextStyle(color: Colors.white70, fontSize: 10)),
                      ],
                    )
                  ],
                ),
              )
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Mental Health check-ins
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('🧠 Mental Health Check-in Logs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Daily Stress Level:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  DropdownButton<String>(
                    value: _dailyStressLevel,
                    dropdownColor: Colors.black87,
                    items: ['Low', 'Medium', 'High'].map((l) => DropdownMenuItem(value: l, child: Text(l, style: const TextStyle(color: Colors.white)))).toList(),
                    onChanged: (v) => setState(() => _dailyStressLevel = v!),
                  )
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Monthly Anxiety (1-10):', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  DropdownButton<int>(
                    value: _monthlyAnxietyScale,
                    dropdownColor: Colors.black87,
                    items: List.generate(10, (idx) => idx + 1).map((val) => DropdownMenuItem(value: val, child: Text(val.toString(), style: const TextStyle(color: Colors.white)))).toList(),
                    onChanged: (v) => setState(() => _monthlyAnxietyScale = v!),
                  )
                ],
              ),
              const Divider(color: Colors.white12),
              const Text('💡 Feeling stressed? Here is a help checklist. Call 988 for support.', style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Screen time Detox Challenge tracker
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('📱 Screen Time Detox Tracker', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Text('You have used the app for $_screenTimeHours hours today.', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _detoxActive = true;
                  });
                },
                icon: const Icon(Icons.block),
                label: const Text('Start 24h Digital Detox Challenge'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
              )
            ],
          ),
        ),
      ],
    );
  }

  // Particle Generators
  List<Widget> _buildHeartParticles() {
    return List.generate(8, (idx) {
      final rand = math.Random();
      return Positioned(
        left: rand.nextInt(300).toDouble(),
        top: rand.nextInt(400).toDouble(),
        child: const Text('❤️', style: TextStyle(fontSize: 24)),
      );
    });
  }

  List<Widget> _buildStarParticles() {
    return List.generate(10, (idx) {
      final rand = math.Random();
      return Positioned(
        left: rand.nextInt(300).toDouble(),
        top: rand.nextInt(400).toDouble(),
        child: const Text('🌟', style: TextStyle(fontSize: 20)),
      );
    });
  }

  Color _getTeenBgColor() {
    if (_teenTheme == 'neon') {
      return const Color(0xFF0C0A1F);
    } else if (_teenTheme == 'pastel') {
      return const Color(0xFF1D1B28);
    } else if (_teenTheme == 'anime') {
      return const Color(0xFF141324);
    } else {
      return const Color(0xFF0F172A);
    }
  }
}
