  import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class NotificationService {
  /// Sends a general SMS via Traccar SMS Gateway
  static Future<bool> sendSmsNotification(String phone, String message) async {
    try {
      final traccarUrl = dotenv.env['TRACCAR_URL'];
      final traccarToken = dotenv.env['TRACCAR_TOKEN'];

      if (traccarUrl == null || traccarToken == null) {
        throw Exception('Traccar URL or TOKEN not found in .env');
      }

      // Format phone number with +63 prefix if not already present
      String phoneWithPrefix = phone;
      if (phone.startsWith('0')) {
        phoneWithPrefix = '+63${phone.substring(1)}';
      } else if (!phone.startsWith('+')) {
        phoneWithPrefix = '+63$phone';
      }

      final response = await http
          .post(
            Uri.parse(traccarUrl),
            headers: {
              'authorization': traccarToken,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'to': phoneWithPrefix, 'message': message}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        throw Exception(
          'Failed to send SMS. Status: ${response.statusCode}. Response: ${response.body}',
        );
      }
    } catch (error) {
      print('Error sending SMS notification: $error');
      rethrow;
    }
  }

  /// Sends a demo SMS with sample data following the PAGASA-Web-Scraper format
  static Future<bool> sendDemoSms({
    required String phone,
    required List<String> stations,
    required List<String> alertLevels,
  }) async {
    if (stations.isEmpty) {
      throw Exception('Please select at least one station for the demo.');
    }

    // Use the first selected station and alert level (if any) for the demo
    final stationName = stations.first;
    String status = alertLevels.isNotEmpty ? alertLevels.first.toUpperCase() : "";
    
    // Set sample threshold and current level based on status
    double threshold = 10.0;
    double currentLevel = 10.5;
    String advice = "";
    bool isAbnormalRise = alertLevels.isEmpty;

    if (isAbnormalRise) {
      // For abnormal rise demo without alert level
      status = "ABNORMAL";
      threshold = 10.0;
      currentLevel = 9.20; // High rise but still below alert
      advice = "» Notice: Water level is rising faster than usual. Extra caution is advised for those near the waterway.";
    } else if (status == 'CRITICAL' || status == 'CRITICAL LEVEL') {
      threshold = 15.0;
      currentLevel = 16.25;
      advice = "» Critical: High water level detected. Please strictly follow the safety advisories and instructions from your local government or barangay officials.";
    } else if (status == 'ALARM') {
      threshold = 12.0;
      currentLevel = 12.80;
      advice = "» Warning: Water level has reached the Alarm stage. Residents in low-lying areas should stay vigilant and prepare for potential flooding.";
    } else { // ALERT
      threshold = 10.0;
      currentLevel = 10.15;
      advice = "» Stay alert. Water levels are rising. Please monitor the situation and keep your communication lines open.";
    }

    final now = DateTime.now();
    // Match the scraper's timestamp format: September 15, 2023 10:30AM
    final formattedTime = DateFormat('MMMM dd, yyyy h:mma').format(now);

    // Construct message following PAGASA-Web-Scraper format exactly
    String message = "PAGASA Alert:\n";
    message += "\n$status: $stationName";
    message += "\nLevel: ${currentLevel.toStringAsFixed(2)}m (Threshold: ${threshold.toStringAsFixed(2)}m)";
    
    // Add advice
    message += "\n$advice\n";
    
    message += "\nTimestamp: $formattedTime";

    return await sendSmsNotification(phone, message);
  }
}
