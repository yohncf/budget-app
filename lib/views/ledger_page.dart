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
import 'add_transaction_dialog.dart';

class LedgerPage extends StatefulWidget {
  const LedgerPage({super.key});

  @override
  State<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends State<LedgerPage> {
  final _uuid = const Uuid();
  
  // Filter values
  String _filterType = 'All'; // All, Expense, Income, Transfer
  String _filterCategoryId = 'All'; // All, or specific category ID
  
  // Search values
  final _searchController = TextEditingController();
  String _searchQuery = '';
  
  bool _showDeleted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<DataService>(context, listen: false).setDisplayCurrency('MXN');
      }
    });
  }

  @override
  void dispose() {
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
              // CUSTOMIZATION PREFERENCE: Removed page-specific add button. Add transactions using the global FAB menu.
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Transaction Ledger',
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: isMobile ? 26 : 28),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Detailed historical cash movement records',
                    style: Theme.of(context).textTheme.bodyMedium,
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
    showDialog(
      context: context,
      builder: (context) => AddTransactionDialog(dataService: dataService, editTx: editTx),
    );
  }
}
