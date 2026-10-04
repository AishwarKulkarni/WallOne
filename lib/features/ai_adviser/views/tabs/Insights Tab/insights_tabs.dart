import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:wallone/features/ai_adviser/views/tabs/Insights%20Tab/widgets/insight_card.dart';
import 'package:wallone/features/ai_adviser/views/tabs/Insights%20Tab/widgets/placeholders.dart';
import 'package:wallone/features/ai_adviser/providers/adviser_provider.dart';
import 'package:wallone/core/utils/constants.dart';
import 'package:wallone/features/ai_adviser/services/rule_based_advisor.dart';

/// Enhanced Insights Tab with filtering and statistics
class InsightsTab extends StatefulWidget {
  const InsightsTab({super.key});

  @override
  State<InsightsTab> createState() => _InsightsTabState();
}

class _InsightsTabState extends State<InsightsTab> {
  InsightType? _selectedFilter;
  InsightPriority? _selectedPriority;

  @override
  Widget build(BuildContext context) {
    return Consumer<AIAdvisorProvider>(
      builder: (context, provider, child) {
        debugPrint('AI provider in builder: $provider');
        if (!provider.hasAdvisor) {
          return const SetupRequiredWidget();
        }

        if (!provider.isAIEnabled) {
          return const AIDisabledWidget();
        }

        if (provider.error != null) {
          return ErrorCustomWidget(error: provider.error!);
        }

        return RefreshIndicator(
          onRefresh: () => provider.refreshInsights(forceRefresh: true),
          child: CustomScrollView(
            slivers: [
              // Statistics Section
              _buildStatisticsSection(provider, context),

              // Filter Section
              _buildFilterSection(provider, context),

              // Insights List
              _buildInsightsList(provider),

              // Bottom padding
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.of(context).padding.bottom +
                      kBottomNavigationBarHeight +
                      50.0,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatisticsSection(
      AIAdvisorProvider provider, BuildContext context) {
    final stats = provider.getInsightsStatistics();

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, right: 16, left: 16, top: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: boxColor(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: shadowColor(context).withAlpha(20),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              'Insights Overview',
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryColor(context),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: _buildStatCard(
                        'Active',
                        stats['active'],
                        budgetBackgroundLight(context),
                        primaryColor(context),
                        context)),
                const SizedBox(width: 8),
                Expanded(
                    child: _buildStatCard(
                        'Actionable',
                        stats['actionable'],
                        budgetBackgroundLight(context),
                        primaryColor(context),
                        context)),
                const SizedBox(width: 8),
                Expanded(
                    child: _buildStatCard(
                        'High Priority',
                        stats['highPriority'],
                        budgetBackgroundLight(context),
                        primaryColor(context),
                        context)),
                const SizedBox(width: 8),
                Expanded(
                    child: _buildStatCard(
                        'Executed',
                        stats['executed'],
                        budgetBackgroundLight(context),
                        primaryColor(context),
                        context)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, int value, Color color, Color fontColor,
      BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value.toString(),
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: fontColor,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 10,
              color: fontColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(AIAdvisorProvider provider, BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // Type filters
              _buildFilterChip('All Types', _selectedFilter == null, () {
                setState(() {
                  _selectedFilter = null;
                });
              }, context),
              const SizedBox(width: 8),
              ...InsightType.values.map((type) => Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: _buildFilterChip(
                      type.name.toUpperCase(),
                      _selectedFilter == type,
                      () {
                        setState(() {
                          _selectedFilter =
                              _selectedFilter == type ? null : type;
                        });
                      },
                      context,
                    ),
                  )),

              Container(
                width: 1,
                height: 20,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: budgetTextLight(context),
              ),

              // Priority filters
              ...InsightPriority.values.map((priority) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildFilterChip(
                      priority.name.toUpperCase(),
                      _selectedPriority == priority,
                      () {
                        setState(() {
                          _selectedPriority =
                              _selectedPriority == priority ? null : priority;
                        });
                      },
                      context,
                      color: _getPriorityFilterColor(priority),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(
      String label, bool isSelected, VoidCallback onTap, BuildContext context,
      {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? (color ?? purpleColors(context))
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? (color ?? purpleColors(context))
                : budgetTextLight(context),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : budgetTextLight(context),
          ),
        ),
      ),
    );
  }

  Color _getPriorityFilterColor(InsightPriority priority) {
    switch (priority) {
      case InsightPriority.high:
        return Colors.red;
      case InsightPriority.medium:
        return Colors.orange;
      case InsightPriority.low:
        return Colors.green;
    }
  }

  Widget _buildInsightsList(AIAdvisorProvider provider) {
    var insights = provider.activeInsights;

    // Apply filters
    if (_selectedFilter != null) {
      insights =
          insights.where((insight) => insight.type == _selectedFilter).toList();
    }
    if (_selectedPriority != null) {
      insights = insights
          .where((insight) => insight.priority == _selectedPriority)
          .toList();
    }

    if (insights.isEmpty && !provider.isLoading) {
      return SliverToBoxAdapter(
        child: _buildEmptyState(context),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final insight = insights[index];
          return InsightCard(
            insight: insight,
            onRefresh: () => setState(() {}),
          );
        },
        childCount: insights.length,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
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
              backgroundColor: inversePrimaryColor(context),
              foregroundColor: primaryColor(context),
            ),
          ),
        ],
      ),
    );
  }
}
