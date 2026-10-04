import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:wallone/features/dashboard/providers/balance_provider.dart';
import 'package:wallone/features/investments/providers/investment_provider.dart';

class AllListProvider {
  final int id;
  final String title;
  final String category;
  final double amount;
  final String date; // ISO string
  final bool isIncome;
  final TransactionType transactionType;
  final String createdAt; // ISO string
  final double? beforeBalance;
  final String? docId; // Firestore document id (optional)

  AllListProvider({
    this.id = -1,
    required this.title,
    required this.category,
    required this.amount,
    required this.isIncome,
    String? date,
    String? createdAt,
    TransactionType? transactionType,
    this.beforeBalance,
    this.docId,
  })  : date = date ?? DateTime.now().toIso8601String(),
        createdAt = createdAt ?? DateTime.now().toIso8601String(),
        transactionType = transactionType ??
            (isIncome ? TransactionType.income : TransactionType.expense);

  // Convert object to JSON map for Firestore / serialization
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'amount': amount,
      'date': date,
      'isIncome': isIncome,
      'createdAt': createdAt,
      'transactionType': transactionType.name,
      'beforeBalance': beforeBalance,
    };
  }

  // Build from Firestore / JSON map
  factory AllListProvider.fromJson(Map<String, dynamic> json, {String? docId}) {
    TransactionType parsedType = TransactionType.expense;
    try {
      if (json.containsKey('transactionType') &&
          json['transactionType'] is String) {
        final t = (json['transactionType'] as String).toLowerCase();
        if (t == 'income') {
          parsedType = TransactionType.income;
        } else if (t == 'investment') {
          parsedType = TransactionType.investment;
        } else {
          parsedType = TransactionType.expense;
        }
      } else {
        final isIncome = json['isIncome'] == true;
        if (isIncome) {
          parsedType = TransactionType.income;
        } else {
          final title = (json['title'] ?? '').toString().toLowerCase();
          final category = (json['category'] ?? '').toString().toLowerCase();
          if (title.contains('investment') || category.contains('investment')) {
            parsedType = TransactionType.investment;
          } else {
            parsedType = TransactionType.expense;
          }
        }
      }
    } catch (_) {
      parsedType = TransactionType.expense;
    }

    double? parsedBefore;
    try {
      if (json.containsKey('beforeBalance') && json['beforeBalance'] != null) {
        parsedBefore = (json['beforeBalance'] is num)
            ? (json['beforeBalance'] as num).toDouble()
            : double.tryParse(json['beforeBalance'].toString());
      }
    } catch (_) {
      parsedBefore = null;
    }

    final idVal = (json['id'] is num)
        ? (json['id'] as num).toInt()
        : (json['id'] is String ? int.tryParse(json['id']) : null);

    return AllListProvider(
      id: idVal ?? -1,
      title: json['title'] ?? '',
      category: json['category'] ?? '',
      amount:
          (json['amount'] is num) ? (json['amount'] as num).toDouble() : 0.0,
      date: json['date'] ?? DateTime.now().toIso8601String(),
      isIncome: json['isIncome'] == true,
      createdAt: json['createdAt'] ?? DateTime.now().toIso8601String(),
      transactionType: parsedType,
      beforeBalance: parsedBefore,
      docId: docId,
    );
  }

  @override
  String toString() {
    return 'AllListProvider(id: $id, title: $title, category: $category, amount: $amount, date: $date, isIncome: $isIncome, createdAt: $createdAt, docId: $docId)';
  }

  AllListProvider copyWith({
    int? id,
    String? title,
    String? category,
    double? amount,
    String? date,
    bool? isIncome,
    TransactionType? transactionType,
    String? createdAt,
    double? beforeBalance,
    String? docId,
  }) {
    return AllListProvider(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      isIncome: isIncome ?? this.isIncome,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      transactionType: transactionType ?? this.transactionType,
      beforeBalance: beforeBalance ?? this.beforeBalance,
      docId: docId ?? this.docId,
    );
  }
}

