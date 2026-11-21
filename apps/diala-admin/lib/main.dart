import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// ==========================================
// SUPABASE CONSTANTS & FIREBASE ENTRY POINT
// ==========================================
const String supabaseUrl = "https://jvjtgzewumfecjdpekna.supabase.co";
const String supabaseAnonKey =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp2anRnemV3dW1mZWNqZHBla25hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE2NDYzMzcsImV4cCI6MjEwNzIyMjMzN30.1gck73ek8ErBtcF7xAtFVNej_mptBE";

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (_) {}

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: const DialaAdminApp(),
    ),
  );
}

// ==========================================
// APP STATE MANAGEMENT
// ==========================================
class AppState extends ChangeNotifier {
  bool isAuthenticated = false;
  String userEmail = 'admin@dmc.medical.sd';
  String userRole = 'مدير (Administrator)';
  int currentTab = 0; // 0: الرئيسية, 1: الطلبات, 2: المخزن, 3: التسعير, 4: الإدارة

  // Data Collections
  double dollarRate = 2850.0;
  double profitMargin = 15.0;
  String roundingRule = 'أقرب 500 ج.س';

  List<Map<String, dynamic>> deliveryZones = [
    {'id': 1, 'name': 'عطبرة', 'price': 10000, 'active': true},
    {'id': 2, 'name': 'بربر', 'price': 15000, 'active': true},
    {'id': 3, 'name': 'الدامر', 'price': 12000, 'active': true},
    {'id': 4, 'name': 'أبوحمد', 'price': 25000, 'active': false},
  ];

  List<Map<String, dynamic>> paymentAccounts = [
    {
      'id': 1,
      'number': '3829104',
      'holder': 'شركة DMC للمعدات الطبية',
      'bank': 'بنك الخرطوم (بنكك)',
      'active': true
    }
  ];

  List<Map<String, dynamic>> activityLogs = [
    {
      'user': 'د. طارق (مدير)',
      'action': 'قام بتحديث سعر الدولار من 2,800 إلى 2,850 ج.س',
      'time': 'أمس، 14:30'
    },
    {
      'user': 'أحمد محمد (محاسب)',
      'action': 'قام بتأكيد إشعار تحويل بنكك للطلب #DMC-8480',
      'time': 'أمس، 11:15'
    },
    {
      'user': 'خالد عمر (مخزن)',
      'action': 'قام بمسح فاتورة مورّد جديدة #INV-5049',
      'time': 'قبل يومين'
    },
  ];

  void login(String email, String role) {
    userEmail = email;
    userRole = role;
    isAuthenticated = true;
    notifyListeners();
  }

  void logout() {
    isAuthenticated = false;
    currentTab = 0;
    notifyListeners();
  }

  void setTab(int index) {
    currentTab = index;
    notifyListeners();
  }

  void updateDollarRate(double rate, double margin, String rounding) {
    dollarRate = rate;
    profitMargin = margin;
    roundingRule = rounding;
    activityLogs.insert(0, {
      'user': 'د. طارق (مدير)',
      'action': 'قام بتحديث سعر الدولار إلى $rate ج.س',
      'time': 'الآن'
    });
    notifyListeners();
  }

  void toggleZone(int id) {
    final idx = deliveryZones.indexWhere((z) => z['id'] == id);
    if (idx != -1) {
      deliveryZones[idx]['active'] = !deliveryZones[idx]['active'];
      notifyListeners();
    }
  }

  void addZone(String name, double price) {
    deliveryZones.add({
      'id': deliveryZones.length + 1,
      'name': name,
      'price': price,
      'active': true
    });
    notifyListeners();
  }

  void addStaffLog(String staffName, String action) {
    activityLogs.insert(0, {
      'user': staffName,
      'action': action,
      'time': 'الآن'
    });
    notifyListeners();
  }
}

// ==========================================
// MAIN APP ENTRY & THEME
// ==========================================
class DialaAdminApp extends StatelessWidget {
  const DialaAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    const surfaceDark = Color(0xFF1C2541);
    const surfaceCard = Color(0xFF22304A);
    const goldAccent = Color(0xFFD4AF37);

