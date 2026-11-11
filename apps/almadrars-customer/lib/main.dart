import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: firebaseOptions);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }
  runApp(const AlmadrarsCustomerApp());
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: firebaseOptions);
  debugPrint('Handling background message: ${message.messageId}');
}

// ---------------------------------------------------------------------------
// SUPABASE API CLIENT & PERSISTENCE
// ---------------------------------------------------------------------------
const String kSupabaseUrl = "https://jvjtgzewumfecjdpekna.supabase.co";
const String kSupabaseAnonKey =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp2anRnemV3dW1mZWNqZHBla25hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE2NDYzMzcsImV4cCI6MjEwNzIyMjMzN30.1gck73ek8ErBtcF7xAtFM1TdvNim_1NzFVNej_mptBE";

class SupabaseService {
  static String? accessToken;
  static String? refreshToken;
  static String? userId;
  static String? userEmail;

  static Map<String, String> get headers {
    final map = <String, String>{
      'apikey': kSupabaseAnonKey,
      'Content-Type': 'application/json',
      'Prefer': 'return=representation',
    };
    if (accessToken != null && accessToken!.isNotEmpty) {
      map['Authorization'] = 'Bearer $accessToken';
    }
    return map;
  }

  static Future<void> saveSession(String at, String rt, String uid, String email) async {
    accessToken = at;
    refreshToken = rt;
    userId = uid;
    userEmail = email;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', at);
    await prefs.setString('refresh_token', rt);
    await prefs.setString('user_id', uid);
    await prefs.setString('user_email', email);
  }

