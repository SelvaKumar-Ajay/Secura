import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:math';

/// [SecurePrefs] will used to store senstive informations
/// Cause it uses platform specific secured storage (iOS Keychain, Android Keystore/EncryptedSharedPreferences)
class SecurePrefs {
  static final IOSOptions _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
  );
  static final AndroidOptions _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );
  static final FlutterSecureStorage _secureStorage =
      const FlutterSecureStorage();

  // Key name where we persist the AES key (base64)
  static const String _masterKeyName = 'master_encryption_key_v1';

  /// Get or generate a 32-byte AES key (base64 encoded)
  static Future<String> getOrCreateMasterKey() async {
    var key = await _secureStorage.read(key: _masterKeyName);
    if (key == null) {
      final rnd = Random.secure();
      final bytes = List<int>.generate(32, (_) => rnd.nextInt(256));
      key = base64UrlEncode(bytes);
      await _secureStorage.write(
        key: _masterKeyName,
        value: key,
        iOptions: _iosOptions,
        aOptions: _androidOptions,
      );
    }
    return key;
  }

  /// Securely write with key and platform options
  static Future<void> writeSecure(String key, String value) async =>
      await _secureStorage.write(
        key: key,
        value: value,
        iOptions: _iosOptions,
        aOptions: _androidOptions,
      );

  /// Securely write boolean values with key and platform options
  static Future<void> writeBoolSecure(String key, bool value) async =>
      await _secureStorage.write(
        key: key,
        value: value.toString(),
        iOptions: _iosOptions,
        aOptions: _androidOptions,
      );

  /// Securely read with key and platform options
  static Future<String?> readSecure(String key) async => await _secureStorage
      .read(key: key, iOptions: _iosOptions, aOptions: _androidOptions);

  /// Securely read boolean values by with key and platform options
  static Future<bool> readBoolSecure(String key) async {
    final value = await _secureStorage.read(
      key: key,
      iOptions: _iosOptions,
      aOptions: _androidOptions,
    );
    return value?.toLowerCase() == 'true';
  }

  /// Securely delete with key and platform options
  static Future<void> deleteSecure(String key) async => await _secureStorage
      .delete(key: key, iOptions: _iosOptions, aOptions: _androidOptions);

  /// Clear all values of
  static Future<void> clearAll() async {
    await _secureStorage.deleteAll();
  }
}
