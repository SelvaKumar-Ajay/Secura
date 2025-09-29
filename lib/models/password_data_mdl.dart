import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';
import '../utils/crypto_secure.dart';

class PasswordEntry {
  final String id;
  final String account;
  final String username;
  final String password; // always stored decrypted in memory
  final DateTime createdAt;

  PasswordEntry({
    String? id,
    required this.account,
    required this.username,
    required this.password,
    required this.createdAt,
  }) : id = id ?? const Uuid().v4();

  /// Async factory to decrypt Firestore document
  static Future<PasswordEntry> fromFirestore(
    Map<String, dynamic> data,
    SecretKey masterKey,
  ) async {
    try {
      final encrypted = data['password'] as Map<String, dynamic>;
      final decryptedPassword = await decryptEntry(
        masterKey: masterKey,
        ciphertextB64: encrypted['ciphertext'],
        macB64: encrypted['mac'],
        nonceB64: encrypted['nonce'],
      );

      return PasswordEntry(
        id: data['id'],
        account: data['account'],
        username: data['username'],
        password: decryptedPassword,
        createdAt: DateTime.parse(data['createdAt']),
      );
    } catch (e) {
      throw Exception('Failed to decrypt password entry: $e');
    }
  }

  /// Async method to encrypt this entry before saving to Firestore
  static Future<Map<String, dynamic>> toFirestore(
    PasswordEntry entry,
    SecretKey masterKey,
  ) async {
    final encrypted = await encryptEntry(
      masterKey: masterKey,
      plaintext: entry.password,
    );

    return {
      'id': entry.id,
      'account': entry.account,
      'username': entry.username,
      'password': encrypted,
      'createdAt': entry.createdAt.toIso8601String(),
    };
  }

  /// Copy helper for immutability
  PasswordEntry copyWith({
    String? id,
    String? account,
    String? username,
    String? password,
    DateTime? createdAt,
  }) {
    return PasswordEntry(
      id: id ?? this.id,
      account: account ?? this.account,
      username: username ?? this.username,
      password: password ?? this.password,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
