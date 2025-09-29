import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';

final _rand = Random.secure();
final _aesGcm = AesGcm.with256bits();
final _pbkdf2 = Pbkdf2(
  macAlgorithm: Hmac.sha256(),
  iterations: 150000, // tune for performance/security (>=100k)
  bits: 256,
);

String _b64(List<int> bytes) => base64UrlEncode(bytes);
List<int> _unb64(String s) => base64Url.decode(s);

Future<SecretKey> deriveKeyFromPassword({
  required String password,
  required List<int> salt,
}) async {
  final secretKey = await _pbkdf2.deriveKey(
    secretKey: SecretKey(utf8.encode(password)),
    nonce: salt, // pbkdf2 uses 'nonce' param for salt
  );
  return secretKey;
}

/// Generate random bytes
List<int> randomBytes(int len) =>
    List<int>.generate(len, (_) => _rand.nextInt(256));

/// Generate a new random AES master key (32 bytes)
Future<SecretKey> generateMasterKey() async {
  return SecretKey(randomBytes(32));
}

/// Wrap (encrypt) masterKey with a key derived from password.
/// Returns a map you can JSON store: {wrapped, salt, nonce}
Future<Map<String, String>> wrapMasterKey({
  required SecretKey masterKey,
  required String password,
}) async {
  final salt = randomBytes(16); // store with wrapped blob
  final derived = await deriveKeyFromPassword(password: password, salt: salt);

  // AES-GCM needs a nonce
  final nonce = randomBytes(12);

  // extract master key bytes
  final masterKeyBytes = await masterKey.extractBytes();

  final secretBox = await _aesGcm.encrypt(
    masterKeyBytes,
    secretKey: derived,
    nonce: nonce,
  );

  return {
    'wrapped': _b64(secretBox.cipherText),
    'mac': _b64(secretBox.mac.bytes),
    'nonce': _b64(nonce),
    'salt': _b64(salt),
    'algorithm': 'AES-GCM-256',
    'kdf': 'PBKDF2-HMAC-SHA256',
    'kdf_iterations': '150000',
  };
}

/// Unwrap (decrypt) wrapped master key using password & stored salt/nonce
Future<SecretKey> unwrapMasterKey({
  required String wrappedB64,
  required String saltB64,
  required String nonceB64,
  required String macB64,
  required String password,
}) async {
  final salt = _unb64(saltB64);
  final nonce = _unb64(nonceB64);
  final wrapped = _unb64(wrappedB64);
  final mac = Mac(_unb64(macB64));

  final derived = await deriveKeyFromPassword(password: password, salt: salt);

  final secretBox = SecretBox(wrapped, nonce: nonce, mac: mac);

  // after got all required fields decrypt and get it as plain
  final plain = await _aesGcm.decrypt(secretBox, secretKey: derived);

  return SecretKey(plain);
}

/// Encrypt a password entry with the master key
Future<Map<String, String>> encryptEntry({
  required SecretKey masterKey,
  required String plaintext,
}) async {
  final nonce = randomBytes(12);
  final secretBox = await _aesGcm.encrypt(
    utf8.encode(plaintext),
    secretKey: masterKey,
    nonce: nonce,
  );
  return {
    'ciphertext': _b64(secretBox.cipherText),
    'mac': _b64(secretBox.mac.bytes),
    'nonce': _b64(nonce),
    'version': '1',
  };
}

/// Decrypt entry
Future<String> decryptEntry({
  required SecretKey masterKey,
  required String ciphertextB64,
  required String nonceB64,
  required String macB64,
}) async {
  final cipher = _unb64(ciphertextB64);
  final nonce = _unb64(nonceB64);
  final mac = Mac(_unb64(macB64));

  final secretBox = SecretBox(cipher, nonce: nonce, mac: mac);
  final plain = await _aesGcm.decrypt(secretBox, secretKey: masterKey);
  return utf8.decode(plain);
}
