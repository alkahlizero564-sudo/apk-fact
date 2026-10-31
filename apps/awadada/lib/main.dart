import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';

// ==========================================
// MODELS & ENUMS
// ==========================================

enum TransactionType { expense, income }

enum TransactionCategory {
  food,
  transport,
  shopping,
  bills,
  entertainment,
  health,
  salary,
  investment,
  other,
}

extension CategoryExtension on TransactionCategory {
  String get title {
    switch (this) {
      case TransactionCategory.food:
        return 'طعام وشراب';
      case TransactionCategory.transport:
        return 'مواصلات ونقل';
      case TransactionCategory.shopping:
        return 'تسوق ومشتريات';
      case TransactionCategory.bills:
        return 'فواتير وخدمات';
      case TransactionCategory.entertainment:
        return 'ترفيه ورحلات';
      case TransactionCategory.health:
        return 'صحة وعناية';
      case TransactionCategory.salary:
        return 'راتب وعمل';
      case TransactionCategory.investment:
        return 'استثمار واسترداد';
      case TransactionCategory.other:
        return 'تصنيف آخر';
    }
  }

  IconData get icon {
    switch (this) {
      case TransactionCategory.food:
        return Icons.restaurant_rounded;
      case TransactionCategory.transport:
        return Icons.directions_car_rounded;
      case TransactionCategory.shopping:
        return Icons.shopping_bag_rounded;
      case TransactionCategory.bills:
        return Icons.receipt_long_rounded;
      case TransactionCategory.entertainment:
        return Icons.sports_esports_rounded;
      case TransactionCategory.health:
        return Icons.medical_services_rounded;
      case TransactionCategory.salary:
        return Icons.account_balance_wallet_rounded;
      case TransactionCategory.investment:
        return Icons.trending_up_rounded;
      case TransactionCategory.other:
        return Icons.category_rounded;
    }
  }

  Color get color {
    switch (this) {
      case TransactionCategory.food:
        return const Color(0xFFF59E0B);
      case TransactionCategory.transport:
        return const Color(0xFF3B82F6);
      case TransactionCategory.shopping:
        return const Color(0xFFEC4899);
      case TransactionCategory.bills:
        return const Color(0xFFEF4444);
      case TransactionCategory.entertainment:
        return const Color(0xFF8B5CF6);
      case TransactionCategory.health:
        return const Color(0xFF10B981);
      case TransactionCategory.salary:
        return const Color(0xFF059669);
      case TransactionCategory.investment:
        return const Color(0xFF6366F1);
      case TransactionCategory.other:
        return const Color(0xFF64748B);
    }
  }
}

class TransactionItem {
  final String id;
  final String title;
  final double amount;
  final TransactionType type;
  final TransactionCategory category;
  final DateTime date;
  final String paymentMethod;
  final String? note;

  TransactionItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    required this.paymentMethod,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'type': type.index,
        'category': category.index,
        'date': date.toIso8601String(),
        'paymentMethod': paymentMethod,
        'note': note,
      };

  factory TransactionItem.fromJson(Map<String, dynamic> json) => TransactionItem(
        id: json['id'],
        title: json['title'],
        amount: (json['amount'] as num).toDouble(),
        type: TransactionType.values[json['type']],
        category: TransactionCategory.values[json['category']],
        date: DateTime.parse(json['date']),
        paymentMethod: json['paymentMethod'] ?? 'نقداً',
        note: json['note'],
      );
}

class SavingsGoal {
  final String id;
  final String title;
  final double targetAmount;
  double currentAmount;
  final DateTime targetDate;
  final Color color;

