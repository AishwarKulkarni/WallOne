import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wallone/features/about_us/views/about_us.dart';
import 'package:wallone/features/ai_adviser/views/ai_ml_dashboard.dart';
import 'package:wallone/features/analytics/views/analytics.dart';
import 'package:wallone/features/budget/views/budget_page.dart';
import 'package:wallone/features/dashboard/views/dashboard.dart';
import 'package:wallone/features/onboarding/views/onboarding_page.dart';
import 'package:wallone/features/onboarding/views/user_setup.dart';
import 'package:wallone/features/settings/views/settings.dart';
import 'package:wallone/features/categories/views/category_management.dart';
import 'package:wallone/features/ai_adviser/views/tabs/ai_settings_tab.dart';
import 'package:wallone/features/transactions/views/add_transactions.dart';
import 'package:wallone/features/transactions/views/edit_transactions.dart';
import 'package:wallone/features/transactions/providers/list_provider.dart';
import 'package:wallone/core/utils/layout.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');
final GlobalKey<NavigatorState> _shellNavigatorDashboardKey =
    GlobalKey<NavigatorState>(debugLabel: 'shellDashboard');
final GlobalKey<NavigatorState> _shellNavigatorBudgetKey =
    GlobalKey<NavigatorState>(debugLabel: 'shellBudget');
final GlobalKey<NavigatorState> _shellNavigatorAddTransactionKey =
    GlobalKey<NavigatorState>(debugLabel: 'shellAddTransaction');
final GlobalKey<NavigatorState> _shellNavigatorAnalyticsKey =
    GlobalKey<NavigatorState>(debugLabel: 'shellAnalytics');
final GlobalKey<NavigatorState> _shellNavigatorAiKey =
    GlobalKey<NavigatorState>(debugLabel: 'shellAi');

class AppRouter {
  static GoRouter router({String? initialLocation}) {
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: initialLocation ?? '/layout',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingPage(),
        ),
        GoRoute(
          path: '/user_setup',
          builder: (context, state) => const UserSetupPage(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
        GoRoute(
          path: '/about',
          builder: (context, state) => const AboutUsPage(),
        ),
        GoRoute(
          path: '/category-management',
          builder: (context, state) => const CategoryManagementPage(),
        ),
        GoRoute(
          path: '/ai-settings',
          builder: (context, state) => const AISettingsTab(),
        ),
        GoRoute(
          path: '/edit-transaction',
          builder: (context, state) {
            final transaction = state.extra as AllListProvider;
            return EditTransactionPage(transaction: transaction);
          },
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return DesignLayout(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              navigatorKey: _shellNavigatorDashboardKey,
              routes: [
                GoRoute(
                  path: '/layout',
                  builder: (context, state) => DashboardPage(
                    onBalanceVisibilityChanged: (isVisible) {
                      // We'll manage this state in a provider or handle it differently
                    },
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              navigatorKey: _shellNavigatorBudgetKey,
              routes: [
                GoRoute(
                  path: '/budget',
                  builder: (context, state) => const BudgetPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              navigatorKey: _shellNavigatorAddTransactionKey,
              routes: [
                GoRoute(
                  path: '/add-transaction',
                  builder: (context, state) => const AddTransactionsPage(),
                ),
              ],
            ),
            StatefulShellBranch(
              navigatorKey: _shellNavigatorAnalyticsKey,
              routes: [
                GoRoute(
                  path: '/analytics',
                  builder: (context, state) => AnalyticsPage(
                    onSeeAllAIAdvisor: () {
                      context.go('/ai');
                    },
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              navigatorKey: _shellNavigatorAiKey,
              routes: [
                GoRoute(
                  path: '/ai',
                  builder: (context, state) => const AIAdvisorDashboard(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
