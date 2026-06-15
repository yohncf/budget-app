import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../core/theme.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class AccountsPage extends StatefulWidget {
  const AccountsPage({super.key});

  @override
  State<AccountsPage> createState() => _AccountsPageState();
}

class _AccountsPageState extends State<AccountsPage> {
  final _uuid = const Uuid();

  // Form values
  final _nameController = TextEditingController();
  final _institutionController = TextEditingController();
  String _selectedType = 'checking';
  final _balanceController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _institutionController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<DataService>(context);
    final currencyFormatter = NumberFormat.simpleCurrency(name: 'USD');

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Accounts Management',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Create and monitor liquidity, brokerage containers, and debt accounts',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentCyan,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.account_balance),
                    label: const Text('New Account'),
                    onPressed: () => _showAddAccountDialog(context, dataService),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Accounts Grid
              Expanded(
                child: dataService.accounts.isEmpty
                    ? const Center(
                        child: Text('No accounts registered yet.'),
                      )
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 350,
                          mainAxisSpacing: 20,
                          crossAxisSpacing: 20,
                          childAspectRatio: 1.4,
                        ),
                        itemCount: dataService.accounts.length,
                        itemBuilder: (context, index) {
                          final account = dataService.accounts[index];
                          
                          double totalVal = account.currentBalance;
                          bool isBrokerage = account.type == 'investment' || account.type == 'retirement';
                          
                          if (isBrokerage) {
                            final accountHoldings = dataService.holdings.where((h) => h.accountId == account.id);
                            double holdingsVal = accountHoldings.fold(0.0, (sum, item) => sum + (item.quantity * item.avgBuyPrice));
                            totalVal = account.currentBalance + holdingsVal;
                          }

                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF21213E),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          account.type == 'credit_card'
                                              ? Icons.credit_card
                                              : (isBrokerage ? Icons.analytics : Icons.account_balance_wallet),
                                          color: AppTheme.accentCyan,
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.textSecondary),
                                        onPressed: () => dataService.deleteAccount(account.id),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  Text(
                                    account.name,
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${account.institution ?? "Unknown"} • ${account.type.toUpperCase()}',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
                                  ),
                                  const Spacer(),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        currencyFormatter.format(totalVal),
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: account.type == 'credit_card' ? AppTheme.dangerRed : AppTheme.textPrimary,
                                            ),
                                      ),
                                      if (isBrokerage)
                                        Text(
                                          'Cash sweep: ${currencyFormatter.format(account.currentBalance)}',
                                          style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddAccountDialog(BuildContext context, DataService dataService) {
    setState(() {
      _nameController.clear();
      _institutionController.clear();
      _balanceController.clear();
      _selectedType = 'checking';
    });

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.darkCard,
              title: Text('Register New Account', style: Theme.of(context).textTheme.titleLarge),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Account Name', hintText: 'Chase Sapphire / sweep cash'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _institutionController,
                        decoration: const InputDecoration(labelText: 'Institution', hintText: 'Chase / Binance'),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Account Type'),
                        items: ['checking', 'savings', 'credit_card', 'investment', 'crypto_wallet', 'retirement'].map((t) {
                          return DropdownMenuItem(value: t, child: Text(t.toUpperCase()));
                        }).toList(),
                        onChanged: (val) => setDialogState(() => _selectedType = val!),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _balanceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Opening Balance (Initial Transaction value)'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCyan),
                  child: const Text('Create'),
                  onPressed: () async {
                    if (_nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter an account name.')),
                      );
                      return;
                    }

                    final double initBalance = double.tryParse(_balanceController.text) ?? 0.0;
                    final accId = _uuid.v4().substring(0, 20);

                    final newAcc = Account(
                      id: accId,
                      name: _nameController.text.trim(),
                      institution: _institutionController.text.trim().isEmpty ? null : _institutionController.text.trim(),
                      type: _selectedType,
                      currency: 'USD',
                      currentBalance: 0.0, // Rule 2.2: opening balance is created as transaction, not hardcoded initial state!
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );

                    await dataService.addAccount(newAcc);

                    // Rule 2.2: Opening balance is a transaction using System Category: Opening Balance
                    if (initBalance != 0) {
                      Category? opCat;
                      for (var c in dataService.categories) {
                        if (c.name == 'System: Opening Balance') {
                          opCat = c;
                          break;
                        }
                      }
                      if (opCat == null) {
                        opCat = Category(
                          id: 'sys_opening_balance',
                          name: 'System: Opening Balance',
                          type: 'income',
                          createdAt: DateTime.now(),
                        );
                        await dataService.addCategory(opCat);
                      }

                      final opTx = Transaction(
                        id: _uuid.v4().substring(0, 20),
                        accountId: accId,
                        categoryId: opCat.id,
                        amount: initBalance,
                        currency: 'USD',
                        date: DateTime.now(),
                        description: 'System: Opening Balance Initialization',
                        createdAt: DateTime.now(),
                      );
                      await dataService.addTransaction(opTx);
                    }

                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}
