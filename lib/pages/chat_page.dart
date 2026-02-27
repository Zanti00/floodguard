import 'package:flutter/material.dart';
import '../services/bluetooth_service.dart' as bt_service;

class ChatMessage {
  final String text;
  final bool isMe;
  final bool isSystem;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isMe,
    this.isSystem = false,
    required this.timestamp,
  });
}

class ChatPage extends StatefulWidget {
  final String deviceName;
  final String deviceAddress;

  const ChatPage({
    super.key,
    required this.deviceName,
    required this.deviceAddress,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isConnecting = true;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _connectToDevice();
    _setupMessageListener();
  }

  Future<void> _connectToDevice() async {
    setState(() {
      _isConnecting = true;
      _messages.add(
        ChatMessage(
          text: 'Connecting to ${widget.deviceName}...',
          isMe: false,
          isSystem: true,
          timestamp: DateTime.now(),
        ),
      );
    });

    try {
      final success = await bt_service.BluetoothService.connectToDevice(
        widget.deviceAddress,
      );

      setState(() {
        _isConnecting = false;
        _isConnected = success;

        if (success) {
          _messages.add(
            ChatMessage(
              text: 'Connected to ${widget.deviceName}',
              isMe: false,
              isSystem: true,
              timestamp: DateTime.now(),
            ),
          );
        } else {
          _messages.add(
            ChatMessage(
              text: 'Failed to connect to ${widget.deviceName}',
              isMe: false,
              isSystem: true,
              timestamp: DateTime.now(),
            ),
          );
        }
      });
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _isConnected = false;
        _messages.add(
          ChatMessage(
            text: 'Connection error: $e',
            isMe: false,
            isSystem: true,
            timestamp: DateTime.now(),
          ),
        );
      });
    }
  }

  void _setupMessageListener() {
    bt_service.BluetoothService.setMessageListener(
      (message) {
        if (mounted) {
          setState(() {
            _messages.add(
              ChatMessage(text: message, isMe: false, timestamp: DateTime.now()),
            );
          });

          // Scroll to bottom when receiving message
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }
      },
      onConnectionLost: () {
        if (mounted) {
          setState(() {
            _isConnected = false;
            _messages.add(
              ChatMessage(
                text: 'Connection lost',
                isMe: false,
                isSystem: true,
                timestamp: DateTime.now(),
              ),
            );
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    bt_service.BluetoothService.disconnectDevice();
    // Don't restart server here to avoid conflicts - let MessagePage handle it
    super.dispose();
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;
    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Not connected to device'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final message = _messageController.text.trim();

    setState(() {
      _messages.add(
        ChatMessage(text: message, isMe: true, timestamp: DateTime.now()),
      );
    });

    _messageController.clear();

    // Scroll to bottom after sending message
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });

    // Send message via Bluetooth
    try {
      final success = await bt_service.BluetoothService.sendMessage(message);
      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to send message'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF41BAF1),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.deviceName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              _isConnecting
                  ? 'Connecting...'
                  : _isConnected
                  ? 'Connected'
                  : 'Disconnected',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: _isConnected ? Colors.white : Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              _showDeviceInfo();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start a conversation',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      return _buildMessageBubble(message);
                    },
                  ),
          ),
          // Message input
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(
                            color: Color(0xFF41BAF1),
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    backgroundColor: const Color(0xFF41BAF1),
                    radius: 24,
                    child: IconButton(
                      icon: const Icon(
                        Icons.send,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    if (message.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              message.text,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: message.isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!message.isMe) ...[
            CircleAvatar(
              backgroundColor: Colors.grey.shade300,
              radius: 16,
              child: Icon(Icons.person, size: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: message.isMe ? const Color(0xFF41BAF1) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: message.isMe
                      ? const Radius.circular(16)
                      : const Radius.circular(4),
                  bottomRight: message.isMe
                      ? const Radius.circular(4)
                      : const Radius.circular(16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      fontSize: 15,
                      color: message.isMe ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      color: message.isMe
                          ? Colors.white.withOpacity(0.8)
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (message.isMe) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              backgroundColor: const Color(0xFF41BAF1).withOpacity(0.2),
              radius: 16,
              child: const Icon(
                Icons.person,
                size: 18,
                color: Color(0xFF41BAF1),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      return '${timestamp.day}/${timestamp.month} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  void _showDeviceInfo() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Device Information'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Device Name', widget.deviceName),
              const SizedBox(height: 12),
              _buildInfoRow('MAC Address', widget.deviceAddress),
              const SizedBox(height: 12),
              _buildInfoRow(
                'Status',
                _isConnected ? 'Connected' : 'Disconnected',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _showDisconnectDialog();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Disconnect'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  void _showDisconnectDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Disconnect Device'),
          content: Text(
            'Are you sure you want to disconnect from ${widget.deviceName}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // Go back to previous page
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Disconnect'),
            ),
          ],
        );
      },
    );
  }
}
