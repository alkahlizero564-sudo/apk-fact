import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppStateNotifier(prefs),
      child: const AnaaApp(),
    ),
  );
}

enum ExpenseCategory {
  food('طعام ومشروبات', Icons.restaurant_rounded, Color(0xFFFF6D00)),
  shopping('تسوق وتجهيزات', Icons.shopping_bag_rounded, Color(0xFF9C27B0)),
  transport('مواصلات وتُنقُّل', Icons.directions_car_rounded, Color(0xFF0288D1)),
  bills('فواتير وخدمات', Icons.receipt_long_rounded, Color(0xFFE53935)),
  health('صحة وعناية', Icons.medical_services_rounded, Color(0xFF00897B)),
  entertainment('ترفيه ورحلات', Icons.sports_esports_rounded, Color(0xFFFB8C00)),
  other('مصروفات أخرى', Icons.more_horiz_rounded, Color(0xFF546E7A));

  final String title;
  final IconData icon;
  final Color color;
  const ExpenseCategory(this.title, this.icon, this.color);
}

class ExpenseItem {
  final String id;
  final String title;
  final double amount;
  final ExpenseCategory category;
  final DateTime date;
  final String note;
  bool isFavorite;

  ExpenseItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    this.note = '',
    this.isFavorite = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'categoryIndex': category.index,
        'date': date.toIso8601String(),
        'note': note,
        'isFavorite': isFavorite,
      };

  factory ExpenseItem.fromJson(Map<String, dynamic> json) => ExpenseItem(
        id: json['id'],
        title: json['title'],
        amount: (json['amount'] as num).toDouble(),
        category: ExpenseCategory.values[json['categoryIndex'] ?? 0],
        date: DateTime.parse(json['date']),
        note: json['note'] ?? '',
        isFavorite: json['isFavorite'] ?? false,
      );
}

class AppStateNotifier extends ChangeNotifier {
  final SharedPreferences _prefs;
  ThemeMode _themeMode = ThemeMode.system;
  List<ExpenseItem> _expenses = [];
  double _monthlyBudget = 5000.0;
  String _userName = 'عبدالله';

