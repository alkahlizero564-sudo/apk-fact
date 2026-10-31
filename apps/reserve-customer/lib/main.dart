import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_config.dart';

// Background message handler
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

  runApp(const DairyCustomerApp());
}

class DairyCustomerApp extends StatefulWidget {
  const DairyCustomerApp({super.key});

  @override
  State<DairyCustomerApp> createState() => _DairyCustomerAppState();
}

class _DairyCustomerAppState extends State<DairyCustomerApp> {
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF0F766E);
    const accentTeal = Color(0xFF14B8A6);

    return MaterialApp(
      title: 'محلب الخير - حجز اللبن',
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
// Models
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
      morningSlotLabel: json['morning_slot_label'] ?? 'الفترة الصباحية (6:00 ص - 9:00 ص)',
      eveningSlotLabel: json['evening_slot_label'] ?? 'الفترة المسائية (5:00 م - 8:00 م)',
      deliveryFee: (json['delivery_fee'] is num) ? (json['delivery_fee'] as num).toDouble() : 0.0,
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
// Auth State Gate
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
      // Validate or refresh session
      final valid = await _validateOrRefresh(refreshToken);
      if (valid) {
        setState(() {
          _accessToken = prefs.getString('access_token');
          _userId = uid;
          _userEmail = email;
          _loading = false;
        });
        return;
      }
    }
    setState(() {
      _accessToken = null;
      _userId = null;
      _userEmail = null;
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

  void _onLoggedIn(String token, String uid, String email) {
    setState(() {
      _accessToken = token;
      _userId = uid;
      _userEmail = email;
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
      return AuthScreen(onLoginSuccess: _onLoggedIn);
    }

    return MainCustomerScreen(
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

class AuthScreen extends StatefulWidget {
  final Function(String token, String uid, String email) onLoginSuccess;
  const AuthScreen({super.key, required this.onLoginSuccess});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
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
          _errorMessage = err['error_description'] ?? err['msg'] ?? 'فشل إرسال رمز التحقق';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ في الاتصال بالإنترنت: $e';
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

        // Ensure customer details entry exists
        await _checkAndCreateCustomerRow(accessToken, uid, email);

        widget.onLoginSuccess(accessToken, uid, email);
      } else {
        final err = jsonDecode(res.body);
        setState(() {
          _errorMessage = err['error_description'] ?? err['msg'] ?? 'رمز التحقق غير صحيح أو انتهى';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'حدث خطأ أثناء التحقق: $e';
        _loading = false;
      });
    }
  }

  Future<void> _checkAndCreateCustomerRow(String token, String uid, String email) async {
    try {
      // 1. Check or insert profile
      final profileRes = await http.get(
        Uri.parse('$supabaseUrl/rest/v1/reserve_profiles?id=eq.$uid'),
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer $token',
        },
      );
      if (profileRes.statusCode == 200) {
        final list = jsonDecode(profileRes.body) as List;
        if (list.isEmpty) {
          await http.post(
            Uri.parse('$supabaseUrl/rest/v1/reserve_profiles'),
            headers: {
              'apikey': supabaseAnonKey,
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Prefer': 'return=representation',
            },
            body: jsonEncode({
              'id': uid,
              'email': email,
              'role': 'customer',
              'full_name': 'زبون جديد',
              'phone': '',
            }),
          );
        }
      }

      // 2. Customer details check
      final detRes = await http.get(
        Uri.parse('$supabaseUrl/rest/v1/reserve_customer_details?customer_id=eq.$uid'),
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer $token',
        },
      );
      if (detRes.statusCode == 200) {
        final dList = jsonDecode(detRes.body) as List;
        if (dList.isEmpty) {
          await http.post(
            Uri.parse('$supabaseUrl/rest/v1/reserve_customer_details'),
            headers: {
              'apikey': supabaseAnonKey,
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
              'Prefer': 'return=representation',
            },
            body: jsonEncode({
              'customer_id': uid,
              'address': '',
            }),
          );
        }
      }
    } catch (_) {}
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
                    const Center(
                      child: Text(
                        '🥛',
                        style: TextStyle(fontSize: 72),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'محلب الخير',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'حجز منتجات الألبان الطبيعية بكل سهولة وسرعة',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 36),

                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),

                    if (!_codeSent) ...[
                      Text(
                        'الدخول بواسطة البريد الإلكتروني',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'سنرسل رمز تحقق سري من 6 أرقام إلى بريدك الإلكتروني',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'البريد الإلكتروني',
                          hintText: 'example@email.com',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _loading ? null : _sendOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('إرسال رمز الدخول', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ] else ...[
                      Text(
                        'أدخل رمز التحقق (OTP)',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'تم إرسال رمز التحقق إلى ${_emailController.text}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          hintText: '------',
                          counterText: '',
                          prefixIcon: Icon(Icons.lock_clock_outlined),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _loading ? null : _verifyOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('تأكيد وتسجيل الدخول', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: _cooldown > 0 || _loading ? null : _sendOtp,
                            child: Text(
                              _cooldown > 0 ? 'إعادة الإرسال بعد ($_cooldown ث)' : 'إعادة إرسال الرمز',
                              style: TextStyle(
                                color: _cooldown > 0 ? Colors.grey : theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _codeSent = false;
                                _errorMessage = null;
                                _otpController.clear();
                              });
                            },
                            child: const Text('تغيير البريد'),
                          ),
                        ],
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
// Main Frame: Customer Screen (Home, My Orders, Inbox, Profile)
// -------------------------------------------------------------

class MainCustomerScreen extends StatefulWidget {
  final String userId;
  final String userEmail;
  final String token;
  final VoidCallback onLogout;

  const MainCustomerScreen({
    super.key,
    required this.userId,
    required this.userEmail,
    required this.token,
    required this.onLogout,
  });

  @override
  State<MainCustomerScreen> createState() => _MainCustomerScreenState();
}

class _MainCustomerScreenState extends State<MainCustomerScreen> {
  int _currentIndex = 0;
  int _unreadNotifications = 0;
  Map<String, dynamic> _profile = {};
  String _customerAddress = '';

  @override
  void initState() {
    super.initState();
    _initDeviceAndPush();
    _loadProfileData();
    _loadUnreadCount();
  }

  Future<void> _initDeviceAndPush() async {
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
            'app_name': 'customer',
          }),
        );
      }

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${message.notification?.title ?? "إشعار جديد"}: ${message.notification?.body ?? ""}'),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadUnreadCount();
      });
    } catch (_) {}
  }

  Future<void> _loadProfileData() async {
    try {
      final pRes = await http.get(
        Uri.parse('$supabaseUrl/rest/v1/reserve_profiles?id=eq.${widget.userId}'),
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer ${widget.token}',
        },
      );
      if (pRes.statusCode == 200) {
        final list = jsonDecode(pRes.body) as List;
        if (list.isNotEmpty) {
          setState(() => _profile = list.first);
        }
      }

      final dRes = await http.get(
        Uri.parse('$supabaseUrl/rest/v1/reserve_customer_details?customer_id=eq.${widget.userId}'),
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer ${widget.token}',
        },
      );
      if (dRes.statusCode == 200) {
        final list = jsonDecode(dRes.body) as List;
        if (list.isNotEmpty) {
          setState(() => _customerAddress = list.first['address'] ?? '');
        }
      }
    } catch (_) {}
  }

  Future<void> _loadUnreadCount() async {
    try {
      final res = await http.get(
        Uri.parse(
          '$supabaseUrl/rest/v1/reserve_notifications?or=(to_user.eq.${widget.userId},to_role.eq.customer)&read_at=is.null',
        ),
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer ${widget.token}',
        },
      );
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        setState(() => _unreadNotifications = list.length);
      }
    } catch (_) {}
  }

  void _onNotificationRead() {
    _loadUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        userId: widget.userId,
        token: widget.token,
        profile: _profile,
        address: _customerAddress,
        onOrderCreated: () {
          setState(() => _currentIndex = 1);
        },
      ),
      MyOrdersScreen(
        userId: widget.userId,
        token: widget.token,
      ),
      InboxScreen(
        userId: widget.userId,
        token: widget.token,
        onReadStatusChange: _onNotificationRead,
      ),
      ProfileScreen(
        userId: widget.userId,
        userEmail: widget.userEmail,
        token: widget.token,
        initialProfile: _profile,
        initialAddress: _customerAddress,
        onProfileUpdated: () {
          _loadProfileData();
        },
        onLogout: widget.onLogout,
      ),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: screens,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (idx) {
            setState(() => _currentIndex = idx);
            if (idx == 2) {
              _loadUnreadCount();
            }
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.storefront_outlined),
              selectedIcon: Icon(Icons.storefront),
              label: 'الرئيسية',
            ),
            const NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'حجوزاتي',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: _unreadNotifications > 0,
                label: Text('$_unreadNotifications'),
                child: const Icon(Icons.notifications_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: _unreadNotifications > 0,
                label: Text('$_unreadNotifications'),
                child: const Icon(Icons.notifications),
              ),
              label: 'الإشعارات',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'حسابي',
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 1. Home Screen (Store Status, Products list, Booking bottom-sheet)
// -------------------------------------------------------------

