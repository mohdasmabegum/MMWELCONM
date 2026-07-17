import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mmwelconm/firebase_options.dart';
import 'package:mmwelconm/screens/auth_landing_screen.dart';
import 'package:mmwelconm/screens/home_screen.dart';
import 'package:mmwelconm/screens/login_screen.dart';
import 'package:mmwelconm/screens/register_screen.dart';
import 'package:mmwelconm/screens/splash_screen.dart';
import 'package:mmwelconm/services/notification_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  await NotificationService().init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'mmwelconm',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C63FF)),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      builder: (context, child) => NotificationOverlay(child: child!),
      routes: {
        '/': (_) => const SplashFlow(),
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
      },
      home: const SplashFlow(),
    );
  }
}

class SplashFlow extends StatefulWidget {
  const SplashFlow({super.key});

  @override
  State<SplashFlow> createState() => _SplashFlowState();
}

class _SplashFlowState extends State<SplashFlow> {
  bool _showLanding = false;

  @override
  Widget build(BuildContext context) {
    if (_showLanding) {
      return const AuthGate();
    }

    return SplashScreen(
      onComplete: () {
        if (mounted) {
          setState(() {
            _showLanding = true;
          });
        }
      },
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoggedIn = false;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (!mounted) return;
      final loggedIn = user != null;
      if (loggedIn && !_isLoggedIn) {
        // Delay navigation so any popup on the stack can finish first
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            setState(() {
              _isLoggedIn = true;
              _ready = true;
            });
          }
        });
      } else if (!loggedIn && _isLoggedIn) {
        setState(() {
          _isLoggedIn = false;
          _ready = true;
        });
      } else if (!_ready) {
        setState(() {
          _isLoggedIn = loggedIn;
          _ready = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    if (_isLoggedIn) {
      return const HomeScreen();
    }

    return AuthLandingScreen(
      onLoginTap: () => Navigator.of(context).pushNamed('/login'),
      onRegisterTap: () => Navigator.of(context).pushNamed('/register'),
    );
  }
}
