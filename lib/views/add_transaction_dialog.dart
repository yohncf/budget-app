import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../services/data_service.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../core/theme.dart';

/// Standalone dialog for adding or editing a cash ledger transaction.
/// Can be invoked globally from any page of the app.
class AddTransactionDialog extends StatefulWidget {
  final DataService dataService;
  final Transaction? editTx;

  const AddTransactionDialog({
    super.key,
    required this.dataService,
    this.editTx,
  });

  @override
  State<AddTransactionDialog> createState() => _AddTransactionDialogState();
}

class _AddTransactionDialogState extends State<AddTransactionDialog> {
  final _uuid = const Uuid();
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _dateController;

  late DateTime _selectedDate;
  String? _selectedAccountId;
  String? _selectedTransferToAccountId;
  String? _selectedCategoryId;
  String? _selectedTxCurrency;
  late String _transactionType;
  String? _transferTag;
  Transaction? _pairedTx;
  late final List<Account> _dialogAccounts;

  @override
  void initState() {
    super.initState();
    final dataService = widget.dataService;
    final activeAccounts = dataService.accounts.where((a) => a.status == 'active').toList();
    
    // Sort active accounts alphabetically
    activeAccounts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    // Create a list of accounts that includes archived/inactive ones if editing
    _dialogAccounts = List.from(activeAccounts);
    
    if (widget.editTx != null) {
      final editTx = widget.editTx!;
      Account? acc1;
      for (final a in dataService.accounts) {
        if (a.id == editTx.accountId) {
          acc1 = a;
          break;
        }
      }
      final nonNullAcc1 = acc1;
      if (nonNullAcc1 != null && !_dialogAccounts.any((a) => a.id == nonNullAcc1.id)) {
        _dialogAccounts.add(nonNullAcc1);
      }
      
      for (final tag in editTx.tags) {
        if (tag.startsWith('transfer_')) {
          _transferTag = tag;
          break;
        }
      }
      
      if (_transferTag != null) {
        for (final t in dataService.transactions) {
          if (t.id != editTx.id && t.tags.contains(_transferTag) && t.status != 'deleted') {
            _pairedTx = t;
            break;
          }
        }
        final nonNullPairedTx = _pairedTx;
        if (nonNullPairedTx != null) {
          Account? acc2;
          for (final a in dataService.accounts) {
            if (a.id == nonNullPairedTx.accountId) {
              acc2 = a;
              break;
            }
          }
          final nonNullAcc2 = acc2;
          if (nonNullAcc2 != null && !_dialogAccounts.any((a) => a.id == nonNullAcc2.id)) {
            _dialogAccounts.add(nonNullAcc2);
          }
        }
      }
    }

    _transactionType = 'expense';
    if (widget.editTx != null) {
      if (_transferTag != null) {
        _transactionType = 'transfer';
      } else {
        final cat = dataService.categories.firstWhere(
          (c) => c.id == widget.editTx!.categoryId,
          orElse: () => Category(id: '', name: 'Unknown', type: 'expense', createdAt: DateTime.now()),
        );
        if (cat.type == 'income' || cat.type == 'reimbursement') {
          _transactionType = 'income';
        } else {
          _transactionType = 'expense';
        }
      }
    }

    if (widget.editTx != null) {
      final editTx = widget.editTx!;
      if (_transactionType == 'transfer') {
        final outflow = editTx.amount < 0 ? editTx : _pairedTx;
        final inflow = editTx.amount < 0 ? _pairedTx : editTx;
        
        _selectedAccountId = outflow?.accountId;
        _selectedTransferToAccountId = inflow?.accountId;
        _selectedCategoryId = editTx.categoryId;
        _selectedTxCurrency = outflow?.currency ?? editTx.currency;
        _amountController = TextEditingController(text: editTx.amount.abs().toString());
        _descriptionController = TextEditingController(text: editTx.description ?? '');
        _selectedDate = editTx.date;
      } else {
        _selectedAccountId = editTx.accountId;
        _selectedTransferToAccountId = _dialogAccounts.length > 1 ? _dialogAccounts[1].id : (_dialogAccounts.isNotEmpty ? _dialogAccounts.first.id : null);
        _selectedCategoryId = editTx.categoryId;
        _selectedTxCurrency = editTx.currency;
        _amountController = TextEditingController(text: editTx.amount.abs().toString());
        _descriptionController = TextEditingController(text: editTx.description ?? '');
        _selectedDate = editTx.date;
      }
    } else {
      _selectedAccountId = null;
      if (_dialogAccounts.length > 1) {
        _selectedTransferToAccountId = _dialogAccounts[1].id;
      } else {
        _selectedTransferToAccountId = _dialogAccounts.isNotEmpty ? _dialogAccounts.first.id : null;
      }
      _selectedCategoryId = null;
      _selectedTxCurrency = 'MXN';
      _amountController = TextEditingController();
      _descriptionController = TextEditingController();
      _selectedDate = DateTime.now();
    }
    _dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(_selectedDate));
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataService = widget.dataService;
    final editTx = widget.editTx;
    final pairedTx = _pairedTx;
    final transferTag = _transferTag;
    final dialogAccounts = _dialogAccounts;

