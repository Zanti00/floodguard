import 'package:flutter/services.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';

class BluetoothService {
  static bool _isDiscoveryActive = false;
  static String _deviceName = '';
  static String _deviceAddress = '';
  static const platform = MethodChannel('com.example.floodguard/bluetooth');
  static final FlutterBlePeripheral _blePeripheral = FlutterBlePeripheral();

  /// Checks if Bluetooth is enabled on the device
  /// Includes retry logic with delays to handle state changes
  static Future<bool> isBluetoothEnabled() async {
    try {
      final isEnabled = await platform.invokeMethod<bool>('isBluetoothEnabled');
      print('Bluetooth enabled check result: $isEnabled');
      return isEnabled ?? false;
    } catch (e) {
      print('Error checking Bluetooth status: $e');
      return false;
    }
  }

  /// Checks Bluetooth status with retry logic to handle timing issues
  static Future<bool> isBluetoothEnabledWithRetry({
    int maxRetries = 3,
    Duration retryDelay = const Duration(milliseconds: 500),
  }) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        final isEnabled = await isBluetoothEnabled();
        if (isEnabled) {
          print('Bluetooth is enabled (attempt ${i + 1}/$maxRetries)');
          return true;
        }
        if (i < maxRetries - 1) {
          print(
            'Bluetooth not enabled, retrying... (attempt ${i + 1}/$maxRetries)',
          );
          await Future.delayed(retryDelay);
        }
      } catch (e) {
        print('Error on attempt ${i + 1}: $e');
        if (i < maxRetries - 1) {
          await Future.delayed(retryDelay);
        }
      }
    }
    return false;
  }

  /// Gets the device name and address using platform channels
  static Future<Map<String, String>> getDeviceInfo() async {
    try {
      // Get device name using platform channel
      try {
        _deviceName =
            await platform.invokeMethod<String>('getDeviceName') ?? 'Unknown';
      } catch (e) {
        _deviceName = 'Unknown';
        print('Could not get device name: $e');
      }

      // Get device address using platform channel
      try {
        _deviceAddress =
            await platform.invokeMethod<String>('getDeviceAddress') ??
            'Unavailable';
      } catch (e) {
        _deviceAddress = 'Unavailable';
        print('Could not get device address: $e');
      }

      return {'name': _deviceName, 'address': _deviceAddress};
    } catch (e) {
      print('Error getting device info: $e');
      return {'name': 'Unknown', 'address': 'Unavailable'};
    }
  }

  /// Gets the current device name
  static String getDeviceName() {
    return _deviceName.isNotEmpty ? _deviceName : 'Unknown';
  }

  /// Gets the current device address
  static String getDeviceAddress() {
    print(_deviceAddress);
    return _deviceAddress.isNotEmpty ? _deviceAddress : 'Unavailable';
  }

  /// Enables BLE advertising for the device
  /// Makes the device discoverable via BLE for the specified duration
  static Future<void> makeDeviceDiscoverable({
    Duration discoverabilityDuration = const Duration(seconds: 120),
  }) async {
    try {
      _isDiscoveryActive = true;

      // Get device info if not already loaded
      if (_deviceName.isEmpty) {
        final info = await getDeviceInfo();
        _deviceName = info['name'] ?? 'FloodGuard';
      }

      print(
        '🔵 BLE BROADCAST STARTED: Device advertising for ${discoverabilityDuration.inSeconds} seconds',
      );
      print('📱 Device Name: $_deviceName');

      // Start BLE advertising with error handling
      try {
        final advertiseData = AdvertiseData(
          serviceUuid:
              '0000FFF0-0000-1000-8000-00805F9B34FB', // Custom service UUID for FloodGuard
          localName: _deviceName,
          includeDeviceName: true,
        );

        final advertiseSettings = AdvertiseSettings(
          advertiseMode: AdvertiseMode.advertiseModeBalanced,
          txPowerLevel: AdvertiseTxPower.advertiseTxPowerHigh,
          connectable: true,
        );

        await _blePeripheral.start(
          advertiseData: advertiseData,
          advertiseSettings: advertiseSettings,
        );

        print('✅ BLE advertising started successfully');
        print('📡 Service UUID: 0000FFF0-0000-1000-8000-00805F9B34FB');
        print('📍 Device should now be visible in BLE scanners');
      } catch (e) {
        print('❌ BLE advertising failed: $e');
        print('💡 Trying classic Bluetooth only...');
      }

      // Also try classic Bluetooth discoverability as fallback
      try {
        await platform.invokeMethod<void>('makeDiscoverable', {
          'durationSeconds': discoverabilityDuration.inSeconds,
        });
        print('✅ Classic Bluetooth discoverability also enabled');
      } catch (e) {
        print('ℹ️ Classic Bluetooth discoverability not available: $e');
      }

      // Maintain the discoverable state for the specified duration
      await Future.delayed(discoverabilityDuration);

      await stopBroadcasting();
      print(
        '⏹️ BROADCAST ENDED: Device advertising stopped automatically after ${discoverabilityDuration.inSeconds} seconds',
      );
    } catch (e) {
      print('❌ Error making device discoverable: $e');
      _isDiscoveryActive = false;
      rethrow;
    }
  }

  /// Stops making the device discoverable
  static Future<void> stopBroadcasting() async {
    try {
      // Stop BLE advertising
      await _blePeripheral.stop();
      print('✅ BLE advertising stopped');

      // Stop classic Bluetooth discoverability
      try {
        await platform.invokeMethod<void>('cancelDiscoverability');
        print('✅ Classic Bluetooth discoverability stopped');
      } catch (e) {
        print('ℹ️ Classic Bluetooth discoverability stop: $e');
      }

      _isDiscoveryActive = false;
      print('⏹️ BROADCAST STOPPED: Device advertising manually stopped');
    } catch (e) {
      print('Error stopping broadcast: $e');
      _isDiscoveryActive = false;
      rethrow;
    }
  }

  /// Checks if the device is currently discoverable
  static bool isBroadcasting() {
    return _isDiscoveryActive;
  }

  /// Checks if BLE is supported on the device
  static Future<bool> isBleSupported() async {
    try {
      // This requires flutter_blue_plus package
      // Import it at the top if not already imported
      final isSupported = await platform.invokeMethod<bool>(
        'isBluetoothSupported',
      );
      return isSupported ?? false;
    } catch (e) {
      print('Error checking BLE support: $e');
      return false;
    }
  }

  /// Checks if Bluetooth adapter is currently turned on
  static Future<bool> isBluetoothOn() async {
    try {
      final isOn = await platform.invokeMethod<bool>('isBluetoothOn');
      return isOn ?? false;
    } catch (e) {
      print('Error checking if Bluetooth is on: $e');
      return false;
    }
  }

  /// Requests to turn on Bluetooth (Android only)
  static Future<void> requestBluetoothOn() async {
    try {
      await platform.invokeMethod<void>('turnOnBluetooth');
    } catch (e) {
      print('Error requesting Bluetooth on: $e');
      rethrow;
    }
  }

  /// Comprehensive Bluetooth readiness check
  /// Returns a map with status information
  static Future<Map<String, dynamic>> checkBluetoothReadiness() async {
    try {
      final isSupported = await isBluetoothEnabled();
      if (!isSupported) {
        return {
          'ready': false,
          'reason': 'not_supported',
          'message': 'Bluetooth is not supported on this device',
        };
      }

      final isOn = await isBluetoothEnabled();
      if (!isOn) {
        return {
          'ready': false,
          'reason': 'not_enabled',
          'message': 'Bluetooth is turned off',
        };
      }

      return {
        'ready': true,
        'reason': 'ready',
        'message': 'Bluetooth is ready',
      };
    } catch (e) {
      print('Error checking Bluetooth readiness: $e');
      return {
        'ready': false,
        'reason': 'error',
        'message': 'Error checking Bluetooth: $e',
      };
    }
  }

  /// Scans for classic Bluetooth devices
  static Future<List<Map<String, String>>> scanForClassicDevices({
    Duration scanDuration = const Duration(seconds: 15),
  }) async {
    try {
      print(
        '🔍 Starting classic Bluetooth scan for ${scanDuration.inSeconds} seconds',
      );
      final results = await platform.invokeListMethod<Map<dynamic, dynamic>>(
        'scanDevices',
        {'durationSeconds': scanDuration.inSeconds},
      );

      if (results == null) {
        print('⚠️ No devices found in classic Bluetooth scan');
        return [];
      }

      final devices = results
          .map(
            (result) => {
              'name': result['name'] as String? ?? 'Unknown',
              'address': result['address'] as String? ?? 'N/A',
              'rssi': result['rssi']?.toString() ?? '0',
            },
          )
          .toList();

      print('✅ Found ${devices.length} classic Bluetooth device(s)');
      return devices;
    } catch (e) {
      print('❌ Error scanning for classic Bluetooth devices: $e');
      return [];
    }
  }

  /// Pairs with a classic Bluetooth device
  static Future<bool> pairWithDevice(String deviceAddress) async {
    try {
      print('🔗 Attempting to pair with device: $deviceAddress');
      final success = await platform.invokeMethod<bool>('pairDevice', {
        'address': deviceAddress,
      });

      if (success == true) {
        print('✅ Successfully paired with device: $deviceAddress');
        return true;
      } else {
        print('❌ Failed to pair with device: $deviceAddress');
        return false;
      }
    } catch (e) {
      print('❌ Error pairing with device: $e');
      return false;
    }
  }

  /// Connects to a paired Bluetooth device for communication
  static Future<bool> connectToDevice(String deviceAddress) async {
    try {
      print('🔌 Attempting to connect to device: $deviceAddress');
      final success = await platform.invokeMethod<bool>('connectDevice', {
        'address': deviceAddress,
      });

      if (success == true) {
        print('✅ Successfully connected to device: $deviceAddress');
        return true;
      } else {
        print('❌ Failed to connect to device: $deviceAddress');
        return false;
      }
    } catch (e) {
      print('❌ Error connecting to device: $e');
      return false;
    }
  }

  /// Disconnects from the currently connected device
  static Future<bool> disconnectDevice() async {
    try {
      print('🔌 Disconnecting from device');
      final success = await platform.invokeMethod<bool>('disconnectDevice');

      if (success == true) {
        print('✅ Successfully disconnected');
        return true;
      } else {
        print('❌ Failed to disconnect');
        return false;
      }
    } catch (e) {
      print('❌ Error disconnecting: $e');
      return false;
    }
  }

  /// Sends a text message to the connected device
  static Future<bool> sendMessage(String message) async {
    try {
      print('📤 Sending message: $message');
      final success = await platform.invokeMethod<bool>('sendMessage', {
        'message': message,
      });

      if (success == true) {
        print('✅ Message sent successfully');
        return true;
      } else {
        print('❌ Failed to send message');
        return false;
      }
    } catch (e) {
      print('❌ Error sending message: $e');
      return false;
    }
  }

  /// Sets up a listener for receiving messages
  static void setMessageListener(
    Function(String) onMessageReceived, {
    Function()? onConnectionLost,
  }) {
    const messageChannel = MethodChannel('com.example.floodguard/bluetooth');
    messageChannel.setMethodCallHandler((call) async {
      if (call.method == 'onMessageReceived') {
        final message = call.arguments as String;
        print('📥 Received message: $message');
        onMessageReceived(message);
      } else if (call.method == 'onConnectionLost') {
        print('📞 Connection lost');
        onConnectionLost?.call();
      }
    });
  }

  /// Starts a Bluetooth server to listen for incoming connections
  static Future<bool> startServer() async {
    try {
      print('🔧 Starting Bluetooth server');
      final success = await platform.invokeMethod<bool>('startServer');

      if (success == true) {
        print('✅ Bluetooth server started');
        return true;
      } else {
        print('❌ Failed to start Bluetooth server');
        return false;
      }
    } catch (e) {
      print('❌ Error starting server: $e');
      return false;
    }
  }

  /// Stops the Bluetooth server
  static Future<bool> stopServer() async {
    try {
      print('⏹️ Stopping Bluetooth server');
      final success = await platform.invokeMethod<bool>('stopServer');

      if (success == true) {
        print('✅ Bluetooth server stopped');
        return true;
      } else {
        print('❌ Failed to stop Bluetooth server');
        return false;
      }
    } catch (e) {
      print('❌ Error stopping server: $e');
      return false;
    }
  }

  /// Sets up listeners for pairing and connection events
  static void setPairingListener({
    Function(String deviceName, String deviceAddress)? onDevicePaired,
    Function(String deviceName, String deviceAddress)? onIncomingConnection,
    Function()? onConnectionLost,
  }) {
    const messageChannel = MethodChannel('com.example.floodguard/bluetooth');
    messageChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onDevicePaired':
          final Map<String, dynamic> data = Map<String, dynamic>.from(
            call.arguments,
          );
          final deviceName = data['deviceName'] as String;
          final deviceAddress = data['deviceAddress'] as String;
          print('📱 Device paired: $deviceName ($deviceAddress)');
          onDevicePaired?.call(deviceName, deviceAddress);
          break;
        case 'onIncomingConnection':
          final Map<String, dynamic> data = Map<String, dynamic>.from(
            call.arguments,
          );
          final deviceName = data['deviceName'] as String;
          final deviceAddress = data['deviceAddress'] as String;
          print('📞 Incoming connection: $deviceName ($deviceAddress)');
          onIncomingConnection?.call(deviceName, deviceAddress);
          break;
        case 'onConnectionLost':
          print('📞 Connection lost');
          onConnectionLost?.call();
          break;
        case 'onMessageReceived':
          // Handle in message listener if set up
          break;
      }
    });
  }
}
