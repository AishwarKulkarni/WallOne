import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallone/core/models/icon_map_model.dart';
import 'package:wallone/features/dashboard/providers/balance_provider.dart';
import 'package:wallone/features/transactions/providers/list_provider.dart';
import 'package:wallone/features/categories/providers/category_provider.dart';
import 'package:wallone/core/utils/constants.dart';
import 'package:wallone/core/utils/animations.dart';

class ItemListWidget extends StatefulWidget {
  final List<AllListProvider> transactions;

  const ItemListWidget({super.key, required this.transactions});

  @override
  State<ItemListWidget> createState() => _ItemListWidgetState();
}

class _ItemListWidgetState extends State<ItemListWidget> {
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    if (widget.transactions.isEmpty) {
      return Center(
        child: Text(
          "No transactions available",
          style: TextStyle(fontSize: 18, color: primaryColor(context)),
        ),
      );
    }

    final balanceProvider = context.read<BalanceProvider>();
    final symbol =
        NumberFormat.simpleCurrency(name: balanceProvider.currencyCode)
            .currencySymbol;

    final firstDate = _parseDate(widget.transactions.first.date);
    final headerDate = DateFormat('dd-MM').format(firstDate);
    // Precompute tiles with running 'before' balances (so values are stable)
    final balanceProviderLocal = context.read<BalanceProvider>();
    double runningBalance = balanceProviderLocal.totalBalance;
    final currencyFormatter =
        NumberFormat.simpleCurrency(name: balanceProviderLocal.currencyCode);

    // Sort transactions newest-first to compute consistent before-balances
    final List<AllListProvider> sortedForCalc = List.of(widget.transactions);
    sortedForCalc.sort((a, b) {
      final da = _parseDateFast(a.createdAt, a.date);
      final db = _parseDateFast(b.createdAt, b.date);
      return db.compareTo(da);
    });

    final Map<int, String> beforeMap = {};
    for (final t in sortedForCalc) {
      if (t.beforeBalance != null) {
        beforeMap[t.id] = currencyFormatter.currencySymbol +
            t.beforeBalance!.toStringAsFixed(2);
        // update runningBalance to this stored beforeBalance for subsequent calculations
        runningBalance = t.beforeBalance!;
      } else {
        final delta = t.isIncome ? t.amount : -t.amount;
        final before = runningBalance - delta;
        beforeMap[t.id] =
            currencyFormatter.currencySymbol + before.toStringAsFixed(2);
        runningBalance = before;
      }
    }

