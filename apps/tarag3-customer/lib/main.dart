import 'dart:async';
import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart' as intl;
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_config.dart';

// --- SUPABASE CONFIG ---
const String kSupabaseUrl = "https://jvjtgzewumfecjdpekna.supabase.co";
const String kSupabaseAnonKey =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp2anRnemV3dW1mZWNqZHBla25hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE2NDYzMzcsImV4cCI6MjEwNzIyMjMzN30.1gck73ek8ErBtcF7xAtFM1TdvNim_1NzFVNej_mptBE";

// --- TOP LEVEL BACKGROUND FCM ---
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: firebaseOptions);
  } catch (_) {}
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: firebaseOptions);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (_) {}

  runApp(const DmcCustomerApp());
}

// --- GLOBAL AUTH & STATE MANAGEMENT ---
class AuthState {
  static String? accessToken;
  static String? refreshToken;
  static String? userId;
  static String? userEmail;
  static String? fullName;
  static String? phone;

  static Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    accessToken = prefs.getString('access_token');
    refreshToken = prefs.getString('refresh_token');
    userId = prefs.getString('user_id');
    userEmail = prefs.getString('user_email');
    fullName = prefs.getString('full_name');
    phone = prefs.getString('phone');
  }

  static Future<void> saveSession(Map<String, dynamic> data) async {
    accessToken = data['access_token'];
    refreshToken = data['refresh_token'];
    final user = data['user'];
    if (user != null) {
      userId = user['id'];
      userEmail = user['email'];
      final meta = user['user_metadata'];
      if (meta != null) {
        fullName = meta['full_name'] ?? fullName;
        phone = meta['phone'] ?? phone;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    if (accessToken != null) await prefs.setString('access_token', accessToken!);
    if (refreshToken != null) await prefs.setString('refresh_token', refreshToken!);
    if (userId != null) await prefs.setString('user_id', userId!);
    if (userEmail != null) await prefs.setString('user_email', userEmail!);
    if (fullName != null) await prefs.setString('full_name', fullName!);
    if (phone != null) await prefs.setString('phone', phone!);

    if (userId != null) {
      await fetchProfile();
    }
  }

  static Future<void> fetchProfile() async {
    if (userId == null) return;
    try {
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_profiles?id=eq.$userId'),
        headers: headers(),
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        if (list.isNotEmpty) {
          fullName = list[0]['full_name'] ?? fullName;
          phone = list[0]['phone'] ?? phone;
          final prefs = await SharedPreferences.getInstance();
          if (fullName != null) prefs.setString('full_name', fullName!);
          if (phone != null) prefs.setString('phone', phone!);
        }
      } else if (res.statusCode == 401) {
        await refreshSession();
      }
    } catch (_) {}
  }

  static Future<bool> refreshSession() async {
    if (refreshToken == null) return false;
    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/token?grant_type=refresh_token'),
        headers: headers(auth: false),
        body: jsonEncode({"refresh_token": refreshToken}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        await saveSession(data);
        return true;
      }
    } catch (_) {}
    await clearSession();
    return false;
  }

  static Future<void> updateProfileData(String name, String phoneNum) async {
    fullName = name;
    phone = phoneNum;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('full_name', name);
    await prefs.setString('phone', phoneNum);

    if (userId != null) {
      try {
        final res = await http.patch(
          Uri.parse('$kSupabaseUrl/rest/v1/tarag3_profiles?id=eq.$userId'),
          headers: headers(),
          body: jsonEncode({"full_name": name, "phone": phoneNum}),
        );
        if (res.statusCode == 401) {
          if (await refreshSession()) {
            await http.patch(
              Uri.parse('$kSupabaseUrl/rest/v1/tarag3_profiles?id=eq.$userId'),
              headers: headers(),
              body: jsonEncode({"full_name": name, "phone": phoneNum}),
            );
          }
        }
      } catch (_) {}
    }
  }

  static Future<void> clearSession() async {
    accessToken = null;
    refreshToken = null;
    userId = null;
    userEmail = null;
    fullName = null;
    phone = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Map<String, String> headers({bool auth = true}) {
    final map = <String, String>{
      'apikey': kSupabaseAnonKey,
      'Content-Type': 'application/json',
      'Prefer': 'return=representation',
    };
    if (auth && accessToken != null && accessToken!.isNotEmpty) {
      map['Authorization'] = 'Bearer $accessToken';
    }
    return map;
  }

  static String parseAuthError(Map<String, dynamic> data) {
    final msg = (data['error_description'] ?? data['msg'] ?? data['message'] ?? data['error'] ?? '').toString();
    final lower = msg.toLowerCase();
    if (lower.contains('rate limit') || lower.contains('too many requests')) {
      return 'اتبعتت رسائل كتير، استنى دقايق';
    }
    if (lower.contains('sending') || lower.contains('smtp') || lower.contains('email provider')) {
      return 'ما قدرنا نرسل البريد';
    }
    if (msg.isNotEmpty) return msg;
    return 'حدث خطأ في العملية، يرجى المحاولة لاحقاً';
  }
}

// --- APP WIDGET ---
class DmcCustomerApp extends StatelessWidget {
  const DmcCustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DMC Customer',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'SD'),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Cairo',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A47A8),
          primary: const Color(0xFF0A47A8),
          secondary: const Color(0xFF00B8C4),
          surface: const Color(0xFFF3F7FC),
        ),
        scaffoldBackgroundColor: const Color(0xFFF3F7FC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF0A2F6B),
          elevation: 0.5,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0A2F6B),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Cairo',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A47A8),
          brightness: Brightness.dark,
          primary: const Color(0xFF0A47A8),
          secondary: const Color(0xFF00B8C4),
          surface: const Color(0xFF12161F),
        ),
        scaffoldBackgroundColor: const Color(0xFF12161F),
      ),
      themeMode: ThemeMode.light,
      home: const SplashCheckScreen(),
    );
  }
}

// --- SPLASH CHECK ---
class SplashCheckScreen extends StatefulWidget {
  const SplashCheckScreen({super.key});

  @override
  State<SplashCheckScreen> createState() => _SplashCheckScreenState();
}

class _SplashCheckScreenState extends State<SplashCheckScreen> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    await AuthState.loadSession();
    if (!mounted) return;
    if (AuthState.accessToken != null && AuthState.accessToken!.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainTabsScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFF0A47A8)),
      ),
    );
  }
}