  static Future<bool> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    accessToken = prefs.getString('access_token');
    refreshToken = prefs.getString('refresh_token');
    userId = prefs.getString('user_id');
    userEmail = prefs.getString('user_email');
    return accessToken != null && accessToken!.isNotEmpty;
  }

  static Future<void> signOut() async {
    accessToken = null;
    refreshToken = null;
    userId = null;
    userEmail = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static String parseErrorMessage(dynamic body, String defaultMsg) {
    if (body is Map) {
      final msg = (body['msg'] ?? body['message'] ?? body['error_description'] ?? body['error'] ?? '').toString();
      if (msg.contains('rate limit') || msg.contains('over_email_send_rate_limit')) {
        return 'اتبعتت رسائل كتير، استنى دقايق';
      }
      if (msg.contains('smtp') || msg.contains('sending') || msg.contains('email')) {
        return 'ما قدرنا نرسل البريد';
      }
      if (msg.isNotEmpty) return msg;
    }
    return defaultMsg;
  }

  static Future<bool> tryRefreshToken() async {
    if (refreshToken == null || refreshToken!.isEmpty) return false;
    try {
      final url = Uri.parse('$kSupabaseUrl/auth/v1/token?grant_type=refresh_token');
      final response = await http.post(
        url,
        headers: {'apikey': kSupabaseAnonKey, 'Content-Type': 'application/json'},
        body: jsonEncode({"refresh_token": refreshToken}),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        await saveSession(
          data['access_token'] ?? '',
          data['refresh_token'] ?? refreshToken!,
          data['user']?['id'] ?? userId ?? '',
          data['user']?['email'] ?? userEmail ?? '',
        );
        return true;
      }
    } catch (_) {}
    return false;
  }

  static Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    final url = Uri.parse('$kSupabaseUrl/auth/v1/signup');
    final response = await http.post(
      url,
      headers: {'apikey': kSupabaseAnonKey, 'Content-Type': 'application/json'},
      body: jsonEncode({
        "email": email,
        "password": password,
        "data": {"full_name": fullName, "phone": phone}
      }),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    } else {
      final err = jsonDecode(response.body);
      throw Exception(parseErrorMessage(err, 'فشل إنشاء الحساب'));
    }
  }

  static Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String token,
    required String type,
  }) async {
    final url = Uri.parse('$kSupabaseUrl/auth/v1/verify');
    final response = await http.post(
      url,
      headers: {'apikey': kSupabaseAnonKey, 'Content-Type': 'application/json'},
      body: jsonEncode({"type": type, "email": email, "token": token}),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body);
      if (data['access_token'] != null) {
        await saveSession(
          data['access_token'],
          data['refresh_token'] ?? '',
          data['user']?['id'] ?? '',
          data['user']?['email'] ?? email,
        );
      }
      return data;
    } else {
      throw Exception('رمز التحقق غير صحيح أو منتهي الصلاحية');
    }
  }

  static Future<void> signIn({required String email, required String password}) async {
    final url = Uri.parse('$kSupabaseUrl/auth/v1/token?grant_type=password');
    final response = await http.post(
      url,
      headers: {'apikey': kSupabaseAnonKey, 'Content-Type': 'application/json'},
      body: jsonEncode({"email": email, "password": password}),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body);
      await saveSession(
        data['access_token'],
        data['refresh_token'] ?? '',
        data['user']?['id'] ?? '',
        data['user']?['email'] ?? email,
      );
    } else {
      final err = jsonDecode(response.body);
      throw Exception(parseErrorMessage(err, 'فشل تسجيل الدخول'));
    }
  }

  static Future<void> recoverPassword({required String email}) async {
    final url = Uri.parse('$kSupabaseUrl/auth/v1/recover');
    final response = await http.post(
      url,
      headers: {'apikey': kSupabaseAnonKey, 'Content-Type': 'application/json'},
      body: jsonEncode({"email": email}),
    );
    if (response.statusCode >= 400) {
      final err = jsonDecode(response.body);
      throw Exception(parseErrorMessage(err, 'ما قدرنا نرسل البريد'));
    }
  }

  static Future<void> updatePassword({required String newPassword}) async {
    final url = Uri.parse('$kSupabaseUrl/auth/v1/user');
    final response = await http.put(
      url,
      headers: headers,
      body: jsonEncode({"password": newPassword}),
    );
    if (response.statusCode >= 400) {
      final err = jsonDecode(response.body);
      throw Exception(parseErrorMessage(err, 'فشل تحديث كلمة المرور'));
    }
  }

  static Future<void> resendOtp({required String email, required String type}) async {
    final url = Uri.parse('$kSupabaseUrl/auth/v1/resend');
    final response = await http.post(
      url,
      headers: {'apikey': kSupabaseAnonKey, 'Content-Type': 'application/json'},
      body: jsonEncode({"type": type, "email": email}),
    );
    if (response.statusCode >= 400) {
      final err = jsonDecode(response.body);
      throw Exception(parseErrorMessage(err, 'ما قدرنا نرسل البريد'));
    }
  }

  static Future<List<dynamic>> getTable(String table, {String query = ''}) async {
    final q = query.isNotEmpty ? '?$query' : '';
    final url = Uri.parse('$kSupabaseUrl/rest/v1/$table$q');
    var response = await http.get(url, headers: headers);
    if (response.statusCode == 401) {
      if (await tryRefreshToken()) {
        response = await http.get(url, headers: headers);
      } else {
        throw Exception('401');
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body);
    }
    return [];
  }

  static Future<dynamic> insertRow(String table, Map<String, dynamic> data) async {
    final url = Uri.parse('$kSupabaseUrl/rest/v1/$table');
    var response = await http.post(url, headers: headers, body: jsonEncode(data));
    if (response.statusCode == 401) {
      if (await tryRefreshToken()) {
        response = await http.post(url, headers: headers, body: jsonEncode(data));
      } else {
        throw Exception('401');
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is List && decoded.isNotEmpty) return decoded.first;
        return decoded;
      }
      return null;
    }
    throw Exception('فشل حفظ البيانات');
  }

  static Future<void> updateRow(String table, String query, Map<String, dynamic> data) async {
    final url = Uri.parse('$kSupabaseUrl/rest/v1/$table?$query');
    var response = await http.patch(url, headers: headers, body: jsonEncode(data));
    if (response.statusCode == 401) {
      if (await tryRefreshToken()) {
        response = await http.patch(url, headers: headers, body: jsonEncode(data));
      } else {
        throw Exception('401');
      }
    }
    if (response.statusCode >= 400) {
      throw Exception('فشل تحديث البيانات');
    }
  }

  static Future<dynamic> rpc(String fn, Map<String, dynamic> body) async {
    final url = Uri.parse('$kSupabaseUrl/rest/v1/rpc/$fn');
    var response = await http.post(url, headers: headers, body: jsonEncode(body));
    if (response.statusCode == 401) {
      if (await tryRefreshToken()) {
        response = await http.post(url, headers: headers, body: jsonEncode(body));
      } else {
        throw Exception('401');
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isNotEmpty) return jsonDecode(response.body);
      return null;
    }
    throw Exception('فشل تنفيذ العملية');
  }
}

// ---------------------------------------------------------------------------
// MAIN APP ENTRY & THEME
// ---------------------------------------------------------------------------
class AlmadrarsCustomerApp extends StatelessWidget {
  const AlmadrarsCustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'المدرار للمقاولات الهندسية',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'LY'),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3A86FF),
          brightness: Brightness.light,
          primary: const Color(0xFF3A86FF),
          secondary: const Color(0xFFFF006E),
        ),
        fontFamily: 'Noto Sans Arabic',
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3A86FF),
          brightness: Brightness.dark,
          primary: const Color(0xFF3A86FF),
          secondary: const Color(0xFFFF006E),
          surface: const Color(0xFF0F172A),
        ),
        scaffoldBackgroundColor: const Color(0xFF070B14),
        fontFamily: 'Noto Sans Arabic',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A0F1D),
          elevation: 0,
          centerTitle: true,
        ),
      ),
      themeMode: ThemeMode.dark,
      home: const AuthWrapper(),
    );
  }
}