    final tiles = List<Widget>.generate(widget.transactions.length, (index) {
      final transaction = widget.transactions[index];
      final beforeStr = beforeMap[transaction.id] ??
          (currencyFormatter.currencySymbol +
              balanceProviderLocal.totalBalance.toStringAsFixed(2));
      return StaggeredListAnimation(
        index: index,
        child: _TransactionTile(
          transaction: transaction,
          symbol: symbol,
          lastBalanceText: beforeStr,
          onEdit: () => _editTransaction(context, transaction),
          onDelete: () => _confirmDelete(context, transaction),
        ),
      );
    });

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        decoration: BoxDecoration(
          color: boxColor(context),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: shadowColor(context),
              blurRadius: 24,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(context, headerDate),
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState: _isExpanded
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              firstChild: Column(children: tiles),
              secondChild: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String headerDate) {
    return ScaleInTransition(
      child: InkWell(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        onTap: () => setState(() => _isExpanded = !_isExpanded),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                headerDate,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: primaryColor(context),
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(
                _isExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: primaryColor(context),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

  DateTime _parseDateFast(String? createdAt, String? dateStr) {
    if (createdAt != null && createdAt.isNotEmpty) {
      final dt = DateTime.tryParse(createdAt);
      if (dt != null) return dt;
    }
    if (dateStr != null && dateStr.isNotEmpty) {
      final dt = DateTime.tryParse(dateStr);
      if (dt != null) return dt;
      try {
        if (dateStr.length <= 5) {
          return DateFormat('dd-MM-yyyy').parse('$dateStr-${DateTime.now().year}');
        }
        return DateFormat('dd-MM-yyyy').parse(dateStr);
      } catch (_) {}
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime _parseDate(String date) {
    return _parseDateFast(null, date);
  }

  Future<void> _confirmDelete(
      BuildContext context, AllListProvider transaction) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _DeleteDialog(context: context),
    );

    if (confirm == true && context.mounted) {
      context.read<ListProvider>().removeTransaction(transaction.id);
    }
  }

  Future<void> _editTransaction(
      BuildContext context, AllListProvider transaction) async {
    final updatedTransaction = await context
        .push<AllListProvider>('/edit-transaction', extra: transaction);

    if (updatedTransaction != null && context.mounted) {
      context.read<ListProvider>().editTransaction(updatedTransaction);
    }
  }
}

/// Reusable delete confirmation dialog
class _DeleteDialog extends StatelessWidget {
  final BuildContext context;
  const _DeleteDialog({required this.context});

  @override
  Widget build(BuildContext dialogContext) {
    return AlertDialog(
      title: const Text(
        "Delete Transaction",
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      content: const Text(
        "Are you sure you want to delete this transaction?",
        style: TextStyle(fontSize: 16),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      elevation: 8.0,
      backgroundColor: snackbarColor(context),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(
            "Cancel",
            style: TextStyle(color: primaryColor(context), fontSize: 16),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            "Delete",
            style: TextStyle(color: purpleColors(context), fontSize: 16),
          ),
        ),
      ],
    );
  }
}

/// Single transaction tile (slidable row)
class _TransactionTile extends StatelessWidget {
  final AllListProvider transaction;
  final String symbol;
  final String lastBalanceText;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TransactionTile({
    required this.transaction,
    required this.symbol,
    required this.lastBalanceText,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.sm,
        right: AppSpacing.sm,
        bottom: AppSpacing.sm,
      ),
      child: Slidable(
        closeOnScroll: true,
        key: ValueKey(transaction.id),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.4,
          children: [
            CustomSlidableAction(
              onPressed: (_) => onDelete(),
              backgroundColor: budgetBackgroundLight(context),
              child: Icon(
                Icons.delete_outlined,
                color: primaryColor(context),
                size: 20,
              ),
            ),
            CustomSlidableAction(
              onPressed: (_) => onEdit(),
              backgroundColor: budgetBackgroundLight(context),
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(15),
                bottomRight: Radius.circular(15),
              ),
              child: Icon(
                Icons.edit_document,
                color: primaryColor(context),
                size: 20,
              ),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: boxColor(context),
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: [
              BoxShadow(
                color: shadowColor(context),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                _TransactionIcon(category: transaction.category),
                const SizedBox(width: 10),
                Expanded(
                  child: _TransactionInfo(transaction: transaction),
                ),
                // Amount and last total balance (right aligned)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "$symbol${transaction.amount.toStringAsFixed(2)}",
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        color: primaryColor(context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // Show the running 'last total balance' passed from parent
                    Text(
                      lastBalanceText,
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        color: primaryColor(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Category icon
class _TransactionIcon extends StatelessWidget {
  final String category;
  const _TransactionIcon({required this.category});

  @override
  Widget build(BuildContext context) {
    return Consumer<CategoryProvider>(
      builder: (context, categoryProvider, _) {
        final iconKey = categoryProvider.getIconForCategory(category);
        final iconData = iconMap[iconKey] ?? Icons.category;
        return Icon(iconData, size: 23, color: primaryColor(context));
      },
    );
  }
}

/// Category + title text
class _TransactionInfo extends StatelessWidget {
  final AllListProvider transaction;
  const _TransactionInfo({required this.transaction});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          transaction.category,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
          style: GoogleFonts.outfit(
            fontSize: 15,
            color: primaryColor(context),
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          transaction.title,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
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
