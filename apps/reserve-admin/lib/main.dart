import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_config.dart';

// Background FCM message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: firebaseOptions);
}

const String supabaseUrl = 'https://jvjtgzewumfecjdpekna.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp2anRnemV3dW1mZWNqZHBla25hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE2NDYzMzcsImV4cCI6MjEwNzIyMjMzN30.1gck73ek8ErBtcF7xAtFM1TdvNim_1NzFVNej_mptBE';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: firebaseOptions);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('Firebase init error: $e');
  }

  runApp(const DairyAdminApp());
}

class DairyAdminApp extends StatefulWidget {
  const DairyAdminApp({super.key});

  @override
  State<DairyAdminApp> createState() => _DairyAdminAppState();
}

class _DairyAdminAppState extends State<DairyAdminApp> {
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF0F766E);
    const accentTeal = Color(0xFF14B8A6);

    return MaterialApp(
      title: 'محلب الخير - إدارة الحجوزات',
      scaffoldMessengerKey: _messengerKey,
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryGreen,
          primary: primaryGreen,
          secondary: accentTeal,
          surface: const Color(0xFFF8FAFC),
          brightness: Brightness.light,
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: primaryGreen, width: 2),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryGreen,
          primary: accentTeal,
          secondary: const Color(0xFF2DD4BF),
          surface: const Color(0xFF0F172A),
          brightness: Brightness.dark,
        ),
        cardTheme: CardThemeData(
          elevation: 1,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: const Color(0xFF1E293B),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E293B),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: accentTeal, width: 2),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

// -------------------------------------------------------------
// Data Models
// -------------------------------------------------------------

class StoreSettings {
  final int id;
  final bool isBookingOpen;
  final String? closedReason;
  final String morningSlotLabel;
  final String eveningSlotLabel;
  final double deliveryFee;

  StoreSettings({
    required this.id,
    required this.isBookingOpen,
    this.closedReason,
    required this.morningSlotLabel,
    required this.eveningSlotLabel,
    required this.deliveryFee,
  });

  factory StoreSettings.fromJson(Map<String, dynamic> json) {
    return StoreSettings(
      id: json['id'] ?? 1,
      isBookingOpen: json['is_booking_open'] ?? true,
      closedReason: json['closed_reason'],
      morningSlotLabel:
          json['morning_slot_label'] ?? 'الفترة الصباحية (6:00 ص - 9:00 ص)',
      eveningSlotLabel:
          json['evening_slot_label'] ?? 'الفترة المسائية (5:00 م - 8:00 م)',
      deliveryFee: (json['delivery_fee'] is num)
          ? (json['delivery_fee'] as num).toDouble()
          : 0.0,
    );
  }
}

class ProductItem {
  final int id;
  final String name;
  final String? description;
  final String emoji;
  final double price;
  final String unit;
  final double availableQuantity;
  final bool isActive;

  ProductItem({
    required this.id,
    required this.name,
    this.description,
    required this.emoji,
    required this.price,
    required this.unit,
    required this.availableQuantity,
    required this.isActive,
  });

  factory ProductItem.fromJson(Map<String, dynamic> json) {
    return ProductItem(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'],
      emoji: json['emoji'] ?? '🥛',
      price: (json['price'] is num) ? (json['price'] as num).toDouble() : 0.0,
      unit: json['unit'] ?? 'رطل',
      availableQuantity: (json['available_quantity'] is num)
          ? (json['available_quantity'] as num).toDouble()
          : 0.0,
      isActive: json['is_active'] ?? true,
    );
  }
}

class OrderItem {
  final int id;
  final String customerId;
  final int productId;
  final double quantity;
  final double unitPrice;
  final double totalAmount;
  final String fulfillmentType;
  final String deliverySlot;
  final String? deliveryAddress;
  final String customerName;
  final String customerPhone;
  final String? notes;
  final String status;
  final String createdAt;

