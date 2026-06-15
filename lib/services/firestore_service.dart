import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/holding.dart';
import '../models/asset_transaction.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
  Stream<List<Transaction>> streamTransactions() {
    return _db.collection('transactions').orderBy('date', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Transaction.fromJson(data);
      }).toList();
    });
  }

  Future<void> saveTransaction(Transaction tx) async {
    // Update locally or write to firestore
    await _db.collection('transactions').doc(tx.id).set(tx.toJson());
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

  Future<void> saveAssetTransaction(AssetTransaction tx) async {
    await _db.collection('asset_transactions').doc(tx.id).set(tx.toJson());
  }
}
