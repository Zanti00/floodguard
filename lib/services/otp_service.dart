import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_settings_service.dart';

class OTPService {
  /// Generates a random 6-digit OTP
  static String generateOTP() {
    final random = Random();
    final otp = random.nextInt(1000000);
    return otp.toString().padLeft(6, '0');
  }

  /// Sends OTP via Traccar SMS Gateway
  static Future<bool> sendOTPViaSMS(String phone, String otp) async {
    try {
      final traccarUrl = dotenv.env['TRACCAR_URL'];
      final traccarToken = dotenv.env['TRACCAR_TOKEN'];

      if (traccarUrl == null || traccarToken == null) {
        throw Exception('Traccar URL or TOKEN not found in .env');
      }

      final message = 'Your FloodGuard OTP is: $otp';

      // Format phone number with + prefix if not already present
      final phoneWithPrefix = phone.startsWith('+')
          ? phone
          : '+63${phone.substring(1)}';

      // Send SMS using Traccar SMS endpoint with API Key authentication
      final response = await http
          .post(
            Uri.parse(traccarUrl),
            headers: {
              'authorization': traccarToken,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'to': phoneWithPrefix, 'message': message}),
          )
          .timeout(Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        throw Exception(
          'Failed to send OTP. Status: ${response.statusCode}. Response: ${response.body}',
        );
      }
    } catch (error) {
      print('Error sending OTP via SMS: $error');
      rethrow;
    }
  }

  /// Stores OTP in Supabase for verification
  static Future<void> storeOTPInDatabase(String phone, String otp) async {
    try {
      await Supabase.instance.client.from('otp_verifications').upsert({
        'phone_number': phone,
        'otp': otp,
        'created_at': DateTime.now().toIso8601String(),
        'expires_at': DateTime.now()
            .add(Duration(minutes: 10))
            .toIso8601String(),
        'is_verified': false,
      });
    } catch (error) {
      // Log the database error but continue - OTP was sent successfully via SMS
      print('Warning: Could not store OTP in database: $error');
      print('OTP will only be verified via SMS.');
    }
  }

  /// Verifies OTP against the stored record
  static Future<bool> verifyOTP(String phone, String otp) async {
    try {
      final response = await Supabase.instance.client
          .from('otp_verifications')
          .select()
          .eq('phone_number', phone)
          .order('created_at', ascending: false)
          .limit(1);

      if (response.isEmpty) {
        throw Exception('OTP is invalid and/or expired');
      }

      final otpRecord = response[0];
      final expiresAt = DateTime.parse(otpRecord['expires_at']);
      final isVerified = otpRecord['is_verified'] ?? false;

      // Check if OTP has already been verified (used)
      if (isVerified) {
        throw Exception(
          'This OTP has already been used. Please request a new OTP.',
        );
      }

      // Check if OTP has expired
      if (DateTime.now().isAfter(expiresAt)) {
        throw Exception('OTP has expired. Please request a new OTP.');
      }

      // Check if OTP matches
      if (otpRecord['otp'] != otp) {
        throw Exception('Invalid OTP. Please enter the correct code.');
      }

      // Mark OTP as verified
      await Supabase.instance.client
          .from('otp_verifications')
          .update({'is_verified': true})
          .eq('id', otpRecord['id']);

      return true;
    } catch (error) {
      print('Error verifying OTP: $error');
      rethrow;
    }
  }

  /// Complete OTP send flow (generate, send via SMS, store in DB)
  static Future<String> sendOTP(String phone) async {
    try {
      // Check if SMS feature is enabled
      final smsEnabled = await AppSettingsService.getBoolSetting(
        'sms_enabled',
        defaultValue: true,
      );

      if (!smsEnabled) {
        throw Exception(
          'SMS feature is currently disabled for maintenance. Please try again later.',
        );
      }

      // Generate OTP
      final otp = generateOTP();

      // Send OTP via SMS
      await sendOTPViaSMS(phone, otp);

      // Store OTP in database
      await storeOTPInDatabase(phone, otp);

      return otp;
    } catch (error) {
      print('Error in sendOTP: $error');
      rethrow;
    }
  }
}
