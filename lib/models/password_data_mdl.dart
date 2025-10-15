import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';
import '../utils/crypto_secure.dart';

class PasswordEntry {
  final String id;
  final String account;
  final String username;
  final String category;
  final String? website;
  final DateTime createdAt;
  final String password;
  final String? notes;
  final String? hint;
  final String? recoveryEmail;
  final String? securityQuestion;
  final String? securityAnswer;

  PasswordEntry({
    String? id,
    required this.account,
    required this.username,
    required this.password,
    this.website,
    this.notes,
    this.hint,
    this.recoveryEmail,
    this.securityQuestion,
    this.securityAnswer,
    this.category = 'General',
    required this.createdAt,
  }) : id = id ?? const Uuid().v4();

  // ------------------------------
  // Firestore Encryption Methods
  // ------------------------------

  /// Encrypt all sensitive data (including password, notes, etc.)
  static Future<Map<String, dynamic>> toFirestore(
    PasswordEntry entry,
    SecretKey masterKey,
  ) async {
    final sensitiveData = jsonEncode({
      'password': entry.password,
      'notes': entry.notes,
      'hint': entry.hint,
      'recoveryEmail': entry.recoveryEmail,
      'securityQuestion': entry.securityQuestion,
      'securityAnswer': entry.securityAnswer,
    });

    final encrypted = await encryptEntry(
      masterKey: masterKey,
      plaintext: sensitiveData,
    );

    return {
      'id': entry.id,
      'account': entry.account,
      'username': entry.username,
      'website': entry.website,
      'category': entry.category,
      'createdAt': entry.createdAt.toIso8601String(),
      'secureData': encrypted,
    };
  }

  /// Decrypt Firestore entry back into a usable PasswordEntry
  static Future<PasswordEntry> fromFirestore(
    Map<String, dynamic> data,
    SecretKey masterKey,
  ) async {
    try {
      Map<String, dynamic>? secureData = data['secureData'];
      String decryptedJson;

      // NEW ENTRIES (with secureData)
      if (secureData != null) {
        decryptedJson = await decryptEntry(
          masterKey: masterKey,
          ciphertextB64: secureData['ciphertext'],
          macB64: secureData['mac'],
          nonceB64: secureData['nonce'],
        );
      }
      // OLD ENTRIES (with only password field)
      else if (data['password'] != null) {
        final encrypted = data['password'] as Map<String, dynamic>;
        final decryptedPassword = await decryptEntry(
          masterKey: masterKey,
          ciphertextB64: encrypted['ciphertext'],
          macB64: encrypted['mac'],
          nonceB64: encrypted['nonce'],
        );

        decryptedJson = jsonEncode({'password': decryptedPassword});
      } else {
        throw Exception('No encrypted data found');
      }

      final sensitive = jsonDecode(decryptedJson);

      return PasswordEntry(
        id: data['id'],
        account: data['account'],
        username: data['username'],
        website: data['website'],
        category: data['category'] ?? 'General',
        password: sensitive['password'] ?? '',
        notes: sensitive['notes'],
        hint: sensitive['hint'],
        recoveryEmail: sensitive['recoveryEmail'],
        securityQuestion: sensitive['securityQuestion'],
        securityAnswer: sensitive['securityAnswer'],
        createdAt: DateTime.parse(data['createdAt']),
      );
    } catch (e) {
      throw Exception('Failed to decrypt password entry: $e');
    }
  }

  // ------------------------------
  // Copy Helper
  // ------------------------------
  PasswordEntry copyWith({
    String? id,
    String? account,
    String? username,
    String? password,
    String? website,
    String? notes,
    String? hint,
    String? recoveryEmail,
    String? securityQuestion,
    String? securityAnswer,
    String? category,
    DateTime? createdAt,
  }) {
    return PasswordEntry(
      id: id ?? this.id,
      account: account ?? this.account,
      username: username ?? this.username,
      password: password ?? this.password,
      website: website ?? this.website,
      notes: notes ?? this.notes,
      hint: hint ?? this.hint,
      recoveryEmail: recoveryEmail ?? this.recoveryEmail,
      securityQuestion: securityQuestion ?? this.securityQuestion,
      securityAnswer: securityAnswer ?? this.securityAnswer,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
