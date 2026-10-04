import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:wallone/features/dashboard/models/balance_model.dart';
import 'package:wallone/features/dashboard/providers/balance_provider.dart';
import 'package:wallone/features/transactions/providers/list_provider.dart';
import 'package:wallone/core/utils/constants.dart';

class TotalExpenseBoxWidget extends StatelessWidget {
  final String? label;
  final String balanceType; // 'daily', 'weekly', 'monthly', or 'total'
  final bool isExpensesSelected; // Whether expenses or incomes are selected
  final String selectedPeriod; // 'All Dates' or date key

  const TotalExpenseBoxWidget({
    super.key,
    this.label,
    required this.balanceType,
    required this.isExpensesSelected,
    this.selectedPeriod = 'All Dates',
  });

  @override
  Widget build(BuildContext context) {
    final balanceProvider = Provider.of<BalanceProvider>(context);
    final listProvider = Provider.of<ListProvider>(context);
    String formattedBalance;

    // Instead of using the raw double value, we now use formatted getters.
    switch (balanceType) {
      case 'daily':
        double sum = 0.0;

        // For daily balance, always filter to the specific date (today if 'All Dates')
        final dateToFilter =
            selectedPeriod == 'All Dates' ? 'Today' : selectedPeriod;
        final txs = listProvider.getTransactionsForDate(dateToFilter);

        for (final t in txs) {
          if (isExpensesSelected && !t.isIncome) sum += t.amount;
          if (!isExpensesSelected && t.isIncome) sum += t.amount;
        }

        formattedBalance = const BalanceModel().formatValue(sum);
        break;

      case 'weekly':
        formattedBalance = isExpensesSelected
            ? balanceProvider.formattedWeeklyExpenses
            : balanceProvider.formattedWeeklyIncomes;
        break;
      case 'monthly':
        formattedBalance = isExpensesSelected
            ? balanceProvider.formattedMonthlyExpenses
            : balanceProvider.formattedMonthlyIncomes;
        break;
      case 'total':
      default:
        formattedBalance = balanceProvider.formattedTotalBalance;
        break;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (label != null)
          Text(
            label!,
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: purpleColors(context),
            ),
          ),
        Text(
          formattedBalance,
          style: GoogleFonts.outfit(
            fontSize: 12,
            color: primaryColor(context),
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
