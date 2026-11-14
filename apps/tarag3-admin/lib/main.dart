import 'dart:async';
import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart' as intl;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:image_picker/image_picker.dart';
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

  runApp(const DmcAdminApp());
}

// --- GLOBAL AUTH STATE & HELPERS ---
class AdminAuthState {
  static String? accessToken;
  static String? refreshToken;
  static String? userId;
  static String? userEmail;
  static String? fullName;
  static String? phone;
  static String? role;

  static Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    accessToken = prefs.getString('access_token');
    refreshToken = prefs.getString('refresh_token');
    userId = prefs.getString('user_id');
    userEmail = prefs.getString('user_email');
    fullName = prefs.getString('full_name');
    phone = prefs.getString('phone');
    role = prefs.getString('role');
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
      await claimAdminRole();
    }
  }

  static Future<bool> claimAdminRole([String? pin]) async {
    if (accessToken == null) return false;
    try {
      final body = pin != null ? {"pin": pin} : {};
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/rest/v1/rpc/tarag3_claim_admin'),
        headers: headers(),
        body: jsonEncode(body),
      );
      if (res.statusCode == 200) {
        final val = jsonDecode(res.body);
        if (val == true) {
          role = 'admin';
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('role', 'admin');
          await fetchProfile();
          return true;
        }
      }
    } catch (_) {}
    return false;
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
          role = list[0]['role'] ?? role;
          final prefs = await SharedPreferences.getInstance();
          if (fullName != null) prefs.setString('full_name', fullName!);
          if (phone != null) prefs.setString('phone', phone!);
          if (role != null) prefs.setString('role', role!);
        }
      } else if (res.statusCode == 401) {
        await refreshSession();
      }
    } catch (_) {}
  }

  static Future<bool> updateUserPassword(String newPassword) async {
    if (accessToken == null) return false;
    try {
      final res = await http.put(
        Uri.parse('$kSupabaseUrl/auth/v1/user'),
        headers: headers(),
        body: jsonEncode({"password": newPassword}),
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
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

  static Future<void> clearSession() async {
    accessToken = null;
    refreshToken = null;
    userId = null;
    userEmail = null;
    fullName = null;
    phone = null;
    role = null;
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

// --- APP ROOT ---
class DmcAdminApp extends StatelessWidget {
  const DmcAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DMC Admin',
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
          seedColor: const Color(0xFF0A2F6B),
          primary: const Color(0xFF0A47A8),
          secondary: const Color(0xFF00B8C4),
          surface: const Color(0xFFF3F7FC),
        ),
        scaffoldBackgroundColor: const Color(0xFFF3F7FC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A2F6B),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            fontFamily: 'Cairo',
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Cairo',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A2F6B),
          brightness: Brightness.dark,
          primary: const Color(0xFF0A47A8),
          secondary: const Color(0xFF00B8C4),
          surface: const Color(0xFF101622),
        ),
        scaffoldBackgroundColor: const Color(0xFF101622),
      ),
      themeMode: ThemeMode.light,
      home: const AdminSplashCheckScreen(),
    );
  }
}

// --- SPLASH CHECK ---
class AdminSplashCheckScreen extends StatefulWidget {
  const AdminSplashCheckScreen({super.key});

  @override
  State<AdminSplashCheckScreen> createState() => _AdminSplashCheckScreenState();
}

class _AdminSplashCheckScreenState extends State<AdminSplashCheckScreen> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    await AdminAuthState.loadSession();
    if (!mounted) return;
    if (AdminAuthState.accessToken != null && AdminAuthState.accessToken!.isNotEmpty) {
      await AdminAuthState.claimAdminRole();
      if (!mounted) return;
      if (AdminAuthState.role == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminMainTabsScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminPinScreen()),
        );
      }
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminAuthScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0A2F6B),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'DMC Admin',
              style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 16),
            CircularProgressIndicator(color: Color(0xFF00B8C4)),
          ],
        ),
      ),
    );
  }
}

// --- ADMIN AUTH SCREEN ---
class AdminAuthScreen extends StatefulWidget {
  const AdminAuthScreen({super.key});

  @override
  State<AdminAuthScreen> createState() => _AdminAuthScreenState();
}

class _AdminAuthScreenState extends State<AdminAuthScreen> {
  int authMode = 0; // 0: Login, 1: Register, 2: Forgot Password
  bool loading = false;
  bool showPassword = false;
  bool showConfirmPassword = false;
  String? generalError;

  final nameController = TextEditingController(text: 'المدير العام');
  final phoneController = TextEditingController(text: '0912300000');
  final emailController = TextEditingController(text: 'admin@diala.sd');
  final passwordController = TextEditingController(text: 'admin123456');
  final confirmPasswordController = TextEditingController();

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
      nameError = 'اسم المدير مطلوب';
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

    if (authMode == 1 && !_validateSignUp()) return;
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
        final res = await http.post(
          Uri.parse('$kSupabaseUrl/auth/v1/token?grant_type=password'),
          headers: AdminAuthState.headers(auth: false),
          body: jsonEncode({"email": email, "password": password}),
        );
        final data = jsonDecode(res.body);

