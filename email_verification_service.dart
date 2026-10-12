import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailVerificationService {
  // Admin credentials configured by user
  static const String _adminEmail = 'kiakia.admin@gmail.com';
  static const String _appPassword = 'irlu emrz qzvy bovy'; // Google App Password
  static const String _appName = 'Kia Kia Penang';

  /// Generates a random 6-digit verification code
  static String generateVerificationCode() {
    return (100000 + Random().nextInt(900000)).toString();
  }

  /// Sends a functional HTML verification email to [recipientEmail] with [code]
  static Future<bool> sendVerificationEmail({
    required String recipientEmail,
    required String code,
  }) async {
    final cleanEmail = recipientEmail.trim();
    if (cleanEmail.isEmpty) return false;

    // Set up Gmail SMTP Server
    final cleanPassword = _appPassword.replaceAll(' ', '');
    final smtpServer = gmail(_adminEmail, cleanPassword);

    final message = Message()
      ..from = Address(_adminEmail, _appName)
      ..recipients.add(cleanEmail)
      ..subject = '[$_appName] Your 6-Digit Email Verification Code'
      ..html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #F8FAFC; margin: 0; padding: 24px; }
    .card { max-width: 520px; margin: 0 auto; background: #ffffff; border-radius: 20px; padding: 36px 28px; box-shadow: 0 4px 20px rgba(0,0,0,0.06); border: 1px solid #E2E8F0; }
    .header { text-align: center; margin-bottom: 24px; }
    .title { color: #1E293B; font-size: 24px; font-weight: 700; margin-top: 12px; }
    .text { color: #475569; font-size: 15px; line-height: 1.6; margin-bottom: 24px; }
    .code-box { background: #EEF2FF; border: 2px dashed #304FFE; border-radius: 16px; padding: 18px; text-align: center; margin: 24px 0; }
    .code { font-size: 34px; font-weight: 800; letter-spacing: 10px; color: #304FFE; font-family: monospace; }
    .warning { color: #94A3B8; font-size: 12px; text-align: center; margin-top: 24px; border-top: 1px solid #F1F5F9; padding-top: 16px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="header">
      <div style="font-size: 40px;">🧭</div>
      <div class="title">Kia Kia Penang</div>
    </div>
    <p class="text">
      Hello Explorer,<br><br>
      Thank you for being part of Kia Kia Penang! Please use the following 6-digit verification code to verify your email address:
    </p>
    <div class="code-box">
      <div class="code">$code</div>
    </div>
    <p class="text" style="font-size: 13px; color: #64748B;">
      This code is valid for 10 minutes. If you did not request this verification, you can safely ignore this email.
    </p>
    <div class="warning">
      © 2026 Kia Kia Penang (kiakiapenangfyp). All rights reserved.
    </div>
  </div>
</body>
</html>
''';

    try {
      final sendReport = await send(message, smtpServer);
      debugPrint('Verification email sent successfully: $sendReport');
      return true;
    } catch (e) {
      debugPrint('Error sending verification email: $e');
      rethrow;
    }
  }
}
