import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

class WaterLevelChart extends StatelessWidget {
  final List<dynamic> hourlyData;

  const WaterLevelChart({
    super.key,
    required this.hourlyData,
  });

  @override
  Widget build(BuildContext context) {
    if (hourlyData.isEmpty) {
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
              'Water Level Trend (24h)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 60),
            const Center(child: Text('No historical data available')),
            const SizedBox(height: 60),
          ],
        ),
      );
    }

    // Sort chronologically (oldest to newest)
    final sortedData = List<dynamic>.from(hourlyData)
      ..sort((a, b) {
        final dateA = DateTime.tryParse(a['hour_bucket'].toString()) ?? DateTime.now();
        final dateB = DateTime.tryParse(b['hour_bucket'].toString()) ?? DateTime.now();
        return dateA.compareTo(dateB);
      });

    final fixedLevels = <double>[0.0, 0.0, 0.0, 0.0];
    bool hasData = false;

    // Get the most recent value for each specific hour of the fixed axis
    for (var entry in sortedData) {
      final date = DateTime.tryParse(entry['hour_bucket'].toString())?.toLocal();
      if (date != null) {
        final level = double.tryParse(entry['avg_level_m'].toString()) ?? 0.0;
        if (date.hour == 0) { fixedLevels[0] = level; hasData = true; }
        else if (date.hour == 6) { fixedLevels[1] = level; hasData = true; }
        else if (date.hour == 12) { fixedLevels[2] = level; hasData = true; }
        else if (date.hour == 18) { fixedLevels[3] = level; hasData = true; }
      }
    }

    final levels = fixedLevels;
    final timeLabels = ['12AM', '6AM', '12PM', '6PM'];

    // Find max value for Y-axis
    final maxLevel = hasData ? levels.reduce((a, b) => a > b ? a : b) : 0.0;

    // Add some padding to max level for better visualization
    final yAxisMax = (maxLevel * 1.1).ceilToDouble();
    final yAxisMin = 0.0;
    final finalYAxisMax = yAxisMax > 0 ? yAxisMax : 1.0;

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
            'Water Level Trend (24h)',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _buildChart(levels, yAxisMin, finalYAxisMax, timeLabels),
        ],
      ),
    );
  }

  Widget _buildChart(List<double> levels, double minY, double maxY, List<String> timeLabels) {
    const chartPadding = EdgeInsets.fromLTRB(60, 20, 20, 60);
    const chartHeight = 250.0;
    const chartWidth = 300.0;

    return Padding(
      padding: chartPadding,
      child: CustomPaint(
        size: const Size(chartWidth, chartHeight),
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

    if (levels.isEmpty) return;

    // Calculate positions for data points
    final points = <Offset>[];
    final xStep = levels.length > 1 ? width / (levels.length - 1) : width;
    final yRange = maxY - minY;

    if (yRange <= 0) return;

    for (int i = 0; i < levels.length; i++) {
      final x = levels.length == 1 ? width / 2 : i * xStep;
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
    // Reduce size if there are many points
    final radius = levels.length > 10 ? 3.0 : 6.0;
    final circlePaint = Paint()
      ..color = const Color(0xFF41BAF1)
      ..style = PaintingStyle.fill;

    final circleStrokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = levels.length > 10 ? 1 : 2;

    for (final point in points) {
      canvas.drawCircle(point, radius, circlePaint);
      if (levels.length <= 10 || levels.length > 10) {
        canvas.drawCircle(point, radius, circleStrokePaint);
      }
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
      textPainter.paint(canvas, Offset(-45, y - 6));
    }
  }

  void _drawXAxisAndLabels(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final xStep = timeLabels.length > 1 ? width / (timeLabels.length - 1) : width;

    final axisPaint = Paint()
      ..color = Colors.black54
      ..strokeWidth = 1;

    canvas.drawLine(Offset(0, height), Offset(width, height), axisPaint);

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < timeLabels.length; i++) {
      if (timeLabels[i].isEmpty) continue;

      final x = timeLabels.length == 1 ? width / 2 : i * xStep;

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
    return oldDelegate.levels != levels || oldDelegate.timeLabels != timeLabels;
  }
}