    return MaterialApp(
      title: 'Diala Admin',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'SD'),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F2C59),
          brightness: Brightness.light,
          primary: const Color(0xFF0F2C59),
          secondary: goldAccent,
        ),
        fontFamily: 'Segoe UI',
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF050B14),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F2C59),
          brightness: Brightness.dark,
          primary: const Color(0xFF0F2C59),
          secondary: goldAccent,
          surface: surfaceDark,
        ),
        cardTheme: CardThemeData(
          color: surfaceCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Colors.white10),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0B132B),
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            fontFamily: 'Segoe UI',
          ),
        ),
        fontFamily: 'Segoe UI',
      ),
      home: const MainAppShell(),
    );
  }
}

// ==========================================
// MAIN APP SHELL & NAVIGATION
// ==========================================
class MainAppShell extends StatelessWidget {
  const MainAppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (!state.isAuthenticated) {
      return const AuthScreen();
    }

    final screens = [
      const DashboardScreen(),
      const OrdersScreen(),
      const InventoryScreen(),
      const PricingScreen(),
      const AdminManagementScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: state.currentTab,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: state.currentTab,
        onTap: (index) => state.setTab(index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: const Color(0xF30B132B),
        selectedItemColor: const Color(0xFFD4AF37),
        unselectedItemColor: const Color(0xFF8D99AE),
        selectedFontSize: 11,
        unselectedFontSize: 11,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            label: 'الرئيسية',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            label: 'الطلبات',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'المخزن',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money_rounded),
            label: 'التسعير',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            label: 'الإدارة',
          ),
        ],
      ),
    );
  }
}

// ==========================================
// SCREEN 1: AUTHENTICATION
// ==========================================
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailC = TextEditingController(text: 'admin@dmc.medical.sd');
  final _passC = TextEditingController(text: '••••••••••••');
  String _selectedRole = 'مدير (Administrator)';

  final List<String> _roles = [
    'مدير (Administrator)',
    'مبيعات (Sales)',
    'مخزن (Inventory)',
    'محاسب (Accountant)',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Brand Logo Area
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0F2C59), Color(0xFF1E3E62)],
                    ),
                    border: Border.all(color: const Color(0xFFD4AF37), width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x26D4AF37),
                        blurRadius: 20,
                      )
                    ],
                  ),
                  child: const Icon(
                    Icons.attach_money_rounded,
                    color: Color(0xFFD4AF37),
                    size: 36,
                  ),
                ).animate().scale(duration: 300.ms),
                const SizedBox(height: 12),
                const Text(
                  'Diala Admin',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'مشروع DMC للمعدات والمستهلكات الطبية',
                  style: TextStyle(color: Color(0xFF8D99AE), fontSize: 13),
                ),
                const SizedBox(height: 24),

                // Card Container
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'البريد الإلكتروني للإدارة',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8D99AE),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _emailC,
                          style: const TextStyle(fontSize: 14, color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF1C2541),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Colors.white10),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Colors.white10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        const Text(
                          'كلمة المرور الآمنة',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8D99AE),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _passC,
                          obscureText: true,
                          style: const TextStyle(fontSize: 14, color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF1C2541),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Colors.white10),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Colors.white10),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        const Text(
                          'الصلاحية / الدور',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8D99AE),
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedRole,
                          dropdownColor: const Color(0xFF1C2541),
                          style: const TextStyle(fontSize: 14, color: Colors.white),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFF1C2541),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Colors.white10),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: Colors.white10),
                            ),
                          ),
                          items: _roles.map((role) {
                            return DropdownMenuItem(
                              value: role,
                              child: Text(role),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedRole = val);
                          },
                        ),
                        const SizedBox(height: 20),

                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFD4AF37),
                              foregroundColor: const Color(0xFF050B14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 4,
                            ),
                            onPressed: () {
                              context.read<AppState>().login(_emailC.text, _selectedRole);
                            },
                            child: const Text(
                              'تسجيل الدخول الآمن',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
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
        ),
      ),
    );
  }
}

