import 'package:flutter/material.dart';
import 'dart:math' as math;

class AnimatedWaterLevel extends StatefulWidget {
  final double waterLevel; // Current water level value
  final double? maxLevel; // Critical water level (max)
  final String alarmStatus;

  const AnimatedWaterLevel({
    super.key,
    required this.waterLevel,
    this.maxLevel,
    required this.alarmStatus,
  });

  @override
  State<AnimatedWaterLevel> createState() => _AnimatedWaterLevelState();
}

class _AnimatedWaterLevelState extends State<AnimatedWaterLevel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _waveAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();

    _waveAnimation = Tween<double>(
      begin: 0,
      end: 2 * 3.14159265359,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getWaterColor(String alarmStatus) {
    // Always return blue for water color
    return Color(0xFF41BAF1);
  }

  @override
  Widget build(BuildContext context) {
    double levelPercentage = 0;
    if (widget.maxLevel != null && widget.maxLevel! > 0) {
      levelPercentage = (widget.waterLevel / widget.maxLevel!) * 100;
      if (levelPercentage > 100) levelPercentage = 100;
    }

    return Container(
      margin: EdgeInsets.fromLTRB(20, 20, 20, 20),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Water Level Visualization',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Center(
            child: Container(
              width: 200,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!, width: 2),
                borderRadius: BorderRadius.circular(8),
                color: Color(0xFFF5F5F5),
              ),
              child: Stack(
                children: [
                  // Water wave animation
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: AnimatedBuilder(
                      animation: _waveAnimation,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: WavePainter(
                            wavePhase: _waveAnimation.value,
                            waterLevel: levelPercentage,
                            waterColor: _getWaterColor(widget.alarmStatus),
                          ),
                          size: Size(200, 250),
                        );
                      },
                    ),
                  ),
                  // Water level percentage text
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${levelPercentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '${widget.waterLevel.toStringAsFixed(2)} m',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(0xFFF1F4F8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatusInfo('Status', widget.alarmStatus),
                if (widget.maxLevel != null)
                  _buildStatusInfo(
                    'Critical Level',
                    '${widget.maxLevel?.toStringAsFixed(2)} m',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusInfo(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class WavePainter extends CustomPainter {
  final double wavePhase;
  final double waterLevel;
  final Color waterColor;

  WavePainter({
    required this.wavePhase,
    required this.waterLevel,
    required this.waterColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = waterColor.withOpacity(0.8);
    final borderPaint = Paint()
      ..color = waterColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Calculate water height based on waterLevel percentage
    final waterHeight = (size.height * (100 - waterLevel)) / 100;

    // Draw water with wave effect
    Path path = Path();
    path.moveTo(0, waterHeight);

    // Create wave path
    for (double i = 0; i <= size.width; i++) {
      final wave =
          5 * math.sin((i / size.width * 2 * 3.14159265359) + wavePhase);
      final y = waterHeight - wave;
      path.lineTo(i, y);
    }

    // Complete the path
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    // Draw water fill
    canvas.drawPath(path, paint);

    // Draw wave border
    Path borderPath = Path();
    borderPath.moveTo(0, waterHeight);
    for (double i = 0; i <= size.width; i++) {
      final wave =
          5 * math.sin((i / size.width * 2 * 3.14159265359) + wavePhase);
      final y = waterHeight - wave;
      borderPath.lineTo(i, y);
    }

    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) {
    return oldDelegate.wavePhase != wavePhase ||
        oldDelegate.waterLevel != waterLevel;
  }
}
