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
      // If user logs out, lock the app, clear master key, and clear secure storage.
      _isAppLocked = true;
      _masterKey = null;
      await SecurePrefs.clearAll();
    }
    notifyListeners();
  }

  /// Signs in a user with email and password.
  /// Returns null on success, or an error message string on failure.
  Future<String?> signIn({
    required String email,
    required String password,
    // required String userName,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);

      // After successful Firebase login, unlock the vault to get the master key.
      await SecurePrefs.writeSecure('email', email);
      return await unlockVault(password);
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

      await SecurePrefs.writeSecure('email', email);
      await authenticateWithBiometrics();

      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  /// Signs out the current user.
  Future<void> signOut() async {
    await _auth.signOut();
    _user = null;
    _masterKey = null;
    _isAppLocked = true;
    await SecurePrefs.clearAll();
    notifyListeners();
  }

  /// Unwraps the master key using the password and stores it in memory.
  Future<String?> unlockVault(String password) async {
    if (_user == null) return 'Not signed in.';
    try {
      final doc = await _firestore.collection('users').doc(_user!.uid).get();
      if (!doc.exists) return "User encryption data missing.";

      final data = doc.data()!;
      final wrapped = data['wrapped'] as String;
      final nonce = data['nonce'] as String;
      final salt = data['salt'] as String;
      final mac = data['mac'] as String;

      final masterKey = await unwrapMasterKey(
        wrappedB64: wrapped,
        nonceB64: nonce,
        macB64: mac,
        saltB64: salt,
        password: password,
      );

      _masterKey = masterKey;
      _isAppLocked = false;
      _lastUnlockedAt = DateTime.now();
      notifyListeners();
      return null; // Success
    } on Exception {
      // Generic error for wrong password to avoid enumeration attacks.
      return 'Incorrect password. Please try again.';
    }
  }

  /// Changes the user's master password for both Auth and Firestore.
  Future<String?> changeMasterPassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    if (_masterKey == null) {
      return 'Vault is locked. Please restart the app and unlock it first.';
    }
    if (_user == null) {
      return 'You are not signed in.';
    }

    // 1. Re-authenticate with the old password to ensure user is verified.
    try {
      final cred = EmailAuthProvider.credential(
        email: _user!.email!,
        password: oldPassword,
      );
      await _user!.reauthenticateWithCredential(cred);
    } on FirebaseAuthException catch (e) {
      return 'Incorrect current password. ${e.message}';
    }

    // 2. Update the password in Firebase Authentication.
    try {
      await _user!.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      return 'Failed to update password: ${e.message}';
    }

    // 3. Re-wrap the in-memory master key with the new password.
    try {
      final newWrappedData = await wrapMasterKey(
        masterKey: _masterKey!,
        password: newPassword,
      );

      // 4. Update the wrapped key data in Firestore.
      await _firestore.collection('users').doc(_user!.uid).set(newWrappedData);
    } catch (e) {
      // This is a critical failure state. The user's login password has changed,
      // but their data is still encrypted with the old one.
      return 'CRITICAL: Password updated, but failed to re-encrypt vault. Please contact support.';
    }

    return null; // Success
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
