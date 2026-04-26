import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/metabolic_state.dart';
import '../theme/app_theme.dart';

const double _liverTargetPct = 70;
const double _muscleTargetPct = 75;

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
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              _targetLine(
                y: _liverTargetPct,
                color: AppTheme.teal,
                label: 'Liver target',
                labelAlignment: Alignment.bottomRight,
              ),
              _targetLine(
                y: _muscleTargetPct,
                color: AppTheme.amber,
                label: 'Muscle target',
                labelAlignment: Alignment.topRight,
              ),
            ],
          ),
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

  HorizontalLine _targetLine({
    required double y,
    required Color color,
    required String label,
    required Alignment labelAlignment,
  }) {
    return HorizontalLine(
      y: y,
      color: color.withAlpha(150),
      strokeWidth: 1.5,
      dashArray: const [7, 5],
      label: HorizontalLineLabel(
        show: true,
        alignment: labelAlignment,
        padding: const EdgeInsets.only(right: 4, bottom: 2),
        style: TextStyle(
          color: color.withAlpha(210),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
        labelResolver: (_) => label,
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
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _LegendItem.swatch(color: AppTheme.teal, label: 'Liver'),
        _LegendItem.swatch(color: AppTheme.amber, label: 'Muscle'),
        _LegendItem.swatch(color: AppTheme.coral, label: 'BG proxy'),
        _LegendItem.dashed(color: AppTheme.gray500, label: 'Targets'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool dashed;

  const _LegendItem.swatch({
    required this.color,
    required this.label,
  }) : dashed = false;

  const _LegendItem.dashed({
    required this.color,
    required this.label,
  }) : dashed = true;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dashed ? _dash(color) : _dot(color),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.gray600),
        ),
      ],
    );
  }

  Widget _dot(Color c) => Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      );

  Widget _dash(Color c) => SizedBox(
        width: 18,
        height: 10,
        child: CustomPaint(painter: _DashedLegendPainter(c)),
      );
}

class _DashedLegendPainter extends CustomPainter {
  final Color color;

  const _DashedLegendPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    const dashWidth = 5.0;
    const gapWidth = 3.0;
    var x = 0.0;
    final y = size.height / 2;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + dashWidth).clamp(0, size.width), y),
        paint,
      );
      x += dashWidth + gapWidth;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLegendPainter oldDelegate) =>
      oldDelegate.color != color;
}