  AppStateNotifier(this._prefs) {
    _loadFromPrefs();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  List<ExpenseItem> get expenses => _expenses;
  double get monthlyBudget => _monthlyBudget;
  String get userName => _userName;

  List<ExpenseItem> get favoriteExpenses =>
      _expenses.where((e) => e.isFavorite).toList();

  double get totalSpent => _expenses.fold(0.0, (sum, item) => sum + item.amount);

  double get todaySpent {
    final now = DateTime.now();
    return _expenses.where((item) {
      return item.date.year == now.year &&
          item.date.month == now.month &&
          item.date.day == now.day;
    }).fold(0.0, (sum, item) => sum + item.amount);
  }

  double get thisWeekSpent {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    return _expenses.where((item) {
      return item.date.isAfter(startOfWeek.subtract(const Duration(seconds: 1)));
    }).fold(0.0, (sum, item) => sum + item.amount);
  }

  void _loadFromPrefs() {
    final themeStr = _prefs.getString('theme_mode') ?? 'system';
    if (themeStr == 'dark') _themeMode = ThemeMode.dark;
    if (themeStr == 'light') _themeMode = ThemeMode.light;

    _monthlyBudget = _prefs.getDouble('monthly_budget') ?? 5000.0;
    _userName = _prefs.getString('user_name') ?? 'عبدالله';

    final String? data = _prefs.getString('expenses_data');
    if (data != null && data.isNotEmpty) {
      try {
        final List list = jsonDecode(data);
        _expenses = list.map((e) => ExpenseItem.fromJson(e)).toList();
      } catch (_) {
        _loadDefaultData();
      }
    } else {
      _loadDefaultData();
    }
    notifyListeners();
  }

  void _loadDefaultData() {
    final now = DateTime.now();
    _expenses = [
      ExpenseItem(
        id: '1',
        title: 'مشتريات البقالة الأسبوعية',
        amount: 340.50,
        category: ExpenseCategory.food,
        date: now.subtract(const Duration(hours: 2)),
        note: 'خضار، فواكه، ومستلزمات مطبخ',
        isFavorite: true,
      ),
      ExpenseItem(
        id: '2',
        title: 'فاتورة الكهرباء والماء',
        amount: 450.00,
        category: ExpenseCategory.bills,
        date: now.subtract(const Duration(days: 1)),
        note: 'فاتورة شهر يوليو',
        isFavorite: true,
      ),
      ExpenseItem(
        id: '3',
        title: 'بنزين السيارة',
        amount: 130.00,
        category: ExpenseCategory.transport,
        date: now.subtract(const Duration(days: 2)),
        note: 'محطة الدريس 95',
      ),
      ExpenseItem(
        id: '4',
        title: 'عشاء مع العائلة',
        amount: 225.00,
        category: ExpenseCategory.food,
        date: now.subtract(const Duration(days: 3)),
      ),
      ExpenseItem(
        id: '5',
        title: 'اشتراك النادي الرياضي',
        amount: 350.00,
        category: ExpenseCategory.health,
        date: now.subtract(const Duration(days: 4)),
        isFavorite: true,
      ),
      ExpenseItem(
        id: '6',
        title: 'تذاكر سينما ومشروبات',
        amount: 110.00,
        category: ExpenseCategory.entertainment,
        date: now.subtract(const Duration(days: 6)),
      ),
    ];
    _saveToPrefs();
  }

  void toggleTheme() {
    if (_themeMode == ThemeMode.dark) {
      _themeMode = ThemeMode.light;
      _prefs.setString('theme_mode', 'light');
    } else {
      _themeMode = ThemeMode.dark;
      _prefs.setString('theme_mode', 'dark');
    }
    notifyListeners();
  }

  void setBudget(double budget) {
    _monthlyBudget = budget;
    _prefs.setDouble('monthly_budget', budget);
    notifyListeners();
  }

  void setUserName(String name) {
    _userName = name;
    _prefs.setString('user_name', name);
    notifyListeners();
  }

  void addExpense(ExpenseItem item) {
    _expenses.insert(0, item);
    _saveToPrefs();
    notifyListeners();
  }

  void deleteExpense(String id) {
    _expenses.removeWhere((item) => item.id == id);
    _saveToPrefs();
    notifyListeners();
  }

  void toggleFavorite(String id) {
    final index = _expenses.indexWhere((item) => item.id == id);
    if (index != -1) {
      _expenses[index].isFavorite = !_expenses[index].isFavorite;
      _saveToPrefs();
      notifyListeners();
    }
  }

  void _saveToPrefs() {
    final jsonString = jsonEncode(_expenses.map((e) => e.toJson()).toList());
    _prefs.setString('expenses_data', jsonString);
  }
}

class AnaaApp extends StatelessWidget {
  const AnaaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final notifier = Provider.of<AppStateNotifier>(context);

    const primaryColor = Color(0xFF0D9488);
    const secondaryColor = Color(0xFF14B8A6);
    const accentColor = Color(0xFFF59E0B);

    final lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
        secondary: secondaryColor,
        tertiary: accentColor,
        surface: const Color(0xFFF8FAFC),
      ),
      scaffoldBackgroundColor: const Color(0xFFF1F5F9),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );

    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        primary: const Color(0xFF2DD4BF),
        secondary: secondaryColor,
        tertiary: accentColor,
        surface: const Color(0xFF1E293B),
      ),
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: const Color(0xFF1E293B),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: MaterialApp(
        title: 'أنا - إدارة المصروفات',
        debugShowCheckedModeBanner: false,
        themeMode: notifier.themeMode,
        theme: lightTheme,
        darkTheme: darkTheme,
        home: const MainShellScreen(),
      ),
    );
  }
}

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomeScreen(),
    StatsScreen(),
    FavoritesScreen(),
    SettingsScreen(),
  ];

  void _openAddExpenseModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddExpenseBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notifier = Provider.of<AppStateNotifier>(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              child: const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'أنَا',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  'إدارة المصروفات الشخصية',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: notifier.isDarkMode ? 'الوضع الفاتح' : 'الوضع الليلي',
            onPressed: () {
              notifier.toggleTheme();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    notifier.isDarkMode
                        ? 'تم تفعيل الوضع الليلي 🌙'
                        : 'تم تفعيل الوضع الفاتح ☀️',
                  ),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            icon: Icon(
              notifier.isDarkMode
                  ? Icons.light_mode_rounded
                  : Icons.dark_mode_rounded,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: FloatingActionButton.extended(
          onPressed: () => _openAddExpenseModal(context),
          elevation: 6,
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded, size: 26),
          label: const Text(
            'إضافة مصروف',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.18),
        elevation: 10,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.donut_large_outlined),
            selectedIcon: Icon(Icons.donut_large_rounded),
            label: 'الإحصائيات',
          ),
          NavigationDestination(
            icon: Icon(Icons.bookmark_border_rounded),
            selectedIcon: Icon(Icons.bookmark_rounded),
            label: 'المفضلة',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_rounded),
            selectedIcon: Icon(Icons.tune_rounded),
            label: 'الإعدادات',
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum SortOption { newest, highest, lowest }

