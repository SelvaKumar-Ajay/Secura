import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/password_data_mdl.dart';
import 'auth_s.dart';

enum SortOrder { byDate, byAccountName }

/// Will fetch and manipulate data from firestore
///
class PasswordService with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  AuthService? _authService;

  List<PasswordEntry> _passwords = [];
  bool _isLoading = false;
  String? _error;
  bool _disposed = false;
  SortOrder _sortOrder = SortOrder.byDate;

  String? get _userId => _authService?.user?.uid;

  PasswordService(this._authService);

  void updateAuth(AuthService? auth) {
    _authService = auth;
    // Optionally reload passwords when auth/masterKey changes
    if (_authService?.masterKey != null && _authService?.user != null) {
      loadPasswords();
    }
  }

  List<PasswordEntry> get passwords => _passwords;
  bool get isLoading => _isLoading;
  String? get error => _error;
  SortOrder get sortOrder => _sortOrder;
  dynamic get _masterKey => _authService?.masterKey; // SecretKey
  dynamic get masterKey => _masterKey; // SecretKey

  /// Returns a reference to the user's private password collection in Firestore.
  CollectionReference<Map<String, dynamic>> get _passwordsCollection =>
      _firestore.collection('users').doc(_userId).collection('passwords');

  void _sortPasswords() {
    switch (_sortOrder) {
      case SortOrder.byDate:
        _passwords.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case SortOrder.byAccountName:
        _passwords.sort((a, b) => a.account.toLowerCase().compareTo(b.account.toLowerCase()));
        break;
    }
  }

  void setSortOrder(SortOrder order) {
    _sortOrder = order;
    _sortPasswords();
    notifyListeners();
  }

  /// Load passwords from Firestore, waits for master key if not available yet
  Future<void> loadPasswords() async {
    if (_masterKey == null) {
      debugPrint('Master key not ready yet. Waiting...');
      // wait for master key to become available
      await _waitForMasterKey();
    }

    if (_masterKey == null) {
      debugPrint('Vault locked: master key unavailable, cannot load passwords');
      _passwords = [];
      notifyListeners();
      return;
    }

    if (_userId == null) {
      _passwords = [];
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snapshot = await _passwordsCollection.get();
      _passwords = await Future.wait(
        snapshot.docs.map((doc) async {
          return PasswordEntry.fromFirestore(doc.data(), _masterKey!);
        }).toList(),
      );
      _sortPasswords();
    } catch (e) {
      _passwords = [];
      _error = "Error loading passwords from Firestore: $e";
      debugPrint(_error);
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Wait for master key to become available
  Future<void> _waitForMasterKey({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final start = DateTime.now();
    while (_masterKey == null) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (DateTime.now().difference(start) > timeout) break;
    }
  }

  /// Add new password to firestore
  Future<void> addPassword(PasswordEntry entry) async {
    if (_masterKey == null) {
      throw Exception("Vault is locked: master key unavailable");
    }
    if (_userId == null) return;

    final encrypted = await PasswordEntry.toFirestore(entry, _masterKey);
    await _passwordsCollection.doc(entry.id).set(encrypted);
    _passwords.add(entry);
    _sortPasswords();
    notifyListeners();
  }

  // Update the existing password
  Future<void> updatePassword(PasswordEntry updatedEntry) async {
    if (_userId == null) return;

    final encrypted = await PasswordEntry.toFirestore(updatedEntry, _masterKey);
    await _passwordsCollection.doc(updatedEntry.id).update(encrypted);

    final index = _passwords.indexWhere((p) => p.id == updatedEntry.id);
    if (index != -1) {
      _passwords[index] = updatedEntry;
      _sortPasswords();
      notifyListeners();
    }
  }

  ///Delete the password with id
  Future<void> deletePassword(String id) async {
    if (_userId == null) return;

    await _passwordsCollection.doc(id).delete();
    _passwords.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void notifySafely() {
    if (!_disposed) {
      notifyListeners();
    }
  }
}