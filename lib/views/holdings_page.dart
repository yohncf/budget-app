import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/data_service.dart';
import '../models/holding.dart';
import '../models/account.dart';
import '../models/asset_transaction.dart';
import '../models/asset.dart';
import '../core/theme.dart';

class HoldingsPage extends StatefulWidget {
  const HoldingsPage({super.key});

  @override
  State<HoldingsPage> createState() => _HoldingsPageState();
}

class _HoldingsPageState extends State<HoldingsPage> {
  final _uuid = const Uuid();

  // Transaction form controllers
  final _symbolController = TextEditingController();
  final _nameController = TextEditingController();
  final _qtyController = TextEditingController();
  final _priceController = TextEditingController();
  
  Account? _selectedAccount;
  String _selectedAssetType = 'stock'; // stock, crypto, etf
  String _selectedTxType = 'buy'; // buy, sell, dividend_reinvest, split, reward
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<DataService>(context, listen: false).setDisplayCurrency('USD');
      }
    });
  }

  @override
  void dispose() {
    _symbolController.dispose();
    _nameController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
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
    
    // Group active holdings (quantity > 0) by asset type
    final activeHoldings = dataService.holdings.where((h) => h.quantity > 0.0).toList();
    
    final Map<String, List<Holding>> groupedHoldings = {
      'stock': [],
      'crypto': [],
      'etf': [],
      'other': [],
    };

    for (var h in activeHoldings) {
      // Look up asset in service.assets
      final asset = dataService.assets.firstWhere(
        (a) => a.id == h.assetId,
        orElse: () => Asset(
          id: h.assetId,
          symbol: h.assetSymbol ?? h.assetId,
          name: h.assetName ?? 'Unknown Asset',
          type: 'stock',
        ),
      );

      final inferredType = asset.type.toLowerCase();
      final targetGroup = groupedHoldings.containsKey(inferredType) ? inferredType : 'other';
      groupedHoldings[targetGroup]!.add(h);
    }

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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
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
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentCyan,
                        foregroundColor: Colors.black,
                        padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: isMobile ? 10 : 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.add_chart),
                      label: Text(isMobile ? 'New' : 'New Transaction'),
                      onPressed: () => _showAddTransactionDialog(context, dataService),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Graph Card and Net Worth side by side on desktop, stacked on mobile
                !isDesktop
                    ? Column(
                        children: [
                          _buildNetWorthCard(context, dataService),
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
                            child: _buildNetWorthCard(context, dataService),
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
                _buildHoldingsSection(context, groupedHoldings, dataService),
              ],
            ),
          ),
        ),
      ),
    );
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

    final firstDate = history.first['date'] as DateTime;
    final List<FlSpot> spots = [];
    
    for (int i = 0; i < history.length; i++) {
      final date = history[i]['date'] as DateTime;
      final value = history[i]['value'] as double;
      final days = date.difference(firstDate).inDays.toDouble();
      spots.add(FlSpot(days, value));
    }

    // Determine boundaries
    double minX = 0.0;
    double maxX = history.last['date'].difference(firstDate).inDays.toDouble();
    if (maxX == 0.0) maxX = 1.0; // Avoid division by zero

    double minY = history.map((e) => e['value'] as double).reduce((a, b) => a < b ? a : b);
    double maxY = history.map((e) => e['value'] as double).reduce((a, b) => a > b ? a : b);
    
    // Add margins to Y axis
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
            const SizedBox(height: 24),
            SizedBox(
              height: 220,
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
                            service.formatCurrency(value),
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
                      isCurved: true,
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
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.mainAction.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'NET WORTH',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              service.formatCurrencyWith(service.calculateNetWorthIn('USD'), 'USD'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '≈ ${service.formatCurrencyWith(service.calculateNetWorthIn('MXN'), 'MXN')} MXN',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.trending_up, color: Colors.white.withOpacity(0.9), size: 14),
                const SizedBox(width: 6),
                Text(
                  '+12.4% this month',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHoldingsSection(BuildContext context, Map<String, List<Holding>> groups, DataService service) {
    final list = <Widget>[];

    groups.forEach((type, holdings) {
      if (holdings.isEmpty) return;

      final label = type == 'stock' 
          ? 'Stocks' 
          : type == 'crypto' 
              ? 'Crypto' 
              : type == 'etf' 
                  ? 'ETFs' 
                  : 'Other Assets';

      final Color typeColor = type == 'crypto' 
          ? const Color(0xFFF59E0B) 
          : type == 'etf' 
              ? AppTheme.mainAction 
              : AppTheme.accentCyan;

      // Calculate category sum using current value
      double categoryTotal = 0.0;
      for (var h in holdings) {
        final acc = service.accounts.firstWhere((a) => a.id == h.accountId, orElse: () => Account(id: '', name: '', type: 'checking', currency: 'USD', createdAt: DateTime.now(), updatedAt: DateTime.now()));
        final currentPrice = service.getHoldingCurrentPrice(h, acc);
        final holdingValInDisplay = service.convertToDisplay(h.quantity * currentPrice, acc.currency);
        categoryTotal += holdingValInDisplay;
      }

      list.add(
        Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            initiallyExpanded: true,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: typeColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Text(
                  service.formatCurrency(categoryTotal),
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: typeColor),
                ),
              ],
            ),
             childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: holdings.map((h) {
              final acc = service.accounts.firstWhere((a) => a.id == h.accountId, orElse: () => Account(id: '', name: '', type: 'checking', currency: 'USD', createdAt: DateTime.now(), updatedAt: DateTime.now()));
              final currentPrice = service.getHoldingCurrentPrice(h, acc);
              final displayPrice = service.convertToDisplay(h.avgBuyPrice, acc.currency);
              final displayCurrentPrice = service.convertToDisplay(currentPrice, acc.currency);
              final holdingValInDisplay = service.convertToDisplay(h.quantity * currentPrice, acc.currency);

              final totalCost = h.quantity * h.avgBuyPrice;
              final currentValue = h.quantity * currentPrice;
              final gainLoss = currentValue - totalCost;
              final displayGainLoss = service.convertToDisplay(gainLoss, acc.currency);
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${asset.name} (${asset.symbol})',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Qty: ${h.quantity.toStringAsFixed(4)}  •  Avg: ${service.formatCurrency(displayPrice)}  •  Cur: ${service.formatCurrency(displayCurrentPrice)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Held in: ${acc.name}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          service.formatCurrency(holdingValInDisplay),
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
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
            }).toList(),
          ),
        ),
      );
    });

    // Query active accounts to add PPR, Savings Fund, and Afore to the bottom of the asset allocation
    final List<String> targetNames = ['ppr', 'savings fund', 'afore', 'fondo de ahorro'];
    final List<Account> matchedAccounts = [];
    
    for (var acc in service.accounts) {
      if (acc.status != 'active') continue;
      final nameLower = acc.name.toLowerCase();
      if (targetNames.any((target) => nameLower.contains(target))) {
        matchedAccounts.add(acc);
      }
    }

    // Sort priority: PPR -> Savings Fund -> Afore
    matchedAccounts.sort((a, b) {
      int getPriority(String name) {
        final n = name.toLowerCase();
        if (n.contains('ppr')) return 1;
        if (n.contains('savings fund') || n.contains('fondo de ahorro')) return 2;
        if (n.contains('afore')) return 3;
        return 4;
      }
      return getPriority(a.name).compareTo(getPriority(b.name));
    });

    for (var account in matchedAccounts) {
      final accountHoldings = service.holdings.where((h) => h.accountId == account.id && h.quantity > 0.0).toList();
      double holdingsVal = accountHoldings.fold(0.0, (sum, item) => sum + service.convertToDisplay(item.quantity * service.getHoldingCurrentPrice(item, account), account.currency));
      double totalDisplayVal = service.convertToDisplay(account.currentBalance, account.currency) + holdingsVal;

      final nameLower = account.name.toLowerCase();
      Color accountColor = AppTheme.mainAction;
      if (nameLower.contains('ppr')) {
        accountColor = const Color(0xFF8B5CF6); // Purple
      } else if (nameLower.contains('savings fund') || nameLower.contains('fondo de ahorro')) {
        accountColor = AppTheme.successGreen; // Green
      } else if (nameLower.contains('afore')) {
        accountColor = const Color(0xFFF59E0B); // Orange
      }

      list.add(
        Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            initiallyExpanded: false,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: accountColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      account.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Text(
                  service.formatCurrency(totalDisplayVal),
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: accountColor),
                ),
              ],
            ),
            childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              if (account.currentBalance != 0.0)
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
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
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
                        style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${asset.name} (${asset.symbol})',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Qty: ${h.quantity.toStringAsFixed(4)}  •  Avg: ${service.formatCurrency(displayPrice)}  •  Cur: ${service.formatCurrency(displayCurrentPrice)}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            service.formatCurrency(holdingValInDisplay),
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
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
              if (account.currentBalance == 0.0 && accountHoldings.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Center(
                    child: Text('No cash balance or holdings recorded.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
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
          child: Text('No active investment holdings in portfolio.', style: TextStyle(color: AppTheme.textSecondary)),
        ),
      );
    }

    return Column(children: list);
  }

  void _showAddTransactionDialog(BuildContext context, DataService service) {
    // Reset inputs
    _symbolController.clear();
    _nameController.clear();
    _qtyController.clear();
    _priceController.clear();
    
    // Choose initial account if available
    final brokerages = service.accounts.where((a) => a.status == 'active' && (a.type == 'investment' || a.type == 'retirement' || a.type == 'crypto_wallet')).toList();
    _selectedAccount = brokerages.isNotEmpty ? brokerages.first : (service.accounts.isNotEmpty ? service.accounts.first : null);
    _selectedAssetType = 'stock';
    _selectedTxType = 'buy';
    _selectedDate = DateTime.now();

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
                  const Icon(Icons.add_chart, color: AppTheme.accentCyan),
                  const SizedBox(width: 8),
                  const Text('Log Asset Transaction'),
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
                      DropdownButtonFormField<Account>(
                        value: _selectedAccount,
                        decoration: const InputDecoration(labelText: 'Destination Account'),
                        items: service.accounts.where((a) => a.status == 'active').map((a) {
                          return DropdownMenuItem<Account>(
                            value: a,
                            child: Text('${a.name} (${a.currency})'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() {
                            _selectedAccount = val;
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      // Asset details
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _symbolController,
                              textCapitalization: TextCapitalization.characters,
                              decoration: const InputDecoration(labelText: 'Symbol', hintText: 'e.g. AAPL'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _selectedAssetType,
                              decoration: const InputDecoration(labelText: 'Asset Type'),
                              items: const [
                                DropdownMenuItem(value: 'stock', child: Text('Stock')),
                                DropdownMenuItem(value: 'crypto', child: Text('Crypto')),
                                DropdownMenuItem(value: 'etf', child: Text('ETF')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() {
                                    _selectedAssetType = val;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Asset Name', hintText: 'e.g. Apple Inc.'),
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
                            setDialogState(() {
                              _selectedTxType = val;
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
                                setDialogState(() {
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

                    final assetTxId = _uuid.v4().substring(0, 20);
                    final newAssetTx = AssetTransaction(
                      id: assetTxId,
                      accountId: _selectedAccount!.id,
                      assetId: symbol, // Using symbol as simple assetId
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
          },
        );
      },
    );
  }
}
