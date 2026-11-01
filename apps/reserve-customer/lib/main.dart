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
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF0F766E);
    const accentTeal = Color(0xFF14B8A6);

    return MaterialApp(
      title: 'محلب الخير - حجز اللبن والطازج',
      scaffoldMessengerKey: _messengerKey,
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      themeMode: _themeMode,
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
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0), width: 0.8),
          ),
          color: Colors.white,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          elevation: 0.5,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF334155), width: 0.8),
          ),
          color: const Color(0xFF1E293B),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E293B),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      home: AuthGate(onThemeToggle: _toggleTheme, isDarkMode: _themeMode == ThemeMode.dark),
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
  final String category;

  ProductItem({
    required this.id,
    required this.name,
    this.description,
    required this.emoji,
    required this.price,
    required this.unit,
    required this.availableQuantity,
    required this.isActive,
    this.category = 'طازج',
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
      category: json['category'] ?? (json['name'].toString().contains('زبادي') ? 'زبادي ورايب' : 'حليب طازج'),
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

class SavedNameEntry {
  final String id;
  final String label; // e.g. "المنزل", "الوالدة", "المكتب"
  final String recipientName;
  final String phone;
  final String address;

  SavedNameEntry({
    required this.id,
    required this.label,
    required this.recipientName,
    required this.phone,
    required this.address,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'recipientName': recipientName,
        'phone': phone,
        'address': address,
      };

  factory SavedNameEntry.fromJson(Map<String, dynamic> json) => SavedNameEntry(
        id: json['id'] ?? '',
        label: json['label'] ?? '',
        recipientName: json['recipientName'] ?? '',
        phone: json['phone'] ?? '',
        address: json['address'] ?? '',
      );
}

class DailySubscription {
  final String id;
  final String productName;
  final String emoji;
  final double quantity;
  final String unit;
  final String slotLabel;
  final String daysSchedule;
  bool isActive;

  DailySubscription({
    required this.id,
    required this.productName,
    required this.emoji,
    required this.quantity,
    required this.unit,
    required this.slotLabel,
    required this.daysSchedule,
    this.isActive = true,
  });
}

// -------------------------------------------------------------
// Auth State Gate
// -------------------------------------------------------------

class AuthGate extends StatefulWidget {
  final Function(bool) onThemeToggle;
  final bool isDarkMode;
  const AuthGate({super.key, required this.onThemeToggle, required this.isDarkMode});

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
      onThemeToggle: widget.onThemeToggle,
      isDarkMode: widget.isDarkMode,
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
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          '🥛',
                          style: TextStyle(fontSize: 48),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
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
                      'حجز اللبن الطازج والمنتجات الطبيعية بكل سهولة وسرعة',
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
                            const Icon(Icons.error_outline, color: Colors.red, size: 20),
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
                        'تسجيل الدخول أو حساب جديد',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'أدخل بريدك الإلكتروني ليصلك رمز التحقق مباشرة',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'البريد الإلكتروني',
                          hintText: 'name@example.com',
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
                            : const Text('إرسال رمز الدخول السري', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ] else ...[
                      Text(
                        'رمز التحقق السري (OTP)',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'أدخل الرمز المكون من 6 أرقام المرسل إلى ${_emailController.text}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 26, letterSpacing: 8, fontWeight: FontWeight.bold),
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
                            : const Text('تأكيد الدخول', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                            child: const Text('تعديل البريد'),
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
// Main Customer Navigation Container
// -------------------------------------------------------------

class MainCustomerScreen extends StatefulWidget {
  final String userId;
  final String userEmail;
  final String token;
  final VoidCallback onLogout;
  final Function(bool) onThemeToggle;
  final bool isDarkMode;

  const MainCustomerScreen({
    super.key,
    required this.userId,
    required this.userEmail,
    required this.token,
    required this.onLogout,
    required this.onThemeToggle,
    required this.isDarkMode,
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
          setState(() => _currentIndex = 1); // Jump to My Orders tab
        },
      ),
      MyOrdersScreen(
        userId: widget.userId,
        token: widget.token,
      ),
      SavedNamesScreen(
        userId: widget.userId,
        token: widget.token,
      ),
      SubscriptionsScreen(
        userId: widget.userId,
        token: widget.token,
        profile: _profile,
        address: _customerAddress,
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
        onThemeToggle: widget.onThemeToggle,
        isDarkMode: widget.isDarkMode,
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
            if (idx == 4) {
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
            const NavigationDestination(
              icon: Icon(Icons.badge_outlined),
              selectedIcon: Icon(Icons.badge),
              label: 'الأسماء',
            ),
            const NavigationDestination(
              icon: Icon(Icons.repeat_outlined),
              selectedIcon: Icon(Icons.repeat),
              label: 'الاشتراكات',
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
  String _searchQuery = '';
  String _selectedCategory = 'الكل';

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
        _error = 'تعذر تحميل بيانات المحلب: $e';
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

  List<ProductItem> get _filteredProducts {
    return _products.where((p) {
      final matchesSearch = p.name.contains(_searchQuery) || (p.description?.contains(_searchQuery) ?? false);
      final matchesCategory = _selectedCategory == 'الكل' || p.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('🥛', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('محلب الخير الطازج', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                Text('منتجات ألبان طازجة يومياً', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ],
            ),
          ],
        ),
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
                      _buildStoreStatusBanner(theme),
                      const SizedBox(height: 16),

                      // Search Bar
                      TextField(
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                        decoration: InputDecoration(
                          hintText: 'ابحث عن لبن، زبادي، جبنة...',
                          prefixIcon: const Icon(Icons.search),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () => setState(() => _searchQuery = ''),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Category Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: ['الكل', 'حليب طازج', 'زبادي ورايب', 'أجبان وقشطة'].map((cat) {
                            final isSelected = _selectedCategory == cat;
                            return Padding(
                              padding: const EdgeInsets.only(left: 8.0),
                              child: ChoiceChip(
                                label: Text(cat),
                                selected: isSelected,
                                onSelected: (sel) {
                                  if (sel) setState(() => _selectedCategory = cat);
                                },
                                selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                                labelStyle: TextStyle(
                                  color: isSelected ? theme.colorScheme.primary : Colors.grey[700],
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 18),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'قائمة منتجات اليوم المتاحة',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${_filteredProducts.length} منتجات',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_filteredProducts.isEmpty)
                        Card(
                          elevation: 0,
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          child: const Padding(
                            padding: EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Text('🥛', style: TextStyle(fontSize: 48)),
                                SizedBox(height: 8),
                                Text('لا توجد منتجات مطابقة للبحث', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _filteredProducts.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final prod = _filteredProducts[index];
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
              isOpen ? Icons.check_circle_outline : Icons.lock_clock,
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
                  isOpen ? 'باب الحجز مفتوح الآن للطلبات' : 'الحجز مقفول حالياً',
                  style: TextStyle(
                    color: isOpen ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  isOpen
                      ? 'يمكنك الآن اختيار نصيبك من اللبن والمنتجات الطازجة'
                      : (_settings?.closedReason?.isNotEmpty == true
                          ? _settings!.closedReason!
                          : 'نعتذر، اكتملت حجوزات اليوم أو المحل مغلق حالياً'),
                  style: TextStyle(
                    color: isOpen ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                    fontSize: 12,
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
      elevation: 0.5,
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
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                      const SizedBox(width: 8),
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
                elevation: 0,
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
// Booking Bottom Sheet (With Saved Names Fast Selection)
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
  String _fulfillmentType = 'delivery';
  String _deliverySlot = 'morning';
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _notesController;
  bool _submitting = false;

  List<SavedNameEntry> _savedNames = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customerName);
    _phoneController = TextEditingController(text: widget.customerPhone);
    _addressController = TextEditingController(text: widget.defaultAddress);
    _notesController = TextEditingController();
    _loadSavedNames();
  }

  Future<void> _loadSavedNames() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('saved_names_list_${widget.userId}');
    if (raw != null) {
      final List decoded = jsonDecode(raw);
      setState(() {
        _savedNames = decoded.map((e) => SavedNameEntry.fromJson(e)).toList();
      });
    }
  }

  void _applySavedName(SavedNameEntry entry) {
    setState(() {
      _nameController.text = entry.recipientName;
      _phoneController.text = entry.phone;
      _addressController.text = entry.address;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم تطبيق بيانات المستلم (${entry.label})'), duration: const Duration(seconds: 1)),
    );
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
        top: 16,
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
                  const SizedBox(width: 12),
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

              // Quantity Selector
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

              // Quick Saved Names Selector
              if (_savedNames.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.badge_outlined, size: 18),
                    const SizedBox(width: 6),
                    const Text('اختيار اسم مستلم مسبق:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _savedNames.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 8.0),
                        child: ActionChip(
                          avatar: const Icon(Icons.person, size: 16),
                          label: Text('${entry.label}: ${entry.recipientName}'),
                          onPressed: () => _applySavedName(entry),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),
              ],

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

              const Text('وقت التسليم والوجبة:', style: TextStyle(fontWeight: FontWeight.bold)),
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

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'اسم صاحب الطلب أو المستلم *', prefixIcon: Icon(Icons.person_outline)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'الاسم مطلوب' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'رقم الهاتف للتواصل *', prefixIcon: Icon(Icons.phone_outlined)),
                validator: (v) => (v == null || v.trim().length < 9) ? 'أدخل رقم هاتف صحيح' : null,
              ),
              const SizedBox(height: 12),

              if (_fulfillmentType == 'delivery') ...[
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'عنوان التوصيل (الحي / الشارع / المنزل) *',
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
                  elevation: 0,
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
// 2. Saved Names & Recipient Directory Screen (شاشة إدارة الأسماء والعناوين)
// -------------------------------------------------------------

class SavedNamesScreen extends StatefulWidget {
  final String userId;
  final String token;

  const SavedNamesScreen({super.key, required this.userId, required this.token});

  @override
  State<SavedNamesScreen> createState() => _SavedNamesScreenState();
}

class _SavedNamesScreenState extends State<SavedNamesScreen> {
  List<SavedNameEntry> _savedNames = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedNames();
  }

  Future<void> _loadSavedNames() async {
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('saved_names_list_${widget.userId}');

    if (raw != null) {
      final List decoded = jsonDecode(raw);
      setState(() {
        _savedNames = decoded.map((e) => SavedNameEntry.fromJson(e)).toList();
        _loading = false;
      });
    } else {
      // Default initial templates if empty
      setState(() {
        _savedNames = [
          SavedNameEntry(
            id: '1',
            label: 'منزلي',
            recipientName: 'الاسم الشخصي',
            phone: '',
            address: 'الحي الرابع - شارع 10',
          ),
        ];
        _loading = false;
      });
      _persist();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(_savedNames.map((e) => e.toJson()).toList());
    await prefs.setString('saved_names_list_${widget.userId}', raw);
  }

  void _showAddOrEditDialog([SavedNameEntry? entry]) {
    final labelCtrl = TextEditingController(text: entry?.label ?? '');
    final nameCtrl = TextEditingController(text: entry?.recipientName ?? '');
    final phoneCtrl = TextEditingController(text: entry?.phone ?? '');
    final addressCtrl = TextEditingController(text: entry?.address ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(entry == null ? 'إضافة اسم/مستلم جديد' : 'تعديل اسم المستلم'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: labelCtrl,
                    decoration: const InputDecoration(
                      labelText: 'المسمى (مثال: البيت، الوالدة، المكتب)',
                      prefixIcon: Icon(Icons.bookmark_border),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'أدخل مسمى توضيحي' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'اسم المستلم الثلاثي *',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'اسم المستلم مطلوب' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'رقم هاتف التواصل *',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (v) => (v == null || v.trim().length < 8) ? 'رقم هاتف صحيح' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: addressCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'عنوان التوصيل التفصيلي *',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'العنوان مطلوب' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                setState(() {
                  if (entry == null) {
                    _savedNames.add(
                      SavedNameEntry(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        label: labelCtrl.text.trim(),
                        recipientName: nameCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        address: addressCtrl.text.trim(),
                      ),
                    );
                  } else {
                    final idx = _savedNames.indexWhere((e) => e.id == entry.id);
                    if (idx != -1) {
                      _savedNames[idx] = SavedNameEntry(
                        id: entry.id,
                        label: labelCtrl.text.trim(),
                        recipientName: nameCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        address: addressCtrl.text.trim(),
                      );
                    }
                  }
                });
                _persist();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(entry == null ? 'تمت إضافة الاسم بنجاح' : 'تم تحديث البيانات')),
                );
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteEntry(SavedNameEntry entry) {
    setState(() {
      _savedNames.removeWhere((e) => e.id == entry.id);
    });
    _persist();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حذف الاسم من القائمة')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('شاشة الأسماء والعناوين المحفوظة', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _showAddOrEditDialog(),
            tooltip: 'إضافة اسم جديد',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Info Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Text('📇', style: TextStyle(fontSize: 34)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'دليل أسماء المستلمين للحجز السريع',
                              style: TextStyle(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'احفظ أسماء وعناوين أهلك وأقاربك أو مواقعك لتسهيل اختيار الاسم مباشرة أثناء حجز اللبن والطازج.',
                              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'الأسماء المحفوظة للطلبات',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showAddOrEditDialog(),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('إضافة اسم'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_savedNames.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          const Icon(Icons.badge_outlined, size: 48, color: Colors.grey),
                          const SizedBox(height: 12),
                          const Text('لا توجد أسماء مضافة بعد', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('اضغط زر إضافة اسم لحفظ مستلم جديد للحجوزات', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _savedNames.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = _savedNames[index];
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
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          item.label,
                                          style: TextStyle(
                                            color: theme.colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        item.recipientName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 20),
                                        onPressed: () => _showAddOrEditDialog(item),
                                        tooltip: 'تعديل',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                        onPressed: () => _deleteEntry(item),
                                        tooltip: 'حذف',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.phone, size: 16, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Text(
                                    item.phone.isNotEmpty ? item.phone : 'لم يتم إدخال رقم هاتف',
                                    style: TextStyle(color: Colors.grey[700], fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      item.address.isNotEmpty ? item.address : 'لم يحدد عنوان',
                                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
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
              ],
            ),
    );
  }
}

// -------------------------------------------------------------
// 3. Subscriptions Screen (Daily Recurring Reservations)
// -------------------------------------------------------------

class SubscriptionsScreen extends StatefulWidget {
  final String userId;
  final String token;
  final Map<String, dynamic> profile;
  final String address;

  const SubscriptionsScreen({
    super.key,
    required this.userId,
    required this.token,
    required this.profile,
    required this.address,
  });

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  final List<DailySubscription> _subscriptions = [
    DailySubscription(
      id: 'sub_1',
      productName: 'حليب طازج (بقر)',
      emoji: '🥛',
      quantity: 2,
      unit: 'رطل',
      slotLabel: 'الفترة الصباحية',
      daysSchedule: 'يومياً (السبت - الجمعة)',
      isActive: true,
    ),
    DailySubscription(
      id: 'sub_2',
      productName: 'زبادي طبيعي',
      emoji: '🥣',
      quantity: 1,
      unit: 'كيلو',
      slotLabel: 'الفترة المسائية',
      daysSchedule: 'الأحد - الثلاثاء - الخميس',
      isActive: false,
    ),
  ];

  void _toggleSubscription(int index) {
    setState(() {
      _subscriptions[index].isActive = !_subscriptions[index].isActive;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _subscriptions[index].isActive
              ? 'تم تفعيل الاشتراك الدوري للمنتج'
              : 'تم إيقاف الاشتراك الدوري مؤقتاً',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _addNewSubscriptionModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NewSubscriptionBottomSheet(
        onAdd: (sub) {
          setState(() {
            _subscriptions.add(sub);
          });
          Navigator.pop(ctx);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إنشاء الاشتراك الدوري بنجاح! سيتم الحجز آلياً كل يوم'),
              backgroundColor: Color(0xFF0F766E),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الاشتراكات اليومية والطلب الدوري', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _addNewSubscriptionModal,
            tooltip: 'اشتراك جديد',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Text('📅', style: TextStyle(fontSize: 36)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'احجز لبنك يومياً آلياً',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'يمكنك تفعيل الاشتراك الدوري ليصلك اللبن والطازج في الموعد المحدد دون الحاجة للدخول يومياً.',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'جدول الاشتراكات النشطة',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: _addNewSubscriptionModal,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('إضافة اشتراك'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_subscriptions.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    const Icon(Icons.repeat, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text('لا يوجد لديك اشتراكات دائرية بعد', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('اضغط زر إضافة اشتراك لطلب اللبن اليومي تلقائياً', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _subscriptions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final sub = _subscriptions[index];
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
                                Text(sub.emoji, style: const TextStyle(fontSize: 28)),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(sub.productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text('${sub.quantity.toInt()} ${sub.unit} - ${sub.slotLabel}', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                  ],
                                ),
                              ],
                            ),
                            Switch(
                              value: sub.isActive,
                              onChanged: (_) => _toggleSubscription(index),
                              activeThumbColor: theme.colorScheme.primary,
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(sub.daysSchedule, style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: sub.isActive ? Colors.green.shade50 : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                sub.isActive ? 'مفعل نشط' : 'متوقف مؤقتاً',
                                style: TextStyle(
                                  color: sub.isActive ? Colors.green.shade800 : Colors.grey.shade700,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
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
        ],
      ),
    );
  }
}

class _NewSubscriptionBottomSheet extends StatefulWidget {
  final Function(DailySubscription) onAdd;
  const _NewSubscriptionBottomSheet({required this.onAdd});

  @override
  State<_NewSubscriptionBottomSheet> createState() => _NewSubscriptionBottomSheetState();
}

class _NewSubscriptionBottomSheetState extends State<_NewSubscriptionBottomSheet> {
  String _selectedProduct = 'حليب طازج (بقر)';
  String _emoji = '🥛';
  double _qty = 2;
  String _slot = 'الفترة الصباحية (6:00 ص)';
  String _schedule = 'يومياً (السبت - الجمعة)';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('إنشاء اشتراك دوري جديد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _selectedProduct,
              decoration: const InputDecoration(labelText: 'اختر المنتج للدوري', prefixIcon: Icon(Icons.local_drink)),
              items: const [
                DropdownMenuItem(value: 'حليب طازج (بقر)', child: Text('🥛 حليب طازج (بقر)')),
                DropdownMenuItem(value: 'حليب جاموسي', child: Text('🥛 حليب جاموسي')),
                DropdownMenuItem(value: 'زبادي طبيعي', child: Text('🥣 زبادي طبيعي')),
                DropdownMenuItem(value: 'لبن رايب', child: Text('🍶 لبن رايب')),
              ],
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedProduct = val;
                    if (val.contains('زبادي')) {
                      _emoji = '🥣';
                    } else if (val.contains('رايب')) {
                      _emoji = '🍶';
                    } else {
                      _emoji = '🥛';
                    }
                  });
                }
              },
            ),
            const SizedBox(height: 14),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('الكمية اليومية:', style: TextStyle(fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                    ),
                    Text('${_qty.toInt()} رطل/كيلو', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => setState(() => _qty++),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            DropdownButtonFormField<String>(
              initialValue: _slot,
              decoration: const InputDecoration(labelText: 'فترة الاستلام اليومي', prefixIcon: Icon(Icons.access_time)),
              items: const [
                DropdownMenuItem(value: 'الفترة الصباحية (6:00 ص)', child: Text('الفترة الصباحية (6:00 ص)')),
                DropdownMenuItem(value: 'الفترة المسائية (5:00 م)', child: Text('الفترة المسائية (5:00 م)')),
              ],
              onChanged: (v) => setState(() => _slot = v!),
            ),
            const SizedBox(height: 14),

            DropdownButtonFormField<String>(
              initialValue: _schedule,
              decoration: const InputDecoration(labelText: 'أيام التكرار', prefixIcon: Icon(Icons.calendar_month)),
              items: const [
                DropdownMenuItem(value: 'يومياً (السبت - الجمعة)', child: Text('يومياً (السبت - الجمعة)')),
                DropdownMenuItem(value: 'الأحد - الثلاثاء - الخميس', child: Text('الأحد - الثلاثاء - الخميس')),
                DropdownMenuItem(value: 'السبت - الإثنين - الأربعاء', child: Text('السبت - الإثنين - الأربعاء')),
              ],
              onChanged: (v) => setState(() => _schedule = v!),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: () {
                widget.onAdd(
                  DailySubscription(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    productName: _selectedProduct,
                    emoji: _emoji,
                    quantity: _qty,
                    unit: _selectedProduct.contains('زبادي') ? 'كيلو' : 'رطل',
                    slotLabel: _slot,
                    daysSchedule: _schedule,
                    isActive: true,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('حفظ وتفعيل الاشتراك', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// 4. Orders Screen (Customer's own bookings)
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
  String _statusFilter = 'الكل';

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() => _loading = true);
    try {
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
        label = 'تم المقابلة والتأكيد';
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

  List<OrderItem> get _filteredOrders {
    if (_statusFilter == 'نشط') {
      return _orders.where((o) => o.status == 'pending' || o.status == 'accepted' || o.status == 'on_the_way' || o.status == 'ready_for_pickup').toList();
    } else if (_statusFilter == 'مكتمل') {
      return _orders.where((o) => o.status == 'delivered').toList();
    } else if (_statusFilter == 'ملغي') {
      return _orders.where((o) => o.status == 'rejected').toList();
    }
    return _orders;
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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['الكل', 'نشط', 'مكتمل', 'ملغي'].map((st) {
                  final selected = _statusFilter == st;
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                      label: Text(st),
                      selected: selected,
                      onSelected: (val) {
                        if (val) setState(() => _statusFilter = st);
                      },
                      selectedColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: selected ? theme.colorScheme.primary : Colors.grey[700],
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredOrders.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
                              const SizedBox(height: 16),
                              const Text('لا توجد حجوزات في هذه القائمة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Text('تصفح شاشة الرئيسية واحجز لبنك في ثوانٍ',
                                  textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchOrders,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredOrders.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final order = _filteredOrders[index];
                            final prod = _productMap[order.productId];
                            final prodName = prod?.name ?? 'منتج ألبان';
                            final prodEmoji = prod?.emoji ?? '🥛';
                            final dateFormatted = order.createdAt.length >= 10 ? order.createdAt.substring(0, 10) : '';

                            return Card(
                              elevation: 0.5,
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
                                    const SizedBox(height: 10),
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
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------
// 5. Notifications / Inbox Screen
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
        title: const Text('الإشعارات والتحديثات', style: TextStyle(fontWeight: FontWeight.bold)),
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
                        Text('ستظهر هنا تحديثات طلباتك وإشعارات المحلب', style: TextStyle(color: Colors.grey[600])),
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
                        elevation: isUnread ? 1 : 0.5,
                        color: isUnread ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.05) : null,
                        child: ListTile(
                          onTap: () => _markAsRead(item),
                          leading: CircleAvatar(
                            backgroundColor: isUnread
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey.shade400,
                            foregroundColor: Colors.white,
                            child: const Icon(Icons.notifications, size: 20),
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
// 6. Customer Profile & Settings Screen
// -------------------------------------------------------------

class ProfileScreen extends StatefulWidget {
  final String userId;
  final String userEmail;
  final String token;
  final Map<String, dynamic> initialProfile;
  final String initialAddress;
  final VoidCallback onProfileUpdated;
  final VoidCallback onLogout;
  final Function(bool) onThemeToggle;
  final bool isDarkMode;

  const ProfileScreen({
    super.key,
    required this.userId,
    required this.userEmail,
    required this.token,
    required this.initialProfile,
    required this.initialAddress,
    required this.onProfileUpdated,
    required this.onLogout,
    required this.onThemeToggle,
    required this.isDarkMode,
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
        content: const Text('هل ترغب بتسجيل الخروج من حسابك؟'),
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
                      radius: 44,
                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                      child: Text(
                        _nameController.text.isNotEmpty ? _nameController.text.characters.first : '🥛',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
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
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('حفظ التعديلات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 24),

              const Divider(),
              const SizedBox(height: 12),

              SwitchListTile(
                title: const Text('المظهر الداكن (Dark Mode)'),
                subtitle: const Text('تغيير ألوان التطبيق للمظهر المظلم'),
                secondary: const Icon(Icons.dark_mode_outlined),
                value: widget.isDarkMode,
                onChanged: (val) => widget.onThemeToggle(val),
              ),
              const SizedBox(height: 20),

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
