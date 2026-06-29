import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/data_service.dart';
import '../models/holding.dart';
import '../models/account.dart';
import '../models/asset_transaction.dart';
import '../models/asset.dart';
import '../models/transaction.dart';
import '../core/theme.dart';

class HoldingsPage extends StatefulWidget {
  const HoldingsPage({super.key});

  @override
  State<HoldingsPage> createState() => _HoldingsPageState();
}

class _HoldingsPageState extends State<HoldingsPage> {
  final _uuid = const Uuid();

  int _selectedGroupIndex = -1;

  // Selected time period filter for Portfolio Valuation Trend chart
  String _selectedPeriod = 'all';

  @override
  void initState() {
    super.initState();
    // Load the last selected period filter from persistent storage
    _loadSelectedPeriod();
  }

  // Load selected period from SharedPreferences
  Future<void> _loadSelectedPeriod() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPeriod = prefs.getString('holdings_selected_period');
      if (savedPeriod != null && mounted) {
        setState(() {
          _selectedPeriod = savedPeriod;
        });
      }
    } catch (e) {
      debugPrint('Error loading saved period: $e');
    }
  }

  // Save selected period to SharedPreferences to persist choice across sessions
  Future<void> _saveSelectedPeriod(String period) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('holdings_selected_period', period);
    } catch (e) {
      debugPrint('Error saving selected period: $e');
    }
  }

  // Helper method to compute dynamic cutoff date for historical range slicing
  DateTime _getCutoffDate(String period) {
    final now = DateTime.now();
    // Normalize to the start of today to make date comparisons cleaner
    final today = DateTime(now.year, now.month, now.day);
    switch (period) {
      case '1M':
        return DateTime(today.year, today.month - 1, today.day);
      case '3M':
        return DateTime(today.year, today.month - 3, today.day);
      case '6M':
        return DateTime(today.year, today.month - 6, today.day);
      case '1Y':
        return DateTime(today.year - 1, today.month, today.day);
      case '5Y':
        return DateTime(today.year - 5, today.month, today.day);
      case 'all':
      default:
        // Set date to a far past value to include the whole timeline
        return DateTime(1900);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  // Generate historical portfolio valuation points day-by-day
  List<Map<String, dynamic>> _calculateHistoricalValuation(DataService service) {
    final txs = List<AssetTransaction>.from(service.assetTransactions);
    // Sort chronologically
    txs.sort((a, b) => a.executedAt.compareTo(b.executedAt));

    if (txs.isEmpty) return [];

    final List<Map<String, dynamic>> dataPoints = [];

    // Group transactions by date for quick lookup
    final Map<String, List<AssetTransaction>> txsByDate = {};
    for (var tx in txs) {
      final dateKey = '${tx.executedAt.year}-${tx.executedAt.month}-${tx.executedAt.day}';
      txsByDate.putIfAbsent(dateKey, () => []).add(tx);
    }

    final firstTxDate = txs.first.executedAt;
    final startDate = DateTime(firstTxDate.year, firstTxDate.month, firstTxDate.day);
    
    final now = DateTime.now();
    var endDate = DateTime(now.year, now.month, now.day);
    if (endDate.isBefore(startDate)) {
      endDate = startDate;
    }

    double cumulativeValue = 0.0;
    DateTime currentDay = startDate;
    int safetyCounter = 0;
    while (!currentDay.isAfter(endDate) && safetyCounter < 3650) {
      safetyCounter++;
      final dateKey = '${currentDay.year}-${currentDay.month}-${currentDay.day}';

      if (txsByDate.containsKey(dateKey)) {
        for (var tx in txsByDate[dateKey]!) {
          if (tx.type.toLowerCase() == 'split') {
            // Split doesn't alter the value of the portfolio at that moment
            continue;
          }

          final account = service.accounts.firstWhere(
            (a) => a.id == tx.accountId,
            orElse: () => Account(
              id: '',
              name: '',
              type: 'checking',
              currency: 'USD',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

          final txValue = tx.quantity * tx.unitPrice;
          final txValueInDisplay = service.convertToDisplay(txValue, account.currency);

          if (tx.type.toLowerCase() == 'sell') {
            cumulativeValue -= txValueInDisplay;
          } else {
            // buy, dividend_reinvest, reward
            cumulativeValue += txValueInDisplay;
          }
        }
      }

      dataPoints.add({
        'date': currentDay,
        'value': cumulativeValue,
      });

      currentDay = DateTime(currentDay.year, currentDay.month, currentDay.day + 1);
    }

    return dataPoints;
  }

  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<DataService>(context);
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12.0 : 24.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                // CUSTOMIZATION PREFERENCE: Removed page-specific add button. Add transactions using the global FAB menu.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Holdings & Investments',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: isMobile ? 24 : 28),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Track stocks, ETFs, crypto, and asset valuation logs',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Graph Card, Net Worth, and Portfolio Distribution side by side on desktop, stacked on mobile
                // CUSTOMIZATION PREFERENCE: Use IntrinsicHeight on desktop to align the Portfolio Distribution card height exactly with the Y-axis bottom of the trend graph card.
                !isDesktop
                    ? Column(
                        children: [
                          _buildNetWorthCard(context, dataService),
                          const SizedBox(height: 16),
                          _buildAccountGroupPieChart(context, dataService),
                          const SizedBox(height: 24),
                          _buildValuationGraphCard(context, dataService),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: _buildValuationGraphCard(context, dataService),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 2,
                            child: Column(
                              children: [
                                _buildNetWorthCard(context, dataService),
                                const SizedBox(height: 24),
                                _buildAccountGroupPieChart(context, dataService, isExpanded: true),
                              ],
                            ),
                          ),
                        ],
                      ),
                const SizedBox(height: 24),

                // Holdings Group Lists
                Text(
                  'Asset Allocation',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                _buildHoldingsSection(context, dataService),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Build a horizontal row of filter chips for timeline period selection
  Widget _buildPeriodChips() {
    final periods = ['1M', '3M', '6M', '1Y', '5Y', 'all'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: periods.map((period) {
          final isSelected = _selectedPeriod == period;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedPeriod = period;
                  _saveSelectedPeriod(period);
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  // Use transparent for unselected, subtle accent cyan overlay for selected state
                  color: isSelected
                      ? AppTheme.accentCyan.withOpacity(0.12)
                      : const Color(0xFF1D1D22),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? AppTheme.accentCyan : const Color(0xFF222226),
                    width: 1,
                  ),
                ),
                child: Text(
                  period,
                  style: TextStyle(
                    color: isSelected ? AppTheme.accentCyan : AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // CUSTOMIZATION PREFERENCE: Format vertical axis values using a clean, compact format to avoid long strings of zeros.
  String _formatCompactValue(double value, DataService service) {
    final absVal = value.abs();
    String sign = value < 0 ? '-' : '';
    String symbol = '\$';
    if (service.displayCurrency == 'MXN') {
      symbol = '\$';
    } else if (service.displayCurrency == 'SOL' || service.displayCurrency == 'PEN') {
      symbol = 'S/.';
    } else if (service.displayCurrency == 'EUR') {
      symbol = '€';
    }
    
    if (absVal >= 1000000.0) {
      return '$sign$symbol${(absVal / 1000000.0).toStringAsFixed(1)}M';
    } else if (absVal >= 1000.0) {
      return '$sign$symbol${(absVal / 1000.0).toStringAsFixed(1)}K';
    } else {
      return '$sign$symbol${absVal.toStringAsFixed(0)}';
    }
  }

  Widget _buildValuationGraphCard(BuildContext context, DataService service) {
    final history = _calculateHistoricalValuation(service);
    
    if (history.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.show_chart, size: 48, color: AppTheme.textSecondary),
                const SizedBox(height: 16),
                Text(
                  'No investment history recorded.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Record new buy/sell transactions to track valuation growth.',
                  style: TextStyle(color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Filter historical points by the active period filter key (e.g. '1M', '3M', etc.)
    final cutoffDate = _getCutoffDate(_selectedPeriod);
    final filteredHistory = history.where((point) {
      final date = point['date'] as DateTime;
      return !date.isBefore(cutoffDate);
    }).toList();

    // Fall back to entire history if the filtered result is empty to avoid rendering crash
    final displayHistory = filteredHistory.isNotEmpty ? filteredHistory : history;

    // Use the first point in our filtered range as the coordinate origin (minX = 0.0)
    final firstDate = displayHistory.first['date'] as DateTime;
    final List<FlSpot> spots = [];
    
    for (int i = 0; i < displayHistory.length; i++) {
      final date = displayHistory[i]['date'] as DateTime;
      final value = displayHistory[i]['value'] as double;
      final days = date.difference(firstDate).inDays.toDouble();
      spots.add(FlSpot(days, value));
    }

    // Determine boundaries based on filtered timeline range
    double minX = 0.0;
    double maxX = displayHistory.last['date'].difference(firstDate).inDays.toDouble();
    if (maxX == 0.0) maxX = 1.0; // Avoid division by zero

    double minY = displayHistory.map((e) => e['value'] as double).reduce((a, b) => a < b ? a : b);
    double maxY = displayHistory.map((e) => e['value'] as double).reduce((a, b) => a > b ? a : b);
    
    // Add margins to Y axis for better visual breathing room
    final yMargin = (maxY - minY) * 0.15;
    minY = (minY - yMargin).clamp(0.0, double.infinity);
    maxY = maxY + (yMargin == 0.0 ? 1000.0 : yMargin);

    return Card(
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Portfolio Valuation Trend',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Cumulative net worth of investments in ${service.displayCurrency}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            _buildPeriodChips(),
            const SizedBox(height: 20),
            SizedBox(
              height: 300,
              child: LineChart(
                LineChartData(
                  minX: minX,
                  maxX: maxX,
                  minY: minY,
                  maxY: maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => const FlLine(
                      color: Color(0xFF1E1E24),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 55,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            _formatCompactValue(value, service),
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        interval: (maxX - minX) / 4 > 0 ? (maxX - minX) / 4 : 1.0,
                        getTitlesWidget: (value, meta) {
                          if (value < minX || value > maxX) return const SizedBox();
                          final date = firstDate.add(Duration(days: value.toInt()));
                          return Text(
                            DateFormat('MMM dd').format(date),
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 9),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => AppTheme.darkCard,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final date = firstDate.add(Duration(days: spot.x.toInt()));
                          final formattedDate = DateFormat('MMM dd, yyyy').format(date);
                          return LineTooltipItem(
                            '$formattedDate\n${service.formatCurrency(spot.y)}',
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: false,
                      color: AppTheme.accentCyan,
                      barWidth: 3.5,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: spots.length < 30),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.accentCyan.withOpacity(0.25),
                            AppTheme.accentCyan.withOpacity(0.0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
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
  }

  Widget _buildNetWorthCard(BuildContext context, DataService service) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'NET WORTH',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    service.formatCurrencyWith(service.calculateNetWorthIn('USD'), 'USD'),
                    style: const TextStyle(
                      color: AppTheme.mainAction,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '≈ ${service.formatCurrencyWith(service.calculateNetWorthIn('MXN'), 'MXN')} MXN',
                    style: TextStyle(
                      color: AppTheme.mainAction.withOpacity(0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.successGreen.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.trending_up, color: AppTheme.successGreen, size: 14),
                  SizedBox(width: 4),
                  Text(
                    '+12.4%',
                    style: TextStyle(
                      color: AppTheme.successGreen,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Map<String, double> _calculateAccountGroupDistribution(DataService service) {
    final Map<String, double> groupTotals = {};
    final Set<String> processedAccountIds = {};

    void addAccountValue(Account account, double value) {
      if (processedAccountIds.contains(account.id)) return;
      processedAccountIds.add(account.id);

      // Exclude credit cards and checking/debit accounts from holdings/investment net worth/pie chart
      if (account.type == 'credit_card' || account.type == 'checking') {
        return;
      }
      if (account.accountGroup == 'credit' || account.accountGroup == 'liquid_assets') {
        return;
      }

      String group = account.accountGroup ?? 'capital';
      if (group.isEmpty) {
        if (account.type == 'retirement') {
          group = 'retirement';
        } else {
          group = 'capital';
        }
      }
      
      String displayGroup = group;
      if (group == 'capital') {
        displayGroup = 'Capital';
      } else if (group == 'retirement') {
        displayGroup = 'Retirement';
      } else if (group == 'liquid_assets') {
        displayGroup = 'Liquid Assets';
      } else if (group == 'credit') {
        displayGroup = 'Credit';
      } else {
        displayGroup = group[0].toUpperCase() + group.substring(1);
      }

      groupTotals[displayGroup] = (groupTotals[displayGroup] ?? 0.0) + value;
    }

    // 1. Accounts with active holdings
    final activeHoldings = service.holdings.where((h) => h.quantity > 0.0).toList();
    for (var h in activeHoldings) {
      final account = service.accounts.firstWhere(
        (a) => a.id == h.accountId,
        orElse: () => Account(
          id: '',
          name: '',
          type: 'checking',
          currency: 'USD',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      if (account.id.isEmpty || account.status != 'active') continue;

      if (!processedAccountIds.contains(account.id)) {
        final accountHoldings = service.holdings.where((sh) => sh.accountId == account.id && sh.quantity > 0.0).toList();
        double holdingsVal = accountHoldings.fold(0.0, (sum, item) {
          final currentPrice = service.getHoldingCurrentPrice(item, account);
          return sum + service.convertToDisplay(item.quantity * currentPrice, account.currency);
        });
        // CUSTOMIZATION PREFERENCE: Prevent double counting for capital accounts which already track cash as a CASH asset holding
        double totalVal = account.accountGroup == 'capital' 
            ? holdingsVal 
            : service.convertToDisplay(account.currentBalance, account.currency) + holdingsVal;
        addAccountValue(account, totalVal);
      }
    }

    // 2. Matched accounts (PPR, Afore, etc.)
    final List<String> targetNames = ['ppr', 'savings fund', 'afore', 'fondo de ahorro'];
    for (var account in service.accounts) {
      if (account.status != 'active') continue;
      final nameLower = account.name.toLowerCase();
      if (targetNames.any((target) => nameLower.contains(target))) {
        if (!processedAccountIds.contains(account.id)) {
          final accountHoldings = service.holdings.where((sh) => sh.accountId == account.id && sh.quantity > 0.0).toList();
          double holdingsVal = accountHoldings.fold(0.0, (sum, item) {
            final currentPrice = service.getHoldingCurrentPrice(item, account);
            return sum + service.convertToDisplay(item.quantity * currentPrice, account.currency);
          });
          // CUSTOMIZATION PREFERENCE: Prevent double counting for capital accounts which already track cash as a CASH asset holding
          double totalVal = account.accountGroup == 'capital'
              ? holdingsVal
              : service.convertToDisplay(account.currentBalance, account.currency) + holdingsVal;
          addAccountValue(account, totalVal);
        }
      }
    }

    return groupTotals;
  }

  Widget _buildAccountGroupPieChart(BuildContext context, DataService service, {bool isExpanded = false}) {
    final distribution = _calculateAccountGroupDistribution(service);
    if (distribution.isEmpty) {
      return const SizedBox.shrink();
    }

    double totalValue = distribution.values.fold(0.0, (sum, val) => sum + val);

    final sortedEntries = distribution.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Ensure selection index is within bounds
    if (sortedEntries.isEmpty) {
      _selectedGroupIndex = -1;
    } else if (_selectedGroupIndex >= sortedEntries.length) {
      _selectedGroupIndex = -1;
    }

    final List<Color> groupColors = [
      AppTheme.accentCyan,
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFF59E0B), // Amber
      const Color(0xFF10B981), // Emerald
    ];

    final List<PieChartSectionData> chartSections = [];
    for (int i = 0; i < sortedEntries.length; i++) {
      final entry = sortedEntries[i];
      final sum = entry.value;
      final color = groupColors[i % groupColors.length];
      final isSelected = i == _selectedGroupIndex;
      
      chartSections.add(
        PieChartSectionData(
          color: color,
          value: sum,
          title: '', 
          radius: isSelected ? 20.0 : 14.0, 
          showTitle: false,
        ),
      );
    }

    final chartWidget = LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 280;
        
        final chartSize = isExpanded ? 180.0 : 140.0;
        final centerRadius = isExpanded ? 58.0 : 45.0;
        final textFontSize = isExpanded ? 15.0 : 14.0;
        
        final donutChart = Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              height: chartSize,
              width: chartSize,
              child: PieChart(
                PieChartData(
                  sections: chartSections,
                  sectionsSpace: 2,
                  centerSpaceRadius: centerRadius,
                  pieTouchData: PieTouchData(
                    touchCallback: (FlTouchEvent event, pieTouchResponse) {
                      if (event is FlTapDownEvent || event is FlTapUpEvent) {
                        if (pieTouchResponse != null &&
                            pieTouchResponse.touchedSection != null) {
                          final touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                          setState(() {
                            if (touchedIndex >= 0 && touchedIndex < sortedEntries.length) {
                              _selectedGroupIndex = _selectedGroupIndex == touchedIndex ? -1 : touchedIndex;
                            } else {
                              _selectedGroupIndex = -1;
                            }
                          });
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
                  service.formatCurrency(totalValue),
                  style: TextStyle(
                    fontSize: textFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Total Portfolio',
                  style: TextStyle(
                    fontSize: 9,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        );

        final legendList = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(sortedEntries.length, (index) {
            final entry = sortedEntries[index];
            final groupName = entry.key;
            final sum = entry.value;
            final percent = totalValue > 0 ? (sum / totalValue) * 100 : 0.0;
            final color = groupColors[index % groupColors.length];
            final isSelected = index == _selectedGroupIndex;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedGroupIndex = _selectedGroupIndex == index ? -1 : index;
                });
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withOpacity(0.12) : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? color.withOpacity(0.3) : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  child: Row(
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
                      Expanded(
                        child: Text(
                          groupName,
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            service.formatCurrency(sum),
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${percent.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        );

        if (isNarrow) {
          return Column(
            children: [
              Center(child: donutChart),
              const SizedBox(height: 16),
              legendList,
            ],
          );
        }

        return Row(
          children: [
            donutChart,
            const SizedBox(width: 16),
            Expanded(child: legendList),
          ],
        );
      },
    );

    return Card(
      elevation: 6,
      child: Container(
        height: isExpanded ? 348 : null,
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Portfolio Distribution',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Allocation by account group',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            isExpanded ? Expanded(child: chartWidget) : chartWidget,
          ],
        ),
      ),
    );
  }

  // CUSTOMIZATION PREFERENCE: List Capital and Retirement accounts directly, sorted by total value descending.
  // Retirement accounts manually sum their holdings and cash balance, whereas Capital accounts track cash directly as a CASH holding asset.
  Widget _buildHoldingsSection(BuildContext context, DataService service) {
    final list = <Widget>[];

    // Filter accounts: active and either capital or retirement
    final List<Account> targetAccounts = service.accounts
        .where((a) => a.status == 'active' && (a.accountGroup == 'capital' || a.accountGroup == 'retirement'))
        .toList();

    // Map to store precomputed total values for sorting
    final Map<String, double> accountValues = {};

    for (var account in targetAccounts) {
      final accountHoldings = service.holdings.where((h) => h.accountId == account.id && h.quantity > 0.0).toList();
      double holdingsVal = accountHoldings.fold(0.0, (sum, item) {
        final currentPrice = service.getHoldingCurrentPrice(item, account);
        return sum + service.convertToDisplay(item.quantity * currentPrice, account.currency);
      });
      double totalVal = account.accountGroup == 'capital'
          ? holdingsVal
          : service.convertToDisplay(account.currentBalance, account.currency) + holdingsVal;
      accountValues[account.id] = totalVal;
    }

    // Sort accounts by total value descending
    targetAccounts.sort((a, b) {
      final valA = accountValues[a.id] ?? 0.0;
      final valB = accountValues[b.id] ?? 0.0;
      return valB.compareTo(valA);
    });

    for (var account in targetAccounts) {
      final totalDisplayVal = accountValues[account.id] ?? 0.0;
      final accountHoldings = service.holdings.where((h) => h.accountId == account.id && h.quantity > 0.0).toList();

      final isCapital = account.accountGroup == 'capital';
      final groupColor = isCapital ? AppTheme.accentCyan : const Color(0xFF8B5CF6); // Cyan for Capital, Purple for Retirement
      final groupIcon = isCapital ? Icons.account_balance_wallet_outlined : Icons.savings_outlined;
      final groupLabel = isCapital ? 'Capital' : 'Retirement';

      list.add(
        Card(
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            initiallyExpanded: false,
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: groupColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(groupIcon, color: groupColor, size: 20),
            ),
            title: Text(
              account.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            subtitle: Text(
              '$groupLabel • ${account.currency.toUpperCase()}',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
              ),
            ),
            trailing: Text(
              service.formatCurrency(totalDisplayVal),
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: groupColor,
              ),
            ),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              // Show cash row for non-capital accounts (retirement accounts etc) if they have cash balance
              if (!isCapital && account.currentBalance != 0.0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cash Balance',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textSecondary,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Held in: ${account.currency}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10),
                          ),
                        ],
                      ),
                      Text(
                        service.formatAndConvert(account.currentBalance, account.currency),
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              // Map holdings/assets
              ...accountHoldings.map((h) {
                final currentPrice = service.getHoldingCurrentPrice(h, account);
                final displayPrice = service.convertToDisplay(h.avgBuyPrice, account.currency);
                final displayCurrentPrice = service.convertToDisplay(currentPrice, account.currency);
                final holdingValInDisplay = service.convertToDisplay(h.quantity * currentPrice, account.currency);

                final totalCost = h.quantity * h.avgBuyPrice;
                final currentValue = h.quantity * currentPrice;
                final gainLoss = currentValue - totalCost;
                final displayGainLoss = service.convertToDisplay(gainLoss, account.currency);
                final roiPct = totalCost > 0 ? (gainLoss / totalCost) * 100 : 0.0;

                final asset = service.assets.firstWhere(
                  (a) => a.id == h.assetId,
                  orElse: () => Asset(
                    id: h.assetId,
                    symbol: h.assetSymbol ?? h.assetId,
                    name: h.assetName ?? 'Unknown Asset',
                    type: 'stock',
                  ),
                );

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${asset.name} (${asset.symbol})',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Qty: ${h.quantity.toStringAsFixed(4)}  •  Avg: ${service.formatCurrency(displayPrice)}  •  Cur: ${service.formatCurrency(displayCurrentPrice)}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontSize: 12,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            service.formatCurrency(holdingValInDisplay),
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                displayGainLoss >= 0 ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                                color: displayGainLoss >= 0 ? AppTheme.successGreen : AppTheme.dangerRed,
                                size: 16,
                              ),
                              Text(
                                '${displayGainLoss >= 0 ? '+' : ''}${service.formatCurrency(displayGainLoss)} (${roiPct.toStringAsFixed(2)}%)',
                                style: TextStyle(
                                  color: displayGainLoss >= 0 ? AppTheme.successGreen : AppTheme.dangerRed,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
              if ((isCapital || account.currentBalance == 0.0) && accountHoldings.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Center(
                    child: Text(
                      'No assets or balance recorded.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    if (list.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40.0),
          child: Text(
            'No active capital or retirement accounts found.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    return Column(children: list);
  }
}