// ==========================================
// SCREEN 2: DASHBOARD
// ==========================================
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  void _requestNotificationPermission(BuildContext context) async {
    try {
      NotificationSettings settings =
          await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم رفض الإشعارات. يمكن تغيير ذلك من إعدادات الهاتف.'),
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تفعيل إشعارات التطبيق بنجاح')),
          );
        }
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تنبيه: خدمات الإشعارات تعمل في الوضع التلقائي')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'مرحباً، د. طارق',
              style: TextStyle(fontSize: 12, color: Color(0xFF8D99AE)),
            ),
            Text(
              'لوحة القيادة (Dashboard)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(left: 16),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF22304A),
              border: Border.all(color: Colors.white10),
            ),
            child: IconButton(
              icon: const Icon(Icons.notifications_none, size: 20),
              onPressed: () => _requestNotificationPermission(context),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // KPI Grid
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildKpiCard('مبيعات اليوم', '4,850,000 ج.س', '↑ 12% عن الأمس', const Color(0xFF2A9D8F)),
              _buildKpiCard('الطلبات الجديدة', '14 طلب', 'بانتظار المعالجة', const Color(0xFFD4AF37)),
              _buildKpiCard('سعر الدولار اليوم', '${state.dollarRate.toInt()} ج.س', 'محدث منذ ساعتين', const Color(0xFFE9C46A)),
              _buildKpiCard('تنبيهات المخزون', '3 منتجات', 'قرب النفاد', const Color(0xFFE76F51)),
            ],
          ),

          const SizedBox(height: 16),

          // Sales Chart Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'إحصائيات المبيعات الأسبوعية',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0x26D4AF37),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(color: const Color(0x4DD4AF37)),
                        ),
                        child: const Text(
                          'أبريل 2025',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD4AF37),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Simulated Bar Chart
                  SizedBox(
                    height: 120,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildBarItem('السبت', 0.4, false),
                        _buildBarItem('الأحد', 0.65, false),
                        _buildBarItem('الإثنين', 0.5, false),
                        _buildBarItem('الثلاثاء', 0.85, false),
                        _buildBarItem('الأربعاء', 0.95, true),
                      ],
                    ),
                  ),

                  const Divider(height: 24, color: Colors.white10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'إجمالي الأسبوع: 24.5 مليون ج.س',
                        style: TextStyle(fontSize: 11, color: Color(0xFF8D99AE)),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ReportsScreen()),
                          );
                        },
                        child: const Text(
                          'التقرير الكامل ←',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFD4AF37),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, String trend, Color trendColor) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 12, color: Color(0xFF8D99AE)),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              trend,
              style: TextStyle(fontSize: 11, color: trendColor, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarItem(String label, double heightRatio, bool isActive) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: isActive ? const Color(0xFFD4AF37) : const Color(0xFF8D99AE),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 32,
          height: 80 * heightRatio,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFFD4AF37) : const Color(0xFF1C2541),
            borderRadius: BorderRadius.circular(4),
            boxShadow: isActive
                ? const [
                    BoxShadow(
                      color: Color(0x4DD4AF37),
                      blurRadius: 8,
                    )
                  ]
                : null,
          ),
        ),
      ],
    );
  }
}

