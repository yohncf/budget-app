import 'package:flutter/foundation.dart' hide Category;
import 'firestore_service.dart';
import 'supabase_service.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/holding.dart';
import '../models/asset_transaction.dart';

class DataService extends ChangeNotifier {
  final FirestoreService _firestore = FirestoreService();
  SupabaseService? _supabase;

  List<Account> accounts = [];
  List<Category> categories = [];
  List<Transaction> transactions = [];
  List<Holding> holdings = [];
  List<AssetTransaction> assetTransactions = [];

  bool isLoading = false;
  String? error;

  DataService() {
    try {
      _supabase = SupabaseService();
    } catch (e) {
      debugPrint("Supabase not initialized: $e");
    }
    _listenToFirestore();
  }

  // Bind real-time Firestore streams to update local state and notify listeners
  void _listenToFirestore() {
    isLoading = true;
    notifyListeners();

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

    _firestore.streamTransactions().listen((data) {
      transactions = data;
      notifyListeners();
    });

    _firestore.streamHoldings().listen((data) {
      holdings = data;
      notifyListeners();
    });

    _firestore.streamAssetTransactions().listen((data) {
      assetTransactions = data;
      notifyListeners();
    });
  }

  // --- MUTATION METHODS WITH SUPABASE BACKUP ---

  Future<void> addAccount(Account account) async {
    // Write to Primary (Firestore)
    await _firestore.saveAccount(account);

    // Sync to Backup (Supabase)
    if (_supabase != null) {
      try {
        await _supabase!.saveAccount(account);
      } catch (e) {
        debugPrint("Supabase backup failed for account: $e");
      }
    }
  }

  Future<void> deleteAccount(String id) async {
    await _firestore.deleteAccount(id);
    if (_supabase != null) {
      try {
        await _supabase!.deleteAccount(id);
      } catch (e) {
        debugPrint("Supabase backup delete failed: $e");
      }
    }
  }

  Future<void> addCategory(Category category) async {
    await _firestore.saveCategory(category);
    if (_supabase != null) {
      try {
        await _supabase!.saveCategory(category);
      } catch (e) {
        debugPrint("Supabase backup failed for category: $e");
      }
    }
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

    // 3. Update current balance in primary db (if Firestore rules don't auto-calculate, we do it in service)
    final account = accounts.firstWhere((a) => a.id == tx.accountId);
    final updatedAccount = account.copyWith(
      currentBalance: account.currentBalance + tx.amount,
      updatedAt: DateTime.now(),
    );
    await _firestore.saveAccount(updatedAccount);

    // 4. Sync transaction and account changes to Supabase backup
    if (_supabase != null) {
      try {
        await _supabase!.saveTransaction(tx);
        await _supabase!.saveAccount(updatedAccount);
      } catch (e) {
        debugPrint("Supabase backup failed for transaction/account balance update: $e");
      }
    }
  }

  Future<void> deleteTransaction(Transaction tx) async {
    await _firestore.deleteTransaction(tx.id);

    final account = accounts.firstWhere((a) => a.id == tx.accountId);
    final updatedAccount = account.copyWith(
      currentBalance: account.currentBalance - tx.amount,
      updatedAt: DateTime.now(),
    );
    await _firestore.saveAccount(updatedAccount);

    if (_supabase != null) {
      try {
        await _supabase!.deleteTransaction(tx.id);
        await _supabase!.saveAccount(updatedAccount);
      } catch (e) {
        debugPrint("Supabase backup delete failed for transaction: $e");
      }
    }
  }

  Future<void> addAssetTransaction(AssetTransaction assetTx, {double? cashImpactAmount}) async {
    // Write asset transaction execution log
    await _firestore.saveAssetTransaction(assetTx);

    // Write to Supabase backup
    if (_supabase != null) {
      try {
        await _supabase!.saveAssetTransaction(assetTx);
      } catch (e) {
        debugPrint("Supabase backup failed for asset transaction: $e");
      }
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
    if (_supabase != null) {
      try {
        await _supabase!.saveHolding(newHolding);
      } catch (e) {
        debugPrint("Supabase backup failed for holdings update: $e");
      }
    }
  }

  // --- CALCULATION HELPER FUNCTIONS ---

  double get netWorth {
    double liquidCash = accounts.fold(0.0, (sum, item) {
      if (item.type == 'credit_card') {
        return sum - item.currentBalance; // Subtract debt
      }
      return sum + item.currentBalance; // Add checking, savings, sweep cash
    });
    
    // In production, we'd multiply holding.quantity * liveMarketPrice.
    // For now we use the average buy price (cost basis) as holding valuation placeholder
    double liveHoldingsValue = holdings.fold(0.0, (sum, item) {
      return sum + (item.quantity * item.avgBuyPrice);
    });

    return liquidCash + liveHoldingsValue;
  }
}
