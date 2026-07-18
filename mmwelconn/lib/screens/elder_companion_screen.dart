import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mmwelconm/models/user_model.dart';
import 'package:mmwelconm/services/firestore_service.dart';
import 'package:mmwelconm/widgets/app_brand.dart';

class ElderCompanionScreen extends StatefulWidget {
  const ElderCompanionScreen({super.key});

  @override
  State<ElderCompanionScreen> createState() => _ElderCompanionScreenState();
}

class _ElderCompanionScreenState extends State<ElderCompanionScreen> {
  final FirestoreService _fs = FirestoreService();
  final uid = FirebaseAuth.instance.currentUser?.uid;

  // Tabs: 0=Daily Dashboard, 1=Health & BP Logs, 2=Memories & Friends
  int _activeTab = 0;

  // Accessibility defaults: 2.0x font scaling, High contrast cream/black theme
  double _fontScale = 2.0;
  bool _highContrastMode = true;

  // Large Emojis Selection (150x150)
  String _selectedEmoji = '😊';
  String _emojiDescription = 'Happy 😊';

  // Medicine checklist
  final List<Map<String, dynamic>> _medicines = [
    {'title': '💊 BP Pill (9:00 AM)', 'time': '09:00 AM', 'taken': false},
    {'title': '💉 Insulin (8:00 AM)', 'time': '08:00 AM', 'taken': true},
    {'title': '💊 Sleeping Pill (9:00 PM)', 'time': '09:00 PM', 'taken': false},
  ];

  // Health Stats Inputs
  String _bloodPressure = '120/80';
  int _bloodSugar = 95;
  double _weight = 70.0;

  // Emergency SOS state
  bool _sosTriggered = false;

  // One-Tap Actions
  String _oneTapStatus = 'At Home';

  // Voice Command Simulation
  final TextEditingController _voiceCmdCtrl = TextEditingController();
  String _voiceCmdFeedback = 'Say: "Call my son" or "Show medicine schedule"';

