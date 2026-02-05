import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked,
    ),
    mOptions: MacOsOptions(
      accessibility: KeychainAccessibility.unlocked,
    ),
  );

  static const _masterKeyKey = 'master_key_vault';
  static const _pinHashKey = 'master_pin_hash';
  static const _recoveryKeyHash = 'recovery_key_hash';

  // ===== MASTER KEY =====
  Future<void> writeMasterKey(String key) async {
    await _storage.write(key: _masterKeyKey, value: key);
  }

  Future<String?> readMasterKey() async {
    return await _storage.read(key: _masterKeyKey);
  }

  Future<void> deleteMasterKey() async {
    await _storage.delete(key: _masterKeyKey);
  }

  // ===== PIN HASH =====
  Future<void> writePinHash(String hash) async {
    await _storage.write(key: _pinHashKey, value: hash);
  }

  Future<String?> readPinHash() async {
    return await _storage.read(key: _pinHashKey);
  }

  Future<void> deletePinHash() async {
    await _storage.delete(key: _pinHashKey);
  }

  // ===== RECOVERY KEY =====
  Future<void> writeRecoveryKeyHash(String hash) async {
    await _storage.write(key: _recoveryKeyHash, value: hash);
  }

  Future<String?> readRecoveryKeyHash() async {
    return await _storage.read(key: _recoveryKeyHash);
  }

  Future<void> deleteRecoveryKeyHash() async {
    await _storage.delete(key: _recoveryKeyHash);
  }

  // ===== Generic Key/Value Storage (Biometrics, Preferences, etc.) =====
  Future<void> writeValue(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  Future<String?> readValue(String key) async {
    return await _storage.read(key: key);
  }
}
