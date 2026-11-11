import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
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
  runApp(const AlmadrarsAdminApp());
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: firebaseOptions);
  debugPrint('Handling background message: ${message.messageId}');
}

// ---------------------------------------------------------------------------
// DESIGN SYSTEM CONSTANTS & THEMES
// ---------------------------------------------------------------------------
const Color kM3Primary = Color(0xFF2563EB);
const Color kM3Secondary = Color(0xFFE11D48);
const Color kM3Accent = Color(0xFFF59E0B);
const Color kM3BgDark = Color(0xFF090D16);
const Color kM3SurfaceDark = Color(0xFF131B2E);
const Color kM3SurfaceCard = Color(0xFF1E293B);
const Color kM3BorderGlass = Color(0x2AFFFFFF);
const Color kM3Success = Color(0xFF10B981);
const Color kM3Warning = Color(0xFFF59E0B);
const Color kM3Error = Color(0xFFEF4444);

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

// ---------------------------------------------------------------------------
// SUPABASE REST CLIENT SERVICE
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

  static Future<void> saveSession(
      String at, String rt, String uid, String email) async {
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

  static String parseErrorMessage(dynamic body, String defaultMsg,
      {bool isVerify = false}) {
    if (body is Map) {
      final msg = (body['msg'] ??
              body['message'] ??
              body['error_description'] ??
              body['error'] ??
              '')
          .toString();
      final lower = msg.toLowerCase();
      if (lower.contains('rate limit') ||
          lower.contains('over_request') ||
          lower.contains('too many requests')) {
        return 'اتبعتت رسائل كتير، استنى دقايق';
      }
      if (lower.contains('smtp') ||
          lower.contains('sending') ||
          lower.contains('error sending') ||
          lower.contains('unable to send')) {
        return 'ما قدرنا نرسل البريد';
      }
      if (isVerify) {
        return 'رمز التحقق غير صحيح أو انتهت صلاحيته';
      }
      if (msg.isNotEmpty) return msg;
    }
    return isVerify ? 'رمز التحقق غير صحيح أو انتهت صلاحيته' : defaultMsg;
  }

  static Future<bool> tryRefreshToken() async {
    if (refreshToken == null || refreshToken!.isEmpty) return false;
    try {
      final url =
          Uri.parse('$kSupabaseUrl/auth/v1/token?grant_type=refresh_token');
      final response = await http.post(
        url,
        headers: {
          'apikey': kSupabaseAnonKey,
          'Content-Type': 'application/json',
        },
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

  // Claim Admin RPC: OPEN TO ANY SIGNED IN USER
  static Future<bool> claimAdmin({String? pin}) async {
    try {
      final url = Uri.parse('$kSupabaseUrl/rest/v1/rpc/almadrars_claim_admin');
      final bodyMap = pin != null ? {"pin": pin} : <String, dynamic>{};
      var response =
          await http.post(url, headers: headers, body: jsonEncode(bodyMap));
      if (response.statusCode == 401) {
        if (await tryRefreshToken()) {
          response =
              await http.post(url, headers: headers, body: jsonEncode(bodyMap));
        } else {
          return false;
        }
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final res = jsonDecode(response.body);
        if (res is bool) return res;
        if (res.toString() == 'true') return true;
      }
    } catch (_) {}
    return false;
  }

  // Read profile role: GET almadrars_profiles?id=eq.<user.id>
  static Future<String?> getProfileRole(String uid) async {
    try {
      final res = await getTable('almadrars_profiles', query: 'id=eq.$uid');
      if (res.isNotEmpty && res.first is Map) {
        return res.first['role'] as String?;
      }
    } catch (_) {}
    return null;
  }

  // Register Device RPC
  static Future<void> registerDevice(String token) async {
    try {
      final url =
          Uri.parse('$kSupabaseUrl/rest/v1/rpc/almadrars_register_device');
      await http.post(url,
          headers: headers,
          body: jsonEncode({"device_token": token, "app_name": "admin"}));
    } catch (_) {}
  }

  static Future<void> signIn(
      {required String email, required String password}) async {
    final url = Uri.parse('$kSupabaseUrl/auth/v1/token?grant_type=password');
    final response = await http.post(
      url,
      headers: {
        'apikey': kSupabaseAnonKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode({"email": email, "password": password}),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body);
      await saveSession(
        data['access_token'] ?? '',
        data['refresh_token'] ?? '',
        data['user']?['id'] ?? '',
        data['user']?['email'] ?? email,
      );
    } else {
      final decoded = jsonDecode(response.body);
      throw Exception(parseErrorMessage(decoded, 'فشل تسجيل الدخول'));
    }
  }

  static Future<List<dynamic>> getTable(String table,
      {String query = ''}) async {
    final queryString = query.isEmpty ? 'select=*' : 'select=*&$query';
    final url = Uri.parse('$kSupabaseUrl/rest/v1/$table?$queryString');
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

  static Future<dynamic> insertRow(
      String table, Map<String, dynamic> data) async {
    final url = Uri.parse('$kSupabaseUrl/rest/v1/$table');
    var response =
        await http.post(url, headers: headers, body: jsonEncode(data));
    if (response.statusCode == 401) {
      if (await tryRefreshToken()) {
        response =
            await http.post(url, headers: headers, body: jsonEncode(data));
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

  static Future<void> updateRow(
      String table, String query, Map<String, dynamic> data) async {
    final url = Uri.parse('$kSupabaseUrl/rest/v1/$table?$query');
    var response =
        await http.patch(url, headers: headers, body: jsonEncode(data));
    if (response.statusCode == 401) {
      if (await tryRefreshToken()) {
        response =
            await http.patch(url, headers: headers, body: jsonEncode(data));
      } else {
        throw Exception('401');
      }
    }
    if (response.statusCode >= 400) {
      throw Exception('فشل تحديث البيانات');
    }
  }
}

// ---------------------------------------------------------------------------
// MAIN APPLICATION
// ---------------------------------------------------------------------------
class AlmadrarsAdminApp extends StatelessWidget {
  const AlmadrarsAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      title: 'إدارة المدرار للمقاولات الهندسية',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'LY'),
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
          seedColor: kM3Primary,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kM3Primary,
          brightness: Brightness.dark,
          primary: kM3Primary,
          secondary: kM3Secondary,
          surface: kM3SurfaceDark,
        ),
        scaffoldBackgroundColor: kM3BgDark,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0C1322),
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

// ---------------------------------------------------------------------------
// AUTH WRAPPER: ADMIN LOGIN IS OPEN TO ANY EMAIL
// ---------------------------------------------------------------------------
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  bool _needsAdminPin = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final hasSession = await SupabaseService.loadSession();
    if (hasSession && SupabaseService.userId != null) {
      // 1. Claim admin with {}
      await SupabaseService.claimAdmin();
      // 2. Read profile again
      final role = await SupabaseService.getProfileRole(SupabaseService.userId!);
      if (role != 'admin') {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isLoggedIn = true;
            _needsAdminPin = true;
          });
        }
        return;
      }
      // Register Push
      try {
        await FirebaseMessaging.instance.requestPermission();
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) await SupabaseService.registerDevice(token);
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _isLoggedIn = hasSession;
        _isLoading = false;
        _needsAdminPin = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: kM3Primary),
        ),
      );
    }
    if (!_isLoggedIn) {
      return const AuthScreen();
    }
    if (_needsAdminPin) {
      return AdminPinScreen(onSuccess: () {
        setState(() => _needsAdminPin = false);
      });
    }
    return const MainContainerScreen();
  }
}

