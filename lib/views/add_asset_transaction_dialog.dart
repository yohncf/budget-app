import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../services/data_service.dart';
import '../models/asset_transaction.dart';
import '../models/transaction.dart';
import '../models/account.dart';
import '../models/asset.dart';
import '../core/theme.dart';

// CUSTOMIZATION PREFERENCE: Standalone reusable dialog widget for logging asset transactions.
class AddAssetTransactionDialog extends StatefulWidget {
  final DataService dataService;

  const AddAssetTransactionDialog({
    super.key,
    required this.dataService,
  });

  @override
  State<AddAssetTransactionDialog> createState() => _AddAssetTransactionDialogState();
}

class _AddAssetTransactionDialogState extends State<AddAssetTransactionDialog> {
  final _uuid = const Uuid();
  final _symbolController = TextEditingController();
  final _nameController = TextEditingController();
  final _qtyController = TextEditingController();
  final _priceController = TextEditingController();
  
  Account? _selectedAccount;
  Asset? _selectedAsset;
  String _selectedAssetType = 'stock';
  String _selectedTxType = 'buy';
  DateTime _selectedDate = DateTime.now();
  Transaction? _selectedLinkedTx;

  @override
  void initState() {
    super.initState();
    final service = widget.dataService;
    // CUSTOMIZATION PREFERENCE: Only accounts of 'account_group' "capital" are shown
    final capitalAccounts = service.accounts.where((a) => a.status == 'active' && a.accountGroup == 'capital').toList();
    _selectedAccount = capitalAccounts.isNotEmpty ? capitalAccounts.first : null;

    // CUSTOMIZATION PREFERENCE: Initialize asset selection based on the "assets" table
    _selectedAsset = service.assets.isNotEmpty ? service.assets.first : null;
    if (_selectedAsset != null) {
      _symbolController.text = _selectedAsset!.symbol;
      _nameController.text = _selectedAsset!.name;
      _selectedAssetType = _selectedAsset!.type;
    } else {
      _symbolController.clear();
      _nameController.clear();
      _selectedAssetType = 'stock';
    }
  }

