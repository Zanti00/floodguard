import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/otp_service.dart';

class EditMonitoredStationPage extends StatefulWidget {
  const EditMonitoredStationPage({super.key});

  @override
  State<EditMonitoredStationPage> createState() =>
      _EditMonitoredStationPageState();
}

class _EditMonitoredStationPageState extends State<EditMonitoredStationPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _updated = false;
  bool _otpSent = false;
  int _resendCountdown = 0;
  bool _isResendDisabled = false;
  bool _isSendingOTP = false;
  bool _isResendingOTP = false;
  String? _otpError;
  bool _isPhoneValid = false;
  String? _phoneWarning;
  List<String> _stations = [];
  Map<String, bool> _selectedStations = {};
  bool _isLoadingStations = true;
  String? _stationError;
  List<String> _currentStations = [];

  @override
  void initState() {
    super.initState();
    _fetchStations();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _fetchStations() async {
    try {
      final response = await Supabase.instance.client
          .from('water_levels')
          .select('station_name')
          .order('station_name');

      final uniqueStations = <String>{};
      for (var entry in response) {
        uniqueStations.add(entry['station_name']);
      }

      setState(() {
        _stations = uniqueStations.toList();
        // Initialize all stations as unchecked
        for (var station in _stations) {
          _selectedStations[station] = false;
        }
        _isLoadingStations = false;
      });
    } catch (error) {
      setState(() {
        _stationError = 'Error loading stations: $error';
        _isLoadingStations = false;
      });
      print('Error fetching stations: $error');
    }
  }

  void _validatePhoneNumber(String value) {
    setState(() {
      // Remove any non-digit characters
      String digitsOnly = value.replaceAll(RegExp(r'\D'), '');

      if (digitsOnly.isEmpty) {
        _phoneWarning = null;
        _isPhoneValid = false;
      } else if (digitsOnly.length < 11) {
        _phoneWarning = 'Phone number must be exactly 11 digits';
        _isPhoneValid = false;
      } else if (digitsOnly.length > 11) {
        _phoneWarning = 'Phone number must be exactly 11 digits';
        _isPhoneValid = false;
      } else if (!digitsOnly.startsWith('09')) {
        _phoneWarning = 'Phone number must start with "09"';
        _isPhoneValid = false;
      } else {
        _phoneWarning = null;
        _isPhoneValid = true;
      }

      // Update the controller if it has non-digit characters
      if (value != digitsOnly) {
        _phoneController.value = _phoneController.value.copyWith(
          text: digitsOnly,
          selection: TextSelection.collapsed(offset: digitsOnly.length),
        );
      }
    });
  }

  /// Helper function to clean error messages
  String _cleanErrorMessage(String errorMessage) {
    // Remove "Exception: " prefix
    if (errorMessage.startsWith('Exception: ')) {
      return errorMessage.replaceFirst('Exception: ', '');
    }
    return errorMessage;
  }

  void _sendOTP({bool isResend = false}) async {
    setState(() {
      if (isResend) {
        _isResendingOTP = true;
      } else {
        _isSendingOTP = true;
      }
      _otpError = null;
    });

    try {
      final phone = _phoneController.text;

      // Check if phone number is already registered in users table
      try {
        final existingUser = await Supabase.instance.client
            .from('users')
            .select()
            .eq('phone_number', phone)
            .limit(1);

        if (existingUser.isEmpty) {
          throw Exception('This phone number is not registered');
        }

        // Get current stations for this user
        final user = existingUser[0];
        final stationsData = user['stations'];

        if (stationsData is String) {
          _currentStations = stationsData.isEmpty
              ? []
              : stationsData.split(',').map((s) => s.trim()).toList();
        } else if (stationsData is List) {
          _currentStations = List<String>.from(
            stationsData.map((s) => s.toString().trim()),
          );
        } else {
          _currentStations = [];
        }

        // Update UI to show current stations
        setState(() {
          for (var station in _currentStations) {
            if (_selectedStations.containsKey(station)) {
              _selectedStations[station] = true;
            }
          }
        });
      } catch (checkError) {
        throw checkError;
      }

      // Use OTP Service to send OTP
      await OTPService.sendOTP(phone);

      setState(() {
        _otpSent = true;
        _isResendDisabled = true;
        _resendCountdown = 60;
        _isSendingOTP = false;
        _isResendingOTP = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OTP sent to $phone'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );

      // Start countdown timer
      _startResendCountdown();
    } catch (error) {
      setState(() {
        _isSendingOTP = false;
        _isResendingOTP = false;
        _otpError = error.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_cleanErrorMessage(_otpError!)),
          duration: Duration(seconds: 3),
          backgroundColor: Colors.red,
        ),
      );

      print('Error sending OTP: $error');
    }
  }

  void _startResendCountdown() {
    Future.delayed(Duration(seconds: 1), () {
      if (mounted && _isResendDisabled) {
        setState(() {
          _resendCountdown--;
          if (_resendCountdown <= 0) {
            _isResendDisabled = false;
            _resendCountdown = 0;
          }
        });
        if (_isResendDisabled) {
          _startResendCountdown();
        }
      }
    });
  }

  void _resendOTP() {
    _sendOTP(isResend: true);
  }

  Widget _buildOTPInputField() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (index) {
        return SizedBox(
          width: 50,
          height: 60,
          child: TextField(
            enabled: _isPhoneValid && !_isLoading && !_updated,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            maxLength: 1,
            obscureText: true,
            onChanged: (value) {
              if (value.isNotEmpty) {
                _otpController.text += value;
                if (index < 5) {
                  FocusScope.of(context).nextFocus();
                }
              } else {
                if (_otpController.text.isNotEmpty) {
                  _otpController.text = _otpController.text.substring(
                    0,
                    _otpController.text.length - 1,
                  );
                }
                if (index > 0) {
                  FocusScope.of(context).previousFocus();
                }
              }
              setState(() {});
            },
            decoration: InputDecoration(
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Color(0xFF41BAF1), width: 2),
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        );
      }),
    );
  }

  Future<void> _updateStations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final phone = _phoneController.text.trim();
      final otp = _otpController.text.trim();

      if (phone.isEmpty) {
        throw Exception('Please enter your phone number');
      }

      if (otp.isEmpty || otp.length != 6) {
        throw Exception('Please enter a valid 6-digit OTP');
      }

      // Verify OTP using the service
      await OTPService.verifyOTP(phone, otp);

      // Get selected stations
      final selectedStations = _selectedStations.entries
          .where((entry) => entry.value)
          .map((entry) => entry.key)
          .toList();

      if (selectedStations.isEmpty) {
        throw Exception('Please select at least one station to monitor');
      }

      print('Selected stations: $selectedStations');

      // Check if user exists
      final existingUser = await Supabase.instance.client
          .from('users')
          .select()
          .eq('phone_number', phone)
          .limit(1);

      if (existingUser.isEmpty) {
        throw Exception('Phone number not found in our records');
      }

      // Update stations
      await Supabase.instance.client
          .from('users')
          .update({'stations': selectedStations.join(',')})
          .eq('phone_number', phone);

      setState(() {
        _isLoading = false;
        _updated = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully updated monitored stations'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Navigate back after 2 seconds
      await Future.delayed(Duration(seconds: 2));
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
        _error = error.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_error!),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );

      print('Error updating stations: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF1F4F8),
      appBar: AppBar(
        backgroundColor: Color(0xFF41BAF1),
        title: const Text(
          'Edit Monitored Station',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Monitored Stations',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Update the stations you want to monitor for flood alerts',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              SizedBox(height: 24),
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.blue.shade700,
                            size: 20,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Verify your phone number to update your monitored stations.',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),
                    Text(
                      'Phone Number',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.number,
                      maxLength: 11,
                      onChanged: _validatePhoneNumber,
                      enabled: !_isLoading && !_updated,
                      decoration: InputDecoration(
                        hintText: '09XXXXXXXXX',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        counterText: '${_phoneController.text.length}/11',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        errorText: _phoneWarning,
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.red),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.red, width: 2),
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'One Time Password (OTP)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 8),
                    _buildOTPInputField(),
                    SizedBox(height: 12),
                    // Send and Resend Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                !_isPhoneValid || _otpSent || _isSendingOTP
                                ? null
                                : _sendOTP,
                            icon: _isSendingOTP
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
                                : Icon(Icons.send),
                            label: Text(
                              _isSendingOTP ? 'Sending...' : 'Send OTP',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF41BAF1),
                              disabledBackgroundColor: Colors.grey.shade300,
                              padding: EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: !_otpSent || _isResendDisabled
                                ? null
                                : _resendOTP,
                            icon: _isResendingOTP
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
                                : Icon(Icons.refresh),
                            label: Text(
                              _isResendingOTP
                                  ? 'Resending...'
                                  : (_isResendDisabled
                                        ? 'Resend (${_resendCountdown}s)'
                                        : 'Resend OTP'),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF41BAF1),
                              disabledBackgroundColor: Colors.grey.shade300,
                              padding: EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    if (!_isPhoneValid)
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.amber.shade700,
                              size: 20,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Enter a valid phone number to enable OTP field',
                                style: TextStyle(
                                  color: Colors.amber.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_otpSent)
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green.shade700,
                              size: 20,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'OTP sent successfully. Select your stations below.',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_otpSent) ...[
                      SizedBox(height: 20),
                      Text(
                        'Select Stations to Monitor',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 8),
                      _isLoadingStations
                          ? Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : _stationError != null
                          ? Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Text(
                                _stationError!,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          : _stations.isEmpty
                          ? Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Text(
                                'No stations available',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                children: List.generate(_stations.length, (
                                  index,
                                ) {
                                  final station = _stations[index];
                                  final isLast = index == _stations.length - 1;
                                  return Column(
                                    children: [
                                      CheckboxListTile(
                                        value:
                                            _selectedStations[station] ?? false,
                                        onChanged: (bool? value) {
                                          setState(() {
                                            _selectedStations[station] =
                                                value ?? false;
                                          });
                                        },
                                        title: Text(station),
                                        controlAffinity:
                                            ListTileControlAffinity.leading,
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 0,
                                        ),
                                      ),
                                      if (!isLast) Divider(height: 1),
                                    ],
                                  );
                                }),
                              ),
                            ),
                      SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed:
                              _otpController.text.length == 6 &&
                                  !_isLoading &&
                                  !_updated
                              ? _updateStations
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF41BAF1),
                            disabledBackgroundColor: Colors.grey.shade300,
                            padding: EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  'Update Stations',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
