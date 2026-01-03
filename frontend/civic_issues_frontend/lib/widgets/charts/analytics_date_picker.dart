import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

class AnalyticsDatePicker extends StatefulWidget {
  final Function(DateTime, DateTime) onDateRangeSelected;
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;

  const AnalyticsDatePicker({
    super.key,
    required this.onDateRangeSelected,
    this.initialStartDate,
    this.initialEndDate,
  });

  @override
  State<AnalyticsDatePicker> createState() => _AnalyticsDatePickerState();
}

class _AnalyticsDatePickerState extends State<AnalyticsDatePicker> {
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate ??
        DateTime.now().subtract(const Duration(days: 30));
    _endDate = widget.initialEndDate ?? DateTime.now();
  }

  void _onSelectionChanged(DateRangePickerSelectionChangedArgs args) {
    if (args.value is PickerDateRange) {
      final range = args.value as PickerDateRange;
      if (range.startDate != null && range.endDate != null) {
        setState(() {
          _startDate = range.startDate!;
          _endDate = range.endDate!;
        });
        widget.onDateRangeSelected(_startDate, _endDate);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Date Range',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: SfDateRangePicker(
                selectionMode: DateRangePickerSelectionMode.range,
                initialSelectedRange: PickerDateRange(_startDate, _endDate),
                onSelectionChanged: _onSelectionChanged,
                maxDate: DateTime.now(),
                minDate: DateTime.now().subtract(const Duration(days: 365)),
                headerStyle: const DateRangePickerHeaderStyle(
                  textStyle: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                monthViewSettings: const DateRangePickerMonthViewSettings(
                  firstDayOfWeek: 1, // Monday
                ),
                selectionColor: Colors.blue,
                rangeSelectionColor: Colors.blue.withValues(alpha: 0.1),
                startRangeSelectionColor: Colors.blue,
                endRangeSelectionColor: Colors.blue,
                todayHighlightColor: Colors.orange,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'From: ${_startDate.toString().split(' ')[0]}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  'To: ${_endDate.toString().split(' ')[0]}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final now = DateTime.now();
                      setState(() {
                        _startDate = now.subtract(const Duration(days: 7));
                        _endDate = now;
                      });
                      widget.onDateRangeSelected(_startDate, _endDate);
                    },
                    child: const Text('Last 7 Days'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final now = DateTime.now();
                      setState(() {
                        _startDate = now.subtract(const Duration(days: 30));
                        _endDate = now;
                      });
                      widget.onDateRangeSelected(_startDate, _endDate);
                    },
                    child: const Text('Last 30 Days'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final now = DateTime.now();
                      setState(() {
                        _startDate = now.subtract(const Duration(days: 90));
                        _endDate = now;
                      });
                      widget.onDateRangeSelected(_startDate, _endDate);
                    },
                    child: const Text('Last 90 Days'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
