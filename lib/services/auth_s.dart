import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart';
import 'package:password_manager/services/fss_s.dart';

import '../utils/crypto_secure.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _user;
  bool _isAppLocked = true; // App starts in a locked state.
  bool _canCheckBiometrics = false;
  bool _isCheckingBiometrics = true;
  List<BiometricType> _availableBiometrics = [];
  SecretKey? _masterKey; // in-memory only

  // Track when the app was last unlocked (to avoid immediate re-lock on resume).
  DateTime? _lastUnlockedAt;

  // Track when an authentication flow is actively running (biometric prompt shown).
  bool _authInProgress = false;
  bool get authInProgress => _authInProgress;

  bool get isCheckingBiometrics => _isCheckingBiometrics;
  User? get user => _user;
  bool get isAppLocked => _isAppLocked;
  bool get isAuthenticated => _user != null;
  bool get canCheckBiometrics => _canCheckBiometrics;
  List<BiometricType> get availableBiometrics => _availableBiometrics;
  SecretKey? get masterKey => _masterKey;

  AuthService() {
    // Listen to Firebase auth state changes.
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  /// Returns true if the app was unlocked within [threshold].
  bool wasUnlockedRecently(Duration threshold) {
    final last = _lastUnlockedAt;
    if (last == null) return false;
    return DateTime.now().difference(last) < threshold;
  }

  Future<void> _onAuthStateChanged(User? user) async {
    _user = user;
    if (user == null) {
      // If user logs out, lock the app and clear secure storage.
      _isAppLocked = true;
      await SecurePrefs.clearAll();
    } else {
      // Try restoring master key from secure storage on restart
      await _restoreMasterKey();
    }
    notifyListeners();
  }

  /// Save master key securely
  Future<void> _persistMasterKey(SecretKey key) async {
    final bytes = await key.extractBytes();
    await SecurePrefs.writeSecure('masterKey', base64UrlEncode(bytes));
  }

  /// Restore master key securely
  Future<void> _restoreMasterKey() async {
    final savedKeyB64 = await SecurePrefs.readSecure('masterKey');
    if (savedKeyB64 != null) {
      final keyBytes = base64Url.decode(savedKeyB64);
      _masterKey = SecretKey(keyBytes);
      debugPrint('Restored master key from secure storage');
    } else {
      debugPrint('No master key in secure storage, fallback to unwrap later');
    }
  }

  /// Signs in a user with email and password.
  /// Returns null on success, or an error message string on failure.
  Future<String?> signIn({
    required String email,
    required String password,
    // required String userName,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Derive master key from user password
      final uid = cred.user!.uid;

      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) return "User encryption data missing";

      final data = doc.data()!;
      final wrapped = data['wrapped'] as String;
      final nonce = data['nonce'] as String;
      final salt = data['salt'] as String;
      final mac = data['mac'] as String;

      // Unwrap master key
      final masterKey = await unwrapMasterKey(
        wrappedB64: wrapped,
        nonceB64: nonce,
        macB64: mac,
        saltB64: salt,
        password: password,
      );

      _masterKey = masterKey;
      await _persistMasterKey(masterKey);

      // After successful Firebase login, prompt for biometrics to unlock the app.
      await SecurePrefs.writeSecure('email', email);

      await authenticateWithBiometrics();

      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  /// Signs up a user with email and password.
  /// Returns null on success, or an error message string on failure.
  Future<String?> signUp({
    required String email,
    required String password,
    // required String userName,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // After successful Firebase login, prompt for biometrics to unlock the app.
      await SecurePrefs.writeSecure('email', email);

      final uid = cred.user!.uid;

      // Generate a new AES master key
      final masterKey = await generateMasterKey();

      // Wrap it using password
      final wrapped = await wrapMasterKey(
        masterKey: masterKey,
        password: password,
      );

      // Store wrapped key in Firestore
      await _firestore.collection('users').doc(uid).set(wrapped);

      // Keep master key in memory
      _masterKey = masterKey;
      await _persistMasterKey(masterKey);

      await SecurePrefs.writeSecure('email', email);
      await authenticateWithBiometrics();

      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    _user = null;
    _masterKey = null;
    SecurePrefs.clearAll();
    await _auth.signOut();
    notifyListeners();
  }

  // Function to handle biometric authentication.
  Future<bool> authenticateWithBiometrics() async {
    _authInProgress = true;
    notifyListeners();
    try {
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access your passwords',
        options: const AuthenticationOptions(biometricOnly: false),
      );
      if (didAuthenticate) {
        _isAppLocked = false;
        _lastUnlockedAt = DateTime.now(); // mark unlock time
        notifyListeners();
      }
      return didAuthenticate;
    } catch (e) {
      _isAppLocked = true;
      notifyListeners();
      return false;
    } finally {
      _authInProgress = false;
      notifyListeners();
    }
  }

  // Sensitive action Biometric
  Future<bool> sensitiveActionWithBiometrics() async {
    try {
      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Please authenticate to Proceed this action',
        options: const AuthenticationOptions(biometricOnly: false),
      );

      return didAuthenticate;
    } catch (e) {
      return false;
    }
  }

  Future<void> checkBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      if (canCheck) {
        _availableBiometrics = await _localAuth.getAvailableBiometrics();
        final isDeviceSupported = await _localAuth.isDeviceSupported();
        _canCheckBiometrics =
            canCheck && _availableBiometrics.isNotEmpty && isDeviceSupported;
      } else {
        _canCheckBiometrics = false;
      }
    } catch (e) {
      debugPrint("Error checking for biometrics: $e");
      _canCheckBiometrics = false;
    }
    _isCheckingBiometrics = false;
    notifyListeners();
  }

  // Lock the app, when it goes into the background.
  void lockApp() {
    _isAppLocked = true;
    // Clear last unlocked timestamp so resume lock behavior is consistent.
    _lastUnlockedAt = null;
    notifyListeners();
  }
}
