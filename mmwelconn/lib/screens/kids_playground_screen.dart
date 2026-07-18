import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mmwelconm/models/user_model.dart';
import 'package:mmwelconm/models/mood_model.dart';
import 'package:mmwelconm/services/firestore_service.dart';
import 'package:mmwelconm/widgets/app_brand.dart';

class KidsPlaygroundScreen extends StatefulWidget {
  const KidsPlaygroundScreen({super.key});

  @override
  State<KidsPlaygroundScreen> createState() => _KidsPlaygroundScreenState();
}

class _KidsPlaygroundScreenState extends State<KidsPlaygroundScreen> with TickerProviderStateMixin {
  final FirestoreService _fs = FirestoreService();
  final uid = FirebaseAuth.instance.currentUser?.uid;

  // Simple Nav State: 0 = Chat, 1 = Mood (Emojis, Draw, Pet), 2 = Photos (Gallery/Study)
  int _currentKidsTab = 1;

  // Swipe theme background settings
  final List<String> _bgThemes = ['space', 'ocean', 'forest'];
  int _activeBgIdx = 0;

  // Drawing Canvas points
  List<DrawingPoint?> _points = [];
  Color _selectedColor = Colors.red;
  double _strokeWidth = 5.0;
  final List<Color> _canvasColors = [
    Colors.red,
    Colors.blue,
    Colors.yellow,
    Colors.green,
    Colors.purple,
    Colors.orange,
  ];
  final List<Map<String, dynamic>> _savedDrawings = [];

  // Animated Emojis state
  String _activeBouncingEmoji = '';
  late AnimationController _bounceController;

  // Voice recording & Transcription Easy Mock
  bool _isRecording = false;
  String _voiceTranscription = '';

  // Screen Time & Bedtime locks
  int _secondsRemaining = 3600; // 1 hour default
  Timer? _countdownTimer;
  bool _screenLocked = false;
  bool _bedtimeLocked = false;

  // Virtual Pet companion state
  int _petHappiness = 80;
  String _petMood = 'Happy'; // Happy, Sad, Exciting
  late AnimationController _petAnimationController;

  // Homework check items
  final List<Map<String, dynamic>> _homeworks = [
    {'title': 'Math Homework Math Book 📚', 'done': false},
    {'title': 'Read Bedtime Story 📖', 'done': false},
    {'title': 'Pack School Bag 🎒', 'done': false},
  ];

  // Voice Guide guidance alerts text
  String _voiceGuideText = 'Tap here to draw and play! 🔊';

  // Parent Zone Settings
  final TextEditingController _pinCtrl = TextEditingController();
  bool _parentAccessGranted = false;
  bool _chatMonitoring = true;
  bool _safetyFiltersActive = true;
  double _parentScreenTimeHours = 1.0;
  int _parentBedtimeHour = 20; // 8 PM default

  // Friends Approval Mock List
  final List<Map<String, String>> _pendingFriends = [
    {'name': 'Sarah', 'mmId': 'KID778'},
    {'name': 'Tommy', 'mmId': 'KID124'},
  ];

