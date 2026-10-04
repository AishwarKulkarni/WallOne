import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallone/features/ads/widgets/banner_ad_widget.dart';
import 'package:wallone/features/dashboard/widgets/usage_card.dart';
import 'package:wallone/features/budget/providers/budget_provider.dart';
import 'package:wallone/features/dashboard/providers/balance_provider.dart';
import 'package:wallone/core/utils/constants.dart';
import 'package:wallone/features/budget/widgets/budget_card.dart';
import 'package:wallone/features/investments/widgets/investment_card.dart';
import 'package:wallone/features/budget/widgets/add_budget_dialog.dart';

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final budgetProvider = Provider.of<BudgetProvider>(context);
    final balanceProvider = Provider.of<BalanceProvider>(context);

    final double progress = (budgetProvider.monthlyIncome > 0)
        ? (balanceProvider.monthlyExpenses / budgetProvider.monthlyIncome)
            .clamp(0.0, 1.0)
        : 0.0;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildMonthlyIncomeCard(
                  context, budgetProvider, progress, balanceProvider),
              const SizedBox(height: 30),
              _buildSectionWithBadge(
                "Budget Categories",
                "${budgetProvider.budgets.length} Active",
                context,
              ),
              const SizedBox(height: 16),
              const BudgetOverviewCard(),
              const SizedBox(height: 20),
              const Align(
                alignment: Alignment.center,
                child: BannerAdWidget(),
              ),
              const SizedBox(height: 35),
              _buildSectionWithInfoButton(
                "Fixed Investments",
                context,
                onInfoPressed: () => _showInvestmentInfo(context),
              ),
              const SizedBox(height: 16),
              const FixedInvestmentsCard(),
              const SizedBox(height: 110),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionWithBadge(
      String title, String badgeText, BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: screenWidth / 23,
            color: primaryColor(context),
            fontWeight: FontWeight.w500,
          ),
        ),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: boxColor(context),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor(context).withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                badgeText,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w600,
                  color: primaryColor(context),
                ),
              ),
            ),
            if (title == "Budget Categories") ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => showAddBudgetDialog(context),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: boxColor(context),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: shadowColor(context).withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.add,
                    color: primaryColor(context),
                    size: 20,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildSectionWithInfoButton(String title, BuildContext context,
      {required VoidCallback onInfoPressed}) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: screenWidth / 23,
            fontWeight: FontWeight.w500,
            color: primaryColor(context),
          ),
        ),
        GestureDetector(
          onTap: onInfoPressed,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: boxColor(context),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: shadowColor(context).withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.info_outline,
              color: primaryColor(context),
              size: screenWidth / 25,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthlyIncomeCard(
      BuildContext context,
      BudgetProvider budgetProvider,
      double progress,
      BalanceProvider balanceProvider) {
    final monthlyExpenses = balanceProvider.monthlyExpenses;
    final code = context.read<BalanceProvider>().currencyCode;
    final symbol = NumberFormat.simpleCurrency(name: code).currencySymbol;
    final screenWidth = MediaQuery.of(context).size.width;

    // Determine progress color based on percentage
    Color progressColor = Colors.green;
    if (progress > 0.7 && progress <= 0.9) {
      progressColor = Colors.orange;
    } else if (progress > 0.9) {
      progressColor = Colors.red;
    }

    return Container(
      height: 220,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [boxColor(context).withValues(alpha: 0.5), boxColor(context)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: shadowColor(context).withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Decorative elements
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor(context).withValues(alpha: 0.05),
                ),
              ),
            ),
            Positioned(
              left: -20,
              bottom: -20,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor(context).withValues(alpha: 0.05),
                ),
              ),
            ),
            // Decorative dots pattern
            Positioned(
              right: 40,
              top: 40,
              child: _buildDotPattern(
                  6, 6, 4, 4, primaryColor(context).withValues(alpha: 0.1)),
            ),
            Positioned(
              left: 30,
              bottom: 30,
              child: _buildDotPattern(
                  4, 4, 3, 3, primaryColor(context).withValues(alpha: 0.1)),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Monthly Income Column
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: primaryColor(context)
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.account_balance_wallet,
                                    color: primaryColor(context)
                                        .withValues(alpha: 0.9),
                                    size: screenWidth / 25,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Total Savings',
                                  style: GoogleFonts.outfit(
                                    fontSize: screenWidth / 25,
                                    color: primaryColor(context)
                                        .withValues(alpha: 0.9),
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "$symbol${budgetProvider.monthlySavings.toStringAsFixed(2)}",
                              style: GoogleFonts.outfit(
                                fontSize: screenWidth / 16,
                                fontWeight: FontWeight.bold,
                                color: primaryColor(context),
                              ),
                            ),
                          ],
                        ),
                      ),

                      UsageCard(
                        budgetProvider: budgetProvider,
                        balanceProvider: balanceProvider,
                        progress: progress,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: primaryColor(context)
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.account_balance,
                                  color: primaryColor(context)
                                      .withValues(alpha: 0.9),
                                  size: 14,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Monthly Expenses',
                                style: GoogleFonts.outfit(
                                  fontSize: screenWidth / 27,
                                  color: primaryColor(context)
                                      .withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '$symbol${monthlyExpenses.toStringAsFixed(2)}',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              color: primaryColor(context),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Stack(
                        children: [
                          // Background progress bar
                          Container(
                            height: 12,
                            decoration: BoxDecoration(
                              color:
                                  primaryColor(context).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          // Foreground progress bar
                          FractionallySizedBox(
                            widthFactor: progress,
                            child: Container(
                              height: 12,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    progressColor.withValues(alpha: 0.7),
                                    progressColor,
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: progressColor.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: (progress > 0.8
                                      ? Colors.red
                                      : primaryColor(context))
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              progress > 0.8
                                  ? Icons.warning_amber_rounded
                                  : Icons.info_outline,
                              color: progress > 0.8
                                  ? Colors.red.shade300
                                  : primaryColor(context)
                                      .withValues(alpha: 0.9),
                              size: 14,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${(progress * 100).toStringAsFixed(1)}% of monthly income spent',
                            style: GoogleFonts.outfit(
                              fontSize: screenWidth / 27,
                              color: progress > 0.8
                                  ? Colors.red.shade300
                                  : primaryColor(context)
                                      .withValues(alpha: 0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDotPattern(
      int rows, int columns, double size, double spacing, Color color) {
    return Column(
      children: List.generate(rows, (rowIndex) {
        return Padding(
          padding: EdgeInsets.only(bottom: spacing),
          child: Row(
            children: List.generate(columns, (colIndex) {
              return Padding(
                padding: EdgeInsets.only(right: spacing),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}

void _showInvestmentInfo(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(top: 16, bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(5),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: primaryColor(context).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.savings,
                      color: primaryColor(context),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Investment Tracker',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: primaryColor(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Static info list
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildTipCard(
                    context,
                    icon: Icons.trending_up,
                    title: "📈 Monthly Growth",
                    description:
                        "Your chosen amount (e.g., ₹500) is automatically added every month, helping you grow your investments consistently.",
                  ),
                  _buildTipCard(
                    context,
                    icon: Icons.pause_circle_outline,
                    title: "⏸ Pause Anytime",
                    description:
                        "You can disable or pause an active investment if you decide to stop it temporarily. No progress is lost.",
                  ),
                  _buildTipCard(
                    context,
                    icon: Icons.track_changes,
                    title: "🔍 Progress Tracking",
                    description:
                        "WallOne keeps track of how much you’ve invested so far, showing month-over-month growth in one place.",
                  ),
                  _buildTipCard(
                    context,
                    icon: Icons.check_circle_outline,
                    title: "✅ Easy Management",
                    description:
                        "Start, stop, or adjust your fixed investments anytime with just one tap — no complexity involved.",
                  ),
                ],
              ),
            ),

            // Got it button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor(context),
                    foregroundColor: inversePrimaryColor(context),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Got it',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildTipCard(BuildContext context,
    {required IconData icon,
    required String title,
    required String description}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: shadowColor(context).withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: primaryColor(context).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: primaryColor(context),
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.color
                      ?.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