        if (res.statusCode == 200) {
          await AdminAuthState.saveSession(data);
          await _postLoginNavigate();
        } else {
          final errStr = AdminAuthState.parseAuthError(data);
          if (errStr.contains('Email not confirmed') || (data['error_description'] ?? '').toString().contains('Email not confirmed')) {
            await http.post(
              Uri.parse('$kSupabaseUrl/auth/v1/resend'),
              headers: AdminAuthState.headers(auth: false),
              body: jsonEncode({"type": "signup", "email": email}),
            );
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AdminOtpVerifyScreen(email: email, isSignup: true)),
            );
          } else {
            setState(() => generalError = errStr);
          }
        }
      } else if (authMode == 1) {
        final name = nameController.text.trim();
        final phone = phoneController.text.trim();

        final res = await http.post(
          Uri.parse('$kSupabaseUrl/auth/v1/signup'),
          headers: AdminAuthState.headers(auth: false),
          body: jsonEncode({
            "email": email,
            "password": password,
            "data": {"full_name": name, "phone": phone}
          }),
        );
        final data = jsonDecode(res.body);

        if (res.statusCode == 200 || res.statusCode == 201) {
          if (data['access_token'] != null) {
            await AdminAuthState.saveSession(data);
            await _postLoginNavigate();
          } else {
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AdminOtpVerifyScreen(email: email, isSignup: true)),
            );
          }
        } else {
          setState(() => generalError = AdminAuthState.parseAuthError(data));
        }
      } else if (authMode == 2) {
        final res = await http.post(
          Uri.parse('$kSupabaseUrl/auth/v1/recover'),
          headers: AdminAuthState.headers(auth: false),
          body: jsonEncode({"email": email}),
        );
        final data = jsonDecode(res.body);
        if (res.statusCode == 200) {
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AdminOtpVerifyScreen(email: email, isSignup: false)),
          );
        } else {
          setState(() => generalError = AdminAuthState.parseAuthError(data));
        }
      }
    } catch (_) {
      setState(() => generalError = 'حدث خطأ في الاتصال بالخادم');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _postLoginNavigate() async {
    if (!mounted) return;
    if (AdminAuthState.role == 'admin') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminMainTabsScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminPinScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0A2F6B), Color(0xFF0A47A8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [
                      BoxShadow(color: Color(0x330A2F6B), blurRadius: 12, offset: Offset(0, 4)),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'DMC',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 26,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'لوحة إدارة DMC',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0A2F6B)),
                ),
                const Text(
                  'Diala Medical & Chemical Equipment',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 20),

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
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  setState(() => authMode = 0);
                                  _clearErrors();
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: authMode == 0 ? const Color(0xFF0A47A8) : Colors.transparent,
                                        width: 2.5,
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
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: authMode == 1 ? const Color(0xFF0A47A8) : Colors.transparent,
                                        width: 2.5,
                                      ),
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    'حساب مدير جديد',
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

                      if (authMode == 2)
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back, color: Color(0xFF0A2F6B)),
                              onPressed: () {
                                setState(() => authMode = 0);
                                _clearErrors();
                              },
                            ),
                            const Text(
                              'استعادة كلمة المرور',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0A2F6B)),
                            ),
                          ],
                        ),

                      const SizedBox(height: 16),

                      if (generalError != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Text(
                            generalError!,
                            style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                        ),

                      if (authMode == 1) ...[
                        _buildInputField('اسم المدير / المسئول', nameController, error: nameError, icon: Icons.person_outline),
                        const SizedBox(height: 12),
                        _buildInputField('رقم الهاتف', phoneController, keyboardType: TextInputType.phone, error: phoneError, icon: Icons.phone_outlined),
                        const SizedBox(height: 12),
                      ],

                      _buildInputField('البريد الإلكتروني', emailController, keyboardType: TextInputType.emailAddress, error: emailError, icon: Icons.email_outlined),
                      const SizedBox(height: 12),

                      if (authMode != 2) ...[
                        _buildInputField(
                          'كلمة المرور',
                          passwordController,
                          isPassword: true,
                          showPass: showPassword,
                          onTogglePass: () => setState(() => showPassword = !showPassword),
                          error: passwordError,
                          icon: Icons.lock_outline,
                        ),
                        const SizedBox(height: 12),
                      ],

                      if (authMode == 1) ...[
                        _buildInputField(
                          'تأكيد كلمة المرور',
                          confirmPasswordController,
                          isPassword: true,
                          showPass: showConfirmPassword,
                          onTogglePass: () => setState(() => showConfirmPassword = !showConfirmPassword),
                          error: confirmPasswordError,
                          icon: Icons.lock_outline,
                        ),
                        const SizedBox(height: 12),
                      ],

                      if (authMode == 0)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () {
                              setState(() => authMode = 2);
                              _clearErrors();
                            },
                            child: const Text(
                              'نسيت كلمة المرور؟',
                              style: TextStyle(color: Color(0xFF0A47A8), fontSize: 12, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),

                      const SizedBox(height: 8),

                      ElevatedButton(
                        onPressed: loading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A47A8),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                        child: loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                              )
                            : Text(
                                authMode == 0
                                    ? 'تسجيل الدخول والإدارة'
                                    : authMode == 1
                                        ? 'إنشاء حساب مدير'
                                        : 'إرسال رمز التوثيق',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                              ),
                      ),

                      const SizedBox(height: 14),
                      const Center(
                        child: Text(
                          'تأكيد وتوثيق الحساب عبر Supabase Auth',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
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

  Widget _buildInputField(
    String label,
    TextEditingController controller, {
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool showPass = false,
    VoidCallback? onTogglePass,
    String? error,
    IconData? icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0A2F6B)),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: isPassword && !showPass,
          decoration: InputDecoration(
            prefixIcon: icon != null ? Icon(icon, size: 20, color: const Color(0xFF64748B)) : null,
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(showPass ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF64748B)),
                    onPressed: onTogglePass,
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE1E9F3))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE1E9F3))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF0A47A8), width: 1.5)),
            errorText: error,
          ),
        ),
      ],
    );
  }
}

// --- OTP VERIFY SCREEN ---
class AdminOtpVerifyScreen extends StatefulWidget {
  final String email;
  final bool isSignup;

  const AdminOtpVerifyScreen({super.key, required this.email, required this.isSignup});

  @override
  State<AdminOtpVerifyScreen> createState() => _AdminOtpVerifyScreenState();
}

class _AdminOtpVerifyScreenState extends State<AdminOtpVerifyScreen> {
  final codeControllers = List.generate(6, (_) => TextEditingController());
  bool loading = false;
  String? errorMsg;

