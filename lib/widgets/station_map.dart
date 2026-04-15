import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class StationMap extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String stationName;
  final String alarmStatus;

  const StationMap({
    Key? key,
    required this.latitude,
    required this.longitude,
    required this.stationName,
    required this.alarmStatus,
  }) : super(key: key);

  @override
  State<StationMap> createState() => _StationMapState();
}

class _StationMapState extends State<StationMap> {
  final MapController _mapController = MapController();

  @override
  void didUpdateWidget(covariant StationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When the selected station changes, move the map center!
    if (oldWidget.latitude != widget.latitude ||
        oldWidget.longitude != widget.longitude) {
      _mapController.move(LatLng(widget.latitude, widget.longitude), 15.0);
    }
  }

  Color _getMarkerColor() {
    switch (widget.alarmStatus) {
      case 'Critical Level':
        return Colors.red;
      case 'Alarm Level':
        return Colors.orange;
      case 'Alert Level':
        return Colors.yellow;
      case 'Normal':
        return Colors.green;
      default:
        return Colors.blue; // Default fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLatLng = LatLng(widget.latitude, widget.longitude);

    return Container(
      height: 300,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // Clip map corners to our box decoration
      clipBehavior: Clip.hardEdge, 
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: currentLatLng,
          initialZoom: 15.0,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate, 
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.floodguard',
          ),
          MarkerLayer(
            markers: [
              Marker(
                point: currentLatLng,
                width: 120, // Wide enough to hold text if needed
                height: 60,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        widget.stationName,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.location_on,
                      color: _getMarkerColor(),
                      size: 40,
                      shadows: [
                        Shadow( // To give the pin some depth
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
