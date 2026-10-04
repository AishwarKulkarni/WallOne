import 'dart:async';
import 'package:device_preview/device_preview.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wallone/firebase_options.dart';
import 'package:wallone/splash_screen.dart';
import 'package:wallone/core/routes/app_router.dart';
import 'package:wallone/features/ai_adviser/providers/adviser_provider.dart';
import 'package:wallone/features/dashboard/providers/balance_provider.dart';
import 'package:wallone/features/investments/providers/investment_provider.dart';
import 'package:wallone/features/budget/providers/budget_provider.dart';
import 'package:wallone/features/categories/providers/category_provider.dart';
import 'package:wallone/features/transactions/providers/list_provider.dart';
import 'package:wallone/core/theme/theme_provider.dart';
import 'package:wallone/features/transactions/providers/transaction_type_provider.dart';
import 'package:wallone/features/settings/providers/userprofile_provider.dart';
import 'package:wallone/core/services/purchase_service.dart';
import 'package:wallone/core/services/notification_service.dart';
import 'package:wallone/core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase FIRST
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  if (kDebugMode) {
    debugPrint('[main] Firebase initialized successfully');
  }

  // Initialize Notification Service
  try {
    if (kDebugMode) debugPrint('[main] Initializing NotificationService...');
    await NotificationService().initialize();
    if (kDebugMode) debugPrint('[main] NotificationService initialized');
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[main] NotificationService initialization error: $e');
    }
  }

  // Initialize Google Mobile Ads SDK
  try {
    await MobileAds.instance.initialize();
    if (kDebugMode) debugPrint('[main] MobileAds initialized');
  } catch (e) {
    if (kDebugMode) debugPrint('[main] MobileAds initialization error: $e');
  }

  // Initialize In-App Purchase Service
  try {
    if (kDebugMode) {
      debugPrint('[main] Initializing In-App Purchase service...');
    }
    await PurchaseService().initialize();
    if (kDebugMode) debugPrint('[main] In-App Purchase service initialized');
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('[main] In-App Purchase initialization error: $e');
      debugPrint('[main] Stack trace: $st');
    }
  }

  // Create providers in the correct order
  // Note: These now use Firestore internally, no BalanceStorage needed!
  if (kDebugMode) debugPrint('[Main] Creating Firestore-based providers...');

  final balanceProvider = BalanceProvider();
  final investmentProvider = InvestmentProvider();
  final listProvider = ListProvider(balanceProvider, investmentProvider);

  // Set up provider relationships BEFORE creating BudgetProvider
  if (kDebugMode) debugPrint('[Main] Setting up provider relationships...');

  // Set balance provider reference in investment provider
  investmentProvider.setBalanceProvider(balanceProvider);

  // Set list provider reference in balance provider
  balanceProvider.setListProvider(listProvider);

  // Set list provider reference in investment provider
  investmentProvider.setListProvider(listProvider);

  if (kDebugMode) {
    debugPrint('[Main] Provider relationships established:');
    debugPrint(
        '  - InvestmentProvider has BalanceProvider: ${investmentProvider.balanceProvider != null}');
    debugPrint(
        '  - InvestmentProvider has ListProvider: ${investmentProvider.listProvider != null}');
    debugPrint(
        '  - BalanceProvider has ListProvider: ${balanceProvider.listProvider != null}');
  }

  // Wait a bit to ensure all async initialization is complete
  await Future.delayed(const Duration(milliseconds: 100));

  // Create BudgetProvider after all relationships are established
  final budgetProvider =
      BudgetProvider(balanceProvider, investmentProvider, listProvider);

  final aiAdvisorProvider = AIAdvisorProvider();

  // Wire up a quick refresh when new transactions are added.
  // Use a short debounce to avoid spamming the AI service when multiple
  // transactions are created in quick succession.
  Timer? aiRefreshTimer;
  listProvider.onTransactionAdded = (transaction) {
    try {
      aiRefreshTimer?.cancel();
      aiRefreshTimer = Timer(const Duration(milliseconds: 800), () async {
        try {
          // If the advisor is not ready this call will be a no-op.
          await aiAdvisorProvider.refreshInsights(forceRefresh: true);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[Main] Error refreshing AI insights: $e');
          }
        }
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Main] Error setting up AI refresh timer: $e');
      }
    }
  };

  if (kDebugMode) debugPrint('[Main] All providers initialized and linked');

  runApp(
    DevicePreview(
      enabled: kDebugMode,
      builder: (context) => MultiProvider(
        providers: [
          // Use .value for pre-created instances
          ChangeNotifierProvider<BalanceProvider>.value(value: balanceProvider),
          ChangeNotifierProvider<InvestmentProvider>.value(
              value: investmentProvider),
          ChangeNotifierProvider<ListProvider>.value(value: listProvider),
          ChangeNotifierProvider<BudgetProvider>.value(value: budgetProvider),

          // Create new instances for these (now use Firestore)
          ChangeNotifierProvider(create: (_) => TransactionTypeProvider()),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => CategoryProvider()),
          ChangeNotifierProvider<AIAdvisorProvider>.value(
              value: aiAdvisorProvider),

          // UserProfileProvider now handles purchase service internally
          ChangeNotifierProvider(create: (_) => UserProfileProvider()),
        ],
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool? _hasSeenOnboarding;
  GoRouter? _router;
  StreamSubscription<User?>? _authSubscription;
  bool _aiInitialized = false;

  @override
  void initState() {
    super.initState();

    if (kDebugMode) {
      debugPrint('[MyApp] initState called');
    }

    // Start with null (loading state), load from Firestore
    _hasSeenOnboarding = null;
    _loadHasSeenOnboarding();

    // Add observer for app lifecycle
    WidgetsBinding.instance.addObserver(this);

    // Listen to auth state changes to properly manage AI settings
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        _handleAuthStateChange(user);
      }
    });

    // Defer AI initialization until after the first frame to avoid
    // notifying providers during the widget build phase.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAI();
    });
  }

  Future<void> _handleAuthStateChange(User? user) async {
    try {
      final aiProvider = context.read<AIAdvisorProvider>();

      if (user == null) {
        // User logged out - reset AI settings
        if (kDebugMode) debugPrint('[MyApp] User logged out - resetting AI');
        aiProvider.reset();
        _aiInitialized = false;
      } else {
        // User logged in - reinitialize AI if needed
        if (kDebugMode) {
          debugPrint('[MyApp] User logged in - reinitializing AI');
        }

        // Short delay to ensure auth is fully settled
        await Future.delayed(const Duration(milliseconds: 300));

        if (mounted && !_aiInitialized) {
          await _initializeAI();
        }
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[MyApp] Error handling auth state change: $e');
        debugPrint('[MyApp] Stack trace: $st');
      }
    }
  }

  Future<void> _loadHasSeenOnboarding() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      bool value = false;
      
      if (uid == null) {
        if (kDebugMode) {
          debugPrint('[MyApp] No user logged in, hasSeenOnboarding -> false');
        }
      } else {
        final userDoc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        value = userDoc.data()?['hasSeenOnboarding'] as bool? ?? false;
        if (kDebugMode) {
          debugPrint('[MyApp] _loadHasSeenOnboarding from Firestore -> $value');
        }
      }

      // Instantiate router outside setState so if it throws, we don't end up with partial state
      final newRouter = AppRouter.router(
          initialLocation: value ? '/layout' : '/onboarding');

      if (mounted) {
        setState(() {
          _router = newRouter;
          _hasSeenOnboarding = value;
        });
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[MyApp] Error loading hasSeenOnboarding: $e\n$st');
      }
      // Default to false if there's an error
      try {
        final fallbackRouter = AppRouter.router(initialLocation: '/onboarding');
        if (mounted) {
          setState(() {
            _router = fallbackRouter;
            _hasSeenOnboarding = false;
          });
        }
      } catch (routerError, routerSt) {
        if (kDebugMode) {
           debugPrint('[MyApp] CRITICAL: Failed to instantiate fallback router: $routerError\n$routerSt');
        }
      }
    }
  }

  Future<void> _initializeAI() async {
    try {
      if (kDebugMode) {
        debugPrint('[MyApp] Initializing AI advisor...');
      }

      final aiProvider = context.read<AIAdvisorProvider>();
      final balanceProvider = context.read<BalanceProvider>();
      final investmentProvider = context.read<InvestmentProvider>();
      final budgetProvider = context.read<BudgetProvider>();
      final listProvider = context.read<ListProvider>();
      final categoryProvider = context.read<CategoryProvider>();

      // Initialize the rule-based advisor (no API key required)
      await aiProvider.initializeAdvisor(
        balanceProvider: balanceProvider,
        investmentProvider: investmentProvider,
        budgetProvider: budgetProvider,
        listProvider: listProvider,
        categoryProvider: categoryProvider,
      );
      if (!mounted) return;

      // ✅ CRITICAL FIX: Wait for UserProfileProvider to load premium status
      final userProfileProvider = context.read<UserProfileProvider>();

      // Check if user is logged in
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        if (kDebugMode) {
          debugPrint('[MyApp] Waiting for UserProfileProvider to load...');
        }

        // Give UserProfileProvider time to load from Firestore
        // We'll check its premium status directly from Firestore to be safe
        final uid = user.uid;
        final userDoc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();

        final isPremium = userDoc.data()?['isPremium'] ?? false;

        if (kDebugMode) {
          debugPrint('[MyApp] User premium status from Firestore: $isPremium');
          debugPrint(
              '[MyApp] UserProfileProvider isPremium: ${userProfileProvider.isPremium}');
        }

        // Load AI settings based on actual premium status
        await aiProvider.loadUserSettings(isPremium);

        _aiInitialized = true;

        if (kDebugMode) {
          debugPrint('[MyApp] AI advisor initialized successfully');
          debugPrint('[MyApp] AI enabled: ${aiProvider.isAIEnabled}');
        }
      } else {
        if (kDebugMode) {
          debugPrint('[MyApp] No user logged in, skipping AI settings load');
        }
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[MyApp] Error initializing AI: $e');
        debugPrint('[MyApp] Stack trace: $st');
      }
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    // Safely ensure _router is initialized if we have onboarding status but it was somehow null
    if (_hasSeenOnboarding != null && _router == null) {
      try {
        _router = AppRouter.router(
            initialLocation: _hasSeenOnboarding! ? '/layout' : '/onboarding');
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[MyApp] Failed to lazy-init router in build: $e');
        }
      }
    }

    // While we are still loading or if router failed to initialize, show the custom splash screen
    if (_hasSeenOnboarding == null || _router == null) {
      return MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeProvider.themeMode,
        debugShowCheckedModeBanner: false,
        home: const SplashScreen(),
      );
    }

    return MaterialApp.router(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      debugShowCheckedModeBanner: false,
      routerConfig: _router,
    );
  }
}