  SavingsGoal({
    required this.id,
    required this.title,
    required this.targetAmount,
    this.currentAmount = 0.0,
    required this.targetDate,
    required this.color,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'targetAmount': targetAmount,
        'currentAmount': currentAmount,
        'targetDate': targetDate.toIso8601String(),
        'colorValue': color.toARGB32(),
      };

  factory SavingsGoal.fromJson(Map<String, dynamic> json) => SavingsGoal(
        id: json['id'],
        title: json['title'],
        targetAmount: (json['targetAmount'] as num).toDouble(),
        currentAmount: (json['currentAmount'] as num).toDouble(),
        targetDate: DateTime.parse(json['targetDate']),
        color: Color(json['colorValue'] ?? 0xFF0F766E),
      );
}

// ==========================================
// PROVIDER (STATE MANAGEMENT)
// ==========================================

class ExpenseProvider extends ChangeNotifier {
  List<TransactionItem> _transactions = [];
  List<SavingsGoal> _goals = [];
  double _monthlyBudget = 5000.0;
  String _currency = 'ر.س';
  bool _isDarkMode = false;
  String _searchQuery = '';
  TransactionCategory? _selectedCategoryFilter;

  ExpenseProvider() {
    _loadData();
  }

  List<TransactionItem> get transactions {
    return _transactions.where((tx) {
      final matchesSearch = tx.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (tx.note?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      final matchesCategory = _selectedCategoryFilter == null || tx.category == _selectedCategoryFilter;
      return matchesSearch && matchesCategory;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  List<SavingsGoal> get goals => _goals;
  double get monthlyBudget => _monthlyBudget;
  String get currency => _currency;
  bool get isDarkMode => _isDarkMode;
  TransactionCategory? get selectedCategoryFilter => _selectedCategoryFilter;

  double get totalIncome => _transactions
      .where((t) => t.type == TransactionType.income)
      .fold(0.0, (sum, item) => sum + item.amount);

  double get totalExpense => _transactions
      .where((t) => t.type == TransactionType.expense)
      .fold(0.0, (sum, item) => sum + item.amount);

  double get currentBalance => totalIncome - totalExpense;

  double get currentMonthExpenses {
    final now = DateTime.now();
    return _transactions
        .where((t) =>
            t.type == TransactionType.expense &&
            t.date.month == now.month &&
            t.date.year == now.year)
        .fold(0.0, (sum, item) => sum + item.amount);
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCategoryFilter(TransactionCategory? category) {
    _selectedCategoryFilter = category;
    notifyListeners();
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    _saveData();
    notifyListeners();
  }

  void setCurrency(String newCurrency) {
    _currency = newCurrency;
    _saveData();
    notifyListeners();
  }

  void setMonthlyBudget(double amount) {
    _monthlyBudget = amount;
    _saveData();
    notifyListeners();
  }

  void addTransaction(TransactionItem transaction) {
    _transactions.insert(0, transaction);
    _saveData();
    notifyListeners();
  }

  void deleteTransaction(String id) {
    _transactions.removeWhere((t) => t.id == id);
    _saveData();
    notifyListeners();
  }

  void addGoal(SavingsGoal goal) {
    _goals.add(goal);
    _saveData();
    notifyListeners();
  }

  void updateGoalAmount(String id, double addedAmount) {
    final index = _goals.indexWhere((g) => g.id == id);
    if (index != -1) {
      _goals[index].currentAmount += addedAmount;
      _saveData();
      notifyListeners();
    }
  }

  void deleteGoal(String id) {
    _goals.removeWhere((g) => g.id == id);
    _saveData();
    notifyListeners();
  }

  // Local Storage Logic
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool('isDarkMode') ?? false;
    _currency = prefs.getString('currency') ?? 'ر.س';
    _monthlyBudget = prefs.getDouble('monthlyBudget') ?? 5000.0;

    final txString = prefs.getString('transactions');
    if (txString != null) {
      final List decoded = json.decode(txString);
      _transactions = decoded.map((item) => TransactionItem.fromJson(item)).toList();
    } else {
      // Seed Demo Data
      _transactions = [
        TransactionItem(
          id: const Uuid().v4(),
          title: 'راتب الشهر الحالي',
          amount: 8500.0,
          type: TransactionType.income,
          category: TransactionCategory.salary,
          date: DateTime.now().subtract(const Duration(days: 4)),
          paymentMethod: 'تحويل بنكي',
          note: 'الراتب الأساسي',
        ),
        TransactionItem(
          id: const Uuid().v4(),
          title: 'مشتريات السوبرماركت',
          amount: 345.5,
          type: TransactionType.expense,
          category: TransactionCategory.food,
          date: DateTime.now().subtract(const Duration(days: 1)),
          paymentMethod: 'بطاقة مدى',
          note: 'أغراض المنزل الأسبوعية',
        ),
        TransactionItem(
          id: const Uuid().v4(),
          title: 'فاتورة الكهرباء والماء',
          amount: 210.0,
          type: TransactionType.expense,
          category: TransactionCategory.bills,
          date: DateTime.now().subtract(const Duration(days: 2)),
          paymentMethod: 'بطاقة سداد',
        ),
        TransactionItem(
          id: const Uuid().v4(),
          title: 'وقود السيارة',
          amount: 120.0,
          type: TransactionType.expense,
          category: TransactionCategory.transport,
          date: DateTime.now(),
          paymentMethod: 'نقداً',
        ),
      ];
    }

    final goalString = prefs.getString('goals');
    if (goalString != null) {
      final List decoded = json.decode(goalString);
      _goals = decoded.map((item) => SavingsGoal.fromJson(item)).toList();
    } else {
      _goals = [
        SavingsGoal(
          id: const Uuid().v4(),
          title: 'صندوق الطوارئ',
          targetAmount: 10000.0,
          currentAmount: 4200.0,
          targetDate: DateTime.now().add(const Duration(days: 180)),
          color: const Color(0xFF0F766E),
        ),
        SavingsGoal(
          id: const Uuid().v4(),
          title: 'رحلة الصيف',
          targetAmount: 6000.0,
          currentAmount: 1800.0,
          targetDate: DateTime.now().add(const Duration(days: 90)),
          color: const Color(0xFF3B82F6),
        ),
      ];
    }
    notifyListeners();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _isDarkMode);
    await prefs.setString('currency', _currency);
    await prefs.setDouble('monthlyBudget', _monthlyBudget);

    final txString = json.encode(_transactions.map((t) => t.toJson()).toList());
    await prefs.setString('transactions', txString);

    final goalString = json.encode(_goals.map((g) => g.toJson()).toList());
    await prefs.setString('goals', goalString);
  }
}

// ==========================================
// MAIN APP ENTRY
// ==========================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ExpenseProvider(),
      child: const AwadadaApp(),
    ),
  );
}

class AwadadaApp extends StatelessWidget {
  const AwadadaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);