  OrderItem({
    required this.id,
    required this.customerId,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
    required this.fulfillmentType,
    required this.deliverySlot,
    this.deliveryAddress,
    required this.customerName,
    required this.customerPhone,
    this.notes,
    required this.status,
    required this.createdAt,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'],
      customerId: json['customer_id'] ?? '',
      productId: json['product_id'] ?? 0,
      quantity: (json['quantity'] is num) ? (json['quantity'] as num).toDouble() : 0.0,
      unitPrice: (json['unit_price'] is num) ? (json['unit_price'] as num).toDouble() : 0.0,
      totalAmount: (json['total_amount'] is num) ? (json['total_amount'] as num).toDouble() : 0.0,
      fulfillmentType: json['fulfillment_type'] ?? 'delivery',
      deliverySlot: json['delivery_slot'] ?? 'morning',
      deliveryAddress: json['delivery_address'],
      customerName: json['customer_name'] ?? '',
      customerPhone: json['customer_phone'] ?? '',
      notes: json['notes'],
      status: json['status'] ?? 'pending',
      createdAt: json['created_at'] ?? '',
    );
  }
}

class CustomerProfile {
  final String id;
  final String email;
  final String fullName;
  final String phone;
  final String role;
  final String? address;
  final String? registeredAt;

  CustomerProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.role,
    this.address,
    this.registeredAt,
  });

  factory CustomerProfile.fromJson(Map<String, dynamic> json) {
    return CustomerProfile(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? 'زبون',
      phone: json['phone'] ?? '',
      role: json['role'] ?? 'customer',
      address: json['address'],
      registeredAt: json['registered_at'],
    );
  }
}

class AppNotificationItem {
  final int id;
  final String title;
  final String body;
  final String? readAt;
  final String createdAt;

  AppNotificationItem({
    required this.id,
    required this.title,
    required this.body,
    this.readAt,
    required this.createdAt,
  });

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) {
    return AppNotificationItem(
      id: json['id'],
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      readAt: json['read_at'],
      createdAt: json['created_at'] ?? '',
    );
  }
}

