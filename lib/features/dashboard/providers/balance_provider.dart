import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import 'package:wallone/features/dashboard/models/balance_model.dart';
import 'package:wallone/features/ai_adviser/providers/adviser_provider.dart';
import 'package:wallone/features/budget/providers/budget_provider.dart';
import 'package:wallone/features/categories/providers/category_provider.dart';
import 'package:wallone/features/investments/providers/investment_provider.dart';
import 'package:wallone/features/transactions/providers/list_provider.dart';

/// Firestore structure (Option 2) - FIXED:
/// users/{uid}/balances  -- doc with current values (map)
/// users/{uid}/balances/history/{yyyy-MM-dd}  -- doc { totalBalance: number, ts: Timestamp }
class BalanceProvider extends ChangeNotifier {
  final String _tag = 'BalanceProvider';
  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Currency
  String _currencyCode = 'INR';
  final List<String> supportedCurrencies = ['INR', 'USD', 'EUR', 'GBP', 'JPY'];
  String get currencyCode => _currencyCode;

  // Local cache of balance model
  BalanceModel _balance = const BalanceModel();
  bool _showDateTimePicker = false;

  // External providers / dependencies
  ListProvider? _listProvider;
  ListProvider? get listProvider => _listProvider;

  // Firestore subscription
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _balancesSub;
  StreamSubscription<User?>? _authSub;

  // Constructor
  BalanceProvider() {
    _loadFromLocal();
    _initListener();
  }

  Future<void> _loadFromLocal() async {
    try {
      const storage = FlutterSecureStorage();

      final str = await storage.read(key: 'cached_balance_model');
      if (str != null) {
        final map = jsonDecode(str);
        // Cast values to double where needed, or let BalanceModel.fromMap handle it if it uses _toDouble
        _balance = BalanceModel.fromMap(map);
        notifyListeners();
      }

      final cur = await storage.read(key: 'cached_currencyCode');
      if (cur != null && supportedCurrencies.contains(cur)) {
        _currencyCode = cur;
        notifyListeners();
      }
    } catch (e) {
      _log('Error loading local cache: $e');
    }
  }

  Future<void> _saveToLocal() async {
    try {
      const storage = FlutterSecureStorage();
      await storage.write(
          key: 'cached_balance_model', value: jsonEncode(_balance.toMap()));
      await storage.write(key: 'cached_currencyCode', value: _currencyCode);
    } catch (e) {
      _log('Error saving local cache: $e');
    }
  }

  void _log(String message) => debugPrint('[$_tag] $message');
  void _logError(String message, dynamic error, StackTrace? st) {
    debugPrint('[$_tag] ERROR: $message');
    if (error != null) debugPrint('[$_tag] Exception: $error');
    if (st != null) debugPrint('[$_tag] Stack: $st');
  }

  // ---------------------------
  // Authentication-aware listener
  // ---------------------------
  void _initListener() {
    _authSub = _auth.authStateChanges().listen((user) {
      // cancel previous sub
      _balancesSub?.cancel();
      _balancesSub = null;

      if (user == null) {
        // clear local state on sign out
        _balance = const BalanceModel();
        notifyListeners();
      } else {
        _subscribeToBalancesDoc(user.uid);
      }
    });
  }

  DocumentReference<Map<String, dynamic>>? _balancesDocRefForUid(String? uid) {
    if (uid == null) return null;
    return _fs
        .collection('users')
        .doc(uid)
        .collection('balances')
        .doc('current');
    // Note: Using a nested collection `balances` with a single doc `current`.
    // History subcollection is under this `current` doc: balances/current/history/{date}
  }

