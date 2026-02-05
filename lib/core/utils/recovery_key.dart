import 'dart:math';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class RecoveryKeyUtil {
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  static String generate() {
    final rnd = Random.secure();
    final parts = List.generate(4, (_) {
      return List.generate(4, (_) => _alphabet[rnd.nextInt(_alphabet.length)])
          .join();
    });
    return parts.join('-');
  }

  static String hash(String key) {
    return sha256.convert(utf8.encode(key)).toString();
  }
}
