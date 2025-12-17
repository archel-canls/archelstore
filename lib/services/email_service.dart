import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailService {
  // Kredensial Admin Anda
  final String _username = 'archelscuritypw@gmail.com';
  final String _password = 'hxrhxlezkjpakllz'; // App Password

  Future<bool> sendOtp(String recipientEmail, String otp, {bool isReset = false}) async {
    final smtpServer = gmail(_username, _password);
    
    String subject = isReset 
        ? 'Kode Reset Password ArchelStore' 
        : 'Kode Verifikasi Pendaftaran ArchelStore';
        
    String htmlContent = '''
      <div style="font-family: Arial, sans-serif; padding: 20px; border: 1px solid #e0e0e0; border-radius: 10px;">
        <h2 style="color: #E91E63;">ArchelStore Security</h2>
        <p>Halo,</p>
        <p>Gunakan kode rahasia berikut untuk melanjutkan proses ${isReset ? 'reset password' : 'pendaftaran'} Anda:</p>
        <h1 style="background-color: #fce4ec; padding: 10px; text-align: center; letter-spacing: 5px; color: #E91E63; border-radius: 5px;">$otp</h1>
        <p>Kode ini berlaku selama 5 menit. Jangan berikan kepada siapapun, termasuk pihak ArchelStore.</p>
        <hr>
        <p style="font-size: 12px; color: grey;">Ini adalah pesan otomatis, mohon tidak membalas.</p>
      </div>
    ''';

    final message = Message()
      ..from = Address(_username, 'ArchelStore Security')
      ..recipients.add(recipientEmail)
      ..subject = '$subject: $otp'
      ..html = htmlContent;

    try {
      await send(message, smtpServer);
      print('OTP berhasil dikirim ke $recipientEmail');
      return true;
    } catch (e) {
      print('Gagal kirim email: $e');
      return false;
    }
  }
}