import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class TotpService {
  static String generateSecret() {
    final random = Random.secure();
    final bytes = List<int>.generate(20, (_) => random.nextInt(256));
    return base32Encode(Uint8List.fromList(bytes));
  }

  static String getTotpUri(String secret, String accountName) {
    return 'otpauth://totp/LaidaniRepair:$accountName?secret=$secret&issuer=LaidaniRepair';
  }

  static bool verifyTotp(String secret, String code, {int window = 1}) {
    try {
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      for (int i = -window; i <= window; i++) {
        final generated = _generateTotp(secret, now + i * 30);
        if (generated == code) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  static String _generateTotp(String secret, int timeCounter) {
    final key = base32Decode(secret);
    var counter = timeCounter ~/ 30;
    final counterBytes = Uint8List(8);
    for (int i = 7; i >= 0; i--) {
      counterBytes[i] = counter & 0xFF;
      if (i < 7) counter = counter >> 8;
    }
    final hmac = Hmac(sha1, key);
    final hash = hmac.convert(counterBytes);
    final offset = hash.bytes.last & 0x0F;
    final binary = ((hash.bytes[offset] & 0x7F) << 24) |
        ((hash.bytes[offset + 1] & 0xFF) << 16) |
        ((hash.bytes[offset + 2] & 0xFF) << 8) |
        (hash.bytes[offset + 3] & 0xFF);
    return (binary % 1000000).toString().padLeft(6, '0');
  }

  static String base32Encode(Uint8List bytes) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final buffer = StringBuffer();
    for (int i = 0; i < bytes.length; i += 5) {
      final n = (i < bytes.length ? bytes[i] : 0) << 32 |
          (i + 1 < bytes.length ? bytes[i + 1] : 0) << 24 |
          (i + 2 < bytes.length ? bytes[i + 2] : 0) << 16 |
          (i + 3 < bytes.length ? bytes[i + 3] : 0) << 8 |
          (i + 4 < bytes.length ? bytes[i + 4] : 0);
      buffer.write(alphabet[(n >> 35) & 0x1F]);
      buffer.write(alphabet[(n >> 30) & 0x1F]);
      buffer.write(alphabet[(n >> 25) & 0x1F]);
      buffer.write(alphabet[(n >> 20) & 0x1F]);
      buffer.write(alphabet[(n >> 15) & 0x1F]);
      buffer.write(alphabet[(n >> 10) & 0x1F]);
      buffer.write(alphabet[(n >> 5) & 0x1F]);
      buffer.write(alphabet[n & 0x1F]);
    }
    return buffer.toString();
  }

  static Uint8List base32Decode(String input) {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
    final s = input.toUpperCase().replaceAll(RegExp('[^A-Z2-7]'), '');
    final result = <int>[];
    int buffer = 0, bitsLeft = 0;
    for (int i = 0; i < s.length; i++) {
      final value = alphabet.indexOf(s[i]);
      if (value == -1) continue;
      buffer = (buffer << 5) | value;
      bitsLeft += 5;
      if (bitsLeft >= 8) {
        bitsLeft -= 8;
        result.add((buffer >> bitsLeft) & 0xFF);
      }
    }
    return Uint8List.fromList(result);
  }
}