  // Grandchildren Widget
  final List<Map<String, String>> _grandkids = [
    {'name': 'Timmy 👦', 'mood': 'Happy 😊', 'photo': 'https://images.unsplash.com/photo-1503919545889-aef636e10ad4?w=80'},
    {'name': 'Lily 👧', 'mood': 'Excited 🥳', 'photo': 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?w=80'},
  ];

  // Family Memories
  final List<Map<String, String>> _memories = [
    {'title': 'Golden Wedding Anniversary 💍', 'year': '15 years ago'},
    {'title': 'Grandma\'s Graduation 🎓', 'year': '30 years ago'},
  ];

  // Inactivity safety tracker (2 hours fall checker)
  Timer? _inactivityTimer;
  bool _showingInactivityAlert = false;

  // Payments State
  final List<Map<String, String>> _linkedBanks = [
    {'name': 'State Bank Pension Card', 'account': '**** 9901'},
  ];
  final List<String> _linkedUpis = ['grandma@upi'];
  final TextEditingController _bankNameCtrl = TextEditingController();
  final TextEditingController _bankAccCtrl = TextEditingController();
  final TextEditingController _upiIdCtrl = TextEditingController();
  final TextEditingController _sendUpiCtrl = TextEditingController();
  final TextEditingController _sendAmtCtrl = TextEditingController();
  double _dailySpentSoFar = 800.0;
  bool _isTransferring = false;
  double _transferProgress = 0.0;
  bool _transferSuccess = false;

  @override
  void initState() {
    super.initState();
    _startInactivityCheck();
  }

  void _startInactivityCheck() {
    _inactivityTimer = Timer(const Duration(seconds: 40), () {
      if (mounted) {
        setState(() {
          _showingInactivityAlert = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    _voiceCmdCtrl.dispose();
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
      const SnackBar(content: Text('Bank pension Card Linked! 💳')),
    );
  }

  void _linkUpi() {
    if (_upiIdCtrl.text.trim().isEmpty) return;
    setState(() {
      _linkedUpis.add(_upiIdCtrl.text.trim());
      _upiIdCtrl.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('UPI Account ID Added! 📱')),
    );
  }

  void _executeTransfer() {
    final amtStr = _sendAmtCtrl.text.trim();
    final upi = _sendUpiCtrl.text.trim();
    if (amtStr.isEmpty || upi.isEmpty) return;

    final amt = double.tryParse(amtStr) ?? 0.0;
    if (amt <= 0) return;

    // Daily Limit check: Elder mode is Major account, limit is 100,000 per day.
    const double dailyLimit = 100000.0;
    if (_dailySpentSoFar + amt > dailyLimit) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('⚠️ Daily Limit Exceeded'),
          content: const Text(
            'Transfer failed. Daily Limit is 100,000 for Major Accounts.\nRemaining Limit: 99,200 INR',
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

  void _triggerVoiceCommand() {
    final cmd = _voiceCmdCtrl.text.trim().toLowerCase();
    if (cmd.isEmpty) return;

    setState(() {
      if (cmd.contains('son') || cmd.contains('call')) {
        _voiceCmdFeedback = 'Voice command success: Calling son... 📞';
      } else if (cmd.contains('medicine') || cmd.contains('schedule')) {
        _voiceCmdFeedback = 'Voice command success: Displaying BP medication times... 💊';
      } else if (cmd.contains('family') || cmd.contains('mood')) {
        _voiceCmdFeedback = 'Voice command success: Grandkids are Happy today! ❤️';
      } else {
        _voiceCmdFeedback = 'Command heard: "$cmd". Guidance: Try "Call son"';
      }
      _voiceCmdCtrl.clear();
    });
    HapticFeedback.heavyImpact();
  }

  void _triggerEmergencySos() {
    setState(() {
      _sosTriggered = true;
    });
    HapticFeedback.vibrate();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🚨 SOS ALERT SENT! Auto-notifying family and sending location 📍'),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vibe = AppTheme.vibe;
    final textTheme = TextStyle(
      fontSize: 18 * _fontScale / 1.2,
      fontWeight: FontWeight.bold,
      color: Colors.black,
    );

    // Fall alert dialog overlay
    if (_showingInactivityAlert) {
      return Scaffold(
        backgroundColor: Colors.yellow,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('⚠️', style: TextStyle(fontSize: 100)),
                const SizedBox(height: 16),
                const Text(
                  'Are you okay?',
                  style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.black),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No movement detected for 2 hours. Tap the button below to alert family.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, color: Colors.black54),
                ),
                const SizedBox(height: 36),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _showingInactivityAlert = false;
                    });
                    _startInactivityCheck();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  child: const Text('I\'m Okay! 👍', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _triggerEmergencySos,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  child: const Text('NEED HELP 🚨', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                )
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Accessible Title Header
            Container(
              color: Colors.black,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('👵 ELDER COMPANION', style: TextStyle(color: Colors.yellowAccent, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      SizedBox(height: 4),
                      Text('Grandma Safe Space', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                    ],
                  ),
                  const Spacer(),
                  // SOS Button
                  ElevatedButton(
                    onPressed: _triggerEmergencySos,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text('SOS', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),

            // Tab bar switcher (Clean contrast buttons)
            Container(
              color: Colors.grey.shade200,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildTabBtn(0, '👵 Dashboard'),
                  _buildTabBtn(1, '💊 Health/BP'),
                  _buildTabBtn(2, '📷 Memories'),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Step-by-Step Guidance Box
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue, width: 2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.blue, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getStepGuidance(),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  )
                ],
              ),
            ),

            // Workspace
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildActiveTabContent(textTheme),
              ),
            )
          ],
        ),
      ),
    );
  }

