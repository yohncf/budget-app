import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/data_service.dart';
import 'core/theme.dart';
import 'views/dashboard_page.dart';
import 'views/ledger_page.dart';
import 'views/accounts_page.dart';
import 'models/category.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (wrapped in try-catch to allow running locally without configurations)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase initialization skipped or failed: $e");
  }

  // Initialize Supabase (wrapped in try-catch)
  try {
    await Supabase.initialize(
      url: 'https://ubjvlwnzcyogxcwzdypd.supabase.co',
      anonKey: 'sb_publishable_6xo-YeBUV1dcgiNeJWQ31w_qx8G7IlH',
    );
  } catch (e) {
    debugPrint("Supabase initialization skipped or failed: $e");
  }

  runApp(const BudgetApp());
}

class BudgetApp extends StatelessWidget {
  const BudgetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DataService(),
      child: MaterialApp(
        title: 'Budget App Ledger',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const MainLayout(),
      ),
    );
  }
}

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const DashboardPage(),
    const LedgerPage(),
    const AccountsPage(),
  ];

  @override
  void initState() {
    super.initState();
    // Proactively seed basic categories for a premium first-time experience
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _seedDefaultCategories();
    });
  }

  void _seedDefaultCategories() async {
    final ds = Provider.of<DataService>(context, listen: false);
    if (ds.categories.isEmpty) {
      final defaultCats = [
        Category(id: 'cat_salary', name: 'Salary', type: 'income', createdAt: DateTime.now()),
        Category(id: 'cat_groceries', name: 'Groceries', type: 'expense', createdAt: DateTime.now()),
        Category(id: 'cat_dining', name: 'Dining Out', type: 'expense', createdAt: DateTime.now()),
        Category(id: 'cat_transfer', name: 'Savings Transfer', type: 'transfer', createdAt: DateTime.now()),
        Category(id: 'cat_reimburse', name: 'Corporate Reimbursement', type: 'reimbursement', createdAt: DateTime.now()),
      ];
      for (var cat in defaultCats) {
        await ds.addCategory(cat);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Sidebar rail for premium desktop feel
          NavigationRail(
            backgroundColor: AppTheme.darkCard,
            selectedIndex: _selectedIndex,
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            unselectedLabelTextStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            selectedLabelTextStyle: const TextStyle(color: AppTheme.accentCyan, fontSize: 12, fontWeight: FontWeight.bold),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Image.network(
                'https://img.icons8.com/color/96/000000/google-wallet.png',
                width: 48,
                height: 48,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.account_balance_wallet, size: 36, color: AppTheme.primaryPurple),
              ),
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard, color: AppTheme.accentCyan),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.list_alt_outlined),
                selectedIcon: Icon(Icons.list_alt, color: AppTheme.accentCyan),
                label: Text('Ledger'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet, color: AppTheme.accentCyan),
                label: Text('Accounts'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1, color: Color(0xFF2E2E4A)),
          
          // Main Content
          Expanded(
            child: _pages[_selectedIndex],
          ),
        ],
      ),
    );
  }
}
