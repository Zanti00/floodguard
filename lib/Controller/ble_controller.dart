import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';

class BleController extends GetxController {
  // Store scan results
  final RxList<ScanResult> scanResults = <ScanResult>[].obs;
  final RxBool isScanning = false.obs;

  Future<void> scanDevice({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    // Prevent multiple simultaneous scans
    if (isScanning.value) return;

    try {
      isScanning.value = true;
      scanResults.clear();

      // Subscribe to scan results stream
      FlutterBluePlus.scanResults.listen((results) {
        scanResults.value = results;
      });

      // Start scan with timeout
      await FlutterBluePlus.startScan(timeout: timeout);

      // Wait for scan to complete
      await Future.delayed(timeout);
    } catch (e) {
      print('Error during BLE scan: $e');
    } finally {
      isScanning.value = false;
    }
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } finally {
      isScanning.value = false;
    }
  }

  // Getter to access scan results
  List<ScanResult> get results => scanResults;
}
