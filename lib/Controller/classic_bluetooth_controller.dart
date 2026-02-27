import 'package:get/get.dart';
import '../services/bluetooth_service.dart';

class ClassicBluetoothController extends GetxController {
  // Store scan results
  final RxList<Map<String, String>> scanResults = <Map<String, String>>[].obs;
  final RxBool isScanning = false.obs;

  Future<void> scanDevices({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    // Prevent multiple simultaneous scans
    if (isScanning.value) return;

    try {
      isScanning.value = true;
      scanResults.clear();

      // Start classic Bluetooth scan
      final results = await BluetoothService.scanForClassicDevices(
        scanDuration: timeout,
      );

      scanResults.value = results;
      print('Classic Bluetooth scan complete. Found ${results.length} devices');
    } catch (e) {
      print('Error during classic Bluetooth scan: $e');
    } finally {
      isScanning.value = false;
    }
  }

  void clearResults() {
    scanResults.clear();
  }

  // Getter to access scan results
  List<Map<String, String>> get results => scanResults;
}
