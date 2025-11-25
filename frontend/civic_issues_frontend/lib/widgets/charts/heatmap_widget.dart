import 'package:flutter/material.dart';

class HeatmapWidget extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final String title;

  const HeatmapWidget({
    super.key,
    required this.data,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return _buildEmptyState();
    }

    return Card(
      elevation: 4,
      child: Padding(
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
            SizedBox(
              height: 300,
              child: _buildHeatmapGrid(),
            ),
            const SizedBox(height: 16),
            _buildLegend(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(
              Icons.map_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No location data available',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatmapGrid() {
    // Group data points by grid cells
    const gridSize = 10;
    final Map<String, int> gridCounts = {};

    // Find min/max coordinates
    double minLat = double.infinity;
    double maxLat = double.negativeInfinity;
    double minLng = double.infinity;
    double maxLng = double.negativeInfinity;

    for (var point in data) {
      final lat = point['latitude'] as double;
      final lng = point['longitude'] as double;

      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    // Count points in each grid cell
    for (var point in data) {
      final lat = point['latitude'] as double;
      final lng = point['longitude'] as double;

      final x = ((lng - minLng) / (maxLng - minLng) * gridSize)
          .floor()
          .clamp(0, gridSize - 1);
      final y = ((lat - minLat) / (maxLat - minLat) * gridSize)
          .floor()
          .clamp(0, gridSize - 1);

      final key = '$x,$y';
      gridCounts[key] = (gridCounts[key] ?? 0) + 1;
    }

    final maxCount = gridCounts.values.isEmpty
        ? 1
        : gridCounts.values.reduce((a, b) => a > b ? a : b);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: gridSize,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: gridSize * gridSize,
      itemBuilder: (context, index) {
        final x = index % gridSize;
        final y = index ~/ gridSize;
        final key = '$x,$y';
        final count = gridCounts[key] ?? 0;

        return Container(
          decoration: BoxDecoration(
            color: _getHeatColor(count, maxCount),
            borderRadius: BorderRadius.circular(2),
          ),
          child: count > 0
              ? Center(
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color:
                          count > maxCount / 2 ? Colors.white : Colors.black87,
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  Color _getHeatColor(int count, int maxCount) {
    if (count == 0) return Colors.grey[200]!;

    final intensity = count / maxCount;

    if (intensity < 0.2) {
      return Colors.blue[100]!;
    } else if (intensity < 0.4) {
      return Colors.green[300]!;
    } else if (intensity < 0.6) {
      return Colors.yellow[600]!;
    } else if (intensity < 0.8) {
      return Colors.orange[600]!;
    } else {
      return Colors.red[700]!;
    }
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem('Low', Colors.blue[100]!),
        const SizedBox(width: 8),
        _buildLegendItem('Medium', Colors.yellow[600]!),
        const SizedBox(width: 8),
        _buildLegendItem('High', Colors.red[700]!),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}
