import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../../features/progress/domain/parent_analytics_model.dart';

class WeeklySessionsChart extends StatelessWidget {
  const WeeklySessionsChart({
    required this.dataPoints,
    this.lineColor = AppColors.primary,
    this.height = 180,
    super.key,
  });

  final List<WeeklyDataPoint> dataPoints;
  final Color lineColor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final points = dataPoints;
    final allZero = points.isEmpty || points.every((p) => p.sessionCount == 0);
    if (allZero) {
      return SizedBox(
        height: height,
        child: const Center(child: Text('Aucune session cette période')),
      );
    }

    final maxY = points.map((e) => e.sessionCount.toDouble()).reduce((a, b) => a > b ? a : b);
    final safeMaxY = (maxY < 1 ? 1.0 : maxY) + 1.0;

    final spots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      spots.add(FlSpot(i.toDouble(), points[i].sessionCount.toDouble()));
    }

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: safeMaxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (_) => const FlLine(
              color: AppColors.grey200,
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  if (value % 1 != 0) return const SizedBox.shrink();
                  return Text(value.toInt().toString(), style: const TextStyle(fontSize: 11));
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= points.length) return const SizedBox.shrink();
                  final fromEnd = points.length - 1 - index;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('S-$fromEnd', style: const TextStyle(fontSize: 11)),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots
                    .map((spot) => LineTooltipItem(
                          '${spot.y.toInt()} session(s)',
                          const TextStyle(color: Colors.white),
                        ))
                    .toList();
              },
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: lineColor,
              barWidth: 2.5,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                color: lineColor.withValues(alpha: 0.08),
              ),
            ),
          ],
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}