// --- AUTH SCREEN (SIGN IN / SIGN UP / FORGOT) ---
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  int authMode = 0; // 0: Login, 1: Register, 2: Forgot Password
  bool loading = false;
  bool showPassword = false;
  bool showConfirmPassword = false;
  String? generalError;

  // Sign up fields
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController(text: 'customer@diala.sd');
  final passwordController = TextEditingController(text: 'password123');
  final confirmPasswordController = TextEditingController();

  // Field specific errors
  String? nameError;
  String? phoneError;
  String? emailError;
  String? passwordError;
  String? confirmPasswordError;

  void _clearErrors() {
    setState(() {
      generalError = null;
      nameError = null;
      phoneError = null;
      emailError = null;
      passwordError = null;
      confirmPasswordError = null;
    });
  }

  bool _validateSignUp() {
    bool valid = true;
    _clearErrors();

    if (nameController.text.trim().isEmpty) {
      nameError = 'الاسم الكامل مطلوب';
      valid = false;
    }
    if (phoneController.text.trim().isEmpty) {
      phoneError = 'رقم الهاتف مطلوب';
      valid = false;
    }
    if (emailController.text.trim().isEmpty) {
      emailError = 'البريد الإلكتروني مطلوب';
      valid = false;
    }
    if (passwordController.text.length < 6) {
      passwordError = 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
      valid = false;
    }
    if (passwordController.text != confirmPasswordController.text) {
      confirmPasswordError = 'كلمة المرور غير متطابقة';
      valid = false;
    }

    setState(() {});
    return valid;
  }

  Future<void> _submit() async {
    _clearErrors();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (authMode == 1 && !_validateSignUp()) {
      return;
    }

    if (authMode == 0 && email.isEmpty) {
      setState(() => emailError = 'البريد الإلكتروني مطلوب');
      return;
    }
    if (authMode == 0 && password.isEmpty) {
      setState(() => passwordError = 'كلمة المرور مطلوبة');
      return;
    }
    if (authMode == 2 && email.isEmpty) {
      setState(() => emailError = 'البريد الإلكتروني مطلوب');
      return;
    }

    setState(() => loading = true);

    try {
      if (authMode == 0) {
        // Sign In
        final res = await http.post(
          Uri.parse('$kSupabaseUrl/auth/v1/token?grant_type=password'),
          headers: AuthState.headers(auth: false),
          body: jsonEncode({"email": email, "password": password}),
        );
        final data = jsonDecode(res.body);

        if (res.statusCode == 200) {
          await AuthState.saveSession(data);
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainTabsScreen()),
          );
        } else {
          final errStr = AuthState.parseAuthError(data);
          if (errStr.contains('Email not confirmed') || (data['error_description'] ?? '').toString().contains('Email not confirmed')) {
            await http.post(
              Uri.parse('$kSupabaseUrl/auth/v1/resend'),
              headers: AuthState.headers(auth: false),
              body: jsonEncode({"type": "signup", "email": email}),
            );
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => OtpVerifyScreen(email: email, isSignup: true)),
            );
          } else {
            setState(() => generalError = errStr);
          }
        }
      } else if (authMode == 1) {
        // Sign Up
        final name = nameController.text.trim();
        final phone = phoneController.text.trim();

        final res = await http.post(
          Uri.parse('$kSupabaseUrl/auth/v1/signup'),
          headers: AuthState.headers(auth: false),
          body: jsonEncode({
            "email": email,
            "password": password,
            "data": {"full_name": name, "phone": phone}
          }),
        );
        final data = jsonDecode(res.body);

        if (res.statusCode == 200 || res.statusCode == 201) {
          if (data['access_token'] != null) {
            await AuthState.saveSession(data);
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const MainTabsScreen()),
            );
          } else {
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => OtpVerifyScreen(email: email, isSignup: true)),
            );
          }
        } else {
          setState(() => generalError = AuthState.parseAuthError(data));
        }
      } else if (authMode == 2) {
        // Forgot Password
        final res = await http.post(
          Uri.parse('$kSupabaseUrl/auth/v1/recover'),
          headers: AuthState.headers(auth: false),
          body: jsonEncode({"email": email}),
        );
        final data = jsonDecode(res.body);
        if (res.statusCode == 200) {
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => OtpVerifyScreen(email: email, isSignup: false)),
          );
        } else {
          setState(() => generalError = AuthState.parseAuthError(data));
        }
      }
    } catch (e) {
      setState(() => generalError = 'حدث خطأ في الاتصال بالخادم');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // DMC Logo Badge
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0A2F6B), Color(0xFF0A47A8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Color(0x330A47A8), blurRadius: 10, offset: Offset(0, 4)),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'DMC',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Diala Medical',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0A2F6B)),
                ),
                const Text(
                  'معدات ومستهلكات طبية',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 20),

                // Card Container
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE1E9F3)),
                    boxShadow: const [
                      BoxShadow(color: Color(0x0A0A2F6B), blurRadius: 16, offset: Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (authMode != 2)
                        Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    setState(() => authMode = 0);
                                    _clearErrors();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: authMode == 0 ? const Color(0xFF0A47A8) : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'تسجيل الدخول',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: authMode == 0 ? FontWeight.w800 : FontWeight.w700,
                                        color: authMode == 0 ? const Color(0xFF0A47A8) : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () {
                                    setState(() => authMode = 1);
                                    _clearErrors();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        bottom: BorderSide(
                                          color: authMode == 1 ? const Color(0xFF0A47A8) : Colors.transparent,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      'حساب جديد',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: authMode == 1 ? FontWeight.w800 : FontWeight.w700,
                                        color: authMode == 1 ? const Color(0xFF0A47A8) : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      if (authMode == 2)
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back),
                              onPressed: () {
                                setState(() => authMode = 0);
                                _clearErrors();
                              },
                            ),
                            const Text(
                              'إعادة ضبط كلمة المرور',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0A2F6B)),
                            ),
                          ],
                        ),

                      // Sign Up Fields: Full Name & Phone
                      if (authMode == 1) ...[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('الاسم الكامل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0A2F6B))),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 46,
                              child: TextField(
                                controller: nameController,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0A2F6B)),
                                decoration: InputDecoration(
                                  hintText: 'د. محمد أحمد',
                                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE1E9F3))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE1E9F3))),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF0A47A8))),
                                ),
                              ),
                            ),
                            if (nameError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4, right: 4),
                                child: Text(nameError!, style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w600)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('رقم الهاتف', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0A2F6B))),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 46,
                              child: TextField(
                                controller: phoneController,
                                keyboardType: TextInputType.phone,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0A2F6B)),
                                decoration: InputDecoration(
                                  hintText: '0912345678',
                                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE1E9F3))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE1E9F3))),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF0A47A8))),
                                ),
                              ),
                            ),
                            if (phoneError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4, right: 4),
                                child: Text(phoneError!, style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w600)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Email Input Field
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('البريد الإلكتروني', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0A2F6B))),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 46,
                            child: TextField(
                              controller: emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0A2F6B)),
                              decoration: InputDecoration(
                                hintText: 'name@domain.com',
                                hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE1E9F3))),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE1E9F3))),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF0A47A8))),
                              ),
                            ),
                          ),
                          if (emailError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4, right: 4),
                              child: Text(emailError!, style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w600)),
                            ),
                        ],
                      ),

                      if (authMode != 2) ...[
                        const SizedBox(height: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('كلمة المرور', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0A2F6B))),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 46,
                              child: TextField(
                                controller: passwordController,
                                obscureText: !showPassword,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0A2F6B)),
                                decoration: InputDecoration(
                                  hintText: '••••••••',
                                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  suffixIcon: IconButton(
                                    icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF94A3B8), size: 18),
                                    onPressed: () => setState(() => showPassword = !showPassword),
                                  ),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE1E9F3))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE1E9F3))),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF0A47A8))),
                                ),
                              ),
                            ),
                            if (passwordError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4, right: 4),
                                child: Text(passwordError!, style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w600)),
                              ),
                          ],
                        ),
                      ],

                      if (authMode == 1) ...[
                        const SizedBox(height: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('تأكيد كلمة المرور', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0A2F6B))),
                            const SizedBox(height: 6),
                            SizedBox(
                              height: 46,
                              child: TextField(
                                controller: confirmPasswordController,
                                obscureText: !showConfirmPassword,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0A2F6B)),
                                decoration: InputDecoration(
                                  hintText: '••••••••',
                                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  suffixIcon: IconButton(
                                    icon: Icon(showConfirmPassword ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF94A3B8), size: 18),
                                    onPressed: () => setState(() => showConfirmPassword = !showConfirmPassword),
                                  ),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE1E9F3))),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE1E9F3))),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF0A47A8))),
                                ),
                              ),
                            ),
                            if (confirmPasswordError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4, right: 4),
                                child: Text(confirmPasswordError!, style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w600)),
                              ),
                          ],
                        ),
                      ],

                      if (authMode == 0) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: () {
                              setState(() => authMode = 2);
                              _clearErrors();
                            },
                            child: const Text(
                              'نسيت كلمة المرور؟',
                              style: TextStyle(color: Color(0xFF0A47A8), fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],

                      if (generalError != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFCE8E6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            generalError!,
                            style: const TextStyle(color: Color(0xFFE53935), fontSize: 12, fontWeight: FontWeight.w700),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),
                      SizedBox(
                        height: 46,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0A47A8),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          onPressed: loading ? null : _submit,
                          child: loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Text(
                                  authMode == 0
                                      ? 'تسجيل الدخول'
                                      : authMode == 1
                                          ? 'إنشاء الحساب'
                                          : 'إرسال رمز التفعيل',
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                                ),
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

// --- OTP VERIFICATION SCREEN ---
class OtpVerifyScreen extends StatefulWidget {
  final String email;
  final bool isSignup;
  const OtpVerifyScreen({super.key, required this.email, required this.isSignup});

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final codeController = TextEditingController();
  bool loading = false;
  String? errorMsg;
  int resendSec = 60;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    resendSec = 60;
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (resendSec > 0) {
        if (mounted) setState(() => resendSec--);
      } else {
        t.cancel();
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _resendCode() async {
    setState(() {
      errorMsg = null;
      loading = true;
    });
    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/resend'),
        headers: AuthState.headers(auth: false),
        body: jsonEncode({
          "type": widget.isSignup ? "signup" : "recovery",
          "email": widget.email,
        }),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        _startTimer();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم إعادة إرسال الرمز بنجاح')),
          );
        }
      } else {
        setState(() => errorMsg = AuthState.parseAuthError(data));
      }
    } catch (_) {
      setState(() => errorMsg = 'ما قدرنا نرسل البريد');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _verify() async {
    final code = codeController.text.trim();
    if (code.length < 6) {
      setState(() => errorMsg = 'يرجى إدخال 6 أرقام');
      return;
    }
    setState(() {
      loading = true;
      errorMsg = null;
    });
    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/verify'),
        headers: AuthState.headers(auth: false),
        body: jsonEncode({
          "type": widget.isSignup ? "signup" : "recovery",
          "email": widget.email,
          "token": code,
        }),
      );
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        await AuthState.saveSession(data);
        if (!mounted) return;
        if (widget.isSignup) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const MainTabsScreen()),
            (route) => false,
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
          );
        }
      } else {
        setState(() {
          errorMsg = 'رمز التحقق غير صحيح أو انتهت صلاحيته';
        });
      }
    } catch (e) {
      setState(() => errorMsg = 'خطأ في الاتصال بالخادم');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('رمز التحقق')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.mark_email_read_outlined, size: 64, color: Color(0xFF0A47A8)),
            const SizedBox(height: 16),
            Text(
              'بعتنا رمز على بريدك:\n${widget.email}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 8),
              maxLength: 6,
              decoration: InputDecoration(
                hintText: '000000',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            if (errorMsg != null) ...[
              const SizedBox(height: 8),
              Text(errorMsg!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700, fontSize: 13)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A47A8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: loading ? null : _verify,
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('تأكيد والمتابعة', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: (resendSec == 0 && !loading) ? _resendCode : null,
              child: Text(
                resendSec > 0 ? 'إعادة الإرسال بعد $resendSec ثانية' : 'إعادة إرسال الرمز',
                style: TextStyle(
                  color: resendSec == 0 ? const Color(0xFF0A47A8) : const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- RESET PASSWORD SCREEN ---
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final newPasswordController = TextEditingController();
  final confirmController = TextEditingController();
  bool loading = false;
  String? errorMsg;

  Future<void> _updatePassword() async {
    final pwd = newPasswordController.text.trim();
    if (pwd.length < 6) {
      setState(() => errorMsg = 'كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }
    if (pwd != confirmController.text.trim()) {
      setState(() => errorMsg = 'كلمتا المرور غير متطابقتين');
      return;
    }

    setState(() {
      loading = true;
      errorMsg = null;
    });

    try {
      final res = await http.put(
        Uri.parse('$kSupabaseUrl/auth/v1/user'),
        headers: AuthState.headers(),
        body: jsonEncode({"password": pwd}),
      );
      if (res.statusCode == 200) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث كلمة المرور بنجاح')),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainTabsScreen()),
          (route) => false,
        );
      } else {
        final data = jsonDecode(res.body);
        setState(() => errorMsg = AuthState.parseAuthError(data));
      }
    } catch (_) {
      setState(() => errorMsg = 'خطأ في الاتصال بالخادم');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('كلمة المرور الجديدة')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('أدخل كلمة المرور الجديدة لحسابك:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 16),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'كلمة المرور الجديدة',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'تأكيد كلمة المرور',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            if (errorMsg != null) ...[
              const SizedBox(height: 12),
              Text(errorMsg!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A47A8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: loading ? null : _updatePassword,
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('حفظ كلمة المرور', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- PROFILE EDIT SCREEN ---
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController nameCtrl;
  late TextEditingController phoneCtrl;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: AuthState.fullName ?? '');
    phoneCtrl = TextEditingController(text: AuthState.phone ?? '');
  }

  Future<void> _save() async {
    setState(() => saving = true);
    await AuthState.updateProfileData(nameCtrl.text.trim(), phoneCtrl.text.trim());
    if (!mounted) return;
    setState(() => saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ الملف الشخصي بنجاح')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الملف الشخصي')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: const Color(0xFF0A47A8),
            child: Text(
              (AuthState.fullName != null && AuthState.fullName!.isNotEmpty)
                  ? AuthState.fullName![0].toUpperCase()
                  : 'D',
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            AuthState.userEmail ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: nameCtrl,
            decoration: InputDecoration(
              labelText: 'الاسم الكامل',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'رقم الهاتف',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A47A8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: saving ? null : _save,
              child: saving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('حفظ التعديلات', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onPressed: () async {
              await AuthState.clearSession();
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const AuthScreen()),
                (route) => false,
              );
            },
            icon: const Icon(Icons.logout),
            label: const Text('تسجيل الخروج', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// --- MAIN TABS SCREEN ---
class MainTabsScreen extends StatefulWidget {
  const MainTabsScreen({super.key});

  @override
  State<MainTabsScreen> createState() => _MainTabsScreenState();
}

class _MainTabsScreenState extends State<MainTabsScreen> with WidgetsBindingObserver {
  int currentIndex = 0;
  Timer? syncTimer;
  int unreadNotificationsCount = 0;
  int cartItemsCount = 0;

  final GlobalKey<HomeScreenState> homeKey = GlobalKey<HomeScreenState>();
  final GlobalKey<CartScreenState> cartKey = GlobalKey<CartScreenState>();
  final GlobalKey<OrdersScreenState> ordersKey = GlobalKey<OrdersScreenState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initFcmAndSync();
    _fetchBadges();
    syncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _fetchBadges();
      _refreshCurrentScreen();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    syncTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchBadges();
      _refreshCurrentScreen();
    }
  }

  void _refreshCurrentScreen() {
    if (currentIndex == 0) {
      homeKey.currentState?.fetchDataQuietly();
    } else if (currentIndex == 1) {
      cartKey.currentState?.fetchCartQuietly();
    } else if (currentIndex == 2) {
      ordersKey.currentState?.fetchOrdersQuietly();
    }
  }

  Future<void> _fetchBadges() async {
    if (AuthState.userId == null) return;
    try {
      final notifRes = await http.get(
        Uri.parse(
          '$kSupabaseUrl/rest/v1/tarag3_notifications?or=(to_user.eq.${AuthState.userId},to_role.eq.customer)&read_at=is.null',
        ),
        headers: AuthState.headers(),
      );
      final cartRes = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_cart_items?customer_id=eq.${AuthState.userId}'),
        headers: AuthState.headers(),
      );

      if (notifRes.statusCode == 200) {
        final list = jsonDecode(notifRes.body) as List;
        if (mounted) setState(() => unreadNotificationsCount = list.length);
      } else if (notifRes.statusCode == 401) {
        if (await AuthState.refreshSession()) {
          _fetchBadges();
        }
      }

      if (cartRes.statusCode == 200) {
        final list = jsonDecode(cartRes.body) as List;
        if (mounted) setState(() => cartItemsCount = list.length);
      }
    } catch (_) {}
  }

  Future<void> _initFcmAndSync() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null && AuthState.userId != null) {
          await http.post(
            Uri.parse('$kSupabaseUrl/rest/v1/rpc/tarag3_register_device'),
            headers: AuthState.headers(),
            body: jsonEncode({"device_token": token, "app_name": "customer"}),
          );
        }
      }

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (!mounted) return;
        final notification = message.notification;
        final title = notification?.title ?? 'إشعار جديد';
        final body = notification?.body ?? '';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                if (body.isNotEmpty) Text(body, style: const TextStyle(fontSize: 12)),
              ],
            ),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'فتح الإشعارات',
              textColor: Colors.amber,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                ).then((_) => _fetchBadges());
              },
            ),
          ),
        );

        _fetchBadges();
        _refreshCurrentScreen();
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
              },
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF0A2F6B), Color(0xFF0A47A8)]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Color(0x400A47A8), blurRadius: 10, offset: Offset(0, 4)),
                  ],
                ),
                alignment: Alignment.center,
                child: const Text('DMC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AuthState.fullName != null && AuthState.fullName!.isNotEmpty ? AuthState.fullName! : 'DMC Diala',
                  style: const TextStyle(color: Color(0xFF0A2F6B), fontSize: 15, fontWeight: FontWeight.w800, height: 1.2),
                ),
                const Text('معدات ومستهلكات طبية', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFF0F5FA),
                  fixedSize: const Size(40, 40),
                ),
                icon: const Icon(Icons.notifications_outlined, color: Color(0xFF0A2F6B), size: 20),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())).then((_) => _fetchBadges());
                },
              ),
              if (unreadNotificationsCount > 0)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE53935),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$unreadNotificationsCount',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: currentIndex,
        children: [
          HomeScreen(key: homeKey, onCartUpdated: _fetchBadges),
          CartScreen(key: cartKey, onCartUpdated: _fetchBadges),
          OrdersScreen(key: ordersKey),
          const ContactScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        height: 68,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE1E9F3))),
          boxShadow: [
            BoxShadow(color: Color(0x0D0A2F6B), blurRadius: 16, offset: Offset(0, -4)),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, 'الرئيسية', Icons.home_outlined, Icons.home),
            _buildNavItem(1, 'السلة', Icons.shopping_bag_outlined, Icons.shopping_bag, badgeCount: cartItemsCount),
            _buildNavItem(2, 'طلباتي', Icons.description_outlined, Icons.description),
            _buildNavItem(3, 'تواصل', Icons.phone_outlined, Icons.phone),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String label, IconData icon, IconData activeIcon, {int badgeCount = 0}) {
    final bool isActive = currentIndex == index;
    return InkWell(
      onTap: () {
        setState(() => currentIndex = index);
        _fetchBadges();
        _refreshCurrentScreen();
      },
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isActive ? const Color(0xFFE8F0FE) : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    isActive ? activeIcon : icon,
                    color: isActive ? const Color(0xFF0A47A8) : const Color(0xFF64748B),
                    size: 22,
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -2,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isActive ? const Color(0xFF0A47A8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 1. HOME SCREEN ---
class HomeScreen extends StatefulWidget {
  final VoidCallback onCartUpdated;
  const HomeScreen({super.key, required this.onCartUpdated});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  String selectedCategory = 'الكل';
  String searchQuery = '';
  double usdRate = 2700.0;
  List<dynamic> products = [];
  List<dynamic> deliveryAreas = [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _fetchSettingsAndAreas();
    fetchDataQuietly();
  }

  Future<void> _fetchSettingsAndAreas() async {
    try {
      final setRes = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_settings?select=*'),
        headers: AuthState.headers(),
      );
      if (setRes.statusCode == 200) {
        final list = jsonDecode(setRes.body) as List;
        if (list.isNotEmpty && list[0]['usd_rate'] != null) {
          usdRate = double.parse(list[0]['usd_rate'].toString());
        }
      }

      final areaRes = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_delivery_areas?select=*'),
        headers: AuthState.headers(),
      );
      if (areaRes.statusCode == 200) {
        final list = jsonDecode(areaRes.body) as List;
        if (mounted) setState(() => deliveryAreas = list);
      }
    } catch (_) {}
  }

  Future<void> fetchDataQuietly() async {
    try {
      final prodRes = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_products?select=*&is_visible=eq.true&order=created_at.desc'),
        headers: AuthState.headers(),
      );
      if (prodRes.statusCode == 200) {
        final list = jsonDecode(prodRes.body) as List;
        if (mounted) setState(() => products = list);
      } else if (prodRes.statusCode == 401) {
        if (await AuthState.refreshSession()) {
          fetchDataQuietly();
        }
      }
    } catch (_) {}
  }

  Future<void> _addToCart(Map<String, dynamic> p) async {
    if (AuthState.userId == null) return;
    final productId = p['id'];
    try {
      // Check existing in cart
      final resCart = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_cart_items?customer_id=eq.${AuthState.userId}&product_id=eq.$productId'),
        headers: AuthState.headers(),
      );
      if (resCart.statusCode == 200) {
        final list = jsonDecode(resCart.body) as List;
        if (list.isNotEmpty) {
          final existingId = list[0]['id'];
          final currentQty = list[0]['quantity'] ?? 1;
          await http.patch(
            Uri.parse('$kSupabaseUrl/rest/v1/tarag3_cart_items?id=eq.$existingId'),
            headers: AuthState.headers(),
            body: jsonEncode({"quantity": currentQty + 1}),
          );
        } else {
          await http.post(
            Uri.parse('$kSupabaseUrl/rest/v1/tarag3_cart_items'),
            headers: AuthState.headers(),
            body: jsonEncode({
              "customer_id": AuthState.userId,
              "product_id": productId,
              "quantity": 1,
            }),
          );
        }
        widget.onCartUpdated();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تمت إضافة المنتج للسلة')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر إضافة المنتج للسلة')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = products.where((p) {
      final catMatch = selectedCategory == 'الكل' || p['category'] == selectedCategory;
      final queryMatch = searchQuery.isEmpty || (p['name'] ?? '').toString().toLowerCase().contains(searchQuery.toLowerCase());
      return catMatch && queryMatch;
    }).toList();

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          // Search Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 44,
              child: TextField(
                onChanged: (val) => setState(() => searchQuery = val),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0A2F6B)),
                decoration: InputDecoration(
                  hintText: 'ابحث عن جهاز، مستهلك، شاش، جلوكوز...',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8), size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE1E9F3))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF0A47A8))),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Categories Horizontal Chips
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: ['الكل', 'معدات', 'مستهلكات', 'مختبر'].map((cat) {
                final isSel = selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: InkWell(
                    onTap: () => setState(() => selectedCategory = cat),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel ? const Color(0xFF0A47A8) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSel ? const Color(0xFF0A47A8) : const Color(0xFFE1E9F3)),
                        boxShadow: isSel ? const [BoxShadow(color: Color(0x330A47A8), blurRadius: 8, offset: Offset(0, 2))] : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: isSel ? Colors.white : const Color(0xFF475569),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          // Interactive Delivery Area Bar
          if (deliveryAreas.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFE0F7FA), Color(0xFFE8F5E9)]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFB2EBF2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, color: Color(0xFF006064), size: 18),
                        const SizedBox(width: 8),
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(text: 'التوصيل إلى: ', style: TextStyle(color: Color(0xFF006064), fontSize: 13, fontWeight: FontWeight.w600)),
                              TextSpan(text: '${deliveryAreas.first['name'] ?? "عطبرة"}', style: const TextStyle(color: Color(0xFF006064), fontSize: 13, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFF00838F), borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        '${intl.NumberFormat('#,###').format(deliveryAreas.first['delivery_fee'] ?? 3000)} ج.س',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),

          // Product Grid
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('لا يوجد منتجات في هذا القسم حالياً', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.66,
                ),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final p = filtered[index];
                  final double priceUsd = p['price_usd'] != null ? double.parse(p['price_usd'].toString()) : 0.0;
                  final double priceSdg = priceUsd * usdRate;
                  final imgUrl = p['image_url'] as String?;

                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ProductDetailsScreen(product: p, usdRate: usdRate, onCartUpdated: widget.onCartUpdated)),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE1E9F3)),
                        boxShadow: const [BoxShadow(color: Color(0x0A0A2F6B), blurRadius: 8, offset: Offset(0, 2))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            height: 110,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            clipBehavior: Clip.antiAlias,
                            alignment: Alignment.center,
                            child: imgUrl != null && imgUrl.startsWith('http')
                                ? CachedNetworkImage(imageUrl: imgUrl, fit: BoxFit.cover, errorWidget: (_, _, _) => const Icon(Icons.science_outlined, size: 40, color: Color(0xFF0A47A8)))
                                : Icon(
                                    index % 2 == 0 ? Icons.science_outlined : Icons.monitor_heart_outlined,
                                    size: 48,
                                    color: index % 2 == 0 ? const Color(0xFF0A47A8) : const Color(0xFF00B8C4),
                                  ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            p['category'] ?? 'مستهلكات',
                            style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                          SizedBox(
                            height: 34,
                            child: Text(
                              p['name'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0A2F6B), height: 1.3),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '${intl.NumberFormat('#,###').format(priceSdg)} ',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0A47A8)),
                                ),
                                const TextSpan(
                                  text: 'ج.س',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 36,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                backgroundColor: const Color(0xFFEBF2FA),
                                foregroundColor: const Color(0xFF0A47A8),
                                side: const BorderSide(color: Color(0xFFD0E1F9)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: EdgeInsets.zero,
                              ),
                              onPressed: () => _addToCart(p),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('أضف للسلة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
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
}

// --- 2. PRODUCT DETAILS SCREEN ---
class ProductDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> product;
  final double usdRate;
  final VoidCallback onCartUpdated;

  const ProductDetailsScreen({
    super.key,
    required this.product,
    required this.usdRate,
    required this.onCartUpdated,
  });

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  int quantity = 1;
  bool adding = false;

  Future<void> _addToCart() async {
    if (AuthState.userId == null) return;
    setState(() => adding = true);
    final productId = widget.product['id'];
    try {
      final resCart = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_cart_items?customer_id=eq.${AuthState.userId}&product_id=eq.$productId'),
        headers: AuthState.headers(),
      );
      if (resCart.statusCode == 200) {
        final list = jsonDecode(resCart.body) as List;
        if (list.isNotEmpty) {
          final existingId = list[0]['id'];
          final currentQty = list[0]['quantity'] ?? 0;
          await http.patch(
            Uri.parse('$kSupabaseUrl/rest/v1/tarag3_cart_items?id=eq.$existingId'),
            headers: AuthState.headers(),
            body: jsonEncode({"quantity": currentQty + quantity}),
          );
        } else {
          await http.post(
            Uri.parse('$kSupabaseUrl/rest/v1/tarag3_cart_items'),
            headers: AuthState.headers(),
            body: jsonEncode({
              "customer_id": AuthState.userId,
              "product_id": productId,
              "quantity": quantity,
            }),
          );
        }
        widget.onCartUpdated();
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة المنتج للسلة بنجاح')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر إضافة المنتج للسلة')));
      }
    } finally {
      if (mounted) setState(() => adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double priceUsd = widget.product['price_usd'] != null ? double.parse(widget.product['price_usd'].toString()) : 0.0;
    final double priceSdg = priceUsd * widget.usdRate;
    final imgUrl = widget.product['image_url'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل المنتج'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE1E9F3)),
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: imgUrl != null && imgUrl.startsWith('http')
                ? CachedNetworkImage(imageUrl: imgUrl, fit: BoxFit.cover, width: double.infinity)
                : const Icon(Icons.science_outlined, size: 80, color: Color(0xFF0A47A8)),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE1E9F3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFE6F4EA), borderRadius: BorderRadius.circular(20)),
                      child: Text(
                        (widget.product['stock_quantity'] ?? 0) > 0 ? 'متوفر' : 'غير متوفر',
                        style: TextStyle(
                          color: (widget.product['stock_quantity'] ?? 0) > 0 ? const Color(0xFF00A86B) : Colors.red,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Text('قسم ${widget.product['category'] ?? "المختبر"}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
                  ],
                ),
                const SizedBox(height: 8),
                Text(widget.product['name'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0A2F6B))),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '${intl.NumberFormat('#,###').format(priceSdg)} ',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0A47A8)),
                      ),
                      const TextSpan(
                        text: 'جنيه سوداني',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.product['description'] ?? 'لا يوجد وصف متاح للمنتج حالياً.',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.6),
                ),
                const SizedBox(height: 16),
                Container(height: 1, color: const Color(0xFFE1E9F3)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('الكمية المطلوبة:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0A2F6B))),
                    Container(
                      decoration: BoxDecoration(color: const Color(0xFFF0F4F9), borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () {
                              if (quantity > 1) setState(() => quantity--);
                            },
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE1E9F3))),
                              alignment: Alignment.center,
                              child: const Text('-', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Text('$quantity', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                          ),
                          InkWell(
                            onTap: () => setState(() => quantity++),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE1E9F3))),
                              alignment: Alignment.center,
                              child: const Text('+', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 46,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A47A8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: adding ? null : _addToCart,
              icon: adding ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.shopping_bag_outlined, size: 20),
              label: Text(
                'أضف للسلة (${intl.NumberFormat('#,###').format(priceSdg * quantity)} ج.س)',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- 3. CART SCREEN ---
class CartScreen extends StatefulWidget {
  final VoidCallback onCartUpdated;
  const CartScreen({super.key, required this.onCartUpdated});

  @override
  State<CartScreen> createState() => CartScreenState();
}

class CartScreenState extends State<CartScreen> {
  List<dynamic> cartItems = [];
  Map<int, dynamic> productsMap = {};
  double usdRate = 2700.0;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    fetchCartQuietly();
  }

  Future<void> fetchCartQuietly() async {
    if (AuthState.userId == null) return;
    try {
      final setRes = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_settings?select=*'),
        headers: AuthState.headers(),
      );
      if (setRes.statusCode == 200) {
        final list = jsonDecode(setRes.body) as List;
        if (list.isNotEmpty && list[0]['usd_rate'] != null) {
          usdRate = double.parse(list[0]['usd_rate'].toString());
        }
      }

      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_cart_items?customer_id=eq.${AuthState.userId}&order=created_at.desc'),
        headers: AuthState.headers(),
      );
      if (res.statusCode == 200) {
        final items = jsonDecode(res.body) as List;
        cartItems = items;

        if (items.isNotEmpty) {
          final pIds = items.map((e) => e['product_id']).toSet().join(',');
          final pRes = await http.get(
            Uri.parse('$kSupabaseUrl/rest/v1/tarag3_products?id=in.($pIds)'),
            headers: AuthState.headers(),
          );
          if (pRes.statusCode == 200) {
            final pList = jsonDecode(pRes.body) as List;
            productsMap = {for (var p in pList) p['id'] as int: p};
          }
        }
        if (mounted) setState(() {});
      } else if (res.statusCode == 401) {
        if (await AuthState.refreshSession()) {
          fetchCartQuietly();
        }
      }
    } catch (_) {}
  }

  Future<void> _updateQty(int cartId, int newQty) async {
    if (newQty <= 0) {
      await http.delete(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_cart_items?id=eq.$cartId'),
        headers: AuthState.headers(),
      );
    } else {
      await http.patch(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_cart_items?id=eq.$cartId'),
        headers: AuthState.headers(),
        body: jsonEncode({"quantity": newQty}),
      );
    }
    widget.onCartUpdated();
    await fetchCartQuietly();
  }

  @override
  Widget build(BuildContext context) {
    if (cartItems.isEmpty) {
      return const EmptyStateView();
    }

    double subtotal = 0;
    for (var item in cartItems) {
      final p = productsMap[item['product_id']];
      if (p != null) {
        final priceUsd = p['price_usd'] != null ? double.parse(p['price_usd'].toString()) : 0.0;
        final qty = (item['quantity'] ?? 1) as int;
        subtotal += (priceUsd * usdRate) * qty;
      }
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('سلة التسوق', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0A2F6B))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: const BoxDecoration(color: Color(0xFFEBF2FA), borderRadius: BorderRadius.all(Radius.circular(20))),
              child: Text('${cartItems.length} عناصر', style: const TextStyle(color: Color(0xFF0A47A8), fontWeight: FontWeight.w800, fontSize: 11)),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ...cartItems.map((item) {
            final p = productsMap[item['product_id']];
            final name = p != null ? p['name'] : 'منتج غير متوفر';
            final priceUsd = p != null && p['price_usd'] != null ? double.parse(p['price_usd'].toString()) : 0.0;
            final priceSdg = priceUsd * usdRate;
            final qty = (item['quantity'] ?? 1) as int;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE1E9F3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                    alignment: Alignment.center,
                    child: const Icon(Icons.science_outlined, size: 28, color: Color(0xFF0A47A8)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0A2F6B))),
                        const SizedBox(height: 2),
                        Text('${intl.NumberFormat('#,###').format(priceSdg)} ج.س', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0A47A8))),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(color: const Color(0xFFF0F4F9), borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () => _updateQty(item['id'], qty - 1),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE1E9F3))),
                            alignment: Alignment.center,
                            child: const Text('-', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text('$qty', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                        ),
                        InkWell(
                          onTap: () => _updateQty(item['id'], qty + 1),
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE1E9F3))),
                            alignment: Alignment.center,
                            child: const Text('+', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 10),

          // Order Summary Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE1E9F3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ملخص الحساب', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0A2F6B))),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('مجموع المنتجات:', style: TextStyle(fontSize: 13, color: Color(0xFF475569))),
                    Text('${intl.NumberFormat('#,###').format(subtotal)} ج.س', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A47A8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CheckoutScreen(
                      cartItems: cartItems,
                      productsMap: productsMap,
                      usdRate: usdRate,
                      subtotalSdg: subtotal,
                      onOrderCreated: () {
                        widget.onCartUpdated();
                        fetchCartQuietly();
                      },
                    ),
                  ),
                );
              },
              child: const Text('المتابعة لإتمام الطلب', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// --- 4. CHECKOUT SCREEN ---
class CheckoutScreen extends StatefulWidget {
  final List<dynamic> cartItems;
  final Map<int, dynamic> productsMap;
  final double usdRate;
  final double subtotalSdg;
  final VoidCallback onOrderCreated;

  const CheckoutScreen({
    super.key,
    required this.cartItems,
    required this.productsMap,
    required this.usdRate,
    required this.subtotalSdg,
    required this.onOrderCreated,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String deliveryType = 'توصيل';
  List<dynamic> deliveryAreas = [];
  Map<String, dynamic>? selectedArea;
  bool loading = false;

  late TextEditingController nameCtrl;
  late TextEditingController phoneCtrl;
  final addressCtrl = TextEditingController();
  final notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController(text: AuthState.fullName ?? '');
    phoneCtrl = TextEditingController(text: AuthState.phone ?? '');
    _fetchAreas();
  }

  Future<void> _fetchAreas() async {
    try {
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_delivery_areas?select=*'),
        headers: AuthState.headers(),
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        if (mounted && list.isNotEmpty) {
          setState(() {
            deliveryAreas = list;
            selectedArea = list[0];
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _submitOrder() async {
    if (nameCtrl.text.trim().isEmpty || phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء إدخال الاسم ورقم الهاتف')));
      return;
    }

    setState(() => loading = true);

    try {
      final deliveryFee = deliveryType == 'توصيل' && selectedArea != null
          ? double.parse(selectedArea!['delivery_fee'].toString())
          : 0.0;
      final totalSdg = widget.subtotalSdg + deliveryFee;
      final orderNumber = 'DMC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      // 1. Insert Order
      final orderRes = await http.post(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_orders'),
        headers: AuthState.headers(),
        body: jsonEncode({
          "order_number": orderNumber,
          "customer_id": AuthState.userId,
          "customer_name": nameCtrl.text.trim(),
          "customer_phone": phoneCtrl.text.trim(),
          "delivery_area_id": selectedArea?['id'],
          "delivery_area_name": selectedArea?['name'] ?? 'عام',
          "delivery_address": addressCtrl.text.trim(),
          "delivery_type": deliveryType,
          "payment_method": "الدفع عند الاستلام",
          "status": "جديد",
          "subtotal_sdg": widget.subtotalSdg,
          "delivery_fee": deliveryFee,
          "total_sdg": totalSdg,
          "usd_rate_used": widget.usdRate,
          "notes": notesCtrl.text.trim(),
        }),
      );

      if (orderRes.statusCode == 200 || orderRes.statusCode == 201) {
        final createdOrders = jsonDecode(orderRes.body) as List;
        final orderId = createdOrders[0]['id'];

        // 2. Insert Order Items
        for (var item in widget.cartItems) {
          final p = widget.productsMap[item['product_id']];
          if (p != null) {
            final priceUsd = p['price_usd'] != null ? double.parse(p['price_usd'].toString()) : 0.0;
            final priceSdg = priceUsd * widget.usdRate;
            final qty = (item['quantity'] ?? 1) as int;

            await http.post(
              Uri.parse('$kSupabaseUrl/rest/v1/tarag3_order_items'),
              headers: AuthState.headers(),
              body: jsonEncode({
                "order_id": orderId,
                "product_id": p['id'],
                "product_name": p['name'],
                "quantity": qty,
                "price_usd": priceUsd,
                "price_sdg": priceSdg,
                "total_sdg": priceSdg * qty,
              }),
            );
          }
        }

        // 3. Clear Cart
        await http.delete(
          Uri.parse('$kSupabaseUrl/rest/v1/tarag3_cart_items?customer_id=eq.${AuthState.userId}'),
          headers: AuthState.headers(),
        );

        // 4. Send Notification to Admin
        await http.post(
          Uri.parse('$kSupabaseUrl/rest/v1/tarag3_notifications'),
          headers: AuthState.headers(),
          body: jsonEncode({
            "to_role": "admin",
            "title": "طلب جديد #$orderNumber",
            "body": "قام ${nameCtrl.text.trim()} بتقديم طلب جديد بإجمالي ${intl.NumberFormat('#,###').format(totalSdg)} ج.س",
            "data": {"order_id": orderId},
          }),
        );

        widget.onOrderCreated();
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم إرسال الطلب بنجاح #$orderNumber')),
        );
      } else {
        final data = jsonDecode(orderRes.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data['message'] ?? 'فشل إنشاء الطلب')),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ في الاتصال أثناء تنفيذ الطلب')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deliveryFee = deliveryType == 'توصيل' && selectedArea != null
        ? double.parse(selectedArea!['delivery_fee'].toString())
        : 0.0;
    final totalSdg = widget.subtotalSdg + deliveryFee;

    return Scaffold(
      appBar: AppBar(
        title: const Text('إتمام الطلب'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE1E9F3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('بيانات الاستلام والتوصيل', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0A2F6B))),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('الاسم بالكامل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0A2F6B))),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 46,
                      child: TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE1E9F3))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE1E9F3))),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('رقم الهاتف', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0A2F6B))),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 46,
                      child: TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE1E9F3))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE1E9F3))),
                        ),
                      ),
                    ),
                  ],
                ),
                if (deliveryType == 'توصيل' && deliveryAreas.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('منطقة التوصيل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0A2F6B))),
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 46,
                        child: DropdownButtonFormField<Map<String, dynamic>>(
                          initialValue: selectedArea,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE1E9F3))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE1E9F3))),
                          ),
                          items: deliveryAreas.map((area) {
                            final fee = area['delivery_fee'] != null ? double.parse(area['delivery_fee'].toString()) : 0.0;
                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: area,
                              child: Text('${area['name']} (${intl.NumberFormat('#,###').format(fee)} ج.س)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => selectedArea = val);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('العنوان التفصيلي / الملاحظات', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0A2F6B))),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 46,
                      child: TextField(
                        controller: addressCtrl,
                        decoration: InputDecoration(
                          hintText: 'اسم الحي، شارع، مستشفى أو عيادة...',
                          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE1E9F3))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFE1E9F3))),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Options Row
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE1E9F3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('طريقة الاستلام', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0A2F6B))),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => deliveryType = 'توصيل'),
                        child: Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: deliveryType == 'توصيل' ? const Color(0xFFEBF2FA) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: deliveryType == 'توصيل' ? const Color(0xFF0A47A8) : const Color(0xFFE1E9F3),
                              width: deliveryType == 'توصيل' ? 1.5 : 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'توصيل للموقع',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: deliveryType == 'توصيل' ? const Color(0xFF0A47A8) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => deliveryType = 'استلام'),
                        child: Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: deliveryType == 'استلام' ? const Color(0xFFEBF2FA) : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: deliveryType == 'استلام' ? const Color(0xFF0A47A8) : const Color(0xFFE1E9F3),
                              width: deliveryType == 'استلام' ? 1.5 : 1,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'استلام من المحل',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: deliveryType == 'استلام' ? const Color(0xFF0A47A8) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('طريقة الدفع', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0A2F6B))),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE1E9F3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.payments_outlined, color: Color(0xFF0A2F6B), size: 20),
                      SizedBox(width: 8),
                      Text('الدفع كاش عند الاستلام', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0A2F6B))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            height: 46,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A47A8),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: loading ? null : _submitOrder,
              child: loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('تأكيد الطلب (${intl.NumberFormat('#,###').format(totalSdg)} ج.س)', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

// --- 5. MY ORDERS SCREEN ---
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => OrdersScreenState();
}

