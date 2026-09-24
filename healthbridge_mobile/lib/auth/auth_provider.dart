import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  User? _user;
  bool _isLoading = false;
  String _errorMessage = '';
  String? _cachedRole; // <--- NEW: Cache the role

  // Getters
  User? get user => _user;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  AuthProvider() {
    // Listen to auth state changes automatically
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      if (user == null) {
        _cachedRole = null; // <--- Clear cache on logout
      }
      notifyListeners();
    });
  }

  // REAL LOGIN FUNCTION
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = '';
    _cachedRole = null; // <--- Reset cache on new login
    notifyListeners();

    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      
      _user = result.user;
      _isLoading = false;
      notifyListeners();
      return true; // Login successful

    } on FirebaseAuthException catch (e) {
      // Handle specific Firebase errors
      _errorMessage = e.message ?? 'An error occurred during login.';
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'An unexpected error occurred.';
      notifyListeners();
      return false;
    }
  }

  // ROLE CHECKER (CACHED FOR SPEED!)
  Future<String> getCurrentRole() async {
    // If we already know the role, return it immediately (No Firestore call!)
    if (_cachedRole != null) return _cachedRole!;

    final uid = user?.uid;
    if (uid == null) return 'none';

    // 1. Check if user is in the 'users' collection
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (userDoc.exists) {
      // Check Status
      final status = userDoc.data()?['status'];
      if (status == 'Inactive') {
        _cachedRole = 'none'; // Cache the blocked role
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

    // 2. ALSO check if user is in the 'patients' collection
    final patientDoc = await FirebaseFirestore.instance.collection('patients').doc(uid).get();
    if (patientDoc.exists) {
      _cachedRole = 'patient';
      return 'patient';
    }

    // 3. ALSO check if user is in the 'appointments' collection
    final appointmentDoc = await FirebaseFirestore.instance.collection('appointments').where('patientId', isEqualTo: uid).limit(1).get();
    if (appointmentDoc.docs.isNotEmpty) {
      _cachedRole = 'patient';
      return 'patient';
    }

    _cachedRole = 'none'; // Cache nothing found
    return 'none';
  }

  // LOGOUT FUNCTION
  Future<void> logout() async {
    await _auth.signOut();
    _user = null;
    _cachedRole = null; // <--- Clear cache on logout
    notifyListeners();
  }
}