// ==========================================
// SCREEN 3: ORDERS MANAGEMENT
// ==========================================
class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  void _showBankakModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B132B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'مراجعة إشعار تحويل بنكك',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF1C2541),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              child: const Center(
                child: Text(
                  '[صورة إشعار التحويل المرفوعة من الزبون]',
                  style: TextStyle(color: Color(0xFF8D99AE), fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'المبلغ المطلوب: 535,000 ج.س | المطابق: نعم\nرقم العملية: 849201 | اسم الحساب: مستشفى الأمل',
              style: TextStyle(fontSize: 13, color: Color(0xFF8D99AE)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2A9D8F),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 44),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('تأكيد الدفع وتحويل للتجهيز'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFE76F51),
                      side: const BorderSide(color: Color(0xFFE76F51)),
                      minimumSize: const Size(0, 44),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('رفض السبب'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showQuotationModal(BuildContext context) {
    final priceC = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B132B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          top: 24,
          left: 24,
          right: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'الرد على طلب عرض السعر',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceC,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'السعر المقدم للزبون (ج.س)',
                filled: true,
                fillColor: Color(0xFF1C2541),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: const Color(0xFF050B14),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إرسال عرض السعر للعميل'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الطلبات والردود'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(left: 16.0),
            child: Icon(Icons.search),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Order 1
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'طلب #DMC-8492',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0x26E9C46A),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(color: const Color(0x4DE9C46A)),
                        ),
                        child: const Text(
                          'بانتظار تأكيد الدفع (بنكك)',
                          style: TextStyle(fontSize: 11, color: Color(0xFFE9C46A)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'الزبون: مستشفى الأمل التخصصي (عطبرة)\nالأصناف: جهاز تخطيط قلب (1) + قفازات (5)',
                    style: TextStyle(fontSize: 13, color: Color(0xFF8D99AE)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'الإجمالي: 535,000 ج.س',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD4AF37),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD4AF37),
                          foregroundColor: const Color(0xFF050B14),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        onPressed: () => _showBankakModal(context),
                        child: const Text('مراجعة إشعار بنكك', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Order 2
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'طلب عرض سعر #Q-1042',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0x26D4AF37),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(color: const Color(0x4DD4AF37)),
                        ),
                        child: const Text(
                          'طلب كميات كبيرة',
                          style: TextStyle(fontSize: 11, color: Color(0xFFD4AF37)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'الزبون: مركز النيل الطبي (الدامر)\nالأصناف: محاقن طبية 10 مل (50 كرتونة)',
                    style: TextStyle(fontSize: 13, color: Color(0xFF8D99AE)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'مطلوب عرض سعر خاص',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD4AF37),
                        ),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        onPressed: () => _showQuotationModal(context),
                        child: const Text('الرد على عرض السعر', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Order 3
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'طلب #DMC-8488',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0x262A9D8F),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(color: const Color(0x4D2A9D8F)),
                        ),
                        child: const Text(
                          'في الطريق (استلام)',
                          style: TextStyle(fontSize: 11, color: Color(0xFF2A9D8F)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'الزبون: صيدلية الشفا (بربر)\nالدفع: الدفع عند الاستلام',
                    style: TextStyle(fontSize: 13, color: Color(0xFF8D99AE)),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'الإجمالي: 18,500 ج.س',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFD4AF37),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2A9D8F),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        onPressed: () {},
                        child: const Text('تسجيل "تم استلام المبلغ"', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// SCREEN 4: PRODUCTS & INVENTORY MANAGEMENT
// ==========================================
class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  void _showAddProductModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B132B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          top: 24,
          left: 24,
          right: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'إضافة أو تعديل منتج وصورته للزبون',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),

            const Text(
              'صورة المنتج المرئية (يراها الزبون في التطبيق)',
              style: TextStyle(fontSize: 12, color: Color(0xFF8D99AE)),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: () async {
                final picker = ImagePicker();
                await picker.pickImage(source: ImageSource.gallery);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C2541),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0x1AD4AF37),
                      ),
                      child: const Icon(Icons.image, color: Color(0xFFD4AF37)),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'انقر لرفع صورة واضحة',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'PNG, JPG (تظهر مباشرة في متجر الزبون)',
                          style: TextStyle(fontSize: 11, color: Color(0xFF8D99AE)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            const TextField(
              decoration: InputDecoration(
                labelText: 'اسم المنتج الطبي',
                filled: true,
                fillColor: Color(0xFF1C2541),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: const [
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'السعر الأساسي (\$)',
                      filled: true,
                      fillColor: Color(0xFF1C2541),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'الكمية بالمخزن',
                      filled: true,
                      fillColor: Color(0xFF1C2541),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: const Color(0xFF050B14),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('حفظ ونشر المنتج مع صورته للزبائن'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المنتجات والمخزون'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddProductModal(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Item 1
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFE76F51), width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C2541),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: const Icon(Icons.monitor_heart, color: Color(0xFFD4AF37)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'جهاز تخطيط القلب ECG 12 قناة',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0x26E76F51),
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  child: const Text(
                                    'المخزون منخفض: 2 فقط',
                                    style: TextStyle(fontSize: 10, color: Color(0xFFE76F51)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'السعر الأساسي: \$160.00 | السعر بالجنيه: 450,000 ج.س',
                              style: TextStyle(fontSize: 12, color: Color(0xFF8D99AE)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: Colors.white10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'صورة مرئية للزبون مفعلة ✓',
                        style: TextStyle(fontSize: 12, color: Color(0xFFD4AF37)),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onPressed: () => _showAddProductModal(context),
                        child: const Text('تعديل الصورة والبيانات', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Item 2
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFE9C46A), width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C2541),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: const Icon(Icons.clean_hands_outlined, color: Color(0xFFD4AF37)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'قفازات لاتكس طبية (علبة 100)',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0x26E9C46A),
                                    borderRadius: BorderRadius.circular(50),
                                  ),
                                  child: const Text(
                                    'قرب انتهاء الصلاحية',
                                    style: TextStyle(fontSize: 10, color: Color(0xFFE9C46A)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'المخزون: 140 علبة | الصلاحية: 12/05/2025',
                              style: TextStyle(fontSize: 12, color: Color(0xFF8D99AE)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: Colors.white10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'صورة مرئية للزبون مفعلة ✓',
                        style: TextStyle(fontSize: 12, color: Color(0xFFE9C46A)),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onPressed: () => _showAddProductModal(context),
                        child: const Text('تعديل الصورة والبيانات', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// SCREEN 5: AUTOMATIC PRICING (USD)
// ==========================================
class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  late TextEditingController _rateC;
  late TextEditingController _marginC;
  String _selectedRounding = 'أقرب 500 ج.س';

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _rateC = TextEditingController(text: state.dollarRate.toInt().toString());
    _marginC = TextEditingController(text: state.profitMargin.toInt().toString());
  }

  void _showPreviewModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B132B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'معاينة تغييرات الأسعار',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'سعر الدولار الجديد: ${_rateC.text} ج.س (تمت إضافة هامش ربح ${_marginC.text}% وتطبيق التقريب)',
              style: const TextStyle(fontSize: 13, color: Color(0xFF8D99AE)),
            ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('جهاز تخطيط القلب ECG', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('السعر القديم: 430,000 ج.س', style: TextStyle(fontSize: 12, color: Color(0xFF8D99AE))),
                        Text('السعر الجديد: 450,000 ج.س', style: TextStyle(fontSize: 12, color: Color(0xFFD4AF37), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: const Color(0xFF050B14),
                ),
                onPressed: () {
                  final r = double.tryParse(_rateC.text) ?? 2850;
                  final m = double.tryParse(_marginC.text) ?? 15;
                  context.read<AppState>().updateDollarRate(r, m, _selectedRounding);
                  Navigator.pop(ctx);
                },
                child: const Text('تأكيد وتحديث الأسعار للزبائن فوراً'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التسعير التلقائي (سعر الدولار)'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFD4AF37)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'تحديث سعر الدولار اليوم',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD4AF37),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'سعر الدولار الحالي (جنيه سوداني)',
                    style: TextStyle(fontSize: 12, color: Color(0xFF8D99AE)),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _rateC,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD4AF37),
                    ),
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: Color(0xFF1C2541),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'هامش الربح الإضافي (%)',
                    style: TextStyle(fontSize: 12, color: Color(0xFF8D99AE)),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _marginC,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: Color(0xFF1C2541),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'تقريب الأسعار لأقرب',
                    style: TextStyle(fontSize: 12, color: Color(0xFF8D99AE)),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedRounding,
                    dropdownColor: const Color(0xFF1C2541),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: Color(0xFF1C2541),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'أقرب 100 ج.س', child: Text('أقرب 100 ج.س')),
                      DropdownMenuItem(value: 'أقرب 500 ج.س', child: Text('أقرب 500 ج.س')),
                      DropdownMenuItem(value: 'بدون تقريب', child: Text('بدون تقريب')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedRounding = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: const Color(0xFF050B14),
                      ),
                      onPressed: () => _showPreviewModal(context),
                      child: const Text('معاينة وتطبيق الأسعار فوراً'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'سجل تغييرات سعر الدولار',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('2,800 ج.س ← 2,850 ج.س', style: TextStyle(fontSize: 12, color: Color(0xFF8D99AE))),
                      Text('أمس، 14:30 (د. طارق)', style: TextStyle(fontSize: 12, color: Color(0xFF8D99AE))),
                    ],
                  ),
                  const Divider(color: Colors.white10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('2,750 ج.س ← 2,800 ج.س', style: TextStyle(fontSize: 12, color: Color(0xFF8D99AE))),
                      Text('02 أبريل (د. طارق)', style: TextStyle(fontSize: 12, color: Color(0xFF8D99AE))),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// SCREEN 5: ADMIN MANAGEMENT & QUICK NAV
// ==========================================
class AdminManagementScreen extends StatelessWidget {
  const AdminManagementScreen({super.key});

  void _showAddStaffModal(BuildContext context) {
    final nameC = TextEditingController();
    final roleC = TextEditingController(text: 'محاسب');

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B132B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          top: 24,
          left: 24,
          right: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'إضافة موظف جديد وتحديد صلاحياته',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameC,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'اسم الموظف',
                filled: true,
                fillColor: Color(0xFF1C2541),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: roleC,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'الدور / الصلاحيات',
                filled: true,
                fillColor: Color(0xFF1C2541),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: const Color(0xFF050B14),
                ),
                onPressed: () {
                  if (nameC.text.isNotEmpty) {
                    context.read<AppState>().addStaffLog(
                          '${nameC.text} (${roleC.text})',
                          'تم إنشاء الحساب وإعطاء الصلاحيات',
                        );
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('إضافة الموظف'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('الصلاحيات وسجل النشاط'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            onPressed: () => _showAddStaffModal(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Navigation Shortcuts for all 12 reviewer screens
          const Text(
            'أقسام الإدارة والخدمات',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFD4AF37)),
          ),
          const SizedBox(height: 8),

          _buildNavTile(
            context,
            title: 'مناطق التوصيل وأسعارها',
            subtitle: 'عطبرة، بربر، الدامر، أبوحمد',
            icon: Icons.local_shipping_outlined,
            targetScreen: const DeliveryLocationsScreen(),
          ),
          _buildNavTile(
            context,
            title: 'حسابات بنكك وإشعارات الدفع',
            subtitle: 'الحساب النشط #3829104',
            icon: Icons.account_balance_outlined,
            targetScreen: const PaymentAccountsScreen(),
          ),
          _buildNavTile(
            context,
            title: 'مسح الفواتير بالذكاء الاصطناعي (OCR)',
            subtitle: 'قراءة فواتير الموردين تلقائياً',
            icon: Icons.document_scanner_outlined,
            targetScreen: const InvoiceOcrScreen(),
          ),
          _buildNavTile(
            context,
            title: 'العملاء والتقارير البيانية',
            subtitle: 'المبيعات وتصدير PDF / Excel',
            icon: Icons.bar_chart_outlined,
            targetScreen: const ReportsScreen(),
          ),
          _buildNavTile(
            context,
            title: 'عرض حالة الطلبات الفارغة',
            subtitle: 'معاينة الشاشة عند خلو الطلبات',
            icon: Icons.inbox_outlined,
            targetScreen: const EmptyStateScreen(),
          ),
          _buildNavTile(
            context,
            title: 'معاينة هيكل التحميل (Skeleton)',
            subtitle: 'اختبار حالة التحميل المؤقتة',
            icon: Icons.hourglass_empty_outlined,
            targetScreen: const SkeletonScreen(),
          ),

          const SizedBox(height: 20),

          // Activity Log Section (سجل النشاط)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'سجل النشاط (من عدّل شنو ومتى)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: state.activityLogs.map((log) {
                  return Container(
                    padding: const EdgeInsets.only(bottom: 10, top: 10),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.white10)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log['user'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          log['action'] ?? '',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF8D99AE)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          log['time'] ?? '',
                          style: const TextStyle(fontSize: 10, color: Color(0xFFD4AF37)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 16),

          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFE76F51),
              side: const BorderSide(color: Color(0xFFE76F51)),
              minimumSize: const Size(0, 48),
            ),
            icon: const Icon(Icons.logout),
            label: const Text('تسجيل الخروج من الحساب'),
            onPressed: () => context.read<AppState>().logout(),
          ),
        ],
      ),
    );
  }

  Widget _buildNavTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget targetScreen,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFFD4AF37)),
        title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF8D99AE))),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF8D99AE)),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => targetScreen));
        },
      ),
    );
  }
}

