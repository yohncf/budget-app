import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/data_service.dart';
import '../core/theme.dart';
import '../models/category.dart';
import '../models/budget_target.dart';
import 'package:intl/intl.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late DateTime _selectedMonth;
  int _selectedCategoryIndex = 0;
  bool _addHoldingsToDebit = false;

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

  void _onMonthChanged(DateTime? newMonth, DataService service) {
    if (newMonth == null) return;
    setState(() {
      _selectedMonth = newMonth;
      _selectedCategoryIndex = 0;
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
                    final theme = Theme.of(context);

                    final headerText = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Personal Wealth Ledger',
                          style: theme.textTheme.headlineMedium?.copyWith(
                                fontSize: isNarrow ? 22 : 28,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Real-time Firestore & Supabase unified status',
                          style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    );

                    final syncStatus = Consumer<DataService>(
                      builder: (context, ds, child) {
                        final state = ds.backupState;
                        String text = 'Sync: Checking...';
                        Color statusColor = theme.colorScheme.onSurfaceVariant;
                        bool isLoading = false;

                        if (state != null) {
                          final status = state['status'] ?? '';
                          final lastDate = state['last_backup_date'] ?? 'Never';
                          if (status == 'in_progress') {
                            text = 'Syncing to Supabase...';
                            statusColor = theme.colorScheme.primary;
                            isLoading = true;
                          } else if (status == 'success') {
                            text = 'Synced: $lastDate';
                            statusColor = AppTheme.successGreen;
                          } else if (status == 'failed') {
                            text = 'Sync Failed';
                            statusColor = theme.colorScheme.error;
                          }
                        }

                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Image.asset(
                                'assets/images/supabase_logo.png',
                                width: 16,
                                height: 16,
                                errorBuilder: (context, error, stackTrace) =>
                                    Icon(Icons.cloud_upload_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                              ),
                              const SizedBox(width: 8),
                              if (isLoading)
                                SizedBox(
                                  width: 10,
                                  height: 10,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.5,
                                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
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
                                style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurface,
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
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth >= 1000) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Column(
                                  children: [
                                    _buildIncomeVsExpensesChart(context, dataService),
                                    const SizedBox(height: 24),
                                    _buildChartsSection(context, dataService),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 2,
                                child: Align(
                                  alignment: Alignment.topLeft,
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 550),
                                    child: _buildDebitVsCreditChart(context, dataService),
                                  ),
                                ),
                              ),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              _buildIncomeVsExpensesChart(context, dataService),
                              const SizedBox(height: 24),
                              _buildChartsSection(context, dataService),
                              const SizedBox(height: 24),
                              _buildDebitVsCreditChart(context, dataService),
                            ],
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthSelector(BuildContext context, DataService service) {
    final months = _getAvailableMonths();
    final formattedSelected = DateFormat('MMMM yyyy').format(_selectedMonth);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
      ),
      child: PopupMenuButton<DateTime>(
        initialValue: _selectedMonth,
        tooltip: 'Change month',
        onSelected: (date) => _onMonthChanged(date, service),
        color: theme.colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.5)),
        ),
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
                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                ),
              ),
            );
          }).toList();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                formattedSelected,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_drop_down,
                size: 16,
                color: theme.colorScheme.primary,
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

    // Ensure selected category index is within bounds
    if (sortedEntries.isEmpty) {
      _selectedCategoryIndex = -1;
    } else if (_selectedCategoryIndex < 0 || _selectedCategoryIndex >= sortedEntries.length) {
      _selectedCategoryIndex = 0;
    }

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
    for (int i = 0; i < sortedEntries.length; i++) {
      final entry = sortedEntries[i];
      final cat = entry.key;
      final sum = entry.value;
      final color = categoryColors[cat.id.isNotEmpty ? cat.id : cat.name] ?? parseColor(cat.colorHex);
      final isSelected = i == _selectedCategoryIndex;
      
      chartSections.add(
        PieChartSectionData(
          color: color,
          value: sum,
          title: '', 
          radius: isSelected ? 24.0 : 16.0, 
          showTitle: false,
        ),
      );
    }

    final theme = Theme.of(context);

    // Build selected category details banner
    Widget? selectedCategoryDetails;
    if (sortedEntries.isNotEmpty && _selectedCategoryIndex >= 0 && _selectedCategoryIndex < sortedEntries.length) {
      final entry = sortedEntries[_selectedCategoryIndex];
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

      selectedCategoryDetails = AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 6,
          children: [
            Icon(iconData, color: color, size: 18),
            Text(
              cat.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
                fontSize: 13,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                service.formatCurrency(sum),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${percent.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  isOverBudget ? Icons.arrow_upward : Icons.arrow_downward,
                  color: isOverBudget ? theme.colorScheme.error : AppTheme.successGreen,
                  size: 13,
                ),
              ],
            ),
          ],
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
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Excludes internal transfers (Rule 2.4)',
                        style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
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
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40.0),
                  child: Text(
                    'No expense transactions recorded for this month.',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              )
            else ...[
              // Donut Chart + Legend Row
              Builder(
                builder: (context) {
                  final isMobile = MediaQuery.of(context).size.width < 600;
                  
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
                            pieTouchData: PieTouchData(
                              touchCallback: (FlTouchEvent event, pieTouchResponse) {
                                if (event is FlTapDownEvent || event is FlTapUpEvent) {
                                  if (pieTouchResponse != null &&
                                      pieTouchResponse.touchedSection != null) {
                                    final touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                                    if (touchedIndex >= 0 && touchedIndex < sortedEntries.length) {
                                      setState(() {
                                        _selectedCategoryIndex = touchedIndex;
                                      });
                                    }
                                  }
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            service.formatCurrency(totalOutflow),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Total Outflow',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );

                  final legendList = Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: List.generate(sortedEntries.length, (index) {
                      final entry = sortedEntries[index];
                      final cat = entry.key;
                      final color = categoryColors[cat.id.isNotEmpty ? cat.id : cat.name] ?? parseColor(cat.colorHex);
                      final isSelected = index == _selectedCategoryIndex;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedCategoryIndex = index;
                          });
                        },
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected 
                                  ? color.withOpacity(0.15) 
                                  : theme.colorScheme.surfaceContainerHigh.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(
                                color: isSelected ? color : theme.colorScheme.outline.withOpacity(0.3),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  cat.name,
                                  style: TextStyle(
                                    color: isSelected ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  );

                  if (isMobile) {
                    return Column(
                      children: [
                        Center(child: donutChart),
                        const SizedBox(height: 24),
                        Center(child: legendList),
                        if (selectedCategoryDetails != null) ...[
                          const SizedBox(height: 20),
                          selectedCategoryDetails,
                        ],
                      ],
                    );
                  }

                  // NOTE: Do NOT wrap this Row in a ConstrainedBox (like maxWidth: 480).
                  // Allowing the legend Column to occupy the full remaining width of the card
                  // enables legend chips to wrap across multiple columns, drastically reducing
                  // card height and eliminating empty margins on both sides of the donut chart.
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      donutChart,
                      const SizedBox(width: 32),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            legendList,
                            if (selectedCategoryDetails != null) ...[
                              const SizedBox(height: 16),
                              selectedCategoryDetails,
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        ),
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
    final theme = Theme.of(context);

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
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Cumulative comparison for ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
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
                _buildLegendItem(context, 'Income', theme.colorScheme.primary),
                const SizedBox(width: 16),
                _buildLegendItem(context, 'Expenses', theme.colorScheme.error),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: MediaQuery.of(context).size.width >= 1000 ? 300 : 220,
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
                      return FlLine(
                        color: theme.colorScheme.outline.withOpacity(0.08),
                        strokeWidth: 1,
                      );
                    },
                    getDrawingVerticalLine: (value) {
                      return FlLine(
                        color: theme.colorScheme.outline.withOpacity(0.08),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: theme.colorScheme.outline.withOpacity(0.12)),
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
                              child: Text('$dayVal', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10)),
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
                      getTooltipColor: (_) => theme.colorScheme.surfaceContainerHigh,
                      tooltipBorder: BorderSide(color: theme.colorScheme.outline.withOpacity(0.5)),
                      getTooltipItems: (touchedSpots) {
                        // NOTE: Custom formatted tooltip as requested: "[Month] [Day]:\n Income: $####\n Expense: $####".
                        // Do not change this structure back to default as it is a specific user requirement.
                        if (touchedSpots.isEmpty) return [];

                        // Sort touchedSpots by barIndex so that income (0) is always first
                        final sortedSpots = List<LineBarSpot>.from(touchedSpots)
                          ..sort((a, b) => a.barIndex.compareTo(b.barIndex));

                        final firstSpot = sortedSpots.first;
                        final dayVal = firstSpot.x.toInt();
                        final date = DateTime(_selectedMonth.year, _selectedMonth.month, dayVal);
                        final dateStr = DateFormat('MMMM d').format(date);

                        LineBarSpot? incomeSpot;
                        LineBarSpot? expenseSpot;
                        for (var spot in sortedSpots) {
                          if (spot.barIndex == 0) {
                            incomeSpot = spot;
                          } else if (spot.barIndex == 1) {
                            expenseSpot = spot;
                          }
                        }

                        final List<LineTooltipItem> items = [];

                        if (incomeSpot != null) {
                          items.add(LineTooltipItem(
                            '$dateStr:\n',
                            TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            children: [
                              TextSpan(
                                text: ' Income: ${service.formatCurrency(incomeSpot.y)}',
                                style: TextStyle(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ));
                        }

                        if (expenseSpot != null) {
                          if (incomeSpot == null) {
                            items.add(LineTooltipItem(
                              '$dateStr:\n',
                              TextStyle(
                                color: theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                              children: [
                                TextSpan(
                                  text: ' Expense: ${service.formatCurrency(expenseSpot.y)}',
                                  style: TextStyle(
                                    color: theme.colorScheme.error,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ));
                          } else {
                            items.add(LineTooltipItem(
                              ' Expense: ${service.formatCurrency(expenseSpot.y)}',
                              TextStyle(
                                color: theme.colorScheme.error,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ));
                          }
                        }

                        return items;
                      },
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: incomeSpots,
                      isCurved: true,
                      color: theme.colorScheme.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: theme.colorScheme.primary.withOpacity(0.08),
                      ),
                    ),
                    LineChartBarData(
                      spots: expenseSpots,
                      isCurved: true,
                      color: theme.colorScheme.error,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: theme.colorScheme.error.withOpacity(0.08),
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
                    Text('Total Income', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      service.formatCurrency(totalIncome),
                      style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text('Total Expenses', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      service.formatCurrency(totalExpenses),
                      style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text('Net Cash Flow', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      service.formatCurrency(totalIncome - totalExpenses),
                      style: TextStyle(
                        color: (totalIncome - totalExpenses) >= 0 ? AppTheme.successGreen : theme.colorScheme.error,
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

  Widget _buildLegendItem(BuildContext context, String title, Color color) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: theme.colorScheme.onSurfaceVariant,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // NOTE: This chart compares active Checking type accounts vs Credit Card type accounts.
  // The toggle "Include Holding" controls inclusion/exclusion of the specific checking
  // account named "Holding" (ID: UPar7rbvISPWw6dlYIlJ). Do not refactor this back to general holdings.
  Widget _buildDebitVsCreditChart(BuildContext context, DataService service) {
    double checkingSum = 0.0;
    double creditSum = 0.0;

    for (var account in service.accounts) {
      if (account.status != 'active') continue;

      double valInDisplay = service.convertToDisplay(account.currentBalance, account.currency);
      final typeLower = account.type.toLowerCase();
      final nameLower = account.name.toLowerCase().trim();

      // Explicitly match the Holding account first by ID/name variations to handle database schema differences.
      final isHolding = account.id.trim() == 'UPar7rbvISPWw6dlYIlJ' || 
                        nameLower == 'holding' || 
                        nameLower == 'holdings' ||
                        nameLower.contains('holding');

      if (isHolding) {
        if (_addHoldingsToDebit) {
          checkingSum += valInDisplay;
        }
      } else if (typeLower == 'checking') {
        checkingSum += valInDisplay;
      } else if (typeLower == 'credit_card') {
        creditSum += valInDisplay.abs();
      }
    }

    final double checkingVal = checkingSum;
    final double creditVal = creditSum;

    double maxVal = checkingVal > creditVal ? checkingVal : creditVal;
    double maxYValue = maxVal > 0 ? maxVal * 1.15 : 1000.0;
    final theme = Theme.of(context);

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
                        'Checking vs Credit Cards',
                        style: theme.textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Comparison of active checking accounts vs credit card liabilities',
                        style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Include Holding',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: _addHoldingsToDebit,
                      onChanged: (val) {
                        setState(() {
                          _addHoldingsToDebit = val;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxYValue,
                  minY: 0,
                  barTouchData: BarTouchData(
                    enabled: false,
                    handleBuiltInTouches: false,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Colors.transparent,
                      tooltipPadding: EdgeInsets.zero,
                      tooltipMargin: 8,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        return BarTooltipItem(
                          service.formatCurrency(rod.toY),
                          TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final style = TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          );
                          Widget text;
                          if (value.toInt() == 0) {
                            text = Text(_addHoldingsToDebit ? 'Checking + Holding' : 'Checking', style: style);
                          } else if (value.toInt() == 1) {
                            text = Text('Credit Cards', style: style);
                          } else {
                            text = Text('', style: style);
                          }
                          return SideTitleWidget(
                            meta: meta,
                            space: 8,
                            child: text,
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxYValue / 5 > 0 ? maxYValue / 5 : 200,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: theme.colorScheme.outline.withOpacity(0.08),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    BarChartGroupData(
                      x: 0,
                      showingTooltipIndicators: const [0],
                      barRods: [
                        BarChartRodData(
                          toY: checkingVal,
                          color: AppTheme.successGreen,
                          width: 48,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 1,
                      showingTooltipIndicators: const [0],
                      barRods: [
                        BarChartRodData(
                          toY: creditVal,
                          color: theme.colorScheme.error,
                          width: 48,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


}