// -------------------------------------------------------------
// Auth Gate
// -------------------------------------------------------------

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _loading = true;
  String? _accessToken;
  String? _userId;
  String? _userEmail;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final refreshToken = prefs.getString('refresh_token');
    final uid = prefs.getString('user_id');
    final email = prefs.getString('user_email');

    if (token != null && uid != null) {
      final valid = await _validateOrRefresh(refreshToken);
      if (valid) {
        final currentToken = prefs.getString('access_token')!;
        final role = await _fetchRole(currentToken, uid);
        setState(() {
          _accessToken = currentToken;
          _userId = uid;
          _userEmail = email;
          _userRole = role;
          _loading = false;
        });
        return;
      }
    }
    setState(() {
      _accessToken = null;
      _userId = null;
      _userEmail = null;
      _userRole = null;
      _loading = false;
    });
  }

  Future<bool> _validateOrRefresh(String? refreshToken) async {
    if (refreshToken == null) return false;
    try {
      final res = await http.post(
        Uri.parse('$supabaseUrl/auth/v1/token?grant_type=refresh_token'),
        headers: {
          'apikey': supabaseAnonKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'refresh_token': refreshToken}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', data['access_token']);
        if (data['refresh_token'] != null) {
          await prefs.setString('refresh_token', data['refresh_token']);
        }
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<String> _fetchRole(String token, String uid) async {
    try {
      final res = await http.get(
        Uri.parse('$supabaseUrl/rest/v1/reserve_profiles?id=eq.$uid'),
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer $token',
        },
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        if (list.isNotEmpty) {
          return list[0]['role'] ?? 'customer';
        }
      }
    } catch (_) {}
    return 'customer';
  }

  void _onLoggedIn(String token, String uid, String email, String role) {
    setState(() {
      _accessToken = token;
      _userId = uid;
      _userEmail = email;
      _userRole = role;
    });
  }

  void _onLoggedOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_id');
    await prefs.remove('user_email');
    setState(() {
      _accessToken = null;
      _userId = null;
      _userEmail = null;
      _userRole = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_accessToken == null || _userId == null) {
      return AdminAuthScreen(onLoginSuccess: _onLoggedIn);
    }

    if (_userRole != 'admin') {
      return NotAdminScreen(onLogout: _onLoggedOut);
    }

    return AdminHomeScreen(
      userId: _userId!,
      userEmail: _userEmail ?? '',
      token: _accessToken!,
      onLogout: _onLoggedOut,
    );
  }
}

// -------------------------------------------------------------
// Auth Screen (Email OTP)
// -------------------------------------------------------------

class AdminAuthScreen extends StatefulWidget {
  final Function(String token, String uid, String email, String role)
      onLoginSuccess;

  const AdminAuthScreen({super.key, required this.onLoginSuccess});

  @override
  State<AdminAuthScreen> createState() => _AdminAuthScreenState();
}

class _AdminAuthScreenState extends State<AdminAuthScreen> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();

  bool _codeSent = false;
  bool _loading = false;
  int _cooldown = 0;
  Timer? _timer;
  String? _errorMessage;

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() => _cooldown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldown <= 1) {
        timer.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'يرجى إدخال بريد إلكتروني صحيح');
      return;
    }
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final res = await http.post(
        Uri.parse('$supabaseUrl/auth/v1/otp'),
        headers: {
          'apikey': supabaseAnonKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'create_user': true,
        }),
      );

      if (res.statusCode == 200 || res.statusCode == 204) {
        setState(() {
          _codeSent = true;
          _loading = false;
        });
        _startTimer();
      } else {
        final err = jsonDecode(res.body);
        setState(() {
          _errorMessage =
              err['error_description'] ?? err['msg'] ?? 'فشل إرسال رمز التحقق';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'تعذر الاتصال بالشبكة: $e';
        _loading = false;
      });
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'أدخل رمز التحقق المكون من 6 أرقام');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();

    try {
      final res = await http.post(
        Uri.parse('$supabaseUrl/auth/v1/verify'),
        headers: {
          'apikey': supabaseAnonKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'type': 'email',
          'email': email,
          'token': code,
        }),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final accessToken = data['access_token'] as String;
        final refreshToken = data['refresh_token'] as String;
        final user = data['user'] as Map<String, dynamic>;
        final uid = user['id'] as String;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', accessToken);
        await prefs.setString('refresh_token', refreshToken);
        await prefs.setString('user_id', uid);
        await prefs.setString('user_email', email);

        // Fetch user profile role
        String role = 'customer';
        final profRes = await http.get(
          Uri.parse('$supabaseUrl/rest/v1/reserve_profiles?id=eq.$uid'),
          headers: {
            'apikey': supabaseAnonKey,
            'Authorization': 'Bearer $accessToken',
          },
        );

        if (profRes.statusCode == 200) {
          final list = jsonDecode(profRes.body) as List;
          if (list.isNotEmpty) {
            role = list[0]['role'] ?? 'customer';
          }
        }

        widget.onLoginSuccess(accessToken, uid, email, role);
      } else {
        final err = jsonDecode(res.body);
        setState(() {
          _errorMessage =
              err['error_description'] ?? err['msg'] ?? 'رمز التحقق غير صحيح';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'خطأ أثناء التحقق: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Text('🥛', style: TextStyle(fontSize: 64)),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'إدارة محلب الخير',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'نظام لوحة التحكم والمتابعة المباشرة للحجوزات',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (!_codeSent) ...[
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'البريد الإلكتروني للآدمن',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _sendOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('إرسال رمز الدخول',
                                  style: TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ] else ...[
                      Text(
                        'تم إرسال رمز الدخول المكون من 6 أرقام إلى بريدك:',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _emailController.text,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 24,
                            letterSpacing: 8,
                            fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          hintText: '000000',
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _verifyOtp,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : const Text('تأكيد الدخول',
                                  style: TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _cooldown > 0 ? null : _sendOtp,
                        child: Text(
                          _cooldown > 0
                              ? 'إعادة الإرسال بعد $_cooldown ثانية'
                              : 'إعادة إرسال الرمز',
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _codeSent = false;
                            _otpController.clear();
                          });
                        },
                        child: const Text('تغيير البريد الإلكتروني'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// Not Admin Screen
// -------------------------------------------------------------

class NotAdminScreen extends StatelessWidget {
  final VoidCallback onLogout;
  const NotAdminScreen({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.gpp_bad_rounded,
                        size: 64, color: Colors.amber),
                    const SizedBox(height: 16),
                    const Text(
                      'هذا الحساب ليس حساب إدارة',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'عفواً، لا تملك الصلاحيات الكافية للوصول إلى تطبيق الإدارة.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: onLogout,
                      icon: const Icon(Icons.logout),
                      label: const Text('تسجيل الخروج'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// Admin Main Screen
// -------------------------------------------------------------

class AdminHomeScreen extends StatefulWidget {
  final String userId;
  final String userEmail;
  final String token;
  final VoidCallback onLogout;

  const AdminHomeScreen({
    super.key,
    required this.userId,
    required this.userEmail,
    required this.token,
    required this.onLogout,
  });

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _currentIndex = 0;
  bool _loading = true;

  StoreSettings? _storeSettings;
  List<ProductItem> _products = [];
  List<OrderItem> _orders = [];
  List<CustomerProfile> _customers = [];
  List<AppNotificationItem> _notifications = [];

  @override
  void initState() {
    super.initState();
    _initPushAndData();
  }

  Future<void> _initPushAndData() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final deviceToken = await messaging.getToken();
      if (deviceToken != null) {
        await http.post(
          Uri.parse('$supabaseUrl/rest/v1/rpc/reserve_register_device'),
          headers: {
            'apikey': supabaseAnonKey,
            'Authorization': 'Bearer ${widget.token}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'device_token': deviceToken,
            'app_name': 'admin',
          }),
        );
      }

      FirebaseMessaging.onMessage.listen((RemoteMessage msg) {
        if (msg.notification != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${msg.notification!.title}: ${msg.notification!.body}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        _fetchAllData();
      });
    } catch (e) {
      debugPrint('Push token error: $e');
    }

    await _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    setState(() => _loading = true);
    await Future.wait([
      _fetchStoreSettings(),
      _fetchProducts(),
      _fetchOrders(),
      _fetchCustomers(),
      _fetchNotifications(),
    ]);
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchStoreSettings() async {
    try {
      final res = await http.get(
        Uri.parse('$supabaseUrl/rest/v1/reserve_store_settings?select=*&limit=1'),
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer ${widget.token}',
        },
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        if (list.isNotEmpty) {
          _storeSettings = StoreSettings.fromJson(list.first);
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchProducts() async {
    try {
      final res = await http.get(
        Uri.parse('$supabaseUrl/rest/v1/reserve_products?select=*&order=id.asc'),
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer ${widget.token}',
        },
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        _products = list.map((e) => ProductItem.fromJson(e)).toList();
      }
    } catch (_) {}
  }

  Future<void> _fetchOrders() async {
    try {
      final res = await http.get(
        Uri.parse('$supabaseUrl/rest/v1/reserve_orders?select=*&order=created_at.desc'),
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer ${widget.token}',
        },
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        _orders = list.map((e) => OrderItem.fromJson(e)).toList();
      }
    } catch (_) {}
  }

  Future<void> _fetchCustomers() async {
    try {
      final res = await http.get(
        Uri.parse('$supabaseUrl/rest/v1/reserve_profiles?select=*&order=full_name.asc'),
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer ${widget.token}',
        },
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        _customers = list.map((e) => CustomerProfile.fromJson(e)).toList();
      }
    } catch (_) {}
  }

  Future<void> _fetchNotifications() async {
    try {
      final res = await http.get(
        Uri.parse(
            '$supabaseUrl/rest/v1/reserve_notifications?to_role=eq.admin&order=created_at.desc'),
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer ${widget.token}',
        },
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        _notifications =
            list.map((e) => AppNotificationItem.fromJson(e)).toList();
      }
    } catch (_) {}
  }

  Future<void> _updateOrderStatus(OrderItem order, String newStatus) async {
    try {
      final res = await http.patch(
        Uri.parse('$supabaseUrl/rest/v1/reserve_orders?id=eq.${order.id}'),
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
          'Prefer': 'return=representation',
        },
        body: jsonEncode({'status': newStatus}),
      );

      if (res.statusCode == 200 || res.statusCode == 204) {
        String title = 'تحديث الطلب';
        String body = 'تم تغيير حالة طلبك رقم #${order.id} إلى $newStatus';

        if (newStatus == 'accepted') {
          title = 'تم قبول طلبك بنجاح';
          body = 'قام المحلب بقبول طلبك وتأكيد حجز اللبن.';
        } else if (newStatus == 'on_the_way') {
          title = 'طلبك في الطريق للتوصيل';
          body = 'الطلب في الطريق إليك الآن.';
        } else if (newStatus == 'ready') {
          title = 'طلبك جاهز للاستلام من المحل';
          body = 'يمكنك زيارة المحلب الآن واستلام حجزك.';
        } else if (newStatus == 'delivered') {
          title = 'تم تسليم الطلب بنجاح';
          body = 'شكراً لتعاملك مع محلب الخير!';
        } else if (newStatus == 'rejected') {
          title = 'تم الاعتذار عن تلبية طلبك';
          body = 'عذراً، تعذر تلبية حجزك في الوقت الحالي.';
        }

        // Notify customer
        await http.post(
          Uri.parse('$supabaseUrl/rest/v1/reserve_notifications'),
          headers: {
            'apikey': supabaseAnonKey,
            'Authorization': 'Bearer ${widget.token}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'to_user': order.customerId,
            'to_role': 'customer',
            'title': title,
            'body': body,
            'data': {'order_id': order.id, 'status': newStatus},
          }),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تحديث حالة الطلب وإرسال التنبيه')),
          );
        }
        _fetchAllData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل التحديث: $e')),
        );
      }
    }
  }

  int get _unreadCount =>
      _notifications.where((n) => n.readAt == null).length;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _currentIndex == 0
                ? 'لوحة التحكم اليومية'
                : _currentIndex == 1
                    ? 'إدارة الطلبات'
                    : _currentIndex == 2
                        ? 'قائمة الزباين'
                        : 'المحل والمنتجات',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          actions: [
            Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => _showNotificationsSheet(context),
                ),
                if (_unreadCount > 0)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$_unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _fetchAllData,
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: widget.onLogout,
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : IndexedStack(
                index: _currentIndex,
                children: [
                  DashboardTab(
                    orders: _orders,
                    products: _products,
                    storeSettings: _storeSettings,
                    customers: _customers,
                    onStatusUpdate: _updateOrderStatus,
                  ),
                  OrdersTab(
                    orders: _orders,
                    products: _products,
                    onStatusUpdate: _updateOrderStatus,
                  ),
                  CustomersTab(
                    customers: _customers,
                    orders: _orders,
                  ),
                  StoreProductsTab(
                    storeSettings: _storeSettings,
                    products: _products,
                    token: widget.token,
                    onRefresh: _fetchAllData,
                  ),
                ],
              ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'الرئيسية',
            ),
            NavigationDestination(
              icon: Icon(Icons.shopping_bag_outlined),
              selectedIcon: Icon(Icons.shopping_bag),
              label: 'الطلبات',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: 'الزباين',
            ),
            NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront),
              label: 'المنتجات',
            ),
          ],
        ),
      ),
    );
  }

  void _showNotificationsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'التنبيهات الواردة',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    )
                  ],
                ),
                const Divider(),
                Expanded(
                  child: _notifications.isEmpty
                      ? const Center(child: Text('لا توجد تنبيهات حالياً'))
                      : ListView.builder(
                          itemCount: _notifications.length,
                          itemBuilder: (c, i) {
                            final n = _notifications[i];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              color: n.readAt == null
                                  ? Colors.teal.shade50
                                  : null,
                              child: ListTile(
                                leading: const Icon(Icons.notifications_active,
                                    color: Color(0xFF0F766E)),
                                title: Text(n.title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                subtitle: Text('${n.body}\n${n.createdAt}'),
                                isThreeLine: true,
                              ),
                            );
                          },
                        ),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}

