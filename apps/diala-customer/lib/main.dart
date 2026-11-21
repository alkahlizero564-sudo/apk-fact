import 'dart:async';
import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:url_launcher/url_launcher.dart';

// -----------------------------------------------------------------------------
// FIREBASE BACKGROUND HANDLER
// -----------------------------------------------------------------------------
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background message handler
}

// -----------------------------------------------------------------------------
// APP COLORS & CONSTANTS
// -----------------------------------------------------------------------------
class AppColors {
  static const Color primary = Color(0xFF0F2C59);
  static const Color primaryLight = Color(0xFF1E3E62);
  static const Color accent = Color(0xFFD4AF37); // Metallic Gold
  static const Color accentGlow = Color(0x26D4AF37);
  static const Color bgDark = Color(0xFF0B132B);
  static const Color surfaceDark = Color(0xFF1C2541);
  static const Color surfaceCard = Color(0xFF22304A);
  static const Color textMain = Color(0xFFF0F4F8);
  static const Color textMuted = Color(0xFF8D99AE);
  static const Color border = Color(0x14FFFFFF);
  static const Color success = Color(0xFF2A9D8F);
  static const Color warning = Color(0xFFE9C46A);
  static const Color error = Color(0xFFE76F51);
  static const Color whatsapp = Color(0xFF25D366);
}

// -----------------------------------------------------------------------------
// API SERVICE
// -----------------------------------------------------------------------------
class ApiService {
  static const String baseUrl = "https://jvjtgzewumfecjdpekna.supabase.co";
  static const String anonKey =
      "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp2anRnemV3dW1mZWNqZHBla25hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE2NDYzMzcsImV4cCI6MjEwNzIyMjMzN30.1gck73ek8ErBtcF7xAtFM1TdvNim_1NzFVNej_mptBE";

  static String? accessToken;
  static String? refreshToken;
  static String? currentUserId;

  static Future<void> initSession() async {
    final prefs = await SharedPreferences.getInstance();
    accessToken = prefs.getString('access_token');
    refreshToken = prefs.getString('refresh_token');
    currentUserId = prefs.getString('user_id');
  }

  static Future<void> saveSession(String access, String refresh, String uid) async {
    accessToken = access;
    refreshToken = refresh;
    currentUserId = uid;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', access);
    await prefs.setString('refresh_token', refresh);
    await prefs.setString('user_id', uid);
  }

  static Future<void> clearSession() async {
    accessToken = null;
    refreshToken = null;
    currentUserId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_id');
  }

  static Map<String, String> _headers({bool auth = true}) {
    final map = {
      'apikey': anonKey,
      'Content-Type': 'application/json',
      'Prefer': 'return=representation',
    };
    if (auth && accessToken != null) {
      map['Authorization'] = 'Bearer $accessToken';
    }
    return map;
  }

  static Future<Map<String, dynamic>> signup({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    final url = Uri.parse("$baseUrl/auth/v1/signup");
    final res = await http.post(
      url,
      headers: _headers(auth: false),
      body: jsonEncode({
        "email": email,
        "password": password,
        "data": {"full_name": name, "phone": phone}
      }),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw data['msg'] ?? data['error_description'] ?? data['message'] ?? 'فشل إنشاء الحساب';
    }
    return data;
  }

  static Future<void> verifyOtp({required String email, required String token}) async {
    final url = Uri.parse("$baseUrl/auth/v1/verify");
    final res = await http.post(
      url,
      headers: _headers(auth: false),
      body: jsonEncode({"email": email, "token": token, "type": "signup"}),
    );
    final data = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw data['msg'] ?? data['error_description'] ?? data['message'] ?? 'رمز التحقق غير صحيح أو منتهي الصلاحية';
    }
    if (data['access_token'] != null) {
      await saveSession(data['access_token'], data['refresh_token'], data['user']['id']);
    }
  }

  static Future<List<dynamic>> getTable(String table, {String query = ""}) async {
    try {
      final url = Uri.parse("$baseUrl/rest/v1/$table?select=*&$query");
      final res = await http.get(url, headers: _headers());
      if (res.statusCode >= 400) {
        return [];
      }
      return jsonDecode(res.body) as List<dynamic>;
    } catch (_) {
      return [];
    }
  }

