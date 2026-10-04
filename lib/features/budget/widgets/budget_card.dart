import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:wallone/features/dashboard/providers/balance_provider.dart';
import 'package:wallone/core/utils/constants.dart';
import 'package:provider/provider.dart';
import 'package:wallone/features/budget/providers/budget_provider.dart';
import 'package:wallone/features/budget/widgets/add_budget_dialog.dart';

// Constants for better maintainability
class _BudgetCardConstants {
  static const double iconContainerPadding = 14;
  static const double iconContainerBorderRadius = 16;
  static const double progressBarHeight = 8;
  static const double estimatedItemHeight = 130.0;
  static const Duration pageScrollDuration = Duration(milliseconds: 500);
  static const Duration autoScrollInterval = Duration(seconds: 4);
}

// Main widget class
class BudgetOverviewCard extends StatefulWidget {
  const BudgetOverviewCard({
    super.key,
  });

  @override
  State<BudgetOverviewCard> createState() => _BudgetOverviewCardState();
}

class _BudgetOverviewCardState extends State<BudgetOverviewCard> {
  Timer? _timer;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_BudgetCardConstants.autoScrollInterval, (timer) {
      final budgetProvider = context.read<BudgetProvider>();
      if (!budgetProvider.showAllBudgets && mounted) {
        final budgets = budgetProvider.budgets;
        if (budgets.isNotEmpty) {
          final nextPage =
              (budgetProvider.currentBudgetIndex + 1) % budgets.length;
          _pageController.animateToPage(
            nextPage,
            duration: _BudgetCardConstants.pageScrollDuration,
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  double _calculateProgress(Budget budget) {
    if (budget.amount <= 0) return 0.0;
    final progress = budget.spent / budget.amount;
    return progress.isFinite ? math.max(0.0, progress) : 0.0;
  }

  String _formatCurrency(double amount, String currencyCode) {
    final symbol =
        NumberFormat.simpleCurrency(name: currencyCode).currencySymbol;
    return '$symbol${amount.toStringAsFixed(0)}';
  }

  Widget _buildBudgetProgress(Budget budget) {
    final code = context.read<BalanceProvider>().currencyCode;
    final screenWidth = MediaQuery.of(context).size.width;
    final progress = _calculateProgress(budget);

    return GestureDetector(
      onLongPress: () => showAddBudgetDialog(context, budget: budget),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: screenWidth / 40),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              budget.color(context).withValues(alpha: 0.15),
              budget.color(context).withValues(alpha: 0.25),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: budget.color(context).withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: budget.color(context).withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildGradientIconContainer(
                  budget.icon,
                  [
                    budget.color(context).withValues(alpha: 0.7),
                    budget.color(context),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        budget.category,
                        style: GoogleFonts.outfit(
                          fontSize: screenWidth / 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 6, top: 6),
                            decoration: BoxDecoration(
                              color: budget.color(context),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: budget
                                      .color(context)
                                      .withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            budget.statusText,
                            style: GoogleFonts.outfit(
                              fontSize: screenWidth / 30,
                              color: budget.color(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      spacing: 5,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                budget.color(context).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${(progress * 100).toStringAsFixed(0)}%',
                            style: GoogleFonts.outfit(
                              fontSize: screenWidth / 28,
                              fontWeight: FontWeight.bold,
                              color: budget.color(context),
                            ),
                          ),
                        ),
                        Text(
                          _formatCurrency(budget.spent, code),
                          style: GoogleFonts.outfit(
                            fontSize: screenWidth / 25,
                            fontWeight: FontWeight.w600,
                            color: budget.color(context),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'of ${_formatCurrency(budget.amount, code)}',
                      style: GoogleFonts.outfit(
                        fontSize: screenWidth / 30,
                        color: budgetTextLight(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildProgressBar(budget, progress),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(Budget budget, double progress) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          Container(
            height: _BudgetCardConstants.progressBarHeight,
            decoration: BoxDecoration(
              color: budget.color(context).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              height: _BudgetCardConstants.progressBarHeight,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    budget.color(context).withValues(alpha: 0.7),
                    budget.color(context),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),
          if (progress >= 1.0)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(
                    Icons.warning_rounded,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGradientIconContainer(
      IconData icon, List<Color> gradientColors) {
    return Container(
      padding: const EdgeInsets.all(_BudgetCardConstants.iconContainerPadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(
            _BudgetCardConstants.iconContainerBorderRadius),
        boxShadow: [
          BoxShadow(
            color: gradientColors[0].withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: 15,
      ),
    );
  }

  Widget _buildBudgetSummary(List<Budget> budgets) {
    final code = context.read<BalanceProvider>().currencyCode;
    final totalBudgeted = budgets.fold<double>(0, (sum, b) => sum + b.amount);
    final totalSpent = budgets.fold<double>(0, (sum, b) => sum + b.spent);
    final remaining = totalBudgeted - totalSpent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).primaryColor.withValues(alpha: 0.1),
            Theme.of(context).primaryColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem(
            label: 'Budgeted',
            value: _formatCurrency(totalBudgeted, code),
            icon: Icons.account_balance_wallet,
          ),
          Container(
            width: 1,
            height: 40,
            color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
          ),
          _buildSummaryItem(
            label: 'Spent',
            value: _formatCurrency(totalSpent, code),
            icon: Icons.trending_down,
          ),
          Container(
            width: 1,
            height: 40,
            color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
          ),
          _buildSummaryItem(
            label: 'Remaining',
            value: _formatCurrency(remaining, code),
            icon: Icons.trending_up,
            isPositive: remaining >= 0,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required String label,
    required String value,
    required IconData icon,
    bool isPositive = true,
  }) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 20,
            color: isPositive ? Colors.green : Colors.red,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: budgetTextLight(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: primaryColor(context),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BudgetProvider>(
      builder: (context, budgetProvider, child) {
        final budgets = budgetProvider.budgets;

        if (budgets.isEmpty) {
          return _buildEmptyState();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBudgetSummary(budgets),
            const SizedBox(height: 20),
            _buildListViewSection(budgets, budgetProvider),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: boxColor(context),
            shape: BoxShape.circle,
            border: Border.all(
              color: shadowColor(context),
            ),
          ),
          child: Icon(
            Icons.account_balance_wallet_outlined,
            size: 32,
            color: primaryColor(context),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          "No Budgets Yet",
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: primaryColor(context),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "Start tracking your expenses by adding a budget category.",
          textAlign: TextAlign.center,
          style: GoogleFonts.outfit(
            fontSize: 16,
            color: budgetTextLight(context),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 28),
        ElevatedButton.icon(
          onPressed: () => showAddBudgetDialog(context),
          icon: Icon(
            Icons.add,
            color: primaryColor(context),
          ),
          label: Text(
            'Add Budget',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.w600,
              color: primaryColor(context),
            ),
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: 28,
              vertical: 14,
            ),
            backgroundColor: boxColor(context),
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: shadowColor(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListViewSection(
      List<Budget> budgets, BudgetProvider budgetProvider) {
    return LayoutBuilder(builder: (context, constraints) {
      final computedHeight = math.min(
        budgets.length * _BudgetCardConstants.estimatedItemHeight,
        constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : MediaQuery.of(context).size.height * 0.6,
      );

      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: computedHeight),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: budgets.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return Slidable(
              closeOnScroll: true,
              key: Key(budgets[index].id),
              endActionPane: ActionPane(
                motion: const DrawerMotion(),
                extentRatio: 0.4,
                children: [
                  CustomSlidableAction(
                    onPressed: (_) {
                      budgetProvider.removeBudget(budgets[index].id);
                    },
                    backgroundColor: boxColor(context),
                    child: Icon(
                      Icons.delete_outlined,
                      color: primaryColor(context),
                    ),
                  ),
                  CustomSlidableAction(
                    onPressed: (_) {
                      showAddBudgetDialog(context, budget: budgets[index]);
                    },
                    backgroundColor: boxColor(context),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    child: Icon(
                      Icons.edit_note_rounded,
                      color: primaryColor(context),
                    ),
                  ),
                ],
              ),
              child: _buildBudgetProgress(budgets[index]),
            );
          },
        ),
      );
    });
  }
}