enum TransactionType { expense, income, investment }

class ListProvider with ChangeNotifier {
  final String _tag = 'ListProvider';
  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final BalanceProvider _balanceProvider;
  final InvestmentProvider _investmentProvider;

  final List<AllListProvider> _transactions = [];
  int _nextId = 0;

  /// Optional callback invoked when a new transaction is added.
  void Function(AllListProvider transaction)? onTransactionAdded;

  // Filter state
  bool _isFilterActive = false;
  bool _isExpensesSelected = true;
  String _currentPeriod = 'All Dates';

  // Firestore subscription & auth
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _txSub;
  StreamSubscription<User?>? _authSub;

  ListProvider(this._balanceProvider, this._investmentProvider) {
    _init();
  }

  void _log(String m) => debugPrint('[$_tag] $m');
  void _logError(String m, dynamic e, StackTrace? st) {
    debugPrint('[$_tag] ERROR: $m');
    if (e != null) debugPrint('$_tag exception: $e');
    if (st != null) debugPrint('$_tag stack: $st');
  }

  // -------------------------
  // Firestore refs
  // -------------------------
  CollectionReference<Map<String, dynamic>>? get _txCollection {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _fs.collection('users').doc(uid).collection('transactions');
  }

  // -------------------------
  // Initialization
  // -------------------------
  void _init() {
    _authSub = _auth.authStateChanges().listen((user) {
      _txSub?.cancel();
      _txSub = null;
      _transactions.clear();
      _nextId = 0;
      notifyListeners();

      if (user != null) {
        _subscribeToTransactions(user.uid);
        // load once
        loadTransactions().catchError((e, st) {
          _logError('Initial load error', e, st);
        });
      }
    });

    // Also listen to investmentProvider to recompute things if needed
    _investmentProvider.addListener(() {
      _syncWithInvestmentProvider();
    });
  }

  // -------------------------
  // Subscription to collection
  // -------------------------
  void _subscribeToTransactions(String uid) {
    try {
      final col = _txCollectionForUid(uid);
      if (col == null) return;
      _txSub = col.orderBy('date', descending: true).snapshots().listen((snap) {
        _transactions.clear();
        for (final doc in snap.docs) {
          final m = doc.data();
          DateTime dateParsed;
          try {
            if (m['date'] is Timestamp) {
              dateParsed = (m['date'] as Timestamp).toDate();
            } else {
              dateParsed = DateTime.tryParse(m['date']?.toString() ?? '') ??
                  DateTime.now();
            }
          } catch (_) {
            dateParsed = DateTime.now();
          }

          final t = AllListProvider.fromJson({
            'id': m['id'] ?? -1,
            'title': m['title'],
            'category': m['category'],
            'amount': m['amount'],
            'date': dateParsed.toIso8601String(),
            'isIncome': m['isIncome'] ?? false,
            'createdAt': m['createdAt'] ?? DateTime.now().toIso8601String(),
            'transactionType': m['transactionType'],
            'beforeBalance': m['beforeBalance'],
          }, docId: doc.id);

          _transactions.add(t);
        }

        // compute nextId
        if (_transactions.isEmpty) {
          _nextId = 0;
        } else {
          _nextId = _transactions
                  .map((t) => t.id)
                  .fold<int>(0, (prev, e) => e > prev ? e : prev) +
              1;
        }

        // Try to populate missing beforeBalance asynchronously for recent transactions
        _populateBeforeBalancesForRecent();

        notifyListeners();
      }, onError: (e, st) {
        _logError('Transactions snapshot error', e, st);
      });
    } catch (e, st) {
      _logError('Failed to subscribe to transactions', e, st);
    }
  }

  // helper to obtain collection for a specific uid
  CollectionReference<Map<String, dynamic>>? _txCollectionForUid(String? uid) {
    if (uid == null) return null;
    return _fs.collection('users').doc(uid).collection('transactions');
  }