class HomeScreen extends StatefulWidget {
  final String userId;
  final String token;
  final Map<String, dynamic> profile;
  final String address;
  final VoidCallback onOrderCreated;

  const HomeScreen({
    super.key,
    required this.userId,
    required this.token,
    required this.profile,
    required this.address,
    required this.onOrderCreated,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StoreSettings? _settings;
  List<ProductItem> _products = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchStoreData();
  }

  Future<void> _fetchStoreData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1. Store settings
      final sRes = await http.get(
        Uri.parse('$supabaseUrl/rest/v1/reserve_store_settings?select=*&limit=1'),
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      StoreSettings? settings;
      if (sRes.statusCode == 200) {
        final list = jsonDecode(sRes.body) as List;
        if (list.isNotEmpty) {
          settings = StoreSettings.fromJson(list.first);
        }
      }

      // 2. Products
      final pRes = await http.get(
        Uri.parse('$supabaseUrl/rest/v1/reserve_products?select=*&is_active=eq.true&order=id.asc'),
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      List<ProductItem> products = [];
      if (pRes.statusCode == 200) {
        final list = jsonDecode(pRes.body) as List;
        products = list.map((e) => ProductItem.fromJson(e)).toList();
      }

      setState(() {
        _settings = settings ??
            StoreSettings(
              id: 1,
              isBookingOpen: true,
              morningSlotLabel: 'الفترة الصباحية (6:00 ص - 9:00 ص)',
              eveningSlotLabel: 'الفترة المسائية (5:00 م - 8:00 م)',
              deliveryFee: 0,
            );
        _products = products;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'تعذر تحميل بيانات المتجر: $e';
        _loading = false;
      });
    }
  }

  void _showBookingDialog(ProductItem product) {
    if (_settings?.isBookingOpen != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_settings?.closedReason ?? 'الحجز مقفول حالياً في المحل'),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    if (product.availableQuantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('عذراً، هذا المنتج غير متوفر بالكمية الكافية اليوم'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BookingBottomSheet(
        product: product,
        settings: _settings!,
        userId: widget.userId,
        token: widget.token,
        customerName: widget.profile['full_name'] ?? 'الزبون',
        customerPhone: widget.profile['phone'] ?? '',
        defaultAddress: widget.address,
        onSuccess: () {
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تأكيد حجزك بنجاح! سيصلك إشعار بالرد قريباً'),
              backgroundColor: Color(0xFF0F766E),
            ),
          );
          _fetchStoreData();
          widget.onOrderCreated();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('محلب الخير - المنتجات الطازجة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchStoreData,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _fetchStoreData, child: const Text('إعادة المحاولة')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchStoreData,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    children: [
                      // Store banner
                      _buildStoreStatusBanner(theme),
                      const SizedBox(height: 16),

                      Text(
                        'قائمة الحجز المتاحة اليوم',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),

                      if (_products.isEmpty)
                        Card(
                          elevation: 0,
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          child: const Padding(
                            padding: EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Text('🥛', style: TextStyle(fontSize: 48)),
                                SizedBox(height: 8),
                                Text('لا توجد منتجات معروضة للحجز حالياً', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _products.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final prod = _products[index];
                            return _buildProductCard(theme, prod);
                          },
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStoreStatusBanner(ThemeData theme) {
    final isOpen = _settings?.isBookingOpen ?? true;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOpen ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOpen ? const Color(0xFFA7F3D0) : const Color(0xFFFECACA),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isOpen ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOpen ? Icons.check_circle : Icons.lock_clock,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOpen ? 'باب الحجز مفتوح الآن للطلبات' : 'الحجز مقفول مؤقتاً',
                  style: TextStyle(
                    color: isOpen ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isOpen
                      ? 'يمكنك حجز نصيبك من اللبن الطازج ومنتجات الألبان'
                      : (_settings?.closedReason?.isNotEmpty == true
                          ? _settings!.closedReason!
                          : 'نعتذر، اكتملت حجوزات اليوم أو المحل مغلق حالياً'),
                  style: TextStyle(
                    color: isOpen ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(ThemeData theme, ProductItem prod) {
    final isAvailable = prod.availableQuantity > 0 && (_settings?.isBookingOpen ?? true);

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                child: Text(
                  prod.emoji.isNotEmpty ? prod.emoji : '🥛',
                  style: const TextStyle(fontSize: 32),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prod.name,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  if (prod.description != null && prod.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        prod.description!,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '${prod.price.toStringAsFixed(0)} ج.س / ${prod.unit}',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: prod.availableQuantity > 0 ? Colors.green.shade50 : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          prod.availableQuantity > 0
                              ? 'متاح: ${prod.availableQuantity.toStringAsFixed(0)} ${prod.unit}'
                              : 'نفدت الكمية',
                          style: TextStyle(
                            color: prod.availableQuantity > 0 ? Colors.green.shade800 : Colors.red.shade800,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: isAvailable ? () => _showBookingDialog(prod) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              child: const Text('احجز', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// Booking Bottom Sheet
// -------------------------------------------------------------

class BookingBottomSheet extends StatefulWidget {
  final ProductItem product;
  final StoreSettings settings;
  final String userId;
  final String token;
  final String customerName;
  final String customerPhone;
  final String defaultAddress;
  final VoidCallback onSuccess;

  const BookingBottomSheet({
    super.key,
    required this.product,
    required this.settings,
    required this.userId,
    required this.token,
    required this.customerName,
    required this.customerPhone,
    required this.defaultAddress,
    required this.onSuccess,
  });

  @override
  State<BookingBottomSheet> createState() => _BookingBottomSheetState();
}

class _BookingBottomSheetState extends State<BookingBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  double _quantity = 1.0;
  String _fulfillmentType = 'delivery'; // delivery or pickup
  String _deliverySlot = 'morning'; // morning or evening
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _notesController;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customerName);
    _phoneController = TextEditingController(text: widget.customerPhone);
    _addressController = TextEditingController(text: widget.defaultAddress);
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double get _totalPrice {
    final subtotal = widget.product.price * _quantity;
    final delivery = (_fulfillmentType == 'delivery') ? widget.settings.deliveryFee : 0.0;
    return subtotal + delivery;
  }

  Future<void> _submitOrder() async {
    if (!_formKey.currentState!.validate()) return;

    if (_quantity > widget.product.availableQuantity) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('الكمية المطلوبة أكبر من المتاح (${widget.product.availableQuantity})')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final orderData = {
        'customer_id': widget.userId,
        'product_id': widget.product.id,
        'quantity': _quantity,
        'unit_price': widget.product.price,
        'total_amount': _totalPrice,
        'fulfillment_type': _fulfillmentType,
        'delivery_slot': _deliverySlot,
        'delivery_address': _fulfillmentType == 'delivery' ? _addressController.text.trim() : 'استلام من المحل',
        'customer_name': _nameController.text.trim(),
        'customer_phone': _phoneController.text.trim(),
        'notes': _notesController.text.trim(),
        'status': 'pending',
      };

      final res = await http.post(
        Uri.parse('$supabaseUrl/rest/v1/reserve_orders'),
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
          'Prefer': 'return=representation',
        },
        body: jsonEncode(orderData),
      );

      if (res.statusCode == 201 || res.statusCode == 200) {
        final inserted = (jsonDecode(res.body) as List).first;
        final orderId = inserted['id'];

        // Send notification to admin
        await http.post(
          Uri.parse('$supabaseUrl/rest/v1/reserve_notifications'),
          headers: {
            'apikey': supabaseAnonKey,
            'Authorization': 'Bearer ${widget.token}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'to_role': 'admin',
            'title': 'حجز جديد وارد',
            'body': 'طلب جديد من ${_nameController.text.trim()} للمنتج ${widget.product.name} بمقدار $_quantity ${widget.product.unit}',
            'data': {'order_id': orderId, 'product_id': widget.product.id},
          }),
        );

        // Update profile phone & address if updated
        await _syncProfile();

        widget.onSuccess();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ في إنشاء الحجز: ${res.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في الاتصال: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _syncProfile() async {
    try {
      await http.patch(
        Uri.parse('$supabaseUrl/rest/v1/reserve_profiles?id=eq.${widget.userId}'),
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'full_name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
        }),
      );

      if (_fulfillmentType == 'delivery' && _addressController.text.isNotEmpty) {
        await http.patch(
          Uri.parse('$supabaseUrl/rest/v1/reserve_customer_details?customer_id=eq.${widget.userId}'),
          headers: {
            'apikey': supabaseAnonKey,
            'Authorization': 'Bearer ${widget.token}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'address': _addressController.text.trim(),
          }),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(widget.product.emoji, style: const TextStyle(fontSize: 32)),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('حجز ${widget.product.name}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('${widget.product.price.toStringAsFixed(0)} ج.س لكل ${widget.product.unit}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),

              // Quantity counter
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('الكمية المطلوبة:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: _quantity > 1 ? () => setState(() => _quantity -= 1) : null,
                        ),
                        Text(
                          '${_quantity.toInt()} ${widget.product.unit}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _quantity < widget.product.availableQuantity
                              ? () => setState(() => _quantity += 1)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Fulfillment Type (Delivery / Pickup)
              const Text('طريقة الاستلام:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'delivery', label: Text('توصيل للعنوان'), icon: Icon(Icons.delivery_dining)),
                  ButtonSegment(value: 'pickup', label: Text('استلام من المحل'), icon: Icon(Icons.storefront)),
                ],
                selected: {_fulfillmentType},
                onSelectionChanged: (set) => setState(() => _fulfillmentType = set.first),
              ),
              const SizedBox(height: 16),

              // Delivery Slot
              const Text('وقت الاستلام أو التوصيل:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'morning', label: Text(widget.settings.morningSlotLabel)),
                  ButtonSegment(value: 'evening', label: Text(widget.settings.eveningSlotLabel)),
                ],
                selected: {_deliverySlot},
                onSelectionChanged: (set) => setState(() => _deliverySlot = set.first),
              ),
              const SizedBox(height: 16),

              // Inputs
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'الاسم الكامل *', prefixIcon: Icon(Icons.person_outline)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'رقم الهاتف *', prefixIcon: Icon(Icons.phone_outlined)),
                validator: (v) => (v == null || v.trim().length < 9) ? 'أدخل رقم هاتف صحيح' : null,
              ),
              const SizedBox(height: 12),

              if (_fulfillmentType == 'delivery') ...[
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'عنوان التوصيل بالتفصيل (الحي / الشارع / المنزل) *',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  validator: (v) => (_fulfillmentType == 'delivery' && (v == null || v.trim().isEmpty))
                      ? 'العنوان مطلوب للتوصيل'
                      : null,
                ),
                const SizedBox(height: 12),
              ],

              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'ملاحظة للمحل (اختياري)', prefixIcon: Icon(Icons.notes)),
              ),
              const SizedBox(height: 20),

              // Price Breakdown
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('المبلغ الإجمالي:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                      '${_totalPrice.toStringAsFixed(0)} ج.س',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: _submitting ? null : _submitOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('تأكيد الحجز الآن', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 2. Orders Screen (Customer's own bookings)
// -------------------------------------------------------------

class MyOrdersScreen extends StatefulWidget {
  final String userId;
  final String token;

  const MyOrdersScreen({super.key, required this.userId, required this.token});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  List<OrderItem> _orders = [];
  Map<int, ProductItem> _productMap = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() => _loading = true);
    try {
      // Products for names
      final pRes = await http.get(
        Uri.parse('$supabaseUrl/rest/v1/reserve_products?select=*'),
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer ${widget.token}',
        },
      );
      if (pRes.statusCode == 200) {
        final pList = jsonDecode(pRes.body) as List;
        _productMap = {for (var item in pList) item['id']: ProductItem.fromJson(item)};
      }

      // Customer orders
      final res = await http.get(
        Uri.parse('$supabaseUrl/rest/v1/reserve_orders?customer_id=eq.${widget.userId}&order=created_at.desc'),
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        setState(() {
          _orders = list.map((e) => OrderItem.fromJson(e)).toList();
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _cancelOrder(OrderItem order) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء الحجز'),
        content: const Text('هل أنت متأكد من رغبتك في إلغاء هذا الطلب؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('رجوع')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('نعم، إلغاء'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await http.patch(
        Uri.parse('$supabaseUrl/rest/v1/reserve_orders?id=eq.${order.id}'),
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'status': 'rejected'}),
      );

      if (res.statusCode == 200 || res.statusCode == 204) {
        // Notify admin about cancellation
        await http.post(
          Uri.parse('$supabaseUrl/rest/v1/reserve_notifications'),
          headers: {
            'apikey': supabaseAnonKey,
            'Authorization': 'Bearer ${widget.token}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'to_role': 'admin',
            'title': 'تم إلغاء حجز من قبل الزبون',
            'body': 'قام الزبون ${order.customerName} بإلغاء طلبه رقم #${order.id}',
            'data': {'order_id': order.id},
          }),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إلغاء الحجز بنجاح')),
        );
        _fetchOrders();
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر إلغاء الحجز، حاول ثانية')),
      );
    }
  }

  Widget _getStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'pending':
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade900;
        label = 'قيد الانتظار';
        break;
      case 'accepted':
        bg = Colors.blue.shade100;
        fg = Colors.blue.shade900;
        label = 'تم القبول';
        break;
      case 'on_the_way':
        bg = Colors.purple.shade100;
        fg = Colors.purple.shade900;
        label = 'في الطريق للتوصيل';
        break;
      case 'ready_for_pickup':
        bg = Colors.teal.shade100;
        fg = Colors.teal.shade900;
        label = 'جاهز للاستلام';
        break;
      case 'delivered':
        bg = Colors.green.shade100;
        fg = Colors.green.shade900;
        label = 'تم التسليم بنجاح';
        break;
      case 'rejected':
      default:
        bg = Colors.red.shade100;
        fg = Colors.red.shade900;
        label = 'مرفوض / ملغي';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('حجوزاتي وطلباتي', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchOrders,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text('لا توجد لديك حجوزات حتى الآن', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('ابدأ باختيار منتج طازج من شاشة المنتجات واحجزه بكل بساطة',
                            textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchOrders,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _orders.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final order = _orders[index];
                      final prod = _productMap[order.productId];
                      final prodName = prod?.name ?? 'منتج ألبان';
                      final prodEmoji = prod?.emoji ?? '🥛';
                      final dateFormatted = order.createdAt.length >= 10 ? order.createdAt.substring(0, 10) : '';

                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(prodEmoji, style: const TextStyle(fontSize: 24)),
                                      const SizedBox(width: 8),
                                      Text(
                                        'طلب #00${order.id}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ],
                                  ),
                                  _getStatusBadge(order.status),
                                ],
                              ),
                              const Divider(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '$prodName (${order.quantity.toStringAsFixed(0)} ${prod?.unit ?? "وحدة"})',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    '${order.totalAmount.toStringAsFixed(0)} ج.س',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    order.fulfillmentType == 'delivery' ? Icons.delivery_dining : Icons.store,
                                    size: 16,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    order.fulfillmentType == 'delivery' ? 'توصيل للعنوان' : 'استلام من المحل',
                                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                  ),
                                  const SizedBox(width: 14),
                                  Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                                  const SizedBox(width: 6),
                                  Text(
                                    order.deliverySlot == 'morning' ? 'صباحاً' : 'مساءً',
                                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                  ),
                                ],
                              ),
                              if (order.fulfillmentType == 'delivery' && order.deliveryAddress != null) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[600]),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        order.deliveryAddress!,
                                        style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    dateFormatted,
                                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                  ),
                                  if (order.status == 'pending')
                                    OutlinedButton(
                                      onPressed: () => _cancelOrder(order),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red,
                                        side: const BorderSide(color: Colors.red),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                                        minimumSize: const Size(60, 32),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: const Text('إلغاء الحجز', style: TextStyle(fontSize: 12)),
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
    );
  }
}

// -------------------------------------------------------------
// 3. Notifications / Inbox Screen
// -------------------------------------------------------------

class InboxScreen extends StatefulWidget {
  final String userId;
  final String token;
  final VoidCallback onReadStatusChange;

  const InboxScreen({
    super.key,
    required this.userId,
    required this.token,
    required this.onReadStatusChange,
  });

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  List<AppNotificationItem> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse(
          '$supabaseUrl/rest/v1/reserve_notifications?or=(to_user.eq.${widget.userId},to_role.eq.customer)&order=created_at.desc',
        ),
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        setState(() {
          _notifications = list.map((e) => AppNotificationItem.fromJson(e)).toList();
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _markAsRead(AppNotificationItem item) async {
    if (item.readAt != null) return;
    try {
      await http.patch(
        Uri.parse('$supabaseUrl/rest/v1/reserve_notifications?id=eq.${item.id}'),
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'read_at': DateTime.now().toIso8601String()}),
      );
      widget.onReadStatusChange();
      _fetchNotifications();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات الواردة', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchNotifications),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text('صندوق الإشعارات فارغ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text('ستظهر هنا تحديثات طلباتك من المحل', style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchNotifications,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final item = _notifications[index];
                      final isUnread = item.readAt == null;

                      return Card(
                        elevation: isUnread ? 2 : 0,
                        color: isUnread ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.05) : null,
                        child: ListTile(
                          onTap: () => _markAsRead(item),
                          leading: CircleAvatar(
                            backgroundColor: isUnread
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.shade400,
                            foregroundColor: Colors.white,
                            child: const Icon(Icons.notifications),
                          ),
                          title: Text(
                            item.title,
                            style: TextStyle(
                              fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(item.body, style: const TextStyle(fontSize: 13)),
                              const SizedBox(height: 6),
                              Text(
                                item.createdAt.length >= 16 ? item.createdAt.substring(0, 16).replaceAll('T', ' ') : '',
                                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                              ),
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

// -------------------------------------------------------------
// 4. Customer Profile Screen
// -------------------------------------------------------------

class ProfileScreen extends StatefulWidget {
  final String userId;
  final String userEmail;
  final String token;
  final Map<String, dynamic> initialProfile;
  final String initialAddress;
  final VoidCallback onProfileUpdated;
  final VoidCallback onLogout;

  const ProfileScreen({
    super.key,
    required this.userId,
    required this.userEmail,
    required this.token,
    required this.initialProfile,
    required this.initialAddress,
    required this.onProfileUpdated,
    required this.onLogout,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialProfile['full_name'] ?? '');
    _phoneController = TextEditingController(text: widget.initialProfile['phone'] ?? '');
    _addressController = TextEditingController(text: widget.initialAddress);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      // 1. Update Profile
      await http.patch(
        Uri.parse('$supabaseUrl/rest/v1/reserve_profiles?id=eq.${widget.userId}'),
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'full_name': _nameController.text.trim(),
          'phone': _phoneController.text.trim(),
        }),
      );

      // 2. Update or insert details
      await http.patch(
        Uri.parse('$supabaseUrl/rest/v1/reserve_customer_details?customer_id=eq.${widget.userId}'),
        headers: {
          'apikey': supabaseAnonKey,
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'address': _addressController.text.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        }),
      );

      widget.onProfileUpdated();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ بيانات الحساب بنجاح'),
          backgroundColor: Color(0xFF0F766E),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر الحفظ: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل ترغب بتسجيل الخروج من الحساب؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              widget.onLogout();
            },
            child: const Text('خروج'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('حسابي وبيانات التوصيل', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 46,
                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                      child: Text(
                        _nameController.text.isNotEmpty ? _nameController.text.characters.first : '🥛',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.userEmail,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 24),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'الاسم الكامل',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى كتابة الاسم' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'رقم الهاتف',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (v) => (v == null || v.trim().length < 9) ? 'رقم الهاتف غير صالح' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _addressController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'العنوان الافتراضي للتوصيل (الحي ورقم المنزل)',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'يرجى كتابة العنوان' : null,
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _saving ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('حفظ التعديلات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 28),

              OutlinedButton.icon(
                onPressed: _confirmLogout,
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
