import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:wallone/features/ai_adviser/providers/adviser_provider.dart';
import 'package:wallone/features/budget/providers/budget_provider.dart';
import 'package:wallone/features/categories/providers/category_provider.dart';
import 'package:wallone/features/investments/providers/investment_provider.dart';
import 'package:wallone/core/theme/theme_provider.dart';
import 'package:wallone/features/dashboard/providers/balance_provider.dart';
import 'package:wallone/features/settings/providers/userprofile_provider.dart';
import 'package:wallone/core/utils/constants.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // profile data comes from UserProfileProvider — no local prefs load
  }

  Future<void> _pickImage() async {
    try {
      final XFile? picked =
          await _picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      if (!mounted) return;

      // Save via provider so everyone updates instantly
      await context.read<UserProfileProvider>().setImagePath(picked.path);

      // provider updated the profile image path — the UI watches provider

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile image updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  Future<void> _editName() async {
    final controller = TextEditingController(
        text: context.read<UserProfileProvider>().userName ?? '');
    final newName = await showDialog<String?>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadiusGeometry.circular(10),
          ),
          title: Text(
            'Edit Name',
            style: GoogleFonts.outfit(
              color: primaryColor(context),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: TextField(
            style: GoogleFonts.outfit(
              color: primaryColor(context),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            controller: controller,
            decoration: InputDecoration(
              labelText: 'Name',
              hintText: 'Enter your name',
              labelStyle: TextStyle(color: primaryColor(context)),
              hintStyle: TextStyle(color: budgetTextLight(context)),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: Text(
                'Cancel',
                style: GoogleFonts.outfit(
                  color: primaryColor(context),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                final val = controller.text.trim();
                Navigator.pop(context, val.isEmpty ? null : val);
              },
              child: Text(
                'Save',
                style: GoogleFonts.outfit(
                  color: primaryColor(context),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (newName == null) return;
    if (!mounted) return;
    // Save via provider; widgets which read provider will rebuild
    await context.read<UserProfileProvider>().setName(newName);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Name updated')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final profile = context.watch<UserProfileProvider>();
    final profileName = profile.userName;
    final profileImagePath = profile.coverImagePath;

    return Scaffold(
      onDrawerChanged: (isOpened) {
        // no-op — profile data lives in provider and will update listeners
      },

      //
      backgroundColor: mainColor(context),
      appBar: AppBar(
        title: Text(
          'Settings',
          style: GoogleFonts.outfit(
            color: primaryColor(context),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: primaryColor(context)),
            onPressed: () async {
              Navigator.pop(context);
            }),
        elevation: 0,
        backgroundColor: mainColor(context),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 20),
          // Profile Section
          Align(
            alignment: Alignment.center,
            child: Column(
              children: [
                // tappable avatar to change image
                Stack(
                  children: [
                    Container(
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
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return CircleAvatar(
                                    radius: 60,
                                    backgroundColor:
                                        purpleColors(context).withAlpha(50),
                                    child: Icon(
                                      Icons.person,
                                      size: 40,
                                      color: purpleColors(context),
                                    ),
                                  );
                                },
                              )
                            : CircleAvatar(
                                radius: 60,
                                backgroundColor:
                                    purpleColors(context).withAlpha(50),
                                child: Icon(
                                  Icons.person,
                                  size: 40,
                                  color: purpleColors(context),
                                ),
                              ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      top: 0,
                      child: IconButton(
                        onPressed: _pickImage,
                        icon: Icon(
                          Icons.add,
                          color: inversePrimaryColor(context),
                          size: 40,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // tappable name to edit
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 5,
                  children: [
                    Text(
                      profileName ?? "Guest User",
                      style: GoogleFonts.outfit(
                        color: primaryColor(context),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    InkWell(
                      onTap: _editName,
                      child: Icon(
                        Icons.edit_outlined,
                        color: primaryColor(context),
                        size: 17,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Appearance Section
          _buildSettingsSection(
            'Appearance',
            [
              ListTile(
                title: Text(
                  'Dark Mode',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: primaryColor(context),
                  ),
                ),
                subtitle: Text(
                  'Choose your preferred theme',
                  style: GoogleFonts.outfit(
                    color: budgetTextLight(context),
                  ),
                ),
                trailing: ThemeSwitcher(themeProvider: themeProvider),
              ),
            ],
            context,
          ),

          // Currency Section
          Consumer<BalanceProvider>(
            builder: (ctx, balanceProvider, _) {
              return _buildSettingsSection(
                'Currency',
                [
                  ListTile(
                    title: Text(
                      'Select Currency',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: primaryColor(context),
                      ),
                    ),
                    subtitle: Text(
                      'Current: ${balanceProvider.currencyCode}',
                      style: GoogleFonts.outfit(
                        color: budgetTextLight(context),
                      ),
                    ),
                    trailing: DropdownButton<String>(
                      value: balanceProvider.currencyCode,
                      borderRadius: BorderRadius.circular(8),
                      dropdownColor: boxColor(context),
                      underline: const SizedBox(),
                      icon: Icon(Icons.keyboard_arrow_down,
                          color: budgetTextLight(context)),
                      items: balanceProvider.supportedCurrencies.map((code) {
                        return DropdownMenuItem(
                          value: code,
                          child: Text(
                            code,
                            style: GoogleFonts.outfit(
                              color: primaryColor(context),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (newCode) {
                        if (newCode != null) {
                          balanceProvider.setCurrency(newCode);
                        }
                      },
                    ),
                  ),
                ],
                context,
              );
            },
          ),

          // Categories Section
          _buildSettingsSection(
            'Categories',
            [
              ListTile(
                title: Text(
                  'Manage Categories',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: primaryColor(context),
                  ),
                ),
                subtitle: Text(
                  'Add, edit, or remove expense categories',
                  style: GoogleFonts.outfit(
                    color: budgetTextLight(context),
                  ),
                ),
                trailing: Icon(Icons.arrow_forward_ios,
                    color: budgetTextLight(context), size: 18),
                onTap: () {
                  context.push('/category-management');
                },
              ),
            ],
            context,
          ),

          // AI Advisor Section
          _buildSettingsSection(
            'AI Advisor',
            [
              ListTile(
                title: Text(
                  'AI Advisor Settings',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: primaryColor(context),
                  ),
                ),
                subtitle: Text(
                  'Configure AI features and automation',
                  style: GoogleFonts.outfit(
                    color: budgetTextLight(context),
                  ),
                ),
                trailing: Icon(Icons.arrow_forward_ios,
                    color: budgetTextLight(context), size: 18),
                onTap: () {
                  context.push('/ai-settings');
                },
              ),
            ],
            context,
          ),

          // Reset Section
          _buildSettingsSection(
            'Data Management',
            [
              ListTile(
                title: Text(
                  'Reset App',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                subtitle: Text(
                  'Delete all app data and start fresh',
                  style: GoogleFonts.outfit(
                    color: budgetTextLight(context),
                  ),
                ),
                trailing: const Icon(Icons.restore, color: Colors.red),
                onTap: () async {
                  _handleReset(context);
                },
              ),
            ],
            context,
          ),

          const SizedBox(height: 85),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(
      String title, List<Widget> children, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
          ),
          child: Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: budgetTextLight(context),
            ),
          ),
        ),
        Card(
          elevation: 10,
          color: boxColor(context),
          shadowColor: shadowColor(context),
          child: Column(children: children),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _handleReset(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadiusGeometry.circular(10),
        ),
        title: Text(
          'Reset App?',
          style: GoogleFonts.outfit(
            color: primaryColor(context),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will delete all your data. This action cannot be undone.',
          style: GoogleFonts.outfit(
            color: primaryColor(context),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(
                color: primaryColor(context),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(
              'Reset',
              style: GoogleFonts.outfit(
                color: Colors.red,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final balanceProvider =
          Provider.of<BalanceProvider>(context, listen: false);
      final aiAdvisorProvider =
          Provider.of<AIAdvisorProvider>(context, listen: false);
      final categoryProvider =
          Provider.of<CategoryProvider>(context, listen: false);
      final budgetProvider =
          Provider.of<BudgetProvider>(context, listen: false);
      final investmentProvider =
          Provider.of<InvestmentProvider>(context, listen: false);

      await balanceProvider.resetApp(
        aiAdvisorProvider,
        context,
        categoryProvider: categoryProvider,
        budgetProvider: budgetProvider,
        investmentProvider: investmentProvider,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reset failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
