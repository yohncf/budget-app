import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import '../models/transaction.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../core/theme.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class LedgerPage extends StatefulWidget {
  const LedgerPage({super.key});

  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  final _uuid = const Uuid();
  
  // Form values
  String? _selectedAccountId;
  String? _selectedCategoryId;
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<DataService>(context);
    final currencyFormatter = NumberFormat.simpleCurrency(name: 'USD');
    final dateFormatter = DateFormat('yyyy-MM-dd HH:mm');

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
                        'Transaction Ledger',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Detailed historical cash movement records',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Transaction'),
                    onPressed: () => _showAddTransactionDialog(context, dataService),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Ledger Table/List
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: dataService.transactions.isEmpty
                        ? const Center(
                            child: Text('No transactions registered. Add some to get started.'),
                          )
                        : ListView.separated(
                            itemCount: dataService.transactions.length,
                            separatorBuilder: (context, index) => const Divider(color: Color(0xFF2E2E4A)),
                            itemBuilder: (context, index) {
                              final tx = dataService.transactions[index];
                              Account? account;
                              for (var a in dataService.accounts) {
                                if (a.id == tx.accountId) {
                                  account = a;
                                  break;
                                }
                              }
                              account ??= Account(id: '', name: 'Deleted Account', type: 'checking', currency: 'USD', createdAt: DateTime.now(), updatedAt: DateTime.now());

                              Category? category;
                              for (var c in dataService.categories) {
                                if (c.id == tx.categoryId) {
                                  category = c;
                                  break;
                                }
                              }
                              category ??= Category(id: '', name: 'Uncategorized', type: 'expense', createdAt: DateTime.now());

                              Color amountColor = Colors.white;
                              String prefix = '';
                              if (category.type == 'expense') {
                                amountColor = AppTheme.dangerRed;
                              } else if (category.type == 'income' || category.type == 'reimbursement') {
                                amountColor = AppTheme.successGreen;
                                prefix = '+';
                              } else if (category.type == 'transfer') {
                                amountColor = AppTheme.accentCyan;
                              }

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tx.description ?? 'No description',
                                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF21213E),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  category.name,
                                                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                account.name,
                                                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                              ),
                                            ],
                                          )
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        dateFormatter.format(tx.date),
                                        style: Theme.of(context).textTheme.bodyMedium,
                                      ),
                                    ),
                                    Text(
                                      '$prefix${currencyFormatter.format(tx.amount)}',
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                            color: amountColor,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: AppTheme.textSecondary),
                                      onPressed: () => dataService.deleteTransaction(tx),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddTransactionDialog(BuildContext context, DataService dataService) {
    if (dataService.accounts.isEmpty || dataService.categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please register at least one account and category first.')),
      );
      return;
    }

    setState(() {
      _selectedAccountId = dataService.accounts.first.id;
      _selectedCategoryId = dataService.categories.first.id;
      _amountController.clear();
      _descriptionController.clear();
      _selectedDate = DateTime.now();
    });

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.darkCard,
              title: Text(
                'New Cash Transaction',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Accounts list dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedAccountId,
                        decoration: const InputDecoration(labelText: 'Account'),
                        items: dataService.accounts.map<DropdownMenuItem<String>>((Account a) {
                          return DropdownMenuItem(value: a.id, child: Text(a.name));
                        }).toList(),
                        onChanged: (val) => setDialogState(() => _selectedAccountId = val),
                      ),
                      const SizedBox(height: 16),

                      // Categories list dropdown
                      DropdownButtonFormField<String>(
                        value: _selectedCategoryId,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: dataService.categories.map<DropdownMenuItem<String>>((Category c) {
                          return DropdownMenuItem(value: c.id, child: Text('${c.name} (${c.type.toUpperCase()})'));
                        }).toList(),
                        onChanged: (val) => setDialogState(() => _selectedCategoryId = val),
                      ),
                      const SizedBox(height: 16),

                      // Amount (requires sign rules based on category type)
                      TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          hintText: '-25.50 or 1200.00',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Description
                      TextField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(labelText: 'Description / Merchant'),
                      ),
                      const SizedBox(height: 16),

                      // Date selector
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}'),
                          TextButton(
                            child: const Text('Change Date'),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _selectedDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setDialogState(() => _selectedDate = picked);
                              }
                            },
                          ),
                        ],
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
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple),
                  child: const Text('Save'),
                  onPressed: () async {
                    final double? amount = double.tryParse(_amountController.text);
                    if (amount == null || amount == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid, non-zero amount.')),
                      );
                      return;
                    }

                    final newTx = Transaction(
                      id: _uuid.v4().substring(0, 20), // 20-character PK string
                      accountId: _selectedAccountId!,
                      categoryId: _selectedCategoryId!,
                      amount: amount,
                      currency: 'USD',
                      date: _selectedDate,
                      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
                      createdAt: DateTime.now(),
                    );

                    try {
                      await dataService.addTransaction(newTx);
                      Navigator.of(context).pop();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: ${e.toString()}')),
                      );
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
