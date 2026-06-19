import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/data_service.dart';
import '../core/theme.dart';
import '../models/account.dart';
import '../models/category.dart';
import 'package:intl/intl.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<DataService>(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top header bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Personal Wealth Ledger',
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 28),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Real-time Firestore & Supabase unified status',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    Consumer<DataService>(
                      builder: (context, ds, child) {
                        final state = ds.backupState;
                        String text = 'Sync: Checking...';
                        Color statusColor = AppTheme.textSecondary;
                        bool isLoading = false;

                        if (state != null) {
                          final status = state['status'] ?? '';
                          final lastDate = state['last_backup_date'] ?? 'Never';
                          if (status == 'in_progress') {
                            text = 'Syncing to Supabase...';
                            statusColor = AppTheme.mainAction;
                            isLoading = true;
                          } else if (status == 'success') {
                            text = 'Synced: $lastDate';
                            statusColor = AppTheme.successGreen;
                          } else if (status == 'failed') {
                            text = 'Sync Failed';
                            statusColor = AppTheme.dangerRed;
                          }
                        }

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D1D22),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF23232A)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/images/supabase_logo.png',
                                width: 16,
                                height: 16,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.cloud_upload_outlined, size: 16, color: AppTheme.textSecondary),
                              ),
                              const SizedBox(width: 8),
                              if (isLoading)
                                const SizedBox(
                                  width: 10,
                                  height: 10,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.mainAction),
                                  ),
                                )
                              else
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              const SizedBox(width: 8),
                              Text(
                                text,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Main Layout Grid
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth > 800;

                    return isDesktop
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  children: [
                                    _buildNetWorthCard(context, dataService),
                                    const SizedBox(height: 24),
                                    _buildChartsSection(context, dataService),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 2,
                                child: _buildAccountsSection(context, dataService),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              _buildNetWorthCard(context, dataService),
                              const SizedBox(height: 24),
                              _buildAccountsSection(context, dataService),
                              const SizedBox(height: 24),
                              _buildChartsSection(context, dataService),
                            ],
                          );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNetWorthCard(BuildContext context, DataService service) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.mainAction.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NET WORTH',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white.withOpacity(0.7),
                    letterSpacing: 2.0,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              service.formatCurrency(service.netWorth),
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.trending_up, color: Colors.white.withOpacity(0.9)),
                const SizedBox(width: 8),
                Text(
                  '+12.4% this month',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartsSection(BuildContext context, DataService service) {
    // Generate simple charts based on transaction categories
    final Map<String, double> categorySummaries = {};
    for (var tx in service.transactions) {
      if (tx.status == 'deleted') continue;
      if (tx.amount < 0) {
        Category? cat;
        for (var c in service.categories) {
          if (c.id == tx.categoryId) {
            cat = c;
            break;
          }
        }
        cat ??= Category(id: '', name: 'Miscellaneous', type: 'expense', createdAt: DateTime.now());
        // Exclude internal transfers from charts as per Rule 2.4
        if (cat.type != 'transfer') {
          // Convert amount to display currency first
          final amountInDisplay = service.convertToDisplay(tx.amount.abs(), tx.currency);
          categorySummaries[cat.name] = (categorySummaries[cat.name] ?? 0) + amountInDisplay;
        }
      }
    }

    final List<PieChartSectionData> chartSections = [];
    int index = 0;
    final colors = [
      AppTheme.mainAction,
      AppTheme.secondaryColor,
      AppTheme.successGreen,
      AppTheme.warningOrange,
      AppTheme.dangerRed,
      Colors.pink,
      Colors.blue,
    ];

    categorySummaries.forEach((catName, sum) {
      final color = colors[index % colors.length];
      chartSections.add(
        PieChartSectionData(
          color: color,
          value: sum,
          title: service.formatCurrency(sum),
          radius: 50,
          titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      );
      index++;
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Outflow Breakdown',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Excludes internal transfers (Rule 2.4)',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            if (chartSections.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40.0),
                  child: Text('No expense transactions recorded yet.'),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 180,
                      child: PieChart(
                        PieChartData(
                          sections: chartSections,
                          sectionsSpace: 4,
                          centerSpaceRadius: 40,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: categorySummaries.keys.map((catName) {
                        final idx = categorySummaries.keys.toList().indexOf(catName);
                        final color = colors[idx % colors.length];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            children: [
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  catName,
                                  style: Theme.of(context).textTheme.bodyLarge,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountsSection(BuildContext context, DataService service) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Accounts & Containers',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Builder(
              builder: (context) {
                final activeAccounts = service.accounts.where((a) => a.status == 'active').toList();
                
                // Sort accounts by type hierarchy
                const typeOrder = {
                  'checking': 0,
                  'savings': 1,
                  'credit_card': 2,
                  'investment': 3,
                  'crypto_wallet': 4,
                  'retirement': 5,
                };
                activeAccounts.sort((a, b) {
                  final orderA = typeOrder[a.type] ?? 99;
                  final orderB = typeOrder[b.type] ?? 99;
                  if (orderA != orderB) {
                    return orderA.compareTo(orderB);
                  }
                  return a.name.toLowerCase().compareTo(b.name.toLowerCase());
                });

                if (activeAccounts.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.0),
                      child: Text('No active accounts registered.'),
                    ),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: activeAccounts.length,
                  separatorBuilder: (context, index) => const Divider(color: Color(0xFF23232A)),
                  itemBuilder: (context, index) {
                    final account = activeAccounts[index];
                    return _buildAccountRow(context, account, service);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountRow(BuildContext context, Account account, DataService service) {
    // Rule 2.1 brokerage rules
    double totalVal = account.currentBalance;
    bool isBrokerage = account.type == 'investment' || account.type == 'retirement';
    
    if (isBrokerage) {
      // Rule 4.3 aggregation: account.current_balance + Sum(holding.quantity * holding.avg_buy_price)
      final accountHoldings = service.holdings.where((h) => h.accountId == account.id);
      double holdingsVal = accountHoldings.fold(0.0, (sum, item) => sum + (item.quantity * item.avgBuyPrice));
      totalVal = account.currentBalance + holdingsVal;
    }

    IconData iconData = Icons.account_balance_wallet;
    if (account.type == 'credit_card') iconData = Icons.credit_card;
    if (isBrokerage) iconData = Icons.analytics;
    if (account.type == 'crypto_wallet') iconData = Icons.currency_bitcoin;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1D1D22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(iconData, color: AppTheme.mainAction),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  account.type.toUpperCase(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                service.formatAndConvert(totalVal, account.currency),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: account.type == 'credit_card' ? AppTheme.dangerRed : Colors.white,
                    ),
              ),
              if (isBrokerage)
                Text(
                  'Cash: ${service.formatAndConvert(account.currentBalance, account.currency)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
