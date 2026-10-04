import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:wallone/features/ai_adviser/providers/adviser_provider.dart';
import 'package:wallone/features/dashboard/providers/balance_provider.dart';
import 'package:wallone/features/settings/providers/userprofile_provider.dart';
import 'package:wallone/core/utils/constants.dart';

import 'package:go_router/go_router.dart';

class DesignLayout extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const DesignLayout({super.key, required this.navigationShell});

  @override
  State<DesignLayout> createState() => _DesignLayoutState();
}

class _DesignLayoutState extends State<DesignLayout> {
  final bool _showAppBarBalance = false;

  void _onItemTapped(int index) {
    widget.navigationShell.goBranch(
      index,
      // A common pattern when using bottom navigation bars is to support
      // navigating to the initial location when tapping the item that is
      // already active.
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      // Drawer
      drawer: Drawer(
        backgroundColor: mainColor(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                  top: 70.0, left: 16.0, right: 16.0, bottom: 20),
              child: Card(
                color: primaryColor(context),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Consumer<UserProfileProvider>(
                    builder: (context, profile, child) {
                      final profileName = profile.userName ?? 'Guest User';
                      final profileImagePath = profile.coverImagePath;
                      return Row(
                        children: [
                          InkWell(
                            onTap: () {
                              context.push('/settings');
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                  color: mainColor(context),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: boxColor(context),
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: shadowColor(context),
                                      blurRadius: 5,
                                    )
                                  ]),
                              child: ClipOval(
                                child: profileImagePath != null &&
                                        File(profileImagePath).existsSync()
                                    ? Image.file(
                                        File(profileImagePath),
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                      )
                                    : CircleAvatar(
                                        radius: 20,
                                        backgroundColor: primaryColor(context),
                                        child: Icon(
                                          Icons.person,
                                          size: 20,
                                          color: inversePrimaryColor(context),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profileName,
                                  style: GoogleFonts.outfit(
                                    color: inversePrimaryColor(context),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  profileName,
                                  style: GoogleFonts.outfit(
                                    color: inversePrimaryColor(context),
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: ListTile(
                leading: Icon(Icons.home, color: primaryColor(context)),
                title: Text(
                  "Home",
                  style: GoogleFonts.outfit(
                    fontSize: screenWidth / 22,
                    color: primaryColor(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  context.pop();
                },
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: ListTile(
                leading: Icon(Icons.settings, color: primaryColor(context)),
                title: Text(
                  "Settings",
                  style: GoogleFonts.outfit(
                    fontSize: screenWidth / 22,
                    color: primaryColor(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  context.push('/settings');
                },
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: ListTile(
                leading: Icon(Icons.info, color: primaryColor(context)),
                title: Text(
                  "About Us",
                  style: GoogleFonts.outfit(
                    fontSize: screenWidth / 22,
                    color: primaryColor(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  context.push('/about');
                },
              ),
            ),
            const Spacer(),
            // Logout Button
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Card(
                color: boxColor(context),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: Icon(Icons.logout, color: primaryColor(context)),
                  title: Text(
                    "Logout",
                    style: GoogleFonts.outfit(
                      fontSize: screenWidth / 22,
                      color: primaryColor(context),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () async {
                    try {
                      final aiProvider = Provider.of<AIAdvisorProvider>(context,
                          listen: false);
                      aiProvider.reset();
                      // Sign out from Firebase
                      await FirebaseAuth.instance.signOut();

                      // Navigate back to UserSetupPage (or login page)
                      if (context.mounted) {
                        context.go('/user_setup');
                      }
                    } catch (e) {
                      // Optional: show error
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Failed to logout: $e")),
                      );
                    }
                  },
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),

      // App Bar
      appBar: AppBar(
        backgroundColor: mainColor(context),
        centerTitle: true,
        scrolledUnderElevation: 0,
        title: _AppBarBalanceTitle(
          selectedIndex: widget.navigationShell.currentIndex,
          showAppBarBalance: _showAppBarBalance,
        ),
        actions: [
          if (widget.navigationShell.currentIndex == 4)
            Consumer<AIAdvisorProvider>(
              builder: (context, provider, child) {
                return IconButton(
                  icon: provider.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  onPressed: provider.isLoading
                      ? null
                      : () => provider.refreshInsights(forceRefresh: true),
                );
              },
            ),
          Padding(
            padding: const EdgeInsets.only(right: 5.0),
            child: IconButton(
              onPressed: () {},
              icon: Icon(
                Icons.notifications_none,
                size: screenWidth / 17,
              ),
            ),
          ),
        ],
        elevation: 0,
      ),

      // Background Color
      backgroundColor: mainColor(context),

      extendBody: false,

      // Body
      body: Stack(
        children: [
          Positioned.fill(
            key: const ValueKey('NavigationShellPositioned'),
            child: widget.navigationShell,
          ),

          //

          Align(
            key: const ValueKey('BottomNavBarAlign'),
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                decoration: BoxDecoration(
                  color: boxColor(context),
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 15,
                      color: shadowColor(context),
                    )
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => _onItemTapped(0),
                      icon: Icon(
                        Icons.home_outlined,
                        size: 28,
                        color: widget.navigationShell.currentIndex == 0
                            ? primaryColor(context)
                            : null,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _onItemTapped(1),
                      icon: Icon(
                        Icons.account_balance_wallet_outlined,
                        size: 26,
                        color: widget.navigationShell.currentIndex == 1
                            ? primaryColor(context)
                            : null,
                      ),
                    ),
                    SizedBox(
                      child: FloatingActionButton(
                        elevation: 10,
                        onPressed: () {
                          context.push('/add-transaction');
                        },
                        backgroundColor: primaryColor(context),
                        child: Consumer<BalanceProvider>(
                          builder: (context, balanceProvider, child) {
                            final currencyCode = balanceProvider.currencyCode;
                            final symbol = NumberFormat.simpleCurrency(name: currencyCode).currencySymbol;
                            return Text(
                              symbol,
                              style: GoogleFonts.outfit(
                                fontSize: 25,
                                fontWeight: FontWeight.bold,
                                color: purpleColors(context),
                              ),
                            );
                          }
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _onItemTapped(3),
                      icon: Icon(
                        Icons.analytics_outlined,
                        size: 28,
                        color: widget.navigationShell.currentIndex == 3
                            ? primaryColor(context)
                            : null,
                      ),
                    ),
                    IconButton(
                      onPressed: () => _onItemTapped(4),
                      icon: Icon(
                        Icons.bolt,
                        size: 28,
                        color: widget.navigationShell.currentIndex == 4
                            ? primaryColor(context)
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A dedicated widget for the AppBar title that shows either the app name
/// or the current balance. Using [context.select] means only this widget
/// rebuilds when the balance changes — the rest of the Scaffold is untouched.
class _AppBarBalanceTitle extends StatelessWidget {
  final int selectedIndex;
  final bool showAppBarBalance;

  const _AppBarBalanceTitle({
    required this.selectedIndex,
    required this.showAppBarBalance,
  });

  @override
  Widget build(BuildContext context) {
    final showBalance = showAppBarBalance || selectedIndex != 0;

    if (!showBalance) {
      return Text(
        'Wall One',
        style: GoogleFonts.outfit(
          color: primaryColor(context),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    final totalBalance =
        context.select<BalanceProvider, double>((p) => p.totalBalance);
    final currencyCode =
        context.select<BalanceProvider, String>((p) => p.currencyCode);
    final symbol =
        NumberFormat.simpleCurrency(name: currencyCode).currencySymbol;

    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Hero(
        tag: 'balanceHero',
        child: Material(
          color: Colors.transparent,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, anim) {
              final offsetAnim = anim.drive(
                Tween<Offset>(
                  begin: const Offset(0, -0.18),
                  end: Offset.zero,
                ).chain(CurveTween(curve: Curves.easeOut)),
              );
              return SlideTransition(
                position: offsetAnim,
                child: FadeTransition(opacity: anim, child: child),
              );
            },
            child: Column(
              key: ValueKey(totalBalance),
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$symbol$totalBalance',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    color: primaryColor(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Total Balance',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: primaryColor(context),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
