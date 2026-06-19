import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/holding.dart';
import '../models/asset_transaction.dart';
import '../models/account_snapshot.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // --- ACCOUNTS ---
  Future<List<Account>> fetchAccounts() async {
    final response = await _client.from('accounts').select();
    return (response as List).map((data) => Account.fromJson(data)).toList();
  }

  Future<void> saveAccount(Account account) async {
    await _client.from('accounts').upsert(account.toJson());
  }

  Future<void> deleteAccount(String accountId) async {
    await _client.from('accounts').delete().eq('id', accountId);
  }

  // --- CATEGORIES ---
  Future<List<Category>> fetchCategories() async {
    final response = await _client.from('categories').select();
    return (response as List).map((data) => Category.fromJson(data)).toList();
  }

  Future<void> saveCategory(Category category) async {
    await _client.from('categories').upsert(category.toJson());
  }

  // --- TRANSACTIONS ---
  Future<List<Transaction>> fetchTransactions() async {
    final response = await _client.from('transactions').select().order('date', ascending: false);
    return (response as List).map((data) => Transaction.fromJson(data)).toList();
  }

  Future<void> saveTransaction(Transaction tx) async {
    // Format tags array to pg format (handled in database/API mapping, json is fine for postgrest)
    await _client.from('transactions').upsert(tx.toJson());
  }

  Future<void> deleteTransaction(String txId) async {
    await _client.from('transactions').update({'status': 'deleted'}).eq('id', txId);
  }

  // --- HOLDINGS ---
  Future<List<Holding>> fetchHoldings() async {
    final response = await _client.from('holdings').select();
    return (response as List).map((data) => Holding.fromJson(data)).toList();
  }

  Future<void> saveHolding(Holding holding) async {
    await _client.from('holdings').upsert(holding.toJson());
  }

  // --- ASSET TRANSACTIONS ---
  Future<List<AssetTransaction>> fetchAssetTransactions() async {
    final response = await _client.from('asset_transactions').select().order('executed_at', ascending: false);
    return (response as List).map((data) => AssetTransaction.fromJson(data)).toList();
  }

  Future<void> saveAssetTransaction(AssetTransaction tx) async {
    await _client.from('asset_transactions').upsert(tx.toJson());
  }

  // --- ACCOUNT SNAPSHOTS ---
  Future<void> saveAccountSnapshot(AccountSnapshot snapshot) async {
    await _client.from('account_snapshots').upsert(snapshot.toJson());
  }
}
