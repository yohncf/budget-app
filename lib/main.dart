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
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    if (isMobile) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppTheme.darkCard,
          elevation: 0,
          title: Text(
            _selectedIndex == 0
                ? 'Dashboard'
                : _selectedIndex == 1
                    ? 'Ledger'
                    : 'Accounts',
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
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.backgroundGradient,
          ),
          child: _pages[_selectedIndex],
        ),
        bottomNavigationBar: NavigationBar(
          backgroundColor: AppTheme.darkCard,
          indicatorColor: AppTheme.mainAction.withOpacity(0.15),
          selectedIndex: _selectedIndex,
          onDestinationSelected: (int index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          height: 65,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined, color: AppTheme.textSecondary),
              selectedIcon: Icon(Icons.dashboard, color: AppTheme.mainAction),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: Icon(Icons.list_alt_outlined, color: AppTheme.textSecondary),
              selectedIcon: Icon(Icons.list_alt, color: AppTheme.mainAction),
              label: 'Ledger',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined, color: AppTheme.textSecondary),
              selectedIcon: Icon(Icons.account_balance_wallet, color: AppTheme.mainAction),
              label: 'Accounts',
            ),
          ],
        ),
      );
    }

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
            selectedLabelTextStyle: const TextStyle(color: AppTheme.mainAction, fontSize: 12, fontWeight: FontWeight.bold),
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Image.asset(
                'assets/images/app_logo.png',
                width: 48,
                height: 48,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.analytics, size: 36, color: AppTheme.mainAction),
              ),
            ),
            trailing: Consumer<DataService>(
              builder: (context, ds, child) {
                final displayCurrencies = ds.availableDisplayCurrencies;
                return Padding(
                  padding: const EdgeInsets.only(top: 32.0, bottom: 16.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1D1D22),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF23232A)),
                    ),
                    child: PopupMenuButton<String>(
                      initialValue: ds.displayCurrency,
                      tooltip: 'Change display currency',
                      onSelected: (currency) {
                        ds.setDisplayCurrency(currency);
                      },
                      offset: const Offset(60, 0),
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
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              ds.displayCurrency,
                              style: const TextStyle(
                                  fontSize: 11,
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
                  ),
                );
              },
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard, color: AppTheme.mainAction),
                label: Text('Dashboard'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.list_alt_outlined),
                selectedIcon: Icon(Icons.list_alt, color: AppTheme.mainAction),
                label: Text('Ledger'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.account_balance_wallet_outlined),
                selectedIcon: Icon(Icons.account_balance_wallet, color: AppTheme.mainAction),
                label: Text('Accounts'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1, color: Color(0xFF23232A)),
          
          // Main Content
          Expanded(
            child: _pages[_selectedIndex],
          ),
        ],
      ),
    );
  }
}