    return MaterialApp(
      title: 'عوادادة - مصروفاتي',
      debugShowCheckedModeBanner: false,
      themeMode: provider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E), // Elegant Emerald/Teal
          brightness: Brightness.light,
        ),
        fontFamily: 'Roboto',
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.dark,
        ),
        fontFamily: 'Roboto',
      ),
      builder: (context, child) {
        // Enforce Arabic RTL Layout
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: const MainNavigationScreen(),
    );
  }
}

// ==========================================
// MAIN NAVIGATION & NAVIGATION BAR
// ==========================================

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    ReportsScreen(),
    BudgetGoalsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _screens[_currentIndex],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet_rounded),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.donut_small_outlined),
            selectedIcon: Icon(Icons.donut_small_rounded),
            label: 'التقارير',
          ),
          NavigationDestination(
            icon: Icon(Icons.savings_outlined),
            selectedIcon: Icon(Icons.savings_rounded),
            label: 'الميزانية والأهداف',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune_rounded),
            label: 'الإعدادات',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddTransactionModal(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('إضافة معاملة'),
        elevation: 4,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  void _openAddTransactionModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const AddTransactionModal(),
    );
  }
}

// ==========================================
// SCREEN 1: HOME SCREEN (DASHBOARD & RECENT TX)
// ==========================================

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.account_balance_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'عوادادة',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                Text(
                  'إدارة المصروفات اليومية',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(provider.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            onPressed: () => provider.toggleTheme(),
            tooltip: 'تغيير المظهر',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overview Card
            const BalanceOverviewCard().animate().fadeIn().slideY(begin: -0.1, end: 0),
            const SizedBox(height: 20),

            // Budget Progress Summary
            const MonthlyBudgetBar().animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 20),

            // Search and Category Filter
            const SearchAndFilterSection(),
            const SizedBox(height: 16),

            // Recent Transactions Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'المعاملات المالية',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  ' العدد: ${provider.transactions.length}',
                  style: TextStyle(color: Theme.of(context).colorScheme.outline),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Transactions List
            provider.transactions.isEmpty
                ? const EmptyStateWidget()
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: provider.transactions.length,
                    itemBuilder: (context, index) {
                      final item = provider.transactions[index];
                      return TransactionListTile(item: item)
                          .animate()
                          .fadeIn(delay: Duration(milliseconds: 50 * index))
                          .slideX(begin: 0.1, end: 0);
                    },
                  ),
            const SizedBox(height: 80), // Padding for FAB
          ],
        ),
      ),
    );
  }
}

