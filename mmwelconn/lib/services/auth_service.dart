import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:mmwelconm/models/user_model.dart';
import 'package:mmwelconm/services/firestore_service.dart';
import 'package:mmwelconm/services/notification_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _generateMmId() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final rand = Random();
  return 'MM${List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join()}';
}

class AuthService {
  // Secure storage for Remember Me
  static const _storage = FlutterSecureStorage();
  static const _emailKey = 'email';
  static const _passwordKey = 'password';

  /// Save credentials when Remember Me is enabled.
  static Future<void> saveCredentials({required String email, required String password}) async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_emailKey, email);
        await prefs.setString(_passwordKey, password);
      } else {
        await _storage.write(key: _emailKey, value: email);
        await _storage.write(key: _passwordKey, value: password);
      }
    } catch (_) {}
  }

  /// Clear stored credentials.
  static Future<void> clearCredentials() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_emailKey);
        await prefs.remove(_passwordKey);
      } else {
        await _storage.delete(key: _emailKey);
        await _storage.delete(key: _passwordKey);
      }
    } catch (_) {}
  }

  /// Retrieve stored credentials, returns null if not present.
  static Future<Map<String, String>?> getStoredCredentials() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final email = prefs.getString(_emailKey);
        final password = prefs.getString(_passwordKey);
        if (email != null && password != null) {
          return {'email': email, 'password': password};
        }
      } else {
        final email = await _storage.read(key: _emailKey);
        final password = await _storage.read(key: _passwordKey);
        if (email != null && password != null) {
          return {'email': email, 'password': password};
        }
      }
    } catch (_) {}
    return null;
  }
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<String> _generateUniqueMmId() async {
    while (true) {
      final id = _generateMmId();
      final snap = await _db
          .collection('users')
          .where('mmId', isEqualTo: id)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return id;
    }
  }

  // Sign up — creates Firestore doc while still authenticated, then signs out
  // so AuthGate does not redirect to HomeScreen before the dialog is dismissed.
  Future<User?> signUp(String email, String password, String name, {String ageGroup = 'teen'}) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = result.user;
    if (user != null) {
      final mmId = await _generateUniqueMmId();
      await _firestoreService.createUser(UserModel(
        uid: user.uid,
        mmId: mmId,
        name: name,
        email: email,
        createdAt: DateTime.now(),
        lastActive: DateTime.now(),
        ageGroup: ageGroup,
      ));
      await _auth.signOut();
      // Trigger welcome notification after successful registration
      NotificationService().show(InAppNotification(
        title: 'Welcome to mmwelconm! 🎉',
        body: 'Your account is ready. Start connecting with people!',
        type: NotifType.welcome,
      ));
    }
    return user;
  }

  Future<User?> login(String email, String password) async {
    if (kIsWeb) await _auth.setPersistence(Persistence.LOCAL);
    final result = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = result.user;
    if (user != null) {
      try {
        final profile = await _firestoreService.getUser(user.uid);
        final showOnline = profile?.showOnline ?? true;
        await _firestoreService.setUserStatus(user.uid, showOnline ? 'online' : 'offline');
      } catch (_) {}
    }
    return user;
  }

  // Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Logout
  Future<void> logout() async {
    final uid = _auth.currentUser?.uid;
    if (uid != null) {
      try {
        await _firestoreService.updateUser(uid, {'fcmToken': FieldValue.delete()});
        await _firestoreService.setUserStatus(uid, 'offline');
      } catch (_) {}
    }
    await _auth.signOut();
  }

  // Check if user is logged in
  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }
}
