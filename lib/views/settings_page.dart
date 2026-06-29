import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../services/data_service.dart';
import '../models/recurring_transaction.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/asset.dart';
import '../core/theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _uuid = const Uuid();
  
  // Search state (for currencies)
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Form State (for recurring transactions)
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _amountController = TextEditingController();
  final _intervalController = TextEditingController(text: '1');
  
  String? _selectedAccountId;
  String? _selectedCategoryId;
  String _selectedFrequency = 'monthly';
  DateTime _startDate = DateTime.now();
  DateTime _nextDueDate = DateTime.now();
  DateTime? _endDate;

  // Form State (for Assets)
  final _assetFormKey = GlobalKey<FormState>();
  final _assetSymbolController = TextEditingController();
  final _assetNameController = TextEditingController();
  String _selectedAssetType = 'stock';

  static const Map<String, String> _worldCurrencies = {
    'MXN': 'Mexican Peso',
    'USD': 'US Dollar',
    'SOL': 'Solana (Crypto)',
    'EUR': 'Euro',
    'GBP': 'British Pound',
    'JPY': 'Japanese Yen',
    'CAD': 'Canadian Dollar',
    'AUD': 'Australian Dollar',
    'CHF': 'Swiss Franc',
    'CNY': 'Chinese Yuan',
    'PEN': 'Peruvian Sol',
    'BRL': 'Brazilian Real',
    'ARS': 'Argentine Peso',
    'COP': 'Colombian Peso',
    'CLP': 'Chilean Peso',
    'INR': 'Indian Rupee',
    'SGD': 'Singapore Dollar',
    'HKD': 'Hong Kong Dollar',
    'NZD': 'New Zealand Dollar',
    'SEK': 'Swedish Krona',
    'NOK': 'Norwegian Krone',
    'RUB': 'Russian Ruble',
    'ZAR': 'South African Rand',
    'KRW': 'South Korean Won',
    'TRY': 'Turkish Lira',
  };

  @override
  void dispose() {
    _searchController.dispose();
    _descController.dispose();
    _amountController.dispose();
    _intervalController.dispose();
    _assetSymbolController.dispose();
    _assetNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ds = Provider.of<DataService>(context);
    
    // Initialize default dropdown selections if they are null or not present in active lists
    final activeAccounts = ds.accounts.where((a) => a.status == 'active').toList();
    if (activeAccounts.isNotEmpty) {
      if (_selectedAccountId == null || !activeAccounts.any((a) => a.id == _selectedAccountId)) {
        _selectedAccountId = activeAccounts.first.id;
      }
    } else {
      _selectedAccountId = null;
    }

    if (ds.categories.isNotEmpty) {
      if (_selectedCategoryId == null || !ds.categories.any((c) => c.id == _selectedCategoryId)) {
        _selectedCategoryId = ds.categories.first.id;
      }
    } else {
      _selectedCategoryId = null;
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('App Settings & Configurations'),
          backgroundColor: AppTheme.darkCard,
          elevation: 0,
          bottom: const TabBar(
            indicatorColor: AppTheme.mainAction,
            labelColor: AppTheme.mainAction,
            unselectedLabelColor: AppTheme.textSecondary,
            tabs: [
              Tab(icon: Icon(Icons.currency_exchange), text: 'Currencies'),
              Tab(icon: Icon(Icons.autorenew), text: 'Recurring Transactions'),
              Tab(icon: Icon(Icons.wallet), text: 'Assets'),
            ],
          ),
        ),
        body: SelectionArea(
          child: Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.backgroundGradient,
            ),
            child: TabBarView(
              children: [
                _buildCurrenciesTab(context, ds),
                _buildRecurringTxTab(context, ds),
                _buildAssetsTab(context, ds),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrenciesTab(BuildContext context, DataService ds) {
    final enabled = ds.enabledCurrencies;
    final searchResults = _worldCurrencies.entries.where((entry) {
      final code = entry.key.toLowerCase();
      final name = entry.value.toLowerCase();
      final q = _searchQuery.toLowerCase();
      return (code.contains(q) || name.contains(q)) && !enabled.contains(entry.key);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Currency Management',
            style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 24),
          ),
          const SizedBox(height: 8),
          Text(
            'Configure which currencies are available throughout the app for ledger transactions, account creations, and display switchers.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Text(
            'Enabled Currencies',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentCyan,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            children: enabled.map((currency) {
              final isDisplay = currency == ds.displayCurrency;
              return Chip(
                backgroundColor: isDisplay ? AppTheme.mainAction.withOpacity(0.2) : AppTheme.darkCard,
                side: BorderSide(
                  color: isDisplay ? AppTheme.mainAction : const Color(0xFF23232A),
                ),
                label: Text(
                  '$currency - ${_worldCurrencies[currency] ?? ""}',
                  style: TextStyle(
                    color: isDisplay ? AppTheme.mainAction : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                deleteIcon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                onDeleted: enabled.length > 1 && !isDisplay
                    ? () async {
                        final newEnabled = List<String>.from(enabled)..remove(currency);
                        await ds.updateEnabledCurrencies(newEnabled);
                        ds.syncExchangeRates(); // Sync exchange rates for new configuration
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$currency removed from enabled currencies.')),
                          );
                        }
                      }
                    : null,
              );
            }).toList(),
          ),
          if (enabled.length <= 1) ...[
            const SizedBox(height: 8),
            const Text(
              'At least one currency must be enabled. Cannot delete the active display currency.',
              style: TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],
          const SizedBox(height: 32),
          Text(
            'Search & Add Currencies',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentCyan,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Search Currencies',
              hintText: 'Type MXN, EUR, Euro, etc...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: searchResults.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.isEmpty ? 'Type in search to find more currencies' : 'No matching currencies found',
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  )
                : ListView.builder(
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final entry = searchResults[index];
                      return Card(
                        color: AppTheme.darkCard,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Color(0xFF23232A)),
                        ),
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            entry.key,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          subtitle: Text(
                            entry.value,
                            style: const TextStyle(color: AppTheme.textSecondary),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.add_circle_outline, color: AppTheme.accentCyan),
                            onPressed: () async {
                              final newEnabled = List<String>.from(enabled)..add(entry.key);
                              await ds.updateEnabledCurrencies(newEnabled);
                              ds.syncExchangeRates(); // Fetch rates for newly added currency
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('${entry.key} added to enabled currencies.')),
                                );
                              }
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecurringTxTab(BuildContext context, DataService ds) {
    final activeAccounts = ds.accounts.where((a) => a.status == 'active').toList();
    final categories = ds.categories;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          
          final formWidget = Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add New Recurring Transaction',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accentCyan,
                          ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Description
                    TextFormField(
                      controller: _descController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        prefixIcon: Icon(Icons.description_outlined),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Enter a description' : null,
                    ),
                    const SizedBox(height: 16),
                    
                    // Amount & Interval in Row
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                            decoration: const InputDecoration(
                              labelText: 'Amount',
                              hintText: 'e.g. -500 or 1500',
                              prefixIcon: Icon(Icons.attach_money),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Enter amount';
                              if (double.tryParse(val) == null) return 'Enter a number';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _intervalController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Period Interval',
                              hintText: 'e.g. 1',
                              prefixIcon: Icon(Icons.repeat),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) return 'Enter interval';
                              if (int.tryParse(val) == null) return 'Enter an integer';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Account & Category selectors
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedAccountId,
                            decoration: const InputDecoration(labelText: 'Account'),
                            dropdownColor: AppTheme.darkCard,
                            items: activeAccounts.map((a) => DropdownMenuItem(
                              value: a.id,
                              child: Text(a.name),
                            )).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedAccountId = val;
                              });
                            },
                            validator: (val) => val == null ? 'Select an account' : null,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedCategoryId,
                            decoration: const InputDecoration(labelText: 'Category'),
                            dropdownColor: AppTheme.darkCard,
                            items: categories.map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            )).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedCategoryId = val;
                              });
                            },
                            validator: (val) => val == null ? 'Select a category' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Frequency & Start Date
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedFrequency,
                            decoration: const InputDecoration(labelText: 'Frequency'),
                            dropdownColor: AppTheme.darkCard,
                            items: const [
                              DropdownMenuItem(value: 'daily', child: Text('Daily')),
                              DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                              DropdownMenuItem(value: 'biweekly', child: Text('Biweekly')),
                              DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                              DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedFrequency = val;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: const BorderSide(color: Color(0xFF23232A)),
                            ),
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text('Starts: ${DateFormat('yyyy-MM-dd').format(_startDate)}'),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _startDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 3650)),
                              );
                              if (picked != null) {
                                setState(() {
                                  _startDate = picked;
                                  _nextDueDate = picked;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Next Due Date & End Date
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: const BorderSide(color: Color(0xFF23232A)),
                            ),
                            icon: const Icon(Icons.next_plan_outlined, size: 16),
                            label: Text('Next Due: ${DateFormat('yyyy-MM-dd').format(_nextDueDate)}'),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _nextDueDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 3650)),
                              );
                              if (picked != null) {
                                setState(() {
                                  _nextDueDate = picked;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: const BorderSide(color: Color(0xFF23232A)),
                            ),
                            icon: const Icon(Icons.event_busy_outlined, size: 16),
                            label: Text(_endDate == null ? 'No End Date' : 'End: ${DateFormat('yyyy-MM-dd').format(_endDate!)}'),
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _endDate ?? DateTime.now(),
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 3650)),
                              );
                              setState(() {
                                _endDate = picked;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.mainAction,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Recurring Template', style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          if (_formKey.currentState!.validate()) {
                            final template = RecurringTransaction(
                              id: 'rt_${_uuid.v4().substring(0, 15)}',
                              accountId: _selectedAccountId!,
                              categoryId: _selectedCategoryId!,
                              amount: double.parse(_amountController.text),
                              frequency: _selectedFrequency,
                              interval: int.parse(_intervalController.text),
                              startDate: _startDate,
                              endDate: _endDate,
                              nextDueDate: _nextDueDate,
                              status: 'active',
                              description: _descController.text.trim(),
                            );
                            await ds.saveRecurringTransaction(template);
                            _descController.clear();
                            _amountController.clear();
                            _intervalController.text = '1';
                            setState(() {
                              _endDate = null;
                              _startDate = DateTime.now();
                              _nextDueDate = DateTime.now();
                            });
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Recurring template created successfully.')),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          
          final listWidget = Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configured Recurring Templates',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentCyan,
                        ),
                  ),
                  const SizedBox(height: 16),
                  if (ds.recurringTransactions.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40.0),
                        child: Text('No recurring templates configured yet.'),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: ds.recurringTransactions.length,
                      separatorBuilder: (context, index) => const Divider(color: Color(0xFF23232A)),
                      itemBuilder: (context, index) {
                        final rt = ds.recurringTransactions[index];
                        final acc = ds.accounts.firstWhere((a) => a.id == rt.accountId, orElse: () => Account(id: '', name: 'Deleted Account', type: 'checking', currency: 'USD', createdAt: DateTime.now(), updatedAt: DateTime.now()));
                        final catName = ds.categories.firstWhere((c) => c.id == rt.categoryId, orElse: () => Category(id: '', name: 'Uncategorized', type: 'expense', createdAt: DateTime.now())).name;
                        
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(rt.description, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            '$catName • ${acc.name}\n${rt.frequency.toUpperCase()} (Every ${rt.interval} period)\nNext Due: ${DateFormat('yyyy-MM-dd').format(rt.nextDueDate)}',
                            style: const TextStyle(height: 1.4, fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                ds.formatCurrency(rt.amount),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: rt.amount < 0 ? AppTheme.dangerRed : AppTheme.successGreen,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                onPressed: () async {
                                  await ds.deleteRecurringTransaction(rt.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Recurring template deleted.')),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          );
          
          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: formWidget),
                const SizedBox(width: 24),
                Expanded(flex: 5, child: listWidget),
              ],
            );
          }
          
          return Column(
            children: [
              formWidget,
              const SizedBox(height: 24),
              listWidget,
            ],
          );
        },
      ),
    );
  }

  // CUSTOMIZATION PREFERENCE: Pair the Assets configuration directly with the assets database table, supporting full CRUD operations.
  Widget _buildAssetsTab(BuildContext context, DataService ds) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          final formWidget = Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _assetFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add New Asset',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accentCyan,
                          ),
                    ),
                    const SizedBox(height: 16),

                    // Symbol
                    TextFormField(
                      controller: _assetSymbolController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Asset Symbol',
                        hintText: 'e.g. AAPL, BTC, MSFT',
                        prefixIcon: Icon(Icons.token_outlined),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Enter an asset symbol';
                        }
                        final trimmed = val.trim().toUpperCase();
                        if (ds.assets.any((a) => a.symbol == trimmed)) {
                          return 'Asset symbol already exists';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Name
                    TextFormField(
                      controller: _assetNameController,
                      decoration: const InputDecoration(
                        labelText: 'Asset Name',
                        hintText: 'e.g. Apple Inc., Bitcoin',
                        prefixIcon: Icon(Icons.info_outline),
                      ),
                      validator: (val) =>
                          val == null || val.trim().isEmpty ? 'Enter a name' : null,
                    ),
                    const SizedBox(height: 16),

                    // Type Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedAssetType,
                      decoration: const InputDecoration(
                        labelText: 'Asset Type',
                        prefixIcon: Icon(Icons.category_outlined),
                      ),
                      dropdownColor: AppTheme.darkCard,
                      items: const [
                        DropdownMenuItem(value: 'stock', child: Text('Stock')),
                        DropdownMenuItem(value: 'crypto', child: Text('Crypto')),
                        DropdownMenuItem(value: 'etf', child: Text('ETF')),
                        DropdownMenuItem(value: 'cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedAssetType = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.mainAction,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Asset',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        onPressed: () async {
                          if (_assetFormKey.currentState!.validate()) {
                            final newAsset = Asset(
                              id: const Uuid()
                                  .v4()
                                  .replaceAll('-', '')
                                  .substring(0, 20),
                              symbol: _assetSymbolController.text.trim().toUpperCase(),
                              name: _assetNameController.text.trim(),
                              type: _selectedAssetType,
                            );

                            await ds.saveAsset(newAsset);
                            _assetSymbolController.clear();
                            _assetNameController.clear();
                            setState(() {
                              _selectedAssetType = 'stock';
                            });

                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'Asset ${newAsset.symbol} created successfully.')),
                              );
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          final listWidget = Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configured Assets',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentCyan,
                        ),
                  ),
                  const SizedBox(height: 16),
                  if (ds.assets.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40.0),
                        child: Text('No assets configured yet.'),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: ds.assets.length,
                      separatorBuilder: (context, index) =>
                          const Divider(color: Color(0xFF23232A)),
                      itemBuilder: (context, index) {
                        final asset = ds.assets[index];
                        // CUSTOMIZATION PREFERENCE: Delete is only enabled if no active holdings have this asset (meaning quantity <= 0)
                        final canDelete = !ds.holdings
                            .any((h) => h.assetId == asset.id && h.quantity > 0);

                        Widget deleteIconButton = IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: canDelete
                                ? Colors.redAccent
                                : Colors.grey.withOpacity(0.4),
                          ),
                          onPressed: canDelete
                              ? () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: AppTheme.darkCard,
                                      title: const Text('Delete Asset'),
                                      content: Text(
                                          'Are you sure you want to delete ${asset.symbol}? This will permanently remove this asset metadata.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancel',
                                              style: TextStyle(
                                                  color: AppTheme.textSecondary)),
                                        ),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.dangerRed,
                                            foregroundColor: Colors.white,
                                          ),
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Delete',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    await ds.deleteAsset(asset.id);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                'Asset ${asset.symbol} deleted.')),
                                      );
                                    }
                                  }
                                }
                              : null,
                        );

                        if (!canDelete) {
                          deleteIconButton = Tooltip(
                            message:
                                'Cannot delete: Asset has active holdings in one or more accounts.',
                            child: deleteIconButton,
                          );
                        }

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(asset.symbol,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            '${asset.name} • ${asset.type.toUpperCase()}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined,
                                    color: AppTheme.accentCyan),
                                onPressed: () =>
                                    _showEditAssetDialog(context, ds, asset),
                              ),
                              const SizedBox(width: 4),
                              deleteIconButton,
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          );

          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: formWidget),
                const SizedBox(width: 24),
                Expanded(flex: 5, child: listWidget),
              ],
            );
          }

          return Column(
            children: [
              formWidget,
              const SizedBox(height: 24),
              listWidget,
            ],
          );
        },
      ),
    );
  }

  Future<void> _showEditAssetDialog(
      BuildContext context, DataService ds, Asset asset) async {
    final editSymbolController = TextEditingController(text: asset.symbol);
    final editNameController = TextEditingController(text: asset.name);
    String editType = asset.type;
    final editFormKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.darkCard,
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: const [
                  Icon(Icons.edit_outlined, color: AppTheme.accentCyan),
                  SizedBox(width: 8),
                  Text('Edit Asset'),
                ],
              ),
              content: Form(
                key: editFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: editSymbolController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(labelText: 'Symbol'),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Enter a symbol';
                        }
                        final trimmed = val.trim().toUpperCase();
                        if (trimmed != asset.symbol &&
                            ds.assets.any((a) => a.symbol == trimmed)) {
                          return 'Asset symbol already exists';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: editNameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Enter a name'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: editType,
                      decoration: const InputDecoration(labelText: 'Type'),
                      dropdownColor: AppTheme.darkCard,
                      items: const [
                        DropdownMenuItem(value: 'stock', child: Text('Stock')),
                        DropdownMenuItem(value: 'crypto', child: Text('Crypto')),
                        DropdownMenuItem(value: 'etf', child: Text('ETF')),
                        DropdownMenuItem(value: 'cash', child: Text('Cash')),
                        DropdownMenuItem(value: 'other', child: Text('Other')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            editType = val;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel',
                      style: TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentCyan,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () async {
                    if (editFormKey.currentState!.validate()) {
                      final updatedAsset = Asset(
                        id: asset.id,
                        symbol: editSymbolController.text.trim().toUpperCase(),
                        name: editNameController.text.trim(),
                        type: editType,
                      );
                      await ds.saveAsset(updatedAsset);
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Asset updated successfully.')),
                        );
                      }
                    }
                  },
                  child: const Text('Save',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