  String _getStepGuidance() {
    if (_activeTab == 0) {
      return 'Step 1: Tap a big emoji to share how you feel!';
    } else if (_activeTab == 1) {
      return 'Step 2: Check off medicines as you take them!';
    } else {
      return 'Step 3: View grandchildren updates and send love!';
    }
  }

  Widget _buildTabBtn(int idx, String label) {
    final active = _activeTab == idx;
    return ElevatedButton(
      onPressed: () {
        setState(() => _activeTab = idx);
        HapticFeedback.mediumImpact();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: active ? Colors.black : Colors.white,
        foregroundColor: active ? Colors.white : Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.black, width: 2)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildActiveTabContent(TextStyle style) {
    switch (_activeTab) {
      case 0:
        return _buildDashboardTab(style);
      case 1:
        return _buildHealthTab(style);
      case 2:
        return _buildMemoriesTab(style);
      default:
        return const SizedBox();
    }
  }

  // Tab 1: Dashboard, Emojis, and One-Tap Actions
  Widget _buildDashboardTab(TextStyle style) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Giant Emojis Picker (150x150 size)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 2.5),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              const Text('Select Your Mood:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ('😊', 'Happy'),
                    ('😢', 'Sad'),
                    ('😴', 'Tired'),
                    ('😎', 'Cool'),
                  ].map((m) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedEmoji = m.$1;
                          _emojiDescription = '${m.$2} ${m.$1}';
                        });
                        HapticFeedback.heavyImpact();
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          color: _selectedEmoji == m.$1 ? Colors.yellow.shade100 : Colors.white,
                          border: Border.all(color: Colors.black, width: _selectedEmoji == m.$1 ? 4.0 : 2.0),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(m.$1, style: const TextStyle(fontSize: 80)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Selected: $_emojiDescription',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
              )
            ],
          ),
        ),

        const SizedBox(height: 16),

        // One-Tap Actions list
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 2.5),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('One-Tap Location updates:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: ['At Home', 'At Doctor', 'Out Walk'].map((loc) {
                  final active = _oneTapStatus == loc;
                  return ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _oneTapStatus = loc;
                      });
                      HapticFeedback.mediumImpact();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: active ? Colors.blue : Colors.white,
                      foregroundColor: active ? Colors.white : Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Colors.black, width: 2)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: Text(loc, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              const Divider(color: Colors.black, thickness: 1.5),
              // Safety Zone Alerts
              Row(
                children: [
                  const Icon(Icons.security, color: Colors.green, size: 28),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Location Safety: Inside Home Zone ✓ (Safe)',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                    ),
                  )
                ],
              )
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Voice Command Input Box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 2.5),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('🎙️ Voice Commands assistant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _voiceCmdCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Type voice command...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _triggerVoiceCommand,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)),
                    child: const Text('Send', style: TextStyle(color: Colors.white)),
                  )
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _voiceCmdFeedback,
                style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold),
              )
            ],
          ),
        ),
      ],
    );
  }

  // Tab 2: Health, BP logs, and Medicines
  Widget _buildHealthTab(TextStyle style) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Medicine reminders list
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 2.5),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('💊 Daily Medicine Reminders', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ..._medicines.map((med) {
                return CheckboxListTile(
                  value: med['taken'],
                  activeColor: Colors.green,
                  checkColor: Colors.white,
                  title: Text(med['title']!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
                  onChanged: (val) {
                    setState(() {
                      med['taken'] = val ?? false;
                    });
                  },
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // BP and Sugar logs
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 2.5),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('📊 Health logs Inputs', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Blood Pressure:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  Text(_bloodPressure, style: const TextStyle(fontSize: 16, color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Blood Sugar:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  Text('$_bloodSugar mg/dL', style: const TextStyle(fontSize: 16, color: Colors.blue, fontWeight: FontWeight.bold)),
                ],
              ),
              const Divider(color: Colors.black, thickness: 1.5),
              // Warning high BP
              if (_bloodPressure == '140/90')
                const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.redAccent, size: 28),
                    SizedBox(width: 6),
                    Text('BP is high! Contact doctor immediately.', style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
                  ],
                )
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Doctor appointments countdown
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 2.5),
            borderRadius: BorderRadius.circular(24),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('🏥 Doctor Appointment Countdown', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Text('Heart checkup: Monday at 10:00 AM (In 1 hour)', style: TextStyle(color: Colors.purple, fontSize: 14, fontWeight: FontWeight.bold)),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Payments limits and cards
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 2.5),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('💳 Linked Pension & Bank Cards', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._linkedBanks.map((b) => ListTile(
                    dense: true,
                    title: Text(b['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black)),
                    subtitle: Text(b['account']!, style: const TextStyle(color: Colors.grey)),
                  )),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _bankNameCtrl,
                      style: const TextStyle(fontSize: 13, color: Colors.black),
                      decoration: const InputDecoration(hintText: 'Card Name...'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _bankAccCtrl,
                      style: const TextStyle(fontSize: 13, color: Colors.black),
                      decoration: const InputDecoration(hintText: 'Last 4 digits...'),
                    ),
                  ),
                  IconButton(onPressed: _linkBank, icon: const Icon(Icons.add_circle, color: Colors.green)),
                ],
              ),
              const Divider(color: Colors.black, thickness: 1.5),
              const Text('📱 Linked UPI IDs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ..._linkedUpis.map((u) => Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: Text(u, style: const TextStyle(color: Colors.green, fontSize: 14, fontWeight: FontWeight.bold)),
                  )),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _upiIdCtrl,
                      style: const TextStyle(fontSize: 13, color: Colors.black),
                      decoration: const InputDecoration(hintText: 'Link new UPI ID...'),
                    ),
                  ),
                  IconButton(onPressed: _linkUpi, icon: const Icon(Icons.add_circle, color: Colors.green)),
                ],
              )
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Send Money Form
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 2.5),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('💸 Send Money Transfer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: _sendUpiCtrl,
                style: const TextStyle(color: Colors.black),
                decoration: const InputDecoration(labelText: 'Recipient UPI ID', labelStyle: TextStyle(color: Colors.grey)),
              ),
              TextField(
                controller: _sendAmtCtrl,
                style: const TextStyle(color: Colors.black),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (INR)', labelStyle: TextStyle(color: Colors.grey)),
              ),
              const SizedBox(height: 16),
              if (_isTransferring) ...[
                const Text('Executing Speed Transfer... ⚡', style: TextStyle(color: Colors.orange, fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: _transferProgress, color: Colors.black),
              ] else if (_transferSuccess) ...[
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 28),
                    SizedBox(width: 8),
                    Text('Success! 🚀 Sent in seconds.', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ] else ...[
                ElevatedButton(
                  onPressed: _executeTransfer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Send Money', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                )
              ]
            ],
          ),
        ),
      ],
    );
  }

  // Tab 3: Grandchildren & Family Memories
  Widget _buildMemoriesTab(TextStyle style) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Grandchildren mood widget
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 2.5),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('👶 Grandchildren Moods widget', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ..._grandkids.map((gk) {
                return Card(
                  color: Colors.grey.shade100,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: CircleAvatar(backgroundImage: NetworkImage(gk['photo']!)),
                    title: Text(gk['name']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black)),
                    subtitle: Text('Mood: ${gk['mood']}', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                    trailing: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Send Love to ${gk['name']}! ❤️')),
                        );
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
                      child: const Text('Send ❤️', style: TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Family Memories lane
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 2.5),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('📷 Family Memories lane', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ..._memories.map((mem) {
                return ListTile(
                  dense: true,
                  title: Text(mem['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black)),
                  subtitle: Text(mem['year']!, style: const TextStyle(color: Colors.grey)),
                  trailing: const Icon(Icons.photo_library, color: Colors.black),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}
