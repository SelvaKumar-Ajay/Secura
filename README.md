Secura 🔐

A simple yet secure password manager built with Flutter & Firestore.
Secura uses modern cryptography (AES-GCM 256-bit) to encrypt all sensitive data before it ever leaves your device. Your passwords stay yours.

✨ Features

🔑 Master Key Encryption — AES-GCM 256-bit protects your stored entries.
🔒 Password-Based Key Derivation (PBKDF2) — derives strong keys from your password using HMAC-SHA256 with 150,000 iterations.
🗄️ Cloud Sync — securely syncs encrypted data to Google Firestore.
🛡️ Zero-Knowledge Security — only encrypted data is stored in Firestore; no plaintext passwords are ever uploaded.

⚙️ How Security Works

1. Master Key
A random 256-bit master key (32 bytes) is generated.
This key is used to encrypt/decrypt your password entries.
Think of it as the “vault key.”

2. Wrapping the Master Key
The master key itself is encrypted (wrapped) using a key derived from your login password.
Derivation is done with PBKDF2-HMAC-SHA256:
Salt: 16 random bytes
Iterations: 150,000 (slows brute force attacks)
Output: 256-bit derived key
Wrapping is performed with AES-GCM, which provides both encryption and integrity.
The wrapped master key + salt + nonce + MAC are stored in Firestore.

3. Encrypting Entries
Each password entry is encrypted with the master key using AES-GCM 256-bit.
For each encryption:
A random nonce (12 bytes) is generated.
The ciphertext and MAC (Message Authentication Code) are stored alongside the nonce.
This ensures both confidentiality (nobody can read) and authenticity (nobody can tamper).

4. Firestore Storage
Firestore stores only:
Wrapped master key data (wrapped, salt, nonce, mac)
Encrypted entries (ciphertext, nonce, mac)
Firestore never sees your plaintext or master key.

🔑 Key Crypto Concepts Used
AES-GCM (Advanced Encryption Standard – Galois/Counter Mode)
Symmetric encryption (same key to encrypt and decrypt).
256-bit key size.
Provides confidentiality + integrity.
PBKDF2 (Password-Based Key Derivation Function 2)
Strengthens weak passwords into strong keys.
Uses HMAC-SHA256 repeatedly (150,000 iterations).
HMAC (Hash-Based Message Authentication Code)
Combines hashing (SHA-256) with a secret key.
Ensures authenticity of encrypted data.
Nonce (Number used once)
Random value used with AES-GCM to ensure unique encryption each time.
MAC (Message Authentication Code)
A cryptographic tag that detects if data has been modified.

📦 Example Encryption Flow

You sign in with your password.
PBKDF2 derives a strong 256-bit key from it (using salt + iterations).
That derived key unwraps the encrypted master key stored in Firestore.
With the master key, you encrypt/decrypt your password entries locally.
Only encrypted entries are uploaded to Firestore.

🚀 Getting Started

Prerequisites

Flutter SDK installed
Firebase project set up (with Firestore enabled)

Setup

Clone repo:
git clone https://github.com/yourname/secura.git

cd secura

Install dependencies:
flutter pub get

Configure Firebase for your Flutter app.

Run:
flutter run

🛡️ Security Notes

Use a strong master password — the security of PBKDF2 depends on it.
Salts and nonces are random and unique for each operation.
Firestore only stores encrypted blobs; even if compromised, attackers cannot read entries without your password.
AES-GCM with 256-bit keys is considered state-of-the-art for application-level encryption.
