import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' hide Category;
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'services/data_service.dart';
import 'core/theme.dart';
import 'views/dashboard_page.dart';
import 'views/ledger_page.dart';
import 'views/accounts_page.dart';
import 'views/login_page.dart';
import 'views/holdings_page.dart';
import 'views/settings_page.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (wrapped in try-catch to allow running locally without configurations)
  try {
    await Firebase.initializeApp(
      options: kIsWeb
          ? const FirebaseOptions(
              apiKey: 'AIzaSyDyPMN1YCO6k0y3m13k9JR_fWF7mjpSIUk',
              appId: '1:1006598018185:web:2d8a37bccfe4299fc92258',
              messagingSenderId: '1006598018185',
              projectId: 'budget-app-81120',
              authDomain: 'budget-app-81120.firebaseapp.com',
              storageBucket: 'budget-app-81120.firebasestorage.app',
              measurementId: 'G-968QW5D1Q7',
            )
          : null,
    );
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
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }
            final user = snapshot.data;
            if (user != null && user.email == 'yohncf@gmail.com') {
              return const MainLayout();
            }
            return LoginPage(currentUser: user);
          },
        ),
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
    const HoldingsPage(),
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.darkCard,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Image.asset(
              'assets/images/app_logo.png',
              width: 32,
              height: 32,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.analytics, size: 28, color: AppTheme.mainAction),
            ),
            tooltip: 'Open menu',
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          _selectedIndex == 0
              ? 'Dashboard'
              : _selectedIndex == 1
                  ? 'Ledger'
                  : _selectedIndex == 2
                      ? 'Accounts'
                      : 'Holdings',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        actions: [
          Consumer<DataService>(
            builder: (context, ds, child) {
              final displayCurrencies = ds.availableDisplayCurrencies;
              return Container(
                margin: const EdgeInsets.only(right: 16.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D1D22),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF23232A)),
                ),
                child: PopupMenuButton<String>(
                  initialValue: ds.displayCurrency,
                  tooltip: 'Change display currency',
                  onSelected: (currency) {
                    ds.setDisplayCurrency(currency);
                  },
                  color: AppTheme.darkCard,
                  itemBuilder: (context) {
                    return displayCurrencies.map((c) {
                      return PopupMenuItem<String>(
                        value: c,
                        child: Text(
                          c,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: ds.displayCurrency == c ? FontWeight.bold : FontWeight.normal,
                            color: ds.displayCurrency == c ? AppTheme.mainAction : Colors.white,
                          ),
                        ),
                      );
                    }).toList();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ds.displayCurrency,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.mainAction,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.arrow_drop_down,
                          size: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: AppTheme.darkCard,
        child: Column(
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF1D1D2C),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/app_logo.png',
                      width: 64,
                      height: 64,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.analytics, size: 48, color: AppTheme.mainAction),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Budget App Ledger',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: Icon(
                      _selectedIndex == 0 ? Icons.dashboard : Icons.dashboard_outlined,
                      color: _selectedIndex == 0 ? AppTheme.mainAction : AppTheme.textSecondary,
                    ),
                    title: Text(
                      'Dashboard',
                      style: TextStyle(
                        color: _selectedIndex == 0 ? Colors.white : AppTheme.textSecondary,
                        fontWeight: _selectedIndex == 0 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: _selectedIndex == 0,
                    selectedTileColor: AppTheme.mainAction.withOpacity(0.1),
                    onTap: () {
                      setState(() {
                        _selectedIndex = 0;
                      });
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      _selectedIndex == 1 ? Icons.list_alt : Icons.list_alt_outlined,
                      color: _selectedIndex == 1 ? AppTheme.mainAction : AppTheme.textSecondary,
                    ),
                    title: Text(
                      'Ledger',
                      style: TextStyle(
                        color: _selectedIndex == 1 ? Colors.white : AppTheme.textSecondary,
                        fontWeight: _selectedIndex == 1 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: _selectedIndex == 1,
                    selectedTileColor: AppTheme.mainAction.withOpacity(0.1),
                    onTap: () {
                      setState(() {
                        _selectedIndex = 1;
                      });
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      _selectedIndex == 2 ? Icons.account_balance_wallet : Icons.account_balance_wallet_outlined,
                      color: _selectedIndex == 2 ? AppTheme.mainAction : AppTheme.textSecondary,
                    ),
                    title: Text(
                      'Accounts',
                      style: TextStyle(
                        color: _selectedIndex == 2 ? Colors.white : AppTheme.textSecondary,
                        fontWeight: _selectedIndex == 2 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: _selectedIndex == 2,
                    selectedTileColor: AppTheme.mainAction.withOpacity(0.1),
                    onTap: () {
                      setState(() {
                        _selectedIndex = 2;
                      });
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      _selectedIndex == 3 ? Icons.pie_chart : Icons.pie_chart_outline,
                      color: _selectedIndex == 3 ? AppTheme.mainAction : AppTheme.textSecondary,
                    ),
                    title: Text(
                      'Holdings',
                      style: TextStyle(
                        color: _selectedIndex == 3 ? Colors.white : AppTheme.textSecondary,
                        fontWeight: _selectedIndex == 3 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: _selectedIndex == 3,
                    selectedTileColor: AppTheme.mainAction.withOpacity(0.1),
                    onTap: () {
                      setState(() {
                        _selectedIndex = 3;
                      });
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF23232A), height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.settings, color: AppTheme.textSecondary),
                    tooltip: 'Settings',
                    onPressed: () {
                      Navigator.pop(context); // close drawer
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SettingsPage()),
                      );
                    },
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.logout, color: Colors.redAccent),
                    tooltip: 'Logout',
                    onPressed: () async {
                      await FirebaseAuth.instance.signOut();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: _pages[_selectedIndex],
      ),
    );
  }
}
