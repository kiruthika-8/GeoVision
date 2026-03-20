import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache the user name to reduce Firestore reads
  String? _cachedName;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<Map<String, dynamic>> signIn(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = result.user!.uid;
      final userDoc = await _firestore.collection('users').doc(uid).get();

      String role = 'student';
      String name = email.split('@')[0];

      if (userDoc.exists) {
        final data = userDoc.data()!;
        role = data['role'] as String? ?? 'student';
        name = data['name'] as String? ?? name;
      } else {
        // First-time sign-in: create user record
        await _firestore.collection('users').doc(uid).set({
          'email': email.trim(),
          'name': name,
          'role': 'student',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      _cachedName = name;
      return {
        'success': true,
        'user': result.user,
        'role': role,
        'message': 'Login successful',
      };
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': _authErrorMessage(e.code)};
    } catch (e) {
      debugPrint('SignIn error: $e');
      return {'success': false, 'message': 'An unexpected error occurred.'};
    }
  }

  Future<Map<String, dynamic>> register(
      String email, String password, String name) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      await _firestore.collection('users').doc(result.user!.uid).set({
        'email': email.trim(),
        'name': name.trim(),
        'role': 'student',
        'createdAt': FieldValue.serverTimestamp(),
      });

      _cachedName = name.trim();
      return {
        'success': true,
        'user': result.user,
        'role': 'student',
        'message': 'Registration successful',
      };
    } on FirebaseAuthException catch (e) {
      debugPrint('Register FirebaseAuth error: ${e.code}');
      return {'success': false, 'message': _authErrorMessage(e.code)};
    } catch (e) {
      debugPrint('Register error: $e');
      return {'success': false, 'message': 'An unexpected error occurred.'};
    }
  }

  Future<String> getUserRole(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) return doc.data()?['role'] as String? ?? 'student';
      return 'student';
    } catch (e) {
      debugPrint('getUserRole error: $e');
      return 'student';
    }
  }

  Future<String> getStudentName() async {
    if (_cachedName != null) return _cachedName!;
    try {
      if (currentUser == null) return 'Unknown';
      final doc =
      await _firestore.collection('users').doc(currentUser!.uid).get();
      final data = doc.exists ? doc.data() : null;
      final name = (data != null ? data['name'] as String? : null) ?? 'Unknown';
      _cachedName = name;
      return name;
    } catch (e) {
      debugPrint('getStudentName error: $e');
      return 'Unknown';
    }
  }

  Future<void> signOut() async {
    _cachedName = null;
    await _auth.signOut();
  }

  String _authErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect email or password.';
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}