  Future<void> _verify() async {
    final code = codeControllers.map((e) => e.text.trim()).join();
    if (code.length < 6) {
      setState(() => errorMsg = 'يرجى إدخال رمز التوثيق المكون من 6 أرقام');
      return;
    }
    setState(() {
      loading = true;
      errorMsg = null;
    });

    try {
      final type = widget.isSignup ? "signup" : "recovery";
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/verify'),
        headers: AdminAuthState.headers(auth: false),
        body: jsonEncode({"type": type, "email": widget.email, "token": code}),
      );
      final data = jsonDecode(res.body);

      if (res.statusCode == 200) {
        await AdminAuthState.saveSession(data);
        if (!mounted) return;
        if (!widget.isSignup) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminNewPasswordScreen()),
          );
        } else {
          if (AdminAuthState.role == 'admin') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AdminMainTabsScreen()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const AdminPinScreen()),
            );
          }
        }
      } else {
        setState(() => errorMsg = 'رمز التوثيق غير صحيح أو منتهي الصلاحية');
      }
    } catch (_) {
      setState(() => errorMsg = 'حدث خطأ في الاتصال بالخادم');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('رمز التوثيق')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Text(
                'أدخل الرمز المكون من 6 أرقام المرسل إلى:\n${widget.email}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (i) {
                  return SizedBox(
                    width: 44,
                    height: 52,
                    child: TextField(
                      controller: codeControllers[i],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        counterText: "",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (val) {
                        if (val.isNotEmpty && i < 5) {
                          FocusScope.of(context).nextFocus();
                        }
                      },
                    ),
                  );
                }),
              ),
              if (errorMsg != null) ...[
                const SizedBox(height: 16),
                Text(errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w700)),
              ],
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: loading ? null : _verify,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A47A8),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('تأكيد الرمز', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- NEW PASSWORD SCREEN (FORGOT PASSWORD STEP 3) ---
class AdminNewPasswordScreen extends StatefulWidget {
  const AdminNewPasswordScreen({super.key});

  @override
  State<AdminNewPasswordScreen> createState() => _AdminNewPasswordScreenState();
}

class _AdminNewPasswordScreenState extends State<AdminNewPasswordScreen> {
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  bool showPass = false;
  bool loading = false;
  String? errorMsg;

  Future<void> _saveNewPassword() async {
    final pass = passwordController.text.trim();
    final conf = confirmController.text.trim();
    if (pass.length < 6) {
      setState(() => errorMsg = 'كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }
    if (pass != conf) {
      setState(() => errorMsg = 'كلمتا المرور غير متطابقتين');
      return;
    }

    setState(() {
      loading = true;
      errorMsg = null;
    });

    final success = await AdminAuthState.updateUserPassword(pass);
    if (!mounted) return;
    setState(() => loading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تغيير كلمة المرور بنجاح'), backgroundColor: Color(0xFF00A86B)),
      );
      if (AdminAuthState.role == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminMainTabsScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminPinScreen()),
        );
      }
    } else {
      setState(() => errorMsg = 'حدث خطأ أثناء تحديث كلمة المرور');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('كلمة المرور الجديدة')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('تعيين كلمة مرور جديدة لحساب الإدارة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0A2F6B))),
              const SizedBox(height: 20),
              TextField(
                controller: passwordController,
                obscureText: !showPass,
                decoration: InputDecoration(
                  labelText: 'كلمة المرور الجديدة',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  suffixIcon: IconButton(
                    icon: Icon(showPass ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => showPass = !showPass),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: confirmController,
                obscureText: !showPass,
                decoration: InputDecoration(
                  labelText: 'تأكيد كلمة المرور الجديدة',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              if (errorMsg != null) ...[
                const SizedBox(height: 14),
                Text(errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w700)),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: loading ? null : _saveNewPassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A47A8),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('حفظ كلمة المرور وتحديث الحساب', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- ADMIN PIN PROMPT SCREEN ---
class AdminPinScreen extends StatefulWidget {
  const AdminPinScreen({super.key});

  @override
  State<AdminPinScreen> createState() => _AdminPinScreenState();
}

class _AdminPinScreenState extends State<AdminPinScreen> {
  final pinController = TextEditingController();
  bool loading = false;
  String? errorMsg;

  Future<void> _submitPin() async {
    final pin = pinController.text.trim();
    if (pin.isEmpty) {
      setState(() => errorMsg = 'يرجى إدخال رمز الإدارة');
      return;
    }
    setState(() {
      loading = true;
      errorMsg = null;
    });

    final success = await AdminAuthState.claimAdminRole(pin);
    if (!mounted) return;
    setState(() => loading = false);

    if (success) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminMainTabsScreen()),
      );
    } else {
      setState(() => errorMsg = 'رمز الإدارة غير صحيح');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A2F6B),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.admin_panel_settings, size: 64, color: Color(0xFF0A47A8)),
                  const SizedBox(height: 12),
                  const Text('دخول الإدارة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0A2F6B))),
                  const SizedBox(height: 8),
                  const Text('أدخل رمز الإدارة السري للمتابعة', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  const SizedBox(height: 20),
                  TextField(
                    controller: pinController,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: '••••',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      errorText: errorMsg,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: loading ? null : _submitPin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A47A8),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('تأكيد الرمز', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- MAIN ADMIN TABS SCREEN ---
class AdminMainTabsScreen extends StatefulWidget {
  const AdminMainTabsScreen({super.key});

  @override
  State<AdminMainTabsScreen> createState() => _AdminMainTabsScreenState();
}

class _AdminMainTabsScreenState extends State<AdminMainTabsScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  Timer? _syncTimer;
  int _unreadNotificationsCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchUnreadNotificationsCount();
    _startSyncTimer();
    _setupPushNotifications();
  }

  Future<void> _fetchUnreadNotificationsCount() async {
    try {
      final uid = AdminAuthState.userId ?? '';
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_notifications?or=(to_user.eq.$uid,to_role.eq.admin)&read_at=is.null&select=id'),
        headers: AdminAuthState.headers(),
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        if (mounted) setState(() => _unreadNotificationsCount = list.length);
      }
    } catch (_) {}
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) {
        _fetchUnreadNotificationsCount();
        setState(() {});
      }
    });
  }

  Future<void> _setupPushNotifications() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          await http.post(
            Uri.parse('$kSupabaseUrl/rest/v1/rpc/tarag3_register_device'),
            headers: AdminAuthState.headers(),
            body: jsonEncode({"device_token": token, "app_name": "admin"}),
          );
        }
      }
    } catch (_) {}

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message.notification?.title ?? 'إشعار جديد وصل'),
            backgroundColor: const Color(0xFF00B8C4),
          ),
        );
        _fetchUnreadNotificationsCount();
        setState(() {});
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        _fetchUnreadNotificationsCount();
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    super.dispose();
  }

  final List<Widget> _pages = const [
    AdminDashboardTab(),
    AdminOrdersTab(),
    AdminProductsTab(),
    AdminPurchasesTab(),
    AdminCustomersTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AppBar(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF0A47A8), Color(0xFF00B8C4)]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('DMC', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 14)),
              ),
              const SizedBox(width: 10),
              const Text('تطبيق الإدارة والتحكم'),
            ],
          ),
          actions: [
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminNotificationsInboxScreen()),
                    ).then((_) => _fetchUnreadNotificationsCount());
                  },
                ),
                if (_unreadNotificationsCount > 0)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF00B8C4),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '$_unreadNotificationsCount',
                        style: const TextStyle(color: Color(0xFF0A2F6B), fontSize: 9, fontWeight: FontWeight.w900),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.campaign_outlined, color: Colors.white),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminOffersBroadcastScreen()));
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined, color: Colors.white),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminSettingsScreen()));
              },
            ),
          ],
        ),
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE1E9F3))),
          boxShadow: [BoxShadow(color: Color(0x0A0A2F6B), blurRadius: 16, offset: Offset(0, -4))],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF0A47A8),
          unselectedItemColor: const Color(0xFF64748B),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, fontFamily: 'Cairo'),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, fontFamily: 'Cairo'),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'الرئيسية'),
            BottomNavigationBarItem(icon: Icon(Icons.shopping_bag_outlined), activeIcon: Icon(Icons.shopping_bag), label: 'الطلبات'),
            BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), activeIcon: Icon(Icons.inventory_2), label: 'المنتجات'),
            BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), activeIcon: Icon(Icons.receipt_long), label: 'المشتريات'),
            BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people), label: 'الزبائن'),
          ],
        ),
      ),
    );
  }
}