  // -------------------------
  // Getters / Filters
  // -------------------------
  List<AllListProvider> get transactions => List.unmodifiable(_transactions);
  bool get isFilterActive => _isFilterActive;
  bool get isExpensesSelected => _isExpensesSelected;
  String get currentPeriod => _currentPeriod;

  List<String> get last7Days {
    return List.generate(7, (index) {
      final date = DateTime.now().subtract(Duration(days: index));
      return DateFormat('yyyy-MM-dd').format(date);
    });
  }

  void setFilterPeriod(String period) {
    _currentPeriod = period;
    notifyListeners();
  }

  void setFilter({bool? isExpensesSelected, String? period, bool? isActive}) {
    bool shouldNotify = false;

    if (isExpensesSelected != null &&
        _isExpensesSelected != isExpensesSelected) {
      _isExpensesSelected = isExpensesSelected;
      shouldNotify = true;
    }
    if (period != null && _currentPeriod != period) {
      _currentPeriod = period;
      shouldNotify = true;
    }
    if (isActive != null && _isFilterActive != isActive) {
      _isFilterActive = isActive;
      shouldNotify = true;
    }
    if (shouldNotify) notifyListeners();
  }

  List<AllListProvider> getTransactions({bool applyFilter = false}) {
    var listToReturn = List<AllListProvider>.from(_transactions);
    if (applyFilter && _isFilterActive) {
      listToReturn =
          getFilteredTransactions(_isExpensesSelected, _currentPeriod);
    }
    // sort newest-first
    listToReturn.sort((a, b) {
      try {
        final dateA = DateTime.parse(a.date);
        final dateB = DateTime.parse(b.date);
        return dateB.compareTo(dateA);
      } catch (_) {
        return 0;
      }
    });
    return listToReturn;
  }

  List<AllListProvider> getFilteredTransactions(
      bool isExpensesSelected, String selectedDate) {
    var filtered = _transactions
        .where((t) => isExpensesSelected ? !t.isIncome : t.isIncome)
        .toList();

    if (selectedDate != 'All Dates') {
      filtered = filtered.where((t) {
        try {
          final txnDate = DateTime.parse(t.date);
          final txnIso = DateFormat('yyyy-MM-dd').format(txnDate);
          if (selectedDate == 'Today') {
            final todayIso = DateFormat('yyyy-MM-dd').format(DateTime.now());
            return txnIso == todayIso;
          }
          if (RegExp(r"^\d{4}-\d{2}-\d{2}").hasMatch(selectedDate)) {
            return txnIso == selectedDate;
          }

          final txnDateOnly = DateFormat('dd-MM-yyyy').format(txnDate);
          try {
            final legacy = DateFormat('dd-MM-yyyy').format(DateFormat('dd-MM')
                .parse('$selectedDate-${DateTime.now().year}'));
            if (txnDateOnly == legacy) return true;
          } catch (_) {}
          return txnDateOnly == selectedDate;
        } catch (e) {
          _log('Error parsing date for transaction ${t.id}: ${t.date}');
          return false;
        }
      }).toList();
    }

    filtered.sort((a, b) {
      try {
        final dateA = DateTime.parse(a.date);
        final dateB = DateTime.parse(b.date);
        return dateB.compareTo(dateA);
      } catch (_) {
        return 0;
      }
    });
    return filtered;
  }