  // Chats data structure for Kids Chat Zone
  final List<Map<String, dynamic>> _chatMessages = [
    {'sender': 'Mom 👩', 'relation': 'family', 'text': 'Hi Timmy! Did you pack your bag? 🎒'},
    {'sender': 'Alex 👦', 'relation': 'friend', 'text': 'Hey let\'s play games today! 🎮'},
    {'sender': 'Mrs. Davis 👩‍🏫', 'relation': 'teacher', 'text': 'Hi Timmy! Math homework page 14 is due tomorrow.'},
  ];
  final TextEditingController _chatSendCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _petAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _startTimers();
    _loadParentSettings();
  }

  void _loadParentSettings() async {
    if (uid == null) return;
    final user = await _fs.getUser(uid!);
    if (user != null && mounted) {
      setState(() {
        _parentScreenTimeHours = user.kidsScreenTimeLimitHours;
        _secondsRemaining = (_parentScreenTimeHours * 3600).toInt();
        _parentBedtimeHour = user.kidsBedtimeHour;
        final themeIdx = _bgThemes.indexOf(user.kidsBgTheme);
        if (themeIdx != -1) _activeBgIdx = themeIdx;
      });
    }
  }

  void _startTimers() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      
      // Bedtime checks (auto locks if local hour >= bedtime hour)
      final hourNow = DateTime.now().hour;
      if (hourNow >= _parentBedtimeHour || hourNow < 7) {
        if (!_bedtimeLocked) {
          setState(() {
            _bedtimeLocked = true;
          });
        }
      } else {
        if (_bedtimeLocked) {
          setState(() {
            _bedtimeLocked = false;
          });
        }
      }

      // Screen time checks
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        if (!_screenLocked) {
          setState(() {
            _screenLocked = true;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _bounceController.dispose();
    _petAnimationController.dispose();
    _pinCtrl.dispose();
    _chatSendCtrl.dispose();
    super.dispose();
  }

  void _swipeTheme(bool left) {
    setState(() {
      if (left) {
        _activeBgIdx = (_activeBgIdx - 1 + _bgThemes.length) % _bgThemes.length;
      } else {
        _activeBgIdx = (_activeBgIdx + 1) % _bgThemes.length;
      }
      _voiceGuideText = 'Theme swiped! Background is now ${_bgThemes[_activeBgIdx]}! 🔊';
    });
    if (uid != null) {
      _fs.updateUser(uid!, {'kidsBgTheme': _bgThemes[_activeBgIdx]});
    }
  }

  void _bounceEmoji(String emoji, String moodLabel) async {
    setState(() {
      _activeBouncingEmoji = emoji;
      _petMood = moodLabel == 'Sleepy' ? 'Sad' : (moodLabel == 'Excited' ? 'Exciting' : 'Happy');
    });
    _bounceController.forward(from: 0.0);
    HapticFeedback.mediumImpact();

    // Post to Firestore
    if (uid != null) {
      final user = await _fs.getUser(uid!);
      await _fs.postMood(MoodModel(
        id: '',
        userId: uid!,
        userDisplayName: user?.name ?? 'Kid',
        userPhotoUrl: user?.profilePicture ?? '',
        emoji: emoji,
        label: moodLabel,
        isPublic: true,
        createdAt: DateTime.now(),
      ));
      await _fs.setCurrentMood(uid!, moodLabel);
    }
  }

  // Draw diary gallery
  void _saveMoodDrawing() {
    if (_points.isEmpty) return;
    setState(() {
      _savedDrawings.add({
        'points': List<DrawingPoint?>.from(_points),
        'time': DateTime.now(),
      });
      _points = [];
      _voiceGuideText = 'Saved your mood art to photos! 🎨🔊';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Mood Art saved successfully! 🏆')),
    );
  }

  // Voice note simulation
  void _startVoiceLogging() {
    setState(() {
      _isRecording = true;
      _voiceTranscription = 'Listening to your voice... 🎙️';
    });
    Future.delayed(const Duration(seconds: 3), () async {
      if (!mounted) return;
      final transcriptions = [
        'I am playing with my toys and feeling super happy today! 🧸',
        'Just had some awesome ice cream! 🍦 It was delicious!',
        'Ready to go to space in my rocket ship! 🚀 Woohoo!',
        'Feeling creative today, doing some cool painting! 🎨',
      ];
      final result = transcriptions[math.Random().nextInt(transcriptions.length)];
      setState(() {
        _isRecording = false;
        _voiceTranscription = result;
        _chatMessages.add({
          'sender': 'Me 👦',
          'relation': 'family',
          'text': '🎤 Voice Note: $result',
        });
      });
    });
  }

  // Kids Zone Parent Controls Gateway Verification
  void _verifyParentPin() {
    if (_pinCtrl.text == '1234' || _pinCtrl.text == '5555') {
      setState(() {
        _parentAccessGranted = true;
      });
      _pinCtrl.clear();
    } else {
      HapticFeedback.vibrate();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wrong PIN! Ask your parents for help. 🔑')),
      );
      _pinCtrl.clear();
    }
  }

  // Feed pet handler
  void _feedPet() {
    setState(() {
      _petHappiness = math.min(100, _petHappiness + 10);
      _petMood = 'Exciting';
      _voiceGuideText = 'Yummy! Fluffy is happy! 🍩🐾';
    });
    HapticFeedback.mediumImpact();
  }

  @override
  Widget build(BuildContext context) {
    // Bedtime Lock Screen
    if (_bedtimeLocked) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('💤', style: TextStyle(fontSize: 100)),
              const SizedBox(height: 24),
              const Text(
                'Goodnight Timmy!',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 12),
              const Text(
                'It is past 8:00 PM. App is locked until 7:00 AM.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 36),
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Dialing parents... 📞 Emergency Call')),
                  );
                },
                icon: const Icon(Icons.phone, color: Colors.white),
                label: const Text('Call Parents Only', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Screen Time Lock Screen
    if (_screenLocked) {
      return Scaffold(
        backgroundColor: const Color(0xFF020617),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('⏰', style: TextStyle(fontSize: 100)),
              const SizedBox(height: 24),
              const Text(
                "Time's Up!",
                style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.amber),
              ),
              const SizedBox(height: 12),
              const Text(
                'Let\'s go play outside and stretch! 🌞',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 36),
              ElevatedButton(
                onPressed: _showParentZoneDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigoAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                ),
                child: const Text('Parent Unlock', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      );
    }

    final themeName = _bgThemes[_activeBgIdx];

    return Scaffold(
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity != null) {
            if (details.primaryVelocity! > 0) {
              _swipeTheme(true); // swipe right
            } else if (details.primaryVelocity! < 0) {
              _swipeTheme(false); // swipe left
            }
          }
        },
        child: Container(
          decoration: _getThemeDecoration(themeName),
          child: SafeArea(
            child: Stack(
              children: [
                // Twinkling stars / Floating Bubbles theme animations
                if (themeName == 'space') ..._buildSpaceDecorations(),
                if (themeName == 'ocean') ..._buildOceanDecorations(),
                if (themeName == 'forest') ..._buildForestDecorations(),

                Column(
                  children: [
                    // Kids Header
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('🧸 PLAYGROUND', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.orangeAccent, letterSpacing: 1.5)),
                              const SizedBox(height: 2),
                              Text('Kids Vibe Mode: ${themeName.toUpperCase()} 🌟', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                            ],
                          ),
                          const Spacer(),
                          // Screen Time Counter indicator
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(16)),
                            child: Row(
                              children: [
                                const Icon(Icons.timer, color: Colors.amber, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  '${(_secondsRemaining ~/ 60)} min left',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                )
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _showParentZoneDialog,
                            icon: const Icon(Icons.security, size: 14),
                            label: const Text('Parents'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purpleAccent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Cute floating voice guidance bar
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.yellowAccent, width: 2),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.volume_up, color: Colors.purple),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _voiceGuideText,
                              style: const TextStyle(color: Colors.purple, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          )
                        ],
                      ),
                    ),

                    // Navigation: Exactly 3 buttons (Icons only)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNavIconBtn(Icons.chat_bubble_rounded, 0, 'Let\'s chat with family! 🔊'),
                          _buildNavIconBtn(Icons.face, 1, 'Tell fluffy how you feel! 🔊'),
                          _buildNavIconBtn(Icons.palette_rounded, 2, 'Let\'s draw your mood art! 🔊'),
                        ],
                      ),
                    ),

                    // Dynamic tab zone
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: _buildActiveKidsTabWidget(),
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavIconBtn(IconData icon, int index, String voiceText) {
    final active = _currentKidsTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentKidsTab = index;
          _voiceGuideText = voiceText;
        });
        HapticFeedback.lightImpact();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: active ? Colors.amber : Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: active ? Colors.black : Colors.white, size: 28),
      ),
    );
  }

  Widget _buildActiveKidsTabWidget() {
    switch (_currentKidsTab) {
      case 0:
        return _buildKidsChatTab();
      case 1:
        return _buildKidsMoodTab();
      case 2:
        return _buildKidsDrawTab();
      default:
        return const SizedBox();
    }
  }

  // 1. Kids Chat Tab
  Widget _buildKidsChatTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('💬 Kids Chat Space', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              // Message Logs
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _chatMessages.length,
                itemBuilder: (context, idx) {
                  final msg = _chatMessages[idx];
                  final relation = msg['relation'];
                  Color bubbleColor = Colors.greenAccent; // friends
                  if (relation == 'family') bubbleColor = Colors.yellowAccent;
                  if (relation == 'teacher') bubbleColor = Colors.pinkAccent;

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                        bottomRight: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg['sender']!,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black54),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          msg['text']!,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              // Send panel
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatSendCtrl,
                      decoration: InputDecoration(
                        hintText: 'Type to chat...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () {
                      if (_chatSendCtrl.text.trim().isEmpty) return;
                      // Content filter checking
                      final bad = ['hate', 'stupid', 'ugly', 'angry'];
                      bool filtered = false;
                      for (var b in bad) {
                        if (_chatSendCtrl.text.toLowerCase().contains(b)) {
                          filtered = true;
                          break;
                        }
                      }
                      if (filtered) {
                        setState(() {
                          _voiceGuideText = 'Filter blocked bad words! Let\'s be friendly! 🌟🔊';
                        });
                        return;
                      }

                      setState(() {
                        _chatMessages.add({
                          'sender': 'Me 👦',
                          'relation': 'family',
                          'text': _chatSendCtrl.text,
                        });
                        _chatSendCtrl.clear();
                      });
                    },
                    icon: const Icon(Icons.send, color: Colors.amber),
                  )
                ],
              )
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Sticker Share Box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              const Text('✨ Cartoon Stickers', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['🦄', '🦖', '🛸', '🦁', '🐱'].map((st) {
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _chatMessages.add({
                          'sender': 'Me 👦',
                          'relation': 'family',
                          'text': 'Sticker: $st',
                        });
                        _voiceGuideText = 'Sticker shared! 🦄🔊';
                      });
                    },
                    child: Text(st, style: const TextStyle(fontSize: 32)),
                  );
                }).toList(),
              )
            ],
          ),
        ),
      ],
    );
  }

  // 2. Kids Mood, Virtual Pet, Emojis Tab
  Widget _buildKidsMoodTab() {
    return Column(
      children: [
        // BIG EMOJIS (120x120 size)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              const Text('😊 How are you today? 😊', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              // Emojis list
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ('😊', 'Happy'),
                    ('😢', 'Sad'),
                    ('😴', 'Sleepy'),
                    ('😎', 'Cool'),
                    ('🤗', 'Hugs'),
                    ('🎉', 'Party'),
                    ('📚', 'Smart')
                  ].map((m) {
                    return GestureDetector(
                      onTap: () => _bounceEmoji(m.$1, m.$2),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.yellowAccent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.yellowAccent, width: 2),
                        ),
                        child: Center(
                          child: Text(m.$1, style: const TextStyle(fontSize: 64)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Virtual Pet Companion
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              const Text('🐾 Virtual Pet Fluffy 🐾', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              // Animated Pet character
              AnimatedBuilder(
                animation: _petAnimationController,
                builder: (context, child) {
                  double dy = 0;
                  double scale = 1.0;
                  if (_petMood == 'Happy') {
                    dy = math.sin(_petAnimationController.value * math.pi * 2) * 10;
                  } else if (_petMood == 'Exciting') {
                    dy = -math.sin(_petAnimationController.value * math.pi) * 20;
                    scale = 1.1;
                  }
                  return Transform.translate(
                    offset: Offset(0, dy),
                    child: Transform.scale(
                      scale: scale,
                      child: Column(
                        children: [
                          Text(
                            _petMood == 'Happy' ? '🐶' : (_petMood == 'Exciting' ? '🐕🎉' : '🐶🥺'),
                            style: const TextStyle(fontSize: 72),
                          ),
                          const SizedBox(height: 6),
                          Text('Fluffy feels: $_petMood (${_petHappiness}% happiness)', style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _feedPet,
                    icon: const Icon(Icons.cookie, size: 14),
                    label: const Text('Feed treats 🍩'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _petHappiness = 100;
                        _petMood = 'Happy';
                        _voiceGuideText = 'Fluffy gives you a big hug! 🤗🐾';
                      });
                    },
                    icon: const Icon(Icons.favorite, size: 14),
                    label: const Text('Hug Fluffy 🤗'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
                  ),
                ],
              )
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Voice to Text Mood Logger Easy Conversion
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              const Text('🎙️ Voice mood Logger 🎙️', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _isRecording ? null : _startVoiceLogging,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _isRecording ? Colors.redAccent : Colors.amberAccent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_isRecording ? Icons.mic : Icons.mic_none, size: 32, color: Colors.black),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _isRecording ? 'Listening...' : 'Tap Mic to speak!',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              if (_voiceTranscription.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'Transcript: "$_voiceTranscription"',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.yellowAccent, fontSize: 12, fontWeight: FontWeight.bold),
                )
              ]
            ],
          ),
        ),
      ],
    );
  }

  // 3. Drawing Canvas Tab (Mood Art Gallery & Homework Scheduler)
  Widget _buildKidsDrawTab() {
    return Column(
      children: [
        // Mood Diary Drawing Canvas
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              const Text('🎨 Drawing Diary 🎨', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              // Drawing Box
              Container(
                width: double.infinity,
                height: 250,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: GestureDetector(
                  onPanStart: (details) {
                    final box = context.findRenderObject() as RenderBox?;
                    if (box != null) {
                      final point = box.globalToLocal(details.globalPosition);
                      setState(() {
                        _points.add(DrawingPoint(
                          offset: Offset(point.dx, point.dy - 120),
                          paint: Paint()
                            ..color = _selectedColor
                            ..strokeCap = StrokeCap.round
                            ..strokeWidth = _strokeWidth,
                        ));
                      });
                    }
                  },
                  onPanUpdate: (details) {
                    final box = context.findRenderObject() as RenderBox?;
                    if (box != null) {
                      final point = box.globalToLocal(details.globalPosition);
                      setState(() {
                        _points.add(DrawingPoint(
                          offset: Offset(point.dx, point.dy - 120),
                          paint: Paint()
                            ..color = _selectedColor
                            ..strokeCap = StrokeCap.round
                            ..strokeWidth = _strokeWidth,
                        ));
                      });
                    }
                  },
                  onPanEnd: (details) {
                    setState(() {
                      _points.add(null);
                    });
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CustomPaint(
                      painter: DrawingPainter(pointsList: _points),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // 6 Colors selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ..._canvasColors.map((color) {
                    final active = _selectedColor == color;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedColor = color;
                        });
                      },
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: active ? Border.all(color: Colors.black, width: 3) : null,
                        ),
                      ),
                    );
                  }).toList(),
                  IconButton(
                    icon: const Icon(Icons.clear, color: Colors.red),
                    onPressed: () => setState(() => _points = []),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check_box_outlined, color: Colors.greenAccent),
                    onPressed: _saveMoodDrawing,
                  ),
                ],
              )
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Homework check-ins & School schedule
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('📚 Homework & School Tasks', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ..._homeworks.map((hw) {
                return CheckboxListTile(
                  value: hw['done'],
                  activeColor: Colors.amber,
                  checkColor: Colors.black,
                  title: Text(hw['title']!, style: TextStyle(color: Colors.white, fontSize: 13, decoration: hw['done'] ? TextDecoration.lineThrough : null)),
                  onChanged: (val) {
                    setState(() {
                      hw['done'] = val ?? false;
                      _voiceGuideText = val == true ? 'Yay! Task completed! 🌟🔊' : 'Task updated. 🔊';
                    });
                  },
                );
              }).toList(),
              const Divider(color: Colors.white24),
              const SizedBox(height: 6),
              // School bus location status
              const Row(
                children: [
                  Icon(Icons.directions_bus, color: Colors.amberAccent),
                  const SizedBox(width: 8),
                  Text('School Bus: Near Main Street (10 mins) 🚌', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              )
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Bedtime story Narrator
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              const Text('🛌 Bedtime Story narration player', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Listen to recorded stories while sleeping 🎧', style: TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _voiceGuideText = 'Now narrating bedtime story: The Magic Unicorn. 🦄🔊';
                      });
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play story 🦄'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _voiceGuideText = 'Bedtime story playback paused. 🔊';
                      });
                    },
                    icon: const Icon(Icons.pause),
                    label: const Text('Pause'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
                  ),
                ],
              )
            ],
          ),
        ),
      ],
    );
  }

  // Cartoon Background Decorations build helpers
  BoxDecoration _getThemeDecoration(String name) {
    if (name == 'space') {
      return const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E1E2E)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      );
    } else if (name == 'ocean') {
      return const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0C4A6E), Color(0xFF0284C7)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      );
    } else {
      return const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF064E3B), Color(0xFF047857)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      );
    }
  }

  List<Widget> _buildSpaceDecorations() {
    return [
      Positioned(top: 80, left: 40, child: const Text('⭐', style: TextStyle(fontSize: 16))),
      Positioned(top: 150, right: 30, child: const Text('⭐', style: TextStyle(fontSize: 24))),
      Positioned(top: 300, left: 100, child: const Text('🪐', style: TextStyle(fontSize: 48))),
      Positioned(bottom: 120, right: 60, child: const Text('🛸', style: TextStyle(fontSize: 32))),
    ];
  }

  List<Widget> _buildOceanDecorations() {
    return [
      Positioned(top: 100, left: 80, child: const Text('🫧', style: TextStyle(fontSize: 20))),
      Positioned(top: 220, right: 50, child: const Text('🐟', style: TextStyle(fontSize: 32))),
      Positioned(bottom: 180, left: 40, child: const Text('🐠', style: TextStyle(fontSize: 24))),
      Positioned(bottom: 80, right: 100, child: const Text('🫧', style: TextStyle(fontSize: 28))),
    ];
  }

  List<Widget> _buildForestDecorations() {
    return [
      Positioned(top: 120, left: 30, child: const Text('🌲', style: TextStyle(fontSize: 48))),
      Positioned(top: 200, right: 80, child: const Text('🦉', style: TextStyle(fontSize: 32))),
      Positioned(bottom: 150, left: 120, child: const Text('🦊', style: TextStyle(fontSize: 36))),
      Positioned(bottom: 90, right: 30, child: const Text('🌲', style: TextStyle(fontSize: 54))),
    ];
  }

  // Parent Zone Settings Modal
  void _showParentZoneDialog() {
    _parentAccessGranted = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final vibe = AppTheme.vibe;
          return AlertDialog(
            backgroundColor: vibe.cardColor.withValues(alpha: 0.95),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Icon(Icons.lock, color: vibe.primaryColor),
                const SizedBox(width: 8),
                Text('Parent Control Gateway', style: TextStyle(color: vibe.textColor, fontWeight: FontWeight.bold)),
              ],
            ),
            content: _parentAccessGranted
                ? SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Verification Successful. Administrator Panel.', style: TextStyle(color: vibe.textColor, fontSize: 12)),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          value: _chatMonitoring,
                          activeColor: vibe.primaryColor,
                          onChanged: (val) => setDialogState(() => _chatMonitoring = val),
                          title: Text('Chat Monitoring log', style: TextStyle(color: vibe.textColor, fontSize: 13, fontWeight: FontWeight.bold)),
                          subtitle: Text('Tracks kid chats and filters logs.', style: TextStyle(color: vibe.textColor.withValues(alpha: 0.6), fontSize: 10)),
                        ),
                        SwitchListTile(
                          value: _safetyFiltersActive,
                          activeColor: vibe.primaryColor,
                          onChanged: (val) => setDialogState(() => _safetyFiltersActive = val),
                          title: Text('Auto Safety Filters', style: TextStyle(color: vibe.textColor, fontSize: 13, fontWeight: FontWeight.bold)),
                          subtitle: Text('Blocks bad words and links.', style: TextStyle(color: vibe.textColor.withValues(alpha: 0.6), fontSize: 10)),
                        ),
                        const SizedBox(height: 12),
                        // Screen Time slider
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Screen Time Limit: ${_parentScreenTimeHours} hr', style: TextStyle(color: vibe.textColor, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Slider(
                          value: _parentScreenTimeHours,
                          min: 0.5,
                          max: 4.0,
                          divisions: 7,
                          activeColor: vibe.primaryColor,
                          onChanged: (v) {
                            setDialogState(() {
                              _parentScreenTimeHours = v;
                              _secondsRemaining = (v * 3600).toInt();
                              _screenLocked = false;
                            });
                            if (uid != null) {
                              _fs.updateUser(uid!, {'kidsScreenTimeLimitHours': v});
                            }
                          },
                        ),
                        // Bedtime hours input slider
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Bedtime Hours: ${_parentBedtimeHour % 12 == 0 ? 12 : _parentBedtimeHour % 12} ${_parentBedtimeHour >= 12 ? 'PM' : 'AM'}', style: TextStyle(color: vibe.textColor, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Slider(
                          value: _parentBedtimeHour.toDouble(),
                          min: 17, // 5 PM
                          max: 23, // 11 PM
                          divisions: 6,
                          activeColor: vibe.primaryColor,
                          onChanged: (v) {
                            setDialogState(() {
                              _parentBedtimeHour = v.toInt();
                            });
                            if (uid != null) {
                              _fs.updateUser(uid!, {'kidsBedtimeHour': v.toInt()});
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        // Friend Requests Pending List
                        const Divider(),
                        Text('Pending Friend Requests:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: vibe.textColor)),
                        const SizedBox(height: 6),
                        if (_pendingFriends.isEmpty)
                          Text('No pending requests.', style: TextStyle(fontSize: 11, color: vibe.textColor.withValues(alpha: 0.5)))
                        else
                          ..._pendingFriends.map((f) {
                            return ListTile(
                              dense: true,
                              title: Text(f['name']!, style: TextStyle(color: vibe.textColor, fontWeight: FontWeight.bold)),
                              subtitle: Text('MM ID: ${f['mmId']}', style: TextStyle(color: vibe.textColor.withValues(alpha: 0.6))),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.check, color: Colors.green),
                                    onPressed: () {
                                      setDialogState(() {
                                        _pendingFriends.remove(f);
                                      });
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.red),
                                    onPressed: () {
                                      setDialogState(() {
                                        _pendingFriends.remove(f);
                                      });
                                    },
                                  )
                                ],
                              ),
                            );
                          }).toList(),
                      ],
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Enter Parent PIN to verify your identity. (Try 1234 or 5555)', style: TextStyle(color: vibe.textColor, fontSize: 12)),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _pinCtrl,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        style: TextStyle(color: vibe.textColor),
                        decoration: InputDecoration(
                          hintText: 'Enter 4-digit PIN',
                          hintStyle: TextStyle(color: vibe.textColor.withValues(alpha: 0.4)),
                          counterText: '',
                        ),
                      ),
                    ],
                  ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
              if (!_parentAccessGranted)
                TextButton(
                  onPressed: () {
                    _verifyParentPin();
                    if (_parentAccessGranted) {
                      setDialogState(() {});
                    }
                  },
                  child: Text('Verify PIN', style: TextStyle(color: vibe.primaryColor, fontWeight: FontWeight.bold)),
                ),
            ],
          );
        },
      ),
    );
  }
}

// Drawing Canvas data point helper models
class DrawingPoint {
  final Offset offset;
  final Paint paint;

  DrawingPoint({required this.offset, required this.paint});
}

class DrawingPainter extends CustomPainter {
  final List<DrawingPoint?> pointsList;

  DrawingPainter({required this.pointsList});

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < pointsList.length - 1; i++) {
      if (pointsList[i] != null && pointsList[i + 1] != null) {
        canvas.drawLine(
          pointsList[i]!.offset,
          pointsList[i + 1]!.offset,
          pointsList[i]!.paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
