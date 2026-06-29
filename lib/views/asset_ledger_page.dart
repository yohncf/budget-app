import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/data_service.dart';
import '../models/asset_transaction.dart';
import '../models/account.dart';
import '../core/theme.dart';
import '../models/asset.dart';
import 'package:intl/intl.dart';

class AssetLedgerPage extends StatefulWidget {
  const AssetLedgerPage({super.key});

  @override
  State<AssetLedgerPage> createState() => _AssetLedgerPageState();
}

class _AssetLedgerPageState extends State<AssetLedgerPage> {
  // Filter values
  String _filterType = 'All'; // All, Buy, Sell, Split, Dividend Reinvest, Reward
  String _filterAccountId = 'All'; // All, or specific Account ID
  
  // Search values
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // CUSTOMIZATION PREFERENCE: Added scroll controller and limit state for lazy loading / paging from Firebase
  final ScrollController _scrollController = ScrollController();
  int _limit = 10;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<DataService>(context, listen: false).setDisplayCurrency('USD');
      }
    });
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (_isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
      _limit += 10;
    });
    // Debounce additional scroll trigger events while stream is updated
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'buy':
        return const Color(0xFF4CAF50); // Green
      case 'sell':
        return const Color(0xFFE57373); // Red
      case 'split':
        return AppTheme.accentCyan; // Cyan
      case 'dividend_reinvest':
        return const Color(0xFF42A5F5); // Blue
      case 'reward':
        return const Color(0xFFFFD54F); // Gold/Amber
      default:
        return AppTheme.textSecondary;
    }
  }

  String _getTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'buy':
        return 'BUY';
      case 'sell':
        return 'SELL';
      case 'split':
        return 'SPLIT';
      case 'dividend_reinvest':
        return 'DIV REINVEST';
      case 'reward':
        return 'REWARD';
      default:
        return type.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dataService = Provider.of<DataService>(context);
    final dateFormatter = DateFormat('yyyy-MM-dd HH:mm');
    final isMobile = MediaQuery.of(context).size.width < 768;

    return StreamBuilder<List<AssetTransaction>>(
      // CUSTOMIZATION PREFERENCE: Fetch only _limit records at a time from Firestore to prevent high read counts
      stream: dataService.streamAssetTransactionsPaged(limit: _limit),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppTheme.accentCyan),
            ),
          );
        }

        final txsList = snapshot.data ?? [];

        // Filter and search logic based on the loaded transactions list
        final filteredTxs = txsList.where((tx) {
          // Type Filter
          if (_filterType != 'All') {
            if (tx.type.toLowerCase() != _filterType.toLowerCase()) return false;
          }
          
          // Account Filter
          if (_filterAccountId != 'All') {
            if (tx.accountId != _filterAccountId) return false;
          }

          // Search Query (symbol, name, account name)
          if (_searchQuery.isNotEmpty) {
            final query = _searchQuery.toLowerCase();
            final asset = dataService.assets.firstWhere(
              (a) => a.id == tx.assetId,
              orElse: () => Asset(
                id: tx.assetId,
                symbol: tx.assetSymbol ?? tx.assetId,
                name: tx.assetName ?? tx.assetSymbol ?? tx.assetId,
                type: 'stock',
              ),
            );
            final symbol = asset.symbol.toLowerCase();
            final name = asset.name.toLowerCase();
            
            final account = dataService.accounts.firstWhere(
              (a) => a.id == tx.accountId,
              orElse: () => Account(
                id: '',
                name: 'Unknown',
                type: '',
                currency: 'USD',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );
            final accountName = account.name.toLowerCase();

            if (!symbol.contains(query) && !name.contains(query) && !accountName.contains(query)) {
              return false;
            }
          }

          return true;
        }).toList();

        // Group transactions by executed date (ignoring time for headers)
        final Map<String, List<AssetTransaction>> groupedTxs = {};
        for (var tx in filteredTxs) {
          final dateKey = DateFormat('yyyy-MM-dd').format(tx.executedAt);
          if (!groupedTxs.containsKey(dateKey)) {
            groupedTxs[dateKey] = [];
          }
          groupedTxs[dateKey]!.add(tx);
        }

        // Sort dates descending
        final sortedDateKeys = groupedTxs.keys.toList()..sort((a, b) => b.compareTo(a));

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
                              'Asset Ledger',
                              style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 26),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Detailed historical investment & asset transactions',
                              style: Theme.of(context).textTheme.bodyMedium,
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
                                  'Asset Ledger',
                                  style: Theme.of(context).textTheme.displayLarge,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Detailed historical investment & asset transactions',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ],
                        ),
                  const SizedBox(height: 20),

                  // Filter and Search Panel
                  Card(
                    color: AppTheme.darkCard,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          // Search Bar
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search by Symbol, Asset Name or Account...',
                              prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, color: AppTheme.textSecondary),
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
                                _searchQuery = val;
                              });
                            },
                          ),
                          const SizedBox(height: 12),

                          // Filter Dropdowns
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _filterType,
                                  decoration: const InputDecoration(labelText: 'Transaction Type'),
                                  items: const [
                                    DropdownMenuItem(value: 'All', child: Text('All Types')),
                                    DropdownMenuItem(value: 'buy', child: Text('Buy')),
                                    DropdownMenuItem(value: 'sell', child: Text('Sell')),
                                    DropdownMenuItem(value: 'split', child: Text('Split')),
                                    DropdownMenuItem(value: 'dividend_reinvest', child: Text('Dividend Reinvest')),
                                    DropdownMenuItem(value: 'reward', child: Text('Reward')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _filterType = val;
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _filterAccountId,
                                  decoration: const InputDecoration(labelText: 'Account'),
                                  items: [
                                    const DropdownMenuItem(value: 'All', child: Text('All Accounts')),
                                    ...dataService.accounts
                                        .where((a) => a.accountGroup == 'capital')
                                        .map((a) {
                                      return DropdownMenuItem(
                                        value: a.id,
                                        child: Text(a.name),
                                      );
                                    }),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() {
                                        _filterAccountId = val;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Grouped Transactions List
                  Expanded(
                    child: filteredTxs.isEmpty
                        ? const Center(
                            child: Text(
                              'No matching asset transactions found.',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            physics: const BouncingScrollPhysics(),
                            itemCount: sortedDateKeys.length,
                            itemBuilder: (context, index) {
                              final dateKey = sortedDateKeys[index];
                              final txs = groupedTxs[dateKey]!;
                              final parsedDate = DateTime.parse(dateKey);
                              final headerStr = DateFormat('EEEE, MMMM d, yyyy').format(parsedDate);

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Date Header
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16.0, bottom: 8.0, left: 4.0),
                                    child: Text(
                                      headerStr,
                                      style: const TextStyle(
                                        color: AppTheme.accentCyan,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  // Card containing transactions of this date
                                  Card(
                                    color: AppTheme.darkCard,
                                    margin: EdgeInsets.zero,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: txs.length,
                                      separatorBuilder: (context, idx) => const Divider(
                                        height: 1,
                                        thickness: 1,
                                        color: Color(0xFF262647),
                                      ),
                                      itemBuilder: (context, idx) {
                                        final tx = txs[idx];
                                         // Cross-reference with assets table
                                         final asset = dataService.assets.firstWhere(
                                           (a) => a.id == tx.assetId,
                                           orElse: () => Asset(
                                             id: tx.assetId,
                                             symbol: tx.assetSymbol ?? tx.assetId,
                                             name: tx.assetName ?? tx.assetSymbol ?? tx.assetId,
                                             type: 'stock',
                                           ),
                                         );
                                         final assetSymbol = asset.symbol;
                                         final assetName = asset.name;
                                        
                                        // Look up account
                                        final account = dataService.accounts.firstWhere(
                                          (a) => a.id == tx.accountId,
                                          orElse: () => Account(
                                            id: '',
                                            name: 'Unknown Account',
                                            type: '',
                                            currency: 'USD',
                                            createdAt: DateTime.now(),
                                            updatedAt: DateTime.now(),
                                          ),
                                        );

                                        final isSplit = tx.type.toLowerCase() == 'split';
                                        final displayTotal = isSplit
                                            ? 'Multiplier: ${tx.quantity}x'
                                            : dataService.formatCurrencyWith(tx.quantity * tx.unitPrice, account.currency);

                                        // Item row layout
                                        Widget itemWidget = Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                                          child: Row(
                                            children: [
                                              // Symbol & Name & Account details
                                              Expanded(
                                                flex: isMobile ? 3 : 4,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Text(
                                                          assetSymbol,
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            color: Colors.white,
                                                            fontSize: 16,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        // Type chip
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: _getTypeColor(tx.type).withOpacity(0.15),
                                                            border: Border.all(
                                                              color: _getTypeColor(tx.type).withOpacity(0.5),
                                                            ),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            _getTypeLabel(tx.type),
                                                            style: TextStyle(
                                                              fontSize: 9,
                                                              color: _getTypeColor(tx.type),
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                        ),
                                                        if (tx.transactionId != null) ...[
                                                          const SizedBox(width: 6),
                                                          const Tooltip(
                                                            message: 'Linked to a ledger cash record',
                                                            child: Icon(
                                                              Icons.link,
                                                              color: AppTheme.accentCyan,
                                                              size: 14,
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      assetName,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                        color: AppTheme.textSecondary,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      account.name,
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color: AppTheme.textSecondary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Quantity & Price
                                              if (!isMobile)
                                                Expanded(
                                                  flex: 2,
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        isSplit ? 'Split Ratio' : '${tx.quantity} shares',
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          color: Colors.white,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        isSplit ? 'Ratio: ${tx.quantity}' : '@ ${dataService.formatCurrencyWith(tx.unitPrice, account.currency)}',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: AppTheme.textSecondary,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              // Total value calculated
                                              Expanded(
                                                flex: 2,
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.end,
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      displayTotal,
                                                      textAlign: TextAlign.end,
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                        color: _getTypeColor(tx.type),
                                                        fontSize: 15,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      dateFormatter.format(tx.executedAt),
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        color: AppTheme.textSecondary,
                                                        fontFamily: 'monospace',
                                                      ),
                                                    ),
                                                    if (isMobile) ...[
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        isSplit ? 'Split' : '${tx.quantity} @ ${dataService.formatCurrencyWith(tx.unitPrice, account.currency)}',
                                                        style: const TextStyle(
                                                          fontSize: 10,
                                                          color: AppTheme.textSecondary,
                                                        ),
                                                      ),
                                                    ]
                                                  ],
                                                ),
                                              ),
                                              // Actions Popup Menu
                                              SizedBox(
                                                width: 44,
                                                child: Center(
                                                  child: PopupMenuButton<String>(
                                                    icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
                                                    color: AppTheme.darkCard,
                                                    onSelected: (action) async {
                                                      if (action == 'delete') {
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
                                                              'Are you sure you want to delete this asset transaction? This will reverse its impact on your portfolio holding inventory.',
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
                                                          await dataService.deleteAssetTransaction(tx);
                                                          if (context.mounted) {
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              SnackBar(
                                                                content: Text('Deleted $assetSymbol transaction!'),
                                                              ),
                                                            );
                                                          }
                                                        }
                                                      }
                                                    },
                                                    itemBuilder: (context) => [
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
                                        );

                                        return itemWidget;
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
