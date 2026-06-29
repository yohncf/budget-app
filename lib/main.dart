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
import 'views/add_transaction_dialog.dart';
import 'views/asset_ledger_page.dart';
import 'views/add_asset_transaction_dialog.dart';


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
  bool _isDrawerOpenOnDesktop = true;
  bool _isFabMenuOpen = false;

  final List<Widget> _pages = [
    // IMPORTANT: Wrap each view page individually in its own SelectionArea.
    // Wrapping the root IndexedStack directly inside a single SelectionArea
    // breaks global text selection due to offstage/hidden widgets sharing the registrar.
    const SelectionArea(child: DashboardPage()),
    const SelectionArea(child: LedgerPage()),
    const SelectionArea(child: AccountsPage()),
    const SelectionArea(child: HoldingsPage()),
    const SelectionArea(child: AssetLedgerPage()), // CUSTOMIZATION PREFERENCE: Asset Ledger view added
  ];

  void _onTabSelected(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
    });
    if (index == 3 || index == 4) {
      Provider.of<DataService>(context, listen: false).setDisplayCurrency('USD');
    } else {
      Provider.of<DataService>(context, listen: false).setDisplayCurrency('MXN');
    }
  }

  @override
  void initState() {
    super.initState();
    // Default the display currency to MXN on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<DataService>(context, listen: false).setDisplayCurrency('MXN');
      }
    });
  }

  Widget _buildSparkleLogo() {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [
          Color(0xFF4285F4),
          Color(0xFF9B72CB),
          Color(0xFFD96570),
          Color(0xFFF4AF60),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: const Icon(
        Icons.auto_awesome,
        color: Colors.white,
        size: 24,
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData iconSelected,
    required IconData iconUnselected,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 3.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        hoverColor: Colors.white.withOpacity(0.06),
        splashColor: Colors.white.withOpacity(0.1),
        highlightColor: Colors.white.withOpacity(0.1),
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            color: isSelected ? Colors.white.withOpacity(0.08) : Colors.transparent,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Icon(
                isSelected ? iconSelected : iconUnselected,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerContent(BuildContext context, {required bool isDesktop}) {
    return Material(
      color: Colors.transparent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 20.0, right: 12.0, top: 20.0, bottom: 16.0),
            child: Row(
              children: [
                _buildSparkleLogo(),
                const SizedBox(width: 12),
                const Text(
                  'Ledger',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                if (isDesktop) ...[
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.menu_open, color: AppTheme.textSecondary, size: 20),
                    tooltip: 'Collapse sidebar',
                    onPressed: () {
                      setState(() {
                        _isDrawerOpenOnDesktop = false;
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: CustomScrollView(
              physics: const ClampingScrollPhysics(),
              slivers: [
                SliverList(
                  delegate: SliverChildListDelegate([
                    _buildDrawerItem(
                      iconSelected: Icons.dashboard,
                      iconUnselected: Icons.dashboard_outlined,
                      label: 'Dashboard',
                      isSelected: _selectedIndex == 0,
                      onTap: () {
                        _onTabSelected(0);
                        if (!isDesktop) {
                          Navigator.pop(context);
                        }
                      },
                    ),
                    _buildDrawerItem(
                      iconSelected: Icons.list_alt,
                      iconUnselected: Icons.list_alt_outlined,
                      label: 'Ledger',
                      isSelected: _selectedIndex == 1,
                      onTap: () {
                        _onTabSelected(1);
                        if (!isDesktop) {
                          Navigator.pop(context);
                        }
                      },
                    ),
                    _buildDrawerItem(
                      iconSelected: Icons.account_balance_wallet,
                      iconUnselected: Icons.account_balance_wallet_outlined,
                      label: 'Accounts',
                      isSelected: _selectedIndex == 2,
                      onTap: () {
                        _onTabSelected(2);
                        if (!isDesktop) {
                          Navigator.pop(context);
                        }
                      },
                    ),
                    _buildDrawerItem(
                      iconSelected: Icons.pie_chart,
                      iconUnselected: Icons.pie_chart_outline,
                      label: 'Holdings',
                      isSelected: _selectedIndex == 3,
                      onTap: () {
                        _onTabSelected(3);
                        if (!isDesktop) {
                          Navigator.pop(context);
                        }
                      },
                    ),
                    _buildDrawerItem(
                      iconSelected: Icons.history,
                      iconUnselected: Icons.history_outlined,
                      label: 'Asset Ledger',
                      isSelected: _selectedIndex == 4,
                      onTap: () {
                        _onTabSelected(4);
                        if (!isDesktop) {
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ]),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _buildDrawerItem(
                        iconSelected: Icons.settings,
                        iconUnselected: Icons.settings_outlined,
                        label: 'Settings',
                        isSelected: false,
                        onTap: () {
                          if (!isDesktop) {
                            Navigator.pop(context);
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SettingsPage()),
                          );
                        },
                      ),
                      _buildDrawerItem(
                        iconSelected: Icons.logout,
                        iconUnselected: Icons.logout_outlined,
                        label: 'Logout',
                        isSelected: false,
                        onTap: () async {
                          await FirebaseAuth.instance.signOut();
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width >= 900;

    final Widget mainScaffold = Scaffold(
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
            tooltip: isDesktop ? 'Toggle sidebar' : 'Open menu',
            onPressed: () {
              if (isDesktop) {
                setState(() {
                  _isDrawerOpenOnDesktop = !_isDrawerOpenOnDesktop;
                });
              } else {
                Scaffold.of(context).openDrawer();
              }
            },
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
      drawer: isDesktop ? null : Drawer(
        backgroundColor: AppTheme.darkCard,
        child: _buildDrawerContent(context, isDesktop: false),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: AppTheme.backgroundGradient,
            ),
            child: IndexedStack(
              index: _selectedIndex,
              children: _pages,
            ),
          ),
          // CUSTOMIZATION PREFERENCE: Translucent dimmed backdrop overlay when SpeedDial is open
          if (_isFabMenuOpen)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  setState(() {
                    _isFabMenuOpen = false;
                  });
                },
                child: Container(
                  color: Colors.black.withOpacity(0.55),
                ),
              ),
            ),
        ],
      ),
      // CUSTOMIZATION PREFERENCE: Rotatable main button and paged dialog options
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_isFabMenuOpen) ...[
            _buildFabMenuItem(
              icon: Icons.attach_money,
              label: 'Log Cash Transaction',
              onTap: () {
                setState(() => _isFabMenuOpen = false);
                showDialog(
                  context: context,
                  builder: (context) => AddTransactionDialog(
                    dataService: Provider.of<DataService>(context, listen: false),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildFabMenuItem(
              icon: Icons.show_chart,
              label: 'Log Asset Transaction',
              onTap: () {
                setState(() => _isFabMenuOpen = false);
                showDialog(
                  context: context,
                  builder: (context) => AddAssetTransactionDialog(
                    dataService: Provider.of<DataService>(context, listen: false),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
          FloatingActionButton(
            backgroundColor: _isFabMenuOpen ? const Color(0xFF42445A) : AppTheme.mainAction,
            foregroundColor: _isFabMenuOpen ? Colors.white : Colors.black,
            shape: const CircleBorder(),
            elevation: 8,
            onPressed: () {
              setState(() {
                _isFabMenuOpen = !_isFabMenuOpen;
              });
            },
            child: AnimatedRotation(
              turns: _isFabMenuOpen ? 0.125 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: const Icon(Icons.add, size: 28),
            ),
          ),
        ],
      ),
    );

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            if (_isDrawerOpenOnDesktop)
              Container(
                width: 260,
                color: AppTheme.darkCard,
                child: SafeArea(
                  child: _buildDrawerContent(context, isDesktop: true),
                ),
              ),
            if (_isDrawerOpenOnDesktop)
              const VerticalDivider(color: Color(0xFF23232A), width: 1, thickness: 1),
            Expanded(child: mainScaffold),
          ],
        ),
      );
    }

    return mainScaffold;
  }

  // CUSTOMIZATION PREFERENCE: Helper method to build premium custom SpeedDial option pills
  Widget _buildFabMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE8E9FA),
            foregroundColor: const Color(0xFF2C2D3B),
            elevation: 6,
            shadowColor: Colors.black.withOpacity(0.4),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
          icon: Icon(icon, size: 20, color: const Color(0xFF2C2D3B)),
          label: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              letterSpacing: 0.2,
            ),
          ),
          onPressed: onTap,
        ),
      ],
    );
  }
}