  static Future<dynamic> insertRow(String table, Map<String, dynamic> data) async {
    final url = Uri.parse("$baseUrl/rest/v1/$table");
    final res = await http.post(url, headers: _headers(), body: jsonEncode(data));
    final body = jsonDecode(res.body);
    if (res.statusCode >= 400) {
      throw body['message'] ?? 'فشل إتمام العملية';
    }
    return body;
  }
}

// -----------------------------------------------------------------------------
// APP NOTIFIER FOR THEME
// -----------------------------------------------------------------------------
class AppSettingsNotifier extends ChangeNotifier {
  bool _isDark = true;
  bool get isDark => _isDark;

  void toggleTheme() {
    _isDark = !_isDark;
    notifyListeners();
  }
}

final appSettings = AppSettingsNotifier();

// -----------------------------------------------------------------------------
// MAIN ENTRY POINT
// -----------------------------------------------------------------------------
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (_) {}
  runApp(const DialaCustomerApp());
}

class DialaCustomerApp extends StatefulWidget {
  const DialaCustomerApp({super.key});

  @override
  State<DialaCustomerApp> createState() => _DialaCustomerAppState();
}

class _DialaCustomerAppState extends State<DialaCustomerApp> {
  @override
  void initState() {
    super.initState();
    appSettings.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Diala - DMC Client',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'SD'),
      themeMode: appSettings.isDark ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
          primary: AppColors.primary,
          secondary: AppColors.accent,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F6F9),
        fontFamily: 'Segoe UI',
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
          primary: AppColors.primaryLight,
          surface: AppColors.surfaceDark,
          secondary: AppColors.accent,
        ),
        scaffoldBackgroundColor: AppColors.bgDark,
        fontFamily: 'Segoe UI',
      ),
      home: const SplashScreen(),
    );
  }
}

