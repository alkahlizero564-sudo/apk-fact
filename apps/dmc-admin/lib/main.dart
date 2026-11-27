import 'package:material_ui/material_ui.dart';
import 'backend.dart';
import 'auth_screens.dart';
import 'ui_kit.dart';
import 'screens/dashboard_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/ledger_screen.dart';
import 'screens/catalog_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Backend.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primarySeed = Color(0xFF0066FF);
    final darkThemeBase = appTheme(seed: primarySeed, style: KitStyle.luxe, brightness: Brightness.dark);
    final darkThemeConfig = darkThemeBase.copyWith(
      scaffoldBackgroundColor: const Color(0xFF0B132B),
      colorScheme: darkThemeBase.colorScheme.copyWith(
        surface: const Color(0xFF1C2541),
        primary: const Color(0xFF0066FF),
        secondary: const Color(0xFF00E5FF),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1C2541),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0x1AFFFFFF), width: 1),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF1C2541),
        selectedItemColor: Color(0xFF00E5FF),
        unselectedItemColor: Color(0xFF64748B),
        type: BottomNavigationBarType.fixed,
        elevation: 12,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
        unselectedLabelStyle: TextStyle(fontSize: 10),
      ),
    );

    return MaterialApp(
      title: 'إدارة DMC',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: Backend.messengerKey,
      themeMode: ThemeMode.dark,
      theme: darkThemeConfig,
      darkTheme: darkThemeConfig,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox(),
      ),
      home: AuthGate(
        brand: const AuthBrand(
          name: 'إدارة DMC',
          tagline: 'DIALA MEDICAL & CHEMICAL EQUIPMENT',
          icon: Icons.admin_panel_settings_rounded,
        ),
        home: const MainShell(),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final List<Widget> _screens = const [
    DashboardScreen(),
    OrdersScreen(),
    LedgerScreen(),
    CatalogScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return AppNavShell(
      tabs: [
        NavTab(
          label: 'التقارير',
          icon: Icons.analytics_rounded,
          page: _screens[0],
        ),
        NavTab(
          label: 'الطلبات',
          icon: Icons.assignment_rounded,
          page: _screens[1],
        ),
        NavTab(
          label: 'المبيعات',
          icon: Icons.receipt_long_rounded,
          page: _screens[2],
        ),
        NavTab(
          label: 'المنتجات',
          icon: Icons.inventory_2_rounded,
          page: _screens[3],
        ),
        NavTab(
          label: 'الإعدادات',
          icon: Icons.settings_rounded,
          page: _screens[4],
        ),
      ],
    );
  }
}