    final expIncAccounts = dialogAccounts.where((a) => a.type == 'checking' || a.type == 'credit_card').toList();

    List<Category> filteredCategories = [];
    if (_transactionType == 'expense') {
      filteredCategories = dataService.categories.where((c) => c.type == 'expense' || c.type == 'investment').toList();
    } else if (_transactionType == 'income') {
      filteredCategories = dataService.categories.where((c) => c.type == 'income' || c.type == 'reimbursement').toList();
    } else {
      filteredCategories = dataService.categories.where((c) => c.type == 'transfer').toList();
    }

    // Sort filtered categories alphabetically
    filteredCategories.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (_selectedCategoryId != null && !filteredCategories.any((c) => c.id == _selectedCategoryId)) {
      _selectedCategoryId = null;
    }

    return StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          backgroundColor: AppTheme.darkCard,
          title: Text(
            editTx != null ? 'Edit Transaction' : 'New Transaction',
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
                      segments: [
                        ButtonSegment<String>(
                          value: 'expense',
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Expense', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          icon: MediaQuery.of(context).size.width < 600 ? null : const Icon(Icons.arrow_downward, size: 14),
                        ),
                        ButtonSegment<String>(
                          value: 'income',
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Income', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          icon: MediaQuery.of(context).size.width < 600 ? null : const Icon(Icons.arrow_upward, size: 14),
                        ),
                        ButtonSegment<String>(
                          value: 'transfer',
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Transfer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          icon: MediaQuery.of(context).size.width < 600 ? null : const Icon(Icons.swap_horiz, size: 14),
                        ),
                      ],
                      selected: {_transactionType},
                      showSelectedIcon: false,
                      onSelectionChanged: (newSelection) {
                        setDialogState(() {
                          _transactionType = newSelection.first;
                          _selectedCategoryId = null; // Clear pre-fill on type change

                          if (_transactionType == 'income') {
                            final defaultAcc = expIncAccounts.firstWhere(
                              (a) => a.name.toLowerCase().contains('debit'),
                              orElse: () => expIncAccounts.firstWhere(
                                (a) => a.type == 'checking',
                                orElse: () => expIncAccounts.isNotEmpty ? expIncAccounts.first : dialogAccounts.first,
                              ),
                            );
                            _selectedAccountId = defaultAcc.id;
                            _selectedTxCurrency = defaultAcc.currency;
                          } else if (_transactionType == 'expense') {
                            _selectedAccountId = null;
                          }
                        });
                      },
                      style: SegmentedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D1D22),
                        selectedBackgroundColor: AppTheme.primaryPurple,
                        selectedForegroundColor: Colors.black,
                        foregroundColor: AppTheme.textSecondary,
                        side: const BorderSide(color: Color(0xFF23232A)),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 3. Category (Search + Dropdown Menu)
                    LayoutBuilder(
                      key: ValueKey('${_transactionType}_$_selectedCategoryId'),
                      builder: (context, constraints) {
                        final currentCategory = filteredCategories.firstWhere(
                          (c) => c.id == _selectedCategoryId,
                          orElse: () => Category(id: '', name: '', type: '', createdAt: DateTime.now()),
                        );
                        return Autocomplete<Category>(
                          initialValue: TextEditingValue(text: currentCategory.name),
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
                              decoration: InputDecoration(
                                labelText: 'Category',
                                hintText: 'Select category...',
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.arrow_drop_down),
                                  onPressed: () {
                                    if (focusNode.hasFocus) {
                                      focusNode.unfocus();
                                    } else {
                                      focusNode.requestFocus();
                                    }
                                  },
                                ),
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
                                } else {
                                  setDialogState(() {
                                    _selectedCategoryId = null;
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
                    if (_transactionType == 'expense' || _transactionType == 'income') ...[
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
                              items: (() {
                                final list = List<String>.from(dataService.availableDisplayCurrencies);
                                if (_selectedTxCurrency != null && !list.contains(_selectedTxCurrency)) {
                                  list.add(_selectedTxCurrency!);
                                }
                                return list;
                              })().map<DropdownMenuItem<String>>((String c) {
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

                      // Account (Search + Dropdown)
                      LayoutBuilder(
                        key: ValueKey('${_transactionType}_account_$_selectedAccountId'),
                        builder: (context, constraints) {
                          final currentAccount = dialogAccounts.firstWhere(
                            (a) => a.id == _selectedAccountId,
                            orElse: () => Account(id: '', name: '', type: 'checking', currency: 'USD', createdAt: DateTime.now(), updatedAt: DateTime.now()),
                          );
                          return Autocomplete<Account>(
                            initialValue: TextEditingValue(text: currentAccount.id.isNotEmpty ? currentAccount.name : ''),
                            displayStringForOption: (Account option) => option.name,
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              final query = textEditingValue.text.trim();
                              if (query.isEmpty) {
                                return expIncAccounts;
                              }
                              return expIncAccounts.where((Account option) {
                                return option.name.toLowerCase().contains(query.toLowerCase());
                              });
                            },
                            fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                              return TextFormField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                decoration: const InputDecoration(
                                  labelText: 'Account',
                                  hintText: 'Search or select account...',
                                  suffixIcon: Icon(Icons.search),
                                ),
                                validator: (val) {
                                  if (val == null || val.isEmpty) {
                                    return 'Account is required';
                                  }
                                  final hasMatch = expIncAccounts.any((a) => a.name.toLowerCase() == val.trim().toLowerCase());
                                  if (!hasMatch) {
                                    return 'Select a valid account';
                                  }
                                  return null;
                                },
                                onChanged: (val) {
                                  final match = expIncAccounts.firstWhere(
                                    (a) => a.name.toLowerCase() == val.trim().toLowerCase(),
                                    orElse: () => Account(id: '', name: '', type: '', currency: 'USD', createdAt: DateTime.now(), updatedAt: DateTime.now()),
                                  );
                                  if (match.id.isNotEmpty) {
                                    setDialogState(() {
                                      _selectedAccountId = match.id;
                                      _selectedTxCurrency = match.currency;
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
                                        final Account option = options.elementAt(index);
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
                            onSelected: (Account selection) {
                              setDialogState(() {
                                _selectedAccountId = selection.id;
                                _selectedTxCurrency = selection.currency;
                              });
                            },
                          );
                        },
                      ),
                    ] else ...[
                      // Transfer Layout:
                      // Source Account (From)
                      LayoutBuilder(
                        key: ValueKey('transfer_from_$_selectedAccountId'),
                        builder: (context, constraints) {
                          final currentAccount = dialogAccounts.firstWhere(
                            (a) => a.id == _selectedAccountId,
                            orElse: () => Account(id: '', name: '', type: 'checking', currency: 'USD', createdAt: DateTime.now(), updatedAt: DateTime.now()),
                          );
                          return Autocomplete<Account>(
                            initialValue: TextEditingValue(text: currentAccount.id.isNotEmpty ? currentAccount.name : ''),
                            displayStringForOption: (Account option) => option.name,
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              final query = textEditingValue.text.trim();
                              if (query.isEmpty) {
                                return dialogAccounts;
                              }
                              return dialogAccounts.where((Account option) {
                                return option.name.toLowerCase().contains(query.toLowerCase());
                              });
                            },
                            fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                              return TextFormField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                decoration: const InputDecoration(
                                  labelText: 'From Account (Source)',
                                  hintText: 'Search or select source account...',
                                  suffixIcon: Icon(Icons.search),
                                ),
                                validator: (val) {
                                  if (val == null || val.isEmpty) {
                                    return 'Source account is required';
                                  }
                                  final hasMatch = dialogAccounts.any((a) => a.name.toLowerCase() == val.trim().toLowerCase());
                                  if (!hasMatch) {
                                    return 'Select a valid source account';
                                  }
                                  return null;
                                },
                                onChanged: (val) {
                                  final match = dialogAccounts.firstWhere(
                                    (a) => a.name.toLowerCase() == val.trim().toLowerCase(),
                                    orElse: () => Account(id: '', name: '', type: '', currency: 'USD', createdAt: DateTime.now(), updatedAt: DateTime.now()),
                                  );
                                  if (match.id.isNotEmpty) {
                                    setDialogState(() {
                                      _selectedAccountId = match.id;
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
                                        final Account option = options.elementAt(index);
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
                            onSelected: (Account selection) {
                              setDialogState(() {
                                _selectedAccountId = selection.id;
                              });
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Destination Account (To)
                      LayoutBuilder(
                        key: ValueKey('transfer_to_$_selectedTransferToAccountId'),
                        builder: (context, constraints) {
                          final currentAccount = dialogAccounts.firstWhere(
                            (a) => a.id == _selectedTransferToAccountId,
                            orElse: () => Account(id: '', name: '', type: 'checking', currency: 'USD', createdAt: DateTime.now(), updatedAt: DateTime.now()),
                          );
                          final toAccountOptions = dialogAccounts.where((a) => a.id != _selectedAccountId).toList();
                          return Autocomplete<Account>(
                            initialValue: TextEditingValue(text: currentAccount.id.isNotEmpty ? currentAccount.name : ''),
                            displayStringForOption: (Account option) => option.name,
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              final query = textEditingValue.text.trim();
                              if (query.isEmpty) {
                                return toAccountOptions;
                              }
                              return toAccountOptions.where((Account option) {
                                return option.name.toLowerCase().contains(query.toLowerCase());
                              });
                            },
                            fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                              return TextFormField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                decoration: const InputDecoration(
                                  labelText: 'To Account (Destination)',
                                  hintText: 'Search or select destination account...',
                                  suffixIcon: Icon(Icons.search),
                                ),
                                validator: (val) {
                                  if (val == null || val.isEmpty) {
                                    return 'Destination account is required';
                                  }
                                  final hasMatch = dialogAccounts.any((a) => a.name.toLowerCase() == val.trim().toLowerCase());
                                  if (!hasMatch) {
                                    return 'Select a valid destination account';
                                  }
                                  if (val.trim().toLowerCase() == dialogAccounts.firstWhere((a) => a.id == _selectedAccountId, orElse: () => Account(id: '', name: '___', type: '', currency: '', createdAt: DateTime.now(), updatedAt: DateTime.now())).name.toLowerCase()) {
                                    return 'Source and destination accounts must be different';
                                  }
                                  return null;
                                },
                                onChanged: (val) {
                                  final match = dialogAccounts.firstWhere(
                                    (a) => a.name.toLowerCase() == val.trim().toLowerCase(),
                                    orElse: () => Account(id: '', name: '', type: '', currency: 'USD', createdAt: DateTime.now(), updatedAt: DateTime.now()),
                                  );
                                  if (match.id.isNotEmpty) {
                                    setDialogState(() {
                                      _selectedTransferToAccountId = match.id;
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
                                        final Account option = options.elementAt(index);
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
                            onSelected: (Account selection) {
                              setDialogState(() {
                                _selectedTransferToAccountId = selection.id;
                              });
                            },
                          );
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
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryPurple,
                foregroundColor: Colors.black,
              ),
              child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                if (!_formKey.currentState!.validate()) {
                  return;
                }

                if (_selectedCategoryId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select a category.')),
                  );
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

                // Show edit confirmation dialog if editing
                if (editTx != null) {
                  if (!context.mounted) return;
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: AppTheme.darkCard,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('Confirm Edit'),
                      content: const Text('Are you sure you want to update this transaction? This will adjust your account balances accordingly.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryPurple, foregroundColor: Colors.black),
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Confirm'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true) return;
                }

                // Dismiss dialog first to prevent Flutter Web widget tree collision on rebuild
                if (context.mounted) {
                  Navigator.of(context).pop();
                }

                try {
                  if (_transactionType == 'transfer') {
                    if (_selectedAccountId == _selectedTransferToAccountId) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Source and destination accounts must be different.')),
                      );
                      return;
                    }

                    final sourceAccount = dialogAccounts.firstWhere((a) => a.id == _selectedAccountId);
                    final destAccount = dialogAccounts.firstWhere((a) => a.id == _selectedTransferToAccountId);

                    // Unified transfer link tag
                    final tTag = transferTag ?? 'transfer_${_uuid.v4()}';

                    // 1. Outflow transaction
                    final outflowTx = Transaction(
                      id: (editTx != null && transferTag != null)
                          ? (editTx.amount < 0 ? editTx.id : (pairedTx?.id ?? _uuid.v4().replaceAll('-', '').substring(0, 20)))
                          : _uuid.v4().replaceAll('-', '').substring(0, 20),
                      accountId: _selectedAccountId!,
                      categoryId: _selectedCategoryId!,
                      amount: -absAmount,
                      currency: sourceAccount.currency,
                      date: _selectedDate,
                      description: _descriptionController.text.trim().isEmpty ? 'Internal Transfer' : _descriptionController.text.trim(),
                      tags: [tTag],
                      createdAt: editTx?.createdAt ?? DateTime.now(),
                    );

                    String destCategoryId = _selectedCategoryId!;
                    if (destAccount.accountGroup == 'capital') {
                      final depositCat = dataService.categories.firstWhere(
                        (c) => c.type == 'income' && c.name.toLowerCase().contains('deposit'),
                        orElse: () => dataService.categories.firstWhere(
                          (c) => c.type == 'income',
                          orElse: () => Category(
                            id: 'deposit_default',
                            name: 'Deposit',
                            type: 'income',
                            createdAt: DateTime.now(),
                          ),
                        ),
                      );
                      destCategoryId = depositCat.id;
                    }

                    // 2. Inflow transaction (with currency conversion if different)
                    final inflowAmount = dataService.convert(absAmount, sourceAccount.currency, destAccount.currency);
                    final inflowTx = Transaction(
                      id: (editTx != null && transferTag != null)
                          ? (editTx.amount >= 0 ? editTx.id : (pairedTx?.id ?? _uuid.v4().replaceAll('-', '').substring(0, 20)))
                          : _uuid.v4().replaceAll('-', '').substring(0, 20),
                      accountId: _selectedTransferToAccountId!,
                      categoryId: destCategoryId,
                      amount: inflowAmount,
                      currency: destAccount.currency,
                      date: _selectedDate,
                      description: _descriptionController.text.trim().isEmpty ? 'Internal Transfer' : _descriptionController.text.trim(),
                      tags: [tTag],
                      createdAt: editTx?.createdAt ?? DateTime.now(),
                    );

                    if (editTx != null) {
                      final oldList = <Transaction>[];
                      oldList.add(editTx);
                      if (pairedTx != null) oldList.add(pairedTx);

                      await dataService.updateTransaction(
                        oldTxs: oldList,
                        newTxs: [outflowTx, inflowTx],
                      );
                    } else {
                      await dataService.addTransaction(outflowTx);
                      await dataService.addTransaction(inflowTx);
                    }
                  } else {
                    // Expense or Income
                    double finalAmount = absAmount;
                    if (_transactionType == 'expense') {
                      finalAmount = -absAmount;
                    }

                    final selectedAccount = dialogAccounts.firstWhere((a) => a.id == _selectedAccountId);
                    final String txCurrency = _selectedTxCurrency ?? selectedAccount.currency;
                    final double exRate = dataService.convert(1.0, txCurrency, selectedAccount.currency);

                    final newTx = Transaction(
                      id: editTx?.id ?? _uuid.v4().replaceAll('-', '').substring(0, 20),
                      accountId: _selectedAccountId!,
                      categoryId: _selectedCategoryId!,
                      amount: finalAmount,
                      currency: txCurrency,
                      exchangeRate: exRate,
                      date: _selectedDate,
                      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
                      createdAt: editTx?.createdAt ?? DateTime.now(),
                    );

                    if (editTx != null) {
                      final oldList = <Transaction>[];
                      oldList.add(editTx);
                      if (pairedTx != null) oldList.add(pairedTx);

                      await dataService.updateTransaction(
                        oldTxs: oldList,
                        newTxs: [newTx],
                      );
                    } else {
                      await dataService.addTransaction(newTx);
                    }
                  }

                  messenger.showSnackBar(
                    SnackBar(content: Text(editTx != null ? 'Transaction updated successfully.' : 'Transaction added successfully.')),
                  );
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
  }
}
