import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mmwelconn/models/user_model.dart';
import 'package:mmwelconn/screens/chats_screen.dart';
import 'package:mmwelconn/screens/contacts_screen.dart';
import 'package:mmwelconn/services/auth_service.dart';
import 'package:mmwelconn/services/firestore_service.dart';
import 'package:mmwelconn/widgets/app_brand.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  int _selectedIndex = 0;

  static final List<Widget> _pages = [
    _HomePage(),
    const ChatsScreen(),
    const ContactsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    // ignore: lines_longer_than_80_chars
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Colors.white.withValues(alpha: 0.78),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedItemColor: AppTheme.violet,
          unselectedItemColor: AppTheme.ink.withValues(alpha: 0.52),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.chat_rounded), label: 'Chats'),
            BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: 'Contacts'),
            BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'Settings'),
          ],
        ),
      ),
    );
  }
}

class _HomePage extends StatefulWidget {
  const _HomePage();

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  final FirestoreService _fs = FirestoreService();
  final AuthService _authService = AuthService();
  UserModel? _userModel;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final uid = _authService.getCurrentUser()?.uid;
    if (uid == null) return;
    final user = await _fs.getUser(uid);
    if (mounted) setState(() => _userModel = user);
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = _authService.getCurrentUser();
    final displayName = _userModel?.name ?? firebaseUser?.email?.split('@').first ?? 'Friend';
    return SoftGlowBackground(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool desktop = constraints.maxWidth > 900;
            return Center(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight - 140),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: desktop ? 56 : 20,
                      vertical: 24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _TopHero(displayName: displayName),
                        const SizedBox(height: 26),
                        _StatsRow(),
                        const SizedBox(height: 26),
                        _QuickActions(authService: _authService),
                        const SizedBox(height: 26),
                        _FuturisticPanel(),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TopHero extends StatelessWidget {
  final String displayName;

  const _TopHero({required this.displayName});

  @override
  Widget build(BuildContext context) {
    return HoverCard(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(34),
          color: Colors.white.withValues(alpha: 0.68),
          border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const BrandLogo(size: 92),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MMWELCONN',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: AppTheme.ink,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'A calm social space for mood, chat, and connection.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppTheme.ink.withValues(alpha: 0.66),
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Welcome back, $displayName',,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.ink,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Everything feels smoother from here. Send a mood, start a conversation, or invite someone new.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.ink.withValues(alpha: 0.68),
                    height: 1.45,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context) {
    final tiles = [
      ('Mood', 'Live', AppTheme.sky, Icons.favorite_rounded),
      ('Chats', '12', AppTheme.violet, Icons.chat_bubble_rounded),
      ('Friends', '84', AppTheme.pink, Icons.people_alt_rounded),
    ];

    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: tiles
          .map(
            (tile) => HoverCard(
              child: Container(
                width: 160,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(tile.$4, color: tile.$3),
                    const SizedBox(height: 18),
                    Text(
                      tile.$1,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.ink.withValues(alpha: 0.62),
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tile.$2,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppTheme.ink,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final AuthService authService;

  const _QuickActions({required this.authService});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Column(
        children: [
          HoverActionButton(
            label: 'Start chat',
            icon: Icons.chat_rounded,
            colors: const [Color(0xFF4E8DFF), Color(0xFF7B61FF)],
            onPressed: () {},
          ),
          const SizedBox(height: 14),
          HoverActionButton(
            label: 'Share mood',
            icon: Icons.favorite_rounded,
            colors: const [Color(0xFFFF6F91), Color(0xFFFF8A65)],
            onPressed: () {},
          ),
          const SizedBox(height: 14),
          HoverActionButton(
            label: 'Logout',
            icon: Icons.logout_rounded,
            colors: const [Color(0xFFE85D75), Color(0xFFFF8A65)],
            onPressed: () async {
              await authService.logout();
            },
            outlined: true,
          ),
        ],
      ),
    );
  }
}

class _FuturisticPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return HoverCard(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFEFF4FF), Color(0xFFF7EDFF), Color(0xFFFFF0F5)],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your next features',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Mood widget, private conversations, live friend updates, and presence tools can live here as the app grows.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.ink.withValues(alpha: 0.68),
                    height: 1.45,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}