import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class HotlinePage extends StatefulWidget {
  final bool showAppBar;

  const HotlinePage({super.key, this.showAppBar = true});

  @override
  State<HotlinePage> createState() => _HotlinePageState();
}

class _HotlinePageState extends State<HotlinePage> {
  late Map<String, dynamic> hotlineData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHotlineData();
  }

  Future<void> _loadHotlineData() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/data/hotline.json',
      );
      setState(() {
        hotlineData = jsonDecode(response);
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading hotline data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _makeCall(String phoneNumber) async {
    // Remove any special characters except digits and + for international format
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri launchUri = Uri(scheme: 'tel', path: cleanNumber);

    try {
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not launch phone call')));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _isLoading
        ? Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.showAppBar)
                    Padding(
                      padding: EdgeInsets.only(bottom: 20),
                      child: Text(
                        'Hotlines & Contacts',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  _buildCategorySection('Emergency', hotlineData['general']),
                  SizedBox(height: 16),
                  _buildCategorySection('Police', hotlineData['police']),
                  SizedBox(height: 16),
                  _buildCategorySection('Fire', hotlineData['fire']),
                  SizedBox(height: 16),
                  _buildCategorySection('Medical', hotlineData['medical']),
                  SizedBox(height: 16),
                  _buildCategorySection(
                    'Rescue & Disaster',
                    hotlineData['rescue_disaster'],
                  ),
                  SizedBox(height: 16),
                  _buildCategorySection('Weather', hotlineData['weather']),
                  SizedBox(height: 16),
                  _buildCategorySection(
                    'Earthquake & Seismic',
                    hotlineData['earthquake_seismic'],
                  ),
                  SizedBox(height: 16),
                  _buildCategorySection('Traffic', hotlineData['traffic']),
                  SizedBox(height: 20),
                ],
              ),
            ),
          );

    if (widget.showAppBar) {
      return Scaffold(
        backgroundColor: Color(0xFFF1F4F8),
        appBar: AppBar(
          backgroundColor: Color(0xFF41BAF1),
          title: const Text(
            'Hotlines & Contacts',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: body,
      );
    } else {
      return body;
    }
  }

  Widget _buildCategorySection(String title, List<dynamic>? organizations) {
    if (organizations == null || organizations.isEmpty) {
      return SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12),
        ...organizations.map((org) => _buildOrganizationCard(org)).toList(),
      ],
    );
  }

  Widget _buildOrganizationCard(dynamic organization) {
    final name = organization['name'] ?? 'Unknown';
    final abbreviation = organization['abbreviation'];
    final hotlines = organization['hotlines'] as List<dynamic>? ?? [];

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (abbreviation != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFF41BAF1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    abbreviation,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (abbreviation != null) SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          ...hotlines.map((hotline) => _buildHotlineItem(hotline)).toList(),
        ],
      ),
    );
  }

  Widget _buildHotlineItem(dynamic hotline) {
    final number = hotline['number'] ?? 'Unknown';
    final range = hotline['range'];
    final locationCode = hotline['location_code'];

    return GestureDetector(
      onTap: () => _makeCall(number),
      child: Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: Color(0xFFF1F4F8),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Icon(Icons.phone, color: Color(0xFF41BAF1), size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      number,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF41BAF1),
                      ),
                    ),
                    if (range != null || locationCode != null)
                      Text(
                        '${range != null ? 'Ext. $range' : ''}${range != null && locationCode != null ? ' • ' : ''}${locationCode ?? ''}',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
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
}