  List<AllListProvider> getTransactionsForDate(String dateFilter) {
    if (dateFilter == 'All Dates') return getTransactions();
    final result = _transactions.where((t) {
      try {
        final txnDate = DateTime.parse(t.date);
        // Convert transaction date to yyyy-MM-dd format for comparison
        final txnDateOnly = DateFormat('yyyy-MM-dd').format(txnDate);

        if (dateFilter == 'Today') {
          final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
          return txnDateOnly == today;
        }

        // If dateFilter is already in yyyy-MM-dd format (e.g., 2025-12-30)
        if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateFilter)) {
          return txnDateOnly == dateFilter;
        }

        // Try to parse as dd-MM format (legacy format)
        try {
          final parsedDate = DateFormat('dd-MM').parse(dateFilter);
          final currentYear = DateTime.now().year;
          final legacyDate =
              DateTime(currentYear, parsedDate.month, parsedDate.day);
          final legacyDateOnly = DateFormat('yyyy-MM-dd').format(legacyDate);
          if (txnDateOnly == legacyDateOnly) return true;
        } catch (_) {}

        return txnDateOnly == dateFilter;
      } catch (_) {
        return false;
      }
    }).toList();

    result.sort((a, b) {
      try {
        final da = DateTime.parse(a.date);
        final db = DateTime.parse(b.date);
        return db.compareTo(da);
      } catch (_) {
        return 0;
      }
    });
    return result;
  }

  // -------------------------
  // Load / Save Transactions (Firestore-backed)
  // -------------------------
  Future<void> loadTransactions() async {
    try {
      final col = _txCollection;
      if (col == null) {
        _transactions.clear();
        _nextId = 0;
        notifyListeners();
        return;
      }

      final snap = await col.orderBy('date', descending: true).get();
      _transactions.clear();
      for (final doc in snap.docs) {
        final m = doc.data();
        DateTime dt;
        if (m['date'] is Timestamp) {
          dt = (m['date'] as Timestamp).toDate();
        } else {
          dt = DateTime.tryParse(m['date']?.toString() ?? '') ?? DateTime.now();
        }

        final t = AllListProvider.fromJson({
          'id': m['id'] ?? -1,
          'title': m['title'],
          'category': m['category'],
          'amount': m['amount'],
          'date': dt.toIso8601String(),
          'isIncome': m['isIncome'] ?? false,
          'createdAt': m['createdAt'] ?? DateTime.now().toIso8601String(),
          'transactionType': m['transactionType'],
          'beforeBalance': m['beforeBalance'],
        }, docId: doc.id);

        _transactions.add(t);
      }

      if (_transactions.isEmpty) {
        _nextId = 0;
      } else {
        _nextId = _transactions
                .map((t) => t.id)
                .fold<int>(0, (prev, e) => e > prev ? e : prev) +
            1;
      }

      // attempt to populate beforeBalance for recent transactions
      await _populateBeforeBalancesForRecent();

      notifyListeners();
    } catch (e, st) {
      _logError('Failed to load transactions', e, st);
      _transactions.clear();
      _nextId = 0;
      notifyListeners();
    }
  }

  Future<void> saveTransactions() async {
    // This method will upsert all Dates to Firestore.
    // For large datasets this may be inefficient; it's fine for typical small user transaction volumes.
    try {
      final col = _txCollection;
      if (col == null) throw Exception('User not signed in');

      // Delete existing docs then write current list in batch to ensure exact sync.
      // (Alternative approach: patch/merge per-doc; this is simpler.)
      // Delete all
      QuerySnapshot<Map<String, dynamic>> existing;
      do {
        existing = await col.limit(500).get();
        if (existing.docs.isEmpty) break;
        final batch = _fs.batch();
        for (final d in existing.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();
      } while (existing.docs.isNotEmpty);

      // Write current transactions
      const batchSize = 500;
      for (int i = 0; i < _transactions.length; i += batchSize) {
        final batch = _fs.batch();
        final end = (i + batchSize < _transactions.length)
            ? i + batchSize
            : _transactions.length;
        for (int j = i; j < end; j++) {
          final t = _transactions[j];
          final docRef = col.doc(); // new doc id
          final map = t.toJson();
          map['id'] = t.id;
          // store date as Timestamp
          map['date'] = Timestamp.fromDate(DateTime.parse(t.date));
          batch.set(docRef, map);
          // update local docId reference
          _transactions[j] = t.copyWith(docId: docRef.id);
        }
        batch.commit().catchError((e) {
          _logError('Failed to save transactions batch', e, null);
        });
      }

      // after saving, rebuild and save balance history via BalanceProvider
      try {
        await _rebuildAndSaveBalanceHistory();
      } catch (e, st) {
        _logError('Failed to rebuild balance history', e, st);
      }

      notifyListeners();
      _log('Saved ${_transactions.length} transactions to Firestore');
    } catch (e, st) {
      _logError('Failed to save transactions', e, st);
    }
  }

  // -------------------------
  // Add / Edit / Remove
  // -------------------------
  Future<void> addTransaction(AllListProvider transaction,
      {bool updateBalance = true}) async {
    try {
      final col = _txCollection;
      if (col == null) {
        _log('User not signed in - cannot add transaction');
        return;
      }

      // compute id
      final newId = _nextId;
      _nextId = newId + 1;

      final now = DateTime.now().toIso8601String();

      final newTransaction = AllListProvider(
        id: newId,
        title: transaction.title,
        category: transaction.category,
        amount: transaction.amount,
        isIncome: transaction.isIncome,
        date: transaction.date,
        createdAt: now,
        transactionType: transaction.transactionType,
      );

      // write to firestore (auto doc id)
      final docRef = col.doc();
      final map = newTransaction.toJson();
      map['id'] = newTransaction.id;
      map['date'] = Timestamp.fromDate(DateTime.parse(newTransaction.date));
      docRef.set(map, SetOptions(merge: true)).catchError((e) {
        _logError('Failed to add transaction to Firestore', e, null);
      });

      // optimistic add to local cache with docId
      final withDoc = newTransaction.copyWith(docId: docRef.id);
      _transactions.insert(0, withDoc);

      // update balances
      if (updateBalance) {
        if (transaction.isIncome) {
          _balanceProvider.addIncome(transaction.amount);
        } else {
          _balanceProvider.addExpense(transaction.amount);
        }
      }

      // handle investment-specific logic
      try {
        if (transaction.transactionType == TransactionType.investment &&
            updateBalance == true) {
          DateTime parsedDate;
          try {
            parsedDate = DateTime.parse(transaction.date);
          } catch (_) {
            parsedDate = DateTime.now();
          }
          _investmentProvider.recordInvestmentTransaction(
            transaction.amount,
            date: parsedDate,
            investmentName: transaction.category,
          );
        }
      } catch (e, st) {
        _logError('Failed to record investment transaction', e, st);
      }

      // attempt to populate beforeBalance for this transaction (async)
      try {
        final parsed = DateTime.tryParse(withDoc.date);
        if (parsed != null) {
          final dateOnly = DateTime(parsed.year, parsed.month, parsed.day);
          final snap = await _balanceProvider.getSavedBalanceForDate(dateOnly);
          if (snap != null) {
            // update doc and local object
            await col
                .doc(docRef.id)
                .set({'beforeBalance': snap}, SetOptions(merge: true));
            final idx = _transactions.indexWhere((t) => t.docId == docRef.id);
            if (idx != -1) {
              final old = _transactions[idx];
              _transactions[idx] = old.copyWith(beforeBalance: snap);
            }
          }
        }
      } catch (e, st) {
        _logError('Failed to populate beforeBalance', e, st);
      }

      // Notify optional listener
      try {
        onTransactionAdded?.call(withDoc);
      } catch (_) {}

      // Persist balance history rebuild asynchronously
      try {
        await _rebuildAndSaveBalanceHistory();
      } catch (e, st) {
        _logError('Failed to rebuild balance history', e, st);
      }

      notifyListeners();
      _log('Added transaction ${withDoc.id} (${withDoc.title})');
    } catch (e, st) {
      _logError('Failed to add transaction', e, st);
    }
  }

  // Edit existing transaction (identifies by numeric id; searches Firestore doc if needed)
  Future<void> editTransaction(AllListProvider updatedTransaction) async {
    try {
      final col = _txCollection;
      if (col == null) return;

      // find doc id
      String? docId = updatedTransaction.docId;
      if (docId == null) {
        // fallback: query by numeric id
        final q = await col
            .where('id', isEqualTo: updatedTransaction.id)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) docId = q.docs.first.id;
      }

      if (docId == null) {
        _log(
            'Could not locate document to edit for id ${updatedTransaction.id}');
        return;
      }

      // Reverse effect of old transaction on balances
      final index = _transactions
          .indexWhere((t) => t.id == updatedTransaction.id || t.docId == docId);
      if (index != -1) {
        final oldTransaction = _transactions[index];
        if (oldTransaction.isIncome) {
          _balanceProvider.deductBalanceForIncome(oldTransaction.amount);
        } else {
          _balanceProvider.deductBalanceOnDelete(oldTransaction.amount);
        }

        // remove historical investment record if needed
        if (oldTransaction.transactionType == TransactionType.investment) {
          _investmentProvider.removeHistoricalInvestmentTransaction(
              oldTransaction.amount, oldTransaction.date);
        }
      }

      // Apply new transaction data
      final map = updatedTransaction.toJson();
      map['date'] = Timestamp.fromDate(DateTime.parse(updatedTransaction.date));
      col.doc(docId).set(map, SetOptions(merge: true)).catchError((e) {
        _logError('Failed to update transaction in Firestore', e, null);
      });

      // Update local cache
      final idxLocal = _transactions
          .indexWhere((t) => t.id == updatedTransaction.id || t.docId == docId);
      final newLocal = updatedTransaction.copyWith(docId: docId);
      if (idxLocal != -1) _transactions[idxLocal] = newLocal;

      // Apply new balances
      if (updatedTransaction.isIncome) {
        _balanceProvider.addIncome(updatedTransaction.amount);
      } else {
        _balanceProvider.addExpense(updatedTransaction.amount);
      }

      // If investment, record historical record
      if (updatedTransaction.transactionType == TransactionType.investment) {
        _investmentProvider.recordInvestmentTransaction(
          updatedTransaction.amount,
          date: DateTime.parse(updatedTransaction.date),
          investmentName: updatedTransaction.category,
        );
      }

      // rebuild history snapshots
      await _rebuildAndSaveBalanceHistory();
      notifyListeners();
      _log('Edited transaction id=${updatedTransaction.id}');
    } catch (e, st) {
      _logError('Failed to edit transaction', e, st);
    }
  }

  // Remove transaction by numeric id (int). Uses doc lookup if necessary.
  Future<void> removeTransaction(int id) async {
    try {
      final col = _txCollection;
      if (col == null) return;

      // find local index
      final idx = _transactions.indexWhere((t) => t.id == id);
      if (idx == -1) {
        // try to find in firestore
        final q = await col.where('id', isEqualTo: id).limit(1).get();
        if (q.docs.isEmpty) {
          _log('Transaction with id $id not found');
          return;
        }
        final doc = q.docs.first;
        final m = doc.data();
        final t = AllListProvider.fromJson({
          'id': m['id'] ?? -1,
          'title': m['title'],
          'category': m['category'],
          'amount': m['amount'],
          'date': (m['date'] is Timestamp)
              ? (m['date'] as Timestamp).toDate().toIso8601String()
              : (m['date']?.toString() ?? DateTime.now().toIso8601String()),
          'isIncome': m['isIncome'] ?? false,
          'createdAt': m['createdAt'] ?? DateTime.now().toIso8601String(),
          'transactionType': m['transactionType'],
          'beforeBalance': m['beforeBalance'],
        }, docId: doc.id);
        // remove remote doc
        col.doc(doc.id).delete().catchError((_) {});
        // update balance
        if (t.isIncome) {
          _balanceProvider.deductBalanceForIncome(t.amount);
        } else {
          _balanceProvider.deductBalanceOnDelete(t.amount);
        }
        if (t.transactionType == TransactionType.investment) {
          _investmentProvider.removeHistoricalInvestmentTransaction(
              t.amount, t.date);
        }
        // reload local cache
        await loadTransactions();
        await _rebuildAndSaveBalanceHistory();
        notifyListeners();
        return;
      }

      final removed = _transactions.removeAt(idx);
      // delete remote doc if docId exists
      if (removed.docId != null) {
        col.doc(removed.docId!).delete().catchError((_) {});
      } else {
        // fallback: delete by numeric id
        final q = await col.where('id', isEqualTo: removed.id).limit(1).get();
        if (q.docs.isNotEmpty) {
          col.doc(q.docs.first.id).delete().catchError((_) {});
        }
      }

      // update balances & investment history
      if (removed.isIncome) {
        _balanceProvider.deductBalanceForIncome(removed.amount);
      } else {
        _balanceProvider.deductBalanceOnDelete(removed.amount);
      }

      if (removed.transactionType == TransactionType.investment) {
        _investmentProvider.removeHistoricalInvestmentTransaction(
            removed.amount, removed.date);
      }

      await _rebuildAndSaveBalanceHistory();
      notifyListeners();
      _log('Removed transaction id=${removed.id}');
    } catch (e, st) {
      _logError('Failed to remove transaction', e, st);
    }
  }

  Future<void> clearTransactions() async {
    try {
      final col = _txCollection;
      if (col == null) {
        _transactions.clear();
        _nextId = 0;
        notifyListeners();
        return;
      }

      QuerySnapshot<Map<String, dynamic>> q;
      do {
        q = await col.limit(500).get();
        if (q.docs.isEmpty) break;
        final batch = _fs.batch();
        for (final d in q.docs) {
          batch.delete(d.reference);
        }
        await batch.commit();
      } while (q.docs.isNotEmpty);

      _transactions.clear();
      _nextId = 0;
      // Rebuild balance history to empty
      await _rebuildAndSaveBalanceHistory();
      notifyListeners();
      _log('Cleared all Dates from Firestore and local cache');
    } catch (e, st) {
      _logError('Failed to clear transactions', e, st);
    }
  }

  // -------------------------
  // Helper: populate beforeBalances for recent txs and rebuild history
  // -------------------------
  Future<void> _populateBeforeBalancesForRecent() async {
    try {
      final now = DateTime.now();
      // Create a copy of the list to avoid index issues during async operations
      final snapshot = List<AllListProvider>.from(_transactions);

      for (final t in snapshot) {
        if (t.beforeBalance != null) continue;
        final parsed = DateTime.tryParse(t.date);
        if (parsed == null) continue;
        final dateOnly = DateTime(parsed.year, parsed.month, parsed.day);
        final diffDays = now.difference(dateOnly).inDays;
        if (diffDays >= 0 && diffDays <= 30) {
          final snap = await _balanceProvider.getSavedBalanceForDate(dateOnly);
          if (snap != null) {
            // update remote doc and local cache
            final col = _txCollection;
            if (col != null && t.docId != null) {
              col.doc(t.docId!).set({'beforeBalance': snap},
                  SetOptions(merge: true)).catchError((_) {});
            } else if (col != null && t.docId == null) {
              // try to find doc by id and update
              final q = await col.where('id', isEqualTo: t.id).limit(1).get();
              if (q.docs.isNotEmpty) {
                col.doc(q.docs.first.id).set({'beforeBalance': snap},
                    SetOptions(merge: true)).catchError((_) {});
              }
            }
            // Find and update the transaction in the current list by ID/docId
            final idx = _transactions.indexWhere((tx) =>
                (t.docId != null && tx.docId == t.docId) ||
                (t.docId == null && tx.id == t.id));
            if (idx != -1) {
              _transactions[idx] =
                  _transactions[idx].copyWith(beforeBalance: snap);
            }
          }
        }
      }
      notifyListeners();
    } catch (e, st) {
      _logError('Failed populating beforeBalances', e, st);
    }
  }

  Future<void> _rebuildAndSaveBalanceHistory({int days = 30}) async {
    try {
      // newest-first
      final sorted = List<AllListProvider>.from(_transactions);
      sorted.sort((a, b) {
        try {
          final da = DateTime.parse(a.date);
          final db = DateTime.parse(b.date);
          return db.compareTo(da);
        } catch (_) {
          return 0;
        }
      });

      double running = _balanceProvider.totalBalance;
      final Map<String, double> history = {};

      // ensure today's snapshot
      final todayKey = DateTime.now().toIso8601String().split('T')[0];
      history[todayKey] = running;

      for (final t in sorted) {
        try {
          final parsed = DateTime.parse(t.date);
          final dateOnly = DateTime(parsed.year, parsed.month, parsed.day);
          final key = dateOnly.toIso8601String().split('T')[0];
          final diffDays = DateTime.now().difference(dateOnly).inDays;

          if (diffDays >= 0 && diffDays <= days) {
            if (!history.containsKey(key)) history[key] = running;
            final delta = t.isIncome ? t.amount : -t.amount;
            final before = running - delta;

            final idx = _transactions
                .indexWhere((x) => x.id == t.id || x.docId == t.docId);
            if (idx != -1) {
              final old = _transactions[idx];
              _transactions[idx] = AllListProvider(
                id: old.id,
                title: old.title,
                category: old.category,
                amount: old.amount,
                isIncome: old.isIncome,
                date: old.date,
                createdAt: old.createdAt,
                transactionType: old.transactionType,
                beforeBalance: before,
                docId: old.docId,
              );
            }

            running = before;
          } else {
            final delta = t.isIncome ? t.amount : -t.amount;
            running = running - delta;
          }
        } catch (_) {}
      }

      // prune older than window
      final cutoff = DateTime.now().subtract(Duration(days: days));
      final pruned = <String, double>{};
      history.forEach((k, v) {
        try {
          final d = DateTime.parse(k);
          if (!d.isBefore(cutoff)) pruned[k] = v;
        } catch (_) {}
      });

      // Use BalanceProvider API to save the pruned history (BalanceProvider is Firestore-backed)
      try {
        await _balanceProvider.saveBalanceHistory(pruned);
      } catch (e, st) {
        _logError('Failed to save balance history via BalanceProvider', e, st);
      }

      // persist updated transactions' beforeBalance fields to Firestore where possible
      final col = _txCollection;
      if (col != null) {
        final batch = _fs.batch();
        int count = 0;
        for (final t in _transactions) {
          if (t.beforeBalance != null && t.docId != null) {
            final ref = col.doc(t.docId!);
            batch.set(ref, {'beforeBalance': t.beforeBalance},
                SetOptions(merge: true));
            count++;
            if (count >= 500) break; // Firestore batch limit
          }
        }
        if (count > 0) {
          batch.commit().catchError((e) {
            _logError('Failed to commit beforeBalance batch', e, null);
          });
        }
      }

      notifyListeners();
      _log('Rebuilt and saved balance history for last $days days');
    } catch (e, st) {
      _logError('Failed to rebuild/save balance history', e, st);
    }
  }

  // -------------------------
  // Sync with InvestmentProvider if needed
  // -------------------------
  void _syncWithInvestmentProvider() {
    // When investments change, we might want to recompute spent/budgets or other derived data.
    // Keep minimal here to avoid expensive work on every investment change.
    // (If needed, call _rebuildAndSaveBalanceHistory or loadTransactions)
  }

  @override
  @override
  void dispose() {
    _txSub?.cancel();
    _txSub = null;
    _authSub?.cancel();
    _authSub = null;
    super.dispose();
  }
}