// -----------------------------------------------------------------------------
// SPLASH SCREEN
// -----------------------------------------------------------------------------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  void _checkSession() async {
    await ApiService.initSession();
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    if (ApiService.accessToken != null) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainScreen()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.bgDark,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryLight],
                  ),
                  border: Border.all(color: AppColors.accent, width: 2),
                  boxShadow: const [
                    BoxShadow(color: AppColors.accentGlow, blurRadius: 24, spreadRadius: 4),
                  ],
                ),
                child: const Icon(Icons.medical_services_outlined, size: 40, color: AppColors.accent),
              ),
              const SizedBox(height: 20),
              const Text('Diala', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textMain)),
              const SizedBox(height: 4),
              const Text('مشروع DMC للمعدات والمستهلكات الطبية', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
              const SizedBox(height: 32),
              const CircularProgressIndicator(color: AppColors.accent),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// AUTH SCREEN (Form)
// -----------------------------------------------------------------------------
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final nameC = TextEditingController(text: "مستشفى النيل التخصصي");
  final emailC = TextEditingController(text: "name@medical.sd");
  final phoneC = TextEditingController(text: "+249 91 234 5678");
  String accountType = 'مؤسسة طبية (مستشفى / صيدلية / معمل)';
  bool loading = false;
  String? errorMsg;

  void _submit() async {
    setState(() {
      loading = true;
      errorMsg = null;
    });
    try {
      // Simulate/call API signup then push OTP screen
      await Future.delayed(const Duration(milliseconds: 600));
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => OtpVerifyScreen(email: emailC.text.trim())));
    } catch (e) {
      setState(() => errorMsg = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.bgDark,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                          border: Border.all(color: AppColors.accent, width: 2),
                          boxShadow: const [BoxShadow(color: AppColors.accentGlow, blurRadius: 24)],
                        ),
                        child: const Icon(Icons.medical_services_outlined, size: 40, color: AppColors.accent),
                      ),
                      const SizedBox(height: 16),
                      const Text('Diala', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textMain)),
                      const SizedBox(height: 4),
                      const Text('مشروع DMC للمعدات والمستهلكات الطبية', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                if (errorMsg != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                    child: Text(errorMsg!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                  ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('الاسم الكامل أو اسم المؤسسة الطبية', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: nameC,
                        style: const TextStyle(color: AppColors.textMain, fontSize: 15),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.surfaceDark,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.accent)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('البريد الإلكتروني', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: emailC,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: AppColors.textMain, fontSize: 15),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.surfaceDark,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.accent)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('رقم الهاتف', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: phoneC,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: AppColors.textMain, fontSize: 15),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.surfaceDark,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.accent)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('نوع الحساب', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: accountType,
                        dropdownColor: AppColors.surfaceDark,
                        style: const TextStyle(color: AppColors.textMain, fontSize: 14, fontFamily: 'Segoe UI'),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: AppColors.surfaceDark,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'مؤسسة طبية (مستشفى / صيدلية / معمل)', child: Text('مؤسسة طبية (مستشفى / صيدلية / معمل)')),
                          DropdownMenuItem(value: 'فرد', child: Text('فرد')),
                        ],
                        onChanged: (val) => setState(() => accountType = val!),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: loading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: const Color(0xFF050B14),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: loading
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                              : const Text('إرسال رمز التأكيد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
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

// -----------------------------------------------------------------------------
// OTP VERIFICATION SCREEN
// -----------------------------------------------------------------------------
class OtpVerifyScreen extends StatefulWidget {
  final String email;
  const OtpVerifyScreen({super.key, required this.email});

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final c1 = TextEditingController(text: "4");
  final c2 = TextEditingController(text: "8");
  final c3 = TextEditingController(text: "9");
  final c4 = TextEditingController(text: "1");
  bool loading = false;

  void _verify() async {
    setState(() => loading = true);
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const MainScreen()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.bgDark,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('التحقق من البريد الإلكتروني', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textMain)),
                const SizedBox(height: 8),
                const Text('أدخل رمز التأكيد المكون من 4 أرقام المرسل إلى بريدك', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [c1, c2, c3, c4].map((controller) {
                    return Container(
                      width: 50,
                      height: 56,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      child: TextField(
                        controller: controller,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: 1,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.accent),
                        decoration: InputDecoration(
                          counterText: "",
                          filled: true,
                          fillColor: AppColors.surfaceDark,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.accent)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: loading ? null : _verify,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: const Color(0xFF050B14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: loading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                        : const Text('تأكيد ودخول التطبيق', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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

// -----------------------------------------------------------------------------
// MAIN SCREEN WITH BOTTOM NAV (5 TABS)
// -----------------------------------------------------------------------------
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = [
    const HomeTab(),
    const SearchCatalogTab(),
    const CartTab(),
    const OrdersTab(),
    const ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    _requestNotificationPermission();
  }

  void _requestNotificationPermission() async {
    try {
      await FirebaseMessaging.instance.requestPermission();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.bgDark,
        body: IndexedStack(
          index: _currentIndex,
          children: _tabs,
        ),
        bottomNavigationBar: Container(
          height: 72,
          decoration: const BoxDecoration(
            color: Color(0xfdf0b132b),
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_outlined, Icons.home, 'الرئيسية'),
              _buildNavItem(1, Icons.search_outlined, Icons.search, 'الكتالوج'),
              _buildNavItem(2, Icons.shopping_cart_outlined, Icons.shopping_cart, 'السلة'),
              _buildNavItem(3, Icons.insert_drive_file_outlined, Icons.insert_drive_file, 'الطلبات'),
              _buildNavItem(4, Icons.person_outline, Icons.person, 'حسابي'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isActive = _currentIndex == index;
    final color = isActive ? AppColors.accent : AppColors.textMuted;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isActive ? activeIcon : icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500)),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 1: HOME TAB
// -----------------------------------------------------------------------------
class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  int selectedCategory = 0;
  final Set<int> favorites = {1};

  final List<Map<String, dynamic>> products = [
    {
      "id": 1,
      "cat": "أجهزة طبية",
      "title": "جهاز تخطيط القلب ECG 12 قناة",
      "price": "450,000 ج.س",
      "icon": Icons.monitor_heart_outlined,
    },
    {
      "id": 2,
      "cat": "مستهلكات",
      "title": "قفازات لاتكس طبية (علبة 100 قطعة)",
      "price": "18,500 ج.س",
      "icon": Icons.clean_hands_outlined,
    },
    {
      "id": 3,
      "cat": "مستلزمات معامل وعمليات",
      "title": "محاقن طبية 10 مل مع إبرة (كرتونة)",
      "price": "65,000 ج.س",
      "icon": Icons.inventory_2_outlined,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Greeting Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('أهلاً بك،', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                    SizedBox(height: 2),
                    Text('مستشفى الأمل التخصصي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain)),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    final mainState = context.findAncestorStateOfType<_MainScreenState>();
                    mainState?.setState(() => mainState._currentIndex = 4);
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceCard,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(Icons.person_outline, size: 20, color: AppColors.textMain),
                  ),
                ),
              ],
            ),
          ),
          // Search Banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: () {
                final mainState = context.findAncestorStateOfType<_MainScreenState>();
                mainState?.setState(() => mainState._currentIndex = 1);
              },
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(50),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.search, size: 18, color: AppColors.textMuted),
                    SizedBox(width: 12),
                    Text('ابحث عن أجهزة، مستهلكات، مستلزمات...', style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Categories horizontal scroll
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildCatChip(0, 'الكل'),
                _buildCatChip(1, 'أجهزة طبية'),
                _buildCatChip(2, 'مستهلكات'),
                _buildCatChip(3, 'مستلزمات معامل وعمليات'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Section Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('المنتجات المميزة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain)),
                GestureDetector(
                  onTap: () {
                    final mainState = context.findAncestorStateOfType<_MainScreenState>();
                    mainState?.setState(() => mainState._currentIndex = 1);
                  },
                  child: const Text('عرض الكل', style: TextStyle(fontSize: 13, color: AppColors.accent, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Products Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.72,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final p = products[index];
                final isFav = favorites.contains(p['id']);
                return GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsScreen(product: p)));
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image area
                        Container(
                          height: 110,
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceDark,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                          ),
                          child: Stack(
                            children: [
                              Center(child: Icon(p['icon'] as IconData, size: 48, color: AppColors.textMuted)),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (isFav) {
                                        favorites.remove(p['id']);
                                      } else {
                                        favorites.add(p['id']);
                                      }
                                    });
                                  },
                                  child: Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.bgDark.withValues(alpha: 0.7),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Icon(
                                      isFav ? Icons.favorite : Icons.favorite_border,
                                      size: 14,
                                      color: isFav ? AppColors.error : AppColors.textMain,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Info
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p['cat'] as String, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                const SizedBox(height: 4),
                                Text(
                                  p['title'] as String,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMain, height: 1.3),
                                ),
                                const Spacer(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(p['price'] as String, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.accent)),
                                    Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: AppColors.accent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.add, size: 18, color: Color(0xFF050B14)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatChip(int id, String title) {
    final isActive = selectedCategory == id;
    return GestureDetector(
      onTap: () => setState(() => selectedCategory = id),
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accent : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: isActive ? AppColors.accent : AppColors.border),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isActive ? const Color(0xFF050B14) : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 2: SEARCH & CATALOG
// -----------------------------------------------------------------------------
class SearchCatalogTab extends StatefulWidget {
  const SearchCatalogTab({super.key});

  @override
  State<SearchCatalogTab> createState() => _SearchCatalogTabState();
}

class _SearchCatalogTabState extends State<SearchCatalogTab> {
  final searchC = TextEditingController(text: "قفازات طبية");
  int selectedCat = 0;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                SizedBox(width: 40),
                Text('البحث والفلترة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain)),
                SizedBox(width: 40),
              ],
            ),
          ),
          // Search box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: AppColors.accent),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 18, color: AppColors.textMuted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: searchC,
                      style: const TextStyle(color: AppColors.textMain, fontSize: 14),
                      decoration: const InputDecoration(border: InputBorder.none),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Categories
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildCatChip(0, 'الكل'),
                _buildCatChip(1, 'أجهزة طبية'),
                _buildCatChip(2, 'مستهلكات'),
                _buildCatChip(3, 'مستلزمات معامل'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Grid
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              childAspectRatio: 0.72,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProductDetailsScreen(
                          product: {
                            "cat": "مستهلكات",
                            "title": "قفازات لاتكس غير معقمة",
                            "price": "18,500 ج.س",
                            "icon": Icons.clean_hands_outlined,
                          },
                        ),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 110,
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceDark,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                          ),
                          child: Stack(
                            children: [
                              const Center(child: Icon(Icons.clean_hands_outlined, size: 48, color: AppColors.textMuted)),
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(50),
                                    border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                                  ),
                                  child: const Text('متوفر', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('مستهلكات', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                              const SizedBox(height: 4),
                              const Text('قفازات لاتكس غير معقمة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMain)),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('18,500 ج.س', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.accent)),
                                  Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(8)),
                                    child: const Icon(Icons.add, size: 18, color: Color(0xFF050B14)),
                                  ),
                                ],
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
          ),
        ],
      ),
    );
  }

  Widget _buildCatChip(int id, String title) {
    final isActive = selectedCat == id;
    return GestureDetector(
      onTap: () => setState(() => selectedCat = id),
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accent : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: isActive ? AppColors.accent : AppColors.border),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isActive ? const Color(0xFF050B14) : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PRODUCT DETAILS SCREEN
// -----------------------------------------------------------------------------
class ProductDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> product;
  const ProductDetailsScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.bgDark,
        body: SafeArea(
          child: Column(
            children: [
              // Top Bar & Hero image container
              Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: 240,
                    color: AppColors.surfaceDark,
                    child: Center(
                      child: Icon(product['icon'] as IconData? ?? Icons.monitor_heart_outlined, size: 80, color: AppColors.accent),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surfaceCard,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(Icons.arrow_forward, size: 18, color: AppColors.textMain),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surfaceCard,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.share_outlined, size: 18, color: AppColors.textMain),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                        ),
                        child: const Text('متوفر في المخزن', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        product['title'] ?? 'جهاز تخطيط القلب ECG 12 قناة احترافي',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textMain),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        product['price'] ?? '450,000 ج.س',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.accent),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'جهاز تخطيط قلبي متطور عالي الدقة مع شاشة ملونة باللمس وطابعة حرارية مدمجة، مناسب للمستشفيات ومراكز الطوارئ.',
                        style: TextStyle(fontSize: 14, color: AppColors.textMuted, height: 1.6),
                      ),
                      const SizedBox(height: 20),
                      const Text('المواصفات التقنية', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textMain)),
                      const SizedBox(height: 10),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        childAspectRatio: 2.2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        children: [
                          _buildSpecItem('عدد القنوات', '12 قناة'),
                          _buildSpecItem('العلامة التجارية', 'DMC MedTech'),
                          _buildSpecItem('الضمان', 'سنة كاملة'),
                          _buildSpecItem('المنشأ', 'ألماني الصنع'),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.accent,
                                  foregroundColor: const Color(0xFF050B14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: const Text('إضافة إلى السلة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.border),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: const Text('طلب عرض سعر', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMain)),
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
        ),
      ),
    );
  }

  Widget _buildSpecItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textMain)),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 3: CART TAB
// -----------------------------------------------------------------------------
class CartTab extends StatefulWidget {
  const CartTab({super.key});

  @override
  State<CartTab> createState() => _CartTabState();
}

class _CartTabState extends State<CartTab> {
  int qty1 = 1;
  int qty2 = 2;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text('سلة الطلبات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildCartItem('جهاز تخطيط القلب ECG', '450,000 ج.س', Icons.monitor_heart_outlined, qty1, (val) => setState(() => qty1 = val)),
                _buildCartItem('قفازات لاتكس طبية', '18,500 ج.س', Icons.clean_hands_outlined, qty2, (val) => setState(() => qty2 = val)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('إجمالي الأصناف', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                          Text('487,000 ج.س', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('رسوم التوصيل', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                          Text('يُحدد في الخطوة التالية', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                        ],
                      ),
                      const Divider(color: AppColors.border, height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text('المجموع الكلي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain)),
                          Text('487,000 ج.س', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.accent)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen()));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: const Color(0xFF050B14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('متابعة إتمام الطلب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(String title, String price, IconData icon, int qty, ValueChanged<int> onQtyChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 28, color: AppColors.textMuted),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMain)),
                const SizedBox(height: 4),
                Text(price, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.accent)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: () {
                    if (qty > 1) onQtyChanged(qty - 1);
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Text('-', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('$qty', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textMain)),
                ),
                InkWell(
                  onTap: () => onQtyChanged(qty + 1),
                  child: const Padding(
                    padding: EdgeInsets.all(4.0),
                    child: Text('+', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain)),
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

// -----------------------------------------------------------------------------
// CHECKOUT SCREEN (Delivery & Payment)
// -----------------------------------------------------------------------------
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  int selectedZone = 0; // 0: عطبرة, 1: الدامر, 2: بربر
  int selectedPayment = 0; // 0: بنكك, 1: COD
  String? proofFileName;

  void _pickProof() async {
    final picker = ImagePicker();
    final img = await picker.pickImage(source: ImageSource.gallery);
    if (img != null) {
      setState(() => proofFileName = img.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.bgDark,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surfaceCard,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(Icons.arrow_forward, size: 18, color: AppColors.textMain),
                      ),
                    ),
                    const Text('منطقة التوصيل والدفع', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain)),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('اختر منطقة التوصيل', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMain)),
                      const SizedBox(height: 12),
                      _buildZoneCard(0, 'عطبرة', '15,000 ج.س', 'التوصيل خلال 24 ساعة للمؤسسات الطبية'),
                      _buildZoneCard(1, 'الدامر', '18,000 ج.س', null),
                      _buildZoneCard(2, 'بربر / أبوحمد', '25,000 ج.س', null),
                      const SizedBox(height: 20),
                      const Text('طريقة الدفع', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMain)),
                      const SizedBox(height: 12),
                      // Bankak Card
                      GestureDetector(
                        onTap: () => setState(() => selectedPayment = 0),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: selectedPayment == 0 ? AppColors.accent.withValues(alpha: 0.05) : AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: selectedPayment == 0 ? AppColors.accent : AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('بنكك (Bankak)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMain)),
                              const SizedBox(height: 4),
                              const Text('التحويل الفوري ورفع صورة إشعار التحويل', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                              if (selectedPayment == 0) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: AppColors.surfaceDark, borderRadius: BorderRadius.circular(8)),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('رقم الحساب: 123456789 (شركة DMC الطبية)', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                      const SizedBox(height: 6),
                                      GestureDetector(
                                        onTap: () {
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ رقم الحساب')));
                                        },
                                        child: const Text('نسخ رقم الحساب 📋', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accent)),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                                const Text('ارفع صورة إشعار التحويل', style: TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                                const SizedBox(height: 6),
                                GestureDetector(
                                  onTap: _pickProof,
                                  child: Container(
                                    height: 48,
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceDark,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.upload_file, size: 18, color: AppColors.accent),
                                        const SizedBox(width: 8),
                                        Text(
                                          proofFileName ?? 'اضغط لاختيار إشعار التحويل...',
                                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      // COD Card
                      GestureDetector(
                        onTap: () => setState(() => selectedPayment = 1),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: selectedPayment == 1 ? AppColors.accent.withValues(alpha: 0.05) : AppColors.surfaceCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: selectedPayment == 1 ? AppColors.accent : AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text('الدفع عند الاستلام', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMain)),
                              SizedBox(height: 4),
                              Text('الدفع نقداً عند استلام الشحنة الطبية', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            final mainState = context.findAncestorStateOfType<_MainScreenState>();
                            mainState?.setState(() => mainState._currentIndex = 3);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: const Color(0xFF050B14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('تأكيد وإرسال الطلب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
    );
  }

  Widget _buildZoneCard(int id, String title, String fee, String? subtitle) {
    final isSelected = selectedZone == id;
    return GestureDetector(
      onTap: () => setState(() => selectedZone = id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent.withValues(alpha: 0.05) : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? AppColors.accent : AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMain)),
                Text(fee, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.accent)),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 4: ORDERS TRACKING & HISTORY TAB
// -----------------------------------------------------------------------------
class OrdersTab extends StatelessWidget {
  const OrdersTab({super.key});

  void _openWhatsApp(BuildContext context) async {
    final uri = Uri.parse("https://wa.me/249912345678");
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح واتساب')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text('تتبع وسجل الطلبات', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain)),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('طلب #DMC-9842', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textMain)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(50),
                              border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                            ),
                            child: const Text('بانتظار تأكيد الدفع', style: TextStyle(color: AppColors.accent, fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text('الإجمالي: 502,000 ج.س (عطبرة)', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                      const SizedBox(height: 20),
                      // Timeline
                      _buildTimeline(),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 42,
                              child: OutlinedButton(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري تحميل الفاتورة PDF...')));
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.border),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: const Text('تحميل الفاتورة PDF 📄', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMain)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: 42,
                              child: ElevatedButton(
                                onPressed: () => _openWhatsApp(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.whatsapp,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: const Text('تواصل واتساب 💬', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ),
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

  Widget _buildTimeline() {
    return Column(
      children: [
        _buildTimelineStep('قيد المراجعة', 'اليوم، 10:30 ص', isCompleted: true, isActive: false),
        _buildTimelineStep('بانتظار تأكيد الدفع (بنكك)', 'تم رفع الإشعار، جاري المطابقة', isCompleted: false, isActive: true),
        _buildTimelineStep('تم التجهيز', null, isCompleted: false, isActive: false),
        _buildTimelineStep('في الطريق', null, isCompleted: false, isActive: false),
        _buildTimelineStep('تم التسليم', null, isCompleted: false, isActive: false, isLast: true),
      ],
    );
  }

  Widget _buildTimelineStep(String title, String? subtitle, {required bool isCompleted, required bool isActive, bool isLast = false}) {
    final dotColor = isActive
        ? AppColors.accent
        : isCompleted
            ? AppColors.success
            : AppColors.textMuted;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
                border: Border.all(color: dotColor, width: 2),
                boxShadow: isActive ? const [BoxShadow(color: AppColors.accentGlow, blurRadius: 8)] : null,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 32,
                color: isCompleted ? AppColors.success : AppColors.surfaceDark,
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? AppColors.accent
                      : isCompleted
                          ? AppColors.textMain
                          : AppColors.textMuted,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 5: PROFILE & SETTINGS TAB
// -----------------------------------------------------------------------------
class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool notificationsEnabled = true;

  void _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('خدمات الموقع غير مفعلة')));
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفض صلاحية الموقع')));
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          title: const Text('صلاحية الموقع المطلوبة', style: TextStyle(color: AppColors.textMain)),
          content: const Text('تم رفض صلاحية تحديد الموقع الجغرافي بشكل دائم. يتطلب التطبيق الوصول إلى الموقع لتقديم خدمات التوصيل.', style: TextStyle(color: AppColors.textMuted)),
          actions: [
            TextButton(
              onPressed: () => Geolocator.openAppSettings(),
              child: const Text('فتح الإعدادات', style: TextStyle(color: AppColors.accent)),
            ),
          ],
        ),
      );
      return;
    }
    Position pos = await Geolocator.getCurrentPosition();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('موقعك: ${pos.latitude}, ${pos.longitude}')));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        children: [
          // Profile Header
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.surfaceCard, AppColors.bgDark],
              ),
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryLight,
                    border: Border.all(color: AppColors.accent, width: 2),
                  ),
                  child: const Center(
                    child: Text('م.أ', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.accent)),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('مستشفى الأمل التخصصي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain)),
                const SizedBox(height: 4),
                const Text('مؤسسة طبية • عطبرة', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
              ],
            ),
          ),
          // Settings list
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildSettingsTile(
                  title: 'إشعارات التطبيق الفورية',
                  trailing: Switch(
                    value: notificationsEnabled,
                    activeThumbColor: AppColors.accent,
                    onChanged: (val) => setState(() => notificationsEnabled = val),
                  ),
                ),
                _buildSettingsTile(
                  title: 'قائمة المفضلة',
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesScreen()));
                  },
                ),
                _buildSettingsTile(
                  title: 'التحقق من موقع التوصيل',
                  onTap: _checkLocationPermission,
                ),
                _buildSettingsTile(
                  title: 'سياسة الخصوصية والشروط',
                  onTap: () {},
                ),
                _buildSettingsTile(
                  title: 'تسجيل الخروج',
                  textColor: AppColors.error,
                  trailing: const Icon(Icons.logout, color: AppColors.error, size: 18),
                  onTap: () async {
                    await ApiService.clearSession();
                    if (!mounted) return;
                    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AuthScreen()), (route) => false);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required String title,
    Widget? trailing,
    Color textColor = AppColors.textMain,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
            trailing ?? const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// FAVORITES SCREEN (EMPTY STATE DEMO & LIST)
// -----------------------------------------------------------------------------
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.bgDark,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.surfaceCard,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(Icons.arrow_forward, size: 18, color: AppColors.textMain),
                      ),
                    ),
                    const Text('قائمة المفضلة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textMain)),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accent.withValues(alpha: 0.1),
                      ),
                      child: const Icon(Icons.favorite_outline, size: 36, color: AppColors.accent),
                    ),
                    const SizedBox(height: 16),
                    const Text('لا توجد منتجات في المفضلة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textMain)),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'قم بإضافة المنتجات الطبية التي تطلبها باستمرار للوصول السريع إليها',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 200,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: const Color(0xFF050B14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('تصفح الكتالوج', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
