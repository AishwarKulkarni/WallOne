import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:wallone/features/ai_adviser/views/tabs/Insights%20Tab/widgets/placeholders.dart';
import 'package:wallone/features/ai_adviser/providers/adviser_provider.dart';
import 'package:wallone/core/utils/constants.dart';
import 'package:wallone/features/analytics/utils/insight_helpers.dart';
import 'package:wallone/features/ai_adviser/services/rule_based_advisor.dart';

/// Minimal insight display widget - single container with key information
class MinimalInsightDisplay extends StatelessWidget {
  final VoidCallback? onTap;

  const MinimalInsightDisplay({
    super.key,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AIAdvisorProvider>(
      builder: (context, provider, child) {
        if (!provider.hasAdvisor) {
          return const SetupRequiredWidget();
        }

        if (!provider.isAIEnabled) {
          return const AIDisabledWidget();
        }

        if (provider.error != null) {
          return ErrorCustomWidget(error: provider.error!);
        }

        if (!provider.hasAdvisor ||
            !provider.isAIEnabled ||
            provider.insights.isEmpty) {
          return _buildEmptyState(context);
        }

        final highPriorityInsights = provider.insights
            .where((insight) => insight.priority == InsightPriority.high)
            .toList();

        final topInsight = highPriorityInsights.isNotEmpty
            ? highPriorityInsights.first
            : provider.insights.first;

        final healthScore = provider.getFinancialHealthScore();
        final totalInsights = provider.insights.length;
        final actionableCount =
            provider.insights.where((insight) => insight.isActionable).length;

        return Card(
          color: boxColor(context),
          elevation: 3,
          shadowColor: shadowColor(context),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with title and health score
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.psychology,
                            size: 20,
                            color: purpleColors(context),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'AI Insights',
                            style: GoogleFonts.outfit(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: primaryColor(context),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: insightHealthScoreColor(healthScore)
                              .withAlpha(30),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: insightHealthScoreColor(healthScore),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$healthScore',
                              style: GoogleFonts.outfit(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: insightHealthScoreColor(healthScore),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              insightHealthScoreIcon(healthScore),
                              size: 14,
                              color: insightHealthScoreColor(healthScore),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Top insight preview
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: budgetBackgroundLight(context),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: insightPriorityColor(topInsight.priority),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            insightTypeIcon(topInsight.type),
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                topInsight.title,
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: primaryColor(context),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                topInsight.description,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: budgetTextLight(context),
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (topInsight.recommendedAmount != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: budgetBackgroundLight(context),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '₹${formatInsightAmount(topInsight.recommendedAmount!)}',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: primaryColor(context),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Summary stats and action
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Stats
                      Row(
                        children: [
                          _buildStatChip(
                            context,
                            totalInsights.toString(),
                            'Total',
                            Icons.lightbulb_outline,
                          ),
                          const SizedBox(width: 8),
                          _buildStatChip(
                            context,
                            actionableCount.toString(),
                            'Actionable',
                            Icons.play_arrow,
                          ),
                        ],
                      ),

                      // View all button
                      Container(
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              purpleColors(context),
                              purpleColors(context).withAlpha(200),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ElevatedButton(
                          onPressed: onTap,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View All',
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: primaryColor(context),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 12,
                                color: primaryColor(context),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatChip(
      BuildContext context, String value, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: budgetBackgroundLight(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: primaryColor(context),
          ),
          const SizedBox(width: 2),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: primaryColor(context),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 10,
              color: budgetTextLight(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: boxColor(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.insights,
            size: 64,
            color: budgetTextLight(context),
          ),
          const SizedBox(height: 16),
          Text(
            'No Insights Available',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryColor(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your AI advisor is analyzing your financial data. New insights will appear here soon.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: budgetTextLight(context),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              final provider =
                  Provider.of<AIAdvisorProvider>(context, listen: false);
              provider.refreshInsights(forceRefresh: true);
            },
            icon: const Icon(Icons.refresh),
            label: Text(
              'Refresh Insights',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: purpleColors(context),
              foregroundColor: primaryColor(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Enhanced Insights Tab with minimal design
class EnhancedInsightsTab extends StatelessWidget {
  const EnhancedInsightsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AIAdvisorProvider>(
      builder: (context, provider, child) {
        if (!provider.hasAdvisor) {
          return const _SetupRequiredWidget();
        }

        if (!provider.isAIEnabled) {
          return const _AIDisabledWidget();
        }

        if (provider.error != null) {
          return _ErrorWidget(error: provider.error!);
        }

        if (provider.insights.isEmpty && !provider.isLoading) {
          return const _NoInsightsWidget();
        }

        return RefreshIndicator(
          onRefresh: () => provider.refreshInsights(forceRefresh: true),
          child: CustomScrollView(
            slivers: [
              // Minimal insights overview
              SliverToBoxAdapter(
                child: MinimalInsightDisplay(
                  onTap: () {
                    // Navigate to detailed insights page
                    context.go('/ai');
                  },
                ),
              ),

              // Additional content can be added here
              _buildQuickActions(provider, context),

              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).padding.bottom +
                      kBottomNavigationBarHeight +
                      10.0,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickActions(AIAdvisorProvider provider, BuildContext context) {
    final actionableInsights = provider.insights
        .where((insight) => insight.isActionable)
        .take(3)
        .toList();

    if (actionableInsights.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: boxColor(context),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: shadowColor(context).withAlpha(20),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: cardTextColor(context),
              ),
            ),
            const SizedBox(height: 12),
            ...actionableInsights
                .map((insight) => _buildQuickActionItem(context, insight)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionItem(BuildContext context, FinancialInsight insight) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: insightPriorityColor(insight.priority).withAlpha(30),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              insightTypeIcon(insight.type),
              size: 12,
              color: insightPriorityColor(insight.priority),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              insight.title,
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: cardTextColor(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: () => _executeInsight(context, insight.id),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
            ),
            child: Text(
              'Apply',
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: purpleColors(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _executeInsight(BuildContext context, String insightId) async {
    final provider = context.read<AIAdvisorProvider>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
      ),
    );

    final success = await provider.executeInsight(insightId);

    if (context.mounted) {
      Navigator.pop(context);
      showCustomSnackBar(
        context,
        success ? 'Action executed successfully!' : 'Failed to execute action',
      );
    }
  }
}

// Keep the existing setup/error widgets...
class _SetupRequiredWidget extends StatelessWidget {
  const _SetupRequiredWidget();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.settings, size: 64, color: budgetTextLight(context)),
          const SizedBox(height: 16),
          Text(
            'AI Advisor Setup Required',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryColor(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Rule-based advisor is active — no external API key required',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: budgetTextLight(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AIDisabledWidget extends StatelessWidget {
  const _AIDisabledWidget();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.smart_toy_outlined,
              size: 64, color: budgetTextLight(context)),
          const SizedBox(height: 16),
          Text(
            'AI Advisor Disabled',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryColor(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enable AI features in settings to get personalized insights',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: budgetTextLight(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              final provider = context.read<AIAdvisorProvider>();
              provider.setAIEnabled(true);
            },
            child: Text(
              'Enable AI Advisor',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: primaryColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  final String error;

  const _ErrorWidget({required this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: primaryColor(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: primaryColor(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                final provider = context.read<AIAdvisorProvider>();
                provider.refreshInsights(forceRefresh: true);
              },
              child: Text(
                'Try Again',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: primaryColor(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoInsightsWidget extends StatelessWidget {
  const _NoInsightsWidget();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 64,
            color: budgetTextLight(context),
          ),
          const SizedBox(height: 16),
          Text(
            'No insights yet',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryColor(context),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add some transactions and let AI analyze your spending patterns',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: primaryColor(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              final provider = context.read<AIAdvisorProvider>();
              provider.refreshInsights(forceRefresh: true);
            },
            child: Text(
              'Generate Insights',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                color: primaryColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
