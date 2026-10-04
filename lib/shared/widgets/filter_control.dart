import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wallone/core/utils/constants.dart';
import 'package:wallone/shared/widgets/dropdown_menu.dart';

class TransactionFilterControls extends StatelessWidget {
  final bool isExpensesSelected;
  final String selectedPeriod;
  final Function(bool) onTypeChanged;
  final Function(String?) onPeriodChanged;
  final bool showCustomDateOption;

  const TransactionFilterControls({
    super.key,
    required this.isExpensesSelected,
    required this.selectedPeriod,
    required this.onTypeChanged,
    required this.onPeriodChanged,
    this.showCustomDateOption = false,
  });

  Map<String, String> _generateDateOptions(String currentSelected,
      {int days = 7}) {
    final now = DateTime.now();
    final keyFormat = DateFormat('yyyy-MM-dd');
    final displayFormat = DateFormat('MM-dd');

    final Map<String, String> options = {'All Dates': 'All Dates'};

    for (int i = 0; i < days; i++) {
      final date = now.subtract(Duration(days: i));
      final key = keyFormat.format(date);
      final label = i == 0 ? 'Today' : displayFormat.format(date);
      options[key] = label;
    }

    if (showCustomDateOption) {
      options['Custom_Date'] = 'Select Date...';
    }

    if (currentSelected.isNotEmpty &&
        currentSelected != 'All Dates' &&
        currentSelected != 'Custom_Date' &&
        !options.containsKey(currentSelected)) {
      options[currentSelected] = currentSelected;
    }

    return options;
  }

  @override
  Widget build(BuildContext context) {
    final actualValue = selectedPeriod.isEmpty ? 'All Dates' : selectedPeriod;
    final dateOptions = _generateDateOptions(actualValue);

    return DropdownMenuDynamicWidget(
      boxColor: boxColor(context),
      hintText: '',
      value: actualValue,
      items: dateOptions.keys.toList(),
      itemDisplayMap: dateOptions, // Pass the display map
      customDisplayText: dateOptions[actualValue] ?? actualValue,
      onItemSelected: onPeriodChanged,
    );
  }
}
