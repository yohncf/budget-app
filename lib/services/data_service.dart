import 'package:flutter/foundation.dart' hide Category;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:intl/intl.dart';
import 'firestore_service.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/holding.dart';
import '../models/asset_transaction.dart';
import '../models/account_snapshot.dart';
import '../models/asset.dart';
import '../models/budget_target.dart';
import '../models/recurring_transaction.dart';
import '../core/config.dart';

class DataService extends ChangeNotifier {
  final FirestoreService _firestore = FirestoreService();

  List<Account> accounts = [];
  List<AccountSnapshot> snapshots = [];
  List<Category> categories = [];
  List<Transaction> transactions = [];
  List<Holding> holdings = [];
  List<AssetTransaction> assetTransactions = [];
  List<Asset> assets = [];
  List<BudgetTarget> budgetTargets = [];
  List<RecurringTransaction> recurringTransactions = [];
  bool _hasHealedV5 = false; // CUSTOMIZATION PREFERENCE: Protect from multiple runs of healing script

  // Live asset prices from Alpha Vantage API
  final Map<String, double> currentAssetPrices = {};
  final Map<String, DateTime> _lastFetchTime = {};
  final Map<String, bool> _loadingAssetPrices = {};
  final List<Map<String, String>> _priceRequestQueue = [];
  bool _isProcessingQueue = false;
  DateTime? _dailyLimitHitDate;
  String _lastFetchDate = '';
  final Map<String, int> _fetchCountsToday = {};

  bool get isDailyLimitHit {
    if (_dailyLimitHitDate == null) return false;
    final now = DateTime.now();
    return _dailyLimitHitDate!.year == now.year &&
           _dailyLimitHitDate!.month == now.month &&
           _dailyLimitHitDate!.day == now.day;
  }

  DateTime transactionFilterDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  StreamSubscription<List<Transaction>>? _transactionsSubscription;
  StreamSubscription<List<BudgetTarget>>? _budgetTargetsSubscription;
  StreamSubscription<List<RecurringTransaction>>? _recurringTransactionsSubscription;

  void setTransactionFilterDate(DateTime date) {
    transactionFilterDate = date;
    _transactionsSubscription?.cancel();
    _transactionsSubscription = _firestore.streamTransactions(startFrom: transactionFilterDate).listen((data) {
      transactions = data;
      notifyListeners();
      _healDatabaseRecordsOnce();
    });
  }

  List<String> enabledCurrencies = ['MXN', 'USD', 'SOL'];
  StreamSubscription<List<String>>? _enabledCurrenciesSubscription;

  @override
  void dispose() {
    _transactionsSubscription?.cancel();
    _enabledCurrenciesSubscription?.cancel();
    _budgetTargetsSubscription?.cancel();
    _recurringTransactionsSubscription?.cancel();
    super.dispose();
  }

  bool isLoading = false;
  String? error;

  // Currency Tracking State
  Map<String, double> exchangeRates = {
    'USD': 1.0,
    'MXN': 17.278,
    'PEN': 3.75,
    'SOL': 3.75,
  };

  // Backward-compatible getter/setter
  double get mxnToUsdRate => exchangeRates['MXN'] ?? 17.278;
  set mxnToUsdRate(double val) {
    exchangeRates['MXN'] = val;
  }

  String displayCurrency = 'MXN'; // active display currency ('USD', 'MXN', 'SOL', etc.)
  Map<String, dynamic>? backupState;

  Future<void> updateEnabledCurrencies(List<String> currencies) async {
    await _firestore.saveEnabledCurrencies(currencies);
  }

  DataService() {
    _initializeData();
  }

  Future<void> _initializeData() async {
    isLoading = true;
    notifyListeners();

    // Load cached asset prices
    await _loadCachedPrices();

    // 1. Start listening to Firestore streams
    _listenToFirestore();

    // 2. Sync exchange rates and check/run backup tasks
    syncExchangeRates(); 
    checkAndRunDatabaseBackup(); 
  }

  // --- CURRENCY CONVERSION HELPERS ---

  Set<String> getTargetCurrencies() {
    // Only request the currencies that are actually used by the active accounts plus display currency
    final targets = <String>{};
    for (var acc in accounts) {
      if (acc.status == 'active') {
        final c = acc.currency.toUpperCase();
        if (c != 'USD' && c != 'SOL') {
          targets.add(c);
        } else if (c == 'SOL') {
          targets.add('PEN');
        }
      }
    }
    final disp = displayCurrency.toUpperCase();
    if (disp != 'USD' && disp != 'SOL') {
      targets.add(disp);
    } else if (disp == 'SOL') {
      targets.add('PEN');
    }
    return targets;
  }

  List<String> get availableDisplayCurrencies {
    final set = Set<String>.from(enabledCurrencies.map((c) => c.toUpperCase()));
    for (var acc in accounts) {
      if (acc.status == 'active') {
        set.add(acc.currency.toUpperCase());
      }
    }
    return set.toList();
  }

  double convert(double amount, String fromCurrency, String toCurrency) {
    final from = fromCurrency.trim().toUpperCase();
    final to = toCurrency.trim().toUpperCase();
    if (from == to) return amount;

    // Normalize SOL and PEN to PEN
    final normFrom = from == 'SOL' ? 'PEN' : from;
    final normTo = to == 'SOL' ? 'PEN' : to;

    if (normFrom == normTo) return amount;

    final fromRate = exchangeRates[normFrom] ?? 1.0;
    final toRate = exchangeRates[normTo] ?? 1.0;

    // Convert fromCurrency to USD first (amount / fromRate), then to toCurrency (* toRate)
    return (amount / fromRate) * toRate;
  }

  double convertToDisplay(double amount, String fromCurrency) {
    return convert(amount, fromCurrency, displayCurrency);
  }

  String formatCurrencyWith(double amount, String currency) {
    return NumberFormat.simpleCurrency(name: currency.toUpperCase()).format(amount);
  }

  String formatCurrency(double amount) {
    return formatCurrencyWith(amount, displayCurrency);
  }

  String formatAndConvert(double amount, String fromCurrency) {
    final converted = convertToDisplay(amount, fromCurrency);
    return formatCurrency(converted);
  }

  void setDisplayCurrency(String currency) {
    if (displayCurrency != currency) {
      displayCurrency = currency;
      notifyListeners();
    }
  }

