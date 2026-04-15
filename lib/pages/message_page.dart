import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart' as permission;
import '../services/bluetooth_service.dart' as bt_service;
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import '../Controller/classic_bluetooth_controller.dart';
import 'chat_page.dart';

class MessagePage extends StatefulWidget {
  final bool showAppBar;

  const MessagePage({super.key, this.showAppBar = true});

  @override
  State<MessagePage> createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> with WidgetsBindingObserver {
  final ClassicBluetoothController _classicBtController = Get.put(
    ClassicBluetoothController(),
  );
  bool _isBroadcasting = false;
  String _deviceName = 'Loading...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadDeviceInfo();
    _setupPairingListener();
    _restartBluetoothServer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // App came back to foreground, restart server to ensure it's listening
      print('🔄 App resumed, restarting Bluetooth server');
      _restartBluetoothServer();
    }
  }

  Future<void> _loadDeviceInfo() async {
    try {
      final deviceInfo = await bt_service.BluetoothService.getDeviceInfo();
      if (mounted) {
        setState(() {
          _deviceName = deviceInfo['name'] ?? 'Unknown';
        });
      }
    } catch (e) {
      print('Error loading device info: $e');
      if (mounted) {
        setState(() {
          _deviceName = 'Error';
        });
      }
    }
  }

  // Restart Bluetooth server to ensure it's ready for incoming connections
  Future<void> _restartBluetoothServer() async {
    try {
      // First stop any existing server
      await bt_service.BluetoothService.stopServer();
      // Wait a moment for cleanup
      await Future.delayed(Duration(milliseconds: 500));
      // Start fresh server
      await _startBluetoothServer();
    } catch (e) {
      print('❌ Error restarting Bluetooth server: $e');
      // If restart fails, try just starting
      await _startBluetoothServer();
    }
  }

  void _setupPairingListener() {
    bt_service.BluetoothService.setPairingListener(
      onDevicePaired: (deviceName, deviceAddress) {
        // This device received a pairing request and it was successful
        print('📱 Received pairing from: $deviceName');
        if (mounted) {
          _showIncomingPairDialog(deviceName, deviceAddress);
        }
      },
      onIncomingConnection: (deviceName, deviceAddress) {
        // Someone is connecting to chat - FORCE navigation
        print('📞 FORCE Incoming chat connection from: $deviceName');
        if (mounted) {
          // Dismiss any existing dialogs
          Navigator.of(
            context,
            rootNavigator: true,
          ).popUntil((route) => route.isFirst);

          // Force navigate to chat page
          Future.delayed(Duration(milliseconds: 100), () {
            if (mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(
                  builder: (context) => ChatPage(
                    deviceName: deviceName,
                    deviceAddress: deviceAddress,
                  ),
                  settings: RouteSettings(arguments: {'isChat': true}),
                ),
                (route) => route.isFirst,
              );
            }
          });
        }
      },
      onConnectionLost: () {
        print('📞 Connection lost, restarting server');
        // Restart server if connection is lost
        _restartBluetoothServer();
      },
    );
  }

  Future<void> _startBluetoothServer() async {
    try {
      await bt_service.BluetoothService.startServer();
      print('✅ Bluetooth server started - ready to receive connections');
    } catch (e) {
      print('❌ Failed to start Bluetooth server: $e');
    }
  }

  void _showIncomingPairDialog(String deviceName, String deviceAddress) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Device Paired'),
          content: Text('$deviceName wants to start a conversation with you.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Dismiss'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatPage(
                      deviceName: deviceName,
                      deviceAddress: deviceAddress,
                    ),
                  ),
                );
              },
              child: const Text('Open Chat'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Don't stop server on dispose as we want it to keep listening for incoming connections
    super.dispose();
  }

  void _startClassicBluetoothScanning() async {
    // Check if already scanning
    if (_classicBtController.isScanning.value) return;

    try {
      // Check if Bluetooth is turned on
      final isEnabled = await bt_service.BluetoothService.isBluetoothEnabled();
      if (!isEnabled) {
        if (mounted) {
          _showBluetoothDisabledDialog();
        }
        return;
      }

      // Check location permission (required for Bluetooth scanning on Android)
      permission.PermissionStatus locationStatus =
          await permission.Permission.locationWhenInUse.status;

      if (locationStatus.isDenied) {
        locationStatus = await permission.Permission.locationWhenInUse
            .request();
        if (!locationStatus.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Location permission is required for Bluetooth scanning',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }

      if (locationStatus.isPermanentlyDenied) {
        if (mounted) {
          _showPermissionDeniedDialog('Location');
        }
        return;
      }

      // Check Bluetooth connect permission (Android 12+)
      permission.PermissionStatus bluetoothConnectStatus =
          await permission.Permission.bluetoothConnect.status;

      if (bluetoothConnectStatus.isDenied) {
        bluetoothConnectStatus = await permission.Permission.bluetoothConnect
            .request();
        if (!bluetoothConnectStatus.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Bluetooth connect permission is required'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }

      // Use ClassicBluetoothController to scan
      await _classicBtController.scanDevices();

      if (mounted) {
        print(
          'Bluetooth scan complete. Found ${_classicBtController.scanResults.length} devices',
        );
      }
    } catch (e) {
      print('BLE Scanning error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during BLE scan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleBroadcasting() {
    if (_isBroadcasting) {
      // Stop broadcasting
      _stopBroadcasting();
    } else {
      // Start broadcasting
      _startBroadcasting();
    }
  }

  void _startBroadcasting() {
    try {
      setState(() {
        _isBroadcasting = true;
      });

      // Check for BLUETOOTH_ADVERTISE permission (Android 12+)
      _checkAdvertisePermission().then((_) {
        // Show confirmation that broadcasting started
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Broadcasting as "$_deviceName" for 2 minutes'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Start broadcasting the device for 2 minutes
        bt_service.BluetoothService.makeDeviceDiscoverable(
              discoverabilityDuration: const Duration(minutes: 2),
            )
            .then((_) {
              if (mounted) {
                setState(() {
                  _isBroadcasting = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Device broadcasting stopped'),
                    backgroundColor: Colors.blue,
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            })
            .catchError((e) {
              if (mounted) {
                setState(() {
                  _isBroadcasting = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error broadcasting device: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            });
      });
    } catch (e) {
      print('Broadcast error: $e');
      if (mounted) {
        setState(() {
          _isBroadcasting = false;
        });
      }
    }
  }

  Future<void> _checkAdvertisePermission() async {
    // Check Bluetooth advertise permission (Android 12+)
    permission.PermissionStatus advertiseStatus =
        await permission.Permission.bluetoothAdvertise.status;

    if (advertiseStatus.isDenied) {
      advertiseStatus = await permission.Permission.bluetoothAdvertise
          .request();
      if (!advertiseStatus.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Bluetooth advertise permission is required for broadcasting',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
        throw Exception('Bluetooth advertise permission denied');
      }
    }

    if (advertiseStatus.isPermanentlyDenied) {
      if (mounted) {
        _showPermissionDeniedDialog('Bluetooth advertise');
      }
      throw Exception('Bluetooth advertise permission permanently denied');
    }
  }

  void _stopBroadcasting() {
    try {
      bt_service.BluetoothService.stopBroadcasting()
          .then((_) {
            if (mounted) {
              setState(() {
                _isBroadcasting = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Device broadcasting stopped'),
                  backgroundColor: Colors.blue,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          })
          .catchError((e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error stopping broadcast: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          });
    } catch (e) {
      print('Stop broadcast error: $e');
    }
  }

  Future<void> _pairWithDevice(String deviceAddress, String deviceName) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Expanded(child: Text('Pairing with $deviceName...')),
            ],
          ),
        );
      },
    );

    try {
      final success = await bt_service.BluetoothService.pairWithDevice(
        deviceAddress,
      );

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        if (success) {
          // Close any snackbars
          ScaffoldMessenger.of(context).hideCurrentSnackBar();

          // Navigate to chat page
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatPage(
                deviceName: deviceName,
                deviceAddress: deviceAddress,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to pair with $deviceName'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error pairing: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Regardless of the AppBar flag we only display the private chat content.
    if (widget.showAppBar) {
      return Scaffold(
        backgroundColor: const Color(0xFFF1F4F8),
        appBar: AppBar(
          backgroundColor: const Color(0xFF41BAF1),
          title: const Text(
            'Messages',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25),
          ),
        ),
        body: _buildPrivateTab(),
      );
    } else {
      // Embedded mode simply returns the private chat widget directly.
      return _buildPrivateTab();
    }
  }

  Widget _buildPrivateTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Broadcasting Status Indicator
            if (_isBroadcasting)
              Container(
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue),
                ),
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Device is broadcasting and discoverable by nearby devices as $_deviceName',
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Bluetooth Scan Section
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bluetooth Devices',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Obx(
                          () => ElevatedButton.icon(
                            onPressed: _classicBtController.isScanning.value
                                ? null
                                : _startClassicBluetoothScanning,
                            icon: _classicBtController.isScanning.value
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.bluetooth),
                            label: Text(
                              _classicBtController.isScanning.value
                                  ? 'Scanning...'
                                  : 'Scan Devices',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF41BAF1),
                              disabledBackgroundColor: Colors.grey.shade300,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _toggleBroadcasting,
                        icon: _isBroadcasting
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Icon(Icons.broadcast_on_personal),
                        label: Text(_isBroadcasting ? 'Stop' : 'Broadcast'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isBroadcasting
                              ? Colors.red.shade600
                              : Colors.green.shade600,
                          disabledBackgroundColor: Colors.grey.shade300,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Display scan results
                  Obx(() {
                    if (_classicBtController.scanResults.isEmpty &&
                        !_classicBtController.isScanning.value) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.bluetooth_disabled,
                              size: 48,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No devices scanned yet',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap "Scan Devices" to find nearby Bluetooth devices',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    } else if (_classicBtController.scanResults.isNotEmpty) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Found ${_classicBtController.scanResults.length} device(s)',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount:
                                  _classicBtController.scanResults.length,
                              itemBuilder: (context, index) {
                                final result =
                                    _classicBtController.scanResults[index];
                                final deviceName =
                                    result['name'] ?? 'Unknown Device';
                                final macAddress = result['address'] ?? 'N/A';
                                final rssi =
                                    int.tryParse(result['rssi'] ?? '0') ?? 0;

                                return Column(
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.bluetooth),
                                      title: Text(deviceName),
                                      subtitle: Text(
                                        macAddress,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      trailing: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '$rssi dBm',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getSignalColor(rssi),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              _getSignalStrength(rssi),
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                      onTap: () {
                                        _pairWithDevice(macAddress, deviceName);
                                      },
                                    ),
                                    if (index <
                                        _classicBtController.scanResults.length - 1)
                                      Divider(height: 1),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Get signal strength label based on RSSI value
  String _getSignalStrength(int rssi) {
    if (rssi >= -50) {
      return 'Strong';
    } else if (rssi >= -70) {
      return 'Good';
    } else if (rssi >= -85) {
      return 'Fair';
    } else {
      return 'Weak';
    }
  }

  /// Get signal strength color based on RSSI value
  Color _getSignalColor(int rssi) {
    if (rssi >= -50) {
      return Colors.green;
    } else if (rssi >= -70) {
      return Colors.lightGreen;
    } else if (rssi >= -85) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  /// Shows dialog when Bluetooth is disabled
  void _showBluetoothDisabledDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Bluetooth Disabled'),
          content: const Text(
            'Bluetooth is turned off. Please enable Bluetooth to scan for devices.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                if (Theme.of(context).platform == TargetPlatform.android) {
                  await bt_service.BluetoothService.requestBluetoothOn();
                }
              },
              child: const Text('Enable Bluetooth'),
            ),
          ],
        );
      },
    );
  }

  /// Shows dialog when location services are disabled
  void _showLocationDisabledDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Services Disabled'),
          content: const Text(
            'Location services are required for Bluetooth scanning. Please enable location services in your device settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Geolocator.openLocationSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  /// Shows dialog when permission is permanently denied
  void _showPermissionDeniedDialog(String permissionName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permission Required'),
          content: Text(
            '$permissionName permission is permanently denied. Please enable it in app settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                permission.openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }
}
