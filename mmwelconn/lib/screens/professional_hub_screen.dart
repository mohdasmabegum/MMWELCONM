import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mmwelconm/models/user_model.dart';
import 'package:mmwelconm/services/firestore_service.dart';
import 'package:mmwelconm/widgets/app_brand.dart';

class ProfessionalHubScreen extends StatefulWidget {
  const ProfessionalHubScreen({super.key});

  @override
  State<ProfessionalHubScreen> createState() => _ProfessionalHubScreenState();
}

class _ProfessionalHubScreenState extends State<ProfessionalHubScreen> {
  final FirestoreService _fs = FirestoreService();
  final uid = FirebaseAuth.instance.currentUser?.uid;

  // Tabs: 0 = Admin Panel, 1 = Meetings, 2 = Payments, 3 = Plans
  int _activeTab = 0;

  // Plans
  String _selectedPlan = 'starter'; // starter, classic, growth, business, enterprise, lifetime
  bool _isAnnual = false;

  // Admin Controls
  String _adminId = 'ADMIN_PRO_9021';
  bool _enableMeetings = true;
  bool _enablePayments = true;
  bool _restrictMinorLimits = true;

  // Meetings Schedule list
  final List<Map<String, String>> _meetings = [
    {'title': 'Quarterly Business Review 📊', 'time': '11:00 AM', 'link': 'https://meet.google.com/abc-defg-hij'},
    {'title': 'Sprint Planning Sync 💻', 'time': '03:00 PM', 'link': 'https://zoom.us/j/987654321'},
  ];
  final TextEditingController _meetingTitleCtrl = TextEditingController();
  final TextEditingController _meetingTimeCtrl = TextEditingController();
  final TextEditingController _meetingLinkCtrl = TextEditingController();

  // Payments & Banks Card
  final List<Map<String, String>> _linkedBanks = [
    {'name': 'Chase Professional Platinum', 'account': '**** 8820'},
  ];
  final List<String> _linkedUpis = ['professional@upi'];
  final TextEditingController _bankNameCtrl = TextEditingController();
  final TextEditingController _bankAccCtrl = TextEditingController();
  final TextEditingController _upiIdCtrl = TextEditingController();

  // Send Money form
  final TextEditingController _sendUpiCtrl = TextEditingController();
  final TextEditingController _sendAmtCtrl = TextEditingController();
  double _dailySpentSoFar = 1200.0;
  bool _isTransferring = false;
  double _transferProgress = 0.0;
  bool _transferSuccess = false;

  @override
  void dispose() {
    _meetingTitleCtrl.dispose();
    _meetingTimeCtrl.dispose();
    _meetingLinkCtrl.dispose();
    _bankNameCtrl.dispose();
    _bankAccCtrl.dispose();
    _upiIdCtrl.dispose();
    _sendUpiCtrl.dispose();
    _sendAmtCtrl.dispose();
    super.dispose();
  }

