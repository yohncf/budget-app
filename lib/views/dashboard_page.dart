import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/data_service.dart';
import '../core/theme.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/budget_target.dart';
import '../models/recurring_transaction.dart';
import '../models/transaction.dart';
import 'package:intl/intl.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  List<DateTime> _getAvailableMonths() {
    final now = DateTime.now();
    final List<DateTime> months = [];
    for (int i = 0; i < 12; i++) {
      months.add(DateTime(now.year, now.month - i, 1));
    }
    return months;
  }

  Color _resolveCategoryColor(Category cat, DataService service) {
    final idx = service.categories.indexWhere((c) => c.id == cat.id);
    if (idx != -1) {
      return AppTheme.categoryColors[idx % AppTheme.categoryColors.length];
    }
    try {
      return Color(int.parse(cat.colorHex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.mainAction;
    }
  }

  void _onMonthChanged(DateTime? newMonth, DataService service) {
    if (newMonth == null) return;
    setState(() {
      _selectedMonth = newMonth;
    });

    if (newMonth.isBefore(service.transactionFilterDate)) {
      service.setTransactionFilterDate(newMonth);
    }
  }

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
                LayoutBuilder(
                  builder: (context, headerConstraints) {
                    final isNarrow = headerConstraints.maxWidth < 600;

                    final headerText = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Personal Wealth Ledger',
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                fontSize: isNarrow ? 24 : 28,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Real-time Firestore & Supabase unified status',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    );

                    final syncStatus = Consumer<DataService>(
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
                    );

                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          headerText,
                          const SizedBox(height: 12),
                          syncStatus,
                        ],
                      );
                    }

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: headerText),
                        const SizedBox(width: 16),
                        syncStatus,
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),

                // Main Layout Grid
                Column(
                  children: [
                    _buildIncomeVsExpensesChart(context, dataService),
                    const SizedBox(height: 24),
                    _buildChartsSection(context, dataService),
                    const SizedBox(height: 24),
                    _buildMergedBudgetsAndRecurringSection(context, dataService),
                    const SizedBox(height: 24),
                    _buildNetWorthCard(context, dataService),
                  ],
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

  Widget _buildMonthSelector(BuildContext context, DataService service) {
    final months = _getAvailableMonths();
    final formattedSelected = DateFormat('MMMM yyyy').format(_selectedMonth);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1D1D22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF23232A)),
      ),
      child: PopupMenuButton<DateTime>(
        initialValue: _selectedMonth,
        tooltip: 'Change month',
        onSelected: (date) => _onMonthChanged(date, service),
        color: AppTheme.darkCard,
        itemBuilder: (context) {
          return months.map((m) {
            final label = DateFormat('MMMM yyyy').format(m);
            final isSelected = m.year == _selectedMonth.year && m.month == _selectedMonth.month;
            return PopupMenuItem<DateTime>(
              value: m,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? AppTheme.mainAction : Colors.white,
                ),
              ),
            );
          }).toList();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                formattedSelected,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.mainAction,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                Icons.arrow_drop_down,
                size: 16,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartsSection(BuildContext context, DataService service) {
    Color parseColor(String colorHex) {
      try {
        return Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
      } catch (_) {
        return AppTheme.mainAction;
      }
    }

    IconData getCategoryIcon(String? iconName) {
      switch (iconName?.toLowerCase()) {
        case 'shopping':
        case 'shopping_bag':
          return Icons.shopping_bag_outlined;
        case 'food':
        case 'dining':
        case 'restaurant':
          return Icons.restaurant_outlined;
        case 'groceries':
          return Icons.local_grocery_store_outlined;
        case 'health':
        case 'medical':
          return Icons.medical_services_outlined;
        case 'travel':
        case 'flight':
          return Icons.flight_takeoff_outlined;
        case 'transport':
        case 'taxi':
        case 'car':
          return Icons.directions_car_outlined;
        case 'entertainment':
        case 'movie':
          return Icons.movie_outlined;
        case 'utilities':
        case 'bill':
          return Icons.receipt_long_outlined;
        case 'education':
          return Icons.school_outlined;
        default:
          return Icons.category_outlined;
      }
    }

    // Generate simple charts based on transaction categories
    final Map<Category, double> categorySummaries = {};
    double totalOutflow = 0.0;

    for (var tx in service.transactions) {
      if (tx.status == 'deleted') continue;
      if (tx.date.year != _selectedMonth.year || tx.date.month != _selectedMonth.month) {
        continue;
      }
      if (tx.amount < 0) {
        Category? cat;
        for (var c in service.categories) {
          if (c.id == tx.categoryId) {
            cat = c;
            break;
          }
        }
        cat ??= Category(id: '', name: 'Miscellaneous', type: 'expense', colorHex: '#9CA3AF', createdAt: DateTime.now());
        if (cat.type == 'transfer') continue;
        
        final amountInDisplay = service.convertToDisplay(tx.amount.abs(), tx.currency);
        
        Category? existingKey;
        for (var key in categorySummaries.keys) {
          if (key.id == cat.id || (key.id.isEmpty && cat.id.isEmpty && key.name == cat.name)) {
            existingKey = key;
            break;
          }
        }
        if (existingKey != null) {
          categorySummaries[existingKey] = categorySummaries[existingKey]! + amountInDisplay;
        } else {
          categorySummaries[cat] = amountInDisplay;
        }
        totalOutflow += amountInDisplay;
      }
    }

    final sortedEntries = categorySummaries.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Curated harmonious color palette for categories when not defined in DB
    final List<Color> categoryPalette = [
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFF3B82F6), // Blue
      const Color(0xFF10B981), // Emerald
      const Color(0xFFF59E0B), // Amber
      const Color(0xFFEF4444), // Red
      const Color(0xFFEC4899), // Pink
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFF84CC16), // Lime
      const Color(0xFF14B8A6), // Teal
      const Color(0xFFF97316), // Orange
      const Color(0xFF6366F1), // Indigo
      const Color(0xFFD946EF), // Fuchsia
      const Color(0xFF60A5FA), // Light Blue
      const Color(0xFF34D399), // Light Emerald
      const Color(0xFFFBBF24), // Light Amber
      const Color(0xFFF87171), // Light Red
      const Color(0xFFF472B6), // Light Pink
    ];

    final Map<String, Color> categoryColors = {};
    for (int i = 0; i < sortedEntries.length; i++) {
      final cat = sortedEntries[i].key;
      final key = cat.id.isNotEmpty ? cat.id : cat.name;
      if (cat.colorHex.isNotEmpty && 
          cat.colorHex.toLowerCase() != '#8b5cf6' && 
          cat.colorHex.toLowerCase() != 'null' &&
          cat.colorHex.toLowerCase() != 'undefined') {
        categoryColors[key] = parseColor(cat.colorHex);
      } else {
        categoryColors[key] = categoryPalette[i % categoryPalette.length];
      }
    }

    final List<PieChartSectionData> chartSections = [];
    for (var entry in sortedEntries) {
      final cat = entry.key;
      final sum = entry.value;
      final color = categoryColors[cat.id.isNotEmpty ? cat.id : cat.name] ?? parseColor(cat.colorHex);
      
      chartSections.add(
        PieChartSectionData(
          color: color,
          value: sum,
          title: '', 
          radius: 16, 
          showTitle: false,
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Monthly Outflow Breakdown',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Excludes internal transfers (Rule 2.4)',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                _buildMonthSelector(context, service),
              ],
            ),
            const SizedBox(height: 32),
            if (chartSections.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 40.0),
                  child: Text('No expense transactions recorded for this month.'),
                ),
              )
            else ...[
              // Donut Chart + Legend Row
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  
                  final donutChart = Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 180,
                        width: 180,
                        child: PieChart(
                          PieChartData(
                            sections: chartSections,
                            sectionsSpace: 3,
                            centerSpaceRadius: 60,
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            service.formatCurrency(totalOutflow),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );

                  final legendList = Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: sortedEntries.map((entry) {
                      final cat = entry.key;
                      final color = categoryColors[cat.id.isNotEmpty ? cat.id : cat.name] ?? parseColor(cat.colorHex);
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            cat.name,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  );

                  if (isMobile) {
                    return Column(
                      children: [
                        Center(child: donutChart),
                        const SizedBox(height: 24),
                        Center(child: legendList),
                      ],
                    );
                  }

                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(),
                      donutChart,
                      const SizedBox(width: 48),
                      Expanded(
                        flex: 3,
                        child: legendList,
                      ),
                      const Spacer(),
                    ],
                  );
                },
              ),
              const SizedBox(height: 32),
              const Divider(color: Color(0xFF23232A)),
              const SizedBox(height: 16),
              
              // Category Card List (looking exactly like the user's uploaded mock)
              ...sortedEntries.map((entry) {
                final cat = entry.key;
                final sum = entry.value;
                final percent = totalOutflow > 0 ? (sum / totalOutflow) * 100 : 0.0;
                final color = categoryColors[cat.id.isNotEmpty ? cat.id : cat.name] ?? parseColor(cat.colorHex);
                final iconData = getCategoryIcon(cat.icon);

                // Determine if over budget for the trend arrow (up-red / down-green)
                bool isOverBudget = false;
                BudgetTarget? target;
                for (var t in service.budgetTargets) {
                  if (t.categoryId == cat.id) {
                    target = t;
                    break;
                  }
                }
                if (target != null && sum > target.targetAmount) {
                  isOverBudget = true;
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141417),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF23232A)),
                  ),
                  child: Row(
                    children: [
                      // Circular colored category icon container
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(color: color.withOpacity(0.3), width: 1),
                        ),
                        child: Icon(
                          iconData,
                          color: color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Category Name
                      Expanded(
                        child: Text(
                          cat.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      // Amount & Outflow Percentage Trend
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            service.formatCurrency(sum),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${percent.toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                isOverBudget ? Icons.arrow_upward : Icons.arrow_downward,
                                color: isOverBudget ? AppTheme.dangerRed : AppTheme.successGreen,
                                size: 12,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
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

  Widget _buildIncomeVsExpensesChart(BuildContext context, DataService service) {
    final daysInMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    final Map<int, double> dailyIncomeMap = {};
    final Map<int, double> dailyExpenseMap = {};
    for (int i = 1; i <= daysInMonth; i++) {
      dailyIncomeMap[i] = 0.0;
      dailyExpenseMap[i] = 0.0;
    }

    double totalIncome = 0.0;
    double totalExpenses = 0.0;
    
    for (var tx in service.transactions) {
      if (tx.status == 'deleted') continue;
      if (tx.date.year != _selectedMonth.year || tx.date.month != _selectedMonth.month) {
        continue;
      }
      final cat = service.categories.firstWhere((c) => c.id == tx.categoryId,
          orElse: () => Category(id: '', name: 'Unknown', type: 'expense', createdAt: DateTime.now()));
      if (cat.type == 'transfer') continue;
      
      final amountInDisplay = service.convertToDisplay(tx.amount, tx.currency);
      final day = tx.date.day;
      if (amountInDisplay > 0) {
        dailyIncomeMap[day] = (dailyIncomeMap[day] ?? 0.0) + amountInDisplay;
        totalIncome += amountInDisplay;
      } else {
        dailyExpenseMap[day] = (dailyExpenseMap[day] ?? 0.0) + amountInDisplay.abs();
        totalExpenses += amountInDisplay.abs();
      }
    }

    final List<FlSpot> incomeSpots = [];
    final List<FlSpot> expenseSpots = [];
    double cumulativeIncome = 0.0;
    double cumulativeExpense = 0.0;
    double maxCumulativeVal = 0.0;
    
    for (int d = 1; d <= daysInMonth; d++) {
      cumulativeIncome += dailyIncomeMap[d] ?? 0.0;
      cumulativeExpense += dailyExpenseMap[d] ?? 0.0;
      incomeSpots.add(FlSpot(d.toDouble(), cumulativeIncome));
      expenseSpots.add(FlSpot(d.toDouble(), cumulativeExpense));
      if (cumulativeIncome > maxCumulativeVal) maxCumulativeVal = cumulativeIncome;
      if (cumulativeExpense > maxCumulativeVal) maxCumulativeVal = cumulativeExpense;
    }

    final chartMaxY = maxCumulativeVal > 0 ? maxCumulativeVal * 1.15 : 1000.0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Income vs Expenses',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Cumulative comparison for ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                _buildMonthSelector(context, service),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                _buildLegendItem('Income', AppTheme.mainAction),
                const SizedBox(width: 16),
                _buildLegendItem('Expenses', AppTheme.dangerRed),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minX: 1,
                  maxX: daysInMonth.toDouble(),
                  minY: 0,
                  maxY: chartMaxY,
                  gridData: FlGridData(
                    show: true,
                    drawHorizontalLine: true,
                    drawVerticalLine: true,
                    horizontalInterval: chartMaxY / 5 > 0 ? chartMaxY / 5 : 200,
                    verticalInterval: 5,
                    getDrawingHorizontalLine: (value) {
                      return const FlLine(
                        color: Color(0xFF23232A),
                        strokeWidth: 1,
                      );
                    },
                    getDrawingVerticalLine: (value) {
                      return const FlLine(
                        color: Color(0xFF23232A),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: const Color(0xFF23232A)),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 5,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final dayVal = value.toInt();
                          if (dayVal >= 1 && dayVal <= daysInMonth) {
                            return SideTitleWidget(
                              meta: meta,
                              child: Text('$dayVal', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => AppTheme.darkCard,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final isIncomeLine = spot.barIndex == 0;
                          final title = isIncomeLine ? 'Cumulative Income' : 'Cumulative Expense';
                          final color = isIncomeLine ? AppTheme.mainAction : AppTheme.dangerRed;
                          return LineTooltipItem(
                            'Day ${spot.x.toInt()}: $title ${service.formatCurrency(spot.y)}',
                            TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: incomeSpots,
                      isCurved: true,
                      color: AppTheme.mainAction,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.mainAction.withOpacity(0.08),
                      ),
                    ),
                    LineChartBarData(
                      spots: expenseSpots,
                      isCurved: true,
                      color: AppTheme.dangerRed,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.dangerRed.withOpacity(0.08),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    const Text('Total Income', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      service.formatCurrency(totalIncome),
                      style: const TextStyle(color: AppTheme.mainAction, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                Column(
                  children: [
                    const Text('Total Expenses', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      service.formatCurrency(totalExpenses),
                      style: const TextStyle(color: AppTheme.dangerRed, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                Column(
                  children: [
                    const Text('Net Cash Flow', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      service.formatCurrency(totalIncome - totalExpenses),
                      style: TextStyle(
                        color: (totalIncome - totalExpenses) >= 0 ? AppTheme.successGreen : AppTheme.dangerRed,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String title, Color color) {
    return Row(
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
        Text(title, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
      ],
    );
  }

  double _getRecurringSpent(RecurringTransaction rt, DataService service) {
    double spent = 0.0;
    for (Transaction tx in service.transactions) {
      if (tx.status == 'deleted') continue;
      if (tx.date.year != _selectedMonth.year || tx.date.month != _selectedMonth.month) {
        continue;
      }
      
      bool isMatch = false;
      if (tx.recurringId == rt.id) {
        isMatch = true;
      } else if (tx.categoryId == rt.categoryId) {
        final txDesc = (tx.description ?? '').toLowerCase().trim();
        final rtDesc = rt.description.toLowerCase().trim();
        if (rtDesc.isNotEmpty && txDesc.isNotEmpty) {
          if (txDesc.contains(rtDesc) || rtDesc.contains(txDesc)) {
            isMatch = true;
          }
        } else if (rtDesc.isEmpty) {
          isMatch = true;
        }
      }
      
      if (isMatch) {
        spent += service.convertToDisplay(tx.amount.abs(), tx.currency);
      }
    }
    return spent;
  }

  Widget _buildMergedBudgetsAndRecurringSection(BuildContext context, DataService service) {
    final expenseCategories = service.categories.where((c) => c.type == 'expense').toList();

    final Map<String, double> categorySpending = {};
    for (Transaction tx in service.transactions) {
      if (tx.status == 'deleted') continue;
      if (tx.date.year != _selectedMonth.year || tx.date.month != _selectedMonth.month) {
        continue;
      }
      final cat = service.categories.firstWhere((c) => c.id == tx.categoryId,
          orElse: () => Category(id: '', name: 'Unknown', type: 'expense', createdAt: DateTime.now()));
      if (cat.type == 'expense') {
        final amountInDisplay = service.convertToDisplay(tx.amount.abs(), tx.currency);
        categorySpending[cat.id] = (categorySpending[cat.id] ?? 0) + amountInDisplay;
      }
    }

    final Map<String, double> categoryBudgets = {};
    final Map<String, BudgetTarget> categoryBudgetTargetObjects = {};
    for (BudgetTarget target in service.budgetTargets) {
      final startLimit = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
      final endLimit = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1).subtract(const Duration(days: 1));
      
      final targetStart = DateTime(target.startDate.year, target.startDate.month, target.startDate.day);
      final targetEnd = DateTime(target.endDate.year, target.endDate.month, target.endDate.day);

      if (!targetStart.isAfter(endLimit) && !targetEnd.isBefore(startLimit)) {
        categoryBudgets[target.categoryId] = target.targetAmount;
        categoryBudgetTargetObjects[target.categoryId] = target;
      }
    }

    final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1).subtract(const Duration(days: 1));

    final recurringThisMonth = service.recurringTransactions.where((rt) {
      if (rt.status != 'active') return false;
      if (rt.startDate.isAfter(endOfMonth)) return false;
      if (rt.endDate != null && rt.endDate!.isBefore(startOfMonth)) return false;

      // Calculate month difference from nextDueDate to _selectedMonth
      final diffMonths = (_selectedMonth.year - rt.nextDueDate.year) * 12 + (_selectedMonth.month - rt.nextDueDate.month);
      
      final freq = rt.frequency.toLowerCase();
      if (freq == 'monthly') {
        return diffMonths.abs() % rt.interval == 0;
      } else if (freq == 'yearly') {
        return diffMonths.abs() % (rt.interval * 12) == 0;
      } else {
        // daily, weekly, biweekly, etc. happen within every month
        return true;
      }
    }).toList();

    recurringThisMonth.sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));

    final List<Map<String, dynamic>> budgetList = [];
    for (var cat in expenseCategories) {
      final spent = categorySpending[cat.id] ?? 0.0;
      final budget = categoryBudgets[cat.id];
      final target = categoryBudgetTargetObjects[cat.id];
      if (budget != null && target != null) {
        final hasRecurringThisMonth = recurringThisMonth.any((rt) => rt.categoryId == cat.id);
        final isStartMonth = target.startDate.year == _selectedMonth.year && target.startDate.month == _selectedMonth.month;

        if (target.period.toLowerCase() == 'monthly' ||
            spent > 0 ||
            hasRecurringThisMonth ||
            isStartMonth) {
          budgetList.add({
            'category': cat,
            'spent': spent,
            'budget': budget,
          });
        }
      }
    }

    budgetList.sort((a, b) {
      final aOver = a['budget'] != null && a['spent'] > a['budget'];
      final bOver = b['budget'] != null && b['spent'] > b['budget'];
      if (aOver && !bOver) return -1;
      if (!aOver && bOver) return 1;
      return (b['spent'] as double).compareTo(a['spent'] as double);
    });

    final budgetsWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category Budgets',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        if (budgetList.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40.0),
              child: Text('No spending or budget targets set for this month.'),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: budgetList.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final item = budgetList[index];
              final Category cat = item['category'];
              final double spent = item['spent'];
              final double budget = item['budget'];

              final percent = budget > 0 ? (spent / budget) : 0.0;
              final isOver = spent > budget;
              
              Color progressColor = AppTheme.mainAction;
              String statusText = 'On track';
              Color statusColor = AppTheme.successGreen;
              if (isOver) {
                progressColor = AppTheme.dangerRed;
                statusText = 'Over limit';
                statusColor = AppTheme.dangerRed;
              } else if (percent > 0.8) {
                progressColor = AppTheme.warningOrange;
                statusText = 'Near limit';
                statusColor = AppTheme.warningOrange;
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _resolveCategoryColor(cat, service),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            cat.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
                            ),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            service.formatCurrency(spent),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const Text(' / ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                          Text(
                            service.formatCurrency(budget),
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Stack(
                    children: [
                      Container(
                        height: 6,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1D1D22),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: percent.clamp(0.0, 1.0),
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: progressColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${(percent * 100).toStringAsFixed(0)}% used',
                        style: TextStyle(color: isOver ? AppTheme.dangerRed : AppTheme.textSecondary, fontSize: 11),
                      ),
                      if (isOver)
                        Text(
                          'Over by ${service.formatCurrency(spent - budget)}',
                          style: const TextStyle(color: AppTheme.dangerRed, fontSize: 11, fontWeight: FontWeight.bold),
                        )
                      else
                        Text(
                          'Remaining: ${service.formatCurrency(budget - spent)}',
                          style: const TextStyle(color: AppTheme.successGreen, fontSize: 11),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
      ],
    );

    final recurringWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recurring Transactions',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        if (recurringThisMonth.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40.0),
              child: Text('No recurring transactions scheduled for this month.'),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: recurringThisMonth.length,
            separatorBuilder: (context, index) => const SizedBox(height: 20),
            itemBuilder: (context, index) {
              final rt = recurringThisMonth[index];
              
              final account = service.accounts.firstWhere(
                (a) => a.id == rt.accountId,
                orElse: () => Account(id: '', name: 'Deleted Account', type: 'checking', currency: 'USD', createdAt: DateTime.now(), updatedAt: DateTime.now()),
              );

              final category = service.categories.firstWhere(
                (c) => c.id == rt.categoryId,
                orElse: () => Category(id: '', name: 'Uncategorized', type: 'expense', createdAt: DateTime.now()),
              );

              final double budget = service.convertToDisplay(rt.amount.abs(), account.currency);
              final double spent = _getRecurringSpent(rt, service);
              final percent = budget > 0 ? (spent / budget) : 0.0;
              final isPaid = spent >= budget;

              final isExpense = rt.amount < 0 || category.type == 'expense' || category.type == 'investment';
              final amountColor = isExpense ? AppTheme.dangerRed : AppTheme.successGreen;

              Color progressColor = AppTheme.mainAction;
              String statusText = 'Upcoming';
              Color statusColor = AppTheme.textSecondary;
              if (isPaid) {
                progressColor = AppTheme.successGreen;
                statusText = 'Paid';
                statusColor = AppTheme.successGreen;
              } else if (spent > 0) {
                progressColor = AppTheme.warningOrange;
                statusText = 'Paying';
                statusColor = AppTheme.warningOrange;
              } else {
                progressColor = AppTheme.textSecondary.withOpacity(0.5);
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Icon
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isExpense
                              ? AppTheme.dangerRed.withOpacity(0.1)
                              : AppTheme.successGreen.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isExpense
                              ? Icons.arrow_downward_rounded
                              : Icons.arrow_upward_rounded,
                          color: isExpense ? AppTheme.dangerRed : AppTheme.successGreen,
                          size: 14,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  rt.description,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: statusColor.withOpacity(0.3), width: 1),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: TextStyle(
                                      color: statusColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${category.name} • ${rt.frequency.toUpperCase()}',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Amount
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Text(
                                service.formatCurrency(spent),
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: spent > 0 ? amountColor : Colors.white),
                              ),
                              const Text(' / ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
                              Text(
                                service.formatCurrency(budget),
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Due: ${DateFormat('MM-dd').format(rt.nextDueDate)}',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Stack(
                    children: [
                      Container(
                        height: 6,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1D1D22),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: percent.clamp(0.0, 1.0),
                        child: Container(
                          height: 6,
                          decoration: BoxDecoration(
                            color: progressColor,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isPaid
                            ? 'Fully Paid (100%)'
                            : spent > 0
                                ? '${(percent * 100).toStringAsFixed(0)}% paid'
                                : 'Unpaid (0%)',
                        style: TextStyle(
                          color: isPaid ? AppTheme.successGreen : AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: isPaid ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      if (isPaid)
                        const Text(
                          'Paid',
                          style: TextStyle(color: AppTheme.successGreen, fontSize: 11, fontWeight: FontWeight.bold),
                        )
                      else
                        Text(
                          'Remaining: ${service.formatCurrency(budget - spent)}',
                          style: const TextStyle(color: AppTheme.warningOrange, fontSize: 11),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
      ],
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Budgets & Recurring Transactions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  'Month: ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 24),
            budgetsWidget,
            const SizedBox(height: 32),
            const Divider(color: Color(0xFF23232A)),
            const SizedBox(height: 24),
            recurringWidget,
          ],
        ),
      ),
    );
  }
}