// ---------------------------------------------------------------------------
// AUTHENTICATION WRAPPER
// ---------------------------------------------------------------------------
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final hasSession = await SupabaseService.loadSession();
    if (mounted) {
      setState(() {
        _isLoggedIn = hasSession;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF3A86FF)),
        ),
      );
    }
    if (!_isLoggedIn) {
      return const LoginScreen();
    }
    return const MainNavigatorScreen();
  }
}

// ---------------------------------------------------------------------------
// SIGN-IN SCREEN
// ---------------------------------------------------------------------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  void _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await SupabaseService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      await _registerDeviceAndProceed();
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      if (msg.contains('not confirmed') || msg.contains('Email not confirmed')) {
        try {
          await SupabaseService.resendOtp(email: _emailController.text.trim(), type: 'signup');
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OtpVerifyScreen(email: _emailController.text.trim(), type: 'signup'),
              ),
            );
          }
        } catch (_) {}
      } else {
        setState(() => _errorMessage = msg);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _registerDeviceAndProceed() async {
    try {
      await FirebaseMessaging.instance.requestPermission();
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await SupabaseService.rpc('almadrars_register_device', {
          'device_token': token,
          'app_name': 'customer',
        });
      }
    } catch (_) {}
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigatorScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.architecture, size: 64, color: Color(0xFF3A86FF)),
              const SizedBox(height: 16),
              const Text('المدرار للمقاولات الهندسية', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text('تسجيل الدخول - تطبيق الزبائن', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 32),
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                  child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13), textAlign: TextAlign.center),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'البريد الإلكتروني', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'كلمة المرور',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                  child: const Text('نسيت كلمة المرور؟', style: TextStyle(color: Color(0xFF3A86FF))),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3A86FF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('تسجيل الدخول', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('ليس لديك حساب؟', style: TextStyle(color: Colors.grey)),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUpScreen())),
                    child: const Text('حساب جديد', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SIGN-UP SCREEN
// ---------------------------------------------------------------------------
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _isLoading = false;

  String? _nameError;
  String? _phoneError;
  String? _emailError;
  String? _passwordError;
  String? _confirmError;

  void _signup() async {
    setState(() {
      _nameError = _nameController.text.trim().isEmpty ? 'الاسم الكامل مطلوب' : null;
      _phoneError = _phoneController.text.trim().isEmpty ? 'رقم الهاتف مطلوب' : null;
      _emailError = _emailController.text.trim().isEmpty ? 'البريد الإلكتروني مطلوب' : null;
      _passwordError = _passwordController.text.length < 6 ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل' : null;
      _confirmError = _passwordController.text != _confirmPasswordController.text ? 'كلمتا المرور غير متطابقتين' : null;
    });

    if (_nameError != null || _phoneError != null || _emailError != null || _passwordError != null || _confirmError != null) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      await SupabaseService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => OtpVerifyScreen(email: _emailController.text.trim(), type: 'signup')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حساب جديد')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'الاسم الكامل',
                border: const OutlineInputBorder(),
                errorText: _nameError,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'رقم الهاتف',
                border: const OutlineInputBorder(),
                errorText: _phoneError,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'البريد الإلكتروني',
                border: const OutlineInputBorder(),
                errorText: _emailError,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: _obscure1,
              decoration: InputDecoration(
                labelText: 'كلمة المرور (6+ أحرف)',
                border: const OutlineInputBorder(),
                errorText: _passwordError,
                suffixIcon: IconButton(
                  icon: Icon(_obscure1 ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscure1 = !_obscure1),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              obscureText: _obscure2,
              decoration: InputDecoration(
                labelText: 'تأكيد كلمة المرور',
                border: const OutlineInputBorder(),
                errorText: _confirmError,
                suffixIcon: IconButton(
                  icon: Icon(_obscure2 ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscure2 = !_obscure2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _signup,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3A86FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('إنشاء الحساب والمتابعة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// OTP VERIFICATION SCREEN
// ---------------------------------------------------------------------------
class OtpVerifyScreen extends StatefulWidget {
  final String email;
  final String type;
  const OtpVerifyScreen({super.key, required this.email, required this.type});

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  int _secondsRemaining = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _secondsRemaining = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _verify() async {
    setState(() => _isLoading = true);
    try {
      await SupabaseService.verifyOtp(
        email: widget.email,
        token: _codeController.text.trim(),
        type: widget.type,
      );
      if (widget.type == 'recovery') {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const NewPasswordScreen()),
          );
        }
      } else {
        try {
          await FirebaseMessaging.instance.requestPermission();
          final token = await FirebaseMessaging.instance.getToken();
          if (token != null) {
            await SupabaseService.rpc('almadrars_register_device', {
              'device_token': token,
              'app_name': 'customer',
            });
          }
        } catch (_) {}
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const MainNavigatorScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resend() async {
    if (_secondsRemaining > 0) return;
    try {
      await SupabaseService.resendOtp(email: widget.email, type: widget.type);
      _startTimer();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إعادة إرسال رمز التحقق بنجاح')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('التحقق من البريد الإلكتروني')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('بعتنا رمز على بريدك', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('أدخل الرمز المكون من 6 أرقام المرسل إلى ${widget.email}', style: const TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(border: OutlineInputBorder(), counterText: ''),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _verify,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3A86FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('تحقق وتفعيل', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            Center(
              child: _secondsRemaining > 0
                  ? Text('إعادة الإرسال بعد $_secondsRemaining ثانية', style: const TextStyle(color: Colors.grey))
                  : TextButton(
                      onPressed: _resend,
                      child: const Text('إعادة إرسال الرمز', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FORGOT PASSWORD & NEW PASSWORD SCREENS
// ---------------------------------------------------------------------------
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  void _recover() async {
    setState(() => _isLoading = true);
    try {
      await SupabaseService.recoverPassword(email: _emailController.text.trim());
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OtpVerifyScreen(email: _emailController.text.trim(), type: 'recovery')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('استعادة كلمة المرور')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('أدخل بريدك الإلكتروني المسجل لاستعادة كلمة المرور', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'البريد الإلكتروني', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _recover,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3A86FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('إرسال رمز الاستعادة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class NewPasswordScreen extends StatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  State<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<NewPasswordScreen> {
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  void _update() async {
    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('كلمة المرور يجب أن تكون 6 أحرف على الأقل')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      await SupabaseService.updatePassword(newPassword: _passwordController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث كلمة المرور بنجاح')));
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigatorScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('كلمة مرور جديدة')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('أدخل كلمة المرور الجديدة', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _update,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3A86FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('حفظ كلمة المرور', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MAIN APP NAVIGATION & TABS
// ---------------------------------------------------------------------------
class MainNavigatorScreen extends StatefulWidget {
  const MainNavigatorScreen({super.key});

  @override
  State<MainNavigatorScreen> createState() => _MainNavigatorScreenState();
}

class _MainNavigatorScreenState extends State<MainNavigatorScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  int _unreadCount = 0;
  Timer? _syncTimer;
  GlobalKey<HomeScreenState> homeKey = GlobalKey();
  GlobalKey<MyOrdersScreenState> ordersKey = GlobalKey();
  GlobalKey<NotificationsScreenState> notificationsKey = GlobalKey();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _screens = [
      HomeScreen(key: homeKey),
      const ServiceRequestScreen(),
      MyOrdersScreen(key: ordersKey),
      NotificationsScreen(key: notificationsKey),
      const ProfileScreen(),
    ];
    _startPeriodicSync();
    _setupFirebaseListeners();
    _fetchUnreadBadge();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _startPeriodicSync() {
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      if (SupabaseService.accessToken != null) {
        _refreshCurrentScreen();
      }
    });
  }

  Future<void> _fetchUnreadBadge() async {
    final uid = SupabaseService.userId;
    if (uid == null) return;
    try {
      final notifs = await SupabaseService.getTable(
        'almadrars_notifications',
        query: 'or=(to_user.eq.$uid,to_role.eq.customer)&read_at=is.null',
      );
      if (mounted) {
        setState(() => _unreadCount = notifs.length);
      }
    } catch (_) {}
  }

  void _refreshCurrentScreen() {
    _fetchUnreadBadge();
    homeKey.currentState?.refreshData();
    ordersKey.currentState?.refreshData();
    notificationsKey.currentState?.refreshNotifications();
  }

  void _setupFirebaseListeners() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final title = message.notification?.title ?? message.data['title'] ?? 'تنبيه جديد';
      final body = message.notification?.body ?? message.data['body'] ?? '';
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$title: $body'),
            backgroundColor: const Color(0xFF3A86FF),
          ),
        );
      }

      _refreshCurrentScreen();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshCurrentScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) {
          setState(() => _currentIndex = idx);
          if (idx == 0) homeKey.currentState?.refreshData();
          if (idx == 2) ordersKey.currentState?.refreshData();
          if (idx == 3) {
            notificationsKey.currentState?.refreshNotifications();
            _fetchUnreadBadge();
          }
        },
        destinations: [
          const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
          const NavigationDestination(icon: Icon(Icons.add_chart_outlined), selectedIcon: Icon(Icons.add_chart), label: 'طلب خدمة'),
          const NavigationDestination(icon: Icon(Icons.assignment_outlined), selectedIcon: Icon(Icons.assignment), label: 'طلباتي'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: _unreadCount > 0,
              label: Text('$_unreadCount'),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: _unreadCount > 0,
              label: Text('$_unreadCount'),
              child: const Icon(Icons.notifications),
            ),
            label: 'الإشعارات',
          ),
          const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'حسابي'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SCREEN 1: HOME SCREEN
// ---------------------------------------------------------------------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  List<dynamic> _servicesList = [];
  List<dynamic> _myOrdersList = [];
  bool _isLoading = true;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    refreshData();
  }

  Future<void> refreshData() async {
    try {
      final services = await SupabaseService.getTable('almadrars_services', query: 'is_available=eq.true');
      final uid = SupabaseService.userId;
      final orders = uid != null ? await SupabaseService.getTable('almadrars_requests', query: 'customer_id=eq.$uid&order=created_at.desc') : [];
      
      if (uid != null) {
        final notifs = await SupabaseService.getTable('almadrars_notifications', query: 'or=(to_user.eq.$uid,to_role.eq.customer)&read_at=is.null');
        if (mounted) setState(() => _unreadCount = notifs.length);
      }

      if (mounted) {
        setState(() {
          _servicesList = services;
          _myOrdersList = orders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (e.toString().contains('401')) {
        await SupabaseService.signOut();
        if (mounted) {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeOrder = _myOrdersList.isNotEmpty ? _myOrdersList.first : null;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.architecture, color: Color(0xFF3A86FF)),
                SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('المدرار للمقاولات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('الهندسية والتشطيبات • almadrars', style: TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ],
            ),
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () async {
                    await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                    refreshData();
                  },
                ),
                if (_unreadCount > 0)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Color(0xFFFF006E), shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text('$_unreadCount', style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF1E3A8A), Color(0xFF0F172A)]),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF3A86FF).withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A86FF).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('المدرار almadrars', style: TextStyle(fontSize: 10, color: Color(0xFF3A86FF), fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  const Text('نفّذ مشروعك الهندسي بأعلى معايير الدقة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('متخصصون في الخرسانات، الصب المسلح، والتشطيبات الفاخرة للداخل والخارج.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ServiceRequestScreen()));
                    },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('طلب معاينة / مشروع جديد'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3A86FF),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('أقسام خدمات المقاولات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('${_servicesList.length} خدمات متاحة', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 0.85,
                    ),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _servicesList.length,
                    itemBuilder: (context, index) {
                      final s = _servicesList[index];
                      return ServiceCategoryCard(
                        title: s['title'] ?? '',
                        subtitle: s['description'] ?? '',
                        icon: Icons.architecture,
                        color: const Color(0xFF3A86FF),
                        serviceId: s['id'],
                      );
                    },
                  ),
            const SizedBox(height: 20),
            if (activeOrder != null) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('آخر مشروع نشط', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const MyOrdersScreen()));
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
                                  Text('طلب رقم #${activeOrder['request_number'] ?? 'MD'}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  Text(activeOrder['service_type'] ?? 'مشروع هندسي', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3A86FF).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: const Color(0xFF3A86FF).withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  children: [
                                    const CircleAvatar(radius: 3, backgroundColor: Color(0xFF60A5FA)),
                                    const SizedBox(width: 6),
                                    Text(activeOrder['status'] ?? 'قيد المراجعة', style: const TextStyle(fontSize: 11, color: Color(0xFF60A5FA), fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('📍 ${activeOrder['location'] ?? 'غير محدد'}  •  💰 ${activeOrder['estimated_cost'] ?? 0} د.ل', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: ((activeOrder['completion_percentage'] ?? 0) as num).toDouble() / 100,
                              backgroundColor: Colors.white12,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}

class ServiceCategoryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String serviceId;

  const ServiceCategoryCard({super.key, required this.title, required this.subtitle, required this.icon, required this.color, required this.serviceId});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ServiceRequestScreen(preselectedService: title, serviceId: serviceId)));
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: color, size: 24),
                ),
                const SizedBox(height: 10),
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
            Text('طلب تسعير ←', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SCREEN 2: SERVICE REQUEST & UPLOAD SCREEN
// ---------------------------------------------------------------------------
class ServiceRequestScreen extends StatefulWidget {
  final String? preselectedService;
  final String? serviceId;
  const ServiceRequestScreen({super.key, this.preselectedService, this.serviceId});

  @override
  State<ServiceRequestScreen> createState() => _ServiceRequestScreenState();
}

class _ServiceRequestScreenState extends State<ServiceRequestScreen> {
  late String _selectedService;
  String? _selectedServiceId;
  final _locationController = TextEditingController();
  final _areaController = TextEditingController();
  final _detailsController = TextEditingController();
  final List<String> _attachedFiles = [];
  bool _isLoading = false;

  final List<String> _services = [
    'تشطيب داخلي وخارجي',
    'صب من الأول وصب طوابق',
    'شغل شقة كاملة جاهزة بالتشطيب',
    'صب عمدان'
  ];

  @override
  void initState() {
    super.initState();
    _selectedService = widget.preselectedService ?? _services[0];
    _selectedServiceId = widget.serviceId;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: source);
      if (image != null) {
        setState(() => _attachedFiles.add(image.name));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرفاق الملف بنجاح')));
        }
      }
    } catch (e) {
      debugPrint('Image picker error: $e');
    }
  }

  Future<void> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('خدمات الموقع غير مفعلة في الجهاز')));
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفض صلاحية تحديد الموقع')));
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('صلاحية الموقع مطلوبة'),
            content: const Text('يرجى تفعيل صلاحية الموقع من إعدادات التطبيق لتحديد موقع المشروع بدقة.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
              TextButton(
                onPressed: () {
                  Geolocator.openAppSettings();
                  Navigator.pop(context);
                },
                child: const Text('فتح الإعدادات'),
              ),
            ],
          ),
        );
      }
      return;
    }
    try {
      Position pos = await Geolocator.getCurrentPosition();
      setState(() {
        _locationController.text = 'خط الطول: ${pos.longitude.toStringAsFixed(4)}, خط العرض: ${pos.latitude.toStringAsFixed(4)}';
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر جلب الموقع الميداني حالياً')));
    }
  }

  void _submitRequest() async {
    if (_locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى كتابة أو تحديد موقع المشروع')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final uid = SupabaseService.userId;
      if (uid == null) throw Exception('يجب تسجيل الدخول أولاً');

      final reqNumber = 'MD-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
      final payload = {
        'customer_id': uid,
        'request_number': reqNumber,
        'service_id': _selectedServiceId,
        'service_type': _selectedService,
        'location': _locationController.text.trim(),
        'area_sqm': double.tryParse(_areaController.text.trim()) ?? 0,
        'details': _detailsController.text.trim(),
        'attachments': _attachedFiles,
        'status': 'قيد المراجعة',
        'completion_percentage': 0,
      };

      final createdReq = await SupabaseService.insertRow('almadrars_requests', payload);
      final reqId = createdReq != null ? createdReq['id'] : null;

      // Event Notification to Admin
      await SupabaseService.insertRow('almadrars_notifications', {
        'to_role': 'admin',
        'title': 'طلب معاينة جديد',
        'body': 'قام الزبون بطلب مشروع جديد: $_selectedService (#$reqNumber)',
        'data': {'request_id': reqId, 'request_number': reqNumber}
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال طلب المشروع للإدارة بنجاح')));
        _locationController.clear();
        _areaController.clear();
        _detailsController.clear();
        setState(() => _attachedFiles.clear());
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تقديم طلب مشروع / معاينة')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3A86FF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF3A86FF).withValues(alpha: 0.3)),
                    ),
                    child: const Text('خدمة هندسية معتمدة', style: TextStyle(fontSize: 11, color: Color(0xFF60A5FA), fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 10),
                  Text(_selectedService, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 6),
                  const Text('قم بتعبئة النموذج وسيقوم المهندس المختص بزيارة الموقع وتزويدك بتقرير وتسعير دقيق.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('نوع الخدمة المطلوبة', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedService,
                    items: _services.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (val) => setState(() => _selectedService = val!),
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _locationController,
                    decoration: InputDecoration(
                      labelText: 'الموقع / المدينة والحي',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(icon: const Icon(Icons.my_location, color: Color(0xFF3A86FF)), onPressed: _getLocation),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _areaController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'المساحة التقديرية (متر مربع)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _detailsController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'تفاصيل المشروع والاحتياجات الخاصة', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  const Text('إرفاق صور المبنى والمخططات الهندسية', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library, size: 18),
                          label: const Text('معرض الصور'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt, size: 18),
                          label: const Text('الكاميرا'),
                        ),
                      ),
                    ],
                  ),
                  if (_attachedFiles.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Column(
                      children: _attachedFiles.map((file) => Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('📎 $file', style: const TextStyle(fontSize: 12)),
                            const Text('مرفق', style: TextStyle(fontSize: 11, color: Colors.green)),
                          ],
                        ),
                      )).toList(),
                    ),
                  ],
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submitRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3A86FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('إرسال طلب المعاينة والتسعير 🚀', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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

// ---------------------------------------------------------------------------
// SCREEN 3: MY ORDERS & TRACKING
// ---------------------------------------------------------------------------
class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => MyOrdersScreenState();
}

class MyOrdersScreenState extends State<MyOrdersScreen> {
  String _selectedFilter = 'الكل';
  List<dynamic> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    refreshData();
  }

  Future<void> refreshData() async {
    final uid = SupabaseService.userId;
    if (uid == null) return;
    try {
      final data = await SupabaseService.getTable('almadrars_requests', query: 'customer_id=eq.$uid&order=created_at.desc');
      if (mounted) {
        setState(() {
          _orders = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (e.toString().contains('401')) {
        await SupabaseService.signOut();
        if (mounted) {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
        }
      }
    }
  }

  void _showProjectDetails(Map<String, dynamic> item) async {
    final reqId = item['id'];
    List<dynamic> stages = [];
    try {
      stages = await SupabaseService.getTable('almadrars_project_stages', query: 'request_id=eq.$reqId&order=created_at.asc');
    } catch (_) {}

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        builder: (context, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade700, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Text('تفاصيل مشروع #${item['request_number'] ?? ''}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(item['service_type'] ?? '', style: const TextStyle(color: Color(0xFF3A86FF), fontWeight: FontWeight.bold)),
            const Divider(height: 24, color: Colors.white12),
            _buildDetailRow('الحالة الحالية', item['status'] ?? 'قيد المراجعة'),
            _buildDetailRow('الموقع الميداني', item['location'] ?? 'غير محدد'),
            _buildDetailRow('المساحة', '${item['area_sqm'] ?? 0} م²'),
            _buildDetailRow('التكلفة التقديرية', '${item['estimated_cost'] ?? 0} د.ل'),
            _buildDetailRow('المدة المتوقعة', item['estimated_duration'] ?? 'قيد الدراسة'),
            if (item['status_notes'] != null && item['status_notes'].toString().isNotEmpty)
              _buildDetailRow('ملاحظات الإدارة', item['status_notes']),
            if (item['technical_specs'] != null && item['technical_specs'].toString().isNotEmpty)
              _buildDetailRow('المواصفات الفنية', item['technical_specs']),
            const SizedBox(height: 16),
            const Text('مراحل تنفيذ المشروع:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            if (stages.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('لم يتم إدخال مراحل ميدانية بعد من قسم الهندسية.', style: TextStyle(color: Colors.grey, fontSize: 13)),
              )
            else
              Column(
                children: stages.map((st) {
                  final isDone = st['is_completed'] == true;
                  final isCurrent = st['is_current'] == true;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isCurrent ? const Color(0xFF3A86FF).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isCurrent ? const Color(0xFF3A86FF) : Colors.transparent),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isDone ? Icons.check_circle : (isCurrent ? Icons.play_circle_fill : Icons.radio_button_unchecked),
                          color: isDone ? Colors.greenAccent : (isCurrent ? const Color(0xFF3A86FF) : Colors.grey),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(st['stage_title'] ?? 'مرحلة', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              if (st['stage_description'] != null)
                                Text(st['stage_description'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Flexible(child: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), textAlign: TextAlign.left)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredOrders = _selectedFilter == 'الكل'
        ? _orders
        : _orders.where((o) => o['status'] == _selectedFilter).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('مشاريعي وطلبات المقاولات')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: ['الكل', 'قيد المراجعة', 'تم التسعير', 'قيد التنفيذ', 'مكتمل'].map((filter) {
                      final isSelected = _selectedFilter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ChoiceChip(
                          label: Text(filter),
                          selected: isSelected,
                          onSelected: (selected) => setState(() => _selectedFilter = filter),
                          selectedColor: const Color(0xFF3A86FF),
                          backgroundColor: Colors.white10,
                          labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontWeight: FontWeight.bold),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Expanded(
                  child: filteredOrders.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
                              SizedBox(height: 12),
                              Text('لا توجد طلبات بهذه الحالة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredOrders.length,
                          itemBuilder: (context, index) {
                            final item = filteredOrders[index];
                            return InkWell(
                              onTap: () => _showProjectDetails(item),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B).withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('#${item['request_number'] ?? ''} • ${item['created_at'] != null ? item['created_at'].toString().substring(0, 10) : ''}', style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF3A86FF).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(item['status'] ?? 'قيد المراجعة', style: const TextStyle(fontSize: 11, color: Color(0xFF60A5FA), fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(item['service_type'] ?? 'مشروع هندسي', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                    const SizedBox(height: 6),
                                    Text('الموقع: ${item['location'] ?? 'غير محدد'}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    const SizedBox(height: 10),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text('السعر التقديري المتفق عليه:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                          Text('${item['estimated_cost'] ?? 0} د.ل', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF3A86FF))),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () {},
                                            icon: const Icon(Icons.chat, size: 16, color: Color(0xFF25D366)),
                                            label: const Text('واتساب الإدارة', style: TextStyle(fontSize: 12, color: Color(0xFF25D366))),
                                            style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF25D366))),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () => _showProjectDetails(item),
                                            icon: const Icon(Icons.info_outline, size: 16, color: Color(0xFF60A5FA)),
                                            label: const Text('تفاصيل التتبع', style: TextStyle(fontSize: 12, color: Color(0xFF60A5FA))),
                                            style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF60A5FA))),
                                          ),
                                        ),
                                      ],
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

// ---------------------------------------------------------------------------
// SCREEN 4: NOTIFICATIONS INBOX
// ---------------------------------------------------------------------------
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => NotificationsScreenState();
}

class NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    refreshNotifications();
  }

  Future<void> refreshNotifications() async {
    final uid = SupabaseService.userId;
    if (uid == null) return;
    try {
      final data = await SupabaseService.getTable(
        'almadrars_notifications',
        query: 'or=(to_user.eq.$uid,to_role.eq.customer)&order=created_at.desc',
      );
      if (mounted) {
        setState(() {
          _notifications = data;
          _isLoading = false;
        });
      }
      for (var notif in data) {
        if (notif['read_at'] == null) {
          await SupabaseService.updateRow(
            'almadrars_notifications',
            'id=eq.${notif['id']}',
            {'read_at': DateTime.now().toIso8601String()},
          );
        }
      }
    } catch (e) {
      if (e.toString().contains('401')) {
        await SupabaseService.signOut();
        if (mounted) {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
        }
      }
    }
  }

  void _markAsRead(dynamic notif) async {
    if (notif['read_at'] == null) {
      final now = DateTime.now().toIso8601String();
      try {
        await SupabaseService.updateRow('almadrars_notifications', 'id=eq.${notif['id']}', {'read_at': now});
        refreshNotifications();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final int unreadCount = _notifications.where((n) => n['read_at'] == null).length;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('مركز الإشعارات والتنبيهات'),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Badge(
                label: Text('$unreadCount'),
                backgroundColor: const Color(0xFFFF006E),
              ),
            ],
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(child: Text('لا توجد إشعارات حالياً', style: TextStyle(color: Colors.grey)))
              : RefreshIndicator(
                  onRefresh: refreshNotifications,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    itemBuilder: (context, index) {
                      final item = _notifications[index];
                      final isUnread = item['read_at'] == null;
                      return InkWell(
                        onTap: () => _markAsRead(item),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B).withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isUnread ? const Color(0xFF3A86FF).withValues(alpha: 0.6) : Colors.white10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      if (isUnread) ...[
                                        const CircleAvatar(radius: 4, backgroundColor: Color(0xFF3A86FF)),
                                        const SizedBox(width: 6),
                                      ],
                                      Text(item['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                    ],
                                  ),
                                  Text(
                                    item['created_at'] != null ? item['created_at'].toString().substring(0, 10) : '',
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(item['body'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// ---------------------------------------------------------------------------
// SCREEN 5: PROFILE & SETTINGS
// ---------------------------------------------------------------------------
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final uid = SupabaseService.userId;
    if (uid == null) return;
    try {
      final data = await SupabaseService.getTable('almadrars_profiles', query: 'id=eq.$uid');
      if (mounted) {
        setState(() {
          _profile = data.isNotEmpty ? data.first : null;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (e.toString().contains('401')) {
        await SupabaseService.signOut();
        if (mounted) {
          Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
        }
      }
    }
  }

  void _showEditProfileModal() {
    final nameController = TextEditingController(text: _profile?['full_name'] ?? '');
    final phoneController = TextEditingController(text: _profile?['phone'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('تعديل البيانات الشخصية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'الاسم الكامل', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: phoneController, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder())),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final uid = SupabaseService.userId;
                if (uid == null) return;
                await SupabaseService.updateRow('almadrars_profiles', 'id=eq.$uid', {
                  'full_name': nameController.text.trim(),
                  'phone': phoneController.text.trim(),
                });
                if (mounted) {
                  Navigator.pop(context);
                  _fetchProfile();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث البيانات بنجاح')));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3A86FF), foregroundColor: Colors.white),
              child: const Text('حفظ التغييرات'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordModal() {
    final passController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('تغيير كلمة المرور', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(controller: passController, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة', border: OutlineInputBorder())),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                if (passController.text.length < 6) return;
                await SupabaseService.updatePassword(newPassword: passController.text.trim());
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تغيير كلمة المرور بنجاح')));
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3A86FF), foregroundColor: Colors.white),
              child: const Text('تحديث كلمة المرور'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('الملف الشخصي والإعدادات')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(colors: [Color(0xFF3A86FF), Color(0xFFFF006E)]),
                          ),
                          alignment: Alignment.center,
                          child: Text((_profile?['full_name'] ?? 'م')[0], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_profile?['full_name'] ?? 'زبون المدرار', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(height: 2),
                            Text(_profile?['email'] ?? SupabaseService.userEmail ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            const SizedBox(height: 2),
                            Text(_profile?['phone'] ?? 'غير متوفر', style: const TextStyle(fontSize: 12, color: Color(0xFF3A86FF))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B).withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.person_outline, color: Color(0xFF3A86FF)),
                          title: const Text('تعديل البيانات الشخصية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                          onTap: _showEditProfileModal,
                        ),
                        const Divider(height: 1, color: Colors.white10),
                        ListTile(
                          leading: const Icon(Icons.lock_outline, color: Color(0xFF3A86FF)),
                          title: const Text('تغيير كلمة المرور', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                          onTap: _showChangePasswordModal,
                        ),
                        const Divider(height: 1, color: Colors.white10),
                        ListTile(
                          leading: const Icon(Icons.support_agent, color: Color(0xFF25D366)),
                          title: const Text('الدعم الفني المباشر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('فريق الدعم الفني: +218912345678')));
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () async {
                      await SupabaseService.signOut();
                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('تسجيل الخروج من الحساب'),
                  ),
                  const SizedBox(height: 24),
                  const Text('v2.4.0 • almadrars', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
    );
  }
}
