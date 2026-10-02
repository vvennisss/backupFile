import 'dart:convert';

class EncryptionService {
  // Secret key used for password encoding and decoding.
  static const String _key = "KiaKiaPenangAppSecretKeyForPasswords";

  /// Symmetric XOR encryption with base64 encoding.
  static String encode(String text) {
    List<int> textBytes = utf8.encode(text);
    List<int> keyBytes = utf8.encode(_key);
    List<int> resultBytes = [];

    for (int i = 0; i < textBytes.length; i++) {
      resultBytes.add(textBytes[i] ^ keyBytes[i % keyBytes.length]);
    }
    return base64.encode(resultBytes);
  }

  /// Symmetric XOR decryption.
  static String decode(String encodedText) {
    try {
      List<int> encryptedBytes = base64.decode(encodedText);
      List<int> keyBytes = utf8.encode(_key);
      List<int> resultBytes = [];

      for (int i = 0; i < encryptedBytes.length; i++) {
        resultBytes.add(encryptedBytes[i] ^ keyBytes[i % keyBytes.length]);
      }
      return utf8.decode(resultBytes);
    } catch (e) {
      return '';
    }
  }

  /// Helper to check if user input matches the encoded password.
  static bool verify(String inputPassword, String encodedPassword) {
    final decoded = decode(encodedPassword);
    return inputPassword == decoded;
  }
}