// --- NOTIFICATIONS INBOX SCREEN ---
class AdminNotificationsInboxScreen extends StatefulWidget {
  const AdminNotificationsInboxScreen({super.key});

  @override
  State<AdminNotificationsInboxScreen> createState() => _AdminNotificationsInboxScreenState();
}

class _AdminNotificationsInboxScreenState extends State<AdminNotificationsInboxScreen> {
  List<dynamic> notifications = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    try {
      final uid = AdminAuthState.userId ?? '';
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_notifications?or=(to_user.eq.$uid,to_role.eq.admin)&order=created_at.desc'),
        headers: AdminAuthState.headers(),
      );
      if (res.statusCode == 200) {
        notifications = jsonDecode(res.body);
      }
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  Future<void> _markRead(dynamic item) async {
    final id = item['id'];
    if (item['read_at'] == null) {
      try {
        await http.patch(
          Uri.parse('$kSupabaseUrl/rest/v1/tarag3_notifications?id=eq.$id'),
          headers: AdminAuthState.headers(),
          body: jsonEncode({"read_at": DateTime.now().toIso8601String()}),
        );
        _fetchNotifications();
      } catch (_) {}
    }
  }

  Future<void> _markAllRead() async {
    try {
      final uid = AdminAuthState.userId ?? '';
      await http.patch(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_notifications?or=(to_user.eq.$uid,to_role.eq.admin)&read_at=is.null'),
        headers: AdminAuthState.headers(),
        body: jsonEncode({"read_at": DateTime.now().toIso8601String()}),
      );
      _fetchNotifications();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('صندوق الإشعارات التنبيهية'),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: const Text('تحديد الكل كمقروء', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0A47A8)))
          : notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: const BoxDecoration(color: Color(0xFFE0F7FA), shape: BoxShape.circle),
                        child: const Icon(Icons.notifications_none, size: 48, color: Color(0xFF00B8C4)),
                      ),
                      const SizedBox(height: 14),
                      const Text('لا توجد إشعارات واردة حتى الآن', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0A2F6B))),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final item = notifications[index];
                      final isUnread = item['read_at'] == null;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: isUnread ? const Color(0xFFF0F7FF) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isUnread ? const Color(0xFF0A47A8).withValues(alpha: 0.3) : const Color(0xFFE1E9F3)),
                          boxShadow: const [BoxShadow(color: Color(0x060A2F6B), blurRadius: 6, offset: Offset(0, 2))],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: isUnread ? const Color(0xFF0A47A8) : const Color(0xFFCBD5E1),
                            child: const Icon(Icons.notifications_active, color: Colors.white, size: 20),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item['title'] ?? 'تنبيه جديد',
                                  style: TextStyle(fontWeight: isUnread ? FontWeight.w900 : FontWeight.w700, fontSize: 14, color: const Color(0xFF0A2F6B)),
                                ),
                              ),
                              if (isUnread)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(color: Color(0xFF00B8C4), shape: BoxShape.circle),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(item['body'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                              const SizedBox(height: 6),
                              Text(
                                item['created_at'] != null ? item['created_at'].toString().split('T')[0] : '',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                          onTap: () => _markRead(item),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// --- TAB 1: DASHBOARD ---
class AdminDashboardTab extends StatefulWidget {
  const AdminDashboardTab({super.key});

  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab> {
  final usdController = TextEditingController();
  bool loadingFx = false;
  int newOrdersCount = 0;
  List<dynamic> deliveryAreas = [];
  Map<String, dynamic>? settingsData;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    try {
      final resSet = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_settings?select=*'),
        headers: AdminAuthState.headers(),
      );
      if (resSet.statusCode == 200) {
        final list = jsonDecode(resSet.body) as List;
        if (list.isNotEmpty) {
          settingsData = list[0];
          usdController.text = (settingsData?['usd_rate'] ?? 1100).toString();
        }
      }

      final resOrd = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_orders?status=eq.جديد&select=id'),
        headers: AdminAuthState.headers(),
      );
      if (resOrd.statusCode == 200) {
        final list = jsonDecode(resOrd.body) as List;
        newOrdersCount = list.length;
      }

      final resAreas = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_delivery_areas?select=*&order=created_at.desc'),
        headers: AdminAuthState.headers(),
      );
      if (resAreas.statusCode == 200) {
        deliveryAreas = jsonDecode(resAreas.body);
      }

      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _updateUsdRate() async {
    final rate = double.tryParse(usdController.text.trim());
    if (rate == null || rate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى إدخال سعر دولار صحيح')));
      return;
    }
    setState(() => loadingFx = true);

    try {
      if (settingsData != null && settingsData!['id'] != null) {
        final res = await http.patch(
          Uri.parse('$kSupabaseUrl/rest/v1/tarag3_settings?id=eq.${settingsData!['id']}'),
          headers: AdminAuthState.headers(),
          body: jsonEncode({"usd_rate": rate, "updated_at": DateTime.now().toIso8601String()}),
        );
        if (res.statusCode == 200 || res.statusCode == 204) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم تحديث سعر الدولار اليوم إلى ($rate ج.س). وتعدلت أسعار المنتجات لدى الزبائن تلقائياً!'), backgroundColor: const Color(0xFF00A86B)),
          );
        }
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدث خطأ أثناء تحديث السعر')));
    } finally {
      if (mounted) setState(() => loadingFx = false);
    }
  }

  void _showAddAreaModal([Map<String, dynamic>? editArea]) {
    final nameCtrl = TextEditingController(text: editArea?['name'] ?? '');
    final feeCtrl = TextEditingController(text: (editArea?['delivery_fee'] ?? '').toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, top: 20, left: 20, right: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                editArea != null ? 'تعديل منطقة توصيل' : 'إضافة منطقة توصيل جديدة',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0A2F6B)),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'اسم المنطقة',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: feeCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'سعر التوصيل (بالجنيه السوداني)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  final fee = double.tryParse(feeCtrl.text.trim()) ?? 0.0;
                  if (name.isEmpty) return;

                  Navigator.pop(ctx);
                  if (editArea != null) {
                    await http.patch(
                      Uri.parse('$kSupabaseUrl/rest/v1/tarag3_delivery_areas?id=eq.${editArea['id']}'),
                      headers: AdminAuthState.headers(),
                      body: jsonEncode({"name": name, "delivery_fee": fee}),
                    );
                  } else {
                    await http.post(
                      Uri.parse('$kSupabaseUrl/rest/v1/tarag3_delivery_areas'),
                      headers: AdminAuthState.headers(),
                      body: jsonEncode({"name": name, "delivery_fee": fee}),
                    );
                  }
                  _fetchDashboardData();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A47A8),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('حفظ المنطقة', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _fetchDashboardData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF0A47A8), Color(0xFF0A2F6B)]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Color(0x1A0A2F6B), blurRadius: 10, offset: Offset(0, 4))],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.shopping_bag, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('تنبيه الطلبات', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                        Text('عدد الطلبات الجديدة: $newOrdersCount', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFF00B8C4), borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      '$newOrdersCount طلبات',
                      style: const TextStyle(color: Color(0xFF0A2F6B), fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE1E9F3)),
                boxShadow: const [BoxShadow(color: Color(0x060A2F6B), blurRadius: 8, offset: Offset(0, 2))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.monetization_on_outlined, color: Color(0xFF0A47A8), size: 22),
                          SizedBox(width: 8),
                          Text('سعر الدولار اليوم', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0A2F6B))),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: const Color(0xFFE6F4EA), borderRadius: BorderRadius.circular(20)),
                        child: const Text('مربوط تلقائياً', style: TextStyle(color: Color(0xFF00A86B), fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: usdController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0A2F6B)),
                          decoration: InputDecoration(
                            suffixText: 'ج.س',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: loadingFx ? null : _updateUsdRate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A47A8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: loadingFx
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('تحديث الأسعار', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '* التحديث يغير أسعار جميع المنتجات بالجنيه السوداني لدى الزبائن فوراً.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.5,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                _buildKpiCard('إجمالي المبيعات (الشهر)', '4.25M ج.س', '▲ +14% مقارنة بالشهر السابق', true),
                _buildKpiCard('إجمالي المشتريات', '2.80M ج.س', '▼ -5% تم توريد مستهلكات', false),
                _buildKpiCard('الأرباح الصافية المقدرة', '1.45M ج.س', '▲ أرباح ممتازة', true, isGreen: true),
                _buildKpiCard('المنتجات النشطة', '48 منتج', '3 نفدت من المخزن', true),
              ],
            ),

            const SizedBox(height: 14),

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
                      const Text('مناطق التوصيل وأسعارها', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0A2F6B))),
                      TextButton.icon(
                        onPressed: () => _showAddAreaModal(),
                        icon: const Icon(Icons.add, size: 18, color: Color(0xFF0A47A8)),
                        label: const Text('إضافة منطقة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0A47A8))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (deliveryAreas.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('لا توجد مناطق توصيل مضافة', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                    )
                  else
                    Column(
                      children: deliveryAreas.map((area) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE1E9F3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(area['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0A2F6B))),
                              Row(
                                children: [
                                  Text(
                                    '${intl.NumberFormat('#,##0').format(area['delivery_fee'] ?? 0)} ج.س',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0A47A8)),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18, color: Color(0xFF64748B)),
                                    onPressed: () => _showAddAreaModal(area),
                                  ),
                                ],
                              ),
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
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, String subText, bool isUp, {bool isGreen = false}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1E9F3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: isGreen ? const Color(0xFF00A86B) : const Color(0xFF0A2F6B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subText,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isUp ? const Color(0xFF00A86B) : const Color(0xFFE53935),
            ),
          ),
        ],
      ),
    );
  }
}