  @override
  void dispose() {
    _symbolController.dispose();
    _nameController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.dataService;
    
    // Filter and sort active cash ledger transactions belonging to the selected account.
    // CRITICAL: We filter by transaction type to prevent user errors (e.g. linking a buy trade
    // to a cash inflow sale transaction, which would bypass the cash deduction logic).
    // - Buy or Dividend Reinvest trades (cash outflows) can only link to negative transactions (amount < 0).
    // - Sell trades (cash inflows) can only link to positive transactions (amount > 0).
    final linkedTxsList = service.transactions
        .where((t) => t.status != 'deleted' && t.accountId == _selectedAccount?.id)
        .where((t) {
          if (_selectedTxType == 'buy' || _selectedTxType == 'dividend_reinvest') {
            return t.amount < 0;
          } else if (_selectedTxType == 'sell') {
            return t.amount > 0;
          }
          return true;
        })
        .toList();
    linkedTxsList.sort((a, b) => b.date.compareTo(a.date));
    final recentTxs = linkedTxsList.take(20).toList();
    
    // Ensure currently selected linked transaction remains in the dropdown items list
    if (_selectedLinkedTx != null && !recentTxs.any((t) => t.id == _selectedLinkedTx!.id)) {
      recentTxs.add(_selectedLinkedTx!);
    }

    return AlertDialog(
      backgroundColor: AppTheme.darkCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: const [
          Icon(Icons.add_chart, color: AppTheme.accentCyan),
          SizedBox(width: 8),
          Text('Log Asset Transaction'),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Account Selector
              // CUSTOMIZATION PREFERENCE: Filter the list of destination accounts to strictly show capital accounts.
              DropdownButtonFormField<Account>(
                value: (service.accounts.any((a) => a.id == _selectedAccount?.id && a.status == 'active' && a.accountGroup == 'capital')) ? _selectedAccount : null,
                decoration: const InputDecoration(labelText: 'Destination Account'),
                items: service.accounts.where((a) => a.status == 'active' && a.accountGroup == 'capital').map((a) {
                  return DropdownMenuItem<Account>(
                    value: a,
                    child: Text('${a.name} (${a.currency})'),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedAccount = val;
                    // Reset the selected cash transaction link if the account changes
                    _selectedLinkedTx = null;
                  });
                },
              ),
              const SizedBox(height: 12),

              // Optional cash transaction linkage dropdown (representing transaction_id column)
              DropdownButtonFormField<Transaction?>(
                value: _selectedLinkedTx,
                decoration: const InputDecoration(
                  labelText: 'Linked Cash Transaction (Optional)',
                  helperText: 'Associate this asset transaction with a ledger record',
                ),
                items: [
                  const DropdownMenuItem<Transaction?>(
                    value: null,
                    child: Text('None / No Link', style: TextStyle(color: AppTheme.textSecondary)),
                  ),
                  ...recentTxs.map((t) {
                    final dateStr = DateFormat('yyyy-MM-dd').format(t.date);
                    final amtStr = service.formatCurrencyWith(t.amount, t.currency);
                    final descriptionText = t.description ?? '';
                    final desc = descriptionText.length > 25
                        ? '${descriptionText.substring(0, 22)}...'
                        : descriptionText;
                    return DropdownMenuItem<Transaction?>(
                      value: t,
                      child: Text(
                        '[$dateStr] $desc ($amtStr)',
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                  }),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedLinkedTx = val;
                  });
                },
              ),
              const SizedBox(height: 12),

              // Asset details
              Row(
                children: [
                  Expanded(
                    // CUSTOMIZATION PREFERENCE: Symbol is a drop-down selector of Assets from the database.
                    child: DropdownButtonFormField<Asset>(
                      value: service.assets.contains(_selectedAsset) ? _selectedAsset : null,
                      decoration: const InputDecoration(labelText: 'Symbol'),
                      items: service.assets.map((asset) {
                        return DropdownMenuItem<Asset>(
                          value: asset,
                          child: Text(asset.symbol),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedAsset = val;
                            // CUSTOMIZATION PREFERENCE: Preload Name and Type based on selected symbol
                            _symbolController.text = val.symbol;
                            _nameController.text = val.name;
                            _selectedAssetType = val.type;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    // CUSTOMIZATION PREFERENCE: Asset Type is displayed as styled text instead of a form field.
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Asset Type',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _selectedAssetType.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 15,
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // CUSTOMIZATION PREFERENCE: Asset Name is displayed as styled text instead of a form field.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Asset Name',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _nameController.text.isNotEmpty ? _nameController.text : 'N/A',
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Tx Type Dropdown
              DropdownButtonFormField<String>(
                value: _selectedTxType,
                decoration: const InputDecoration(labelText: 'Transaction Type'),
                items: const [
                  DropdownMenuItem(value: 'buy', child: Text('Buy (Increase)')),
                  DropdownMenuItem(value: 'sell', child: Text('Sell (Decrease)')),
                  DropdownMenuItem(value: 'split', child: Text('Split (Multiply quantity)')),
                  DropdownMenuItem(value: 'dividend_reinvest', child: Text('Dividend Reinvest')),
                  DropdownMenuItem(value: 'reward', child: Text('Reward')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedTxType = val;
                      // CRITICAL: Reset selected linked transaction on type change to prevent cross-type linkage errors.
                      _selectedLinkedTx = null; 
                    });
                  }
                },
              ),
              const SizedBox(height: 12),

              // Qty and Price
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _qtyController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Quantity', hintText: 'e.g. 5.25'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: _selectedTxType == 'split' ? 'Split Ratio' : 'Unit Price',
                        hintText: _selectedTxType == 'split' ? 'e.g. 2.0 (for 2-for-1)' : 'e.g. 150.25',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Date picker row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Executed: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    child: const Text('Change Date', style: TextStyle(color: AppTheme.accentCyan)),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedDate = picked;
                        });
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
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accentCyan,
            foregroundColor: Colors.black,
          ),
          onPressed: () async {
            if (_selectedAccount == null ||
                _symbolController.text.trim().isEmpty ||
                _qtyController.text.trim().isEmpty ||
                _priceController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Please fill out all required fields.')),
              );
              return;
            }

            final symbol = _symbolController.text.trim().toUpperCase();
            final name = _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : symbol;
            final qty = double.tryParse(_qtyController.text) ?? 0.0;
            final price = double.tryParse(_priceController.text) ?? 0.0;

            if (qty <= 0 || price <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Quantity and unit price must be positive numbers.')),
              );
              return;
            }

            // CRITICAL: Prevent purchases (Buy / Dividend Reinvest) if there is insufficient cash in the account.
            if (_selectedTxType == 'buy' || _selectedTxType == 'dividend_reinvest') {
              final cost = qty * price;
              final availableBalance = _selectedAccount!.currentBalance;
              if (_selectedLinkedTx == null && availableBalance < cost) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Insufficient cash in account (${_selectedAccount!.currency} ${availableBalance.toStringAsFixed(2)}) to purchase this asset (Cost: ${cost.toStringAsFixed(2)}).',
                    ),
                  ),
                );
                return;
              }
            }

            final assetTxId = _uuid.v4().replaceAll('-', '').substring(0, 20);
            // CUSTOMIZATION PREFERENCE: Must bind the database ID of the selected asset (_selectedAsset.id)
            // instead of the raw ticker symbol text, to maintain database referential integrity and support accurate
            // holding calculations. Fallback to raw symbol only if no asset match is selected (which shouldn't happen).
            final newAssetTx = AssetTransaction(
              id: assetTxId,
              transactionId: _selectedLinkedTx?.id,
              accountId: _selectedAccount!.id,
              assetId: _selectedAsset?.id ?? symbol,
              type: _selectedTxType,
              quantity: qty,
              unitPrice: price,
              executedAt: _selectedDate,
              assetSymbol: symbol,
              assetName: name,
            );

            try {
              await service.addAssetTransaction(newAssetTx, assetType: _selectedAssetType);
              if (context.mounted) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Asset transaction logged for $symbol!')),
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error logging transaction: $e')),
                );
              }
            }
          },
          child: const Text('Submit', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
