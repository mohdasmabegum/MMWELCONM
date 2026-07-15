import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:mmwelconn/models/user_model.dart';
import 'package:mmwelconn/services/firestore_service.dart';
import 'package:mmwelconn/services/notification_service.dart';

String _generateMmId() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final rand = Random();
  return 'MM${List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join()}';
}

class AuthService {
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
  Future<User?> signUp(String email, String password, String name) async {
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
      ));
      await _auth.signOut();
      // Trigger welcome notification after successful registration
      NotificationService().show(InAppNotification(
        title: 'Welcome to MMWELCONN! 🎉',
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
