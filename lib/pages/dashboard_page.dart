// import 'dart:nativewrappers/_internal/vm/lib/ffi_native_type_patch.dart';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardState();
}

class _DashboardState extends State<DashboardPage> {
  String? selectedValue;
  List<String> items = [];
  List<dynamic> _water_level = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    fetchWaterLevel();
  }

  Future<void> fetchWaterLevel() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final response = await Supabase.instance.client
          .from('water_levels')
          .select();

      setState(() {
        _water_level = response;
        _isLoading = false;
        _addDropDownItem(_water_level);
      });
    } catch (error) {
      setState(() {
        _errorMessage = 'Error loading data: $error';
        _isLoading = false;
      });
      print('An error has occurred: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF1F4F8),
      appBar: AppBar(
        backgroundColor: Color(0xFF41BAF1),
        title: const Text(
          'Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 25),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_errorMessage!),
                  SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: fetchWaterLevel,
                    child: Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: fetchWaterLevel,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: Column(
                  spacing: 12,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            top: 20,
                            left: 20,
                            right: 20,
                          ),
                          child: Text(
                            selectedValue ?? 'Location',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _water_level.isNotEmpty
                                  ? _formatTimestamp(
                                      _water_level.first['timestamp'],
                                    )
                                  : 'No data',
                              overflow: TextOverflow.visible,
                            ),
                          ),
                          const SizedBox(width: 50),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedValue,
                                items: items.map((String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                                onChanged: items.isEmpty
                                    ? null
                                    : (String? newValue) {
                                        setState(() {
                                          selectedValue = newValue;
                                        });
                                      },
                                dropdownColor: Colors.white,
                                icon: const Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.black,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: Column(
                        spacing: 12,
                        children: [
                          _buildDataRow(
                            _getWaterLevelForStation('water_level'),
                            'Current',
                            35,
                            _getAlarmLevelForStation('water_level'),
                          ),
                          _buildDataRow(
                            _getWaterLevelForStation('water_level_30_m'),
                            '30 minutes ago',
                            23,
                            _getAlarmLevelForStation('water_level_30_m'),
                          ),
                          _buildDataRow(
                            _getWaterLevelForStation('water_level_1_h'),
                            '1 hour ago',
                            40,
                            _getAlarmLevelForStation('water_level_1_h'),
                          ),
                          _buildDataRow(
                            _getWaterLevelForStation('water_level_2_h'),
                            '2 hours ago',
                            36,
                            _getAlarmLevelForStation('water_level_2_h'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    try {
      final dateTime = timestamp is String
          ? DateTime.parse(timestamp)
          : timestamp as DateTime;
      final formatter = DateFormat('MMMM dd, yyyy h:mm');
      return formatter.format(dateTime);
    } catch (e) {
      return timestamp.toString();
    }
  }

  void _addDropDownItem(dynamic _water_level) {
    final uniqueStations = <String>{};
    for (var entry in _water_level) {
      uniqueStations.add(entry['station_name']);
    }
    items = uniqueStations.toList();
    // Set the first station as the default selected value
    if (items.isNotEmpty && selectedValue == null) {
      selectedValue = items.first;
    }
  }

  String _getWaterLevelForStation(String fieldName) {
    if (selectedValue == null || _water_level.isEmpty) {
      return '0.00';
    }
    try {
      for (var entry in _water_level) {
        if (entry['station_name'] == selectedValue) {
          final level = entry[fieldName];
          if (level != null) {
            return _cleanWaterLevel(level.toString());
          }
        }
      }
    } catch (e) {
      print('Error getting $fieldName: $e');
    }
    return '0.00';
  }

  String _getAlarmLevelForStation(String fieldName) {
    if (selectedValue == null || _water_level.isEmpty) {
      return 'No data';
    }
    try {
      for (var entry in _water_level) {
        if (entry['station_name'] == selectedValue) {
          final currentLevel = entry[fieldName];
          final criticalLevel = entry['critical_water_level'];
          final alertLevel = entry['alert_water_level'];
          final alarmLevel = entry['alarm_water_level'];

          if (currentLevel != null) {
            final current =
                double.tryParse(_cleanWaterLevel(currentLevel.toString())) ??
                0.0;
            final critical =
                double.tryParse(
                  _cleanWaterLevel(criticalLevel?.toString() ?? '0'),
                ) ??
                0.0;
            final alert =
                double.tryParse(
                  _cleanWaterLevel(alertLevel?.toString() ?? '0'),
                ) ??
                0.0;
            final alarm =
                double.tryParse(
                  _cleanWaterLevel(alarmLevel?.toString() ?? '0'),
                ) ??
                0.0;

            if (current > critical) {
              return 'Critical Level';
            } else if (current > alert) {
              return 'Alert Level';
            } else if (current > alarm) {
              return 'Alarm Level';
            } else {
              return 'Normal';
            }
          }
        }
      }
    } catch (e) {
      print("Error getting alarm level for $fieldName: $e");
    }
    return 'No data';
  }

  String _cleanWaterLevel(String value) {
    return value.replaceAll(RegExp(r'\(\*\)'), '');
  }

  Color _getAlarmColor(String alarmLevel) {
    switch (alarmLevel) {
      case 'Critical Level':
        return Color(0xFFD32F2F); // Dark red
      case 'Alarm Level':
        return Color(0xFFF57C00); // Dark orange
      case 'Alert Level':
        return Color(0xFFFBC02D); // Dark yellow
      case 'Normal':
        return Color(0xFF388E3C); // Dark green
      default:
        return Color(0xFF9E9E9E); // Grey
    }
  }

  Color _getAlarmLabelColor(String value) {
    switch (value) {
      case 'Critical Level':
        return Colors.red;
      case 'Alarm Level':
        return Colors.orange;
      case 'Alert Level':
        return Colors.yellow;
      case 'Normal':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildDataRow(
    String value,
    String label,
    double leftPadding,
    String alarmLevel,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: _getAlarmColor(alarmLevel),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(leftPadding, 20, 20, 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: label == 'Current' ? 34 : 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(label, style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getAlarmLabelColor(alarmLevel),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    alarmLevel,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