  void _addMeeting() {
    if (_meetingTitleCtrl.text.trim().isEmpty) return;
    setState(() {
      _meetings.add({
        'title': _meetingTitleCtrl.text.trim(),
        'time': _meetingTimeCtrl.text.trim().isEmpty ? '09:00 AM' : _meetingTimeCtrl.text.trim(),
        'link': _meetingLinkCtrl.text.trim().isEmpty ? 'https://meet.google.com' : _meetingLinkCtrl.text.trim(),
      });
      _meetingTitleCtrl.clear();
      _meetingTimeCtrl.clear();
      _meetingLinkCtrl.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Meeting scheduled successfully! 📆')),
    );
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
      const SnackBar(content: Text('Bank Platinum Card Linked! 💳')),
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

    // Daily Limit check: Professional mode is Major account, limit is 100,000 per day.
    const double dailyLimit = 100000.0;
    if (_dailySpentSoFar + amt > dailyLimit) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('⚠️ Daily Limit Exceeded'),
          content: const Text(
            'Transfer failed. Daily Limit is 100,000 for Major Accounts.\nRemaining Limit: 98,800 INR',
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

    // Speed transfer simulation
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
    // Elegant Slate-Navy and Clean White professional theme colors
    const Color primaryBg = Color(0xFF0F172A);
    const Color cardBg = Color(0xFF1E293B);
    const Color accentTeal = Color(0xFF0D9488);

    return Scaffold(
      backgroundColor: primaryBg,
      body: SafeArea(
        child: Column(
          children: [
            // Professional Mode Header
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('👔 PROFESSIONAL MODE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: accentTeal, letterSpacing: 2.0)),
                      SizedBox(height: 4),
                      Text('Enterprise Workspace', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: Text('Admin ID: $_adminId', style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),

            // Tab Buttons
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16)),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTabBtn(0, '🔑 Admin'),
                    _buildTabBtn(1, '📆 Meetings'),
                    _buildTabBtn(2, '💳 Payments'),
                    _buildTabBtn(3, '💎 Plans'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Tabs Content Workspace
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildActiveTabContent(cardBg, accentTeal),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTabBtn(int idx, String label) {
    final active = _activeTab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _activeTab = idx);
          HapticFeedback.lightImpact();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF0D9488).withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: active ? Border.all(color: const Color(0xFF0D9488), width: 1.5) : null,
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

  Widget _buildActiveTabContent(Color cardBg, Color teal) {
    switch (_activeTab) {
      case 0:
        return _buildAdminTab(cardBg, teal);
      case 1:
        return _buildMeetingsTab(cardBg, teal);
      case 2:
        return _buildPaymentsTab(cardBg, teal);
      case 3:
        return _buildPlansTab(cardBg, teal);
      default:
        return const SizedBox();
    }
  }

  // ─── PLANS TAB ────────────────────────────────────────────────────────────
  Widget _buildPlansTab(Color cardBg, Color teal) {
    // Pricing per employee per month (base). Annual = 20% off.
    // Market ref: Slack ₹440/u, Teams ₹500/u, Zoho ₹125/u, Google WS ₹150/u
    // MMWelconm is positioned as feature-rich but affordable for Indian SMEs
    final plans = [
      {
        'id': 'starter',
        'name': 'Starter',
        'emoji': '🚀',
        'tagline': 'Perfect to get started',
        'seats': 'Up to 5 employees',
        'maxSeats': 5,
        'monthlyTotal': 0,
        'perUser': 0,
        'annualSaving': 0,
        'color': const Color(0xFF64748B),
        'highlight': false,
        'ribbon': '',
        'features': [
          '✅ Up to 5 team members',
          '✅ Admin control panel',
          '✅ Meeting scheduler',
          '✅ UPI & bank payments',
          '✅ Chat & mood sharing',
          '❌ Priority support',
          '❌ Analytics dashboard',
          '❌ Custom branding',
        ],
      },
      {
        'id': 'classic',
        'name': 'Classic',
        'emoji': '💼',
        'tagline': 'Best for small teams',
        'seats': 'Up to 30 employees',
        'maxSeats': 30,
        'monthlyTotal': 2670,
        'perUser': 89,
        'annualSaving': 6408,
        'color': const Color(0xFF0D9488),
        'highlight': false,
        'ribbon': '',
        'features': [
          '✅ Up to 30 team members',
          '✅ All Starter features',
          '✅ Priority email support',
          '✅ Team analytics dashboard',
          '✅ File sharing & storage 5GB',
          '✅ Meeting recording links',
          '❌ Custom branding',
          '❌ Dedicated account manager',
        ],
      },
      {
        'id': 'growth',
        'name': 'Growth',
        'emoji': '📈',
        'tagline': 'Scaling your business',
        'seats': '51 – 100 employees',
        'maxSeats': 100,
        'monthlyTotal': 6650,
        'perUser': 79,
        'annualSaving': 15960,
        'color': const Color(0xFF7C3AED),
        'highlight': true,
        'ribbon': '⭐ MOST POPULAR',
        'features': [
          '✅ Up to 100 team members',
          '✅ All Classic features',
          '✅ Custom branding & logo',
          '✅ Advanced analytics & reports',
          '✅ File storage 25GB',
          '✅ Bulk employee onboarding',
          '✅ 24/7 chat support',
          '❌ Dedicated account manager',
        ],
      },
      {
        'id': 'business',
        'name': 'Business',
        'emoji': '🏢',
        'tagline': 'For established companies',
        'seats': '101 – 150 employees',
        'maxSeats': 150,
        'monthlyTotal': 10500,
        'perUser': 70,
        'annualSaving': 25200,
        'color': const Color(0xFFB45309),
        'highlight': false,
        'ribbon': '🔥 BEST VALUE',
        'features': [
          '✅ Up to 150 team members',
          '✅ All Growth features',
          '✅ Dedicated account manager',
          '✅ Role-based access control',
          '✅ File storage 100GB',
          '✅ SSO / SAML integration',
          '✅ SLA guarantee (99.9% uptime)',
          '✅ Monthly business reviews',
        ],
      },
      {
        'id': 'enterprise',
        'name': 'Enterprise',
        'emoji': '🌐',
        'tagline': 'Unlimited scale, full control',
        'seats': '150+ employees',
        'maxSeats': 9999,
        'monthlyTotal': -1, // custom pricing
        'perUser': 59,
        'annualSaving': 0,
        'color': const Color(0xFFDC2626),
        'highlight': false,
        'ribbon': '',
        'features': [
          '✅ Unlimited team members',
          '✅ All Business features',
          '✅ Custom contract & SLA',
          '✅ Unlimited file storage',
          '✅ On-premise deployment option',
          '✅ White-label solution',
          '✅ 24/7 phone & video support',
          '✅ Custom API integrations',
        ],
      },
      {
        'id': 'lifetime',
        'name': 'Lifetime Deal',
        'emoji': '♾️',
        'tagline': 'Pay once. 365 days. 150+ team. Forever yours.',
        'seats': '150+ employees · 365 days',
        'maxSeats': 9999,
        'monthlyTotal': 49999,
        'perUser': 0,
        'annualSaving': 75000,
        'color': const Color(0xFFD97706),
        'highlight': false,
        'ribbon': '⏳ LIMITED TIME',
        'features': [
          '✅ 150+ team members (unlimited)',
          '✅ Full 365-day active plan access',
          '✅ All Business features included',
          '✅ Custom branding & white-label',
          '✅ Unlimited file storage (1TB)',
          '✅ Dedicated account manager',
          '✅ Free updates for lifetime',
          '✅ Priority 24/7 phone support',
          '✅ Founding member status & badge',
          '✅ Beta feature early access',
          '✅ Never pay monthly or annually again',
        ],
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Limited Time Offer Banner ──────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFD97706), Color(0xFFB45309)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Text('🎁', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EARLY BIRD OFFER',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 2),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'First 500 admins get 3 months FREE on any annual plan! Offer ends soon.',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('CLAIM', style: TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.w900, fontSize: 11)),
              )
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Annual / Monthly Toggle ────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isAnnual = false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: !_isAnnual ? teal : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('Monthly', textAlign: TextAlign.center,
                        style: TextStyle(color: !_isAnnual ? Colors.white : Colors.white54, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isAnnual = true),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _isAnnual ? teal : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text('Annual', textAlign: TextAlign.center,
                            style: TextStyle(color: _isAnnual ? Colors.white : Colors.white54, fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('Save 20%', style: TextStyle(color: _isAnnual ? Colors.amberAccent : Colors.white30, fontSize: 9, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Current Plan Indicator ─────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: teal.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: teal.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              Icon(Icons.verified, color: teal, size: 18),
              const SizedBox(width: 8),
              Text(
                'Current Plan: ${plans.firstWhere((p) => p['id'] == _selectedPlan)['name']}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              if (_selectedPlan != 'starter')
                Text(
                  _isAnnual
                      ? '₹${(((plans.firstWhere((p) => p['id'] == _selectedPlan)['monthlyTotal'] as int) * 12 * 0.80)).toInt()} /yr'
                      : '₹${plans.firstWhere((p) => p['id'] == _selectedPlan)['monthlyTotal']} /mo',
                  style: TextStyle(color: teal, fontWeight: FontWeight.w900, fontSize: 13),
                )
              else
                const Text('FREE', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w900, fontSize: 13)),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Plan Cards ────────────────────────────────────────────────
        ...plans.map((plan) {
          final id = plan['id'] as String;
          final isSelected = _selectedPlan == id;
          final highlight = plan['highlight'] as bool;
          final color = plan['color'] as Color;
          final ribbon = plan['ribbon'] as String;
          final monthlyTotal = plan['monthlyTotal'] as int;
          final perUser = plan['perUser'] as int;
          final annualSaving = plan['annualSaving'] as int;
          final features = plan['features'] as List<String>;
          final isCustom = monthlyTotal == -1;
          final isLifetime = id == 'lifetime';

          final displayPrice = isCustom
              ? 'Custom'
              : isLifetime
                  ? '₹${monthlyTotal.toString()}'
                  : monthlyTotal == 0
                      ? 'FREE'
                      : _isAnnual
                          ? '₹${(monthlyTotal * 12 * 0.80).toInt()}'
                          : '₹$monthlyTotal';

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isSelected ? color.withOpacity(0.18) : cardBg,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected ? color : (highlight ? color.withOpacity(0.5) : Colors.white12),
                width: isSelected ? 2 : (highlight ? 1.5 : 1),
              ),
              boxShadow: isSelected
                  ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 20, spreadRadius: 2)]
                  : [],
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Plan header
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(child: Text(plan['emoji'] as String, style: const TextStyle(fontSize: 22))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(plan['name'] as String,
                                    style: TextStyle(color: isSelected ? color : Colors.white, fontWeight: FontWeight.w900, fontSize: 17)),
                                Text(plan['tagline'] as String,
                                    style: const TextStyle(color: Colors.white54, fontSize: 11)),
                              ],
                            ),
                          ),
                          // Price
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(displayPrice,
                                  style: TextStyle(
                                      color: monthlyTotal == 0 ? Colors.greenAccent : (isLifetime ? const Color(0xFFD97706) : color),
                                      fontWeight: FontWeight.w900,
                                      fontSize: 20)),
                              if (!isCustom && !isLifetime && monthlyTotal > 0)
                                Text(
                                  _isAnnual ? '/year' : '/month',
                                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                                ),
                              if (isLifetime)
                                const Text('one-time', style: TextStyle(color: Colors.white38, fontSize: 10)),
                              if (isCustom)
                                const Text('contact us', style: TextStyle(color: Colors.white38, fontSize: 10)),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Per user and seats info
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              plan['seats'] as String,
                              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (perUser > 0 && !isLifetime)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '₹$perUser/user/mo',
                                style: const TextStyle(color: Colors.white54, fontSize: 11),
                              ),
                            ),
                          if (_isAnnual && annualSaving > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.greenAccent.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Save ₹$annualSaving/yr',
                                style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 14),
                      const Divider(color: Colors.white12),
                      const SizedBox(height: 8),

                      // Features list
                      ...features.map((f) => Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Text(f,
                                style: TextStyle(
                                    color: f.startsWith('✅') ? Colors.white70 : Colors.white30,
                                    fontSize: 12)),
                          )),

                      const SizedBox(height: 16),

                      // Action button
                      GestureDetector(
                        onTap: () {
                          if (isCustom) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('📧 Contact us at enterprise@mmwelconm.app for custom pricing')),
                            );
                            return;
                          }
                          HapticFeedback.mediumImpact();
                          setState(() => _selectedPlan = id);
                          if (id != 'starter') {
                            _showPlanUpgradeDialog(plan['name'] as String, displayPrice, isLifetime);
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            gradient: isSelected
                                ? LinearGradient(colors: [color, color.withOpacity(0.7)])
                                : null,
                            color: isSelected ? null : color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: !isSelected ? Border.all(color: color.withOpacity(0.5)) : null,
                          ),
                          child: Text(
                            isSelected
                                ? '✅ Current Plan'
                                : isCustom
                                    ? 'Contact Sales'
                                    : monthlyTotal == 0
                                        ? 'Get Started Free'
                                        : isLifetime
                                            ? '♾️ Get Lifetime Deal'
                                            : 'Upgrade to ${plan['name']}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isSelected ? Colors.white : color,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Ribbon badge
                if (ribbon.isNotEmpty)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: highlight ? const Color(0xFF7C3AED) : const Color(0xFFD97706),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(24),
                          bottomLeft: Radius.circular(14),
                        ),
                      ),
                      child: Text(ribbon, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                    ),
                  ),
              ],
            ),
          );
        }),

