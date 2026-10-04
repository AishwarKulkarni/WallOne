import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:wallone/features/investments/providers/investment_provider.dart';
import 'package:wallone/core/utils/constants.dart';

class InvestmentChart extends StatelessWidget {
  final double screenWidth;

  const InvestmentChart({
    super.key,
    required this.screenWidth,
  });

  /// Builds FlSpots from the history list, injecting a Brownian bridge (random walk)
  /// between each real data point. This simulates a realistic, zigzagging stock market
  /// chart even when data is sparse (e.g., only a few months or skipped months).
  List<FlSpot> _buildZigzagSpots(List<double> history, List<bool> skippedSegments) {
    if (history.isEmpty) return [];
    if (history.length == 1) {
      return [FlSpot(0, history.first), FlSpot(1, history.first)];
    }

    final globalMax = history.reduce(math.max);

    final spots = <FlSpot>[];
    const int stepsPerSegment = 15; // Number of zigzags between months
    
    // Fixed seed ensures the generated zigzags remain completely stable across rebuilds.
    // It also ensures historical months keep their exact shape as new months are added.
    final random = math.Random(42);

    for (int i = 0; i < history.length - 1; i++) {
      final y1 = history[i];
      final y2 = history[i + 1];
      final isSkipped = skippedSegments[i];
      
      spots.add(FlSpot(i.toDouble(), y1));

      // Generate a random walk
      List<double> walk = [0.0];
      double currentWalk = 0.0;
      for (int s = 1; s <= stepsPerSegment; s++) {
        currentWalk += (random.nextDouble() - 0.5);
        walk.add(currentWalk);
      }
      
      final walkEnd = walk.last;
      final avg = (y1 + y2) / 2;
      
      // Amplitude of the zigzags: roughly 5% of the value.
      final amplitude = avg == 0 ? 50.0 : avg * 0.05; 
      
      for (int s = 1; s < stepsPerSegment; s++) {
        final t = s / stepsPerSegment;
        final x = i.toDouble() + t;
        
        // Linear baseline between the two real months
        double baseline = y1 + (y2 - y1) * t;
        
        // If it's a skipped month, apply a U-shape downward dip (parabola)
        if (isSkipped && y1 > 0) {
           final dipMagnitude = y1 * 0.15; // 15% visual drop
           final sag = dipMagnitude * 4 * t * (1 - t);
           baseline -= sag;
        }
        
        // Brownian bridge: tie the random walk down so it ends exactly at 0 offset
        final bridge = walk[s] - (walkEnd * t);
        
        // Apply the bridge noise to the baseline
        final finalY = baseline + (bridge * amplitude * 1.5);
        
        // Clamp top to globalMax so we don't overshoot all-time high with noise
        // Do NOT clamp bottom so the dip can be fully visible below historical lows!
        spots.add(FlSpot(x, math.max(0.0, math.min(finalY, globalMax))));
      }
    }
    // Ensure the final point perfectly matches the real history
    spots.add(FlSpot((history.length - 1).toDouble(), history.last));
    return spots;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<InvestmentProvider>(context);
    final sw = screenWidth;

    // Get transactions and sort by date ascending
    final transactions = provider.investmentTransactions.toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    // If there are no investments at all, show empty state
    if (provider.investments.isEmpty && transactions.isEmpty) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: boxColor(context),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFF4C1D95).withValues(alpha: 0.12),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4C1D95).withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.show_chart_rounded,
                  size: 38,
                  color: const Color(0xFF7C3AED).withValues(alpha: 0.35)),
              const SizedBox(height: 8),
              Text(
                'No investment data',
                style: GoogleFonts.outfit(
                  fontSize: sw / 34,
                  color: const Color(0xFF4C1D95).withValues(alpha: 0.4),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Process transactions into a monthly history
    List<double> history = [];
    List<bool> skippedSegments = [];
    double finalCumulative = 0;
    
    // Check if the user has any recurring investments to warrant a "downfall"
    final hasRecurring = provider.investments.any((inv) => inv.isOneTime != true);

    if (transactions.isNotEmpty) {
      final firstTx = transactions.first;
      final lastTx = transactions.last;

      int startYear = firstTx.date.year;
      int startMonth = firstTx.date.month;
      int endYear = lastTx.date.year;
      int endMonth = lastTx.date.month;

      // Group amounts by year-month
      final monthlyAmounts = <String, double>{};
      for (final tx in transactions) {
        final key = '${tx.date.year}-${tx.date.month}';
        monthlyAmounts[key] = (monthlyAmounts[key] ?? 0) + tx.amount;
      }

      double cumulative = 0;
      int currY = startYear;
      int currM = startMonth;

      // Extend to current date so skipped current months are visible
      final now = DateTime.now();
      if (endYear < now.year || (endYear == now.year && endMonth < now.month)) {
        endYear = now.year;
        endMonth = now.month;
      }

      // Iterate through every single month from start to end, inserting gaps naturally
      while (currY < endYear || (currY == endYear && currM <= endMonth)) {
        final key = '$currY-$currM';
        if (monthlyAmounts.containsKey(key)) {
          cumulative += monthlyAmounts[key]!;
          if (history.isNotEmpty) {
             skippedSegments.add(false);
          }
        } else {
          if (history.isNotEmpty) {
             skippedSegments.add(hasRecurring);
          }
        }
        // Using cumulative produces the continuous "waves" (S-curves) going upwards
        history.add(cumulative);

        currM++;
        if (currM > 12) {
          currM = 1;
          currY++;
        }
      }
      finalCumulative = cumulative;
    }

    // Build spots from history using our zigzag generator
    List<FlSpot> spots;
    if (history.isNotEmpty) {
      spots = _buildZigzagSpots(history, skippedSegments);
    } else {
      spots = [const FlSpot(0, 0), const FlSpot(1, 0)];
    }

    double minY = spots.map((s) => s.y).reduce(math.min);
    double maxY = spots.map((s) => s.y).reduce(math.max);
    double minX = 0;
    double maxX = spots.last.x;

    if (maxX == 0) maxX = 1.0;

    // Add padding to Y axis
    final yRange = (maxY - minY).abs();
    final yBuffer =
        yRange == 0 ? (maxY == 0 ? 100.0 : maxY * 0.15) : yRange * 0.25;
    final finalMinY = minY < 0 ? minY - yBuffer : math.max(0.0, minY - yBuffer);
    final finalMaxY = maxY + yBuffer;

    final xBuffer = maxX * 0.05;
    final finalMinX = minX - xBuffer;
    final finalMaxX = maxX + xBuffer;

    // Calculate the TRUE historical min and max so the dashed lines/dots don't move 
    // to the bottom of the artificial visual dip.
    final trueMinY = history.isNotEmpty ? history.reduce(math.min) : 0.0;
    final trueMaxY = history.isNotEmpty ? history.reduce(math.max) : 0.0;

    // We hardcode the colors to match the dark premium image requested
    const Color stroke = Colors.white;
    const Color glowMid = Color(0xFFE6EE9C); // Pale yellow for min/max
    const Color bgLight = Color(0xFF19191B); // Dark background

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildChartCard(
          context: context,
          spots: spots,
          stroke: stroke,
          glowMid: glowMid,
          bgLight: bgLight,
          screenWidth: sw,
          minX: finalMinX,
          maxX: finalMaxX,
          minY: finalMinY,
          maxY: finalMaxY,
          dataMinY: trueMinY,
          dataMaxY: trueMaxY,
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () {
            provider.simulateInvestmentDeduction();
          },
          icon: Icon(
            Icons.fast_forward_rounded,
            size: 20,
            color: inversePrimaryColor(context),
          ),
          label: Text(
            'Simulate Next Month',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: inversePrimaryColor(context),
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor(context),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildChartCard({
    required BuildContext context,
    required List<FlSpot> spots,
    required Color stroke,
    required Color glowMid,
    required Color bgLight,
    required double screenWidth,
    required double minX,
    required double maxX,
    required double minY,
    required double maxY,
    required double dataMinY,
    required double dataMaxY,
  }) {
    String formatCurrency(double value) {
      return '\$${value.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
    }

    const titlesData = FlTitlesData(
      show: true,
      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: bgLight,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.only(top: 36, bottom: 28, left: 0, right: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 188,
            child: LineChart(
              LineChartData(
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchSpotThreshold: 44,
                  getTouchedSpotIndicator: (barData, idxs) => idxs.map((idx) {
                    return TouchedSpotIndicatorData(
                      FlLine(
                        color: stroke.withValues(alpha: 0.35),
                        strokeWidth: 1.5,
                        dashArray: [5, 5],
                      ),
                      FlDotData(
                        getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                          radius: 5,
                          color: stroke,
                          strokeWidth: 2.5,
                          strokeColor: Colors.white,
                        ),
                      ),
                    );
                  }).toList(),
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) =>
                        const Color(0xFF3B0764).withValues(alpha: 0.92),
                    tooltipRoundedRadius: 12,
                    tooltipPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    getTooltipItems: (touched) => touched.map((ts) {
                      final val = ts.y;
                      final text = '₹${val.toStringAsFixed(0)}';
                      return LineTooltipItem(
                        text,
                        GoogleFonts.outfit(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: screenWidth / 31,
                        ),
                      );
                    }).toList(),
                  ),
                ),
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    if (dataMinY != dataMaxY)
                      HorizontalLine(
                        y: dataMinY,
                        color: Colors.white.withValues(alpha: 0.2),
                        strokeWidth: 1,
                        dashArray: [5, 5],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.bottomLeft,
                          padding: const EdgeInsets.only(left: 16, bottom: 6),
                          style: GoogleFonts.outfit(
                            color: glowMid,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          labelResolver: (line) => formatCurrency(line.y),
                        ),
                      ),
                    HorizontalLine(
                      y: dataMaxY,
                      color: Colors.white.withValues(alpha: 0.2),
                      strokeWidth: 1,
                      dashArray: [5, 5],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.topLeft,
                        padding: const EdgeInsets.only(left: 16, top: 6),
                        style: GoogleFonts.outfit(
                          color: glowMid,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        labelResolver: (line) => formatCurrency(line.y),
                      ),
                    ),
                  ],
                ),
                minX: minX,
                maxX: maxX,
                minY: minY,
                maxY: maxY,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: titlesData,
                clipData: const FlClipData.all(),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    color: stroke,
                    barWidth: 1.8,
                    isStrokeCapRound: true,
                    isStrokeJoinRound: true,
                    dotData: FlDotData(
                      show: true,
                      checkToShowDot: (spot, barData) {
                        // Only show the dot if it aligns perfectly with a real month (integer X)
                        // This prevents noise peaks in the middle of a month from triggering a dot.
                        final isRealPoint = spot.x == spot.x.roundToDouble();
                        return isRealPoint && (spot.y == dataMinY || spot.y == dataMaxY);
                      },
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4.5,
                          color: glowMid,
                          strokeWidth: 4,
                          strokeColor: glowMid.withValues(alpha: 0.25),
                        );
                      },
                    ),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
            ),
          ),
        ],
      ),
    );
  }
}
