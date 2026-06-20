import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/transaction.dart';
import '../models/account_snapshot.dart';
import '../core/theme.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';

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
  String _selectedCurrency = 'MXN';
  final _balanceController = TextEditingController();
  final _limitController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _institutionController.dispose();
    _balanceController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<DataService>(context);
    final currencyFormatter = NumberFormat.simpleCurrency(name: 'USD');
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.backgroundGradient,
          ),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 12.0 : 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Accounts Management',
                            style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 24),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Create and monitor accounts',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentCyan,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.account_balance),
                              label: const Text('New Account'),
                              onPressed: () => _showAddAccountDialog(context, dataService),
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
                              foregroundColor: Colors.black,
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

    // Sort accounts by type hierarchy
    const typeOrder = {
      'checking': 0,
      'savings': 1,
      'credit_card': 2,
      'investment': 3,
      'crypto_wallet': 4,
      'retirement': 5,
    };
    filteredAccounts.sort((a, b) {
      final orderA = typeOrder[a.type] ?? 99;
      final orderB = typeOrder[b.type] ?? 99;
      if (orderA != orderB) {
        return orderA.compareTo(orderB);
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    if (filteredAccounts.isEmpty) {
      return Center(
        child: Text(
          isActive ? 'No active accounts registered yet.' : 'No archived accounts.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    final bool isMobile = MediaQuery.of(context).size.width < 600;

    if (isMobile) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        itemCount: filteredAccounts.length,
        itemBuilder: (context, index) {
          final account = filteredAccounts[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: _buildAccountCard(context, account, dataService, currencyFormatter),
          );
        },
      );
    }

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 350,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
        childAspectRatio: 1.5,
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

    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final bool isLimitViolated = (account.type == 'credit_card' && account.limit > 0 && totalVal > account.limit) ||
        ((account.type == 'checking' || account.type == 'savings') && account.limit > 0 && totalVal < account.limit);

    // Get historical snapshots points for the graph
    final accountSnapshots = dataService.snapshots
        .where((s) => s.accountId == account.id)
        .toList();
    accountSnapshots.sort((a, b) => a.snapshotDate.compareTo(b.snapshotDate));
    final List<double> points = accountSnapshots.map((s) => s.balance).toList();

    double changePercent = 0.0;
    if (points.length >= 2) {
      final double prev = points[points.length - 2];
      if (prev != 0.0) {
        changePercent = ((points.last - prev) / prev) * 100.0;
      }
    }

    final Color cardBorderColor = isLimitViolated
        ? (account.type == 'credit_card' ? AppTheme.dangerRed : AppTheme.warningOrange)
        : typeColor.withOpacity(0.35);

    final Color glowColor = isLimitViolated
        ? (account.type == 'credit_card' ? AppTheme.dangerRed : AppTheme.warningOrange)
        : typeColor;

    return AspectRatio(
      aspectRatio: isMobile ? 2.2 : 1.586, // Sleeker ratio on mobile to prevent wasted space
      child: Card(
        elevation: 10,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: cardBorderColor,
            width: isLimitViolated ? 2.0 : 1.2,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF131317),
                glowColor.withOpacity(isLimitViolated ? 0.15 : 0.08),
                const Color(0xFF09090B),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // Glowing background ambient decoration blobs
                Positioned(
                  right: -40,
                  top: -40,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          glowColor.withOpacity(0.22),
                          glowColor.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: -50,
                  bottom: -50,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          glowColor.withOpacity(0.18),
                          glowColor.withOpacity(0.0),
                        ],
                      ),
                    ),
                  ),
                ),

                // Main content layout
                Padding(
                  padding: EdgeInsets.all(isMobile ? 11.0 : 18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Institution name & Account name + type column
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              account.institution?.toUpperCase() ?? "VIRTUAL CARD",
                              style: GoogleFonts.inter(
                                fontSize: isMobile ? 12 : 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                                color: Colors.white70,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                account.name.toUpperCase(),
                                style: GoogleFonts.outfit(
                                  fontSize: isMobile ? 16 : 18,
                                  fontWeight: FontWeight.w900,
                                  fontStyle: FontStyle.italic,
                                  color: typeColor.withOpacity(0.95),
                                  letterSpacing: 1.0,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.12),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  typeLabel,
                                  style: GoogleFonts.inter(
                                    fontSize: isMobile ? 11 : 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white.withOpacity(0.9),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      
                      const Spacer(),

                      // Bottom Row: Balance & limits left, settings dots button right
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  account.type == 'credit_card' ? 'Amount Owed' : 'Available Balance',
                                  style: GoogleFonts.inter(
                                    fontSize: isMobile ? 11 : 10,
                                    color: Colors.white60,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        dataService.formatAndConvert(totalVal, account.currency),
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: isMobile ? 21 : 22,
                                          color: isLimitViolated
                                              ? (account.type == 'credit_card' ? AppTheme.dangerRed : AppTheme.warningOrange)
                                              : Colors.white,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isLimitViolated) ...[
                                      const SizedBox(width: 6),
                                      Icon(
                                        Icons.warning_amber_rounded,
                                        color: account.type == 'credit_card' ? AppTheme.dangerRed : AppTheme.warningOrange,
                                        size: 16,
                                      ),
                                    ],
                                  ],
                                ),
                                if (account.type == 'credit_card' && account.limit > 0) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    (account.limit - totalVal) < 0
                                        ? 'Rem: ${dataService.formatAndConvert(account.limit - totalVal, account.currency)} (Over Limit!)'
                                        : 'Rem: ${dataService.formatAndConvert(account.limit - totalVal, account.currency)}',
                                    style: GoogleFonts.inter(
                                      fontSize: isMobile ? 11 : 10,
                                      color: (account.limit - totalVal) < 0 ? AppTheme.dangerRed : AppTheme.successGreen,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ] else if ((account.type == 'checking' || account.type == 'savings') && account.limit > 0) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    totalVal < account.limit
                                        ? 'Min: ${dataService.formatAndConvert(account.limit, account.currency)} (Below Limit!)'
                                        : 'Min: ${dataService.formatAndConvert(account.limit, account.currency)}',
                                    style: GoogleFonts.inter(
                                      fontSize: isMobile ? 11 : 10,
                                      color: totalVal < account.limit ? AppTheme.warningOrange : AppTheme.textSecondary,
                                      fontWeight: totalVal < account.limit ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _showManageAccountDialog(context, account, dataService, totalVal),
                            child: Container(
                              padding: EdgeInsets.all(isMobile ? 8 : 6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withOpacity(0.05),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.1),
                                  width: 0.8,
                                ),
                              ),
                              child: Icon(
                                Icons.more_vert,
                                color: Colors.white.withOpacity(0.9),
                                size: isMobile ? 16 : 14,
                              ),
                            ),
                          ),
                        ],
                      ),
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


  void _showManageAccountDialog(BuildContext context, Account account, DataService dataService, double totalVal) {
    final bool isActive = account.status == 'active';
    final bool isZero = totalVal.abs() < 0.005;

    final nameController = TextEditingController(text: account.name);
    final instController = TextEditingController(text: account.institution ?? '');
    final limitController = TextEditingController(text: account.limit == 0.0 ? '' : account.limit.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          scrollable: true,
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
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Account Name'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: instController,
                    decoration: const InputDecoration(labelText: 'Institution'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: limitController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Account Limit / Constraint',
                      hintText: 'Credit limit or minimum balance (e.g. 500)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.mainAction,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save Details', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      if (nameController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter an account name.')),
                        );
                        return;
                      }
                      final double newLimit = double.tryParse(limitController.text) ?? 0.0;
                      final updatedAccount = account.copyWith(
                        name: nameController.text.trim(),
                        institution: instController.text.trim().isEmpty ? null : instController.text.trim(),
                        limit: newLimit,
                        updatedAt: DateTime.now(),
                      );
                      await dataService.addAccount(updatedAccount);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Account details updated successfully.')),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Color(0xFF2E2E4A)),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentCyan,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Create Balance Snapshot'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showCreateSnapshotConfirmation(context, account, dataService);
                    },
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryPurple,
                      foregroundColor: Colors.black,
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
                        'Delete Unavailable: Account total valuation is not zero (${dataService.formatAndConvert(totalVal, account.currency)}). You can only delete accounts with a zero balance. Please archive this account instead.',
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

  void _showCreateSnapshotConfirmation(BuildContext context, Account account, DataService dataService) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.darkCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.camera_alt_outlined, color: AppTheme.accentCyan),
              const SizedBox(width: 8),
              const Text('Create Balance Snapshot'),
            ],
          ),
          content: Text(
            'Create a new baseline snapshot for "${account.name}" at the current balance of ${dataService.formatAndConvert(account.currentBalance, account.currency)}?\n\n'
            'This snapshot will serve as a historical record log for net worth growth tracking.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4),
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
              child: const Text('Create'),
              onPressed: () async {
                final String snapshotId = const Uuid().v4().substring(0, 20);
                final newSnapshot = AccountSnapshot(
                  id: snapshotId,
                  accountId: account.id,
                  snapshotDate: DateTime.now(),
                  balance: account.currentBalance,
                  currency: account.currency,
                  createdAt: DateTime.now(),
                );

                try {
                  await dataService.addAccountSnapshot(newSnapshot);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Snapshot for "${account.name}" created successfully!')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error creating snapshot: $e')),
                    );
                  }
                }
              },
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
      _limitController.clear();
      _selectedType = 'checking';
      _selectedCurrency = 'MXN';
    });

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              scrollable: true,
              backgroundColor: AppTheme.darkCard,
              title: Text('Register New Account', style: Theme.of(context).textTheme.titleLarge),
              content: SizedBox(
                width: 400,
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
                      value: _selectedType,
                      decoration: const InputDecoration(labelText: 'Account Type'),
                      items: ['checking', 'savings', 'credit_card', 'investment', 'crypto_wallet', 'retirement'].map((t) {
                        return DropdownMenuItem(value: t, child: Text(t.toUpperCase()));
                      }).toList(),
                      onChanged: (val) => setDialogState(() => _selectedType = val!),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedCurrency,
                      decoration: const InputDecoration(labelText: 'Account Currency'),
                      items: ['MXN', 'USD', 'SOL', 'PEN'].map((c) {
                        return DropdownMenuItem(value: c, child: Text(c));
                      }).toList(),
                      onChanged: (val) => setDialogState(() => _selectedCurrency = val!),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _balanceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Opening Balance (Initial Transaction value)'),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _limitController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Account Limit / Constraint',
                        hintText: 'Credit limit or minimum balance (e.g. 500)',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.mainAction,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Create'),
                  onPressed: () async {
                    if (_nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter an account name.')),
                      );
                      return;
                    }

                    final double initBalance = double.tryParse(_balanceController.text) ?? 0.0;
                    final double limitVal = double.tryParse(_limitController.text) ?? 0.0;
                    final accId = _uuid.v4().substring(0, 20);

                    final newAcc = Account(
                      id: accId,
                      name: _nameController.text.trim(),
                      institution: _institutionController.text.trim().isEmpty ? null : _institutionController.text.trim(),
                      type: _selectedType,
                      currency: _selectedCurrency,
                      currentBalance: 0.0,
                      limit: limitVal,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );

                    final messenger = ScaffoldMessenger.of(context);

                    // Unfocus to close keyboard and overlays safely before popping
                    FocusManager.instance.primaryFocus?.unfocus();

                    // Wait a frame for focus changes to propagate
                    await Future.delayed(Duration.zero);

                    // Dismiss dialog first to prevent Flutter Web widget tree collision on rebuild
                    if (context.mounted) {
                      Navigator.of(context).pop();
                    }

                    try {
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
                          currency: _selectedCurrency,
                          date: DateTime.now(),
                          description: 'System: Opening Balance Initialization',
                          createdAt: DateTime.now(),
                        );
                        await dataService.addTransaction(opTx);
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
