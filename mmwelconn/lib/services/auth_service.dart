import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mmwelconn/models/user_model.dart';
import 'package:mmwelconn/services/firestore_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestoreService = FirestoreService();

  // Sign up with email and password
  Future<User?> signUp(String email, String password, String name) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        await _firestoreService.createUser(UserModel(
          uid: user.uid,
          name: name,
          email: email,
          createdAt: DateTime.now(),
          lastActive: DateTime.now(),
        ));
      }

      return user;
    } on FirebaseAuthException catch (e) {
      print('Sign up error: ${e.message}');
      return null;
    }
  }

  // Login with email and password
  Future<User?> login(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      print('Login error: ${e.message}');
      return null;
    }
  }

  // Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Logout
  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Logout error: $e');
    }
  }

  // Check if user is logged in
  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }

  // Phone authentication for MFA
  Future<String?> sendPhoneVerificationCode(String phoneNumber) async {
    try {
      final Completer<String?> completer = Completer<String?>();
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-retrieved; for testing only
          completer.complete(credential.smsCode);
        },
        verificationFailed: (FirebaseAuthException e) {
          print('Phone verification failed: ${e.message}');
          completer.complete(null);
        },
        codeSent: (String verificationId, int? resendToken) {
          completer.complete(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          // Auto-retrieval timed out
        },
      );
      return await completer.future;
    } catch (e) {
      print('Error sending phone verification: $e');
      return null;
    }
  }

  // Verify phone code and link to account
  Future<User?> verifyAndLinkPhone(String verificationId, String smsCode) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final user = _auth.currentUser;
      if (user != null) {
        await user.linkWithCredential(credential);
        await _firestoreService.updateUser(user.uid, {
          'phoneNumber': user.phoneNumber,
          'mfaEnabled': true,
        });
        return user;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      print('Phone verification error: ${e.message}');
      return null;
    }
  }

  // Check if MFA is enabled for current user
  Future<bool> isMfaEnabled() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      final idTokenResult = await user.getIdTokenResult();
      final claims = idTokenResult.claims;
      return claims != null && claims['mobile_otp'] == true;
    } catch (e) {
      return false;
    }
  }

  // Sign in with phone OTP (standalone for MFA flows)
  Future<User?> signInWithPhone(String verificationId, String smsCode) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final result = await _auth.signInWithCredential(credential);
      return result.user;
    } on FirebaseAuthException catch (e) {
      print('Phone sign-in error: ${e.message}');
      return null;
    }
  }
}