  Future<void> syncExchangeRates() async {
    try {
      final config = await _firestore.getExchangeRateConfig();
      final DateTime now = DateTime.now();
      final String todayString = DateFormat('yyyy-MM-dd').format(now);

      bool shouldFetch = false;
      int currentFetchCount = 0;

      if (config != null) {
        // Load stored rates from database
        if (config['rates'] != null) {
          final Map<String, dynamic> storedRates = config['rates'];
          storedRates.forEach((key, value) {
            exchangeRates[key.toUpperCase()] = (value as num).toDouble();
          });
        } else if (config['mxn_rate'] != null) {
          // Fallback for backward compatibility
          exchangeRates['MXN'] = (config['mxn_rate'] as num).toDouble();
        }

        // Apply alias SOL to PEN
        if (exchangeRates.containsKey('PEN')) {
          exchangeRates['SOL'] = exchangeRates['PEN']!;
        }

        final String lastFetchDate = config['last_fetch_date'] ?? '';
        currentFetchCount = config['fetch_count_today'] ?? 0;

        // Check if there are any currencies in use that aren't cached yet
        final targets = getTargetCurrencies();
        bool hasNewCurrency = targets.any((c) => !exchangeRates.containsKey(c));

        if (lastFetchDate != todayString) {
          shouldFetch = true;
          currentFetchCount = 0;
        } else if (hasNewCurrency && currentFetchCount < 3) {
          // Immediately fetch if a new currency is introduced and we haven't hit the 3x/day limit
          shouldFetch = true;
        } else if (currentFetchCount < 3) {
          final lastFetchedStr = config['last_fetched'] ?? '';
          bool timeElapsed = true;
          if (lastFetchedStr.isNotEmpty) {
            final lastFetched = DateTime.parse(lastFetchedStr);
            if (now.difference(lastFetched).inHours < 8) {
              timeElapsed = false;
            }
          }
          if (timeElapsed) {
            shouldFetch = true;
          }
        } else {
          debugPrint("Exchange rate API fetch limit reached for today: 3/3. Using cached rates.");
        }
      } else {
        shouldFetch = true;
        currentFetchCount = 0;
      }

      if (shouldFetch) {
        await _fetchLiveRates(todayString, currentFetchCount);
      }
    } catch (e) {
      debugPrint("Error syncing exchange rates: $e");
    }
  }

