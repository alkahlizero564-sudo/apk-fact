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
  food('طعام ومشروبات', Icons.restaurant_rounded, Color(0xFFFF7043)),
  shopping('تسوق وتجهيزات', Icons.shopping_bag_rounded, Color(0xFFAB47BC)),
  transport('مواصلات وتُنقُّل', Icons.directions_car_rounded, Color(0xFF42A5F5)),
  bills('فواتير وخدمات', Icons.receipt_long_rounded, Color(0xFFEF5350)),
  health('صحة وعناية', Icons.medical_services_rounded, Color(0xFF26A69A)),
  entertainment('ترفيه ورحلات', Icons.sports_esports_rounded, Color(0xFFFFA726)),
  other('مصروفات أخرى', Icons.more_horiz_rounded, Color(0xFF78909C));

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

  AppStateNotifier(this._prefs) {
    _loadFromPrefs();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  List<ExpenseItem> get expenses => _expenses;
  double get monthlyBudget => _monthlyBudget;

  List<ExpenseItem> get favoriteExpenses =>
      _expenses.where((e) => e.isFavorite).toList();

  double get totalSpent => _expenses.fold(0.0, (sum, item) => sum + item.amount);

  void _loadFromPrefs() {
    final themeStr = _prefs.getString('theme_mode') ?? 'system';
    if (themeStr == 'dark') _themeMode = ThemeMode.dark;
    if (themeStr == 'light') _themeMode = ThemeMode.light;

    _monthlyBudget = _prefs.getDouble('monthly_budget') ?? 5000.0;

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
        title: 'مشتريات البقالة الشهرية',
        amount: 420.50,
        category: ExpenseCategory.food,
        date: now.subtract(const Duration(hours: 3)),
        note: 'خضروات وفاكهة ومستلزمات منزلية',
        isFavorite: true,
      ),
      ExpenseItem(
        id: '2',
        title: 'فاتورة الكهرباء والماء',
        amount: 380.00,
        category: ExpenseCategory.bills,
        date: now.subtract(const Duration(days: 1)),
        note: 'فاتورة شهر يوليو',
        isFavorite: true,
      ),
      ExpenseItem(
        id: '3',
        title: 'بنزين السيارة',
        amount: 140.00,
        category: ExpenseCategory.transport,
        date: now.subtract(const Duration(days: 2)),
      ),
      ExpenseItem(
        id: '4',
        title: 'عشاء مع الأسرة',
        amount: 230.00,
        category: ExpenseCategory.food,
        date: now.subtract(const Duration(days: 3)),
      ),
      ExpenseItem(
        id: '5',
        title: 'اشتراك النادي الرياضي',
        amount: 350.00,
        category: ExpenseCategory.health,
        date: now.subtract(const Duration(days: 5)),
        isFavorite: true,
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

    const primaryColor = Color(0xFF00897B);
    const secondaryColor = Color(0xFF00E676);

    final lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.light,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: const Color(0xFFF8FAF9),
      ),
      scaffoldBackgroundColor: const Color(0xFFF3F7F5),
      cardTheme: CardThemeData(
        elevation: 1,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        color: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      fontFamily: 'Roboto',
    );

    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        primary: const Color(0xFF26A69A),
        secondary: secondaryColor,
        surface: const Color(0xFF1E2624),
      ),
      scaffoldBackgroundColor: const Color(0xFF121816),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        color: const Color(0xFF1E2624),
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
        title: 'أنا - مصروفاتي',
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
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                color: theme.colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'أنا',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  'إدارة المصروفات الذكية',
                  style: TextStyle(
                    fontSize: 12,
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
                  content: Text(notifier.isDarkMode
                      ? 'تم تفعيل الوضع الليلي 🌙'
                      : 'تم تفعيل الوضع الفاتح ☀️'),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            icon: Icon(
              notifier.isDarkMode
                  ? Icons.wb_sunny_rounded
                  : Icons.dark_mode_rounded,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _pages[_currentIndex],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddExpenseModal(context),
        elevation: 3,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text(
          'إضافة مصروف',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        indicatorColor: theme.colorScheme.primary.withValues(alpha: 0.18),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline_rounded),
            selectedIcon: Icon(Icons.pie_chart_rounded),
            label: 'الإحصائيات',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border_rounded),
            selectedIcon: Icon(Icons.favorite_rounded),
            label: 'المفضلة',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
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

class _HomeScreenState extends State<HomeScreen> {
  ExpenseCategory? _selectedCategory;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = Provider.of<AppStateNotifier>(context);
    final theme = Theme.of(context);
    final total = notifier.totalSpent;
    final budget = notifier.monthlyBudget;
    final progress = (total / (budget > 0 ? budget : 1)).clamp(0.0, 1.0);

    final filteredList = notifier.expenses.where((e) {
      final matchesCategory =
          _selectedCategory == null || e.category == _selectedCategory;
      final matchesQuery = _searchController.text.isEmpty ||
          e.title.toLowerCase().contains(_searchController.text.toLowerCase()) ||
          e.note.toLowerCase().contains(_searchController.text.toLowerCase());
      return matchesCategory && matchesQuery;
    }).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
      children: [
        // Summary Header Card
        Card(
          elevation: 2,
          shadowColor: theme.colorScheme.primary.withValues(alpha: 0.25),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.primary.withRed(20).withBlue(160),
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
                    const Text(
                      'إجمالي مصروفات الشهر',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'الميزانية: ${budget.toStringAsFixed(0)} ر.س',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  '${total.toStringAsFixed(2)} ر.س',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: Colors.white24,
                    color: progress > 0.9 ? Colors.amberAccent : Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'المتبقي: ${(budget - total).clamp(0, double.infinity).toStringAsFixed(2)} ر.س',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                    ),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ).animate().fadeIn(duration: 250.ms).slideY(begin: -0.05),

        const SizedBox(height: 16),

        // Search Bar
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'ابحث عن مصروف...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  )
                : null,
            filled: true,
            fillColor: theme.cardTheme.color,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Category Filter Chips
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: FilterChip(
                  label: const Text('الكل'),
                  selected: _selectedCategory == null,
                  onSelected: (_) => setState(() => _selectedCategory = null),
                  selectedColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                ),
              ),
              ...ExpenseCategory.values.map((cat) {
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: FilterChip(
                    avatar: Icon(cat.icon, size: 16, color: cat.color),
                    label: Text(cat.title),
                    selected: isSelected,
                    onSelected: (val) => setState(() {
                      _selectedCategory = val ? cat : null;
                    }),
                    selectedColor: cat.color.withValues(alpha: 0.2),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'سجل المصروفات',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              '${filteredList.length} عنصر',
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (filteredList.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 56,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 12),
                Text(
                  'لا توجد مصروفات هنا',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'اضغط على "إضافة مصروف" بالأسفل لتسجيل مصروف جديد',
                  style: TextStyle(
                    fontSize: 13,
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
                        content: Text('هل أنت أتقن رغبتك في حذف "${expense.title}"؟'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('إلغاء'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('حذف',
                                style: TextStyle(color: Colors.white)),
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
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.centerLeft,
                child: const Icon(Icons.delete_outline_rounded,
                    color: Colors.white, size: 26),
              ),
              child: ExpenseCardItem(expense: expense),
            );
          }),
      ],
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
    final dateFormat = DateFormat('yyyy/MM/dd - hh:mm a');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: expense.category.color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                expense.category.icon,
                color: expense.category.color,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
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
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          expense.category.title,
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                theme.colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dateFormat.format(expense.date),
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                  if (expense.note.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      expense.note,
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
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
                  '-${expense.amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Colors.red.shade400,
                  ),
                ),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () {
                    notifier.toggleFavorite(expense.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(expense.isFavorite
                            ? 'تم إزالة العنصر من المفضلة'
                            : 'تمت إضافة العنصر للمفضلة ❤️'),
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Icon(
                      expense.isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: expense.isFavorite ? Colors.redAccent : Colors.grey,
                      size: 20,
                    ),
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
          'تحليل المصروفات حسب التصنيف',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 14),
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
                        sectionsSpace: 3,
                        centerSpaceRadius: 36,
                        sections: ExpenseCategory.values.map((cat) {
                          final amount = catTotals[cat] ?? 0;
                          final percentage =
                              total > 0 ? (amount / total) * 100 : 0.0;
                          return PieChartSectionData(
                            color: cat.color,
                            value: amount == 0 ? 0.01 : amount,
                            title: percentage > 7
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
                    spacing: 12,
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
                          const SizedBox(width: 6),
                          Text(
                            '${cat.title}: ${amount.toStringAsFixed(0)} ر.س',
                            style: const TextStyle(fontSize: 12),
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
            'تفاصيل الأقسام',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
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
                        Icon(cat.icon, color: cat.color, size: 22),
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
            const Icon(Icons.favorite_rounded, color: Colors.redAccent),
            const SizedBox(width: 8),
            Text(
              'المصروفات المفضلة والثابتة',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'يمكنك الاحتفاظ بالفواتير والمصروفات المتكررة هنا لسهولة المتابعة.',
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 16),
        if (favorites.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(
                  Icons.favorite_border_rounded,
                  size: 56,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 12),
                Text(
                  'قائمة المفضلة فارغة',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'انقر على أيقونة القلب في أي مصروف لإضافته هنا',
                  style: TextStyle(
                    fontSize: 13,
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
    const message = 'مرحباً، أود الاستفسار حول تطبيق أنا - مصروفاتي';
    final url = Uri.parse('https://wa.me/$phoneNumber?text=${Uri.encodeComponent(message)}');

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تعذر فتح تطبيق واتساب مباشرةً'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ عند الانتقال لـ واتساب'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showBudgetDialog(BuildContext context, AppStateNotifier notifier) {
    final controller =
        TextEditingController(text: notifier.monthlyBudget.toStringAsFixed(0));
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم تحديث الميزانية الشهرية بنجاح 🎯'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
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
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('الوضع الليلي (Dark Mode)',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('التبديل بين المظهر الفاتح والداكن'),
                value: notifier.isDarkMode,
                secondary: Icon(
                  notifier.isDarkMode
                      ? Icons.dark_mode_rounded
                      : Icons.wb_sunny_rounded,
                  color: theme.colorScheme.primary,
                ),
                onChanged: (_) {
                  notifier.toggleTheme();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(notifier.isDarkMode
                          ? 'تم تفعيل الوضع الليلي 🌙'
                          : 'تم تفعيل الوضع الفاتح ☀️'),
                      duration: const Duration(seconds: 1),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.savings_rounded,
                    color: theme.colorScheme.primary),
                title: const Text('الميزانية الشهرية',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${notifier.monthlyBudget.toStringAsFixed(0)} ر.س'),
                trailing: const Icon(Icons.edit_rounded, size: 20),
                onTap: () => _showBudgetDialog(context, notifier),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'الدعم والتواصل',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.chat_bubble_rounded, color: Colors.green),
                title: const Text('تواصل معنا عبر واتساب',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('الدعم الفني والخدمة المباشرة'),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                onTap: () => _launchWhatsApp(context),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.info_outline_rounded, color: Colors.blue),
                title: Text('عن التطبيق',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('تطبيق أنا v1.0 - متابعة المصروفات بطريقة حديثة ومبسطة'),
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
          content: Text('تمت إضافة "${newItem.title}" بنجاح ✨'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'تسجيل مصروف جديد',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'عنوان المصروف (مثال: مشتريات البقالة)',
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
                  prefixIcon: const Icon(Icons.attach_money_rounded),
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
              const SizedBox(height: 16),

              const Text(
                'اختر التصنيف:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                      size: 18,
                      color: isSelected ? Colors.white : cat.color,
                    ),
                    label: Text(cat.title),
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
                  labelText: 'ملاحظة إضافية (اختياري)',
                  prefixIcon: const Icon(Icons.notes_rounded),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),

              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('إضافة إلى المفضلة / فواتير ثابتة'),
                value: _isFavorite,
                onChanged: (val) => setState(() => _isFavorite = val ?? false),
                activeColor: theme.colorScheme.primary,
              ),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _submit,
                  icon: const Icon(Icons.check_circle_rounded),
                  label: const Text(
                    'حفظ المصروف',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