// ---------------------------------------------------------------------------
// ADMIN PIN SCREEN (SHOWN ONLY IF PIN PROTECTION IS CONFIGURED)
// ---------------------------------------------------------------------------
class AdminPinScreen extends StatefulWidget {
  final VoidCallback onSuccess;
  const AdminPinScreen({super.key, required this.onSuccess});

  @override
  State<AdminPinScreen> createState() => _AdminPinScreenState();
}

class _AdminPinScreenState extends State<AdminPinScreen> {
  final _pinController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  void _submitPin() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final success =
        await SupabaseService.claimAdmin(pin: _pinController.text.trim());
    setState(() => _isLoading = false);
    if (success) {
      try {
        await FirebaseMessaging.instance.requestPermission();
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) await SupabaseService.registerDevice(token);
      } catch (_) {}
      widget.onSuccess();
    } else {
      setState(() => _error = 'رمز الإدارة غير صحيح');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('دخول الإدارة')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.admin_panel_settings, size: 64, color: kM3Primary),
            const SizedBox(height: 24),
            const Text(
              'أدخل رمز الإدارة لتفعيل صلاحيات الإدارة على هذا الجهاز',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
            const SizedBox(height: 24),
            if (_error != null) ...[
              Text(_error!,
                  style: const TextStyle(color: kM3Error),
                  textAlign: TextAlign.center),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _pinController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'رمز الإدارة',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _submitPin,
              style: ElevatedButton.styleFrom(
                backgroundColor: kM3Primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('تأكيد رمز الإدارة'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () async {
                await SupabaseService.signOut();
                if (mounted) {
                  Navigator.pushReplacement(context,
                      MaterialPageRoute(builder: (_) => const AuthScreen()));
                }
              },
              child: const Text('تسجيل الخروج والرجوع',
                  style: TextStyle(color: kM3Error)),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AUTH SCREEN: OPEN SIGN-IN FOR ANY EMAIL (NO EMAIL RESTRICTION)
// ---------------------------------------------------------------------------
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  int _tabIndex = 0; // 0: Login, 1: Signup, 2: Recover
  bool _isLoading = false;
  String? _error;

  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  final _signupNameController = TextEditingController();
  final _signupPhoneController = TextEditingController();
  final _signupEmailController = TextEditingController();
  final _signupPasswordController = TextEditingController();
  final _signupConfirmController = TextEditingController();
  bool _obscurePassword = true;

  final _recoverEmailController = TextEditingController();

  bool _isVerifyMode = false;
  String _verifyEmail = '';
  String _verifyType = 'signup';
  final _otpController = TextEditingController();

  bool _isNewPasswordMode = false;
  final _newPasswordController = TextEditingController();

  void _handleLogin() async {
    final email = _loginEmailController.text.trim();
    final pass = _loginPasswordController.text.trim();
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'يرجى إدخال البريد الإلكتروني وكلمة المرور');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await SupabaseService.signIn(email: email, password: pass);
      await SupabaseService.claimAdmin();
      final role = await SupabaseService.getProfileRole(SupabaseService.userId!);
      if (role != 'admin') {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => AdminPinScreen(
                onSuccess: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const MainContainerScreen()),
                ),
              ),
            ),
          );
        }
        return;
      }

      try {
        await FirebaseMessaging.instance.requestPermission();
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) await SupabaseService.registerDevice(token);
      } catch (_) {}

      if (mounted) {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const MainContainerScreen()));
      }
    } catch (e) {
      final msg = e.toString().replaceAll('Exception: ', '');
      if (msg.contains('not confirmed') || msg.contains('Email not confirmed')) {
        try {
          await http.post(
            Uri.parse('$kSupabaseUrl/auth/v1/resend'),
            headers: {
              'apikey': kSupabaseAnonKey,
              'Content-Type': 'application/json'
            },
            body: jsonEncode({"type": "signup", "email": email}),
          );
        } catch (_) {}
        setState(() {
          _verifyEmail = email;
          _verifyType = 'signup';
          _isVerifyMode = true;
          _error = 'البريد غير مؤكد. تم إرسال رمز التحقق مجدداً إلى بريدك.';
        });
      } else {
        setState(() => _error = msg);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleSignup() async {
    final name = _signupNameController.text.trim();
    final phone = _signupPhoneController.text.trim();
    final email = _signupEmailController.text.trim();
    final pass = _signupPasswordController.text.trim();
    final confirm = _signupConfirmController.text.trim();

    if (name.isEmpty || phone.isEmpty || email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'يرجى ملء جميع الحقول المطلوبة');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      return;
    }
    if (pass != confirm) {
      setState(() => _error = 'كلمتا المرور غير متطابقتين');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final url = Uri.parse('$kSupabaseUrl/auth/v1/signup');
      final response = await http.post(
        url,
        headers: {
          'apikey': kSupabaseAnonKey,
          'Content-Type': 'application/json'
        },
        body: jsonEncode({
          "email": email,
          "password": pass,
          "data": {"full_name": name, "phone": phone}
        }),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          _verifyEmail = email;
          _verifyType = 'signup';
          _isVerifyMode = true;
        });
      } else {
        final decoded = jsonDecode(response.body);
        throw Exception(
            SupabaseService.parseErrorMessage(decoded, 'فشل إنشاء الحساب'));
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleVerifyCode() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'رمز التحقق يجب أن يكون 6 أرقام');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final url = Uri.parse('$kSupabaseUrl/auth/v1/verify');
      final response = await http.post(
        url,
        headers: {
          'apikey': kSupabaseAnonKey,
          'Content-Type': 'application/json'
        },
        body: jsonEncode(
            {"type": _verifyType, "email": _verifyEmail, "token": code}),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        final at = data['access_token'] ?? '';
        final rt = data['refresh_token'] ?? '';
        final uid = data['user']?['id'] ?? '';
        await SupabaseService.saveSession(at, rt, uid, _verifyEmail);

        if (_verifyType == 'recovery') {
          setState(() {
            _isVerifyMode = false;
            _isNewPasswordMode = true;
            _isLoading = false;
          });
          return;
        }

        await SupabaseService.claimAdmin();
        final role =
            await SupabaseService.getProfileRole(SupabaseService.userId!);
        if (role != 'admin') {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => AdminPinScreen(
                  onSuccess: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const MainContainerScreen()),
                  ),
                ),
              ),
            );
          }
          return;
        }

        try {
          await FirebaseMessaging.instance.requestPermission();
          final token = await FirebaseMessaging.instance.getToken();
          if (token != null) await SupabaseService.registerDevice(token);
        } catch (_) {}

        if (mounted) {
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => const MainContainerScreen()));
        }
      } else {
        final decoded = jsonDecode(response.body);
        throw Exception(SupabaseService.parseErrorMessage(
            decoded, 'رمز التحقق غير صحيح أو انتهت صلاحيته',
            isVerify: true));
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleRecover() async {
    final email = _recoverEmailController.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'يرجى إدخال البريد الإلكتروني');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final url = Uri.parse('$kSupabaseUrl/auth/v1/recover');
      final response = await http.post(
        url,
        headers: {
          'apikey': kSupabaseAnonKey,
          'Content-Type': 'application/json'
        },
        body: jsonEncode({"email": email}),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          _verifyEmail = email;
          _verifyType = 'recovery';
          _isVerifyMode = true;
        });
      } else {
        final decoded = jsonDecode(response.body);
        throw Exception(SupabaseService.parseErrorMessage(
            decoded, 'فشل إرسال رمز استعادة كلمة المرور'));
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleUpdatePassword() async {
    final newPass = _newPasswordController.text.trim();
    if (newPass.length < 6) {
      setState(
          () => _error = 'كلمة المرور الجديدة يجب أن تكون 6 أحرف على الأقل');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final url = Uri.parse('$kSupabaseUrl/auth/v1/user');
      final response = await http.put(
        url,
        headers: SupabaseService.headers,
        body: jsonEncode({"password": newPass}),
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم تحديث كلمة المرور بنجاح')));
          Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => const MainContainerScreen()));
        }
      } else {
        final decoded = jsonDecode(response.body);
        throw Exception(SupabaseService.parseErrorMessage(
            decoded, 'فشل تحديث كلمة المرور'));
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('إدارة المدرار للمقاولات')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isVerifyMode) ...[
              const Icon(Icons.mark_email_read, size: 64, color: kM3Primary),
              const SizedBox(height: 16),
              const Text('بعتنا رمز على بريدك',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('أدخل الرمز المكون من 6 أرقام المرسل إلى: $_verifyEmail',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 24),
              if (_error != null) ...[
                Text(_error!,
                    style: const TextStyle(color: kM3Error),
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _otpController,
                maxLength: 6,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                    fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                    border: OutlineInputBorder(), counterText: ''),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleVerifyCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kM3Primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('تأكيد الرمز'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () async {
                  try {
                    final response = await http.post(
                      Uri.parse('$kSupabaseUrl/auth/v1/resend'),
                      headers: {
                        'apikey': kSupabaseAnonKey,
                        'Content-Type': 'application/json'
                      },
                      body: jsonEncode(
                          {"type": _verifyType, "email": _verifyEmail}),
                    );
                    if (response.statusCode >= 200 && response.statusCode < 300) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم إعادة إرسال الرمز')));
                      }
                    } else {
                      final decoded = jsonDecode(response.body);
                      setState(() => _error =
                          SupabaseService.parseErrorMessage(decoded, 'فشل إعادة الإرسال'));
                    }
                  } catch (e) {
                    setState(() => _error = 'اتبعتت رسائل كتير، استنى دقايق');
                  }
                },
                child: const Text('إعادة إرسال الرمز (بعد 60 ثانية)'),
              ),
            ] else if (_isNewPasswordMode) ...[
              const Icon(Icons.lock_reset, size: 64, color: kM3Primary),
              const SizedBox(height: 16),
              const Text('تعيين كلمة مرور جديدة',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              if (_error != null) ...[
                Text(_error!,
                    style: const TextStyle(color: kM3Error),
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'كلمة المرور الجديدة (6+ أحرف)',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleUpdatePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kM3Primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('حفظ وتحديث كلمة المرور'),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          setState(() { _tabIndex = 0; _error = null; }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _tabIndex == 0
                            ? kM3Primary
                            : Colors.transparent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                      child: const Text('تسجيل الدخول',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          setState(() { _tabIndex = 1; _error = null; }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _tabIndex == 1
                            ? kM3Primary
                            : Colors.transparent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                      child: const Text('حساب جديد',
                          style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          setState(() { _tabIndex = 2; _error = null; }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _tabIndex == 2
                            ? kM3Primary
                            : Colors.transparent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                      child: const Text('نسيت المرور',
                          style: TextStyle(fontSize: 11)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_error != null) ...[
                Text(_error!,
                    style: const TextStyle(color: kM3Error),
                    textAlign: TextAlign.center),
                const SizedBox(height: 12),
              ],
              if (_tabIndex == 0) ...[
                TextField(
                  controller: _loginEmailController,
                  decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _loginPasswordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kM3Primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('دخول لوحة الإدارة'),
                ),
              ] else if (_tabIndex == 1) ...[
                TextField(
                  controller: _signupNameController,
                  decoration: const InputDecoration(
                      labelText: 'الاسم الكامل', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _signupPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                      labelText: 'رقم الهاتف', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _signupEmailController,
                  decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _signupPasswordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور (6+ أحرف)',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _signupConfirmController,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'تأكيد كلمة المرور',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleSignup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kM3Primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('تسجيل حساب جديد'),
                ),
              ] else if (_tabIndex == 2) ...[
                TextField(
                  controller: _recoverEmailController,
                  decoration: const InputDecoration(
                      labelText: 'البريد الإلكتروني للاستعادة',
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleRecover,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kM3Primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('إرسال رمز الاستعادة'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// MAIN CONTAINER SCREEN (15S SYNC + INBOX WITH UNREAD BADGE + REALTIME FCM)
// ---------------------------------------------------------------------------
class MainContainerScreen extends StatefulWidget {
  final int initialTab;
  const MainContainerScreen({super.key, this.initialTab = 0});

  @override
  State<MainContainerScreen> createState() => _MainContainerScreenState();
}

class _MainContainerScreenState extends State<MainContainerScreen>
    with WidgetsBindingObserver {
  late int _currentIndex;
  List<dynamic> _requests = [];
  List<dynamic> _services = [];
  List<dynamic> _customers = [];
  List<dynamic> _notifications = [];
  bool _isLoadingData = true;
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab;
    WidgetsBinding.instance.addObserver(this);
    _fetchAllDataQuiet();
    _setupPushListeners();
    _startPeriodicSync();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchAllDataQuiet();
    }
  }

  void _startPeriodicSync() {
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _fetchAllDataQuiet();
    });
  }

  void _setupPushListeners() {
    try {
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        if (notification != null) {
          rootScaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text(
                  '${notification.title ?? 'تنبيه'}: ${notification.body ?? ''}'),
              backgroundColor: kM3Primary,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        _fetchAllDataQuiet();
      });
    } catch (_) {}
  }

  Future<void> _fetchAllDataQuiet() async {
    try {
      final uid = SupabaseService.userId ?? '';
      final reqs = await SupabaseService.getTable('almadrars_requests',
          query: 'order=created_at.desc');
      final srvs = await SupabaseService.getTable('almadrars_services',
          query: 'order=created_at.desc');
      final custs = await SupabaseService.getTable('almadrars_profiles',
          query: 'role=eq.customer&order=created_at.desc');

      final notifsUrlQuery =
          'or=(to_user.eq.$uid,to_role.eq.admin)&order=created_at.desc';
      final notifs = await SupabaseService.getTable('almadrars_notifications',
          query: notifsUrlQuery);

      if (mounted) {
        setState(() {
          _requests = reqs;
          _services = srvs;
          _customers = custs;
          _notifications = notifs;
          _isLoadingData = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  int get _unreadNotificationsCount {
    return _notifications.where((n) => n['read_at'] == null).length;
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardTab(
        requests: _requests,
        services: _services,
        onNavigate: (idx) => setState(() => _currentIndex = idx),
        onRefresh: _fetchAllDataQuiet,
      ),
      RequestsTab(requests: _requests, onRefresh: _fetchAllDataQuiet),
      ServicesTab(services: _services, onRefresh: _fetchAllDataQuiet),
      NotificationsInboxScreen(
        notifications: _notifications,
        onRefresh: _fetchAllDataQuiet,
      ),
      CustomersTab(customers: _customers),
      SettingsTab(onSignOut: () {
        _syncTimer?.cancel();
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const AuthScreen()));
      }),
      const SkeletonTab(),
      const EmptyTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المدرار للمقاولات الهندسية',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                tooltip: 'صندوق الإشعارات',
                onPressed: () => setState(() => _currentIndex = 3),
              ),
              if (_unreadNotificationsCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: kM3Secondary,
                      shape: BoxShape.circle,
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      '$_unreadNotificationsCount',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          PopupMenuButton<int>(
            icon: const Icon(Icons.menu_rounded),
            onSelected: (idx) => setState(() => _currentIndex = idx),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 0, child: Text('📊 لوحة التحكم والإحصائيات')),
              PopupMenuItem(value: 1, child: Text('📋 إدارة طلبات الزبائن والتسعير')),
              PopupMenuItem(value: 2, child: Text('🏗️ إدارة الخدمات والتشطيبات')),
              PopupMenuItem(value: 3, child: Text('🔔 صندوق الإشعارات الواردة')),
              PopupMenuItem(value: 4, child: Text('👥 قائمة الزبائن والعملاء')),
              PopupMenuItem(value: 5, child: Text('⚙️ إعدادات النظام الإداري')),
              PopupMenuItem(value: 6, child: Text('⏳ حالة التحميل (Skeleton)')),
              PopupMenuItem(value: 7, child: Text('📭 حالة الفارغ (Empty)')),
            ],
          ),
        ],
      ),
      body: _isLoadingData && _requests.isEmpty
          ? const Center(child: CircularProgressIndicator(color: kM3Primary))
          : screens[_currentIndex < screens.length ? _currentIndex : 0],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex > 3 ? 0 : _currentIndex,
        onDestinationSelected: (idx) {
          setState(() => _currentIndex = idx);
        },
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'اللوحة'),
          const NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment),
              label: 'الطلبات'),
          const NavigationDestination(
              icon: Icon(Icons.architecture_outlined),
              selectedIcon: Icon(Icons.architecture),
              label: 'الخدمات'),
          NavigationDestination(
              icon: Badge(
                isLabelVisible: _unreadNotificationsCount > 0,
                label: Text('$_unreadNotificationsCount'),
                child: const Icon(Icons.notifications_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: _unreadNotificationsCount > 0,
                label: Text('$_unreadNotificationsCount'),
                child: const Icon(Icons.notifications),
              ),
              label: 'الإشعارات'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SCREEN 1: DASHBOARD
// ---------------------------------------------------------------------------
class DashboardTab extends StatelessWidget {
  final List<dynamic> requests;
  final List<dynamic> services;
  final Function(int) onNavigate;
  final VoidCallback onRefresh;

  const DashboardTab({
    super.key,
    required this.requests,
    required this.services,
    required this.onNavigate,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0x332563EB), Color(0xCC131B2E)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kM3BorderGlass),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('لوحة متابعة مشاريع المدرار للمقاولات 🏗️',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                SizedBox(height: 6),
                Text(
                  'مزامنة فورية حية مع تطبيق الزبون كل 15 ثانية وتحديث لحظي لعروض الأسعار ومراحل الإنجاز.',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.3,
            children: [
              _buildKpiCard('إجمالي طلبات المقاولات', '${requests.length}',
                  Icons.description, kM3Primary, '▲ نشط ومحدث', kM3Success),
              _buildKpiCard('الخدمات المتاحة', '${services.length}',
                  Icons.architecture, kM3Warning, '● دليل الخدمات', kM3Warning),
              _buildKpiCard(
                  'قيد التنفيذ الميداني',
                  '${requests.where((r) => r['status'] == 'progress').length}',
                  Icons.verified,
                  kM3Success,
                  '▲ في الموقع',
                  kM3Success),
              _buildKpiCard(
                  'بانتظار التسعير',
                  '${requests.where((r) => r['status'] == 'review' || r['status'] == 'new').length}',
                  Icons.pending_actions,
                  kM3Secondary,
                  'فوري',
                  kM3Secondary),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => onNavigate(1),
                  icon: const Icon(Icons.price_change, size: 16),
                  label: const Text('إدارة الطلبات والتسعير',
                      style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: kM3Primary,
                      foregroundColor: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onNavigate(3),
                  icon: const Icon(Icons.campaign, size: 16),
                  label: const Text('إرسال تنبيه جماعي',
                      style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kM3BorderGlass)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('أحدث الطلبات الواردة',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () => onNavigate(1),
                child:
                    const Text('عرض الكل ←', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          ...requests.take(3).map((req) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                color: kM3SurfaceCard,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('طلب #${req['request_number'] ?? '9042'}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                          Chip(
                            label: Text(req['status'] ?? 'review',
                                style: const TextStyle(fontSize: 10)),
                            backgroundColor: kM3Primary.withValues(alpha: 0.2),
                          ),
                        ],
                      ),
                      Text(req['service_type'] ?? 'طلب أعمال هندسية',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.white)),
                      const SizedBox(height: 4),
                      Text('📍 الموقع: ${req['location'] ?? 'طرابلس'}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white70)),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String val, IconData icon, Color iconColor,
      String trend, Color trendColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kM3SurfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kM3BorderGlass),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                  child: Text(title,
                      style:
                          const TextStyle(fontSize: 11, color: Colors.grey))),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 16, color: iconColor),
              ),
            ],
          ),
          Text(val,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          Text(trend,
              style: TextStyle(
                  fontSize: 10,
                  color: trendColor,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// IN-APP NOTIFICATIONS INBOX SCREEN (READS almadrars_notifications & MARKS READ)
// ---------------------------------------------------------------------------
class NotificationsInboxScreen extends StatefulWidget {
  final List<dynamic> notifications;
  final VoidCallback onRefresh;

  const NotificationsInboxScreen({
    super.key,
    required this.notifications,
    required this.onRefresh,
  });

  @override
  State<NotificationsInboxScreen> createState() =>
      _NotificationsInboxScreenState();
}

class _NotificationsInboxScreenState extends State<NotificationsInboxScreen> {
  String _filter = 'all';

  Future<void> _markAsRead(String id) async {
    try {
      final nowIso = DateTime.now().toIso8601String();
      await SupabaseService.updateRow(
        'almadrars_notifications',
        'id=eq.$id',
        {'read_at': nowIso},
      );
      widget.onRefresh();
    } catch (_) {}
  }

  Future<void> _markAllAsRead() async {
    final unread =
        widget.notifications.where((n) => n['read_at'] == null).toList();
    if (unread.isEmpty) return;

    final nowIso = DateTime.now().toIso8601String();
    for (final n in unread) {
      try {
        await SupabaseService.updateRow(
          'almadrars_notifications',
          'id=eq.${n['id']}',
          {'read_at': nowIso},
        );
      } catch (_) {}
    }
    widget.onRefresh();
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      final y = dt.year.toString().padLeft(4, '0');
      final m = dt.month.toString().padLeft(2, '0');
      final d = dt.day.toString().padLeft(2, '0');
      final hh = dt.hour.toString().padLeft(2, '0');
      final mm = dt.minute.toString().padLeft(2, '0');
      return '$y/$m/$d $hh:$mm';
    } catch (_) {
      return dateStr;
    }
  }

  void _showBroadcastModal(BuildContext context) {
    final titleCtrl = TextEditingController(text: 'تنبيه من المدرار للمقاولات');
    final bodyCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kM3SurfaceDark,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('إرسال تنبيه جماعي فوري لجميع الزبائن',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                  labelText: 'عنوان الإشعار', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bodyCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'نص التنبيه العام للزبائن',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final txt = bodyCtrl.text.trim();
                if (txt.isEmpty) return;
                try {
                  await SupabaseService.insertRow('almadrars_notifications', {
                    'to_role': 'customer',
                    'title': titleCtrl.text.trim(),
                    'body': txt,
                    'data': {'broadcast': true}
                  });
                  widget.onRefresh();
                  if (context.mounted) Navigator.pop(context);
                } catch (_) {}
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kM3Primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('إرسال فوري لجميع الزبائن 📢'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount =
        widget.notifications.where((n) => n['read_at'] == null).length;
    final displayedList = widget.notifications.where((n) {
      if (_filter == 'unread') return n['read_at'] == null;
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('صندوق الإشعارات',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  if (unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: kM3Secondary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$unreadCount جديد',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showBroadcastModal(context),
                icon: const Icon(Icons.campaign, size: 16),
                label: const Text('تنبيه جماعي',
                    style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: kM3Secondary,
                    foregroundColor: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              ChoiceChip(
                label: Text('الكل (${widget.notifications.length})',
                    style: const TextStyle(fontSize: 12)),
                selected: _filter == 'all',
                onSelected: (val) => setState(() => _filter = 'all'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text('غير المقروءة ($unreadCount)',
                    style: const TextStyle(fontSize: 12)),
                selected: _filter == 'unread',
                onSelected: (val) => setState(() => _filter = 'unread'),
              ),
              const Spacer(),
              if (unreadCount > 0)
                TextButton.icon(
                  onPressed: _markAllAsRead,
                  icon: const Icon(Icons.done_all, size: 16),
                  label: const Text('تحديد الكل كمقروء',
                      style: TextStyle(fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (displayedList.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(Icons.mark_email_read_outlined,
                        size: 54, color: Colors.grey.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    Text(
                      _filter == 'unread'
                          ? 'لا توجد إشعارات غير مقروءة حالياً'
                          : 'لا توجد إشعارات مسجلة بالصندوق',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ...displayedList.map((n) {
            final isUnread = n['read_at'] == null;
            return Card(
              color: isUnread
                  ? const Color(0xFF1E293B)
                  : const Color(0xFF0F172A),
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isUnread ? kM3Primary : kM3BorderGlass,
                  width: isUnread ? 1.5 : 1.0,
                ),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  if (isUnread) _markAsRead(n['id']);
                },
                child: Padding(
                  padding: const EdgeInsets.all(14),
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
                                  color: isUnread
                                      ? kM3Primary.withValues(alpha: 0.2)
                                      : Colors.white10,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isUnread
                                      ? Icons.notifications_active
                                      : Icons.notifications_none,
                                  size: 16,
                                  color: isUnread ? kM3Primary : Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                n['title'] ?? 'إشعار',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isUnread
                                      ? Colors.white
                                      : Colors.white70,
                                ),
                              ),
                            ],
                          ),
                          if (isUnread)
                            Container(
                              width: 9,
                              height: 9,
                              decoration: const BoxDecoration(
                                color: kM3Secondary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        n['body'] ?? '',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.white70, height: 1.4),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDateTime(n['created_at']),
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey),
                          ),
                          if (isUnread)
                            TextButton.icon(
                              onPressed: () => _markAsRead(n['id']),
                              icon: const Icon(Icons.check, size: 14),
                              label: const Text('تحديد كمقروء',
                                  style: TextStyle(fontSize: 11)),
                              style: TextButton.styleFrom(
                                  foregroundColor: kM3Primary),
                            )
                          else
                            const Row(
                              children: [
                                Icon(Icons.done_all,
                                    size: 14, color: kM3Success),
                                SizedBox(width: 4),
                                Text('مقروء',
                                    style: TextStyle(
                                        fontSize: 10, color: kM3Success)),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// REQUESTS & STATUS UPDATING WITH REALTIME EVENT NOTIFICATIONS
// ---------------------------------------------------------------------------
class RequestsTab extends StatefulWidget {
  final List<dynamic> requests;
  final VoidCallback onRefresh;

  const RequestsTab(
      {super.key, required this.requests, required this.onRefresh});

  @override
  State<RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends State<RequestsTab> {
  String _filterStatus = 'all';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.requests.where((r) {
      if (_filterStatus == 'all') return true;
      return r['status'] == _filterStatus;
    }).toList();

    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('الكل', 'all'),
                _buildFilterChip('بانتظار التسعير', 'review'),
                _buildFilterChip('تم التسعير', 'priced'),
                _buildFilterChip('قيد التنفيذ', 'progress'),
                _buildFilterChip('مكتمل', 'completed'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ...filtered.map((req) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: kM3SurfaceCard,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('طلب #${req['request_number'] ?? '9042'}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                          Chip(
                            label: Text(req['status'] ?? 'review',
                                style: const TextStyle(fontSize: 10)),
                            backgroundColor: kM3Primary.withValues(alpha: 0.2),
                          ),
                        ],
                      ),
                      Text(req['service_type'] ?? 'طلب مقاولات',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.white)),
                      const SizedBox(height: 4),
                      Text('📍 الموقع: ${req['location'] ?? 'طرابلس'}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                      if (req['area_sqm'] != null)
                        Text('المساحة: ${req['area_sqm']} م²',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70)),
                      if (req['estimated_cost'] != null)
                        Text('💰 التكلفة: ${req['estimated_cost']} د.ل',
                            style: const TextStyle(
                                fontSize: 13,
                                color: kM3Success,
                                fontWeight: FontWeight.bold)),
                      if (req['completion_percentage'] != null)
                        Text('نسبة الإنجاز: %${req['completion_percentage']}',
                            style: const TextStyle(
                                fontSize: 12, color: kM3Accent)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _showPricingModal(context, req),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: kM3Primary,
                                  foregroundColor: Colors.white),
                              child: const Text('💵 عرض السعر',
                                  style: TextStyle(fontSize: 11)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _showProgressModal(context, req),
                              style: OutlinedButton.styleFrom(
                                  side:
                                      const BorderSide(color: kM3BorderGlass)),
                              child: const Text('⚙️ الإنجاز والحالة',
                                  style: TextStyle(fontSize: 11)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String status) {
    final isSelected = _filterStatus == status;
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: isSelected,
        onSelected: (val) => setState(() => _filterStatus = status),
      ),
    );
  }

  void _showPricingModal(BuildContext context, Map<String, dynamic> req) {
    final priceController = TextEditingController(
        text: req['estimated_cost']?.toString() ?? '55000');
    final specsController = TextEditingController(
        text: req['technical_specs'] ??
            'خرسانة مسلحة عيار 350 كجم/م3 مع عازل مائي معتمد');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kM3SurfaceDark,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('إضافة عرض سعر ومواصفات فنية للمشروع',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: 'التكلفة الإجمالية (د.ل)',
                    border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(
                controller: specsController,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'المواصفات الفنية المعتمدة',
                    border: OutlineInputBorder())),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final costVal =
                    double.tryParse(priceController.text) ?? 55000;
                await SupabaseService.updateRow(
                    'almadrars_requests', 'id=eq.${req['id']}', {
                  'estimated_cost': costVal,
                  'technical_specs': specsController.text,
                  'status': 'priced'
                });

                // Mandatory Contract Event: إضافة عرض سعر ومواصفات فنية للمشروع
                try {
                  await SupabaseService.insertRow('almadrars_notifications', {
                    'to_user': req['customer_id'],
                    'title': 'إضافة عرض سعر جديد',
                    'body':
                        'تم إضافة عرض سعر بقيمة $costVal د.ل لطلبك رقم #${req['request_number']}',
                    'data': {'request_id': req['id']}
                  });
                } catch (_) {}

                widget.onRefresh();
                if (mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kM3Primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('حفظ وإرسال عرض السعر للزبون 📨'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showProgressModal(BuildContext context, Map<String, dynamic> req) {
    double progress = (req['completion_percentage'] ?? 0).toDouble();
    String selectedStatus = req['status'] ?? 'progress';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kM3SurfaceDark,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 20,
              right: 20,
              top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('تحديث حالة التنفيذ ونسبة الإنجاز الميداني',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedStatus,
                decoration: const InputDecoration(
                    labelText: 'حالة المشروع', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'review', child: Text('قيد المراجعة')),
                  DropdownMenuItem(value: 'priced', child: Text('تم التسعير')),
                  DropdownMenuItem(
                      value: 'progress', child: Text('جاري التنفيذ الميداني')),
                  DropdownMenuItem(value: 'completed', child: Text('مكتمل')),
                ],
                onChanged: (val) =>
                    setModalState(() => selectedStatus = val ?? selectedStatus),
              ),
              const SizedBox(height: 16),
              Text('نسبة الإنجاز: %${progress.round()}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Slider(
                value: progress,
                min: 0,
                max: 100,
                divisions: 20,
                onChanged: (val) => setModalState(() => progress = val),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await SupabaseService.updateRow(
                      'almadrars_requests', 'id=eq.${req['id']}', {
                    'completion_percentage': progress.round(),
                    'status': selectedStatus,
                  });

                  // Mandatory Contract Event: تحديث حالة التنفيذ أو نسبة الإنجاز الميداني
                  try {
                    await SupabaseService.insertRow(
                        'almadrars_notifications', {
                      'to_user': req['customer_id'],
                      'title': 'تحديث حالة المشروع',
                      'body':
                          'تم تحديث نسبة الإنجاز لطلبك رقم #${req['request_number']} إلى %${progress.round()}',
                      'data': {
                        'request_id': req['id'],
                        'status': selectedStatus
                      }
                    });
                  } catch (_) {}

                  widget.onRefresh();
                  if (mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: kM3Primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('حفظ وإرسال التحديث للزبون 🔔'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// SERVICES MANAGEMENT
// ---------------------------------------------------------------------------
class ServicesTab extends StatelessWidget {
  final List<dynamic> services;
  final VoidCallback onRefresh;

  const ServicesTab(
      {super.key, required this.services, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showServiceModal(context, null),
        backgroundColor: kM3Primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('التحكم بالقائمة المتاحة للزبائن وتحديث تفاصيل الخدمات:',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 12),
          ...services.map((srv) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: kM3SurfaceCard,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                              child: Text(srv['title'] ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.white))),
                          Chip(
                              label: Text(
                                  srv['is_available'] == true
                                      ? 'متاحة للطلب'
                                      : 'متوقفة مؤقتاً',
                                  style: const TextStyle(fontSize: 10)),
                              backgroundColor: kM3Success.withValues(alpha: 0.2)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(srv['description'] ?? '',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white70)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => _showServiceModal(context, srv),
                              style: OutlinedButton.styleFrom(
                                  side:
                                      const BorderSide(color: kM3BorderGlass)),
                              child: const Text('✏️ تعديل تفاصيل الخدمة',
                                  style: TextStyle(fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () async {
                              await SupabaseService.updateRow(
                                  'almadrars_services', 'id=eq.${srv['id']}', {
                                'is_available': !(srv['is_available'] ?? true)
                              });
                              onRefresh();
                            },
                            child: const Text('تبديل الحالة',
                                style: TextStyle(color: kM3Warning)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  void _showServiceModal(BuildContext context, Map<String, dynamic>? srv) {
    final titleController = TextEditingController(text: srv?['title'] ?? '');
    final descController =
        TextEditingController(text: srv?['description'] ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: kM3SurfaceDark,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(srv == null ? 'إضافة خدمة جديدة' : 'تعديل تفاصيل الخدمة',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
                controller: titleController,
                decoration: const InputDecoration(
                    labelText: 'اسم الخدمة', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(
                controller: descController,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'وصف الخدمة', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                if (srv == null) {
                  await SupabaseService.insertRow('almadrars_services', {
                    'title': titleController.text,
                    'description': descController.text,
                    'is_available': true
                  });
                } else {
                  await SupabaseService.updateRow(
                      'almadrars_services', 'id=eq.${srv['id']}', {
                    'title': titleController.text,
                    'description': descController.text
                  });
                }
                onRefresh();
                if (context.mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kM3Primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('حفظ التغييرات 💾'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CUSTOMERS LIST
// ---------------------------------------------------------------------------
class CustomersTab extends StatelessWidget {
  final List<dynamic> customers;

  const CustomersTab({super.key, required this.customers});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('قائمة الزبائن المسجلين بالتطبيق:',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 14),
        ...customers.map((c) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: kM3SurfaceCard,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                leading: CircleAvatar(
                    backgroundColor: kM3Primary,
                    child: Text(c['full_name']?[0] ?? 'س',
                        style: const TextStyle(color: Colors.white))),
                title: Text(c['full_name'] ?? 'زبون',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white)),
                subtitle: Text(
                    '${c['phone'] ?? '0910000000'} • ${c['email'] ?? ''}',
                    style:
                        const TextStyle(fontSize: 11, color: Colors.grey)),
              ),
            )),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// SETTINGS & ON-DEMAND PERMISSIONS DEMONSTRATION
// ---------------------------------------------------------------------------
class SettingsTab extends StatelessWidget {
  final VoidCallback onSignOut;
  const SettingsTab({super.key, required this.onSignOut});

  Future<void> _handleLocationDemo(BuildContext context) async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text(
            'تم رفض صلاحية الموقع نهائياً. التطبيق يستمر بالعمل، يمكنك تفعيلها من الإعدادات لإدراج موقع المشروع بدقة.'),
        action: SnackBarAction(
            label: 'فتح الإعدادات',
            onPressed: () => Geolocator.openAppSettings()),
      ));
      return;
    }
    if (perm == LocationPermission.denied && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'تم رفض الصلاحية. التطبيق يستمر بالعمل، نحتاج الموقع لتحديد إحداثيات موقع البناء.'),
      ));
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تم التحقق من صلاحية الموقع بنجاح.'),
        backgroundColor: kM3Success,
      ));
    }
  }

  Future<void> _handlePhotoDemo(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final res = await picker.pickImage(source: ImageSource.gallery);
      if (res != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تم اختيار صورة لتوثيق المشروع بنجاح.'),
          backgroundColor: kM3Success,
        ));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تعذر الوصول للصور. يرجى منح الإذن عند الحاجة.'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: kM3SurfaceCard,
          child: ListTile(
            leading: const CircleAvatar(
                backgroundColor: kM3Primary,
                child: Text('م', style: TextStyle(color: Colors.white))),
            title: Text(SupabaseService.userEmail ?? 'admin@almadrars.ly',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
            subtitle: const Text('مدير قسم المقاولات الهندسية',
                style: TextStyle(color: Colors.grey)),
          ),
        ),
        const SizedBox(height: 20),
        const Text('أذونات النظام اللحظية (تُطلب عند الحاجة فقط):',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 10),
        ListTile(
          tileColor: kM3SurfaceCard,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: const Icon(Icons.location_on, color: kM3Primary),
          title: const Text('اختبار إذن الموقع الميداني للمشاريع'),
          onTap: () => _handleLocationDemo(context),
        ),
        const SizedBox(height: 8),
        ListTile(
          tileColor: kM3SurfaceCard,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: const Icon(Icons.photo_library, color: kM3Accent),
          title: const Text('اختبار إذن استعراض وتوثيق الصور'),
          onTap: () => _handlePhotoDemo(context),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () async {
            await SupabaseService.signOut();
            onSignOut();
          },
          icon: const Icon(Icons.logout, color: kM3Error),
          label: const Text('تسجيل الخروج من لوحة الإدارة',
              style: TextStyle(color: kM3Error)),
          style:
              OutlinedButton.styleFrom(side: const BorderSide(color: kM3Error)),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// SKELETON LOADING STATE
// ---------------------------------------------------------------------------
class SkeletonTab extends StatelessWidget {
  const SkeletonTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 160, height: 20, color: Colors.white24),
          const SizedBox(height: 16),
          Container(
              width: double.infinity,
              height: 100,
              decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(16))),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(16)))),
              const SizedBox(width: 12),
              Expanded(
                  child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(16)))),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// EMPTY STATE
// ---------------------------------------------------------------------------
class EmptyTab extends StatelessWidget {
  const EmptyTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                  color: kM3Primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle),
              child: const Icon(Icons.inbox, size: 40, color: kM3Primary),
            ),
            const SizedBox(height: 16),
            const Text('لا توجد طلبات جديدة حالياً',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
            const SizedBox(height: 6),
            const Text(
              'جميع طلبات المقاولات والتشطيبات تم التعامل معها وإرسال عروض الأسعار للعملاء.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
