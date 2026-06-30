import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import '../models/account.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/holding.dart';
import '../models/asset_transaction.dart';
import '../models/account_snapshot.dart';
import '../models/asset.dart';
import '../models/budget_target.dart';
import '../models/recurring_transaction.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String generateId(String collectionName) {
    return _db.collection(collectionName).doc().id;
  }

  // --- ACCOUNTS ---
  Stream<List<Account>> streamAccounts() {
    return _db.collection('accounts').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Account.fromJson(data);
      }).toList();
    });
  }

  Future<void> saveAccount(Account account) async {
    await _db.collection('accounts').doc(account.id).set(account.toJson());
  }

  Future<void> deleteAccount(String accountId) async {
    await _db.collection('accounts').doc(accountId).delete();
  }

  // --- CATEGORIES ---
  Stream<List<Category>> streamCategories() {
    return _db.collection('categories').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Category.fromJson(data);
      }).toList();
    });
  }

  Future<void> saveCategory(Category category) async {
    await _db.collection('categories').doc(category.id).set(category.toJson());
  }

  // --- TRANSACTIONS ---
  Stream<List<Transaction>> streamTransactions({DateTime? startFrom}) {
    Query query = _db.collection('transactions').orderBy('date', descending: true);
    if (startFrom != null) {
      query = query.where('date', isGreaterThanOrEqualTo: startFrom);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Transaction.fromJson(data);
      }).toList();
    });
  }

  Future<void> saveTransaction(Transaction tx) async {
    // Update locally or write to firestore
    await _db.collection('transactions').doc(tx.id).set(tx.toJson());
  }

  Future<Transaction?> getTransaction(String txId) async {
    final doc = await _db.collection('transactions').doc(txId).get();
    if (!doc.exists || doc.data() == null) return null;
    final data = doc.data()!;
    data['id'] = doc.id;
    return Transaction.fromJson(data);
  }

  Future<void> deleteTransaction(String txId) async {
    await _db.collection('transactions').doc(txId).delete();
  }

  // --- HOLDINGS ---
  Stream<List<Holding>> streamHoldings() {
    return _db.collection('holdings').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Holding.fromJson(data);
      }).toList();
    });
  }

  Future<void> saveHolding(Holding holding) async {
    await _db.collection('holdings').doc(holding.id).set(holding.toJson());
  }

  // --- ASSETS ---
  Stream<List<Asset>> streamAssets() {
    return _db.collection('assets').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Asset.fromJson(data);
      }).toList();
    });
  }

  Future<void> saveAsset(Asset asset) async {
    await _db.collection('assets').doc(asset.id).set(asset.toJson());
  }

  Future<void> deleteAsset(String assetId) async {
    await _db.collection('assets').doc(assetId).delete();
  }

  // --- ASSET TRANSACTIONS ---
  Stream<List<AssetTransaction>> streamAssetTransactions() {
    return _db.collection('asset_transactions').orderBy('executed_at', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return AssetTransaction.fromJson(data);
      }).toList();
    });
  }

  Stream<List<AssetTransaction>> streamAssetTransactionsPaged({required int limit}) {
    return _db.collection('asset_transactions')
        .orderBy('executed_at', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return AssetTransaction.fromJson(data);
      }).toList();
    });
  }

  Future<void> saveAssetTransaction(AssetTransaction tx) async {
    await _db.collection('asset_transactions').doc(tx.id).set(tx.toJson());
  }

  Future<void> deleteAssetTransaction(String id) async {
    await _db.collection('asset_transactions').doc(id).delete();
  }

  Future<void> deleteHolding(String id) async {
    await _db.collection('holdings').doc(id).delete();
  }

  // --- EXCHANGE RATES ---
  Future<Map<String, dynamic>?> getExchangeRateConfig() async {
    try {
      final doc = await _db.collection('config').doc('currency_rates').get();
      return doc.data();
    } catch (e) {
      return null;
    }
  }

  Future<void> saveExchangeRateConfig(Map<String, dynamic> data) async {
    await _db.collection('config').doc('currency_rates').set(data);
  }

  // --- ASSET PRICES ---
  Future<Map<String, dynamic>?> getAssetPriceConfig() async {
    try {
      final doc = await _db.collection('config').doc('asset_prices').get();
      return doc.data();
    } catch (e) {
      return null;
    }
  }

  Future<void> saveAssetPriceConfig(Map<String, dynamic> data) async {
    await _db.collection('config').doc('asset_prices').set(data);
  }

  // --- ENABLED CURRENCIES ---
  Stream<List<String>> streamEnabledCurrencies() {
    return _db.collection('config').doc('currency_preferences').snapshots().map((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        if (data['enabled_currencies'] != null) {
          return List<String>.from(data['enabled_currencies']);
        }
      }
      return ['MXN', 'USD', 'SOL'];
    });
  }

  Future<void> saveEnabledCurrencies(List<String> currencies) async {
    await _db.collection('config').doc('currency_preferences').set({
      'enabled_currencies': currencies,
    });
  }

  // --- DATABASE DATE TYPE MIGRATION ---
  Future<void> migrateDatabaseDates() async {
    try {
      final collectionsToMigrate = {
        'transactions': ['date', 'created_at'],
        'accounts': ['created_at', 'updated_at'],
        'categories': ['created_at'],
        'holdings': ['updated_at'],
        'asset_transactions': ['executed_at'],
        'account_snapshots': ['created_at'],
      };

      for (var entry in collectionsToMigrate.entries) {
        final collectionName = entry.key;
        final dateFields = entry.value;

        final snapshot = await _db.collection(collectionName).get();
        final batch = _db.batch();
        bool hasUpdates = false;

        for (var doc in snapshot.docs) {
          final data = doc.data();
          final Map<String, dynamic> updates = {};

          for (var field in dateFields) {
            final val = data[field];
            if (val is String) {
              try {
                updates[field] = DateTime.parse(val);
              } catch (_) {}
            }
          }

          if (updates.isNotEmpty) {
            batch.update(doc.reference, updates);
            hasUpdates = true;
          }
        }

        if (hasUpdates) {
          await batch.commit();
          // Use print or debugPrint here
        }
      }
    } catch (e) {
      // Ignore migration errors in production
    }
  }

  // --- DATABASE BACKUP STATE & CONVERSION ---
  Future<Map<String, dynamic>?> getBackupState() async {
    try {
      final doc = await _db.collection('config').doc('backup_state').get();
      return doc.data();
    } catch (e) {
      return null;
    }
  }

  Future<void> saveBackupState(Map<String, dynamic> data) async {
    await _db.collection('config').doc('backup_state').set(data);
  }

  Future<List<Map<String, dynamic>>> getBackupCollection(String collectionId) async {
    final snapshot = await _db.collection(collectionId).get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return _formatForSupabase(data);
    }).toList();
  }

  Map<String, dynamic> _formatForSupabase(Map<String, dynamic> record) {
    final formatted = <String, dynamic>{};
    record.forEach((key, value) {
      if (value is Timestamp) {
        final date = value.toDate();
        if (key == 'snapshot_date' || key == 'start_date' || key == 'end_date' || key == 'next_due_date') {
          formatted[key] = date.toIso8601String().split('T')[0];
        } else {
          formatted[key] = date.toUtc().toIso8601String();
        }
      } else if (value is DateTime) {
        if (key == 'snapshot_date' || key == 'start_date' || key == 'end_date' || key == 'next_due_date') {
          formatted[key] = value.toIso8601String().split('T')[0];
        } else {
          formatted[key] = value.toUtc().toIso8601String();
        }
      } else if (key == 'tags' && value is List) {
        formatted[key] = List<String>.from(value);
      } else if (value is num) {
        formatted[key] = value.toDouble();
      } else {
        formatted[key] = value;
      }
    });
    return formatted;
  }

  // --- ACCOUNT SNAPSHOTS ---
  Stream<List<AccountSnapshot>> streamAccountSnapshots() {
    return _db.collection('account_snapshots').orderBy('snapshot_date', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return AccountSnapshot.fromJson(data);
      }).toList();
    });
  }

  Future<void> saveAccountSnapshot(AccountSnapshot snapshot) async {
    await _db.collection('account_snapshots').doc(snapshot.id).set(snapshot.toJson());
  }

  // --- BUDGET TARGETS ---
  Stream<List<BudgetTarget>> streamBudgetTargets() {
    return _db.collection('budget_targets').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return BudgetTarget.fromJson(data);
      }).toList();
    });
  }

  Future<void> saveBudgetTarget(BudgetTarget target) async {
    await _db.collection('budget_targets').doc(target.id).set(target.toJson());
  }

  // --- RECURRING TRANSACTIONS ---
  Stream<List<RecurringTransaction>> streamRecurringTransactions() {
    return _db.collection('recurring_transactions').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return RecurringTransaction.fromJson(data);
      }).toList();
    });
  }

  Future<void> saveRecurringTransaction(RecurringTransaction rt) async {
    await _db.collection('recurring_transactions').doc(rt.id).set(rt.toJson());
  }

  Future<void> deleteRecurringTransaction(String id) async {
    await _db.collection('recurring_transactions').doc(id).delete();
  }
}

