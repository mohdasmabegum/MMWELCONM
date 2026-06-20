import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mmwelconn/firebase_options.dart';
import 'package:mmwelconn/services/auth_service.dart';
import 'package:mmwelconn/screens/auth_landing_screen.dart';
import 'package:mmwelconn/screens/home_screen.dart';
import 'package:mmwelconn/screens/login_screen.dart';
import 'package:mmwelconn/screens/register_screen.dart';
import 'package:mmwelconn/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
      routes: {
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

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  static bool suppressAuthRedirect = false;

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();

    return StreamBuilder(
      stream: authService.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          );
        }

        if (snapshot.hasData && !suppressAuthRedirect) {
          return const HomeScreen();
        }

        return AuthLandingScreen(
          onLoginTap: () => Navigator.of(context).pushNamed('/login'),
          onRegisterTap: () => Navigator.of(context).pushNamed('/register'),
        );
      },
    );
  }
}
