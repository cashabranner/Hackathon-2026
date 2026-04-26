import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/metabolic_state.dart';
import '../theme/app_theme.dart';

class GlycogenChart extends StatelessWidget {
  final List<GlycogenPoint> curve;
  final double liverCapacity;
  final double muscleCapacity;

  const GlycogenChart({
    super.key,
    required this.curve,
    required this.liverCapacity,
    required this.muscleCapacity,
  });

  @override
  Widget build(BuildContext context) {
    if (curve.isEmpty) {
      return const SizedBox(
        height: 180,
        child: Center(child: Text('No data yet')),
      );
    }

    final startMs = curve.first.time.millisecondsSinceEpoch.toDouble();

    List<FlSpot> liverSpots = [];
    List<FlSpot> muscleSpots = [];
    List<FlSpot> bgSpots = [];

    for (final p in curve) {
      final x =
          (p.time.millisecondsSinceEpoch - startMs) / (1000 * 60 * 60); // hours
      liverSpots.add(FlSpot(x, p.liverGlycogenG / liverCapacity * 100));
      muscleSpots.add(FlSpot(x, p.muscleGlycogenG / muscleCapacity * 100));
      bgSpots.add(FlSpot(x, p.bloodGlucoseProxy));
    }

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: AppTheme.gray200, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: 25,
                getTitlesWidget: (v, _) => Text('${v.round()}%',
                    style:
                        const TextStyle(fontSize: 10, color: AppTheme.gray500)),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (v, _) {
                  final time = curve.first.time
                      .add(Duration(seconds: (v * 3600).round()));
                  return Text(
                    DateFormat('ha').format(time).toLowerCase(),
                    style:
                        const TextStyle(fontSize: 10, color: AppTheme.gray500),
                  );
                },
              ),
            ),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            _line(liverSpots, AppTheme.teal, 'Liver'),
            _line(muscleSpots, AppTheme.amber, 'Muscle'),
            _line(bgSpots, AppTheme.coral, 'BG proxy'),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((s) {
                const labels = ['Liver', 'Muscle', 'BG'];
                return LineTooltipItem(
                  '${labels[s.barIndex]}: ${s.y.round()}%',
                  const TextStyle(color: Colors.white, fontSize: 12),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  LineChartBarData _line(List<FlSpot> spots, Color color, String label) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 2.5,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: true,
        color: color.withAlpha(30),
      ),
    );
  }
}

class GlycogenLegend extends StatelessWidget {
  const GlycogenLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _dot(AppTheme.teal),
        const SizedBox(width: 4),
        const Text('Liver',
            style: TextStyle(fontSize: 12, color: AppTheme.gray600)),
        const SizedBox(width: 16),
        _dot(AppTheme.amber),
        const SizedBox(width: 4),
        const Text('Muscle',
            style: TextStyle(fontSize: 12, color: AppTheme.gray600)),
        const SizedBox(width: 16),
        _dot(AppTheme.coral),
        const SizedBox(width: 4),
        const Text('BG proxy',
            style: TextStyle(fontSize: 12, color: AppTheme.gray600)),
      ],
    );
  }

  Widget _dot(Color c) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );
}