        const SizedBox(height: 8),

        // ── Market Comparison Note ────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('📊 How We Compare', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 12),
              _compRow('Platform', 'Per User/Mo', 'Supports', true),
              _compRow('Slack Pro', '₹440', '∞ users', false),
              _compRow('MS Teams', '₹500', '∞ users', false),
              _compRow('Google WS', '₹150', '∞ users', false),
              _compRow('Zoho', '₹125', '∞ users', false),
              _compRow('MMWelconm ⭐', '₹59–₹89', '5–∞ users', false, highlight: true),
              const SizedBox(height: 10),
              const Text(
                '💡 MMWelconm combines social communication, mood tracking, health tools, payments & professional admin \u2014 features you\'d pay for separately elsewhere.',
                style: TextStyle(color: Colors.white38, fontSize: 10, height: 1.5),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Money-back guarantee badge ─────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.greenAccent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.greenAccent.withOpacity(0.25)),
          ),
          child: const Row(
            children: [
              Text('🛡️', style: TextStyle(fontSize: 28)),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('30-Day Money-Back Guarantee', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                    SizedBox(height: 2),
                    Text('Not satisfied? Get a full refund within 30 days. No questions asked.', style: TextStyle(color: Colors.white38, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _compRow(String name, String price, String seats, bool isHeader, {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFF0D9488).withOpacity(0.12) : Colors.transparent,
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
              flex: 3,
              child: Text(name,
                  style: TextStyle(
                      color: isHeader ? Colors.white54 : (highlight ? const Color(0xFF0D9488) : Colors.white70),
                      fontSize: isHeader ? 10 : 12,
                      fontWeight: highlight || isHeader ? FontWeight.bold : FontWeight.normal))),
          Expanded(
              flex: 2,
              child: Text(price,
                  style: TextStyle(
                      color: isHeader ? Colors.white54 : (highlight ? Colors.greenAccent : Colors.white54),
                      fontSize: isHeader ? 10 : 12,
                      fontWeight: highlight ? FontWeight.bold : FontWeight.normal))),
          Expanded(
              flex: 2,
              child: Text(seats,
                  style: TextStyle(
                      color: isHeader ? Colors.white54 : Colors.white38,
                      fontSize: isHeader ? 10 : 11))),
        ],
      ),
    );
  }

  void _showPlanUpgradeDialog(String planName, String price, bool isLifetime) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(isLifetime ? '♾️' : '🎉', style: const TextStyle(fontSize: 48)),
              const SizedBox(height: 12),
              Text(
                isLifetime ? '365-Day Lifetime Deal!' : 'Upgrade to $planName',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20),
              ),
              const SizedBox(height: 8),
              Text(
                isLifetime
                    ? 'One payment of $price. 150+ employees. 365 days of full access. No renewals. Ever.'
                    : 'Confirm upgrade for $price. Your admin features unlock immediately.',
                style: const TextStyle(color: Colors.white60, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (isLifetime)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD97706).withOpacity(0.4)),
                  ),
                  child: const Column(
                    children: [
                      Text(
                        '⏳ Only 23 Lifetime slots remaining!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFFD97706), fontSize: 13, fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '✅ 150+ employees  ·  ✅ 365 days access\n✅ 1TB storage  ·  ✅ Lifetime updates\n✅ No monthly fees. Ever.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.6),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✅ $planName plan activated! Payment gateway integration coming soon.'),
                            backgroundColor: const Color(0xFF0D9488),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D9488),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Proceed to Pay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 1. Admin Control Panel Tab
  Widget _buildAdminTab(Color cardBg, Color teal) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('🔑 Administrator Controls', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              const Text('Configure privileges and feature flags across user accounts.', style: TextStyle(color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 16),
              SwitchListTile(
                value: _enableMeetings,
                activeColor: teal,
                title: const Text('Enable Meeting Scheduler', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text('Allows adding corporate calendar meetings.', style: TextStyle(color: Colors.white30, fontSize: 10)),
                onChanged: (v) => setState(() => _enableMeetings = v),
              ),
              SwitchListTile(
                value: _enablePayments,
                activeColor: teal,
                title: const Text('Enable UPI & Cards Payments', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text('Provides transfers dashboard access.', style: TextStyle(color: Colors.white30, fontSize: 10)),
                onChanged: (v) => setState(() => _enablePayments = v),
              ),
              SwitchListTile(
                value: _restrictMinorLimits,
                activeColor: teal,
                title: const Text('Strict Limit Enforcement', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                subtitle: const Text('Restricts minor daily spend to 5k.', style: TextStyle(color: Colors.white30, fontSize: 10)),
                onChanged: (v) => setState(() => _restrictMinorLimits = v),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 2. Meetings Scheduler Tab
  Widget _buildMeetingsTab(Color cardBg, Color teal) {
    if (!_enableMeetings) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('Meetings access disabled by Administrator.', style: TextStyle(color: Colors.white54, fontSize: 14)),
        ),
      );
    }

    return Column(
      children: [
        // Scheduled meetings list
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('📆 Scheduled Corporate Meetings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ..._meetings.map((m) {
                return Card(
                  color: Colors.white.withValues(alpha: 0.05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    dense: true,
                    title: Text(m['title']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text('Time: ${m['time']}\nLink: ${m['link']}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    trailing: IconButton(
                      icon: const Icon(Icons.open_in_new, color: Colors.blueAccent, size: 18),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Opening Link: ${m['link']}')),
                        );
                      },
                    ),
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Add meeting form
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('➕ Schedule New Meeting', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: _meetingTitleCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Meeting Title', labelStyle: TextStyle(color: Colors.white60)),
              ),
              TextField(
                controller: _meetingTimeCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Time (e.g. 10:00 AM)', labelStyle: TextStyle(color: Colors.white60)),
              ),
              TextField(
                controller: _meetingLinkCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Meeting URL Link', labelStyle: TextStyle(color: Colors.white60)),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _addMeeting,
                style: ElevatedButton.styleFrom(backgroundColor: teal),
                child: const Text('Add Meeting', style: TextStyle(color: Colors.white)),
              )
            ],
          ),
        ),
      ],
    );
  }

  // 3. Payments Section Tab
  Widget _buildPaymentsTab(Color cardBg, Color teal) {
    if (!_enablePayments) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('Payments logs disabled by Administrator.', style: TextStyle(color: Colors.white54, fontSize: 14)),
        ),
      );
    }

    return Column(
      children: [
        // Daily limit indicator
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('💵 Daily Spend Limits Indicator', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('Major Account Limit: 100,000 INR per day', style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
              const Text('Minor Account Limit: 5,000 INR per day', style: TextStyle(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold)),
              const Divider(color: Colors.white12),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: _dailySpentSoFar / 100000.0,
                backgroundColor: Colors.white12,
                color: Colors.greenAccent,
                minHeight: 8,
              ),
              const SizedBox(height: 6),
              Text('Spent Today: ${_dailySpentSoFar.toInt()} / 100,000 INR', style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Cards & UPI Linking
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('💳 Linked Bank Cards', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ..._linkedBanks.map((b) => ListTile(
                    dense: true,
                    title: Text(b['name']!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    subtitle: Text(b['account']!, style: const TextStyle(color: Colors.white60)),
                  )),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _bankNameCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: const InputDecoration(hintText: 'Card Name...'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _bankAccCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      decoration: const InputDecoration(hintText: 'Last 4 digits...'),
                    ),
                  ),
                  IconButton(onPressed: _linkBank, icon: const Icon(Icons.add, color: Colors.greenAccent)),
                ],
              ),
              const Divider(color: Colors.white12),
              const Text('📱 Linked UPI IDs', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ..._linkedUpis.map((u) => Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: Text(u, style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  )),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _upiIdCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 12),
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

        // Send Money Form with speed loader simulation
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('💸 Send Money Transfer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: _sendUpiCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Recipient UPI ID', labelStyle: TextStyle(color: Colors.white60)),
              ),
              TextField(
                controller: _sendAmtCtrl,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (INR)', labelStyle: TextStyle(color: Colors.white60)),
              ),
              const SizedBox(height: 16),
              if (_isTransferring) ...[
                const Text('Executing Speed Transfer... ⚡', style: TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: _transferProgress, color: teal),
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
                  style: ElevatedButton.styleFrom(backgroundColor: teal),
                  child: const Text('Send Money', style: TextStyle(color: Colors.white)),
                )
              ]
            ],
          ),
        ),

        const SizedBox(height: 16),

        // QR scanner simulation
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(24)),
          child: Column(
            children: [
              const Text('🔳 QR Code Scanner & Generator', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Scan QR Code'),
                          content: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.qr_code_scanner, size: 80, color: Colors.blue),
                              SizedBox(height: 8),
                              Text('Simulating camera scan of merchant QR...'),
                            ],
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan QR'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Your UPI QR Code'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.qr_code, size: 100),
                              const SizedBox(height: 8),
                              Text('UPI ID: ${_linkedUpis.first}'),
                            ],
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.qr_code),
                    label: const Text('Show QR'),
                  ),
                ],
              )
            ],
          ),
        ),
      ],
    );
  }
}