// -------------------------------------------------------------
// TAB 1: Dashboard
// -------------------------------------------------------------

class DashboardTab extends StatelessWidget {
  final List<OrderItem> orders;
  final List<ProductItem> products;
  final StoreSettings? storeSettings;
  final List<CustomerProfile> customers;
  final Function(OrderItem order, String newStatus) onStatusUpdate;

  const DashboardTab({
    super.key,
    required this.orders,
    required this.products,
    required this.storeSettings,
    required this.customers,
    required this.onStatusUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final pendingOrders = orders.where((o) => o.status == 'pending').toList();
    final todayTotal = orders.fold<double>(0.0, (sum, o) => sum + o.totalAmount);
    final isStoreOpen = storeSettings?.isBookingOpen ?? true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Store Status Banner
          Card(
            color: isStoreOpen ? Colors.teal.shade50 : Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(
                    isStoreOpen ? Icons.store : Icons.store_outlined,
                    color: isStoreOpen ? Colors.teal.shade800 : Colors.red.shade800,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isStoreOpen ? 'المحل مفتوح للطلبات والحجز' : 'المحل مغلق حالياً',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isStoreOpen ? Colors.teal.shade900 : Colors.red.shade900,
                          ),
                        ),
                        if (!isStoreOpen && storeSettings?.closedReason != null)
                          Text(
                            'السبب: ${storeSettings!.closedReason}',
                            style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Overview Grid Cards
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildStatCard(
                context,
                title: 'طلبات اليوم',
                value: '${orders.length}',
                icon: Icons.receipt_long,
                color: Colors.blue,
              ),
              _buildStatCard(
                context,
                title: 'طلبات معلقة',
                value: '${pendingOrders.length}',
                icon: Icons.hourglass_top,
                color: Colors.orange,
              ),
              _buildStatCard(
                context,
                title: 'إجمالي المبيعات',
                value: '${todayTotal.toStringAsFixed(0)} ج.س',
                icon: Icons.payments,
                color: Colors.green,
              ),
              _buildStatCard(
                context,
                title: 'الزباين المسجلين',
                value: '${customers.length}',
                icon: Icons.people,
                color: Colors.purple,
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Pending Requests Quick Actions Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الطلبات المعلقة الجديدة (${pendingOrders.length})',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (pendingOrders.isEmpty)
            Card(
              child: Container(
                padding: const EdgeInsets.all(24),
                width: double.infinity,
                child: Column(
                  children: const [
                    Icon(Icons.check_circle_outline, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('لا توجد طلبات معلقة تنتظر الموافقة',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pendingOrders.length,
              itemBuilder: (ctx, i) {
                final order = pendingOrders[i];
                final product = products.firstWhere(
                  (p) => p.id == order.productId,
                  orElse: () => ProductItem(
                      id: 0,
                      name: 'منتج',
                      emoji: '🥛',
                      price: 0,
                      unit: 'رطل',
                      availableQuantity: 0,
                      isActive: true),
                );

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(product.emoji, style: const TextStyle(fontSize: 24)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    order.customerName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Text(
                                    '${product.name} - ${order.quantity} ${product.unit}',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${order.totalAmount} ج.س',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F766E)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => onStatusUpdate(order, 'rejected'),
                              icon: const Icon(Icons.close, color: Colors.red),
                              label: const Text('رفض', style: TextStyle(color: Colors.red)),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () => onStatusUpdate(order, 'accepted'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F766E),
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.check),
                              label: const Text('قبول الطلب'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// TAB 2: Orders
// -------------------------------------------------------------

class OrdersTab extends StatefulWidget {
  final List<OrderItem> orders;
  final List<ProductItem> products;
  final Function(OrderItem order, String newStatus) onStatusUpdate;

  const OrdersTab({
    super.key,
    required this.orders,
    required this.products,
    required this.onStatusUpdate,
  });

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  String _selectedStatus = 'all';
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final filteredOrders = widget.orders.where((o) {
      final matchesStatus =
          _selectedStatus == 'all' || o.status == _selectedStatus;
      final matchesSearch = o.customerName.contains(_searchQuery) ||
          o.customerPhone.contains(_searchQuery);
      return matchesStatus && matchesSearch;
    }).toList();

    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: const InputDecoration(
              hintText: 'بحث باسم الزبون أو الهاتف...',
              prefixIcon: Icon(Icons.search),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),

        // Filter chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              _buildFilterChip('all', 'الكل'),
              _buildFilterChip('pending', 'قيد الانتظار'),
              _buildFilterChip('accepted', 'مقبولة'),
              _buildFilterChip('on_the_way', 'في الطريق'),
              _buildFilterChip('ready', 'جاهز للاستلام'),
              _buildFilterChip('delivered', 'مكتملة'),
              _buildFilterChip('rejected', 'مرفوضة'),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Orders List
        Expanded(
          child: filteredOrders.isEmpty
              ? const Center(
                  child: Text('لا توجد طلبات تطابق الفلتر المحدد'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filteredOrders.length,
                  itemBuilder: (ctx, i) {
                    final order = filteredOrders[i];
                    final product = widget.products.firstWhere(
                      (p) => p.id == order.productId,
                      orElse: () => ProductItem(
                          id: 0,
                          name: 'منتج',
                          emoji: '🥛',
                          price: 0,
                          unit: 'رطل',
                          availableQuantity: 0,
                          isActive: true),
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'طلب #${order.id}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.grey),
                                ),
                                _buildStatusBadge(order.status),
                              ],
                            ),
                            const Divider(height: 16),
                            Row(
                              children: [
                                Text(product.emoji,
                                    style: const TextStyle(fontSize: 28)),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        order.customerName,
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        '${product.name} - ${order.quantity} ${product.unit}',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                      if (order.deliveryAddress != null &&
                                          order.deliveryAddress!.isNotEmpty)
                                        Text(
                                          'العنوان: ${order.deliveryAddress}',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[700]),
                                        ),
                                    ],
                                  ),
                                ),
                                Text(
                                  '${order.totalAmount} ج.س',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF0F766E)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.phone, color: Colors.blue),
                                  onPressed: () => _callPhone(order.customerPhone),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chat, color: Colors.green),
                                  onPressed: () => _openWhatsApp(order.customerPhone),
                                ),
                                const Spacer(),
                                PopupMenuButton<String>(
                                  onSelected: (val) =>
                                      widget.onStatusUpdate(order, val),
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                        value: 'accepted', child: Text('قبول')),
                                    const PopupMenuItem(
                                        value: 'on_the_way',
                                        child: Text('في الطريق')),
                                    const PopupMenuItem(
                                        value: 'ready',
                                        child: Text('جاهز للاستلام')),
                                    const PopupMenuItem(
                                        value: 'delivered', child: Text('تم التسليم')),
                                    const PopupMenuItem(
                                        value: 'rejected', child: Text('رفض')),
                                  ],
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: const [
                                        Text('تحديث الحالة',
                                            style: TextStyle(fontSize: 13)),
                                        Icon(Icons.arrow_drop_down),
                                      ],
                                    ),
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
    );
  }

  Widget _buildFilterChip(String statusKey, String label) {
    final selected = _selectedStatus == statusKey;
    return Padding(
      padding: const EdgeInsets.only(left: 6.0),
      child: FilterChip(
        selected: selected,
        label: Text(label),
        onSelected: (val) => setState(() => _selectedStatus = statusKey),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = Colors.grey.shade100;
    Color fg = Colors.grey.shade800;
    String label = status;

    switch (status) {
      case 'pending':
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade900;
        label = 'قيد الانتظار';
        break;
      case 'accepted':
        bg = Colors.blue.shade100;
        fg = Colors.blue.shade900;
        label = 'مقبول';
        break;
      case 'on_the_way':
        bg = Colors.purple.shade100;
        fg = Colors.purple.shade900;
        label = 'في الطريق';
        break;
      case 'ready':
        bg = Colors.teal.shade100;
        fg = Colors.teal.shade900;
        label = 'جاهز للاستلام';
        break;
      case 'delivered':
        bg = Colors.green.shade100;
        fg = Colors.green.shade900;
        label = 'تم التسليم';
        break;
      case 'rejected':
        bg = Colors.red.shade100;
        fg = Colors.red.shade900;
        label = 'مرفوض';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  void _callPhone(String phone) async {
    final Uri url = Uri.parse('tel:$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  void _openWhatsApp(String phone) async {
    final Uri url = Uri.parse('https://wa.me/$phone');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}

// -------------------------------------------------------------
// TAB 3: Customers
// -------------------------------------------------------------

class CustomersTab extends StatefulWidget {
  final List<CustomerProfile> customers;
  final List<OrderItem> orders;

  const CustomersTab({
    super.key,
    required this.customers,
    required this.orders,
  });

  @override
  State<CustomersTab> createState() => _CustomersTabState();
}

class _CustomersTabState extends State<CustomersTab> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.customers.where((c) {
      return c.fullName.contains(_search) || c.phone.contains(_search);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: const InputDecoration(
              hintText: 'بحث عن زبون بالإسم أو الهاتف...',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('لا يوجد زباين'))
              : ListView.builder(
                  itemCount: filtered.length,
                  padding: const EdgeInsets.all(12),
                  itemBuilder: (ctx, i) {
                    final cust = filtered[i];
                    final custOrders =
                        widget.orders.where((o) => o.customerId == cust.id).toList();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          child: Text(
                              cust.fullName.isNotEmpty ? cust.fullName[0] : 'ز'),
                        ),
                        title: Text(cust.fullName,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                            'هاتف: ${cust.phone}\nعدد الطلبات: ${custOrders.length}'),
                        isThreeLine: true,
                        trailing: IconButton(
                          icon: const Icon(Icons.info_outline),
                          onPressed: () => _showCustomerDetails(cust, custOrders),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showCustomerDetails(CustomerProfile cust, List<OrderItem> custOrders) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person, size: 28, color: Color(0xFF0F766E)),
                    const SizedBox(width: 8),
                    Text(
                      cust.fullName,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    )
                  ],
                ),
                const Divider(),
                Text('البريد الإلكتروني: ${cust.email}'),
                Text('رقم الهاتف: ${cust.phone}'),
                const SizedBox(height: 12),
                const Text(
                  'سجل الطلبات السابق:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: custOrders.isEmpty
                      ? const Center(child: Text('لا توجد طلبات سابقة لهذا الزبون'))
                      : ListView.builder(
                          itemCount: custOrders.length,
                          itemBuilder: (c, idx) {
                            final o = custOrders[idx];
                            return ListTile(
                              dense: true,
                              title: Text('طلب #${o.id} - ${o.totalAmount} ج.س'),
                              subtitle: Text('الحالة: ${o.status} | التاريخ: ${o.createdAt}'),
                            );
                          },
                        ),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}

// -------------------------------------------------------------
// TAB 4: Store & Products Settings
// -------------------------------------------------------------

class StoreProductsTab extends StatefulWidget {
  final StoreSettings? storeSettings;
  final List<ProductItem> products;
  final String token;
  final VoidCallback onRefresh;

  const StoreProductsTab({
    super.key,
    required this.storeSettings,
    required this.products,
    required this.token,
    required this.onRefresh,
  });

  @override
  State<StoreProductsTab> createState() => _StoreProductsTabState();
}

class _StoreProductsTabState extends State<StoreProductsTab> {
  bool _savingStore = false;

  Future<void> _toggleStoreStatus(bool isOpen) async {
    setState(() => _savingStore = true);
    try {
      final res = await http.patch(
        Uri.parse('$supabaseUrl/rest/v1/reserve_store_settings?id=eq.1'),
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
          'Prefer': 'return=representation',
        },
        body: jsonEncode({'is_booking_open': isOpen}),
      );

      if (res.statusCode == 200 || res.statusCode == 204) {
        widget.onRefresh();
      }
    } catch (_) {}
    setState(() => _savingStore = false);
  }

  Future<void> _updateProductQuantity(ProductItem product, double newQty) async {
    try {
      final res = await http.patch(
        Uri.parse('$supabaseUrl/rest/v1/reserve_products?id=eq.${product.id}'),
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
          'Prefer': 'return=representation',
        },
        body: jsonEncode({'available_quantity': newQty}),
      );

      if (res.statusCode == 200 || res.statusCode == 204) {
        widget.onRefresh();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isOpen = widget.storeSettings?.isBookingOpen ?? true;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Store Switch Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.storefront, size: 36, color: Color(0xFF0F766E)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'حالة استقبال الحجوزات',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          isOpen ? 'المحل يقتبل الطلبات الآن' : 'المحل متوقف عن قبول الحجوزات',
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  _savingStore
                      ? const CircularProgressIndicator()
                      : Switch(
                          value: isOpen,
                          onChanged: _toggleStoreStatus,
                        ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Products Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text(
                'المنتجات والكميات المتاحة',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.products.length,
            itemBuilder: (ctx, i) {
              final prod = widget.products[i];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Text(prod.emoji, style: const TextStyle(fontSize: 32)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              prod.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              'السعر: ${prod.price} ج.س / ${prod.unit}',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'المتاح: ${prod.availableQuantity} ${prod.unit}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F766E)),
                          ),
                          const SizedBox(height: 4),
                          OutlinedButton.icon(
                            onPressed: () => _showEditQtyDialog(prod),
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('تعديل المخزون'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          )
        ],
      ),
    );
  }

  void _showEditQtyDialog(ProductItem prod) {
    final controller = TextEditingController(text: '${prod.availableQuantity}');
    showDialog(
      context: context,
      builder: (ctx) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text('تحديث كمية ${prod.name}'),
            content: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'الكمية المتاحة بـ (${prod.unit})',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () {
                  final val = double.tryParse(controller.text.trim()) ?? 0.0;
                  Navigator.pop(ctx);
                  _updateProductQuantity(prod, val);
                },
                child: const Text('حفظ'),
              )
            ],
          ),
        );
      },
    );
  }
}
