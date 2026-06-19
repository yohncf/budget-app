import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _formKey = GlobalKey<FormState>();
  
  // Form values
  String? _selectedAccountId;
  String? _selectedTransferToAccountId;
  String? _selectedCategoryId;
  String? _selectedTxCurrency;
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dateController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _showDeleted = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<DataService>(context);
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
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Showing transactions since: ',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.accentCyan,
                          side: const BorderSide(color: AppTheme.accentCyan),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.calendar_today, size: 14),
                        label: Text(DateFormat('yyyy-MM-dd').format(dataService.transactionFilterDate)),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: dataService.transactionFilterDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            dataService.setTransactionFilterDate(picked);
                          }
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      const Text(
                        'Show Deleted',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      Switch(
                        value: _showDeleted,
                        activeColor: AppTheme.accentCyan,
                        onChanged: (val) {
                          setState(() {
                            _showDeleted = val;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Ledger Table/List
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Builder(
                      builder: (context) {
                        final displayTransactions = dataService.transactions.where((tx) {
                          if (tx.status == 'deleted' && !_showDeleted) {
                            return false;
                          }
                          return true;
                        }).toList();

                        if (displayTransactions.isEmpty) {
                          return const Center(
                            child: Text('No transactions registered. Add some to get started.'),
                          );
                        }

                        return ListView.separated(
                          itemCount: displayTransactions.length,
                          separatorBuilder: (context, index) => const Divider(color: Color(0xFF2E2E4A)),
                          itemBuilder: (context, index) {
                            final tx = displayTransactions[index];
                            final isDeleted = tx.status == 'deleted';

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
                              amountColor = isDeleted ? AppTheme.dangerRed.withOpacity(0.5) : AppTheme.dangerRed;
                            } else if (category.type == 'income' || category.type == 'reimbursement') {
                              amountColor = isDeleted ? AppTheme.successGreen.withOpacity(0.5) : AppTheme.successGreen;
                              prefix = '+';
                            } else if (category.type == 'transfer') {
                              amountColor = isDeleted ? AppTheme.accentCyan.withOpacity(0.5) : AppTheme.accentCyan;
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
                                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: isDeleted ? AppTheme.textSecondary.withOpacity(0.5) : null,
                                            decoration: isDeleted ? TextDecoration.lineThrough : null,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: isDeleted ? const Color(0xFF1D1D2C) : const Color(0xFF21213E),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                category.name,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: isDeleted ? AppTheme.textSecondary.withOpacity(0.5) : AppTheme.textSecondary,
                                                  decoration: isDeleted ? TextDecoration.lineThrough : null,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              account.name,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDeleted ? AppTheme.textSecondary.withOpacity(0.5) : AppTheme.textSecondary,
                                                decoration: isDeleted ? TextDecoration.lineThrough : null,
                                              ),
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
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: isDeleted ? AppTheme.textSecondary.withOpacity(0.5) : null,
                                        decoration: isDeleted ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        '$prefix${NumberFormat.simpleCurrency(name: tx.currency).format(tx.amount.abs())} ${tx.currency}',
                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                              color: amountColor,
                                              fontWeight: FontWeight.bold,
                                              decoration: isDeleted ? TextDecoration.lineThrough : null,
                                            ),
                                      ),
                                      if (tx.currency != dataService.displayCurrency)
                                        Text(
                                          'Equiv: ${dataService.formatAndConvert(tx.amount, tx.currency)} ${dataService.displayCurrency}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isDeleted ? AppTheme.textSecondary.withOpacity(0.5) : AppTheme.textSecondary,
                                            decoration: isDeleted ? TextDecoration.lineThrough : null,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  isDeleted
                                      ? const SizedBox(width: 48)
                                      : IconButton(
                                          icon: const Icon(Icons.delete_outline, color: AppTheme.textSecondary),
                                          onPressed: () => dataService.deleteTransaction(tx),
                                        ),
                                ],
                              ),
                            );
                          },
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
    final activeAccounts = dataService.accounts.where((a) => a.status == 'active').toList();
    if (activeAccounts.isEmpty || dataService.categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please register at least one active account and category first.')),
      );
      return;
    }

    // Sort active accounts alphabetically
    activeAccounts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    String transactionType = 'expense';

    setState(() {
      _selectedAccountId = activeAccounts.isNotEmpty ? activeAccounts.first.id : null;
      if (activeAccounts.length > 1) {
        _selectedTransferToAccountId = activeAccounts[1].id;
      } else {
        _selectedTransferToAccountId = activeAccounts.isNotEmpty ? activeAccounts.first.id : null;
      }
      _selectedCategoryId = null; // Start empty/not prefilled
      _selectedTxCurrency = activeAccounts.isNotEmpty ? activeAccounts.first.currency : 'USD';
      _amountController.clear();
      _descriptionController.clear();
      _selectedDate = DateTime.now();
      _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
    });

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            List<Category> filteredCategories = [];
            if (transactionType == 'expense') {
              filteredCategories = dataService.categories.where((c) => c.type == 'expense' || c.type == 'investment').toList();
            } else if (transactionType == 'income') {
              filteredCategories = dataService.categories.where((c) => c.type == 'income' || c.type == 'reimbursement').toList();
            } else {
              filteredCategories = dataService.categories.where((c) => c.type == 'transfer').toList();
            }

            // Sort filtered categories alphabetically
            filteredCategories.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

            if (_selectedCategoryId != null && !filteredCategories.any((c) => c.id == _selectedCategoryId)) {
              _selectedCategoryId = null;
            }

            return AlertDialog(
              backgroundColor: AppTheme.darkCard,
              title: Text(
                'New Transaction',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Date Picker
                        TextFormField(
                          controller: _dateController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Date',
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                _selectedDate = picked;
                                _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        // 2. Transaction Type Selector (SegmentedButton)
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment<String>(
                              value: 'expense',
                              label: Text('Expense'),
                              icon: Icon(Icons.arrow_downward, size: 16),
                            ),
                            ButtonSegment<String>(
                              value: 'income',
                              label: Text('Income'),
                              icon: Icon(Icons.arrow_upward, size: 16),
                            ),
                            ButtonSegment<String>(
                              value: 'transfer',
                              label: Text('Transfer'),
                              icon: Icon(Icons.swap_horiz, size: 16),
                            ),
                          ],
                          selected: {transactionType},
                          showSelectedIcon: false,
                          onSelectionChanged: (newSelection) {
                            setDialogState(() {
                              transactionType = newSelection.first;
                              _selectedCategoryId = null; // Clear pre-fill on type change
                            });
                          },
                          style: SegmentedButton.styleFrom(
                            backgroundColor: const Color(0xFF1D1D22),
                            selectedBackgroundColor: AppTheme.primaryPurple,
                            selectedForegroundColor: Colors.black,
                            foregroundColor: AppTheme.textSecondary,
                            side: const BorderSide(color: Color(0xFF23232A)),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 3. Category (Search + Dropdown)
                        LayoutBuilder(
                          key: ValueKey(transactionType), // Keyed by transaction type to clear when type changes
                          builder: (context, constraints) {
                            return Autocomplete<Category>(
                              initialValue: const TextEditingValue(text: ''), // No pre-filled value
                              displayStringForOption: (Category option) => option.name,
                              optionsBuilder: (TextEditingValue textEditingValue) {
                                final query = textEditingValue.text.trim();
                                if (query.isEmpty) {
                                  return filteredCategories;
                                }
                                return filteredCategories.where((Category option) {
                                  return option.name.toLowerCase().contains(query.toLowerCase());
                                });
                              },
                              fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                                return TextFormField(
                                  controller: textEditingController,
                                  focusNode: focusNode,
                                  decoration: const InputDecoration(
                                    labelText: 'Category',
                                    hintText: 'Search or select category...',
                                    suffixIcon: Icon(Icons.search),
                                  ),
                                  validator: (val) {
                                    if (val == null || val.isEmpty) {
                                      return 'Category is required';
                                    }
                                    final hasMatch = filteredCategories.any((c) => c.name.toLowerCase() == val.trim().toLowerCase());
                                    if (!hasMatch) {
                                      return 'Select a valid category';
                                    }
                                    return null;
                                  },
                                  onChanged: (val) {
                                    final match = filteredCategories.firstWhere(
                                      (c) => c.name.toLowerCase() == val.trim().toLowerCase(),
                                      orElse: () => Category(id: '', name: '', type: '', createdAt: DateTime.now()),
                                    );
                                    if (match.id.isNotEmpty) {
                                      setDialogState(() {
                                        _selectedCategoryId = match.id;
                                      });
                                    }
                                  },
                                );
                              },
                              optionsViewBuilder: (context, onSelected, options) {
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 8,
                                    color: AppTheme.darkCard,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: constraints.maxWidth,
                                      constraints: const BoxConstraints(maxHeight: 200),
                                      decoration: BoxDecoration(
                                        color: AppTheme.darkCard,
                                        border: Border.all(color: const Color(0xFF23232A)),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: ListView.builder(
                                        padding: EdgeInsets.zero,
                                        shrinkWrap: true,
                                        itemCount: options.length,
                                        itemBuilder: (BuildContext context, int index) {
                                          final Category option = options.elementAt(index);
                                          return ListTile(
                                            title: Text(option.name, style: const TextStyle(color: AppTheme.textPrimary)),
                                            hoverColor: Colors.white10,
                                            onTap: () {
                                              onSelected(option);
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                              onSelected: (Category selection) {
                                setDialogState(() {
                                  _selectedCategoryId = selection.id;
                                });
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // Form body based on type:
                        if (transactionType == 'expense' || transactionType == 'income') ...[
                          // Description
                          TextFormField(
                            controller: _descriptionController,
                            decoration: const InputDecoration(labelText: 'Description / Merchant'),
                          ),
                          const SizedBox(height: 16),

                          // Amount (strictly numeric) and Currency
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  controller: _amountController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                                  ],
                                  decoration: const InputDecoration(
                                    labelText: 'Amount',
                                    hintText: '25.50 or 1200.00',
                                  ),
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return 'Amount is required';
                                    }
                                    final amount = double.tryParse(val);
                                    if (amount == null || amount <= 0) {
                                      return 'Enter a valid positive amount';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<String>(
                                  value: _selectedTxCurrency,
                                  decoration: const InputDecoration(labelText: 'Currency'),
                                  items: ['MXN', 'USD', 'SOL', 'PEN'].map<DropdownMenuItem<String>>((String c) {
                                    return DropdownMenuItem(value: c, child: Text(c));
                                  }).toList(),
                                  onChanged: (val) {
                                    setDialogState(() {
                                      _selectedTxCurrency = val;
                                    });
                                  },
                                  validator: (val) => val == null ? 'Required' : null,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Account Dropdown
                          DropdownButtonFormField<String>(
                            value: _selectedAccountId,
                            decoration: const InputDecoration(labelText: 'Account'),
                            items: activeAccounts.map<DropdownMenuItem<String>>((Account a) {
                              return DropdownMenuItem(value: a.id, child: Text(a.name));
                            }).toList(),
                            onChanged: (val) {
                              setDialogState(() {
                                _selectedAccountId = val;
                                if (val != null) {
                                  final acc = activeAccounts.firstWhere((a) => a.id == val);
                                  _selectedTxCurrency = acc.currency;
                                }
                              });
                            },
                            validator: (val) => val == null ? 'Account is required' : null,
                          ),
                        ] else ...[
                          // Transfer Layout:
                          // Source Account (From)
                          DropdownButtonFormField<String>(
                            value: _selectedAccountId,
                            decoration: const InputDecoration(labelText: 'From Account (Source)'),
                            items: activeAccounts.map<DropdownMenuItem<String>>((Account a) {
                              return DropdownMenuItem(value: a.id, child: Text(a.name));
                            }).toList(),
                            onChanged: (val) {
                              setDialogState(() {
                                _selectedAccountId = val;
                              });
                            },
                            validator: (val) => val == null ? 'Source account is required' : null,
                          ),
                          const SizedBox(height: 16),

                          // Destination Account (To)
                          DropdownButtonFormField<String>(
                            value: _selectedTransferToAccountId,
                            decoration: const InputDecoration(labelText: 'To Account (Destination)'),
                            items: activeAccounts.map<DropdownMenuItem<String>>((Account a) {
                              return DropdownMenuItem(value: a.id, child: Text(a.name));
                            }).toList(),
                            onChanged: (val) {
                              setDialogState(() {
                                _selectedTransferToAccountId = val;
                              });
                            },
                            validator: (val) {
                              if (val == null) {
                                return 'Destination account is required';
                              }
                              if (val == _selectedAccountId) {
                                return 'Source and destination accounts must be different';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Amount (strictly numeric)
                          TextFormField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Amount',
                              hintText: '25.50 or 1200.00',
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Amount is required';
                              }
                              final amount = double.tryParse(val);
                              if (amount == null || amount <= 0) {
                                return 'Enter a valid positive amount';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),

                          // Description
                          TextFormField(
                            controller: _descriptionController,
                            decoration: const InputDecoration(labelText: 'Description / Merchant'),
                          ),
                        ]
                      ],
                    ),
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
                    if (!_formKey.currentState!.validate()) {
                      return;
                    }

                    final double? rawAmount = double.tryParse(_amountController.text);
                    if (rawAmount == null || rawAmount == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a valid, non-zero amount.')),
                      );
                      return;
                    }

                    final double absAmount = rawAmount.abs();
                    final messenger = ScaffoldMessenger.of(context);

                    // Unfocus to close autocomplete overlays and keyboard safely before popping
                    FocusManager.instance.primaryFocus?.unfocus();

                    // Wait a frame for the focus change to propagate and overlays to close
                    await Future.delayed(Duration.zero);

                    // Dismiss dialog first to prevent Flutter Web widget tree collision on rebuild
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }

                    try {
                      if (transactionType == 'transfer') {
                        if (_selectedAccountId == _selectedTransferToAccountId) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Source and destination accounts must be different.')),
                          );
                          return;
                        }

                        final sourceAccount = activeAccounts.firstWhere((a) => a.id == _selectedAccountId);
                        final destAccount = activeAccounts.firstWhere((a) => a.id == _selectedTransferToAccountId);

                        // Unified transfer link tag
                        final transferTag = 'transfer_${_uuid.v4()}';

                        // 1. Outflow transaction
                        final outflowTx = Transaction(
                          id: _uuid.v4().substring(0, 20),
                          accountId: _selectedAccountId!,
                          categoryId: _selectedCategoryId!,
                          amount: -absAmount,
                          currency: sourceAccount.currency,
                          date: _selectedDate,
                          description: _descriptionController.text.trim().isEmpty ? 'Internal Transfer' : _descriptionController.text.trim(),
                          tags: [transferTag],
                          createdAt: DateTime.now(),
                        );

                        // 2. Inflow transaction (with currency conversion if different)
                        final inflowAmount = dataService.convert(absAmount, sourceAccount.currency, destAccount.currency);
                        final inflowTx = Transaction(
                          id: _uuid.v4().substring(0, 20),
                          accountId: _selectedTransferToAccountId!,
                          categoryId: _selectedCategoryId!,
                          amount: inflowAmount,
                          currency: destAccount.currency,
                          date: _selectedDate,
                          description: _descriptionController.text.trim().isEmpty ? 'Internal Transfer' : _descriptionController.text.trim(),
                          tags: [transferTag],
                          createdAt: DateTime.now(),
                        );

                        await dataService.addTransaction(outflowTx);
                        await dataService.addTransaction(inflowTx);
                      } else {
                        // Expense or Income
                        double finalAmount = absAmount;
                        if (transactionType == 'expense') {
                          finalAmount = -absAmount;
                        }

                        final selectedAccount = activeAccounts.firstWhere((a) => a.id == _selectedAccountId);
                        final String txCurrency = _selectedTxCurrency ?? selectedAccount.currency;
                        final double exRate = dataService.convert(1.0, txCurrency, selectedAccount.currency);

                        final newTx = Transaction(
                          id: _uuid.v4().substring(0, 20),
                          accountId: _selectedAccountId!,
                          categoryId: _selectedCategoryId!,
                          amount: finalAmount,
                          currency: txCurrency,
                          exchangeRate: exRate,
                          date: _selectedDate,
                          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
                          createdAt: DateTime.now(),
                        );

                        await dataService.addTransaction(newTx);
                      }
                    } catch (e) {
                      messenger.showSnackBar(
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
