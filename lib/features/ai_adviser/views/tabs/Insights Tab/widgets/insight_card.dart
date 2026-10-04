import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:wallone/features/ai_adviser/views/tabs/Insights%20Tab/widgets/execution_dialog.dart';
import 'package:wallone/features/ai_adviser/providers/adviser_provider.dart';
import 'package:wallone/core/utils/constants.dart';
import 'package:wallone/features/ai_adviser/services/rule_based_advisor.dart';

/// Enhanced InsightCard with dismissal and custom execution features
class InsightCard extends StatefulWidget {
  final FinancialInsight insight;
  final VoidCallback? onRefresh;

  const InsightCard({
    super.key,
    required this.insight,
    this.onRefresh,
  });

  @override
  State<InsightCard> createState() => _InsightCardState();
}

class _InsightCardState extends State<InsightCard> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final insight = widget.insight;
    final typeIcon = _getTypeIcon(insight.type);

    return Card(
      color: boxColor(context),
      elevation: 10,
      shadowColor: shadowColor(context),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with dismiss button
            Row(
              children: [
                Icon(typeIcon, size: 20, color: primaryColor(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    insight.title,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: primaryColor(context),
                    ),
                  ),
                ),
                _buildPriorityChip(insight.priority, context),
                const SizedBox(width: 8),
                // Dismiss button
                InkWell(
                  onTap: () => _dismissInsight(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Description
            Text(
              insight.description,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: budgetTextLight(context),
              ),
            ),

            const SizedBox(height: 12),

            // Bottom section with amount and actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Recommended amount
                if (insight.recommendedAmount != null)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: budgetBackgroundLight(context),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Recommended: ₹${insight.recommendedAmount!.toStringAsFixed(2)}',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: primaryColor(context),
                        ),
                      ),
                    ),
                  ),

                if (insight.recommendedAmount != null && insight.isActionable)
                  const SizedBox(width: 15),

                if (insight.recommendedAmount == null && insight.isActionable)
                  const Spacer(),

                // Action buttons
                if (insight.isActionable)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Quick apply button
                      SizedBox(
                        height: 28,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading ? null : () => _quickExecuteInsight(context),
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.flash_on, size: 11),
                          label: Text(
                            _isLoading ? 'Applying...' : 'Quick Apply',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: purpleColors(context),
                            foregroundColor: primaryColor(context),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            disabledBackgroundColor: purpleColors(context).withValues(alpha: 0.5),
                          ),
                        ),
                      ),

                      const SizedBox(width: 6),

                      // Custom apply button
                      SizedBox(
                        height: 28,
                        child: ElevatedButton.icon(
                          onPressed: () => _showCustomExecutionDialog(context),
                          icon: const Icon(Icons.tune, size: 13),
                          label: Text(
                            'Custom',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: budgetBackgroundLight(context),
                            foregroundColor: primaryColor(context),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            // Insight metadata
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  insight.type.name.toUpperCase(),
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (insight.targetCategory != null) ...[
                  Text(
                    ' • ${insight.targetCategory}',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                const Spacer(),
                Text(
                  _formatDateTime(insight.createdAt),
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityChip(InsightPriority priority, BuildContext context) {
    Color chipColor;
    switch (priority) {
      case InsightPriority.high:
        chipColor = Colors.red;
        break;
      case InsightPriority.medium:
        chipColor = Colors.orange;
        break;
      case InsightPriority.low:
        chipColor = Colors.green;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        priority.name.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _dismissInsight(BuildContext context) {
    final provider = context.read<AIAdvisorProvider>();
    provider.dismissInsight(widget.insight.id);

    showCustomSnackBar(
      context,
      'Dismissed: ${widget.insight.title}',
      actionLabel: "Undo",
      onAction: () {
        provider.restoreInsight(widget.insight.id);
      },
    );

    widget.onRefresh?.call();
  }

  Future<void> _quickExecuteInsight(BuildContext context) async {
    setState(() {
      _isLoading = true;
    });

    final provider = context.read<AIAdvisorProvider>();
    final success = await provider.executeInsight(widget.insight.id);

    if (!context.mounted) return;

    setState(() {
      _isLoading = false;
    });

    showCustomSnackBar(
      context,
      success ? 'Applied successfully!' : 'Failed to apply changes',
    );

    widget.onRefresh?.call();
  }

  void _showCustomExecutionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => CustomInsightExecutionDialog(
        insight: widget.insight,
        onExecuted: widget.onRefresh,
      ),
    );
  }

  IconData _getTypeIcon(InsightType type) {
    switch (type) {
      case InsightType.budget:
        return Icons.pie_chart;
      case InsightType.savings:
        return Icons.savings;
      case InsightType.investment:
        return Icons.trending_up;
      case InsightType.expense:
        return Icons.money_off;
      case InsightType.income:
        return Icons.attach_money;
      case InsightType.alert:
        return Icons.warning;
      case InsightType.general:
        return Icons.info;
    }
  }
}