class OrdersScreenState extends State<OrdersScreen> {
  List<dynamic> orders = [];
  bool loading = false;

  @override
  void initState() {
    super.initState();
    fetchOrdersQuietly();
  }

  Future<void> fetchOrdersQuietly() async {
    if (AuthState.userId == null) return;
    try {
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_orders?customer_id=eq.${AuthState.userId}&order=created_at.desc'),
        headers: AuthState.headers(),
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        if (mounted) setState(() => orders = list);
      } else if (res.statusCode == 401) {
        if (await AuthState.refreshSession()) {
          fetchOrdersQuietly();
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('قائمة طلباتي', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0A2F6B))),
      ),
      body: orders.isEmpty
          ? const Center(
              child: Text('لا توجد طلبات سابقة حتى الآن', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final o = orders[index];
                final double total = o['total_sdg'] != null ? double.parse(o['total_sdg'].toString()) : 0.0;
                final status = o['status'] ?? 'جديد';
                final dateStr = o['created_at'] != null
                    ? intl.DateFormat('yyyy/MM/dd - hh:mm a').format(DateTime.parse(o['created_at']))
                    : '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE1E9F3)),
                    boxShadow: const [BoxShadow(color: Color(0x0A0A2F6B), blurRadius: 8, offset: Offset(0, 2))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('طلب #${o['order_number'] ?? o['id']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0A2F6B))),
                              Text(dateStr, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: status == 'تم'
                                  ? const Color(0xFFE6F4EA)
                                  : status == 'في الطريق'
                                      ? const Color(0xFFE0F7FA)
                                      : const Color(0xFFFFF4E5),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: status == 'تم'
                                    ? const Color(0xFF00A86B)
                                    : status == 'في الطريق'
                                        ? const Color(0xFF00838F)
                                        : const Color(0xFFFF9800),
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'منطقة التوصيل: ${o['delivery_area_name'] ?? "عام"}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${intl.NumberFormat('#,###').format(total)} ج.س', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0A47A8))),
                          SizedBox(
                            height: 34,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEBF2FA),
                                foregroundColor: const Color(0xFF0A2F6B),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceScreen(order: o)));
                              },
                              child: const Text('عرض الفاتورة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// --- 6. INVOICE SCREEN ---
class InvoiceScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  const InvoiceScreen({super.key, required this.order});

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  List<dynamic> items = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchItems();
  }

  Future<void> _fetchItems() async {
    try {
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_order_items?order_id=eq.${widget.order['id']}'),
        headers: AuthState.headers(),
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        if (mounted) setState(() => items = list);
      }
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final double subtotal = o['subtotal_sdg'] != null ? double.parse(o['subtotal_sdg'].toString()) : 0.0;
    final double deliveryFee = o['delivery_fee'] != null ? double.parse(o['delivery_fee'].toString()) : 0.0;
    final double total = o['total_sdg'] != null ? double.parse(o['total_sdg'].toString()) : 0.0;
    final dateStr = o['created_at'] != null ? intl.DateFormat('yyyy/MM/dd').format(DateTime.parse(o['created_at'])) : '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('فاتورة المبيعات'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF0A2F6B), width: 2),
              boxShadow: const [BoxShadow(color: Color(0x140A2F6B), blurRadius: 16, offset: Offset(0, 4))],
            ),
            child: Column(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF0A2F6B), Color(0xFF0A47A8)]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Text('DMC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
                ),
                const SizedBox(height: 6),
                const Text('Diala Medical & Chemical', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0A2F6B))),
                const Text('فاتورة مبيعات رسمية', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                const SizedBox(height: 12),
                Container(height: 1, color: const Color(0xFFCBD5E1)),
                const SizedBox(height: 12),

                Align(
                  alignment: Alignment.centerRight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('اسم العميل: ${o['customer_name'] ?? AuthState.fullName ?? ""}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0A2F6B))),
                      Text('رقم الفاتورة: #${o['order_number'] ?? o['id']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0A2F6B))),
                      Text('التاريخ: $dateStr', style: const TextStyle(fontSize: 11, color: Color(0xFF0A2F6B))),
                      Text('منطقة التوصيل: ${o['delivery_area_name'] ?? "عام"}', style: const TextStyle(fontSize: 11, color: Color(0xFF0A2F6B))),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                if (loading)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  )
                else
                  Table(
                    border: TableBorder.all(color: const Color(0xFFCBD5E1), width: 1),
                    columnWidths: const {
                      0: FlexColumnWidth(2.5),
                      1: FlexColumnWidth(1),
                      2: FlexColumnWidth(1.8),
                      3: FlexColumnWidth(1.8),
                    },
                    children: [
                      const TableRow(
                        decoration: BoxDecoration(color: Color(0xFFF1F5F9)),
                        children: [
                          Padding(padding: EdgeInsets.all(6), child: Text('الصنف', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11), textAlign: TextAlign.center)),
                          Padding(padding: EdgeInsets.all(6), child: Text('الكمية', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11), textAlign: TextAlign.center)),
                          Padding(padding: EdgeInsets.all(6), child: Text('السعر', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11), textAlign: TextAlign.center)),
                          Padding(padding: EdgeInsets.all(6), child: Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11), textAlign: TextAlign.center)),
                        ],
                      ),
                      ...items.map((it) {
                        final pSdg = it['price_sdg'] != null ? double.parse(it['price_sdg'].toString()) : 0.0;
                        final tSdg = it['total_sdg'] != null ? double.parse(it['total_sdg'].toString()) : 0.0;
                        return TableRow(
                          children: [
                            Padding(padding: const EdgeInsets.all(6), child: Text(it['product_name'] ?? '', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                            Padding(padding: const EdgeInsets.all(6), child: Text('${it['quantity'] ?? 1}', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                            Padding(padding: const EdgeInsets.all(6), child: Text(intl.NumberFormat('#,###').format(pSdg), style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                            Padding(padding: const EdgeInsets.all(6), child: Text(intl.NumberFormat('#,###').format(tSdg), style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                          ],
                        );
                      }),
                    ],
                  ),
                const SizedBox(height: 12),

                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('مجموع الصافي: ${intl.NumberFormat('#,###').format(subtotal)} ج.س', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      Text('رسوم التوصيل: ${intl.NumberFormat('#,###').format(deliveryFee)} ج.س', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('المطلوب: ${intl.NumberFormat('#,###').format(total)} ج.س', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0A47A8))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A47A8), foregroundColor: Colors.white),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('جاري تجهيز طباعة الفاتورة...')));
                    },
                    icon: const Icon(Icons.print, size: 18),
                    label: const Text('طباعة / PDF', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEBF2FA), foregroundColor: const Color(0xFF0A2F6B), elevation: 0),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('مشاركة رابط الفاتورة')));
                    },
                    child: const Text('مشاركة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- 7. CONTACT US SCREEN ---
class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key});

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  Map<String, dynamic>? settings;
  List<dynamic> deliveryAreas = [];

  @override
  void initState() {
    super.initState();
    _fetchInfo();
  }

  Future<void> _fetchInfo() async {
    try {
      final sRes = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_settings?select=*'),
        headers: AuthState.headers(),
      );
      if (sRes.statusCode == 200) {
        final list = jsonDecode(sRes.body) as List;
        if (list.isNotEmpty && mounted) setState(() => settings = list[0]);
      }

      final aRes = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_delivery_areas?select=*'),
        headers: AuthState.headers(),
      );
      if (aRes.statusCode == 200) {
        final list = jsonDecode(aRes.body) as List;
        if (mounted) setState(() => deliveryAreas = list);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final phone = settings?['store_phone'] ?? '0912345678';
    final whatsapp = settings?['store_whatsapp'] ?? '249912345678';
    final storeName = settings?['store_name'] ?? 'Diala Medical & Chemical';

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('تواصل معنا', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0A2F6B))),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE1E9F3)),
            ),
            child: Column(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF0A2F6B), Color(0xFF0A47A8)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: const Text('DMC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)),
                ),
                const SizedBox(height: 10),
                Text(storeName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0A2F6B))),
                const SizedBox(height: 4),
                const Text('نحن هنا لخدمتكم وتوفير جميع احتياجاتكم الطبية', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => launchUrl(Uri.parse('https://wa.me/$whatsapp')),
                    child: const Text('تواصل عبر الواتساب', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 10),

                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A47A8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => launchUrl(Uri.parse('tel:$phone')),
                    child: const Text('اتصال هاتفي مباشر', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE1E9F3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('مناطق التوصيل المتاحة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0A2F6B))),
                const SizedBox(height: 10),
                if (deliveryAreas.isEmpty)
                  const Text('عطبرة، بربر، الدامر، أبوحمد', style: TextStyle(fontSize: 13, color: Color(0xFF475569)))
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: deliveryAreas.map((a) {
                      final fee = a['delivery_fee'] != null ? double.parse(a['delivery_fee'].toString()) : 0.0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('• ${a['name']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                            Text('${intl.NumberFormat('#,###').format(fee)} ج.س', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0A47A8))),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- 8. NOTIFICATIONS SCREEN ---
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> notifications = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchInbox();
  }

  Future<void> _fetchInbox() async {
    if (AuthState.userId == null) return;
    try {
      final res = await http.get(
        Uri.parse(
          '$kSupabaseUrl/rest/v1/tarag3_notifications?or=(to_user.eq.${AuthState.userId},to_role.eq.customer)&order=created_at.desc',
        ),
        headers: AuthState.headers(),
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        if (mounted) setState(() => notifications = list);
      } else if (res.statusCode == 401) {
        if (await AuthState.refreshSession()) {
          _fetchInbox();
        }
      }
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  Future<void> _markRead(int notifId) async {
    final nowIso = DateTime.now().toIso8601String();
    try {
      await http.patch(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_notifications?id=eq.$notifId'),
        headers: AuthState.headers(),
        body: jsonEncode({"read_at": nowIso}),
      );
      _fetchInbox();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات والتنبيهات'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : notifications.isEmpty
              ? const Center(
                  child: Text('لا توجد إشعارات حتى الآن', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final n = notifications[index];
                    final isRead = n['read_at'] != null;
                    final dateStr = n['created_at'] != null
                        ? intl.DateFormat('yyyy/MM/dd - hh:mm a').format(DateTime.parse(n['created_at']))
                        : '';

                    return InkWell(
                      onTap: () {
                        if (!isRead) _markRead(n['id']);
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isRead ? Colors.white : const Color(0xFFF0F7FF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isRead ? const Color(0xFFE1E9F3) : const Color(0xFF90CAF9)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isRead ? const Color(0xFFE0F7FA) : const Color(0xFF0A47A8),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.notifications_active_outlined,
                                color: isRead ? const Color(0xFF00B8C4) : Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(n['title'] ?? 'إشعار', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0A2F6B))),
                                  const SizedBox(height: 2),
                                  Text(n['body'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                  const SizedBox(height: 4),
                                  Text(dateStr, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// --- 9. EMPTY STATE VIEW ---
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: const BoxDecoration(color: Color(0xFFE0F7FA), shape: BoxShape.circle),
                alignment: Alignment.center,
                child: const Icon(Icons.shopping_bag_outlined, size: 48, color: Color(0xFF00B8C4)),
              ),
              const SizedBox(height: 16),
              const Text('السلة فارغة حالياً', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0A2F6B))),
              const SizedBox(height: 6),
              const Text('لم تقم بإضافة أي معدات أو مستهلكات طبية إلى سلتك بعد.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            ],
          ),
        ),
      ),
    );
  }
}