// ==========================================
// STANDALONE SCREEN 6: DELIVERY LOCATIONS
// ==========================================
class DeliveryLocationsScreen extends StatelessWidget {
  const DeliveryLocationsScreen({super.key});

  void _showAddLocationModal(BuildContext context) {
    final nameC = TextEditingController();
    final priceC = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B132B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          top: 24,
          left: 24,
          right: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'إضافة منطقة توصيل جديدة',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameC,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'اسم المنطقة (مثل: شندي)',
                filled: true,
                fillColor: Color(0xFF1C2541),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceC,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'سعر التوصيل الثابت (ج.س)',
                filled: true,
                fillColor: Color(0xFF1C2541),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: const Color(0xFF050B14),
                ),
                onPressed: () {
                  if (nameC.text.isNotEmpty) {
                    final p = double.tryParse(priceC.text) ?? 10000;
                    context.read<AppState>().addZone(nameC.text, p);
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('حفظ المنطقة'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('مناطق التوصيل وأسعارها'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddLocationModal(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: state.deliveryZones.map((zone) {
          final bool isActive = zone['active'] == true;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        zone['name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0x262A9D8F)
                              : const Color(0x26E9C46A),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                            color: isActive
                                ? const Color(0x4D2A9D8F)
                                : const Color(0x4DE9C46A),
                          ),
                        ),
                        child: Text(
                          isActive ? 'مفعل' : 'متوقف مؤقتاً',
                          style: TextStyle(
                            fontSize: 11,
                            color: isActive ? const Color(0xFF2A9D8F) : const Color(0xFFE9C46A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'سعر التوصيل الثابت: ${zone['price'].toInt()} ج.س',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF8D99AE)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'سعر ثابت لا يتأثر بالدولار',
                        style: TextStyle(fontSize: 11, color: Color(0xFF8D99AE)),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isActive ? Colors.white : const Color(0xFF2A9D8F),
                          side: BorderSide(
                            color: isActive ? Colors.white24 : const Color(0xFF2A9D8F),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onPressed: () {
                          context.read<AppState>().toggleZone(zone['id']);
                        },
                        child: Text(
                          isActive ? 'تعديل السعر' : 'تفعيل المنطقة',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ==========================================
// STANDALONE SCREEN 7: PAYMENT ACCOUNTS & BANKAK
// ==========================================
class PaymentAccountsScreen extends StatelessWidget {
  const PaymentAccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('حسابات بنكك ومراجعة الإشعارات'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(left: 16.0),
            child: Icon(Icons.add),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Active Account Card
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFD4AF37)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'حساب بنكك النش حالياً للزبائن',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0x26D4AF37),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(color: const Color(0x4DD4AF37)),
                        ),
                        child: const Text(
                          'يظهر للزبون',
                          style: TextStyle(fontSize: 11, color: Color(0xFFD4AF37)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 13, color: Color(0xFF8D99AE), fontFamily: 'Segoe UI'),
                      children: [
                        TextSpan(text: 'رقم الحساب: '),
                        TextSpan(text: '3829104\n', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        TextSpan(text: 'اسم صاحب الحساب: '),
                        TextSpan(text: 'شركة DMC للمعدات الطبية\n', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        TextSpan(text: 'بنك الخرطوم (بنكك)'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            'إشعارات بنكك الجديدة (بانتظار المطابقة)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Color(0xFFE9C46A), width: 1),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'إشعار تحويل بنكك #TX-9021',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0x26E9C46A),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: const Text(
                          'بانتظار المطابقة',
                          style: TextStyle(fontSize: 11, color: Color(0xFFE9C46A)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'المبلغ: 535,000 ج.س | الزبون: مستشفى الأمل\nرقم العملية: 849201 | التاريخ: اليوم 10:45 ص',
                    style: TextStyle(fontSize: 13, color: Color(0xFF8D99AE)),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                      ),
                      onPressed: () {},
                      child: const Text('عرض صورة الإشعار للمطابقة', style: TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// STANDALONE SCREEN 8: OCR INVOICE SCANNER
// ==========================================
class InvoiceOcrScreen extends StatelessWidget {
  const InvoiceOcrScreen({super.key});

  void _pickInvoiceImage(BuildContext context, ImageSource source) async {
    try {
      final picker = ImagePicker();
      await picker.pickImage(source: source);
      if (context.mounted) {
        _showOcrResultModal(context);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر الوصول للكاميرا أو الصور')),
        );
      }
    }
  }

  void _showOcrResultModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B132B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'نتائج قراءة الفاتورة بالذكاء الاصطناعي',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'المورد المستخرج: شركة الفجر للمستلزمات الطبية\nرقم الفاتورة: #INV-5050 | التاريخ: اليوم',
              style: TextStyle(fontSize: 13, color: Color(0xFF8D99AE)),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('محاقن طبية 10 مل (50 كرتونة)', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text(
                      'الإجمالي: 1,250,000 ج.س (موجود - ستضاف للمخزن)',
                      style: TextStyle(fontSize: 13, color: Color(0xFFD4AF37)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: const Color(0xFF050B14),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('حفظ وتحديث المخزون والتكلفة'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مسح الفواتير بالذكاء الاصطناعي (OCR)'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // OCR Upload Box
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF22304A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD4AF37), width: 1.5),
            ),
            child: Column(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0x1AD4AF37),
                  ),
                  child: const Icon(Icons.camera_alt_outlined, color: Color(0xFFD4AF37), size: 28),
                ),
                const SizedBox(height: 12),
                const Text(
                  'مسح فاتورة مورّد جديدة',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'استخراج الأصناف والكميات والأسعار تلقائياً بالذكاء الاصطناعي (عربي وإنجليزي)',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Color(0xFF8D99AE)),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: const Color(0xFF050B14),
                    ),
                    onPressed: () => _pickInvoiceImage(context, ImageSource.camera),
                    child: const Text('فتح الكاميرا أو المعرض'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const Text(
            'سجل المشتريات والفواتير الأخيرة',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'فاتورة #INV-5049',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0x262A9D8F),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: const Text(
                          'تمت المراجعة والإضافة',
                          style: TextStyle(fontSize: 11, color: Color(0xFF2A9D8F)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'المورد: شركة الفجر للمستلزمات الطبية\nالتاريخ: أمس | الإجمالي: 2,100,000 ج.س',
                    style: TextStyle(fontSize: 13, color: Color(0xFF8D99AE)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// STANDALONE SCREEN 9: REPORTS & CUSTOMERS
// ==========================================
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  void _showBroadcastModal(BuildContext context) {
    final textC = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0B132B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          top: 24,
          left: 24,
          right: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'إرسال إشعار جماعي لجميع الزبائن والعملاء',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textC,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'نص الإشعار / العرض الجديد',
                filled: true,
                fillColor: Color(0xFF1C2541),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: const Color(0xFF050B14),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إرسال الإشعار الجوال الآن'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('العملاء والتقارير البيانية'),
        actions: [
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: () => _showBroadcastModal(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'أبرز التقارير البيانية',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildReportBtn('تقرير المبيعات والأرباح الشهرية', 'PDF / Excel'),
                  const SizedBox(height: 8),
                  _buildReportBtn('أكثر المنتجات طلباً هذا الشهر', 'عرض'),
                  const SizedBox(height: 8),
                  _buildReportBtn('تقرير حركة المخزون والتالف', 'عرض'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'العملاء الدائمون (أسعار خاصة)',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0x26D4AF37),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        child: const Text(
                          '140 عميل',
                          style: TextStyle(fontSize: 11, color: Color(0xFFD4AF37)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C2541),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('مستشفى الأمل التخصصي', style: TextStyle(fontWeight: FontWeight.bold)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0x262A9D8F),
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: const Text(
                                'مؤسسة طبية',
                                style: TextStyle(fontSize: 10, color: Color(0xFF2A9D8F)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'خصم خاص 5% على جميع الطلبات الدائمة',
                          style: TextStyle(fontSize: 12, color: Color(0xFF8D99AE)),
                        ),
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
  }

  Widget _buildReportBtn(String label, String actionText) {
    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF22304A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Text(
            actionText,
            style: const TextStyle(fontSize: 12, color: Color(0xFFD4AF37), fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// STANDALONE SCREEN 11: EMPTY STATE
// ==========================================
class EmptyStateScreen extends StatelessWidget {
  const EmptyStateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الطلبات الجديدة'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0x1AD4AF37),
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  size: 32,
                  color: Color(0xFFD4AF37),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'لا توجد طلبات جديدة حالياً',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'ستظهر طلبات الزبائن وتنبيهات التحويل هنا فور إرسالها من تطبيق الزبون.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF8D99AE)),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: const Color(0xFF050B14),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('العودة للوحة القيادة'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// STANDALONE SCREEN 12: SKELETON PREVIEW
// ==========================================
class SkeletonScreen extends StatelessWidget {
  const SkeletonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('جاري تحميل البيانات...'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSkeletonBox(80),
          const SizedBox(height: 12),
          _buildSkeletonBox(120),
          const SizedBox(height: 12),
          _buildSkeletonBox(80),
          const SizedBox(height: 12),
          _buildSkeletonBox(100),
        ],
      ),
    );
  }

  Widget _buildSkeletonBox(double height) {
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF1C2541),
        borderRadius: BorderRadius.circular(8),
      ),
    ).animate(onPlay: (controller) => controller.repeat()).shimmer(
          duration: 1200.ms,
          color: const Color(0xFF22304A),
        );
  }
}