class BalanceOverviewCard extends StatelessWidget {
  const BalanceOverviewCard({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.primary.withRed(30),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'إجمالي الرصيد الحالي',
            style: TextStyle(
              color: theme.colorScheme.onPrimary.withValues(alpha: 0.85),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${provider.currentBalance.toStringAsFixed(2)} ${provider.currency}',
            style: TextStyle(
              color: theme.colorScheme.onPrimary,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.tealAccent.withValues(alpha: 0.2),
                        child: const Icon(Icons.arrow_downward_rounded, color: Colors.greenAccent, size: 20),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('الدخل', style: TextStyle(color: theme.colorScheme.onPrimary.withValues(alpha: 0.7), fontSize: 12)),
                          Text(
                            '${provider.totalIncome.toStringAsFixed(1)} ${provider.currency}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(height: 30, width: 1, color: Colors.white24),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                        child: const Icon(Icons.arrow_upward_rounded, color: Colors.redAccent, size: 20),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('المصروفات', style: TextStyle(color: theme.colorScheme.onPrimary.withValues(alpha: 0.7), fontSize: 12)),
                          Text(
                            '${provider.totalExpense.toStringAsFixed(1)} ${provider.currency}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
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
}

class MonthlyBudgetBar extends StatelessWidget {
  const MonthlyBudgetBar({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);
    final spent = provider.currentMonthExpenses;
    final budget = provider.monthlyBudget;
    final ratio = (spent / (budget == 0 ? 1 : budget)).clamp(0.0, 1.0);
    final isOver = spent > budget;

    return Card(
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.pie_chart_outline_rounded, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'الميزانية الشهرية',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                Text(
                  '${spent.toStringAsFixed(0)} / ${budget.toStringAsFixed(0)} ${provider.currency}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isOver ? Colors.red : Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 10,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                color: isOver ? Colors.red : (ratio > 0.85 ? Colors.orange : Theme.of(context).colorScheme.primary),
              ),
            ),
            if (isOver) ...[
              const SizedBox(height: 8),
              const Text(
                ' تنبيه: لقد تجاوزت الميزانية المحددة لهذا الشهر!',
                style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

class SearchAndFilterSection extends StatelessWidget {
  const SearchAndFilterSection({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);

    return Column(
      children: [
        TextField(
          onChanged: (val) => provider.setSearchQuery(val),
          decoration: InputDecoration(
            hintText: 'البحث في المعاملات...',
            prefixIcon: const Icon(Icons.search_rounded),
            filled: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              FilterChip(
                label: const Text('الكل'),
                selected: provider.selectedCategoryFilter == null,
                onSelected: (_) => provider.setCategoryFilter(null),
              ),
              const SizedBox(width: 8),
              ...TransactionCategory.values.map((cat) {
                return Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: FilterChip(
                    avatar: Icon(cat.icon, size: 16, color: cat.color),
                    label: Text(cat.title),
                    selected: provider.selectedCategoryFilter == cat,
                    onSelected: (selected) {
                      provider.setCategoryFilter(selected ? cat : null);
                    },
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

class TransactionListTile extends StatelessWidget {
  final TransactionItem item;
  const TransactionListTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    final isExpense = item.type == TransactionType.expense;
    final formattedDate = DateFormat('yyyy/MM/dd - hh:mm a').format(item.date);

    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.startToEnd,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      onDismissed: (_) {
        provider.deleteTransaction(item.id);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف المعاملة')),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: item.category.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.category.icon, color: item.category.color),
          ),
          title: Text(
            item.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                '${item.category.title} • ${item.paymentMethod}',
                style: const TextStyle(fontSize: 12),
              ),
              if (item.note != null && item.note!.isNotEmpty)
                Text(
                  item.note!,
                  style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline),
                ),
              Text(
                formattedDate,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
          trailing: Text(
            '${isExpense ? '-' : '+'}${item.amount.toStringAsFixed(2)} ${provider.currency}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isExpense ? Colors.redAccent : Colors.green,
            ),
          ),
        ),
      ),
    );
  }
}

class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text(
              'لا يوجد معاملات مالية مسجلة',
              style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'اضغط على زر "إضافة معاملة" لبدء تتبع مصاريفك',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// SCREEN 2: REPORTS & ANALYTICS (FL_CHART)
// ==========================================

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);
    final categoryTotals = _calculateCategoryExpenses(provider.transactions);

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير والإحصائيات'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'توزيع المصروفات حسب التصنيف',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Pie Chart Widget
            categoryTotals.isEmpty
                ? const SizedBox(
                    height: 200,
                    child: Center(child: Text('لا تتوفر بيانات كافية للرسم البياني')),
                  )
                : SizedBox(
                    height: 220,
                    child: PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (FlTouchEvent event, pieTouchResponse) {
                            setState(() {
                              if (!event.isInterestedForInteractions ||
                                  pieTouchResponse == null ||
                                  pieTouchResponse.touchedSection == null) {
                                _touchedIndex = -1;
                                return;
                              }
                              _touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                            });
                          },
                        ),
                        borderData: FlBorderData(show: false),
                        sectionsSpace: 3,
                        centerSpaceRadius: 40,
                        sections: _generatePieSections(categoryTotals),
                      ),
                    ),
                  ),

            const SizedBox(height: 24),
            const Text(
              'تفاصيل الإنفاق حسب القطاع',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            ...categoryTotals.entries.map((entry) {
              final cat = entry.key;
              final amount = entry.value;
              final percentage = (amount / (provider.totalExpense == 0 ? 1 : provider.totalExpense)) * 100;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: cat.color.withValues(alpha: 0.2),
                        child: Icon(cat.icon, color: cat.color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cat.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: percentage / 100,
                                minHeight: 6,
                                color: cat.color,
                                backgroundColor: Colors.grey.shade200,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${amount.toStringAsFixed(1)} ${provider.currency}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${percentage.toStringAsFixed(1)}%',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Map<TransactionCategory, double> _calculateCategoryExpenses(List<TransactionItem> transactions) {
    final Map<TransactionCategory, double> totals = {};
    for (var tx in transactions) {
      if (tx.type == TransactionType.expense) {
        totals[tx.category] = (totals[tx.category] ?? 0.0) + tx.amount;
      }
    }
    return totals;
  }

  List<PieChartSectionData> _generatePieSections(Map<TransactionCategory, double> totals) {
    int i = 0;
    return totals.entries.map((entry) {
      final isTouched = i == _touchedIndex;
      final fontSize = isTouched ? 16.0 : 12.0;
      final radius = isTouched ? 60.0 : 50.0;
      final cat = entry.key;
      final amount = entry.value;

      i++;
      return PieChartSectionData(
        color: cat.color,
        value: amount,
        title: amount.toStringAsFixed(0),
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();
  }
}

// ==========================================
// SCREEN 3: BUDGET & SAVINGS GOALS
// ==========================================

class BudgetGoalsScreen extends StatelessWidget {
  const BudgetGoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الميزانية والأهداف'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Set Monthly Budget Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
              color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 24,
                      child: Icon(Icons.account_balance_rounded),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('حد الميزانية الشهري', style: TextStyle(fontSize: 12)),
                          Text(
                            '${provider.monthlyBudget.toStringAsFixed(0)} ${provider.currency}',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.edit_rounded),
                      onPressed: () => _showEditBudgetDialog(context, provider),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Goals Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'أهداف التوفير والادخار',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () => _openAddGoalModal(context),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('هدف جديد'),
                ),
              ],
            ),
            const SizedBox(height: 12),

            provider.goals.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('لا توجد أهداف توفير حالية. أضف هدفك الأول الآن!'),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: provider.goals.length,
                    itemBuilder: (context, index) {
                      final goal = provider.goals[index];
                      final progress = (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    goal.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                                    onPressed: () => provider.deleteGoal(goal.id),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'تم ادخار ${goal.currentAmount.toStringAsFixed(0)} من ${goal.targetAmount.toStringAsFixed(0)} ${provider.currency}',
                                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                                  ),
                                  Text(
                                    '${(progress * 100).toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 8,
                                  color: goal.color,
                                  backgroundColor: goal.color.withValues(alpha: 0.15),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton.icon(
                                  onPressed: () => _showAddMoneyToGoalDialog(context, provider, goal),
                                  icon: const Icon(Icons.add_circle_outline, size: 18),
                                  label: const Text('إضافة للرصيد'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: Duration(milliseconds: index * 100));
                    },
                  ),
          ],
        ),
      ),
    );
  }

  void _showEditBudgetDialog(BuildContext context, ExpenseProvider provider) {
    final controller = TextEditingController(text: provider.monthlyBudget.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تعديل الميزانية الشهرية'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'المبلغ المحدد (${provider.currency})',
            border: const OutlineInputBorder(),
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
                provider.setMonthlyBudget(val);
                Navigator.pop(ctx);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  void _showAddMoneyToGoalDialog(BuildContext context, ExpenseProvider provider, SavingsGoal goal) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('إضافة مبلغ إلى ${goal.title}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'المبلغ المضاف (${provider.currency})',
            border: const OutlineInputBorder(),
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
                provider.updateGoalAmount(goal.id, val);
                Navigator.pop(ctx);
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  void _openAddGoalModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const AddGoalModal(),
    );
  }
}

// ==========================================
// SCREEN 4: SETTINGS SCREEN
// ==========================================

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('الوضع الداكن (Dark Mode)'),
            subtitle: const Text('تغيير مظهر التطبيق إلى الألوان الداكنة'),
            value: provider.isDarkMode,
            onChanged: (val) => provider.toggleTheme(),
            secondary: const Icon(Icons.dark_mode_outlined),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.payments_outlined),
            title: const Text('العملة المستخدمة'),
            subtitle: Text('العملة الحالية: ${provider.currency}'),
            trailing: DropdownButton<String>(
              value: provider.currency,
              underline: const SizedBox(),
              items: ['ر.س', 'د.إ', 'ج.م', '\$', '€', 'د.ت'].map((c) {
                return DropdownMenuItem(value: c, child: Text(c));
              }).toList(),
              onChanged: (val) {
                if (val != null) provider.setCurrency(val);
              },
            ),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info_outline_rounded),
            title: Text('عن التطبيق'),
            subtitle: Text('عوادادة v1.0.0 - تطبيق إدارة المصروفات الشخصية'),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// MODAL: ADD TRANSACTION
// ==========================================

class AddTransactionModal extends StatefulWidget {
  const AddTransactionModal({super.key});

  @override
  State<AddTransactionModal> createState() => _AddTransactionModalState();
}

class _AddTransactionModalState extends State<AddTransactionModal> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  TransactionType _type = TransactionType.expense;
  TransactionCategory _category = TransactionCategory.food;
  String _paymentMethod = 'نقداً';
  final DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context, listen: false);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'إضافة معاملة جديدة',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Expense / Income Toggle Switch
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text('مصروف'),
                  icon: Icon(Icons.arrow_upward_rounded),
                ),
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text('دخل'),
                  icon: Icon(Icons.arrow_downward_rounded),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (set) {
                setState(() {
                  _type = set.first;
                });
              },
            ),
            const SizedBox(height: 16),

            // Title Input
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'عنوان المعاملة (مثلاً: مشتريات، راتب)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Amount Input
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'المبلغ (${provider.currency})',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Category Selection Dropdown
            DropdownButtonFormField<TransactionCategory>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: 'التصنيف',
                border: OutlineInputBorder(),
              ),
              items: TransactionCategory.values.map((cat) {
                return DropdownMenuItem(
                  value: cat,
                  child: Row(
                    children: [
                      Icon(cat.icon, color: cat.color, size: 20),
                      const SizedBox(width: 8),
                      Text(cat.title),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _category = val);
              },
            ),
            const SizedBox(height: 12),

            // Payment Method Selection
            DropdownButtonFormField<String>(
              initialValue: _paymentMethod,
              decoration: const InputDecoration(
                labelText: 'طريقة الدفع',
                border: OutlineInputBorder(),
              ),
              items: ['نقداً', 'بطاقة مدى', 'بطاقة ائتمانية', 'تحويل بنكي', 'أخرى']
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _paymentMethod = val);
              },
            ),
            const SizedBox(height: 12),

            // Note Input
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'ملاحظة إضافية (اختياري)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  final title = _titleController.text.trim();
                  final amount = double.tryParse(_amountController.text);

                  if (title.isEmpty || amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('الرجاء إدخال البيانات بشكل صحيح')),
                    );
                    return;
                  }

                  final newTx = TransactionItem(
                    id: const Uuid().v4(),
                    title: title,
                    amount: amount,
                    type: _type,
                    category: _category,
                    date: _selectedDate,
                    paymentMethod: _paymentMethod,
                    note: _noteController.text.trim(),
                  );

                  provider.addTransaction(newTx);
                  Navigator.pop(context);
                },
                child: const Text('حفظ المعاملة', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// MODAL: ADD SAVINGS GOAL
// ==========================================

class AddGoalModal extends StatefulWidget {
  const AddGoalModal({super.key});

  @override
  State<AddGoalModal> createState() => _AddGoalModalState();
}

class _AddGoalModalState extends State<AddGoalModal> {
  final _titleController = TextEditingController();
  final _targetAmountController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context, listen: false);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'إضافة هدف ادخار جديد',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'اسم الهدف (مثلاً: شراء سيارة، سفر)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _targetAmountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'المبلغ المستهدف (${provider.currency})',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                final title = _titleController.text.trim();
                final target = double.tryParse(_targetAmountController.text);

                if (title.isEmpty || target == null || target <= 0) {
                  return;
                }

                final newGoal = SavingsGoal(
                  id: const Uuid().v4(),
                  title: title,
                  targetAmount: target,
                  targetDate: DateTime.now().add(const Duration(days: 90)),
                  color: Theme.of(context).colorScheme.primary,
                );

                provider.addGoal(newGoal);
                Navigator.pop(context);
              },
              child: const Text('إضافة الهدف'),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