  void _subscribeToBalancesDoc(String uid) {
    try {
      final docRef = _balancesDocRefForUid(uid);
      if (docRef == null) return;

      _balancesSub = docRef.snapshots().listen((snap) async {
        if (!snap.exists) {
          _log('balances doc does not exist yet for uid=$uid');
          _balance = const BalanceModel();
          notifyListeners();
          return;
        }

        final data = snap.data() ?? {};
        try {
          // Ensure we run reset-checks first so the in-memory model reflects any resets
          await checkAndResetIfNeeded(data, docRef);

          // Refresh data map in case checkAndResetIfNeeded modified the document
          final refreshed = await docRef.get();
          final freshData = refreshed.exists ? refreshed.data() ?? {} : data;

          _balance = BalanceModel.fromMap({
            'totalBalance': _toDouble(data['totalBalance']),
            'dailyExpenses': _toDouble(
                freshData['dailyExpenses'] ?? freshData['dailyExpense']),
            'weeklyExpenses': _toDouble(
                freshData['weeklyExpenses'] ?? freshData['weeklyExpense']),
            'monthlyExpenses': _toDouble(
                freshData['monthlyExpenses'] ?? freshData['monthlyExpense']),
            'dailyIncomes': _toDouble(
                freshData['dailyIncomes'] ?? freshData['dailyIncome']),
            'weeklyIncomes': _toDouble(
                freshData['weeklyIncomes'] ?? freshData['weeklyIncome']),
            'monthlyIncomes': _toDouble(
                freshData['monthlyIncomes'] ?? freshData['monthlyIncome']),
            'lastResetDate':
                freshData['lastResetDate'] ?? freshData['dailyKey'],
            'totalInvestments': _toDouble(freshData['totalInvestments']),
          });
          _saveToLocal();

          // Load currency from user doc
          _loadCurrencyForUid(uid);

          // Automatic reset logic removed — no-op here.
        } catch (e, st) {
          _logError('Error parsing balances doc', e, st);
          _balance = const BalanceModel();
        }

        notifyListeners();
      }, onError: (e, st) {
        _logError('Balances snapshot error', e, st);
        _balance = const BalanceModel();
        notifyListeners();
      });
    } catch (e, st) {
      _logError('Failed to subscribe to balances doc', e, st);
    }
  }

  Future<void> _loadCurrencyForUid(String uid) async {
    try {
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();

      if (userDoc.exists) {
        final currency = userDoc.data()?['currencyCode'] as String?;
        if (currency != null && supportedCurrencies.contains(currency)) {
          _currencyCode = currency;
        }
      }
    } catch (e) {
      _log('Error loading currency: $e');
    }
  }

