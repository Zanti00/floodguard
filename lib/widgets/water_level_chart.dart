import 'package:flutter/material.dart';

class WaterLevelChart extends StatelessWidget {
  final String waterLevel2HrsAgo;
  final String waterLevel1HrAgo;
  final String waterLevel30mAgo;
  final String waterLevelNow;

  const WaterLevelChart({
    super.key,
    required this.waterLevel2HrsAgo,
    required this.waterLevel1HrAgo,
    required this.waterLevel30mAgo,
    required this.waterLevelNow,
  });

  @override
  Widget build(BuildContext context) {
    // Parse water levels to doubles
    final level2HrsAgo = double.tryParse(waterLevel2HrsAgo) ?? 0.0;
    final level1HrAgo = double.tryParse(waterLevel1HrAgo) ?? 0.0;
    final level30mAgo = double.tryParse(waterLevel30mAgo) ?? 0.0;
    final levelNow = double.tryParse(waterLevelNow) ?? 0.0;

    // Find max value for Y-axis
    final allLevels = [level2HrsAgo, level1HrAgo, level30mAgo, levelNow];
    final maxLevel = allLevels.reduce((a, b) => a > b ? a : b);

    // Add some padding to max level for better visualization
    final yAxisMax = (maxLevel * 1.1).ceilToDouble();
    final yAxisMin = 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Water Level Trend',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _buildChart(allLevels, yAxisMin, yAxisMax),
        ],
      ),
    );
  }

  Widget _buildChart(List<double> levels, double minY, double maxY) {
    const timeLabels = ['2hrs ago', '1hr ago', '30m ago', 'Now'];
    const chartPadding = EdgeInsets.fromLTRB(60, 20, 20, 60);
    const chartHeight = 250.0;
    const chartWidth = 300.0;

    return Padding(
      padding: chartPadding,
      child: CustomPaint(
        size: Size(chartWidth, chartHeight),
        painter: LineChartPainter(
          levels: levels,
          minY: minY,
          maxY: maxY,
          timeLabels: timeLabels,
        ),
      ),
    );
  }
}

class LineChartPainter extends CustomPainter {
  final List<double> levels;
  final double minY;
  final double maxY;
  final List<String> timeLabels;

  LineChartPainter({
    required this.levels,
    required this.minY,
    required this.maxY,
    required this.timeLabels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // Draw grid lines and Y-axis labels
    _drawYAxisAndGridLines(canvas, size);

    // Draw X-axis and labels
    _drawXAxisAndLabels(canvas, size);

    // Calculate positions for data points
    final points = <Offset>[];
    final xStep = width / (levels.length - 1);
    final yRange = maxY - minY;

    for (int i = 0; i < levels.length; i++) {
      final x = i * xStep;
      final normalizedY = (levels[i] - minY) / yRange;
      final y = height - (normalizedY * height);
      points.add(Offset(x, y));
    }

    // Draw line connecting points
    if (points.length > 1) {
      final linePaint = Paint()
        ..color = const Color(0xFF41BAF1)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      for (int i = 0; i < points.length - 1; i++) {
        canvas.drawLine(points[i], points[i + 1], linePaint);
      }
    }

    // Draw circles at data points
    final circlePaint = Paint()
      ..color = const Color(0xFF41BAF1)
      ..style = PaintingStyle.fill;

    final circleStrokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (final point in points) {
      canvas.drawCircle(point, 6, circlePaint);
      canvas.drawCircle(point, 6, circleStrokePaint);
    }
  }

  void _drawYAxisAndGridLines(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final yRange = maxY - minY;
    final gridLineCount = 5;

    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..strokeWidth = 1;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i <= gridLineCount; i++) {
      final normalizedValue = i / gridLineCount;
      final value = minY + (normalizedValue * yRange);
      final y = height - (normalizedValue * height);

      // Draw grid line
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);

      // Draw Y-axis label
      textPainter.text = TextSpan(
        text: '${value.toStringAsFixed(0)}m',
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(-50, y - 6));
    }
  }

  void _drawXAxisAndLabels(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final xStep = width / (timeLabels.length - 1);

    final axisPaint = Paint()
      ..color = Colors.black54
      ..strokeWidth = 1;

    canvas.drawLine(Offset(0, height), Offset(width, height), axisPaint);

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < timeLabels.length; i++) {
      final x = i * xStep;

      textPainter.text = TextSpan(
        text: timeLabels[i],
        style: const TextStyle(
          color: Colors.black54,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, height + 10));
    }
  }

  @override
  bool shouldRepaint(LineChartPainter oldDelegate) {
    return oldDelegate.levels != levels;
  }
}
