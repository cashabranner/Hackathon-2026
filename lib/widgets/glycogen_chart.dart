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
            _line(bgSpots, AppTheme.coral, 'Body Glucose'),
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
        _LegendItem.swatch(
          color: AppTheme.teal,
          label: 'Liver',
          info: _MetricInfo.liver,
        ),
        _LegendItem.swatch(
          color: AppTheme.amber,
          label: 'Muscle',
          info: _MetricInfo.muscle,
        ),
        _LegendItem.swatch(
          color: AppTheme.coral,
          label: 'Body Glucose',
          info: _MetricInfo.bgProxy,
        ),
        _LegendItem.dashed(color: AppTheme.gray500, label: 'Targets'),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool dashed;
  final _MetricInfo? info;

  const _LegendItem.swatch({
    required this.color,
    required this.label,
    this.info,
  }) : dashed = false;

  const _LegendItem.dashed({
    required this.color,
    required this.label,
  })  : dashed = true,
        info = null;

  @override
  Widget build(BuildContext context) {
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        dashed ? _dash(color) : _dot(color),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.gray600),
        ),
        if (info != null) ...[
          const SizedBox(width: 3),
          Icon(Icons.info_outline, size: 12, color: color),
        ],
      ],
    );

    if (info == null) return content;

    return InkWell(
      onTap: () => _showMetricInfo(context, info!),
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: content,
      ),
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

  void _showMetricInfo(BuildContext context, _MetricInfo info) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withAlpha(28),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(info.icon, color: color, size: 19),
                ),
                const SizedBox(width: 10),
                Text(
                  info.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              info.body,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            Text(
              info.hint,
              style: const TextStyle(
                color: AppTheme.gray500,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricInfo {
  final String title;
  final String body;
  final String hint;
  final IconData icon;

  const _MetricInfo({
    required this.title,
    required this.body,
    required this.hint,
    required this.icon,
  });

  static const liver = _MetricInfo(
    title: 'Liver Glycogen',
    body:
        'Liver glycogen is stored carbohydrate that helps keep blood glucose steady between meals and during training. It is a smaller tank than muscle glycogen and can drop quickly overnight or during long sessions.',
    hint:
        'Higher liver stores usually mean steadier energy and fewer fasted-session dips.',
    icon: Icons.water_drop_outlined,
  );

  static const muscle = _MetricInfo(
    title: 'Muscle Glycogen',
    body:
        'Muscle glycogen is stored carbohydrate inside working muscle. It is the main fuel reserve for lifting, sprinting, intervals, and other high-intensity work.',
    hint:
        'If this line is low before a hard session, carbs 1-3 hours before training become more important.',
    icon: Icons.fitness_center,
  );

  static const bgProxy = _MetricInfo(
    title: 'Body Glucose',
    body:
        'Body Glucose is a simplified 0-100 estimate of blood-glucose availability, not a medical glucose reading. It rises after meals and trends lower during fasting or exercise.',
    hint:
        'Use it as a trend signal for fueling timing, not as a clinical blood sugar value.',
    icon: Icons.monitor_heart_outlined,
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