class _HomeScreenState extends State<HomeScreen> {
  ExpenseCategory? _selectedCategory;
  SortOption _currentSort = SortOption.newest;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'صباح الخير ☀️';
    if (hour >= 12 && hour < 17) return 'مساء الخير 🌤️';
    return 'مساء الخير ✨';
  }

  void _showBudgetEditModal(BuildContext context, AppStateNotifier notifier) {
    final controller =
        TextEditingController(text: notifier.monthlyBudget.toStringAsFixed(0));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return Container(
          padding: EdgeInsets.fromLTRB(
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'تعديل الميزانية الشهرية',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'المبلغ المحدد (ر.س)',
                  prefixIcon: const Icon(Icons.savings_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    final val = double.tryParse(controller.text);
                    if (val != null && val > 0) {
                      notifier.setBudget(val);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم تحديث الميزانية بنجاح 🎯'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: const Text('حفظ الميزانية الجديدة',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifier = Provider.of<AppStateNotifier>(context);
    final theme = Theme.of(context);
    final total = notifier.totalSpent;
    final budget = notifier.monthlyBudget;
    final remaining = (budget - total).clamp(0.0, double.infinity);
    final progress = (total / (budget > 0 ? budget : 1)).clamp(0.0, 1.0);

    List<ExpenseItem> filteredList = notifier.expenses.where((e) {
      final matchesCategory =
          _selectedCategory == null || e.category == _selectedCategory;
      final query = _searchController.text.trim().toLowerCase();
      final matchesQuery = query.isEmpty ||
          e.title.toLowerCase().contains(query) ||
          e.note.toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList();

    if (_currentSort == SortOption.highest) {
      filteredList.sort((a, b) => b.amount.compareTo(a.amount));
    } else if (_currentSort == SortOption.lowest) {
      filteredList.sort((a, b) => a.amount.compareTo(b.amount));
    } else {
      filteredList.sort((a, b) => b.date.compareTo(a.date));
    }

    final currentMonthName = DateFormat('MMMM yyyy', 'ar').format(DateTime.now());

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_getGreeting()}، ${notifier.userName}',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  'ملخص سريع لنشاطك المالي',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_rounded,
                      size: 14, color: theme.colorScheme.primary),
                  const SizedBox(width: 4),
                  Text(
                    currentMonthName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ).animate().fadeIn(duration: 250.ms),

        const SizedBox(height: 16),

        Card(
          elevation: 6,
          shadowColor: theme.colorScheme.primary.withValues(alpha: 0.25),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: notifier.isDarkMode
                    ? [
                        const Color(0xFF0D9488),
                        const Color(0xFF0F766E),
                        const Color(0xFF115E59),
                      ]
                    : [
                        const Color(0xFF0D9488),
                        const Color(0xFF14B8A6),
                        const Color(0xFF0284C7),
                      ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.pie_chart_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'المصروف الإجمالي',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () => _showBudgetEditModal(context, notifier),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'الميزانية: ${budget.toStringAsFixed(0)} ر.س',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.edit,
                                color: Colors.white, size: 12),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      total.toStringAsFixed(2),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'ر.س',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    color: progress > 0.9
                        ? const Color(0xFFEF4444)
                        : progress > 0.75
                            ? const Color(0xFFF59E0B)
                            : Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'المتبقي: ${remaining.toStringAsFixed(2)} ر.س',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'مستهلك: ${(progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.05),

        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: _QuickStatCard(
                title: 'مصروف اليوم',
                amount: notifier.todaySpent,
                icon: Icons.today_rounded,
                color: const Color(0xFF3B82F6),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QuickStatCard(
                title: 'هذا الأسبوع',
                amount: notifier.thisWeekSpent,
                icon: Icons.date_range_rounded,
                color: const Color(0xFF10B981),
              ),
            ),
          ],
        ).animate().fadeIn(duration: 350.ms),

        const SizedBox(height: 18),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'ابحث في المصروفات أو الملاحظات...',
                  hintStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: theme.cardTheme.color,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(16),
              ),
              child: PopupMenuButton<SortOption>(
                icon: const Icon(Icons.swap_vert_rounded),
                tooltip: 'ترتيب حسب',
                onSelected: (option) {
                  setState(() => _currentSort = option);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: SortOption.newest,
                    child: Row(
                      children: [
                        Icon(Icons.history_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('الأحدث أولاً', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: SortOption.highest,
                    child: Row(
                      children: [
                        Icon(Icons.arrow_upward_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('الأعلى سعراً', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: SortOption.lowest,
                    child: Row(
                      children: [
                        Icon(Icons.arrow_downward_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('الأقل سعراً', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 6.0),
                child: FilterChip(
                  label: Text('الكل (${notifier.expenses.length})'),
                  selected: _selectedCategory == null,
                  onSelected: (_) => setState(() => _selectedCategory = null),
                  selectedColor: theme.colorScheme.primary.withValues(alpha: 0.18),
                  checkmarkColor: theme.colorScheme.primary,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: _selectedCategory == null
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
              ),
              ...ExpenseCategory.values.map((cat) {
                final count =
                    notifier.expenses.where((e) => e.category == cat).length;
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(left: 6.0),
                  child: FilterChip(
                    avatar: Icon(cat.icon, size: 14, color: cat.color),
                    label: Text('${cat.title} ($count)'),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = selected ? cat : null;
                      });
                    },
                    selectedColor: cat.color.withValues(alpha: 0.18),
                    checkmarkColor: cat.color,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 18),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'سجل العمليات',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              '${filteredList.length} عنصر',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        if (filteredList.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            margin: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 56,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 12),
                Text(
                  'لم يتم العثور على أي مصروفات',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _searchController.text.isNotEmpty
                      ? 'حاول البحث بكلمات أخرى أو تغيير الفلتر'
                      : 'أضف مصروف جديد للبدء بتتبع ميزانيتك بسهولة',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ...filteredList.map((expense) {
            return Dismissible(
              key: Key(expense.id),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) async {
                return await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('حذف المصروف'),
                        content: Text('هل أنت تأكد من حذف "${expense.title}"؟'),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('إلغاء'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('حذف'),
                          ),
                        ],
                      ),
                    ) ??
                    false;
              },
              onDismissed: (_) {
                notifier.deleteExpense(expense.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تم حذف "${expense.title}" بنجاح'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              background: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.centerLeft,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('حذف',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                    SizedBox(width: 6),
                    Icon(Icons.delete_outline_rounded,
                        color: Colors.white, size: 24),
                  ],
                ),
              ),
              child: ExpenseCardItem(expense: expense),
            );
          }),
      ],
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  final String title;
  final double amount;
  final IconData icon;
  final Color color;

  const _QuickStatCard({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${amount.toStringAsFixed(1)} ر.س',
                    style: const TextStyle(
                      fontSize: 14,
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
}

class ExpenseCardItem extends StatelessWidget {
  final ExpenseItem expense;
  const ExpenseCardItem({super.key, required this.expense});

  @override
  Widget build(BuildContext context) {
    final notifier = Provider.of<AppStateNotifier>(context, listen: false);
    final theme = Theme.of(context);
    final dateFormat = DateFormat('yyyy/MM/dd • hh:mm a');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: expense.category.color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                expense.category.icon,
                color: expense.category.color,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: expense.category.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          expense.category.title,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: expense.category.color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        dateFormat.format(expense.date),
                        style: TextStyle(
                          fontSize: 10,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                  if (expense.note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      expense.note,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '-${expense.amount.toStringAsFixed(2)} ر.س',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    notifier.toggleFavorite(expense.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(expense.isFavorite
                            ? 'تمت إزالة المصروف من المفضلة'
                            : 'تمت إضافة المصروف إلى المفضلة ❤️'),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: Icon(
                    expense.isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: expense.isFavorite ? Colors.red : Colors.grey.shade400,
                    size: 18,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifier = Provider.of<AppStateNotifier>(context);
    final theme = Theme.of(context);

    final Map<ExpenseCategory, double> catTotals = {};
    for (var cat in ExpenseCategory.values) {
      catTotals[cat] = 0.0;
    }
    for (var item in notifier.expenses) {
      catTotals[item.category] = (catTotals[item.category] ?? 0) + item.amount;
    }

    final total = notifier.totalSpent;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'الإحصائيات والتحليل',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'توزيع الإنفاق حسب الأقسام والتصنيفات',
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 16),
        if (total == 0)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('لا تتوفر إحصائيات حالياً')),
            ),
          )
        else ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  SizedBox(
                    height: 190,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 4,
                        centerSpaceRadius: 42,
                        sections: ExpenseCategory.values.map((cat) {
                          final amount = catTotals[cat] ?? 0;
                          final percentage =
                              total > 0 ? (amount / total) * 100 : 0.0;
                          return PieChartSectionData(
                            color: cat.color,
                            value: amount == 0 ? 0.01 : amount,
                            title: percentage > 8
                                ? '${percentage.toStringAsFixed(0)}%'
                                : '',
                            radius: 46,
                            titleStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: ExpenseCategory.values.map((cat) {
                      final amount = catTotals[cat] ?? 0;
                      if (amount == 0) return const SizedBox.shrink();
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: cat.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${cat.title}: ${amount.toStringAsFixed(0)} ر.س',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 250.ms),

          const SizedBox(height: 20),
          Text(
            'تفاصيل القطاعات',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          ...ExpenseCategory.values.map((cat) {
            final sum = catTotals[cat] ?? 0;
            if (sum == 0) return const SizedBox.shrink();
            final percent = total > 0 ? sum / total : 0.0;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: cat.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(cat.icon, color: cat.color, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          cat.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const Spacer(),
                        Text(
                          '${sum.toStringAsFixed(2)} ر.س',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: percent,
                        minHeight: 6,
                        backgroundColor:
                            theme.colorScheme.onSurface.withValues(alpha: 0.08),
                        color: cat.color,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notifier = Provider.of<AppStateNotifier>(context);
    final theme = Theme.of(context);
    final favorites = notifier.favoriteExpenses;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Icon(Icons.bookmark_rounded, color: Color(0xFFF59E0B)),
            const SizedBox(width: 8),
            Text(
              'المصروفات المفضلة والثابتة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'وصول سريع للمصروفات الدورية والفواتير المكررة.',
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 16),
        if (favorites.isEmpty)
          Container(
            padding: const EdgeInsets.all(36),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.favorite_border_rounded,
                  size: 56,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 12),
                Text(
                  'قائمة المفضلة فارغة حالياً',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'اضغط على أيقونة القلب في أي مصروف لتسجيله هنا كعنصر مفضل',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ...favorites.map((expense) => ExpenseCardItem(expense: expense)),
      ],
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _launchWhatsApp(BuildContext context) async {
    const phoneNumber = '+966500000000';
    const message = 'مرحباً، أود الاستفسار حول تطبيق أنَا - إدارة المصروفات';
    final url =
        Uri.parse('https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('تعذر فتح تطبيق واتساب حالياً')),
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر الاتصال بالخدمة')),
        );
      }
    }
  }

  void _showUserNameDialog(BuildContext context, AppStateNotifier notifier) {
    final controller = TextEditingController(text: notifier.userName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تغيير الاسم الشخصي'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'الاسم',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                notifier.setUserName(controller.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifier = Provider.of<AppStateNotifier>(context);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'الإعدادات والتخصيص',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.person_rounded,
                    color: theme.colorScheme.primary),
                title: const Text('اسم المستخدم',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text(notifier.userName),
                trailing: const Icon(Icons.edit_rounded, size: 18),
                onTap: () => _showUserNameDialog(context, notifier),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text('الوضع الليلي (Dark Mode)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('التبديل بين المظهر الفاتح والداكن'),
                value: notifier.isDarkMode,
                secondary: Icon(
                  notifier.isDarkMode
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  color: theme.colorScheme.primary,
                ),
                onChanged: (_) => notifier.toggleTheme(),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.savings_rounded,
                    color: theme.colorScheme.primary),
                title: const Text('الميزانية الشهرية',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle:
                    Text('${notifier.monthlyBudget.toStringAsFixed(0)} ر.س'),
                trailing: const Icon(Icons.edit_rounded, size: 18),
                onTap: () {
                  final controller = TextEditingController(
                      text: notifier.monthlyBudget.toStringAsFixed(0));
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('تحديد الميزانية الشهرية'),
                      content: TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'المبلغ (ر.س)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('إلغاء'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            final val = double.tryParse(controller.text);
                            if (val != null && val > 0) {
                              notifier.setBudget(val);
                              Navigator.pop(ctx);
                            }
                          },
                          child: const Text('حفظ'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'الدعم والتواصل',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.chat_bubble_rounded,
                    color: Color(0xFF25D366)),
                title: const Text('تواصل معنا عبر واتساب',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('المساعدة والدعم الفني السريع'),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                onTap: () => _launchWhatsApp(context),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.info_outline_rounded, color: Colors.blue),
                title: Text('عن التطبيق',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: Text('تطبيق أنَا الإصدار 2.0 - محلي 100% وبدون إعلانات'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class AddExpenseBottomSheet extends StatefulWidget {
  const AddExpenseBottomSheet({super.key});

  @override
  State<AddExpenseBottomSheet> createState() => _AddExpenseBottomSheetState();
}

class _AddExpenseBottomSheetState extends State<AddExpenseBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  ExpenseCategory _selectedCat = ExpenseCategory.food;
  bool _isFavorite = false;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _addQuickAmount(double val) {
    double current = double.tryParse(_amountController.text) ?? 0.0;
    _amountController.text = (current + val).toStringAsFixed(0);
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final notifier = Provider.of<AppStateNotifier>(context, listen: false);
      final newItem = ExpenseItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        amount: double.parse(_amountController.text.trim()),
        category: _selectedCat,
        date: DateTime.now(),
        note: _noteController.text.trim(),
        isFavorite: _isFavorite,
      );

      notifier.addExpense(newItem);
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تسجيل "${newItem.title}" بنجاح ✨'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'تسجيل مصروف جديد',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _titleController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'عنوان المصروف (مثال: عشاء، بنزين...)',
                  prefixIcon: const Icon(Icons.edit_note_rounded),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'يرجى إدخال عنوان المصروف';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'المبلغ (ر.س)',
                  prefixIcon: const Icon(Icons.payments_rounded),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'يرجى إدخال المبلغ';
                  }
                  if (double.tryParse(val) == null || double.parse(val) <= 0) {
                    return 'يرجى إدخال مبلغ صحيح أكبر من 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  const Text('إضافة سريعة: ', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Wrap(
                    spacing: 6,
                    children: [10, 50, 100, 200].map((val) {
                      return ActionChip(
                        label: Text('+$val', style: const TextStyle(fontSize: 11)),
                        onPressed: () => _addQuickAmount(val.toDouble()),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      );
                    }).toList(),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              const Text(
                'اختر التصنيف المناسب:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ExpenseCategory.values.map((cat) {
                  final isSelected = _selectedCat == cat;
                  return ChoiceChip(
                    avatar: Icon(
                      cat.icon,
                      size: 16,
                      color: isSelected ? Colors.white : cat.color,
                    ),
                    label: Text(cat.title, style: const TextStyle(fontSize: 12)),
                    selected: isSelected,
                    selectedColor: cat.color,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : null,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedCat = cat);
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: 'ملاحظة أو تفاصيل (اختياري)',
                  prefixIcon: const Icon(Icons.notes_rounded),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),

              const SizedBox(height: 6),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('حفظ المصروف في القائمة المفضلة',
                    style: TextStyle(fontSize: 13)),
                value: _isFavorite,
                onChanged: (val) => setState(() => _isFavorite = val ?? false),
                activeColor: theme.colorScheme.primary,
              ),

              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _submit,
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text(
                    'تأكيد وحفظ المصروف',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
