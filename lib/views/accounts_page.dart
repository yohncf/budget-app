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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
                const SizedBox(height: 16),
                
                // Tab Bar
                const TabBar(
                  tabs: [
                    Tab(text: 'Active Accounts'),
                    Tab(text: 'Archived Accounts'),
                  ],
                  labelColor: AppTheme.accentCyan,
                  unselectedLabelColor: AppTheme.textSecondary,
                  indicatorColor: AppTheme.accentCyan,
                  dividerColor: Colors.transparent,
                  indicatorWeight: 3.0,
                ),
                const SizedBox(height: 24),

                // Grid views depending on the tab selection
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildAccountsGrid(context, dataService, currencyFormatter, isActive: true),
                      _buildAccountsGrid(context, dataService, currencyFormatter, isActive: false),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccountsGrid(BuildContext context, DataService dataService, NumberFormat currencyFormatter, {required bool isActive}) {
    final filteredAccounts = dataService.accounts.where((a) => (a.status == 'active') == isActive).toList();

    if (filteredAccounts.isEmpty) {
      return Center(
        child: Text(
          isActive ? 'No active accounts registered yet.' : 'No archived accounts.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 350,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
        childAspectRatio: 1.35,
      ),
      itemCount: filteredAccounts.length,
      itemBuilder: (context, index) {
        final account = filteredAccounts[index];
        return _buildAccountCard(context, account, dataService, currencyFormatter);
      },
    );
  }

  Map<String, dynamic> _getTypeDetails(String type) {
    switch (type) {
      case 'checking':
        return {
          'label': 'Checking',
          'color': const Color(0xFF3B82F6), // Vibrant Blue
          'icon': Icons.account_balance,
        };
      case 'savings':
        return {
          'label': 'Savings',
          'color': AppTheme.successGreen, // Green
          'icon': Icons.savings_outlined,
        };
      case 'credit_card':
        return {
          'label': 'Credit Card',
          'color': AppTheme.dangerRed, // Red
          'icon': Icons.credit_card,
        };
      case 'investment':
        return {
          'label': 'Investment',
          'color': AppTheme.primaryPurple, // Purple
          'icon': Icons.trending_up,
        };
      case 'crypto_wallet':
        return {
          'label': 'Crypto Wallet',
          'color': const Color(0xFFF59E0B), // Orange/Gold
          'icon': Icons.currency_bitcoin,
        };
      case 'retirement':
        return {
          'label': 'Retirement',
          'color': AppTheme.accentCyan, // Cyan/Teal
          'icon': Icons.pie_chart_outline,
        };
      default:
        return {
          'label': type.toUpperCase(),
          'color': AppTheme.textSecondary,
          'icon': Icons.help_outline,
        };
    }
  }

  Widget _buildAccountCard(BuildContext context, Account account, DataService dataService, NumberFormat currencyFormatter) {
    double totalVal = account.currentBalance;
    bool isBrokerage = account.type == 'investment' || account.type == 'retirement';
    
    if (isBrokerage) {
      final accountHoldings = dataService.holdings.where((h) => h.accountId == account.id);
      double holdingsVal = accountHoldings.fold(0.0, (sum, item) => sum + (item.quantity * item.avgBuyPrice));
      totalVal = account.currentBalance + holdingsVal;
    }

    final typeDetails = _getTypeDetails(account.type);
    final Color typeColor = typeDetails['color'] as Color;
    final IconData typeIcon = typeDetails['icon'] as IconData;
    final String typeLabel = typeDetails['label'] as String;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: typeColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              AppTheme.darkCard,
              typeColor.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      typeIcon,
                      color: typeColor,
                      size: 20,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings, size: 20, color: AppTheme.textSecondary),
                    tooltip: 'Manage Account',
                    onPressed: () => _showManageAccountDialog(context, account, dataService, totalVal),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                account.name,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                account.institution ?? "Unknown Institution",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Divider(color: typeColor.withOpacity(0.15), height: 1),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currencyFormatter.format(totalVal),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: account.type == 'credit_card' ? AppTheme.dangerRed : Colors.white,
                              ),
                        ),
                        if (isBrokerage)
                          Text(
                            'Cash: ${currencyFormatter.format(account.currentBalance)}',
                            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: typeColor.withOpacity(0.4),
                        width: 1.0,
                      )
                    ),
                    child: Text(
                      typeLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: typeColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showManageAccountDialog(BuildContext context, Account account, DataService dataService, double totalVal) {
    final bool isActive = account.status == 'active';
    final bool isZero = totalVal.abs() < 0.005;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.darkCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.settings, color: AppTheme.accentCyan),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Manage: ${account.name}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Select an action for this account. Note that deleting is permanent, whereas archiving keeps the historical records but hides the account.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: Icon(isActive ? Icons.archive : Icons.unarchive),
                label: Text(isActive ? 'Archive Account (Recommended)' : 'Restore Account to Active'),
                onPressed: () async {
                  final updatedAccount = account.copyWith(
                    status: isActive ? 'archived' : 'active',
                    updatedAt: DateTime.now(),
                  );
                  await dataService.addAccount(updatedAccount);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(isActive 
                          ? '${account.name} has been archived successfully.' 
                          : '${account.name} is now active.'
                        ),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
              const Divider(color: Color(0xFF2E2E4A)),
              const SizedBox(height: 12),
              if (!isZero) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.dangerRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.dangerRed.withOpacity(0.3)),
                  ),
                  child: Text(
                    'Delete Unavailable: Account total valuation is not zero (${NumberFormat.simpleCurrency(name: 'USD').format(totalVal)}). You can only delete accounts with a zero balance. Please archive this account instead.',
                    style: const TextStyle(fontSize: 12, color: AppTheme.dangerRed, height: 1.4),
                  ),
                ),
              ] else ...[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.dangerRed,
                    side: const BorderSide(color: AppTheme.dangerRed),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('Permanently Delete Account'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    _showDeleteConfirmation1(context, account, dataService);
                  },
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close', style: TextStyle(color: AppTheme.textSecondary)),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmation1(BuildContext context, Account account, DataService dataService) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.darkCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppTheme.warningOrange),
              const SizedBox(width: 8),
              const Text('Confirm Deletion (1/2)'),
            ],
          ),
          content: Text(
            'Are you sure you want to permanently delete the account "${account.name}"? '
            'This action is irreversible and will permanently delete the account entity from the database.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.warningOrange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Proceed'),
              onPressed: () {
                Navigator.of(context).pop();
                _showDeleteConfirmation2(context, account, dataService);
              },
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmation2(BuildContext context, Account account, DataService dataService) {
    final TextEditingController textController = TextEditingController();
    bool canSubmit = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.darkCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.gpp_maybe_outlined, color: AppTheme.dangerRed),
                  const SizedBox(width: 8),
                  const Text('Final Warning (2/2)'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'To confirm deletion of "${account.name}", type the word DELETE below. This will delete the account forever.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: textController,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Type DELETE',
                      hintStyle: TextStyle(color: AppTheme.textSecondary),
                    ),
                    onChanged: (val) {
                      setDialogState(() {
                        canSubmit = val.trim() == 'DELETE';
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    textController.dispose();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canSubmit ? AppTheme.dangerRed : AppTheme.darkCard,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF21213E),
                    disabledForegroundColor: AppTheme.textSecondary,
                  ),
                  onPressed: canSubmit
                      ? () async {
                          try {
                            await dataService.deleteAccount(account.id);
                            if (context.mounted) {
                              textController.dispose();
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Account "${account.name}" has been permanently deleted.')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error deleting account: $e')),
                              );
                            }
                          }
                        }
                      : null,
                  child: const Text('Permanently Delete'),
                ),
              ],
            );
          },
        );
      },
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
