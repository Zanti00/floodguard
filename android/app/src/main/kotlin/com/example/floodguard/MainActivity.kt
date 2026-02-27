package com.example.floodguard

import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothSocket
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.InputStream
import java.io.OutputStream
import java.util.UUID
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.floodguard/bluetooth"
    private val SPP_UUID = UUID.fromString("00001101-0000-1000-8000-00805f9b34fb") // Standard SPP UUID
    private val bluetoothAdapter = BluetoothAdapter.getDefaultAdapter()
    private val discoveredDevices = mutableListOf<Map<String, String>>()
    private var scanReceiver: BroadcastReceiver? = null
    private var bluetoothSocket: BluetoothSocket? = null
    private var serverSocket: android.bluetooth.BluetoothServerSocket? = null
    private var inputStream: InputStream? = null
    private var outputStream: OutputStream? = null
    private var messageChannel: MethodChannel? = null
    private var isConnected = false
    private var isServerRunning = false
    private var readThread: Thread? = null
    private var serverThread: Thread? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        messageChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        messageChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isBluetoothEnabled" -> {
                    try {
                        val isEnabled = bluetoothAdapter?.isEnabled ?: false
                        result.success(isEnabled)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to check Bluetooth status", e.message)
                    }
                }
                "getDeviceName" -> {
                    try {
                        val deviceName = bluetoothAdapter?.name ?: "Unknown"
                        result.success(deviceName)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to get device name", e.message)
                    }
                }
                "getDeviceAddress" -> {
                    try {
                        val deviceAddress = bluetoothAdapter?.address ?: "Unavailable"
                        result.success(deviceAddress)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to get device address", e.message)
                    }
                }
                "scanDevices" -> {
                    try {
                        val durationSeconds = call.argument<Int>("durationSeconds") ?: 15
                        scanForDevices(durationSeconds, result)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to scan devices", e.message)
                    }
                }
                "makeDiscoverable" -> {
                    try {
                        val durationSeconds = call.argument<Int>("durationSeconds") ?: 120
                        makeDeviceDiscoverable(durationSeconds, result)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to make device discoverable", e.message)
                    }
                }
                "cancelDiscoverability" -> {
                    try {
                        cancelDiscoverability(result)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to cancel discoverability", e.message)
                    }
                }
                "pairDevice" -> {
                    try {
                        val deviceAddress = call.argument<String>("address")
                        if (deviceAddress != null) {
                            pairWithDevice(deviceAddress, result)
                        } else {
                            result.error("ERROR", "Device address is required", null)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to pair with device", e.message)
                    }
                }
                "connectDevice" -> {
                    try {
                        val deviceAddress = call.argument<String>("address")
                        if (deviceAddress != null) {
                            connectToDevice(deviceAddress, result)
                        } else {
                            result.error("ERROR", "Device address is required", null)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to connect to device", e.message)
                    }
                }
                "disconnectDevice" -> {
                    try {
                        disconnectFromDevice(result)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to disconnect", e.message)
                    }
                }
                "sendMessage" -> {
                    try {
                        val message = call.argument<String>("message")
                        if (message != null) {
                            sendMessage(message, result)
                        } else {
                            result.error("ERROR", "Message is required", null)
                        }
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to send message", e.message)
                    }
                }
                "startServer" -> {
                    try {
                        startBluetoothServer(result)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to start server", e.message)
                    }
                }
                "stopServer" -> {
                    try {
                        stopBluetoothServer(result)
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to stop server", e.message)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun scanForDevices(durationSeconds: Int, result: MethodChannel.Result) {
        thread {
            try {
                discoveredDevices.clear()
                
                // Create broadcast receiver for discovery
                scanReceiver = object : BroadcastReceiver() {
                    override fun onReceive(context: Context, intent: Intent) {
                        val action = intent.action
                        when (action) {
                            BluetoothDevice.ACTION_FOUND -> {
                                val device = intent.getParcelableExtra<BluetoothDevice>(BluetoothDevice.EXTRA_DEVICE)
                                val rssi = intent.getShortExtra(BluetoothDevice.EXTRA_RSSI, Short.MIN_VALUE)
                                
                                device?.let {
                                    val deviceMap = mapOf(
                                        "name" to (it.name ?: "Unknown"),
                                        "address" to (it.address ?: "N/A"),
                                        "rssi" to rssi.toString()
                                    )
                                    
                                    // Avoid duplicates
                                    if (!discoveredDevices.any { it["address"] == device.address }) {
                                        discoveredDevices.add(deviceMap)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Register receiver
                val filter = IntentFilter(BluetoothDevice.ACTION_FOUND)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    registerReceiver(scanReceiver, filter, Context.RECEIVER_EXPORTED)
                } else {
                    registerReceiver(scanReceiver, filter)
                }
                
                // Start discovery
                bluetoothAdapter?.startDiscovery()
                
                // Wait for scan duration
                Thread.sleep((durationSeconds * 1000).toLong())
                
                // Stop discovery
                bluetoothAdapter?.cancelDiscovery()
                
                // Unregister receiver
                try {
                    unregisterReceiver(scanReceiver)
                } catch (e: IllegalArgumentException) {
                    // Receiver not registered
                }
                
                // Return results
                result.success(discoveredDevices)
            } catch (e: Exception) {
                result.error("ERROR", "Scan failed: ${e.message}", null)
            }
        }
    }

    private fun makeDeviceDiscoverable(durationSeconds: Int, result: MethodChannel.Result) {
        try {
            val discoverableIntent = Intent(BluetoothAdapter.ACTION_REQUEST_DISCOVERABLE)
            discoverableIntent.putExtra(BluetoothAdapter.EXTRA_DISCOVERABLE_DURATION, durationSeconds)
            startActivity(discoverableIntent)
            result.success(null)
        } catch (e: Exception) {
            result.error("ERROR", "Failed to make discoverable: ${e.message}", null)
        }
    }

    private fun cancelDiscoverability(result: MethodChannel.Result) {
        try {
            // Note: Android doesn't provide a direct way to cancel discoverability
            // The discoverability will timeout automatically
            result.success(null)
        } catch (e: Exception) {
            result.error("ERROR", "Failed to cancel discoverability: ${e.message}", null)
        }
    }

    private fun pairWithDevice(deviceAddress: String, result: MethodChannel.Result) {
        thread {
            try {
                val device = bluetoothAdapter?.getRemoteDevice(deviceAddress)
                
                if (device == null) {
                    result.error("ERROR", "Device not found", null)
                    return@thread
                }

                // Check if already paired
                if (device.bondState == BluetoothDevice.BOND_BONDED) {
                    result.success(true)
                    return@thread
                }

                // Create pairing broadcast receiver
                val pairingReceiver = object : BroadcastReceiver() {
                    override fun onReceive(context: Context, intent: Intent) {
                        val action = intent.action
                        if (action == BluetoothDevice.ACTION_BOND_STATE_CHANGED) {
                            val bondState = intent.getIntExtra(BluetoothDevice.EXTRA_BOND_STATE, BluetoothDevice.BOND_NONE)
                            val previousBondState = intent.getIntExtra(BluetoothDevice.EXTRA_PREVIOUS_BOND_STATE, BluetoothDevice.BOND_NONE)
                            
                            when (bondState) {
                                BluetoothDevice.BOND_BONDED -> {
                                    // Successfully paired
                                    unregisterReceiver(this)
                                    
                                    // Notify Flutter about successful pairing
                                    Handler(Looper.getMainLooper()).post {
                                        messageChannel?.invokeMethod("onDevicePaired", mapOf(
                                            "deviceName" to (device.name ?: "Unknown"),
                                            "deviceAddress" to device.address
                                        ))
                                    }
                                    
                                    result.success(true)
                                }
                                BluetoothDevice.BOND_NONE -> {
                                    if (previousBondState == BluetoothDevice.BOND_BONDING) {
                                        // Pairing failed
                                        unregisterReceiver(this)
                                        result.success(false)
                                    }
                                }
                            }
                        }
                    }
                }

                // Register pairing receiver
                val filter = IntentFilter(BluetoothDevice.ACTION_BOND_STATE_CHANGED)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    registerReceiver(pairingReceiver, filter, Context.RECEIVER_EXPORTED)
                } else {
                    registerReceiver(pairingReceiver, filter)
                }

                // Initiate pairing
                device.createBond()
                
            } catch (e: Exception) {
                result.error("ERROR", "Pairing failed: ${e.message}", null)
            }
        }
    }

    private fun connectToDevice(deviceAddress: String, result: MethodChannel.Result) {
        thread {
            try {
                if (isConnected) {
                    result.success(true)
                    return@thread
                }

                val device = bluetoothAdapter?.getRemoteDevice(deviceAddress)
                if (device == null) {
                    result.error("ERROR", "Device not found", null)
                    return@thread
                }

                // Cancel discovery to improve connection reliability
                bluetoothAdapter?.cancelDiscovery()

                // Try connecting with fallback method
                bluetoothSocket = try {
                    device.createRfcommSocketToServiceRecord(SPP_UUID)
                } catch (e: Exception) {
                    // Fallback method using reflection for problematic devices
                    device.javaClass.getMethod("createRfcommSocket", Int::class.javaPrimitiveType)
                        .invoke(device, 1) as BluetoothSocket
                }
                
                try {
                    // Connect to the device
                    bluetoothSocket?.connect()
                } catch (e: Exception) {
                    // If first method fails, try the fallback method
                    bluetoothSocket?.close()
                    bluetoothSocket = device.javaClass.getMethod("createRfcommSocket", Int::class.javaPrimitiveType)
                        .invoke(device, 1) as BluetoothSocket
                    bluetoothSocket?.connect()
                }
                
                // Get input and output streams
                inputStream = bluetoothSocket?.inputStream
                outputStream = bluetoothSocket?.outputStream
                
                isConnected = true
                
                // Start listening for incoming messages
                startReadThread()
                
                result.success(true)
            } catch (e: Exception) {
                cleanupConnection()
                result.error("ERROR", "Connection failed: ${e.message}", null)
            }
        }
    }

    private fun startBluetoothServer(result: MethodChannel.Result) {
        if (isServerRunning) {
            result.success(true)
            return
        }

        // Clean up any existing connections before starting server
        cleanupConnection()

        serverThread = thread {
            try {
                serverSocket = bluetoothAdapter?.listenUsingRfcommWithServiceRecord("FloodGuard", SPP_UUID)
                isServerRunning = true
                
                Handler(Looper.getMainLooper()).post {
                    result.success(true)
                }
                
                while (isServerRunning && serverSocket != null) {
                    try {
                        println("📡 Server waiting for incoming connections...")
                        val socket = serverSocket?.accept()
                        if (socket != null) {
                            println("📞 New connection received from: ${socket.remoteDevice?.name}")
                            
                            // If already connected, clean up previous connection first
                            if (isConnected) {
                                println("🔄 Cleaning up previous connection before accepting new one")
                                cleanupConnection()
                            }
                            
                            bluetoothSocket = socket
                            inputStream = socket.inputStream
                            outputStream = socket.outputStream
                            isConnected = true
                            
                            // Notify Flutter about incoming connection
                            Handler(Looper.getMainLooper()).post {
                                val device = socket.remoteDevice
                                println("📱 Notifying Flutter about incoming connection")
                                messageChannel?.invokeMethod("onIncomingConnection", mapOf(
                                    "deviceName" to (device?.name ?: "Unknown"),
                                    "deviceAddress" to (device?.address ?: "Unknown")
                                ))
                            }
                            
                            startReadThread()
                        }
                    } catch (e: Exception) {
                        println("❌ Server accept error: ${e.message}")
                        if (isServerRunning) {
                            break
                        }
                    }
                }
            } catch (e: Exception) {
                Handler(Looper.getMainLooper()).post {
                    if (!result.toString().contains("success")) {
                        result.error("ERROR", "Server failed: ${e.message}", null)
                    }
                }
            }
        }
    }

    private fun stopBluetoothServer(result: MethodChannel.Result) {
        try {
            isServerRunning = false
            serverSocket?.close()
            serverSocket = null
            serverThread?.interrupt()
            serverThread = null
            result.success(true)
        } catch (e: Exception) {
            result.error("ERROR", "Failed to stop server: ${e.message}", null)
        }
    }

    private fun disconnectFromDevice(result: MethodChannel.Result) {
        try {
            cleanupConnection()
            // Notify Flutter about disconnection
            Handler(Looper.getMainLooper()).post {
                messageChannel?.invokeMethod("onConnectionLost", null)
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("ERROR", "Disconnect failed: ${e.message}", null)
        }
    }

    private fun sendMessage(message: String, result: MethodChannel.Result) {
        thread {
            try {
                if (!isConnected || outputStream == null) {
                    result.error("ERROR", "Not connected to a device", null)
                    return@thread
                }

                val bytes = message.toByteArray(Charsets.UTF_8)
                outputStream?.write(bytes)
                outputStream?.flush()
                
                result.success(true)
            } catch (e: Exception) {
                result.error("ERROR", "Failed to send message: ${e.message}", null)
            }
        }
    }

    private fun startReadThread() {
        readThread = thread {
            val buffer = ByteArray(1024)
            var bytes: Int

            while (isConnected) {
                try {
                    bytes = inputStream?.read(buffer) ?: -1
                    if (bytes > 0) {
                        val receivedMessage = String(buffer, 0, bytes, Charsets.UTF_8)
                        
                        // Send message back to Flutter
                        Handler(Looper.getMainLooper()).post {
                            messageChannel?.invokeMethod("onMessageReceived", receivedMessage)
                        }
                    }
                } catch (e: Exception) {
                    if (isConnected) {
                        // Connection lost
                        cleanupConnection()
                        Handler(Looper.getMainLooper()).post {
                            messageChannel?.invokeMethod("onConnectionLost", null)
                        }
                    }
                    break
                }
            }
        }
    }

    private fun cleanupConnection() {
        isConnected = false
        
        try {
            inputStream?.close()
        } catch (e: Exception) {}
        
        try {
            outputStream?.close()
        } catch (e: Exception) {}
        
        try {
            bluetoothSocket?.close()
        } catch (e: Exception) {}
        
        inputStream = null
        outputStream = null
        bluetoothSocket = null
        
        readThread?.interrupt()
        readThread = null
    }

    override fun onDestroy() {
        cleanupConnection()
        isServerRunning = false
        try {
            serverSocket?.close()
        } catch (e: Exception) {}
        serverThread?.interrupt()
        super.onDestroy()
    }
}