  Future<void> _fetchLiveRates(String todayString, int currentFetchCount) async {
    try {
      final targets = getTargetCurrencies();
      // If we don't have any non-USD/non-SOL currencies in use, targets might be empty
      if (targets.isEmpty) {
        debugPrint("No foreign currencies in use. Skipping live rate fetch.");
        return;
      }

      final currenciesParam = targets.join(',');
      debugPrint("Fetching live exchange rates for $currenciesParam from fxratesapi...");

      final apiKey = AppConfig.fxRatesApiKey;
      final response = await http.get(Uri.parse(
        'https://api.fxratesapi.com/latest?api_key=$apiKey&base=USD&currencies=$currenciesParam&places=4'
      ));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['success'] == true && data['rates'] != null) {
          final Map<String, dynamic> ratesData = data['rates'];
          
          ratesData.forEach((key, value) {
            exchangeRates[key.toUpperCase()] = (value as num).toDouble();
          });
          
          // Ensure USD and aliases are set
          exchangeRates['USD'] = 1.0;
          if (exchangeRates.containsKey('PEN')) {
            exchangeRates['SOL'] = exchangeRates['PEN']!;
          }

          await _firestore.saveExchangeRateConfig({
            'rates': exchangeRates,
            'last_fetched': DateTime.now().toIso8601String(),
            'fetch_count_today': currentFetchCount + 1,
            'last_fetch_date': todayString,
          });

          debugPrint("Successfully updated exchange rates to: $exchangeRates. Fetch count: ${currentFetchCount + 1}");
          notifyListeners();
        }
      } else {
        debugPrint("Failed to fetch rates: status ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching live rates: $e");
    }
  }

  // --- DATABASE BACKUP REPLICATION TO SUPABASE ---

  Future<void> checkAndRunDatabaseBackup() async {
    try {
      final config = await _firestore.getBackupState();
      backupState = config;
      notifyListeners();

      final DateTime now = DateTime.now();
      final String todayString = DateFormat('yyyy-MM-dd').format(now);

      if (config != null) {
        final String lastBackupDate = config['last_backup_date'] ?? '';
        final String status = config['status'] ?? '';
        
        // If last backup date is not today, or if it failed, trigger backup
        if (lastBackupDate != todayString || status == 'failed') {
          runDatabaseBackup(todayString);
        } else {
          debugPrint("Database backup already run today: $lastBackupDate");
        }
      } else {
        // No backup state found, run first backup
        runDatabaseBackup(todayString);
      }
    } catch (e) {
      debugPrint("Error checking database backup state: $e");
    }
  }

  Future<void> runDatabaseBackup(String todayString) async {
    try {
      debugPrint("Starting database replication from Firestore to Supabase in background...");
      
      final newState = {
        'last_backup_date': todayString,
        'status': 'in_progress',
        'started_at': DateTime.now().toIso8601String(),
      };
      
      backupState = newState;
      notifyListeners();
      await _firestore.saveBackupState(newState);

      // Execute sync asynchronously (fire and forget)
      _executeBackup(todayString);
    } catch (e) {
      debugPrint("Error starting database backup: $e");
    }
  }

  Future<void> _executeBackup(String todayString) async {
    try {
      final collections = [
        'accounts',
        'account_snapshots',
        'categories',
        'transactions',
        'assets',
        'asset_transactions',
        'holdings',
        'recurring_transactions',
        'budget_targets',
      ];

      final projectRef = AppConfig.supabaseProjectRef;
      final serviceRoleKey = AppConfig.supabaseServiceRoleKey;
      bool hasError = false;
      String lastErrorMessage = '';

      for (final collection in collections) {
        try {
          final records = await _firestore.getBackupCollection(collection);
          if (records.isEmpty) {
            debugPrint("Backup: Collection $collection is empty. Skipping.");
            continue;
          }

          // CRITICAL: Clean up and filter records before sending to Supabase to prevent:
          // 1. varchar(20) constraint failures due to obsolete/deleted long IDs in the local offline cache.
          // 2. duplicate key conflicts on unique indexes (such as holdings account_id/asset_id constraint).
          var finalRecords = records.where((r) {
            final id = r['id']?.toString() ?? '';
            if (id.length > 20) return false;
            
            final accountId = r['account_id']?.toString() ?? '';
            if (accountId.length > 20) return false;
            
            final categoryId = r['category_id']?.toString() ?? '';
            if (categoryId.length > 20) return false;
            
            final transactionId = r['transaction_id']?.toString() ?? '';
            if (transactionId.length > 20) return false;
            
            final assetId = r['asset_id']?.toString() ?? '';
            if (assetId.length > 20) return false;
            
            final recurringId = r['recurring_id']?.toString() ?? '';
            if (recurringId.length > 20) return false;
            
            return true;
          }).toList();

          if (collection == 'holdings') {
            final Map<String, Map<String, dynamic>> uniqueHoldings = {};
            for (final h in finalRecords) {
              final accountId = h['account_id']?.toString() ?? '';
              final assetId = h['asset_id']?.toString() ?? '';
              final key = '${accountId}_${assetId}';
              
              final existing = uniqueHoldings[key];
              if (existing == null) {
                uniqueHoldings[key] = h;
              } else {
                final existingUpdated = DateTime.tryParse(existing['updated_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
                final currentUpdated = DateTime.tryParse(h['updated_at']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
                if (currentUpdated.isAfter(existingUpdated)) {
                  uniqueHoldings[key] = h;
                }
              }
            }
            finalRecords = uniqueHoldings.values.toList();
          }

          if (finalRecords.isEmpty) {
            debugPrint("Backup: Collection $collection is empty after filtering. Skipping.");
            continue;
          }

          // Upsert to Supabase using REST API with service_role key to bypass RLS
          final url = Uri.parse('https://$projectRef.supabase.co/rest/v1/$collection');
          final response = await http.post(
            url,
            headers: {
              'apikey': serviceRoleKey,
              'Authorization': 'Bearer $serviceRoleKey',
              'Prefer': 'resolution=merge-duplicates',
              'Content-Type': 'application/json',
            },
            body: json.encode(finalRecords),
          );

          if (response.statusCode >= 200 && response.statusCode < 300) {
            debugPrint("Backup: Successfully backed up ${records.length} records for collection $collection.");
          } else {
            throw Exception("Status ${response.statusCode}: ${response.body}");
          }
        } catch (e) {
          debugPrint("Backup: Error backing up collection $collection: $e");
          hasError = true;
          lastErrorMessage = e.toString();
        }
      }

      if (hasError) {
        throw Exception("One or more collections failed to sync. Last error: $lastErrorMessage");
      }

      final successState = {
        'last_backup_date': todayString,
        'status': 'success',
        'completed_at': DateTime.now().toIso8601String(),
      };
      backupState = successState;
      notifyListeners();
      await _firestore.saveBackupState(successState);
      
      debugPrint("Database replication from Firestore to Supabase completed successfully.");
    } catch (e) {
      final failedState = {
        'last_backup_date': todayString,
        'status': 'failed',
        'error': e.toString(),
        'failed_at': DateTime.now().toIso8601String(),
      };
      backupState = failedState;
      notifyListeners();
      await _firestore.saveBackupState(failedState);
      
      debugPrint("Database replication failed: $e");
    }
  }


  // Bind real-time Firestore streams to update local state and notify listeners
  void _listenToFirestore() {

    _firestore.streamAccounts().listen((data) {
      accounts = data;
      isLoading = false;
      notifyListeners();
      _healDatabaseRecordsOnce();
    }, onError: (err) {
      error = err.toString();
      notifyListeners();
    });

    _firestore.streamCategories().listen((data) {
      categories = data;
      notifyListeners();
      _healDatabaseRecordsOnce();
    });

    transactionFilterDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
    setTransactionFilterDate(transactionFilterDate);

    _firestore.streamHoldings().listen((data) {
      holdings = data;
      notifyListeners();
      _healDatabaseRecordsOnce();
    });

    _firestore.streamAssetTransactions().listen((data) {
      assetTransactions = data;
      notifyListeners();
      _healDatabaseRecordsOnce();
    });

    _firestore.streamAssets().listen((data) {
      assets = data;
      notifyListeners();
      _healDatabaseRecordsOnce();
    });

    _firestore.streamAccountSnapshots().listen((data) {
      snapshots = data;
      notifyListeners();
    });

    _enabledCurrenciesSubscription?.cancel();
    _enabledCurrenciesSubscription = _firestore.streamEnabledCurrencies().listen((data) {
      enabledCurrencies = data;
      notifyListeners();
    });

    _budgetTargetsSubscription?.cancel();
    _budgetTargetsSubscription = _firestore.streamBudgetTargets().listen((data) {
      budgetTargets = data;
      notifyListeners();
    });

    _recurringTransactionsSubscription?.cancel();
    _recurringTransactionsSubscription = _firestore.streamRecurringTransactions().listen((data) {
      recurringTransactions = data;
      notifyListeners();
    });
  }

  // --- MUTATION METHODS ---

  Future<void> addAccount(Account account) async {
    // Write to Primary (Firestore)
    await _firestore.saveAccount(account);
  }

  Future<void> deleteAccount(String id) async {
    await _firestore.deleteAccount(id);
  }

  Future<void> addCategory(Category category) async {
    await _firestore.saveCategory(category);
  }

  Future<void> addBudgetTarget(BudgetTarget target) async {
    await _firestore.saveBudgetTarget(target);
  }

  bool _shouldUpdateBalance(String accountId, DateTime transactionDate) {
    DateTime baselineDate = DateTime(1970);
    final accountSnapshots = snapshots.where((s) => s.accountId == accountId).toList();
    if (accountSnapshots.isNotEmpty) {
      baselineDate = accountSnapshots.map((s) => s.snapshotDate).reduce((a, b) => a.isAfter(b) ? a : b);
    }
    final txDateOnly = DateTime(transactionDate.year, transactionDate.month, transactionDate.day);
    final baseDateOnly = DateTime(baselineDate.year, baselineDate.month, baselineDate.day);
    return txDateOnly.isAfter(baseDateOnly);
  }

  Future<void> addTransaction(Transaction tx) async {
    // 1. Enforce validation rule on amount sign vs category type before writing
    final category = categories.firstWhere((c) => c.id == tx.categoryId, 
        orElse: () => Category(id: '', name: 'Unknown', type: 'expense', createdAt: DateTime.now()));
    
    if (category.type == 'expense' && tx.amount >= 0) {
      throw ArgumentError("Expenses must have a negative amount (< 0).");
    }
    if (category.type == 'income' && tx.amount <= 0) {
      throw ArgumentError("Income must have a positive amount (> 0).");
    }
    if (category.type == 'reimbursement' && tx.amount <= 0) {
      throw ArgumentError("Reimbursements must have a positive amount (> 0).");
    }

    // 2. Save transaction to primary db
    await _firestore.saveTransaction(tx);

    // 3. Update current balance in primary db ONLY if tx.date is strictly after the latest snapshot_date
    final accountIndex = accounts.indexWhere((a) => a.id == tx.accountId);
    if (accountIndex != -1) {
      final account = accounts[accountIndex];
      if (_shouldUpdateBalance(account.id, tx.date)) {
        final isCreditCard = account.type == 'credit_card';
        final double convertedAmount = convert(tx.amount, tx.currency, account.currency);
        final updatedAccount = account.copyWith(
          currentBalance: isCreditCard
              ? account.currentBalance - convertedAmount
              : account.currentBalance + convertedAmount,
        );
        await _firestore.saveAccount(updatedAccount);
        accounts[accountIndex] = updatedAccount;
      }

      // CUSTOMIZATION PREFERENCE: Automatically log a CASH asset transaction for cash ledger transactions in capital accounts
      if (account.accountGroup == 'capital') {
        // CRITICAL: All primary keys must be a native 20-character Firestore Document ID (alphanumeric, no underscores).
        final exists = assetTransactions.any((at) => at.transactionId == tx.id && at.assetId == 'CASH');
        if (!exists) {
          final cashAssetTxId = _firestore.generateId('asset_transactions');
          final cashAssetTx = AssetTransaction(
            id: cashAssetTxId,
            transactionId: tx.id,
            accountId: tx.accountId,
            assetId: 'CASH',
            type: tx.amount < 0 ? 'sell' : 'buy', // Outflow sells CASH, inflow buys CASH
            quantity: tx.amount.abs(),
            unitPrice: 1.0,
            executedAt: tx.date,
            assetSymbol: 'CASH',
            assetName: 'Cash',
          );
          await _firestore.saveAssetTransaction(cashAssetTx);
          await _recalculateHolding(cashAssetTx);
        }
      }
    }
  }

  Future<void> deleteTransaction(Transaction tx) async {
    // 1. Soft-delete the main transaction by setting status to 'deleted'
    final updatedTx = tx.copyWith(status: 'deleted');
    await _firestore.saveTransaction(updatedTx);

    // 2. Reverse its effect on the parent account balance
    final accountIndex = accounts.indexWhere((a) => a.id == tx.accountId);
    if (accountIndex != -1) {
      final account = accounts[accountIndex];
      if (_shouldUpdateBalance(account.id, tx.date)) {
        final isCreditCard = account.type == 'credit_card';
        final double convertedAmount = convert(tx.amount, tx.currency, account.currency);
        final updatedAccount = account.copyWith(
          currentBalance: isCreditCard
              ? account.currentBalance + convertedAmount
              : account.currentBalance - convertedAmount,
        );
        await _firestore.saveAccount(updatedAccount);
        accounts[accountIndex] = updatedAccount;
      }

      // CUSTOMIZATION PREFERENCE: Automatically delete corresponding CASH asset transaction for capital accounts
      if (account.accountGroup == 'capital') {
        final cashAssetTx = assetTransactions.cast<AssetTransaction?>().firstWhere(
          (at) => at != null && at.transactionId == tx.id && at.assetId == 'CASH',
          orElse: () => null,
        );
        if (cashAssetTx != null) {
          await _firestore.deleteAssetTransaction(cashAssetTx.id);
          await recalculateHoldingFromScratch(tx.accountId, 'CASH', excludeTxId: cashAssetTx.id);
        }
      }
    }
    // 3. Find and soft-delete any paired transfer transaction
    String? transferTag;
    for (final tag in tx.tags) {
      if (tag.startsWith('transfer_')) {
        transferTag = tag;
        break;
      }
    }

    if (transferTag != null) {
      Transaction? pairedTx;
      for (final t in transactions) {
        if (t.id != tx.id && t.tags.contains(transferTag) && t.status != 'deleted') {
          pairedTx = t;
          break;
        }
      }

      if (pairedTx != null) {
        final nonNullPairedTx = pairedTx;
        // Soft-delete the paired transaction in Firestore
        final updatedPairedTx = nonNullPairedTx.copyWith(status: 'deleted');
        await _firestore.saveTransaction(updatedPairedTx);

        // Reverse the paired transaction's effect on its parent account balance
        final pairedAccountIndex = accounts.indexWhere((a) => a.id == nonNullPairedTx.accountId);
        if (pairedAccountIndex != -1) {
          final account = accounts[pairedAccountIndex];
          if (_shouldUpdateBalance(account.id, nonNullPairedTx.date)) {
            final isCreditCard = account.type == 'credit_card';
            final updatedAccount = account.copyWith(
              currentBalance: isCreditCard
                  ? account.currentBalance + nonNullPairedTx.amount
                  : account.currentBalance - nonNullPairedTx.amount,
            );
            await _firestore.saveAccount(updatedAccount);
            accounts[pairedAccountIndex] = updatedAccount;
          }

          // CUSTOMIZATION PREFERENCE: Delete paired CASH asset transaction if destination account is capital
          if (account.accountGroup == 'capital') {
            final cashAssetTxId = 'ca_${nonNullPairedTx.id.substring(3)}';
            await _firestore.deleteAssetTransaction(cashAssetTxId);
            await recalculateHoldingFromScratch(nonNullPairedTx.accountId, 'CASH', excludeTxId: cashAssetTxId);
          }
        }
      }
    }
  }

  bool isTransactionEditable(Transaction tx) {
    if (!_shouldUpdateBalance(tx.accountId, tx.date)) {
      return false;
    }

    String? transferTag;
    for (final tag in tx.tags) {
      if (tag.startsWith('transfer_')) {
        transferTag = tag;
        break;
      }
    }
    if (transferTag != null) {
      Transaction? pairedTx;
      for (final t in transactions) {
        if (t.id != tx.id && t.tags.contains(transferTag) && t.status != 'deleted') {
          pairedTx = t;
          break;
        }
      }
      if (pairedTx != null) {
        if (!_shouldUpdateBalance(pairedTx.accountId, pairedTx.date)) {
          return false;
        }
      }
    }

    return true;
  }

  Future<void> updateTransaction({
    required List<Transaction> oldTxs,
    required List<Transaction> newTxs,
  }) async {
    for (final tx in oldTxs) {
      if (!isTransactionEditable(tx)) {
        throw ArgumentError("Transaction on or before snapshot date cannot be modified.");
      }
    }

    for (final tx in oldTxs) {
      final accountIndex = accounts.indexWhere((a) => a.id == tx.accountId);
      if (accountIndex != -1) {
        final account = accounts[accountIndex];
        if (_shouldUpdateBalance(account.id, tx.date)) {
          final isCreditCard = account.type == 'credit_card';
          final double convertedAmount = convert(tx.amount, tx.currency, account.currency);
          final updatedAccount = account.copyWith(
            currentBalance: isCreditCard
                ? account.currentBalance + convertedAmount
                : account.currentBalance - convertedAmount,
          );
          await _firestore.saveAccount(updatedAccount);
          accounts[accountIndex] = updatedAccount;
        }
      }
    }

    final newIds = newTxs.map((t) => t.id).toSet();
    for (final tx in oldTxs) {
      if (!newIds.contains(tx.id)) {
        final deletedTx = tx.copyWith(status: 'deleted');
        await _firestore.saveTransaction(deletedTx);

        // CUSTOMIZATION PREFERENCE: Delete corresponding CASH asset transaction
        final account = accounts.cast<Account?>().firstWhere((a) => a?.id == tx.accountId, orElse: () => null);
        if (account != null && account.accountGroup == 'capital') {
          final cashAssetTx = assetTransactions.cast<AssetTransaction?>().firstWhere(
            (at) => at != null && at.transactionId == tx.id && at.assetId == 'CASH',
            orElse: () => null,
          );
          if (cashAssetTx != null) {
            await _firestore.deleteAssetTransaction(cashAssetTx.id);
            await recalculateHoldingFromScratch(tx.accountId, 'CASH', excludeTxId: cashAssetTx.id);
          }
        }
      }
    }

    for (final tx in newTxs) {
      final category = categories.firstWhere((c) => c.id == tx.categoryId, 
          orElse: () => Category(id: '', name: 'Unknown', type: 'expense', createdAt: DateTime.now()));
      if (category.type == 'expense' && tx.amount >= 0) {
        throw ArgumentError("Expenses must have a negative amount (< 0).");
      }
      if (category.type == 'income' && tx.amount <= 0) {
        throw ArgumentError("Income must have a positive amount (> 0).");
      }
      if (category.type == 'reimbursement' && tx.amount <= 0) {
        throw ArgumentError("Reimbursements must have a positive amount (> 0).");
      }

      await _firestore.saveTransaction(tx);

      final accountIndex = accounts.indexWhere((a) => a.id == tx.accountId);
      if (accountIndex != -1) {
        final account = accounts[accountIndex];
        if (_shouldUpdateBalance(account.id, tx.date)) {
          final isCreditCard = account.type == 'credit_card';
          final double convertedAmount = convert(tx.amount, tx.currency, account.currency);
          final updatedAccount = account.copyWith(
            currentBalance: isCreditCard
                ? account.currentBalance - convertedAmount
                : account.currentBalance + convertedAmount,
          );
          await _firestore.saveAccount(updatedAccount);
          accounts[accountIndex] = updatedAccount;
        }

        // CUSTOMIZATION PREFERENCE: Create/update corresponding CASH asset transaction
        if (account.accountGroup == 'capital') {
          final existingCashAssetTx = assetTransactions.cast<AssetTransaction?>().firstWhere(
            (at) => at != null && at.transactionId == tx.id && at.assetId == 'CASH',
            orElse: () => null,
          );
          if (existingCashAssetTx == null) {
            final cashAssetTxId = _firestore.generateId('asset_transactions');
            final cashAssetTx = AssetTransaction(
              id: cashAssetTxId,
              transactionId: tx.id,
              accountId: tx.accountId,
              assetId: 'CASH',
              type: tx.amount < 0 ? 'sell' : 'buy',
              quantity: tx.amount.abs(),
              unitPrice: 1.0,
              executedAt: tx.date,
              assetSymbol: 'CASH',
              assetName: 'Cash',
            );
            await _firestore.saveAssetTransaction(cashAssetTx);
            await _recalculateHolding(cashAssetTx);
          } else {
            final updatedCashAssetTx = existingCashAssetTx.copyWith(
              type: tx.amount < 0 ? 'sell' : 'buy',
              quantity: tx.amount.abs(),
              executedAt: tx.date,
            );
            await _firestore.saveAssetTransaction(updatedCashAssetTx);
            await _recalculateHolding(updatedCashAssetTx);
          }
        }
      }
    }
  }


  Future<void> addAssetTransaction(AssetTransaction assetTx, {double? cashImpactAmount, String? assetType}) async {
    AssetTransaction finalAssetTx = assetTx;

    // CUSTOMIZATION PREFERENCE: Automatically record cash transaction for buys and sells if no link is provided
    if (assetTx.transactionId == null && (assetTx.type == 'buy' || assetTx.type == 'sell')) {
      final accountIndex = accounts.indexWhere((a) => a.id == assetTx.accountId);
      if (accountIndex != -1) {
        final account = accounts[accountIndex];
        final totalValue = assetTx.quantity * assetTx.unitPrice;
        final amount = assetTx.type == 'buy' ? -totalValue : totalValue;

        Category matchedCategory;
        if (assetTx.type == 'buy') {
          matchedCategory = categories.firstWhere(
            (c) => c.type == 'investment' || c.type == 'expense',
            orElse: () => Category(
              id: 'investment_default',
              name: 'Investment',
              type: 'investment',
              createdAt: DateTime.now(),
            ),
          );
        } else {
          matchedCategory = categories.firstWhere(
            (c) => c.type == 'income' && c.name.toLowerCase().contains('deposit'),
            orElse: () => categories.firstWhere(
              (c) => c.type == 'income',
              orElse: () => Category(
                id: 'deposit_default',
                name: 'Deposit',
                type: 'income',
                createdAt: DateTime.now(),
              ),
            ),
          );
        }

        // CRITICAL: ID must be a native 20-character Firestore Document ID (alphanumeric, no underscores).
        final cashTxId = _firestore.generateId('transactions');
        final cashTx = Transaction(
          id: cashTxId,
          accountId: assetTx.accountId,
          categoryId: matchedCategory.id,
          amount: amount,
          currency: account.currency,
          date: assetTx.executedAt,
          description: '${assetTx.type.toUpperCase()} ${assetTx.quantity} ${assetTx.assetSymbol ?? assetTx.assetId} @ ${assetTx.unitPrice}',
          createdAt: DateTime.now(),
        );

        await addTransaction(cashTx);
        finalAssetTx = assetTx.copyWith(transactionId: cashTxId);
      }
    }

    // Write asset transaction execution log
    await _firestore.saveAssetTransaction(finalAssetTx);

    // If asset doesn't exist in our list, create it
    final exists = assets.any((a) => a.id == finalAssetTx.assetId);
    if (!exists) {
      final symbol = finalAssetTx.assetSymbol ?? finalAssetTx.assetId;
      final name = finalAssetTx.assetName ?? symbol;
      final type = assetType ?? 'stock';
      await _firestore.saveAsset(Asset(id: finalAssetTx.assetId, symbol: symbol, name: name, type: type));
    }

    // Recalculate holding inventory
    _recalculateHolding(finalAssetTx);
  }

  Future<void> deleteAssetTransaction(AssetTransaction assetTx) async {
    // Write deletion to Firestore
    await _firestore.deleteAssetTransaction(assetTx.id);

    // CUSTOMIZATION PREFERENCE: Delete corresponding cash ledger transaction (which deletes CASH asset transaction)
    if (assetTx.transactionId != null) {
      final cashTx = transactions.cast<Transaction?>().firstWhere((t) => t?.id == assetTx.transactionId, orElse: () => null);
      if (cashTx != null) {
        await deleteTransaction(cashTx);
      }
    }

    // Recalculate holdings chronologically from scratch, excluding the deleted transaction
    await recalculateHoldingFromScratch(assetTx.accountId, assetTx.assetId, excludeTxId: assetTx.id);
  }

  Future<void> saveAsset(Asset asset) async {
    await _firestore.saveAsset(asset);
  }

  Future<void> deleteAsset(String assetId) async {
    await _firestore.deleteAsset(assetId);
  }

  Stream<List<AssetTransaction>> streamAssetTransactionsPaged({required int limit}) {
    return _firestore.streamAssetTransactionsPaged(limit: limit);
  }

  Future<void> recalculateHoldingFromScratch(String accountId, String assetId, {String? excludeTxId}) async {
    final txs = assetTransactions
        .where((t) => t.accountId == accountId && t.assetId == assetId && t.id != excludeTxId)
        .toList();
    
    // Replay transactions chronologically
    txs.sort((a, b) => a.executedAt.compareTo(b.executedAt));

    final existingHoldings = holdings.where((h) => h.accountId == accountId && h.assetId == assetId);
    
    double qty = 0;
    double avgPrice = 0;

    for (final tx in txs) {
      if (tx.type == 'buy' || tx.type == 'dividend_reinvest' || tx.type == 'reward') {
        final nextQty = qty + tx.quantity;
        if (nextQty > 0) {
          avgPrice = ((qty * avgPrice) + (tx.quantity * tx.unitPrice)) / nextQty;
        }
        qty = nextQty;
      } else if (tx.type == 'sell') {
        qty = qty - tx.quantity;
      } else if (tx.type == 'split') {
        qty = qty * tx.quantity;
        if (qty > 0) {
          avgPrice = avgPrice / tx.quantity;
        }
      }
    }

    if (existingHoldings.isNotEmpty) {
      final h = existingHoldings.first;
      if (qty <= 0) {
        await _firestore.deleteHolding(h.id);
      } else {
        final updatedHolding = Holding(
          id: h.id,
          accountId: h.accountId,
          assetId: h.assetId,
          quantity: qty,
          avgBuyPrice: avgPrice,
          updatedAt: DateTime.now(),
          assetSymbol: h.assetSymbol,
          assetName: h.assetName,
        );
        await _firestore.saveHolding(updatedHolding);
      }
    } else if (qty > 0) {
      final newHolding = Holding(
        id: UniqueKey().toString(),
        accountId: accountId,
        assetId: assetId,
        quantity: qty,
        avgBuyPrice: avgPrice,
        updatedAt: DateTime.now(),
      );
      await _firestore.saveHolding(newHolding);
    }
  }

  Future<void> _recalculateHolding(AssetTransaction assetTx) async {
    final existingHoldings = holdings.where((h) => h.accountId == assetTx.accountId && h.assetId == assetTx.assetId);
    
    double currentQty = 0;
    double currentAvgPrice = 0;
    String id = UniqueKey().toString();

    if (existingHoldings.isNotEmpty) {
      final h = existingHoldings.first;
      currentQty = h.quantity;
      currentAvgPrice = h.avgBuyPrice;
      id = h.id;
    }

    double nextQty = currentQty;
    double nextAvgPrice = currentAvgPrice;

    if (assetTx.type == 'buy' || assetTx.type == 'dividend_reinvest' || assetTx.type == 'reward') {
      nextQty = currentQty + assetTx.quantity;
      if (nextQty > 0) {
        nextAvgPrice = ((currentQty * currentAvgPrice) + (assetTx.quantity * assetTx.unitPrice)) / nextQty;
      }
    } else if (assetTx.type == 'sell') {
      nextQty = currentQty - assetTx.quantity;
      // Cost basis average price remains the same on sale, just quantity reduces
    } else if (assetTx.type == 'split') {
      nextQty = currentQty * assetTx.quantity; // quantity represents multiplier ratio here
      if (nextQty > 0) {
        nextAvgPrice = currentAvgPrice / assetTx.quantity;
      }
    }

    // CUSTOMIZATION PREFERENCE: Delete the holding position if its quantity falls to 0 or less
    if (nextQty <= 0) {
      await _firestore.deleteHolding(id);
    } else {
      final newHolding = Holding(
        id: id,
        accountId: assetTx.accountId,
        assetId: assetTx.assetId,
        quantity: nextQty,
        avgBuyPrice: nextAvgPrice,
        updatedAt: DateTime.now(),
      );
      await _firestore.saveHolding(newHolding);
    }
  }

  Future<void> addAccountSnapshot(AccountSnapshot snapshot) async {
    await _firestore.saveAccountSnapshot(snapshot);

    final account = accounts.firstWhere((a) => a.id == snapshot.accountId);
    final updatedAccount = account.copyWith(
      currentBalance: snapshot.balance,
      updatedAt: DateTime.now(),
    );
    await _firestore.saveAccount(updatedAccount);
  }

  Future<void> saveRecurringTransaction(RecurringTransaction rt) async {
    await _firestore.saveRecurringTransaction(rt);
  }

  Future<void> deleteRecurringTransaction(String id) async {
    await _firestore.deleteRecurringTransaction(id);
  }

  // --- CALCULATION HELPER FUNCTIONS ---

  double getHoldingCurrentPrice(Holding holding, Account account) {
    // Find the asset by ID to resolve the actual symbol from the reference list
    final asset = assets.firstWhere(
      (a) => a.id == holding.assetId,
      orElse: () => Asset(
        id: holding.assetId,
        symbol: holding.assetSymbol ?? holding.assetId,
        name: holding.assetName ?? holding.assetId,
        type: 'stock',
      ),
    );

    final symbol = asset.symbol;
    // CUSTOMIZATION PREFERENCE: Cash asset price is always 1.0 in its own currency
    if (symbol == 'CASH') return 1.0;
    if (symbol.isEmpty) return holding.avgBuyPrice;

    // Check if cache has expired or doesn't exist
    final now = DateTime.now();
    final lastFetch = _lastFetchTime[symbol];
    
    // 4 hours (240 mins) cooldown if succeeded/cached, 15 minutes if failed/empty
    final bool hasPrice = currentAssetPrices[symbol] != null;
    final int cooldownMinutes = hasPrice ? 240 : 15;
    
    final needsFetch = lastFetch == null || now.difference(lastFetch).inMinutes > cooldownMinutes;

    _checkAndResetDailyCounts();
    final fetchCount = _fetchCountsToday[symbol] ?? 0;

    if (needsFetch && _loadingAssetPrices[symbol] != true && !isDailyLimitHit && fetchCount < 4) {
      queueAssetPriceFetch(symbol, asset.type);
    }

    final cachedPriceInUSD = currentAssetPrices[symbol];
    if (cachedPriceInUSD != null) {
      // Convert from USD to the account's base currency
      return convert(cachedPriceInUSD, 'USD', account.currency);
    }

    return holding.avgBuyPrice;
  }

  void _checkAndResetDailyCounts() {
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (_lastFetchDate != todayStr) {
      _lastFetchDate = todayStr;
      _fetchCountsToday.clear();
    }
  }

  void queueAssetPriceFetch(String symbol, String type) {
    if (symbol.isEmpty) return;
    if (isDailyLimitHit) return;
    
    if (_loadingAssetPrices[symbol] == true) return;
    
    _loadingAssetPrices[symbol] = true;
    _priceRequestQueue.add({'symbol': symbol, 'type': type});
    _processPriceQueue();
  }

  Future<void> _processPriceQueue() async {
    if (_isProcessingQueue) return;
    _isProcessingQueue = true;

    while (_priceRequestQueue.isNotEmpty) {
      if (isDailyLimitHit) {
        _priceRequestQueue.clear();
        break;
      }
      final req = _priceRequestQueue.removeAt(0);
      final symbol = req['symbol']!;
      final type = req['type']!;

      await fetchAssetPrice(symbol, type: type);

      // Wait 1.5 seconds between requests to satisfy Alpha Vantage's 1 req/sec burst limit
      await Future.delayed(const Duration(milliseconds: 1500));
    }

    _isProcessingQueue = false;
  }

  void _checkDailyLimit(Map<String, dynamic> data) {
    final note = data['Note']?.toString();
    final info = data['Information']?.toString();
    
    bool isLimit = false;
    if (note != null && (note.contains("rate limit") || note.contains("25 requests per day"))) {
      isLimit = true;
    }
    if (info != null && (info.contains("rate limit") || info.contains("25 requests per day"))) {
      isLimit = true;
    }
    
    if (isLimit) {
      _dailyLimitHitDate = DateTime.now();
      debugPrint("Alpha Vantage daily limit hit detected. Disabling API calls for today.");
      _saveCachedPrices();
    }
  }

  Future<void> fetchAssetPrice(String symbol, {String type = 'stock'}) async {
    if (symbol.isEmpty) return;
    if (isDailyLimitHit) return;
    _loadingAssetPrices[symbol] = true;

    try {
      final apiKey = AppConfig.alphaVantageApiKey;
      double? price;

      if (type.toLowerCase() == 'crypto') {
        // Only try Realtime Currency Exchange Rate for cryptos
        final urlRate = Uri.parse('https://www.alphavantage.co/query?function=CURRENCY_EXCHANGE_RATE&from_currency=$symbol&to_currency=USD&apikey=$apiKey');
        final responseRate = await http.get(urlRate);
        if (responseRate.statusCode == 200) {
          final data = json.decode(responseRate.body);
          _checkDailyLimit(data);
          if (data['Note'] != null) {
            debugPrint("Alpha Vantage rate limit message for $symbol: ${data['Note']}");
          }
          if (data['Information'] != null) {
            debugPrint("Alpha Vantage info for $symbol: ${data['Information']}");
          }
          if (data['Realtime Currency Exchange Rate'] != null && data['Realtime Currency Exchange Rate']['5. Exchange Rate'] != null) {
            final rateStr = data['Realtime Currency Exchange Rate']['5. Exchange Rate'] as String;
            price = double.tryParse(rateStr);
          }
        }
      } else {
        // Only try Global Quote for stocks and ETFs
        final urlQuote = Uri.parse('https://www.alphavantage.co/query?function=GLOBAL_QUOTE&symbol=$symbol&apikey=$apiKey');
        final responseQuote = await http.get(urlQuote);
        if (responseQuote.statusCode == 200) {
          final data = json.decode(responseQuote.body);
          _checkDailyLimit(data);
          if (data['Note'] != null) {
            debugPrint("Alpha Vantage rate limit message for $symbol: ${data['Note']}");
          }
          if (data['Information'] != null) {
            debugPrint("Alpha Vantage info for $symbol: ${data['Information']}");
          }
          if (data['Global Quote'] != null && data['Global Quote']['05. price'] != null) {
            final priceStr = data['Global Quote']['05. price'] as String;
            price = double.tryParse(priceStr);
          }
        }
      }

      if (price != null) {
        currentAssetPrices[symbol] = price;
        _lastFetchTime[symbol] = DateTime.now();
        _checkAndResetDailyCounts();
        _fetchCountsToday[symbol] = (_fetchCountsToday[symbol] ?? 0) + 1;
        _saveCachedPrices();
        notifyListeners();
      } else {
        debugPrint("Alpha Vantage price was null for $symbol ($type)");
        _lastFetchTime[symbol] = DateTime.now(); // Set failure cooldown
        _saveCachedPrices();
      }
    } catch (e) {
      debugPrint("Error fetching Alpha Vantage price for $symbol: $e");
      _lastFetchTime[symbol] = DateTime.now(); // Set failure cooldown
      _saveCachedPrices();
    } finally {
      _loadingAssetPrices[symbol] = false;
    }
  }

  Future<void> _loadCachedPrices() async {
    try {
      final config = await _firestore.getAssetPriceConfig();
      if (config != null) {
        if (config['prices'] != null) {
          final Map<String, dynamic> storedPrices = config['prices'];
          storedPrices.forEach((key, value) {
            currentAssetPrices[key] = (value as num).toDouble();
          });
        }
        if (config['timestamps'] != null) {
          final Map<String, dynamic> storedTimestamps = config['timestamps'];
          storedTimestamps.forEach((key, value) {
            final date = DateTime.tryParse(value as String);
            if (date != null) {
              _lastFetchTime[key] = date;
            }
          });
        }
        if (config['daily_limit_hit_date'] != null) {
          _dailyLimitHitDate = DateTime.tryParse(config['daily_limit_hit_date'] as String);
        }
        if (config['last_fetch_date'] != null) {
          _lastFetchDate = config['last_fetch_date'] as String;
        }
        if (config['fetch_counts_today'] != null) {
          final Map<String, dynamic> storedCounts = config['fetch_counts_today'];
          storedCounts.forEach((key, value) {
            _fetchCountsToday[key] = value as int;
          });
        }
      }

      // Default fallback prices to use if not present in Firestore cache
      final Map<String, double> fallbackPrices = {
        'MSFT': 367.34,
        'GOOGL': 349.68,
        'DIS': 102.45,
        'SCHB': 28.88,
        'SCHG': 33.48,
        'SOL': 71.85,
        'KMNO': 0.0201,
      };

      bool appliedFallback = false;
      fallbackPrices.forEach((key, value) {
        if (!currentAssetPrices.containsKey(key)) {
          currentAssetPrices[key] = value;
          appliedFallback = true;
        }
      });

      if (appliedFallback) {
        await _saveCachedPrices();
      }
      
      debugPrint('Loaded cached asset prices from Firestore: $currentAssetPrices');
    } catch (e) {
      debugPrint('Error loading cached asset prices from Firestore: $e');
    }
  }

  Future<void> _saveCachedPrices() async {
    try {
      final Map<String, String> stringifiedTimestamps = {};
      _lastFetchTime.forEach((key, value) {
        stringifiedTimestamps[key] = value.toIso8601String();
      });

      await _firestore.saveAssetPriceConfig({
        'prices': currentAssetPrices,
        'timestamps': stringifiedTimestamps,
        'daily_limit_hit_date': _dailyLimitHitDate?.toIso8601String(),
        'last_fetch_date': _lastFetchDate,
        'fetch_counts_today': _fetchCountsToday,
      });
      debugPrint('Saved asset prices to Firestore config: $currentAssetPrices');
    } catch (e) {
      debugPrint('Error saving cached asset prices to Firestore: $e');
    }
  }

  double calculateNetWorthIn(String targetCurrency) {
    double totalValue = 0.0;
    
    for (var acc in accounts) {
      if (acc.status != 'active') continue;
      // CUSTOMIZATION PREFERENCE: Skip adding cash balance directly for capital accounts because it is already tracked
      // as a CASH holding asset.
      if (acc.accountGroup == 'capital') continue;
      
      double balanceInTarget = convert(acc.currentBalance, acc.currency, targetCurrency);
      if (acc.type == 'credit_card') {
        totalValue -= balanceInTarget;
      } else {
        totalValue += balanceInTarget;
      }
    }

    for (var holding in holdings) {
      final acc = accounts.firstWhere(
        (a) => a.id == holding.accountId,
        orElse: () => Account(
          id: '',
          name: '',
          type: 'checking',
          currency: 'USD',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      if (acc.status != 'active') continue;
      
      double currentPrice = getHoldingCurrentPrice(holding, acc);
      double holdingValueInAccountCurrency = holding.quantity * currentPrice;
      double holdingValueInTarget = convert(holdingValueInAccountCurrency, acc.currency, targetCurrency);
      totalValue += holdingValueInTarget;
    }

    return totalValue;
  }

  double get netWorth => calculateNetWorthIn(displayCurrency);

  // CUSTOMIZATION PREFERENCE: Self-healing routine to fix incorrect assetId records and missing cash operations
  Future<void> _healDatabaseRecordsOnce() async {
    if (_hasHealedV5) return;
    if (accounts.isEmpty || categories.isEmpty || assets.isEmpty || assetTransactions.isEmpty || transactions.isEmpty) return;
    _hasHealedV5 = true;

    try {
      // CUSTOMIZATION PREFERENCE: Fix bad recurring transaction ID 'rt_9cc64930-b505-4' to follow 20-char schema
      final badRtIndex = recurringTransactions.indexWhere((rt) => rt.id == 'rt_9cc64930-b505-4');
      if (badRtIndex != -1) {
        final badRt = recurringTransactions[badRtIndex];
        final newRtId = '9cc64930b5054d3ba840';
        debugPrint('Found bad recurring transaction ID: ${badRt.id}. Migrating to $newRtId...');

        // 1. Update any transactions referencing this recurring ID
        for (final tx in transactions) {
          if (tx.recurringId == badRt.id) {
            final correctedTx = tx.copyWith(recurringId: newRtId);
            await _firestore.saveTransaction(correctedTx);
          }
        }

        // 2. Delete the old recurring transaction template
        await deleteRecurringTransaction(badRt.id);

        // 3. Create the corrected template with new ID
        final correctedRt = RecurringTransaction(
          id: newRtId,
          accountId: badRt.accountId,
          categoryId: badRt.categoryId,
          amount: badRt.amount,
          frequency: badRt.frequency,
          interval: badRt.interval,
          startDate: badRt.startDate,
          endDate: badRt.endDate,
          nextDueDate: badRt.nextDueDate,
          status: badRt.status,
          description: badRt.description,
        );
        await _firestore.saveRecurringTransaction(correctedRt);
      }
      // CUSTOMIZATION PREFERENCE: Fix bad Cash asset ID '[#9f69c]' and merge it into 'CASH'
      final badCashAsset = assets.cast<Asset?>().firstWhere(
        (a) => a != null && (a.id.contains('9f69c') || a.id == '[#9f69c]'),
        orElse: () => null,
      );

      if (badCashAsset != null) {
        final badId = badCashAsset.id;
        debugPrint('Found bad CASH asset ID: $badId. Migrating to "CASH"...');

        // 1. Correct any asset transactions referencing the bad ID
        final badTxs = assetTransactions.where((tx) => tx.assetId == badId).toList();
        for (final tx in badTxs) {
          final correctedTx = tx.copyWith(assetId: 'CASH', assetSymbol: 'CASH', assetName: 'Cash');
          await _firestore.saveAssetTransaction(correctedTx);
        }

        // 2. Delete holdings referencing the bad ID
        final badHoldings = holdings.where((h) => h.assetId == badId).toList();
        for (final h in badHoldings) {
          await _firestore.deleteHolding(h.id);
        }

        // 3. Delete the bad asset metadata document
        await deleteAsset(badId);

        // 4. Force recalculation of 'CASH' holding for affected accounts
        for (final tx in badTxs) {
          await recalculateHoldingFromScratch(tx.accountId, 'CASH');
        }
      }
      // CUSTOMIZATION PREFERENCE: Make sure the CASH asset type is registered in the database.
      // CRITICAL: The asset type must be set to 'stock' because the Supabase check constraint 
      // ('assets_type_check') only permits 'stock', 'etf', or 'crypto'. Type 'cash' will fail replication.
      final cashAssetExists = assets.any((a) => a.id == 'CASH');
      if (!cashAssetExists) {
        await _firestore.saveAsset(Asset(
          id: 'CASH',
          symbol: 'CASH',
          name: 'Cash',
          type: 'stock',
        ));
      }

      // CUSTOMIZATION PREFERENCE: Generate any missing CASH asset transactions for legacy capital account cash flows
      for (final tx in transactions) {
        if (tx.status == 'deleted') continue;
        final account = accounts.cast<Account?>().firstWhere((a) => a?.id == tx.accountId, orElse: () => null);
        if (account != null && account.accountGroup == 'capital') {
          final exists = assetTransactions.any((at) => at.transactionId == tx.id && at.assetId == 'CASH');
          if (!exists) {
            final cashAssetTxId = _firestore.generateId('asset_transactions');
            final cashAssetTx = AssetTransaction(
              id: cashAssetTxId,
              transactionId: tx.id,
              accountId: tx.accountId,
              assetId: 'CASH',
              type: tx.amount < 0 ? 'sell' : 'buy',
              quantity: tx.amount.abs(),
              unitPrice: 1.0,
              executedAt: tx.date,
              assetSymbol: 'CASH',
              assetName: 'Cash',
            );
            await _firestore.saveAssetTransaction(cashAssetTx);
          }
        }
      }

      // CUSTOMIZATION PREFERENCE: Force recalculation of CASH holdings for all capital accounts
      for (final account in accounts) {
        if (account.accountGroup == 'capital') {
          await recalculateHoldingFromScratch(account.id, 'CASH');
        }
      }

      final correctMsftAsset = assets.firstWhere(
        (a) => a.symbol == 'MSFT' && a.id != 'MSFT',
        orElse: () => assets.firstWhere((a) => a.symbol == 'MSFT'),
      );

      final incorrectTxs = assetTransactions.where((tx) => tx.assetId == 'MSFT').toList();
      
      // Perform MSFT asset ID fix if found
      if (incorrectTxs.isNotEmpty) {
        for (final tx in incorrectTxs) {
          // 1. Correct the asset ID in the transaction
          final correctedTx = tx.copyWith(assetId: correctMsftAsset.id);
          await _firestore.saveAssetTransaction(correctedTx);

          // 2. Generate and link the missing cash transaction
          if (tx.transactionId == null && (tx.type == 'buy' || tx.type == 'sell')) {
            final account = accounts.firstWhere((a) => a.id == tx.accountId);
            final totalValue = tx.quantity * tx.unitPrice;
            final amount = tx.type == 'buy' ? -totalValue : totalValue;

            Category matchedCategory;
            if (tx.type == 'buy') {
              matchedCategory = categories.firstWhere(
                (c) => c.type == 'investment' || c.type == 'expense',
                orElse: () => Category(
                  id: 'investment_default',
                  name: 'Investment',
                  type: 'investment',
                  createdAt: DateTime.now(),
                ),
              );
            } else {
              matchedCategory = categories.firstWhere(
                (c) => c.type == 'income' && c.name.toLowerCase().contains('deposit'),
                orElse: () => categories.firstWhere(
                  (c) => c.type == 'income',
                  orElse: () => Category(
                    id: 'deposit_default',
                    name: 'Deposit',
                    type: 'income',
                    createdAt: DateTime.now(),
                  ),
                ),
              );
            }

            final cashTxId = _firestore.generateId('transactions');
            final cashTx = Transaction(
              id: cashTxId,
              accountId: tx.accountId,
              categoryId: matchedCategory.id,
              amount: amount,
              currency: account.currency,
              date: tx.executedAt,
              description: '${tx.type.toUpperCase()} ${tx.quantity} MSFT @ ${tx.unitPrice}',
              createdAt: DateTime.now(),
            );

            await addTransaction(cashTx);
            await _firestore.saveAssetTransaction(correctedTx.copyWith(transactionId: cashTxId));
          }

          // 3. Clear incorrect 'MSFT' key holding
          final incorrectHoldings = holdings.where((h) => h.assetId == 'MSFT' && h.accountId == tx.accountId).toList();
          for (final h in incorrectHoldings) {
            await _firestore.deleteHolding(h.id);
          }

          // 4. Force chronologically accurate recalculation for correct MSFT asset ID
          await recalculateHoldingFromScratch(tx.accountId, correctMsftAsset.id);
        }
      }

      // CUSTOMIZATION PREFERENCE: Ensure any cash transaction linked to a stock/asset sale uses the correct 'Deposit' category
      // instead of 'Salary' or general 'Income'
      final depositCategory = categories.firstWhere(
        (c) => c.type == 'income' && c.name.toLowerCase().contains('deposit'),
        orElse: () => categories.firstWhere(
          (c) => c.type == 'income',
          orElse: () => Category(
            id: 'deposit_default',
            name: 'Deposit',
            type: 'income',
            createdAt: DateTime.now(),
          ),
        ),
      );

      final sales = assetTransactions.where((at) => at.type == 'sell' && at.transactionId != null).toList();
      for (final sale in sales) {
        final matchingCashTxIndex = transactions.indexWhere((t) => t.id == sale.transactionId);
        Transaction? cashTx;
        if (matchingCashTxIndex != -1) {
          cashTx = transactions[matchingCashTxIndex];
        } else {
          cashTx = await _firestore.getTransaction(sale.transactionId!);
        }

        if (cashTx != null && cashTx.categoryId != depositCategory.id) {
          final correctedCashTx = cashTx.copyWith(categoryId: depositCategory.id);
          await _firestore.saveTransaction(correctedCashTx);
          debugPrint('Healed cash transaction ${cashTx.id} category from ${cashTx.categoryId} to ${depositCategory.id}');
        }
      }
    } catch (e) {
      debugPrint('Self-healing database error: $e');
    }
  }
}
