import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? _user;
  bool _isLoading = false;
  String _errorMessage = '';
  String? _cachedRole;

  // Getters
  User? get user => _user;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  AuthProvider() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      if (user == null) {
        _cachedRole = null;
      }
      notifyListeners();
    });
  }

  // REAL LOGIN FUNCTION
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = '';
    _cachedRole = null;
    notifyListeners();

    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      _user = result.user;
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      // ← THIS IS THE FIX: reset loading before returning
      _isLoading = false;
      _errorMessage = _friendlyAuthError(e.code, e.message);
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'An unexpected error occurred. Please try again.';
      notifyListeners();
      return false;
    }
  }

  /// Convert Firebase error codes into user-friendly messages.
  String _friendlyAuthError(String code, String? fallback) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with that email. Please check the email or contact your CHW.';
      case 'wrong-password':
        return 'Incorrect password. Please check your password and try again.';
      case 'invalid-email':
        return 'That email address is not valid. Please check and try again.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact your CHW.';
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Incorrect email or password. Please check both and try again.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please wait a few minutes and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network and try again.';
      case 'operation-not-allowed':
        return 'Email/password login is not enabled. Please contact support.';
      default:
        return fallback ?? 'Login failed. Please check your credentials and try again.';
    }
  }

  // ROLE CHECKER (CACHED FOR SPEED!)
  Future<String> getCurrentRole() async {
    if (_cachedRole != null) return _cachedRole!;

    final uid = user?.uid;
    if (uid == null) return 'none';

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    if (userDoc.exists) {
      final status = userDoc.data()?['status'];
      if (status == 'Inactive') {
        _cachedRole = 'none';
        return 'none';
      }

      final roles = userDoc.data()?['role'];
      if (roles is String) {
        if (roles == 'admin') {
          _cachedRole = 'admin';
          return 'admin';
        }
        if (roles == 'chw') {
          _cachedRole = 'chw';
          return 'chw';
        }
        if (roles == 'patient') {
          _cachedRole = 'patient';
          return 'patient';
        }
      } else if (roles is List) {
        if (roles.contains('admin')) {
          _cachedRole = 'admin';
          return 'admin';
        }
        if (roles.contains('chw')) {
          _cachedRole = 'chw';
          return 'chw';
        }
        if (roles.contains('patient')) {
          _cachedRole = 'patient';
          return 'patient';
        }
      }
    }

    final patientDoc = await FirebaseFirestore.instance
        .collection('patients')
        .doc(uid)
        .get();
    if (patientDoc.exists) {
      _cachedRole = 'patient';
      return 'patient';
    }

    final appointmentDoc = await FirebaseFirestore.instance
        .collection('appointments')
        .where('patientId', isEqualTo: uid)
        .limit(1)
        .get();
    if (appointmentDoc.docs.isNotEmpty) {
      _cachedRole = 'patient';
      return 'patient';
    }

    _cachedRole = 'none';
    return 'none';
  }

  // LOGOUT FUNCTION
  Future<void> logout() async {
    await _auth.signOut();
    _user = null;
    _cachedRole = null;
    notifyListeners();
  }
}