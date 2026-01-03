import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class LineChartWidget extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final String title;
  final String xAxisLabel;
  final String yAxisLabel;
  final Color lineColor;
  final double? maxY;

  const LineChartWidget({
    super.key,
    required this.data,
    required this.title,
    this.xAxisLabel = 'Date',
    this.yAxisLabel = 'Count',
    this.lineColor = Colors.blue,
    this.maxY,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return Card(
        elevation: 4,
        margin: const EdgeInsets.all(8),
        child: Container(
          height: 300,
          padding: const EdgeInsets.all(16),
          child: const Center(
            child: Text(
              'No data available',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8),
      child: Container(
        height: 300,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 &&
                              value.toInt() < data.length) {
                            final dateStr = data[value.toInt()]['date'] ?? '';
                            // Show every 3rd date to avoid crowding
                            if (value.toInt() % 3 == 0) {
                              return Text(
                                dateStr.length > 10
                                    ? dateStr.substring(5, 10)
                                    : dateStr,
                                style: const TextStyle(fontSize: 10),
                              );
                            }
                          }
                          return const Text('');
                        },
                        reservedSize: 30,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                        reservedSize: 40,
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: data.asMap().entries.map((entry) {
                        final index = entry.key.toDouble();
                        final item = entry.value;
                        final created = item['created'] ?? 0;
                        final assigned = item['assigned'] ?? 0;
                        final completed = item['completed'] ?? 0;
                        final verified = item['verified'] ?? 0;

                        // Show different metrics based on title
                        double yValue = 0;
                        if (title.contains('Created')) {
                          yValue = created.toDouble();
                        } else if (title.contains('Assigned')) {
                          yValue = assigned.toDouble();
                        } else if (title.contains('Completed')) {
                          yValue = completed.toDouble();
                        } else if (title.contains('Verified')) {
                          yValue = verified.toDouble();
                        } else {
                          yValue = created.toDouble(); // Default
                        }

                        return FlSpot(index, yValue);
                      }).toList(),
                      isCurved: true,
                      color: lineColor,
                      barWidth: 3,
                      belowBarData: BarAreaData(
                        show: true,
                        color: lineColor.withValues(alpha: 0.1),
                      ),
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                  minY: 0,
                  maxY: maxY,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
