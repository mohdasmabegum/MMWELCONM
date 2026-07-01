import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mmwelconn/firebase_options.dart';
import 'package:mmwelconn/screens/auth_landing_screen.dart';
import 'package:mmwelconn/screens/home_screen.dart';
import 'package:mmwelconn/screens/login_screen.dart';
import 'package:mmwelconn/screens/register_screen.dart';
import 'package:mmwelconn/screens/splash_screen.dart';
import 'package:mmwelconn/services/notification_service.dart';
import 'package:mmwelconn/widgets/app_brand.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MMWELCONN',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C63FF)),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const NotificationOverlay(child: SplashFlow()),
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

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          );
        }
        if (snap.data != null) return const HomeScreen();
        // Pop all pushed routes (Login/Register) so we land cleanly on AuthLandingScreen
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final nav = Navigator.of(context);
          if (nav.canPop()) nav.popUntil((route) => route.isFirst);
        });
        return AuthLandingScreen(
          onLoginTap: () => Navigator.of(context).push(
            buildPageRoute(const LoginScreen()),
          ),
          onRegisterTap: () => Navigator.of(context).push(
            buildPageRoute(const RegisterScreen()),
          ),
        );
      },
    );
  }
}
