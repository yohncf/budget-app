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
  
  // Filter values
  String _filterType = 'All'; // All, Expense, Income, Transfer
  String _filterCategoryId = 'All'; // All, or specific category ID
  
  // Search values
  final _searchController = TextEditingController();
  String _searchQuery = '';
  
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
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<DataService>(context);
    final dateFormatter = DateFormat('yyyy-MM-dd HH:mm');
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12.0 : 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Responsive Header
              isMobile
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Transaction Ledger',
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 26),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Detailed historical cash movement records',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryPurple,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Add Transaction'),
                            onPressed: () => _showAddTransactionDialog(context, dataService),
                          ),
                        ),
                      ],
                    )
                  : Row(
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
                            foregroundColor: Colors.black,
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
              
              // Responsive Filters
              Wrap(
                spacing: 16,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Search Box
                  Container(
                    width: 240,
                    height: 40,
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        hintText: 'Search description or amount...',
                        hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textSecondary),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16, color: AppTheme.textSecondary),
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim();
                        });
                      },
                    ),
                  ),

                  // Showing since Date Filter
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Showing since: ',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.accentCyan,
                          side: const BorderSide(color: AppTheme.accentCyan),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.calendar_today, size: 12),
                        label: Text(
                          DateFormat('yyyy-MM-dd').format(dataService.transactionFilterDate),
                          style: const TextStyle(fontSize: 12),
                        ),
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

                  // Transaction Type Filter (SegmentedButton)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Type: ',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment<String>(
                            value: 'All',
                            label: Text('All'),
                          ),
                          ButtonSegment<String>(
                            value: 'Expense',
                            label: Text('Expenses'),
                          ),
                          ButtonSegment<String>(
                            value: 'Income',
                            label: Text('Income'),
                          ),
                          ButtonSegment<String>(
                            value: 'Transfer',
                            label: Text('Transfers'),
                          ),
                        ],
                        selected: {_filterType},
                        showSelectedIcon: false,
                        onSelectionChanged: (newSelection) {
                          if (newSelection.isNotEmpty) {
                            final newType = newSelection.first;
                            setState(() {
                              _filterType = newType;
                              // Reset category filter if it doesn't match the new type
                              if (_filterCategoryId != 'All') {
                                final hasCat = dataService.categories.any((c) {
                                  if (c.id != _filterCategoryId) return false;
                                  if (newType == 'All') return true;
                                  if (newType == 'Expense') return c.type == 'expense' || c.type == 'investment';
                                  if (newType == 'Income') return c.type == 'income' || c.type == 'reimbursement';
                                  if (newType == 'Transfer') return c.type == 'transfer';
                                  return true;
                                });
                                if (!hasCat) {
                                  _filterCategoryId = 'All';
                                }
                              }
                            });
                          }
                        },
                        style: SegmentedButton.styleFrom(
                          backgroundColor: const Color(0xFF1D1D22),
                          selectedBackgroundColor: AppTheme.primaryPurple,
                          selectedForegroundColor: Colors.black,
                          foregroundColor: AppTheme.textSecondary,
                          side: const BorderSide(color: Color(0xFF23232A)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
                  ),

                  // Category Dropdown Filter
                  Builder(
                    builder: (context) {
                      final categoriesList = dataService.categories.where((c) {
                        if (_filterType == 'All') return true;
                        if (_filterType == 'Expense') return c.type == 'expense' || c.type == 'investment';
                        if (_filterType == 'Income') return c.type == 'income' || c.type == 'reimbursement';
                        if (_filterType == 'Transfer') return c.type == 'transfer';
                        return true;
                      }).toList();
                      categoriesList.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Category: ',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1D1D22),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF23232A)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _filterCategoryId,
                                dropdownColor: AppTheme.darkCard,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                icon: const Icon(Icons.arrow_drop_down, color: AppTheme.textSecondary, size: 18),
                                items: [
                                  const DropdownMenuItem(value: 'All', child: Text('All Categories')),
                                  ...categoriesList.map((c) => DropdownMenuItem(
                                        value: c.id,
                                        child: Text(c.name),
                                      )),
                                ],
                                onChanged: (newCatId) {
                                  if (newCatId != null) {
                                    setState(() {
                                      _filterCategoryId = newCatId;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  // Show Deleted Switch
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Show Deleted',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(width: 4),
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
              const SizedBox(height: 16),

              // Ledger Table/List
              Expanded(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 12.0 : 20.0),
                    child: Builder(
                      builder: (context) {
                        final displayTransactions = dataService.transactions.where((tx) {
                          if (tx.status == 'deleted' && !_showDeleted) {
                            return false;
                          }
                          
                          final cat = dataService.categories.firstWhere(
                            (c) => c.id == tx.categoryId,
                            orElse: () => Category(id: '', name: 'Unknown', type: 'expense', createdAt: DateTime.now()),
                          );

                          if (_filterType != 'All') {
                            if (_filterType == 'Expense' && cat.type != 'expense' && cat.type != 'investment') {
                              return false;
                            }
                            if (_filterType == 'Income' && cat.type != 'income' && cat.type != 'reimbursement') {
                              return false;
                            }
                            if (_filterType == 'Transfer' && cat.type != 'transfer') {
                              return false;
                            }
                          }

                          if (_filterCategoryId != 'All' && tx.categoryId != _filterCategoryId) {
                            return false;
                          }
                          
                          if (_searchQuery.isNotEmpty) {
                            final desc = tx.description?.toLowerCase() ?? '';
                            final amountStr = tx.amount.abs().toString();
                            final queryLower = _searchQuery.toLowerCase();
                            
                            final matchesDesc = desc.contains(queryLower);
                            final matchesAmount = amountStr.contains(queryLower);
                            
                            if (!matchesDesc && !matchesAmount) {
                              return false;
                            }
                          }
                          
                          return true;
                        }).toList();

                        if (displayTransactions.isEmpty) {
                          return const Center(
                            child: Text('No transactions registered. Add some to get started.'),
                          );
                        }

                        return SelectionContainer.disabled(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (!isMobile) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                                  child: Row(
                                    children: const [
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          'DESCRIPTION / CATEGORY / ACCOUNT',
                                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'DATE',
                                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'AMOUNT',
                                          textAlign: TextAlign.right,
                                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 60,
                                        child: Text(
                                          'ACTIONS',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(color: Color(0xFF2E2E4A)),
                              ],
                              Expanded(
                                child: ListView.separated(
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

                                    if (isMobile) {
                                      // Mobile stacked view item layout
                                      final itemWidget = SelectionArea(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                                          child: Row(
                                            children: [
                                              // Visual leading category type indicator
                                              Container(
                                                width: 36,
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  color: isDeleted
                                                      ? const Color(0xFF1D1D2C)
                                                      : category.type == 'expense'
                                                          ? AppTheme.dangerRed.withOpacity(0.12)
                                                          : category.type == 'transfer'
                                                              ? AppTheme.accentCyan.withOpacity(0.12)
                                                              : AppTheme.successGreen.withOpacity(0.12),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: isDeleted
                                                        ? Colors.transparent
                                                        : category.type == 'expense'
                                                            ? AppTheme.dangerRed.withOpacity(0.3)
                                                            : category.type == 'transfer'
                                                                ? AppTheme.accentCyan.withOpacity(0.3)
                                                                : AppTheme.successGreen.withOpacity(0.3),
                                                    width: 1.0,
                                                  ),
                                                ),
                                                child: Icon(
                                                  category.type == 'expense'
                                                      ? Icons.arrow_downward_rounded
                                                      : category.type == 'transfer'
                                                          ? Icons.swap_horiz_rounded
                                                          : Icons.arrow_upward_rounded,
                                                  color: isDeleted
                                                      ? AppTheme.textSecondary.withOpacity(0.5)
                                                      : category.type == 'expense'
                                                          ? AppTheme.dangerRed
                                                          : category.type == 'transfer'
                                                              ? AppTheme.accentCyan
                                                              : AppTheme.successGreen,
                                                  size: 16,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              
                                              // Sub-details stacked in center
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      crossAxisAlignment: CrossAxisAlignment.center,
                                                      children: [
                                                        Flexible(
                                                          child: Text(
                                                            tx.description ?? 'No description',
                                                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                                                  fontWeight: FontWeight.bold,
                                                                  fontSize: 14,
                                                                  color: isDeleted ? AppTheme.textSecondary.withOpacity(0.5) : null,
                                                                  decoration: isDeleted ? TextDecoration.lineThrough : null,
                                                                ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Text(
                                                          DateFormat('MM-dd').format(tx.date),
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            color: isDeleted ? AppTheme.textSecondary.withOpacity(0.4) : AppTheme.textSecondary,
                                                            decoration: isDeleted ? TextDecoration.lineThrough : null,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Row(
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: isDeleted ? const Color(0xFF1D1D2C) : const Color(0xFF21213E),
                                                            borderRadius: BorderRadius.circular(4),
                                                          ),
                                                          child: Text(
                                                            category.name,
                                                            style: TextStyle(
                                                              fontSize: 9,
                                                              color: isDeleted ? AppTheme.textSecondary.withOpacity(0.5) : AppTheme.textSecondary,
                                                              decoration: isDeleted ? TextDecoration.lineThrough : null,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Text(
                                                          '•',
                                                          style: TextStyle(
                                                            fontSize: 9,
                                                            color: isDeleted ? AppTheme.textSecondary.withOpacity(0.3) : AppTheme.textSecondary.withOpacity(0.7),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        Expanded(
                                                          child: Text(
                                                            account.name,
                                                            style: TextStyle(
                                                              fontSize: 10,
                                                              color: isDeleted ? AppTheme.textSecondary.withOpacity(0.5) : AppTheme.textSecondary,
                                                              decoration: isDeleted ? TextDecoration.lineThrough : null,
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),

                                              // Trailing amount
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      if (!isDeleted && !dataService.isTransactionEditable(tx)) ...[
                                                        const Tooltip(
                                                          message: 'Locked: Prior to account snapshot',
                                                          child: Icon(Icons.lock_outline, color: AppTheme.textSecondary, size: 12),
                                                        ),
                                                        const SizedBox(width: 4),
                                                      ],
                                                      Text(
                                                        '$prefix${NumberFormat.simpleCurrency(name: tx.currency).format(tx.amount.abs())} ${tx.currency}',
                                                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                                              color: amountColor,
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 14,
                                                              decoration: isDeleted ? TextDecoration.lineThrough : null,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (tx.currency != dataService.displayCurrency) ...[
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '${dataService.formatAndConvert(tx.amount, tx.currency)} ${dataService.displayCurrency}',
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        color: isDeleted ? AppTheme.textSecondary.withOpacity(0.5) : AppTheme.textSecondary,
                                                        decoration: isDeleted ? TextDecoration.lineThrough : null,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );

                                      // Only enable Dismissible on active transactions (non-deleted) and editable transactions
                                      if (!isDeleted && dataService.isTransactionEditable(tx)) {
                                        return Dismissible(
                                          key: Key('tx_dismiss_${tx.id}'),
                                          direction: DismissDirection.horizontal,
                                          background: Container(
                                            alignment: Alignment.centerLeft,
                                            padding: const EdgeInsets.only(left: 16.0),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryPurple.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.edit_outlined,
                                              color: AppTheme.primaryPurple,
                                              size: 22,
                                            ),
                                          ),
                                          secondaryBackground: Container(
                                            alignment: Alignment.centerRight,
                                            padding: const EdgeInsets.only(right: 16.0),
                                            decoration: BoxDecoration(
                                              color: AppTheme.dangerRed.withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.delete_outline,
                                              color: AppTheme.dangerRed,
                                              size: 22,
                                            ),
                                          ),
                                          confirmDismiss: (direction) async {
                                            if (direction == DismissDirection.startToEnd) {
                                              _showAddTransactionDialog(context, dataService, editTx: tx);
                                              return false;
                                            } else {
                                              return await showDialog<bool>(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  backgroundColor: AppTheme.darkCard,
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                  title: Row(
                                                    children: const [
                                                      Icon(Icons.delete_outline, color: AppTheme.dangerRed),
                                                      SizedBox(width: 8),
                                                      Text('Delete Transaction?'),
                                                    ],
                                                  ),
                                                  content: const Text(
                                                    'Are you sure you want to delete this transaction? This will reverse the amount from the account balance.',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () => Navigator.of(context).pop(false),
                                                      child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                                                    ),
                                                    ElevatedButton(
                                                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
                                                      onPressed: () => Navigator.of(context).pop(true),
                                                      child: const Text('Delete'),
                                                    ),
                                                  ],
                                                ),
                                              ) ?? false;
                                            }
                                          },
                                          onDismissed: (direction) {
                                            if (direction == DismissDirection.endToStart) {
                                              dataService.deleteTransaction(tx);
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Deleted transaction: ${tx.description ?? "No description"}'),
                                                  duration: const Duration(seconds: 2),
                                                ),
                                              );
                                            }
                                          },
                                          child: itemWidget,
                                        );
                                      }
                                      return itemWidget;
                                    }

                                    // Desktop layout
                                    return SelectionArea(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 3,
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
                                              flex: 2,
                                              child: Text(
                                                dateFormatter.format(tx.date),
                                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  fontFamily: 'monospace',
                                                  color: isDeleted ? AppTheme.textSecondary.withOpacity(0.5) : Colors.white,
                                                  decoration: isDeleted ? TextDecoration.lineThrough : null,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Column(
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
                                            ),
                                            SizedBox(
                                              width: 60,
                                              child: Center(
                                                child: isDeleted
                                                    ? const SizedBox()
                                                    : !dataService.isTransactionEditable(tx)
                                                        ? const Tooltip(
                                                            message: 'Locked: Prior to account snapshot',
                                                            child: Icon(Icons.lock_outline, color: AppTheme.textSecondary, size: 20),
                                                          )
                                                        : PopupMenuButton<String>(
                                                            icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
                                                            color: AppTheme.darkCard,
                                                            onSelected: (action) async {
                                                              if (action == 'edit') {
                                                                _showAddTransactionDialog(context, dataService, editTx: tx);
                                                              } else if (action == 'delete') {
                                                                final confirmed = await showDialog<bool>(
                                                                  context: context,
                                                                  builder: (context) => AlertDialog(
                                                                    backgroundColor: AppTheme.darkCard,
                                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                                    title: Row(
                                                                      children: const [
                                                                        Icon(Icons.delete_outline, color: AppTheme.dangerRed),
                                                                        SizedBox(width: 8),
                                                                        Text('Delete Transaction?'),
                                                                      ],
                                                                    ),
                                                                    content: const Text(
                                                                      'Are you sure you want to delete this transaction? This will reverse the amount from the account balance.',
                                                                    ),
                                                                    actions: [
                                                                      TextButton(
                                                                        onPressed: () => Navigator.of(context).pop(false),
                                                                        child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                                                                      ),
                                                                      ElevatedButton(
                                                                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerRed),
                                                                        onPressed: () => Navigator.of(context).pop(true),
                                                                        child: const Text('Delete'),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                );
                                                                if (confirmed == true) {
                                                                  await dataService.deleteTransaction(tx);
                                                                }
                                                              }
                                                            },
                                                            itemBuilder: (context) => [
                                                              const PopupMenuItem(
                                                                value: 'edit',
                                                                child: Row(
                                                                  children: [
                                                                    Icon(Icons.edit_outlined, size: 16),
                                                                    SizedBox(width: 8),
                                                                    Text('Edit'),
                                                                  ],
                                                                ),
                                                              ),
                                                              const PopupMenuItem(
                                                                value: 'delete',
                                                                child: Row(
                                                                  children: [
                                                                    Icon(Icons.delete_outline, color: AppTheme.dangerRed, size: 16),
                                                                    SizedBox(width: 8),
                                                                    Text('Delete', style: TextStyle(color: AppTheme.dangerRed)),
                                                                  ],
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                              ),
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

  void _showAddTransactionDialog(BuildContext context, DataService dataService, {Transaction? editTx}) {
    final activeAccounts = dataService.accounts.where((a) => a.status == 'active').toList();
    if (activeAccounts.isEmpty || dataService.categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please register at least one active account and category first.')),
      );
      return;
    }

    // Sort active accounts alphabetically
    activeAccounts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    // Create a list of accounts that includes archived/inactive ones if editing
    final List<Account> dialogAccounts = List.from(activeAccounts);
    Transaction? pairedTx;
    String? transferTag;
    if (editTx != null) {
      Account? acc1;
      for (final a in dataService.accounts) {
        if (a.id == editTx.accountId) {
          acc1 = a;
          break;
        }
      }
      final nonNullAcc1 = acc1;
      if (nonNullAcc1 != null && !dialogAccounts.any((a) => a.id == nonNullAcc1.id)) {
        dialogAccounts.add(nonNullAcc1);
      }
      for (final tag in editTx.tags) {
        if (tag.startsWith('transfer_')) {
          transferTag = tag;
          break;
        }
      }
      if (transferTag != null) {
        for (final t in dataService.transactions) {
          if (t.id != editTx.id && t.tags.contains(transferTag) && t.status != 'deleted') {
            pairedTx = t;
            break;
          }
        }
        final nonNullPairedTx = pairedTx;
        if (nonNullPairedTx != null) {
          Account? acc2;
          for (final a in dataService.accounts) {
            if (a.id == nonNullPairedTx.accountId) {
              acc2 = a;
              break;
            }
          }
          final nonNullAcc2 = acc2;
          if (nonNullAcc2 != null && !dialogAccounts.any((a) => a.id == nonNullAcc2.id)) {
            dialogAccounts.add(nonNullAcc2);
          }
        }
      }
    }

    String transactionType = 'expense';
    if (editTx != null) {
      if (transferTag != null) {
        transactionType = 'transfer';
      } else {
        final cat = dataService.categories.firstWhere(
          (c) => c.id == editTx.categoryId,
          orElse: () => Category(id: '', name: 'Unknown', type: 'expense', createdAt: DateTime.now()),
        );
        if (cat.type == 'income' || cat.type == 'reimbursement') {
          transactionType = 'income';
        } else {
          transactionType = 'expense';
        }
      }
    }

    setState(() {
      if (editTx != null) {
        if (transactionType == 'transfer') {
          final outflow = editTx.amount < 0 ? editTx : pairedTx;
          final inflow = editTx.amount < 0 ? pairedTx : editTx;
          
          _selectedAccountId = outflow?.accountId;
          _selectedTransferToAccountId = inflow?.accountId;
          _selectedCategoryId = editTx.categoryId;
          _selectedTxCurrency = outflow?.currency ?? editTx.currency;
          _amountController.text = editTx.amount.abs().toString();
          _descriptionController.text = editTx.description ?? '';
          _selectedDate = editTx.date;
        } else {
          _selectedAccountId = editTx.accountId;
          _selectedTransferToAccountId = dialogAccounts.length > 1 ? dialogAccounts[1].id : (dialogAccounts.isNotEmpty ? dialogAccounts.first.id : null);
          _selectedCategoryId = editTx.categoryId;
          _selectedTxCurrency = editTx.currency;
          _amountController.text = editTx.amount.abs().toString();
          _descriptionController.text = editTx.description ?? '';
          _selectedDate = editTx.date;
        }
      } else {
        _selectedAccountId = null;
        if (dialogAccounts.length > 1) {
          _selectedTransferToAccountId = dialogAccounts[1].id;
        } else {
          _selectedTransferToAccountId = dialogAccounts.isNotEmpty ? dialogAccounts.first.id : null;
        }
        _selectedCategoryId = null;
        _selectedTxCurrency = 'MXN';
        _amountController.clear();
        _descriptionController.clear();
        _selectedDate = DateTime.now();
      }
      _dateController.text = DateFormat('yyyy-MM-dd').format(_selectedDate);
    });

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final expIncAccounts = dialogAccounts.where((a) => a.type == 'checking' || a.type == 'credit_card').toList();

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
                          selected: {transactionType},
                          showSelectedIcon: false,
                          onSelectionChanged: (newSelection) {
                            setDialogState(() {
                              transactionType = newSelection.first;
                              _selectedCategoryId = null; // Clear pre-fill on type change

                              if (transactionType == 'income') {
                                final defaultAcc = expIncAccounts.firstWhere(
                                  (a) => a.name.toLowerCase().contains('debit'),
                                  orElse: () => expIncAccounts.firstWhere(
                                    (a) => a.type == 'checking',
                                    orElse: () => expIncAccounts.isNotEmpty ? expIncAccounts.first : dialogAccounts.first,
                                  ),
                                );
                                _selectedAccountId = defaultAcc.id;
                                _selectedTxCurrency = defaultAcc.currency;
                              } else if (transactionType == 'expense') {
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
                          key: ValueKey('${transactionType}_$_selectedCategoryId'),
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
                            key: ValueKey('${transactionType}_account_$_selectedAccountId'),
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
                      if (transactionType == 'transfer') {
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
                              ? (editTx.amount < 0 ? editTx.id : (pairedTx?.id ?? _uuid.v4().substring(0, 20)))
                              : _uuid.v4().substring(0, 20),
                          accountId: _selectedAccountId!,
                          categoryId: _selectedCategoryId!,
                          amount: -absAmount,
                          currency: sourceAccount.currency,
                          date: _selectedDate,
                          description: _descriptionController.text.trim().isEmpty ? 'Internal Transfer' : _descriptionController.text.trim(),
                          tags: [tTag],
                          createdAt: editTx?.createdAt ?? DateTime.now(),
                        );

                        // 2. Inflow transaction (with currency conversion if different)
                        final inflowAmount = dataService.convert(absAmount, sourceAccount.currency, destAccount.currency);
                        final inflowTx = Transaction(
                          id: (editTx != null && transferTag != null)
                              ? (editTx.amount >= 0 ? editTx.id : (pairedTx?.id ?? _uuid.v4().substring(0, 20)))
                              : _uuid.v4().substring(0, 20),
                          accountId: _selectedTransferToAccountId!,
                          categoryId: _selectedCategoryId!,
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
                        if (transactionType == 'expense') {
                          finalAmount = -absAmount;
                        }

                        final selectedAccount = dialogAccounts.firstWhere((a) => a.id == _selectedAccountId);
                        final String txCurrency = _selectedTxCurrency ?? selectedAccount.currency;
                        final double exRate = dataService.convert(1.0, txCurrency, selectedAccount.currency);

                        final newTx = Transaction(
                          id: editTx?.id ?? _uuid.v4().substring(0, 20),
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
      },
    );
  }
}