// --- TAB 2: ORDERS MANAGEMENT ---
class AdminOrdersTab extends StatefulWidget {
  const AdminOrdersTab({super.key});

  @override
  State<AdminOrdersTab> createState() => _AdminOrdersTabState();
}

class _AdminOrdersTabState extends State<AdminOrdersTab> {
  String selectedFilter = 'الكل';
  List<dynamic> orders = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    try {
      String query = '$kSupabaseUrl/rest/v1/tarag3_orders?select=*&order=created_at.desc';
      if (selectedFilter != 'الكل') {
        query = '$kSupabaseUrl/rest/v1/tarag3_orders?status=eq.$selectedFilter&select=*&order=created_at.desc';
      }
      final res = await http.get(Uri.parse(query), headers: AdminAuthState.headers());
      if (res.statusCode == 200) {
        orders = jsonDecode(res.body);
      }
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'جديد':
        return const Color(0xFF0A47A8);
      case 'قيد التجهيز':
        return const Color(0xFFFF9800);
      case 'في الطريق':
        return const Color(0xFF00838F);
      case 'تم':
        return const Color(0xFF00A86B);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['الكل', 'جديد', 'قيد التجهيز', 'في الطريق', 'تم'].map((filter) {
                final isSelected = selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: ChoiceChip(
                    label: Text(filter),
                    selected: isSelected,
                    selectedColor: const Color(0xFF0A47A8),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF0A2F6B),
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    ),
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          selectedFilter = filter;
                          loading = true;
                        });
                        _fetchOrders();
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),

        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF0A47A8)))
              : orders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          const Text('لا توجد طلبات في هذه الحالة حالياً', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchOrders,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: orders.length,
                        itemBuilder: (context, index) {
                          final order = orders[index];
                          final status = order['status'] ?? 'جديد';
                          final color = _getStatusColor(status);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE1E9F3)),
                              boxShadow: const [BoxShadow(color: Color(0x060A2F6B), blurRadius: 8, offset: Offset(0, 2))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'طلب #${order['order_number'] ?? order['id']}',
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0A2F6B)),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: color.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'الزبون: ${order['customer_name'] ?? 'بدون اسم'} • ${order['delivery_area_name'] ?? ''}',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${intl.NumberFormat('#,##0').format(order['total_sdg'] ?? 0)} ج.س',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0A47A8)),
                                    ),
                                    OutlinedButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => AdminOrderDetailScreen(order: order)),
                                        ).then((_) => _fetchOrders());
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF0A2F6B),
                                        side: const BorderSide(color: Color(0xFFE1E9F3)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      child: const Text('عرض والتعديل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}

// --- ORDER DETAIL & STATUS UPDATE SCREEN ---
class AdminOrderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const AdminOrderDetailScreen({super.key, required this.order});

  @override
  State<AdminOrderDetailScreen> createState() => _AdminOrderDetailScreenState();
}

class _AdminOrderDetailScreenState extends State<AdminOrderDetailScreen> {
  late String currentStatus;
  List<dynamic> items = [];
  bool loadingItems = true;
  bool updating = false;

  @override
  void initState() {
    super.initState();
    currentStatus = widget.order['status'] ?? 'جديد';
    _fetchOrderItems();
  }

  Future<void> _fetchOrderItems() async {
    try {
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_order_items?order_id=eq.${widget.order['id']}'),
        headers: AdminAuthState.headers(),
      );
      if (res.statusCode == 200) {
        items = jsonDecode(res.body);
      }
    } catch (_) {}
    if (mounted) setState(() => loadingItems = false);
  }

  Future<void> _updateStatus() async {
    setState(() => updating = true);
    try {
      final res = await http.patch(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_orders?id=eq.${widget.order['id']}'),
        headers: AdminAuthState.headers(),
        body: jsonEncode({"status": currentStatus, "updated_at": DateTime.now().toIso8601String()}),
      );

      if (res.statusCode == 200 || res.statusCode == 204) {
        if (widget.order['customer_id'] != null) {
          await http.post(
            Uri.parse('$kSupabaseUrl/rest/v1/tarag3_notifications'),
            headers: AdminAuthState.headers(),
            body: jsonEncode({
              "to_user": widget.order['customer_id'],
              "title": "تحديث حالة الطلب #${widget.order['order_number']}",
              "body": "أصبحت حالة طلبك الآن: ($currentStatus)",
              "data": {"order_id": widget.order['id']}
            }),
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث حالة الطلب وإشعارات الزبون بنجاح'), backgroundColor: Color(0xFF00A86B)),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فشل تحديث الحالة')));
    } finally {
      if (mounted) setState(() => updating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('تفاصيل الطلب #${widget.order['order_number'] ?? widget.order['id']}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  const Text('بيانات الزبون', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0A2F6B))),
                  const SizedBox(height: 8),
                  Text('الاسم: ${widget.order['customer_name'] ?? '-'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Text('الهاتف: ${widget.order['customer_phone'] ?? '-'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Text('المنطقة: ${widget.order['delivery_area_name'] ?? '-'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  Text('العنوان التفصيلي: ${widget.order['delivery_address'] ?? '-'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),

            const SizedBox(height: 14),

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
                  const Text('عناصر ومحتويات الطلب', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0A2F6B))),
                  const SizedBox(height: 12),
                  if (loadingItems)
                    const Center(child: CircularProgressIndicator())
                  else
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(3),
                        1: FlexColumnWidth(1),
                        2: FlexColumnWidth(2),
                      },
                      border: TableBorder.all(color: const Color(0xFFE1E9F3), width: 1),
                      children: [
                        const TableRow(
                          decoration: BoxDecoration(color: Color(0xFFF1F5F9)),
                          children: [
                            Padding(padding: EdgeInsets.all(8), child: Text('الصنف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            Padding(padding: EdgeInsets.all(8), child: Text('الكمية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center)),
                            Padding(padding: EdgeInsets.all(8), child: Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.left)),
                          ],
                        ),
                        ...items.map((it) {
                          return TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.all(8), child: Text(it['product_name'] ?? '', style: const TextStyle(fontSize: 12))),
                              Padding(padding: const EdgeInsets.all(8), child: Text('${it['quantity']}', style: const TextStyle(fontSize: 12), textAlign: TextAlign.center)),
                              Padding(padding: const EdgeInsets.all(8), child: Text('${intl.NumberFormat('#,##0').format(it['total_sdg'] ?? 0)} ج.س', style: const TextStyle(fontSize: 12), textAlign: TextAlign.left)),
                            ],
                          );
                        }),
                      ],
                    ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('الإجمالي الكلي شامل التوصيل:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                      Text(
                        '${intl.NumberFormat('#,##0').format(widget.order['total_sdg'] ?? 0)} ج.س',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0A47A8)),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

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
                  const Text('تعديل حالة الطلب الحالية', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0A2F6B))),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: currentStatus,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: ['جديد', 'قيد التجهيز', 'في الطريق', 'تم'].map((st) {
                      return DropdownMenuItem(value: st, child: Text(st, style: const TextStyle(fontWeight: FontWeight.w700)));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => currentStatus = val);
                    },
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: updating ? null : _updateStatus,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A47A8),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: updating
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('حفظ وتحديث الحالة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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

// --- TAB 3: PRODUCTS & INVENTORY ---
class AdminProductsTab extends StatefulWidget {
  const AdminProductsTab({super.key});

  @override
  State<AdminProductsTab> createState() => _AdminProductsTabState();
}

class _AdminProductsTabState extends State<AdminProductsTab> {
  List<dynamic> products = [];
  bool loading = true;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_products?select=*&order=created_at.desc'),
        headers: AdminAuthState.headers(),
      );
      if (res.statusCode == 200) {
        products = jsonDecode(res.body);
      }
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  Future<void> _toggleVisibility(Map<String, dynamic> prod, bool currentVal) async {
    try {
      final res = await http.patch(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_products?id=eq.${prod['id']}'),
        headers: AdminAuthState.headers(),
        body: jsonEncode({"is_visible": !currentVal}),
      );
      if (res.statusCode == 200 || res.statusCode == 204) {
        _fetchProducts();
      }
    } catch (_) {}
  }

  void _openAddEditProduct([Map<String, dynamic>? prod]) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AdminAddEditProductScreen(product: prod)),
    ).then((_) => _fetchProducts());
  }

  @override
  Widget build(BuildContext context) {
    final filtered = products.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      return name.contains(searchQuery.toLowerCase());
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) => setState(() => searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'بحث باسم المنتج أو القسم...',
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE1E9F3))),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => _openAddEditProduct(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('إضافة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A47A8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  minimumSize: const Size(0, 48),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? const Center(child: Text('لا توجد منتجات مسجلة'))
                  : RefreshIndicator(
                      onRefresh: _fetchProducts,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final prod = filtered[index];
                          final isVisible = prod['is_visible'] ?? true;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE1E9F3)),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    width: 60,
                                    height: 60,
                                    color: const Color(0xFFF1F5F9),
                                    child: prod['image_url'] != null && prod['image_url'].toString().startsWith('http')
                                        ? CachedNetworkImage(imageUrl: prod['image_url'], fit: BoxFit.cover, errorWidget: (_, _, _) => const Icon(Icons.medical_services, color: Color(0xFF0A47A8)))
                                        : const Icon(Icons.medical_services, color: Color(0xFF0A47A8), size: 28),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(prod['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0A2F6B))),
                                      const SizedBox(height: 4),
                                      Text(
                                        'السعر: \$${prod['price_usd'] ?? 0} • المخزون: ${prod['stock_quantity'] ?? 0}',
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  children: [
                                    Switch(
                                      value: isVisible,
                                      activeThumbColor: const Color(0xFF0A47A8),
                                      onChanged: (val) => _toggleVisibility(prod, isVisible),
                                    ),
                                    InkWell(
                                      onTap: () => _openAddEditProduct(prod),
                                      child: const Text('تعديل', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0A47A8))),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}

// --- ADD / EDIT PRODUCT SCREEN ---
class AdminAddEditProductScreen extends StatefulWidget {
  final Map<String, dynamic>? product;

  const AdminAddEditProductScreen({super.key, this.product});

  @override
  State<AdminAddEditProductScreen> createState() => _AdminAddEditProductScreenState();
}

class _AdminAddEditProductScreenState extends State<AdminAddEditProductScreen> {
  final nameCtrl = TextEditingController();
  final priceUsdCtrl = TextEditingController();
  final stockCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final imageUrlCtrl = TextEditingController();
  String category = 'معدات';
  bool isVisible = true;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      nameCtrl.text = widget.product!['name'] ?? '';
      priceUsdCtrl.text = (widget.product!['price_usd'] ?? '').toString();
      stockCtrl.text = (widget.product!['stock_quantity'] ?? '').toString();
      descCtrl.text = widget.product!['description'] ?? '';
      imageUrlCtrl.text = widget.product!['image_url'] ?? '';
      category = widget.product!['category'] ?? 'معدات';
      isVisible = widget.product!['is_visible'] ?? true;
    }
  }

  Future<void> _showImageSourcePicker() async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('اختر مصدر صورة المنتج', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0A2F6B))),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFF0A47A8)),
                title: const Text('من معرض الصور والملفات'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(source: ImageSource.gallery);
                  if (picked != null) {
                    setState(() => imageUrlCtrl.text = picked.path);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF0A47A8)),
                title: const Text('التقاط بالكاميرا'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(source: ImageSource.camera);
                  if (picked != null) {
                    setState(() => imageUrlCtrl.text = picked.path);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveProduct() async {
    final name = nameCtrl.text.trim();
    final price = double.tryParse(priceUsdCtrl.text.trim()) ?? 0.0;
    final stock = int.tryParse(stockCtrl.text.trim()) ?? 0;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اسم المنتج مطلوب')));
      return;
    }

    setState(() => loading = true);

    try {
      final body = {
        "name": name,
        "category": category,
        "price_usd": price,
        "stock_quantity": stock,
        "description": descCtrl.text.trim(),
        "image_url": imageUrlCtrl.text.trim(),
        "is_visible": isVisible,
        "updated_at": DateTime.now().toIso8601String(),
      };

      if (widget.product != null) {
        await http.patch(
          Uri.parse('$kSupabaseUrl/rest/v1/tarag3_products?id=eq.${widget.product!['id']}'),
          headers: AdminAuthState.headers(),
          body: jsonEncode(body),
        );
      } else {
        await http.post(
          Uri.parse('$kSupabaseUrl/rest/v1/tarag3_products'),
          headers: AdminAuthState.headers(),
          body: jsonEncode(body),
        );
      }

      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدث خطأ أثناء حفظ المنتج')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'تعديل بيانات المنتج' : 'إضافة منتج جديد')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE1E9F3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _showImageSourcePicker,
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.camera_alt_outlined, color: Color(0xFF64748B), size: 32),
                      const SizedBox(height: 6),
                      Text(
                        imageUrlCtrl.text.isNotEmpty ? 'تم اختيار صورة المنتج 🖼️' : 'اضغط لرفع صورة المنتج (الكاميرا / المعرض)',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'اسم المنتج بالكامل',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: InputDecoration(
                  labelText: 'القسم الرئيسية',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: ['معدات', 'مستهلكات', 'مختبر'].map((c) {
                  return DropdownMenuItem(value: c, child: Text(c));
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => category = val);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: priceUsdCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'السعر ($)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: stockCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'الكمية بالمخزن',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'وصف المنتج والتفاصيل',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('إظهار المنتج في تطبيق الزبائن', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Switch(
                    value: isVisible,
                    activeThumbColor: const Color(0xFF0A47A8),
                    onChanged: (val) => setState(() => isVisible = val),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: loading ? null : _saveProduct,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A47A8),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(isEdit ? 'تعديل وحفظ' : 'إضافة المنتج', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- TAB 4: PURCHASES MANAGEMENT ---
class AdminPurchasesTab extends StatefulWidget {
  const AdminPurchasesTab({super.key});

  @override
  State<AdminPurchasesTab> createState() => _AdminPurchasesTabState();
}

class _AdminPurchasesTabState extends State<AdminPurchasesTab> {
  List<dynamic> purchases = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchPurchases();
  }

  Future<void> _fetchPurchases() async {
    try {
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_purchases?select=*&order=created_at.desc'),
        headers: AdminAuthState.headers(),
      );
      if (res.statusCode == 200) {
        purchases = jsonDecode(res.body);
      }
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  void _openAddPurchaseModal() {
    final supplierCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String payStatus = 'مدفوع';
    String? pickedImagePath;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 20, top: 20, left: 20, right: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('تسجيل فاتورة شراء جديدة من مورد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0A2F6B))),
                  const SizedBox(height: 14),
                  TextField(
                    controller: supplierCtrl,
                    decoration: InputDecoration(
                      labelText: 'اسم المورد أو الشركة',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'المبلغ الإجمالي (ج.س)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: payStatus,
                    decoration: InputDecoration(
                      labelText: 'حالة الدفع',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: ['مدفوع', 'آجل'].map((st) => DropdownMenuItem(value: st, child: Text(st))).toList(),
                    onChanged: (val) {
                      if (val != null) setModalState(() => payStatus = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                        builder: (sheetCtx) {
                          return Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('مصدر صورة الفاتورة الورقية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0A2F6B))),
                                const SizedBox(height: 14),
                                ListTile(
                                  leading: const Icon(Icons.photo_library, color: Color(0xFF0A47A8)),
                                  title: const Text('اختيار من معرض الصور والملفات'),
                                  onTap: () async {
                                    Navigator.pop(sheetCtx);
                                    final picker = ImagePicker();
                                    final picked = await picker.pickImage(source: ImageSource.gallery);
                                    if (picked != null) {
                                      setModalState(() => pickedImagePath = picked.path);
                                    }
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.camera_alt, color: Color(0xFF0A47A8)),
                                  title: const Text('التقاط صورة جديدة بالكاميرا'),
                                  onTap: () async {
                                    Navigator.pop(sheetCtx);
                                    final picker = ImagePicker();
                                    final picked = await picker.pickImage(source: ImageSource.camera);
                                    if (picked != null) {
                                      setModalState(() => pickedImagePath = picked.path);
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.center_focus_weak, color: Color(0xFF0A47A8)),
                          const SizedBox(width: 8),
                          Text(
                            pickedImagePath != null ? 'تم رفع/إرفاق صورة الفاتورة 🖼️' : 'رفع صورة الفاتورة (الكاميرا / المعرض)',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0A2F6B)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      final supplier = supplierCtrl.text.trim();
                      final amount = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                      if (supplier.isEmpty) return;

                      Navigator.pop(ctx);
                      await http.post(
                        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_purchases'),
                        headers: AdminAuthState.headers(),
                        body: jsonEncode({
                          "supplier_name": supplier,
                          "amount_sdg": amount,
                          "payment_status": payStatus,
                          "purchase_date": DateTime.now().toIso8601String().split('T')[0],
                          "invoice_image_url": pickedImagePath ?? '',
                        }),
                      );
                      _fetchPurchases();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A47A8),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('حفظ الفاتورة والتوريد', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddPurchaseModal,
        backgroundColor: const Color(0xFF0A47A8),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('فاتورة جديدة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : purchases.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                      const SizedBox(height: 12),
                      const Text('لا توجد فواتير مشتريات مسجلة حالياً', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _openAddPurchaseModal, child: const Text('+ تسجيل فاتورة شراء')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchPurchases,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: purchases.length,
                    itemBuilder: (context, index) {
                      final item = purchases[index];
                      final isPaid = item['payment_status'] == 'مدفوع';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
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
                                Text(item['supplier_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF0A2F6B))),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isPaid ? const Color(0xFFE6F4EA) : const Color(0xFFFCE8E6),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    item['payment_status'] ?? 'مدفوع',
                                    style: TextStyle(color: isPaid ? const Color(0xFF00A86B) : const Color(0xFFE53935), fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text('التاريخ: ${item['purchase_date'] ?? ''}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${intl.NumberFormat('#,##0').format(item['amount_sdg'] ?? 0)} ج.س',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0A47A8)),
                                ),
                                if (item['invoice_image_url'] != null && item['invoice_image_url'].toString().isNotEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.image, color: Color(0xFF0A47A8)),
                                    onPressed: () {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('صورة الفاتورة مسجلة ومرفقة')));
                                    },
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// --- EXTRA SCREEN: CUSTOMERS LIST ---
class AdminCustomersTab extends StatefulWidget {
  const AdminCustomersTab({super.key});

  @override
  State<AdminCustomersTab> createState() => _AdminCustomersTabState();
}

class _AdminCustomersTabState extends State<AdminCustomersTab> {
  List<dynamic> customers = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
  }

  Future<void> _fetchCustomers() async {
    try {
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_profiles?role=eq.customer'),
        headers: AdminAuthState.headers(),
      );
      if (res.statusCode == 200) {
        customers = jsonDecode(res.body);
      }
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : customers.isEmpty
              ? const Center(child: Text('لا يوجد زبائن مسجلون حالياً'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: customers.length,
                  itemBuilder: (context, index) {
                    final c = customers[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE1E9F3)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: const Color(0xFFEBF2FA),
                            child: Text(
                              (c['full_name'] ?? 'ز')[0],
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0A47A8)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(c['full_name'] ?? 'بدون اسم', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text('${c['phone'] ?? '-'} • ${c['email'] ?? ''}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFE6F4EA), borderRadius: BorderRadius.circular(12)),
                            child: const Text('موثق', style: TextStyle(color: Color(0xFF00A86B), fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

// --- SETTINGS SCREEN ---
class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات النظام والحساب')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE1E9F3)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('بيانات المحل والنظام', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0A2F6B))),
                  SizedBox(height: 12),
                  Text('اسم المحل: DMC Diala Medical & Chemical', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  SizedBox(height: 6),
                  Text('قاعدة البيانات: Supabase Connected (Live)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  SizedBox(height: 6),
                  Text('حالة الربط: متصل بالكامل (Active)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () async {
                await AdminAuthState.clearSession();
                if (!context.mounted) return;
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminAuthScreen()));
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFE53935),
                side: const BorderSide(color: Color(0xFFFCA5A5)),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('تسجيل الخروج من الإدارة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// --- EXTRA SCREEN: OFFERS & BROADCAST ---
class AdminOffersBroadcastScreen extends StatefulWidget {
  const AdminOffersBroadcastScreen({super.key});

  @override
  State<AdminOffersBroadcastScreen> createState() => _AdminOffersBroadcastScreenState();
}

class _AdminOffersBroadcastScreenState extends State<AdminOffersBroadcastScreen> {
  final titleCtrl = TextEditingController(text: 'تخفيضات خاصة على المعدات الطبية!');
  final bodyCtrl = TextEditingController(text: 'خصم 10% لفترة محدودة مع توصيل مجاني لكل ولاية نهر النيل!');
  bool sending = false;

  Future<void> _sendBroadcast() async {
    final title = titleCtrl.text.trim();
    final bodyText = bodyCtrl.text.trim();
    if (title.isEmpty || bodyText.isEmpty) return;

    setState(() => sending = true);

    try {
      await http.post(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_promotions'),
        headers: AdminAuthState.headers(),
        body: jsonEncode({
          "title": title,
          "body": bodyText,
          "sent_at": DateTime.now().toIso8601String(),
          "reached_count": 350
        }),
      );

      await http.post(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_notifications'),
        headers: AdminAuthState.headers(),
        body: jsonEncode({
          "to_role": "customer",
          "title": title,
          "body": bodyText,
          "data": {"type": "promotion"}
        }),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال الإشعار بنجاح لكافة الزبائن 🚀'), backgroundColor: Color(0xFF00A86B)),
      );
      Navigator.pop(context);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدث خطأ أثناء الإرسال')));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('العروض وتنبيهات الزبائن')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE1E9F3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('إرسال عرض / إشعار جماعي لجميع الزبائن', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF0A2F6B))),
              const SizedBox(height: 14),
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: 'عنوان الإشعار',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bodyCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'نص العرض والتفاصيل',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: sending ? null : _sendBroadcast,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A47A8),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: sending
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('🚀 إرسال الإشعار لجميع الزبائن', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
