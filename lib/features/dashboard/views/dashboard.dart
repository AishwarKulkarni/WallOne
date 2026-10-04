import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallone/features/ads/widgets/banner_ad_widget.dart';
import 'package:wallone/shared/widgets/dynamic_buttons.dart';
import 'package:wallone/shared/widgets/filter_control.dart';
import 'package:wallone/shared/widgets/item_list.dart';
import 'package:wallone/features/dashboard/widgets/total_expense.dart';
import 'package:wallone/features/dashboard/providers/balance_provider.dart';
import 'package:wallone/features/transactions/providers/list_provider.dart';
import 'package:wallone/core/utils/constants.dart';

class DashboardPage extends StatefulWidget {
  final Function(bool isBalanceVisible) onBalanceVisibilityChanged;
  const DashboardPage({
    super.key,
    required this.onBalanceVisibilityChanged,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool isExpensesSelected = true;
  String selectedPeriod = 'All Dates';

  final ScrollController _scrollController = ScrollController();
  bool isBalanceVisible = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    // When scroll offset > 80, assume the Balance section is off-screen
    if (_scrollController.offset > 80 && isBalanceVisible) {
      setState(() {
        isBalanceVisible = false;
      });
      widget.onBalanceVisibilityChanged(false);
    } else if (_scrollController.offset <= 80 && !isBalanceVisible) {
      setState(() {
        isBalanceVisible = true;
      });
      widget.onBalanceVisibilityChanged(true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = context.read<BalanceProvider>().currencyCode;
    final symbol = NumberFormat.simpleCurrency(name: code).currencySymbol;
    final totalBalance =
        context.select<BalanceProvider, double>((p) => p.totalBalance);

    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // Scroll Below - Balance Section
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 17.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Hero(
                tag: 'balanceHero',
                child: Material(
                  color: Colors.transparent,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, anim) {
                      final offsetAnim = anim.drive(
                        Tween<Offset>(
                                begin: const Offset(0, 0.25), end: Offset.zero)
                            .chain(
                          CurveTween(curve: Curves.easeOut),
                        ),
                      );
                      return SlideTransition(
                        position: offsetAnim,
                        child: FadeTransition(
                          opacity: anim,
                          child: child,
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Balance',
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            color: purpleColors(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          symbol + totalBalance.toString(),
                          key: ValueKey(totalBalance),
                          style: GoogleFonts.outfit(
                            fontSize: 30,
                            color: primaryColor(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        selectedPeriod != 'All Dates'
                            ? Row(
                                spacing: 10,
                                children: [
                                  SizedBox(
                                    child: TotalExpenseBoxWidget(
                                      balanceType: 'daily',
                                      isExpensesSelected: isExpensesSelected,
                                      selectedPeriod: selectedPeriod,
                                    ),
                                  ),
                                  Card(
                                    color: Colors.transparent,
                                    elevation: 0,
                                    child: Text(
                                      "Total ${isExpensesSelected ? 'Expenses' : 'Income'} for ${DateFormat('dd MMM').format(DateTime.parse(selectedPeriod))}",
                                      style: GoogleFonts.outfit(
                                        fontSize: 12,
                                        color: primaryColor(context),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                spacing: 20,
                                children: [
                                  TotalExpenseBoxWidget(
                                    label: "D A Y",
                                    balanceType: 'daily',
                                    isExpensesSelected: isExpensesSelected,
                                    selectedPeriod: selectedPeriod,
                                  ),
                                  TotalExpenseBoxWidget(
                                    label: "W E E K",
                                    balanceType: 'weekly',
                                    isExpensesSelected: isExpensesSelected,
                                  ),
                                  TotalExpenseBoxWidget(
                                    label: "M O N T H",
                                    balanceType: 'monthly',
                                    isExpensesSelected: isExpensesSelected,
                                  ),
                                ],
                              ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        // Stick at top - Transactions Header
        SliverStickyHeader(
          sticky: true,
          header: Container(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: 16,
              top: 16,
            ),
            color: mainColor(context),
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      "T R A N S A C T I O N S",
                      textAlign: TextAlign.left,
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        color: primaryColor(context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Switches and Filters Container
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      flex: 3,
                      child: DynamicButtonsWidget(
                        onSelectionChanged: (isExpensesSelected) {
                          setState(() {
                            this.isExpensesSelected = isExpensesSelected;
                          });

                          Provider.of<ListProvider>(context, listen: false)
                              .setFilter(
                            isExpensesSelected: isExpensesSelected,
                            period: selectedPeriod,
                            isActive: selectedPeriod != 'All Dates',
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: TransactionFilterControls(
                        isExpensesSelected: isExpensesSelected,
                        selectedPeriod: selectedPeriod,
                        showCustomDateOption: true,
                        onTypeChanged: (value) =>
                            setState(() => isExpensesSelected = value),
                        onPeriodChanged: (period) {
                          if (period == 'Custom_Date') {
                            _showCustomDatePicker(context);
                          } else {
                            final newPeriod = period ?? 'All Dates';
                            setState(() {
                              selectedPeriod = newPeriod;
                            });

                            Provider.of<ListProvider>(context, listen: false)
                                .setFilter(
                              isExpensesSelected: isExpensesSelected,
                              period: newPeriod,
                              isActive: newPeriod != 'All Dates',
                            );
                          }
                        },
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),

          // Stick at top - Filter Controls

          // List
          sliver: Consumer<ListProvider>(
            key: ValueKey('${isExpensesSelected}_$selectedPeriod'),
            builder: (context, listProvider, child) {
              final transactions = listProvider.getFilteredTransactions(
                isExpensesSelected,
                selectedPeriod,
              );

              // Group transactions by date
              final Map<String, List<AllListProvider>> groupedTransactions = {};
              for (final transaction in transactions) {
                String dateKey;
                final dt = DateTime.tryParse(transaction.createdAt.isNotEmpty ? transaction.createdAt : transaction.date);
                if (dt != null) {
                  dateKey = "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
                } else {
                  try {
                    final parsedDate = DateFormat('dd-MM-yyyy').parse(transaction.date);
                    dateKey = "${parsedDate.year}-${parsedDate.month.toString().padLeft(2, '0')}-${parsedDate.day.toString().padLeft(2, '0')}";
                  } catch (_) {
                    dateKey = "1970-01-01";
                  }
                }
                (groupedTransactions[dateKey] ??= []).add(transaction);
              }

              // Sort dates descending
              final sortedDates = groupedTransactions.keys.toList()
                ..sort((a, b) => b.compareTo(a));

              final limitedDates = sortedDates;

              if (limitedDates.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isExpensesSelected
                                ? Icons.receipt_long_rounded
                                : Icons.account_balance_wallet_rounded,
                            size: 80,
                            color: primaryColor(context).withAlpha(80),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            isExpensesSelected
                                ? "No expenses yet!"
                                : "No income yet!",
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: primaryColor(context),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isExpensesSelected
                                ? "Small steps lead to big savings.\nTap '$symbol' to add your first expense!"
                                : "Every penny counts!\nTap '$symbol' to add your income.",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(
                              fontSize: 15,
                              color: primaryColor(context).withAlpha(150),
                            ),
                          ),
                          const SizedBox(height: 48),
                        ],
                      ),
                    ),
                  ),
                );
              }

              // Return SliverList with proper delegate
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final date = limitedDates[index];
                    final isLastItem = index == limitedDates.length - 1;
                    return Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.only(
                            left: 16.0,
                            right: 16,
                            bottom: isLastItem ? 100 : 16.0,
                          ),
                          child: Column(
                            children: [
                              ItemListWidget(
                                transactions: groupedTransactions[date]!,
                              ),
                              if (!isLastItem)
                                const Padding(
                                  padding: EdgeInsets.only(top: 8.0),
                                  child: BannerAdWidget(),
                                ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                  childCount: limitedDates.length,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _showCustomDatePicker(BuildContext context) async {
    final screenWidth = MediaQuery.of(context).size.width;
    DateTime tempDate = DateTime.now();
    DateTime? pickedDate;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Select Date",
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOut),
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
            child: child,
          ),
        );
      },
      pageBuilder: (ctx, anim1, __) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: StatefulBuilder(
          builder: (context, setStateDialog) {
            return Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: boxColor(context),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor(context).withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: primaryColor(context),
                          foregroundColor: inversePrimaryColor(context),
                        ),
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Select Date',
                        style: GoogleFonts.outfit(
                          fontSize: screenWidth / 20,
                          fontWeight: FontWeight.bold,
                          color: primaryColor(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  CupertinoTheme(
                    data: CupertinoThemeData(
                      textTheme: CupertinoTextThemeData(
                        dateTimePickerTextStyle: GoogleFonts.outfit(
                          fontSize: screenWidth / 25,
                          color: cardTextColor(context),
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: boxColor(context),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    shadowColor(context).withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: CupertinoDatePicker(
                            mode: CupertinoDatePickerMode.date,
                            initialDateTime: tempDate,
                            onDateTimeChanged: (dt) {
                              setStateDialog(() {
                                tempDate = dt;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: boxColor(context),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    shadowColor(context).withValues(alpha: 0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormat('yyyy/MM/dd').format(tempDate),
                                style: GoogleFonts.outfit(
                                  fontSize: screenWidth / 30,
                                  color: primaryColor(context),
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                iconSize: screenWidth / 15,
                                icon: const Icon(Icons.refresh),
                                color: Colors.redAccent,
                                tooltip: 'Reset date',
                                onPressed: () {
                                  setStateDialog(() {
                                    tempDate = DateTime.now();
                                  });
                                },
                              ),
                              IconButton(
                                iconSize: screenWidth / 15,
                                icon: const Icon(Icons.check_circle_outline),
                                color: primaryColor(context),
                                onPressed: () {
                                  pickedDate = tempDate;
                                  Navigator.pop(context);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    if (pickedDate != null) {
      final newPeriod = DateFormat('yyyy-MM-dd').format(pickedDate!);
      
      if (!context.mounted) return;

      setState(() {
        selectedPeriod = newPeriod;
      });

      Provider.of<ListProvider>(context, listen: false).setFilter(
        isExpensesSelected: isExpensesSelected,
        period: newPeriod,
        isActive: true,
      );
    }
  }
}
