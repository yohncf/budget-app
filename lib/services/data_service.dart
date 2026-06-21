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
import 'package:supabase_flutter/supabase_flutter.dart';

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

  String formatCurrency(double amount) {
    return NumberFormat.simpleCurrency(name: displayCurrency).format(amount);
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
            body: json.encode(records),
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
    }, onError: (err) {
      error = err.toString();
      notifyListeners();
    });

    _firestore.streamCategories().listen((data) {
      categories = data;
      notifyListeners();
    });

    transactionFilterDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
    setTransactionFilterDate(transactionFilterDate);

    _firestore.streamHoldings().listen((data) {
      holdings = data;
      notifyListeners();
    });

    _firestore.streamAssetTransactions().listen((data) {
      assetTransactions = data;
      notifyListeners();
    });

    _firestore.streamAssets().listen((data) {
      assets = data;
      notifyListeners();
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
          }
        }
      }
    }
  }


  Future<void> addAssetTransaction(AssetTransaction assetTx, {double? cashImpactAmount, String? assetType}) async {
    // Write asset transaction execution log
    await _firestore.saveAssetTransaction(assetTx);

    // If asset doesn't exist in our list, create it
    final exists = assets.any((a) => a.id == assetTx.assetId);
    if (!exists) {
      final symbol = assetTx.assetSymbol ?? assetTx.assetId;
      final name = assetTx.assetName ?? symbol;
      final type = assetType ?? 'stock';
      await _firestore.saveAsset(Asset(id: assetTx.assetId, symbol: symbol, name: name, type: type));
    }

    // Recalculate holding inventory
    _recalculateHolding(assetTx);
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

  double get netWorth {
    double totalDisplayValue = 0.0;
    
    for (var acc in accounts) {
      if (acc.status != 'active') continue;
      
      double balanceInDisplay = convertToDisplay(acc.currentBalance, acc.currency);
      if (acc.type == 'credit_card') {
        totalDisplayValue -= balanceInDisplay;
      } else {
        totalDisplayValue += balanceInDisplay;
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
      
      double holdingValueInAccountCurrency = holding.quantity * holding.avgBuyPrice;
      double holdingValueInDisplay = convertToDisplay(holdingValueInAccountCurrency, acc.currency);
      totalDisplayValue += holdingValueInDisplay;
    }

    return totalDisplayValue;
  }
}