  // ---------------------------
  // Helper: Safe double conversion
  // ---------------------------
  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    try {
      return double.parse(value.toString());
    } catch (_) {
      return 0.0;
    }
  }

  // ---------------------------
  // Getters (expose model properties)
  // ---------------------------
  double get totalBalance => _balance.totalBalance;
  double get dailyExpenses => _balance.dailyExpenses;
  double get weeklyExpenses => _balance.weeklyExpenses;
  double get monthlyExpenses => _balance.monthlyExpenses;
  double get dailyIncomes => _balance.dailyIncomes;
  double get weeklyIncomes => _balance.weeklyIncomes;
  double get monthlyIncomes => _balance.monthlyIncomes;

  String get formattedTotalBalance => _balance.formattedTotalBalance;
  String get formattedDailyExpenses => _balance.formattedDailyExpenses;
  String get formattedWeeklyExpenses => _balance.formattedWeeklyExpenses;
  String get formattedMonthlyExpenses => _balance.formattedMonthlyExpenses;
  String get formattedDailyIncomes => _balance.formattedDailyIncomes;
  String get formattedWeeklyIncomes => _balance.formattedWeeklyIncomes;
  String get formattedMonthlyIncomes => _balance.formattedMonthlyIncomes;

  bool get showDateTimePicker => _showDateTimePicker;

  Map<String, dynamic> toJson() => {'balance': _balance};

  // ---------------------------
  // Setters / UI helpers
  // ---------------------------
  void setCurrency(String newCode) {
    if (newCode == _currencyCode) return;
    _currencyCode = newCode;
    _saveToLocal();

    // Save to Firestore
    _saveCurrencyToFirestore(newCode);

    notifyListeners();
  }

  Future<void> _saveCurrencyToFirestore(String currencyCode) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) {
        _log('No user logged in, skipping currency save');
        return;
      }

      await _fs.collection('users').doc(uid).set({'currencyCode': currencyCode},
          SetOptions(merge: true)).catchError((e) {
        _logError('Failed to save currency to Firestore', e, null);
      });
      _log('Currency queued to save to Firestore: $currencyCode');
    } catch (e, st) {
      _logError('Failed to save currency to Firestore', e, st);
    }
  }

  void toggleDateTimePicker() {
    _showDateTimePicker = !_showDateTimePicker;
    notifyListeners();
  }

  void setListProvider(ListProvider listProvider) {
    _listProvider = listProvider;
    // attempt to load transactions if available
    listProvider.loadTransactions().catchError((e, st) {
      _logError('Error loading transactions', e, st);
    });
  }

  // ---------------------------
  // Firestore helpers
  // ---------------------------
  DocumentReference<Map<String, dynamic>>? _currentBalancesDocRef() {
    final uid = _auth.currentUser?.uid;
    return _balancesDocRefForUid(uid);
  }

  CollectionReference<Map<String, dynamic>>? _historyCollectionRef() {
    final currentDoc = _currentBalancesDocRef();
    if (currentDoc == null) return null;
    return currentDoc.collection('history');
  }

  // Load balances once (non-listening fallback)
  Future<void> loadBalancesOnce() async {
    try {
      _log('Loading balances once...');
      final docRef = _currentBalancesDocRef();
      if (docRef == null) {
        _log('No user signed in - returning default balances');
        _balance = const BalanceModel();
        notifyListeners();
        return;
      }

      final snap = await docRef.get();
      if (!snap.exists) {
        _balance = const BalanceModel();
        notifyListeners();
        return;
      }

      final data = snap.data() ?? {};

      // Run reset-check on manual load as well
      await checkAndResetIfNeeded(data, docRef);

      // reload in case document was modified
      final refreshed = await docRef.get();
      final freshData = refreshed.exists ? refreshed.data() ?? {} : data;

      _balance = BalanceModel.fromMap({
        'totalBalance': _toDouble(freshData['totalBalance']),
        'dailyExpenses':
            _toDouble(freshData['dailyExpenses'] ?? freshData['dailyExpense']),
        'weeklyExpenses': _toDouble(
            freshData['weeklyExpenses'] ?? freshData['weeklyExpense']),
        'monthlyExpenses': _toDouble(
            freshData['monthlyExpenses'] ?? freshData['monthlyExpense']),
        'dailyIncomes':
            _toDouble(freshData['dailyIncomes'] ?? freshData['dailyIncome']),
        'weeklyIncomes':
            _toDouble(freshData['weeklyIncomes'] ?? freshData['weeklyIncome']),
        'monthlyIncomes': _toDouble(
            freshData['monthlyIncomes'] ?? freshData['monthlyIncome']),
        'lastResetDate': freshData['lastResetDate'] ?? freshData['dailyKey'],
        'totalInvestments': _toDouble(freshData['totalInvestments']),
      });
      _saveToLocal();
      notifyListeners();
      _log('Balances loaded');
    } catch (e, st) {
      _logError('Failed to load balances once', e, st);
      _balance = const BalanceModel();
      notifyListeners();
    }
  }

  // Save balances to Firestore 'current' doc
  Future<void> saveBalances() async {
    try {
      final docRef = _currentBalancesDocRef();
      if (docRef == null) {
        throw Exception('User must be signed in to save balances');
      }

      final map = _balance.toMap();
      docRef.set(map, SetOptions(merge: true)).catchError((e) {
        _logError('Failed to save balances to Firestore: $e', null, null);
      });
      _log('Queued balances for Firestore save');

      // also save today's snapshot automatically
      try {
        saveBalanceSnapshot(DateTime.now(), _balance.totalBalance); // no await
      } catch (e, st) {
        // ignore snapshot errors, but log
        _logError('Failed to save snapshot', e, st);
      }
    } catch (e, st) {
      _logError('Failed to save balances', e, st);
    }
  }

  // Save daily snapshot into history subcollection; prune older than maxDays
  Future<void> saveBalanceSnapshot(DateTime date, double totalBalance,
      {int maxDays = 30}) async {
    try {
      final historyRef = _historyCollectionRef();
      if (historyRef == null) {
        _log('No user signed in - cannot save snapshot');
        return;
      }

      final key = _dateKey(date);
      final docRef = historyRef.doc(key);
      docRef.set({
        'totalBalance': totalBalance,
        'ts': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).catchError((e) {
        _logError('Failed to save snapshot to Firestore: $e', null, null);
      });

      _log('Queued snapshot for $key');

      // prune older than maxDays
      final cutoff = DateTime.now().subtract(Duration(days: maxDays));
      final cutoffKey = _dateKey(cutoff);

      // Query all history docs ordered by id (date string) ascending and delete older ones.
      // Note: If history is large, consider adding server-side pruning function instead.
      final oldDocs = await historyRef
          .orderBy(FieldPath.documentId)
          .endBefore([cutoffKey])
          .limit(100) // batch limit; loop could be added for larger datasets
          .get();

      if (oldDocs.docs.isNotEmpty) {
        final batch = _fs.batch();
        for (final d in oldDocs.docs) {
          batch.delete(d.reference);
        }
        batch.commit().catchError((e) {
          _logError('Failed to prune snapshots on Firestore: $e', null, null);
        });
        _log(
            'Queued pruning of ${oldDocs.docs.length} old history docs older than $cutoffKey');
      }
    } catch (e, st) {
      _logError('Failed to save/prune balance snapshot', e, st);
    }
  }

  // Load balance history into a map date->value
  Future<Map<String, double>> loadBalanceHistory({int maxDays = 365}) async {
    try {
      final historyRef = _historyCollectionRef();
      if (historyRef == null) return {};

      // fetch limited history (e.g., last maxDays entries)
      final cutoff = DateTime.now().subtract(Duration(days: maxDays));
      final cutoffKey = _dateKey(cutoff);

      final querySnapshot = await historyRef
          .orderBy(FieldPath.documentId, descending: true)
          .startAfter([cutoffKey])
          .limit(1000)
          .get();

      final Map<String, double> out = {};
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final val = data['totalBalance'];
        if (val != null) {
          try {
            out[doc.id] = _toDouble(val);
          } catch (_) {
            // Skip invalid entries
          }
        }
      }
      return out;
    } catch (e, st) {
      _logError('Failed to load balance history', e, st);
      return {};
    }
  }

  /// FIXED: Added method to save balance history
  Future<void> saveBalanceHistory(Map<String, double> history) async {
    try {
      final historyRef = _historyCollectionRef();
      if (historyRef == null) {
        _log('No user signed in - cannot save balance history');
        return;
      }

      // Save each entry in the history map to Firestore
      final batch = _fs.batch();
      int count = 0;
      history.forEach((dateKey, balance) {
        final docRef = historyRef.doc(dateKey);
        batch.set(
            docRef,
            {
              'totalBalance': balance,
              'ts': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true));
        count++;

        // Firestore batch limit is 500 operations
        if (count >= 500) {
          // In a real scenario, you'd need to commit this batch and start a new one
          // For simplicity, we'll just log a warning
          _log('Warning: More than 500 history entries, some may not be saved');
        }
      });

      batch.commit().catchError((e) {
        _logError('Batch commit failed for saveBalanceHistory: $e', null, null);
      });
      _log('Queued ${history.length} balance history entries to Firestore');
    } catch (e, st) {
      _logError('Failed to save balance history', e, st);
    }
  }

  // Get balance for exact date or nearest earlier
  Future<double?> getBalanceForDate(DateTime date) async {
    try {
      final historyRef = _historyCollectionRef();
      if (historyRef == null) return null;

      final key = _dateKey(date);
      // Try exact match first
      final exact = await historyRef.doc(key).get();
      if (exact.exists) {
        final d = exact.data();
        final v = d?['totalBalance'];
        if (v != null) {
          return _toDouble(v);
        }
      }

      // If not exact, find the latest doc with id <= key (i.e., the nearest earlier date)
      // We can query documents with id <= key by ordering by id descending and starting at key.
      // Firestore doesn't support direct <= comparisons on doc ID, so we query descending and filter.
      final query = await historyRef
          .orderBy(FieldPath.documentId, descending: true)
          .startAt([key])
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        final v = data['totalBalance'];
        if (v != null) {
          return _toDouble(v);
        }
      }

      // fallback to scanning a small batch of previous docs
      final prevQuery = await historyRef
          .orderBy(FieldPath.documentId, descending: true)
          .limit(50)
          .get();

      DateTime? best;
      String? bestId;
      for (final doc in prevQuery.docs) {
        try {
          final d = DateTime.parse(doc.id);
          if (!d.isAfter(date)) {
            if (best == null || d.isAfter(best)) {
              best = d;
              bestId = doc.id;
            }
          }
        } catch (_) {
          // Skip invalid date doc IDs
        }
      }
      if (bestId != null) {
        final doc = await historyRef.doc(bestId).get();
        final val = doc.data()?['totalBalance'];
        if (val != null) return _toDouble(val);
      }

      return null;
    } catch (e, st) {
      _logError('Failed to get balance for date', e, st);
      return null;
    }
  }

  /// FIXED: Added getSavedBalanceForDate method (alias for getBalanceForDate)
  Future<double?> getSavedBalanceForDate(DateTime date) async {
    return await getBalanceForDate(date);
  }

  // ---------------------------
  // Balance operations (update local model + persist)
  // ---------------------------
  Future<void> _persistAfterChange() async {
    // persist but don't await everywhere - caller awaits saveBalances when needed
    _saveToLocal();
    saveBalances(); // Fire and forget
  }

  void addIncome(double amount) {
    try {
      _log('Adding income: $amount');
      final now = DateTime.now();
      final currentDailyKey = dayKey(now);
      final currentWeeklyKey = weekKey(now);
      final currentMonthlyKey = monthKey(now);

      _balance = _balance.copyWith(
        totalBalance: _balance.totalBalance + amount,
        dailyIncomes: _balance.dailyIncomes + amount,
        weeklyIncomes: _balance.weeklyIncomes + amount,
        monthlyIncomes: _balance.monthlyIncomes + amount,
        dailyKey: currentDailyKey,
        weeklyKey: currentWeeklyKey,
        monthlyKey: currentMonthlyKey,
      );
      notifyListeners();
      _persistAfterChange();
    } catch (e, st) {
      _logError('Failed to add income', e, st);
    }
  }

  void addExpense(double amount) {
    try {
      _log('Adding expense: $amount');
      final now = DateTime.now();
      final currentDailyKey = dayKey(now);
      final currentWeeklyKey = weekKey(now);
      final currentMonthlyKey = monthKey(now);

      _balance = _balance.copyWith(
        totalBalance: _balance.totalBalance - amount,
        dailyExpenses: _balance.dailyExpenses + amount,
        weeklyExpenses: _balance.weeklyExpenses + amount,
        monthlyExpenses: _balance.monthlyExpenses + amount,
        dailyKey: currentDailyKey,
        weeklyKey: currentWeeklyKey,
        monthlyKey: currentMonthlyKey,
      );
      notifyListeners();
      _persistAfterChange();
    } catch (e, st) {
      _logError('Failed to add expense', e, st);
    }
  }

  void deductBalanceOnDelete(double amount) {
    try {
      _log('Deducting balance on delete: $amount');
      final now = DateTime.now();
      final currentDailyKey = dayKey(now);
      final currentWeeklyKey = weekKey(now);
      final currentMonthlyKey = monthKey(now);

      _balance = _balance.copyWith(
        totalBalance: _balance.totalBalance + amount,
        dailyExpenses: _balance.dailyExpenses - amount,
        weeklyExpenses: _balance.weeklyExpenses - amount,
        monthlyExpenses: _balance.monthlyExpenses - amount,
        dailyKey: currentDailyKey,
        weeklyKey: currentWeeklyKey,
        monthlyKey: currentMonthlyKey,
      );
      notifyListeners();
      _persistAfterChange();
    } catch (e, st) {
      _logError('Failed to deduct balance on delete', e, st);
    }
  }

  void deductBalanceForIncome(double amount) {
    try {
      _log('Deducting balance for income: $amount');
      final now = DateTime.now();
      final currentDailyKey = dayKey(now);
      final currentWeeklyKey = weekKey(now);
      final currentMonthlyKey = monthKey(now);

      _balance = _balance.copyWith(
        totalBalance: _balance.totalBalance - amount,
        dailyIncomes: _balance.dailyIncomes - amount,
        weeklyIncomes: _balance.weeklyIncomes - amount,
        monthlyIncomes: _balance.monthlyIncomes - amount,
        dailyKey: currentDailyKey,
        weeklyKey: currentWeeklyKey,
        monthlyKey: currentMonthlyKey,
      );
      notifyListeners();
      _persistAfterChange();
    } catch (e, st) {
      _logError('Failed to deduct balance for income', e, st);
    }
  }

  // ---------------------------
  // Reset methods (daily/weekly/monthly)
  // ---------------------------
  void resetDailyValues() {
    try {
      _log('Resetting daily values');
      _balance = _balance.copyWith(dailyExpenses: 0, dailyIncomes: 0);
      notifyListeners();
      _persistAfterChange();
    } catch (e, st) {
      _logError('Failed to reset daily values', e, st);
    }
  }

  void resetWeeklyValues() {
    try {
      _log('Resetting weekly values');
      _balance = _balance.copyWith(weeklyExpenses: 0, weeklyIncomes: 0);
      notifyListeners();
      _persistAfterChange();
    } catch (e, st) {
      _logError('Failed to reset weekly values', e, st);
    }
  }

  void resetMonthlyValues() {
    try {
      _log('Resetting monthly values');
      _balance = _balance.copyWith(monthlyExpenses: 0, monthlyIncomes: 0);
      notifyListeners();
      _persistAfterChange();
    } catch (e, st) {
      _logError('Failed to reset monthly values', e, st);
    }
  }

  // Save/Load last reset dates on current doc
  Future<void> saveLastResetDate(DateTime date) async {
    try {
      final docRef = _currentBalancesDocRef();
      if (docRef == null) return;
      final iso = date.toIso8601String();
      docRef
          .set({'lastResetDate': iso}, SetOptions(merge: true)).catchError((e) {
        _logError(
            'Failed to save last reset date to Firestore: $e', null, null);
      });
      _log('Queued lastResetDate = $iso');
    } catch (e, st) {
      _logError('Failed to save last reset date', e, st);
    }
  }

  // ---------------------------
  // App reset (wipes Firestore entries for this user)
  // ---------------------------
  Future<void> resetApp(
    AIAdvisorProvider aiAdvisorProvider,
    BuildContext context, {
    CategoryProvider? categoryProvider,
    BudgetProvider? budgetProvider,
    InvestmentProvider? investmentProvider,
  }) async {
    try {
      _log('Starting full app reset...');

      // 1) Reset in-memory
      _balance = const BalanceModel();
      _showDateTimePicker = false;
      notifyListeners();

      // 2) Clear Firestore: delete balances/current doc, history subcollection, investments subcollection
      final uid = _auth.currentUser?.uid;
      if (uid != null) {
        final currentDoc = _balancesDocRefForUid(uid);
        if (currentDoc != null) {
          // delete history docs in batches
          final historyRef = currentDoc.collection('history');
          // fetch up to 500 docs at a time and delete in batch
          QuerySnapshot<Map<String, dynamic>> q;
          do {
            q = await historyRef.limit(500).get();
            if (q.docs.isEmpty) break;
            final batch = _fs.batch();
            for (final d in q.docs) {
              batch.delete(d.reference);
            }
            await batch.commit();
          } while (q.docs.isNotEmpty);

          // delete 'current' doc
          await currentDoc.delete().catchError((_) {
            // ignore if not exists
          });

          // optionally delete investments subcollection if you store investments under this user
          final investmentsRef =
              _fs.collection('users').doc(uid).collection('investments');
          do {
            q = await investmentsRef.limit(500).get();
            if (q.docs.isEmpty) break;
            final batch = _fs.batch();
            for (final d in q.docs) {
              batch.delete(d.reference);
            }
            await batch.commit();
          } while (q.docs.isNotEmpty);

          _log('Firestore user data cleared for uid=$uid');
        }
      }

      // 3) Clear transactions via listProvider
      if (listProvider != null) {
        await listProvider!.clearTransactions();
        _log('Transactions cleared (listProvider)');
      }

      // 4) Clear investments provider if provided
      if (investmentProvider != null) {
        await investmentProvider.clearAll();
        _log('InvestmentProvider cleared');
      }

      // 5) Clear AI cache
      await aiAdvisorProvider.clearCache();
      _log('AI cache cleared');

      // 6) Clear budgets and categories (these were previously stored in SharedPreferences).
      //     Here we assume budgetProvider/categoryProvider manage their own Firestore storage.
      if (budgetProvider != null) {
        await budgetProvider.clearAllBudgetsFromFirestore().catchError((e, st) {
          _logError('Failed to clear budgets via provider', e, st);
        });
        _log('BudgetProvider cleared');
      }

      // if (categoryProvider != null) {
      //   await categoryProvider.resetToDefaults().catchError((e, st) {
      //     _logError('Failed to reset categories via provider', e, st);
      //   });
      //   _log('CategoryProvider reset to defaults');
      // }

      notifyListeners();
      _log('Full reset complete');

      // Navigate to onboarding
      if (context.mounted) {
        context.go('/onboarding');
        _log('Navigated to onboarding page');
      }
    } catch (e, st) {
      _logError('Failed to reset app', e, st);
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Reset Failed'),
            content: Text('Failed to reset app: $e'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
            ],
          ),
        );
      }
    }
  }

  Future<bool> verifyReset() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return true; // nothing to verify if not signed in

      final currentDoc = _balancesDocRefForUid(uid);
      final exists =
          currentDoc != null ? (await currentDoc.get()).exists : false;
      final historyRef = currentDoc?.collection('history');
      final historyEmpty = historyRef == null
          ? true
          : (await historyRef.limit(1).get()).docs.isEmpty;

      _log('Verify reset: currentExists=$exists historyEmpty=$historyEmpty');
      return !exists && historyEmpty;
    } catch (e, st) {
      _logError('Failed to verify reset', e, st);
      return false;
    }
  }

  // ---------------------------
  // Utilities
  // ---------------------------
  String _dateKey(DateTime d) {
    final dt = DateTime(d.year, d.month, d.day);
    return dt.toIso8601String().split('T').first; // yyyy-MM-dd
  }

  // --- Reset helpers (day/week/month keys + check-and-reset) ---
  String dayKey(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  String weekKey(DateTime d) {
    final monday = d.subtract(Duration(days: d.weekday - 1));
    return dayKey(monday);
  }

  String monthKey(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}";

  Future<void> checkAndResetIfNeeded(Map<String, dynamic> data,
      DocumentReference<Map<String, dynamic>> docRef) async {
    try {
      final now = DateTime.now();

      final todayKey = dayKey(now);
      final thisWeekKey = weekKey(now);
      final thisMonthKey = monthKey(now);

      final updates = <String, dynamic>{};

      // DAILY RESET
      if (data['dailyKey'] != todayKey) {
        updates.addAll({
          'dailyKey': todayKey,
          // Use ONLY the plural names that match BalanceModel.fromMap
          'dailyIncomes': 0,
          'dailyExpenses': 0,
        });
      }

      // WEEKLY RESET (Every Monday)
      if (data['weeklyKey'] != thisWeekKey) {
        updates.addAll({
          'weeklyKey': thisWeekKey,
          // Use ONLY the plural names that match BalanceModel.fromMap
          'weeklyIncomes': 0,
          'weeklyExpenses': 0,
        });
      }

      // MONTHLY RESET (1st of new month)
      if (data['monthlyKey'] != thisMonthKey) {
        updates.addAll({
          'monthlyKey': thisMonthKey,
          // Use ONLY the plural names that match BalanceModel.fromMap
          'monthlyIncomes': 0,
          'monthlyExpenses': 0,
        });
      }

      if (updates.isNotEmpty) {
        docRef.set(updates, SetOptions(merge: true)).catchError((e) {
          _logError('checkAndResetIfNeeded failed to set to Firestore: $e',
              null, null);
        });
      }
    } catch (e, st) {
      _logError('checkAndResetIfNeeded failed', e, st);
    }
  }

  @override
  void dispose() {
    _balancesSub?.cancel();
    _balancesSub = null;
    _authSub?.cancel();
    _authSub = null;
    super.dispose();
  }
}
