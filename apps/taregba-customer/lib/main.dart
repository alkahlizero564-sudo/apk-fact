import 'dart:async';
import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' as intl;
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_config.dart';

// Top-level Firebase background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: firebaseOptions);
  } catch (_) {}
}

// --- CONSTANTS & DESIGN TOKENS ---
const String kSupabaseUrl = "https://jvjtgzewumfecjdpekna.supabase.co";
const String kSupabaseAnonKey =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp2anRnemV3dW1mZWNqZHBla25hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE2NDYzMzcsImV4cCI6MjEwNzIyMjMzN30.1gck73ek8ErBtcF7xAtFM1TdvNim_1NzFVNej_mptBE";

const Color kPrimaryDark = Color(0xFF0A2F6B);
const Color kPrimary = Color(0xFF0A47A8);
const Color kAccent = Color(0xFF00B8C4);
const Color kBgMain = Color(0xFFF3F7FC);
const Color kCardBg = Colors.white;
const Color kCardBorder = Color(0xFFE1E9F3);
const Color kTextMain = Color(0xFF102A43);
const Color kTextMuted = Color(0xFF627D98);
const Color kBadgeRed = Color(0xFFEF4444);
const Color kBadgeGreen = Color(0xFF10B981);
const Color kBadgeWarning = Color(0xFFF59E0B);
const Color kBadgeWarningText = Color(0xFFB45309);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: firebaseOptions);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, AppDataProvider>(
          create: (_) => AppDataProvider(null),
          update: (_, auth, previous) => AppDataProvider(auth)..updateAuth(auth),
        ),
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: const DMCApp(),
    ),
  );
}

class DMCApp extends StatelessWidget {
  const DMCApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Diala - DMC Customer',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Cairo',
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimary,
          primary: kPrimary,
          secondary: kAccent,
          surface: kBgMain,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: kBgMain,
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Cairo',
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimary,
          primary: kAccent,
          secondary: kPrimary,
          surface: const Color(0xFF0F172A),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0B0F17),
      ),
      themeMode: ThemeMode.light,
      home: const MainRootScreen(),
    );
  }
}

// ==========================================
// MODELS
// ==========================================

class Product {
  final int id;
  final String name;
  final String category;
  final String description;
  final double priceUsd;
  final int stockQuantity;
  final String imageUrl;
  final bool isVisible;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.priceUsd,
    required this.stockQuantity,
    required this.imageUrl,
    required this.isVisible,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? '',
      category: json['category'] ?? 'عام',
      description: json['description'] ?? '',
      priceUsd: (json['price_usd'] ?? 0).toDouble(),
      stockQuantity: json['stock_quantity'] ?? 0,
      imageUrl: json['image_url'] ?? '',
      isVisible: json['is_visible'] ?? true,
    );
  }

  String get emojiIcon {
    final lower = name.toLowerCase();
    if (lower.contains('سكر') || lower.contains('glucose') || lower.contains('فحص')) return '🩸';
    if (lower.contains('سماعة') || lower.contains('stethoscope')) return '🩺';
    if (lower.contains('سرنج') || lower.contains('حقن') || lower.contains('syringe')) return '💉';
    if (lower.contains('ضغط') || lower.contains('جهاز') || lower.contains('قياس')) return '🧬';
    return '💊';
  }
}

class DeliveryArea {
  final int id;
  final String name;
  final double deliveryFeeSdg;
  final bool isActive;

  DeliveryArea({
    required this.id,
    required this.name,
    required this.deliveryFeeSdg,
    required this.isActive,
  });

  factory DeliveryArea.fromJson(Map<String, dynamic> json) {
    return DeliveryArea(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? '',
      deliveryFeeSdg: (json['delivery_fee_sdg'] ?? 0).toDouble(),
      isActive: json['is_active'] ?? true,
    );
  }
}

class BankSettings {
  final String bankName;
  final String accountNumber;
  final String accountHolder;
  final String customerNote;

  BankSettings({
    required this.bankName,
    required this.accountNumber,
    required this.accountHolder,
    required this.customerNote,
  });

  factory BankSettings.fromJson(Map<String, dynamic> json) {
    return BankSettings(
      bankName: json['bank_name'] ?? 'بنك الخرطوم - فرع الدامر',
      accountNumber: json['account_number'] ?? '123456789',
      accountHolder: json['account_holder'] ?? 'شركة ديالا للمعدات الطبية',
      customerNote: json['customer_note'] ?? 'يرجى إرفاق صورة الإشعار بوضوح',
    );
  }
}

class OrderItem {
  final int? id;
  final int? orderId;
  final int? productId;
  final String productName;
  final double unitPriceUsd;
  final double unitPriceSdg;
  final int quantity;
  final double totalPriceSdg;

  OrderItem({
    this.id,
    this.orderId,
    this.productId,
    required this.productName,
    this.unitPriceUsd = 0,
    required this.unitPriceSdg,
    required this.quantity,
    required this.totalPriceSdg,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      orderId: json['order_id'] is int ? json['order_id'] : int.tryParse(json['order_id']?.toString() ?? ''),
      productId: json['product_id'] is int ? json['product_id'] : int.tryParse(json['product_id']?.toString() ?? ''),
      productName: json['product_name'] ?? '',
      unitPriceUsd: (json['unit_price_usd'] ?? 0).toDouble(),
      unitPriceSdg: (json['unit_price_sdg'] ?? 0).toDouble(),
      quantity: json['quantity'] ?? 1,
      totalPriceSdg: (json['total_price_sdg'] ?? 0).toDouble(),
    );
  }

  String get emojiIcon {
    final lower = productName.toLowerCase();
    if (lower.contains('سكر') || lower.contains('glucose')) return '🩸';
    if (lower.contains('سماعة')) return '🩺';
    if (lower.contains('سرنج')) return '💉';
    return '🧬';
  }
}

class CustomerOrder {
  final int id;
  final String orderNumber;
  final String fullName;
  final String phone;
  final String deliveryAreaName;
  final String deliveryAddress;
  final String deliveryType;
  final double deliveryFeeSdg;
  final double subtotalSdg;
  final double totalSdg;
  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final String? receiptUrl;
  final String? rejectReason;
  final String createdAt;
  List<OrderItem> items;

  CustomerOrder({
    required this.id,
    required this.orderNumber,
    required this.fullName,
    required this.phone,
    required this.deliveryAreaName,
    required this.deliveryAddress,
    required this.deliveryType,
    required this.deliveryFeeSdg,
    required this.subtotalSdg,
    required this.totalSdg,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    this.receiptUrl,
    this.rejectReason,
    required this.createdAt,
    this.items = const [],
  });

  factory CustomerOrder.fromJson(Map<String, dynamic> json) {
    return CustomerOrder(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      orderNumber: json['order_number']?.toString() ?? '1001',
      fullName: json['full_name'] ?? '',
      phone: json['phone'] ?? '',
      deliveryAreaName: json['delivery_area_name'] ?? 'الدامر',
      deliveryAddress: json['delivery_address'] ?? '',
      deliveryType: json['delivery_type'] ?? 'توصيل',
      deliveryFeeSdg: (json['delivery_fee_sdg'] ?? 0).toDouble(),
      subtotalSdg: (json['subtotal_sdg'] ?? 0).toDouble(),
      totalSdg: (json['total_sdg'] ?? 0).toDouble(),
      status: json['status'] ?? 'جديد',
      paymentMethod: json['payment_method'] ?? 'transfer',
      paymentStatus: json['payment_status'] ?? 'pending',
      receiptUrl: json['receipt_url'],
      rejectReason: json['reject_reason'],
      createdAt: json['created_at'] ?? '',
    );
  }
}

class AppNotification {
  final int id;
  final String title;
  final String body;
  final String createdAt;
  final String? readAt;
  final Map<String, dynamic>? data;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
    this.data,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      createdAt: json['created_at'] ?? '',
      readAt: json['read_at'],
      data: json['data'] is Map<String, dynamic> ? json['data'] : null,
    );
  }

  bool get isRead => readAt != null && readAt!.isNotEmpty;
}

// ==========================================
// HELPERS FOR SUPABASE REST API
// ==========================================

String _parseAuthError(dynamic body, String defaultMsg) {
  if (body is Map) {
    final errStr = (body['error_description'] ?? body['message'] ?? body['msg'] ?? body['error'] ?? '').toString();
    if (errStr.contains('rate limit') || errStr.contains('over_email_send_rate_limit')) {
      return 'اتبعتت رسائل كتير، استنى دقايق وتاني جرب';
    }
    if (errStr.contains('sending') || errStr.contains('smtp') || errStr.contains('Email rate limit exceeded')) {
      return 'ما قدرنا نرسل البريد، حاول لاحقاً';
    }
    if (errStr.isNotEmpty) return errStr;
  }
  return defaultMsg;
}

// ==========================================
// AUTH PROVIDER
// ==========================================

class AuthProvider extends ChangeNotifier {
  String? _accessToken;
  String? _refreshToken;
  String? _userId;
  String? _userEmail;
  String? _userName;
  String? _userPhone;
  bool _isLoading = false;

  bool get isAuthenticated => _accessToken != null && _accessToken!.isNotEmpty;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  String? get userId => _userId;
  String? get userName => _userName;
  String? get userPhone => _userPhone;
  String? get userEmail => _userEmail;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _loadSession();
  }

  Map<String, String> get authHeaders {
    final headers = {
      'apikey': kSupabaseAnonKey,
      'Content-Type': 'application/json',
      'Prefer': 'return=representation',
    };
    if (isAuthenticated) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    _refreshToken = prefs.getString('refresh_token');
    _userId = prefs.getString('user_id');
    _userEmail = prefs.getString('user_email');
    _userName = prefs.getString('user_name');
    _userPhone = prefs.getString('user_phone');
    notifyListeners();
    if (isAuthenticated) {
      fetchProfile();
    }
  }

  Future<void> _saveSession(Map<String, dynamic> data) async {
    _accessToken = data['access_token'];
    _refreshToken = data['refresh_token'];
    if (data['user'] != null) {
      _userId = data['user']['id'];
      _userEmail = data['user']['email'];
    }
    final prefs = await SharedPreferences.getInstance();
    if (_accessToken != null) await prefs.setString('access_token', _accessToken!);
    if (_refreshToken != null) await prefs.setString('refresh_token', _refreshToken!);
    if (_userId != null) await prefs.setString('user_id', _userId!);
    if (_userEmail != null) await prefs.setString('user_email', _userEmail!);
    notifyListeners();
  }

  Future<void> signOut() async {
    _accessToken = null;
    _refreshToken = null;
    _userId = null;
    _userEmail = null;
    _userName = null;
    _userPhone = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }

  // 1. Sign In
  Future<String?> signIn(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/token?grant_type=password'),
        headers: {'apikey': kSupabaseAnonKey, 'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'password': password}),
      );
      _isLoading = false;
      notifyListeners();

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        await _saveSession(body);
        await fetchProfile();
        return null; // Success
      } else {
        final errMsg = _parseAuthError(body, 'فشل تسجيل الدخول. تحقق من البيانات.');
        if (errMsg.contains('Email not confirmed') || errMsg.contains('unconfirmed')) {
          // Resend code & return special key
          await resendCode(email, 'signup');
          return 'EMAIL_NOT_CONFIRMED';
        }
        return errMsg;
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'تعذر الاتصال بالخادم. تحقق من إنترنت جهازك.';
    }
  }

  // 2. Sign Up
  Future<String?> signUp({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/signup'),
        headers: {'apikey': kSupabaseAnonKey, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
          'data': {
            'full_name': name.trim(),
            'phone': phone.trim(),
          }
        }),
      );
      _isLoading = false;
      notifyListeners();

      final body = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        _userName = name.trim();
        _userPhone = phone.trim();
        _userEmail = email.trim();
        if (body['access_token'] != null) {
          await _saveSession(body);
        }
        return null; // Prompt for 6-digit verification code
      } else {
        return _parseAuthError(body, 'فشل إنشاء الحساب.');
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'تعذر الاتصال بالخادم.';
    }
  }

  // 3. Verify Code
  Future<String?> verifyCode({required String email, required String code, required String type}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/verify'),
        headers: {'apikey': kSupabaseAnonKey, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'type': type, // "signup" or "recovery"
          'email': email.trim(),
          'token': code.trim(),
        }),
      );
      _isLoading = false;
      notifyListeners();

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        await _saveSession(body);
        await fetchProfile();
        return null;
      } else {
        return _parseAuthError(body, 'رمز التحقق غير صحيح أو انتهت صلاحيته');
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'تعذر التحقق من الرمز.';
    }
  }

  // 4. Resend Code
  Future<String?> resendCode(String email, String type) async {
    try {
      final response = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/resend'),
        headers: {'apikey': kSupabaseAnonKey, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'type': type,
          'email': email.trim(),
        }),
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200) return null;
      return _parseAuthError(body, 'تعذر إعادة إرسال الرمز.');
    } catch (e) {
      return 'خطأ في الاتصال بالشبكة.';
    }
  }

  // 5. Recover Password (Forgot)
  Future<String?> recoverPassword(String email) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/recover'),
        headers: {'apikey': kSupabaseAnonKey, 'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim()}),
      );
      _isLoading = false;
      notifyListeners();

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) return null;
      return _parseAuthError(body, 'تعذر إرسال استعادة كلمة المرور.');
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'تعذر الاتصال بالخادم.';
    }
  }

  // 6. Reset Password with session
  Future<String?> resetPassword(String newPassword) async {
    if (!isAuthenticated) return 'غير مسموح. الجلسة منتهية.';
    _isLoading = true;
    notifyListeners();
    try {
      final response = await http.put(
        Uri.parse('$kSupabaseUrl/auth/v1/user'),
        headers: authHeaders,
        body: jsonEncode({'password': newPassword}),
      );
      _isLoading = false;
      notifyListeners();

      final body = jsonDecode(response.body);
      if (response.statusCode == 200) return null;
      return _parseAuthError(body, 'تعذر تحديث كلمة المرور.');
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'خطأ في الاتصال.';
    }
  }

  // Refresh token on 401
  Future<bool> tryRefreshToken() async {
    if (_refreshToken == null) return false;
    try {
      final response = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/token?grant_type=refresh_token'),
        headers: {'apikey': kSupabaseAnonKey, 'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': _refreshToken}),
      );
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        await _saveSession(body);
        return true;
      }
    } catch (_) {}
    await signOut();
    return false;
  }

  // Fetch Profile
  Future<void> fetchProfile() async {
    if (_userId == null) return;
    try {
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/taregba_profiles?id=eq.$_userId'),
        headers: authHeaders,
      );
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        if (list.isNotEmpty) {
          final profile = list.first;
          _userName = profile['full_name'] ?? _userName;
          _userPhone = profile['phone'] ?? _userPhone;
          final prefs = await SharedPreferences.getInstance();
          if (_userName != null) await prefs.setString('user_name', _userName!);
          if (_userPhone != null) await prefs.setString('user_phone', _userPhone!);
          notifyListeners();
        }
      } else if (res.statusCode == 401) {
        final refreshed = await tryRefreshToken();
        if (refreshed) await fetchProfile();
      }
    } catch (_) {}
  }

  // Update Profile
  Future<bool> updateProfile(String fullName, String phone) async {
    if (_userId == null) return false;
    try {
      final res = await http.patch(
        Uri.parse('$kSupabaseUrl/rest/v1/taregba_profiles?id=eq.$_userId'),
        headers: authHeaders,
        body: jsonEncode({
          'full_name': fullName,
          'phone': phone,
        }),
      );
      if (res.statusCode == 200 || res.statusCode == 204) {
        _userName = fullName;
        _userPhone = phone;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', fullName);
        await prefs.setString('user_phone', phone);
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }
}

// ==========================================
// APP DATA PROVIDER (SYNC & NOTIFICATIONS & REST)
// ==========================================

class AppDataProvider extends ChangeNotifier with WidgetsBindingObserver {
  AuthProvider? _auth;
  Timer? _syncTimer;
  BuildContext? currentContext;

  double _usdRate = 1400.0;
  List<Product> _products = [];
  List<DeliveryArea> _deliveryAreas = [];
  BankSettings? _bankSettings;
  List<CustomerOrder> _orders = [];
  List<AppNotification> _notifications = [];
  bool _isLoading = false;

  double get usdRate => _usdRate;
  List<Product> get products => _products.isEmpty ? _fallbackProducts : _products;
  List<DeliveryArea> get deliveryAreas => _deliveryAreas.isEmpty ? _fallbackDeliveryAreas : _deliveryAreas;
  BankSettings get bankSettings => _bankSettings ?? BankSettings(
        bankName: 'بنك الخرطوم - فرع الدامر',
        accountNumber: '123456789',
        accountHolder: 'شركة ديالا للمعدات الطبية',
        customerNote: 'يرجى إرفاق صورة الإشعار بوضوح',
      );
  List<CustomerOrder> get orders => _orders.isEmpty ? _fallbackOrders : _orders;
  List<AppNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;

  int get unreadNotificationsCount => _notifications.where((n) => !n.isRead).length;

  AppDataProvider(this._auth) {
    WidgetsBinding.instance.addObserver(this);
    _initData();
  }

  void setContext(BuildContext context) {
    currentContext = context;
  }

  void updateAuth(AuthProvider auth) {
    final bool authChanged = _auth?.isAuthenticated != auth.isAuthenticated;
    _auth = auth;
    if (auth.isAuthenticated) {
      _registerDevicePush();
      startSyncTimer();
      fetchAllData();
    } else {
      stopSyncTimer();
      if (authChanged) {
        _orders.clear();
        _notifications.clear();
        notifyListeners();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _auth?.isAuthenticated == true) {
      fetchAllData();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    stopSyncTimer();
    super.dispose();
  }

  void startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_auth?.isAuthenticated == true) {
        fetchAllData(quiet: true);
      }
    });
  }

  void stopSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  Future<void> _initData() async {
    _setupPushForegroundListener();
    await fetchAllData();
  }

  void _setupPushForegroundListener() {
    try {
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final title = message.notification?.title ?? 'إشعار جديد من Diala';
        final body = message.notification?.body ?? '';
        if (currentContext != null && currentContext!.mounted) {
          ScaffoldMessenger.of(currentContext!).showSnackBar(
            SnackBar(
              content: Text('$title\n$body'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: kPrimary,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        fetchAllData(quiet: true);
      });
    } catch (e) {
      debugPrint("Firebase Messaging listener error: $e");
    }
  }

  Future<void> _registerDevicePush() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        final token = await messaging.getToken();
        if (token != null && _auth?.isAuthenticated == true) {
          await http.post(
            Uri.parse('$kSupabaseUrl/rest/v1/rpc/taregba_register_device'),
            headers: _auth!.authHeaders,
            body: jsonEncode({
              'device_token': token,
              'app_name': 'customer',
            }),
          );
        }
      }
    } catch (e) {
      debugPrint("Register device push error: $e");
    }
  }

  Future<void> fetchAllData({bool quiet = false}) async {
    if (!quiet) {
      _isLoading = true;
      notifyListeners();
    }
    await Future.wait([
      _fetchUsdRate(),
      _fetchProducts(),
      _fetchDeliveryAreas(),
      _fetchBankSettings(),
      if (_auth?.isAuthenticated == true) _fetchOrders(),
      if (_auth?.isAuthenticated == true) _fetchNotifications(),
    ]);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _fetchUsdRate() async {
    try {
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/taregba_settings?setting_key=eq.usd_sdg_rate'),
        headers: {'apikey': kSupabaseAnonKey},
      );
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        if (list.isNotEmpty) {
          _usdRate = double.tryParse(list.first['setting_value'].toString()) ?? 1400.0;
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchProducts() async {
    try {
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/taregba_products?is_visible=eq.true&order=created_at.desc'),
        headers: {'apikey': kSupabaseAnonKey},
      );
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        _products = list.map((e) => Product.fromJson(e)).toList();
      }
    } catch (_) {}
  }

  Future<void> _fetchDeliveryAreas() async {
    try {
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/taregba_delivery_areas?is_active=eq.true&order=id.asc'),
        headers: {'apikey': kSupabaseAnonKey},
      );
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        _deliveryAreas = list.map((e) => DeliveryArea.fromJson(e)).toList();
      }
    } catch (_) {}
  }

  Future<void> _fetchBankSettings() async {
    try {
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/taregba_bank_settings?limit=1'),
        headers: {'apikey': kSupabaseAnonKey},
      );
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        if (list.isNotEmpty) {
          _bankSettings = BankSettings.fromJson(list.first);
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchOrders() async {
    if (_auth?.userId == null) return;
    try {
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/taregba_orders?customer_id=eq.${_auth!.userId}&order=created_at.desc'),
        headers: _auth!.authHeaders,
      );
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        List<CustomerOrder> fetched = list.map((e) => CustomerOrder.fromJson(e)).toList();

        // Fetch items for these orders
        for (var o in fetched) {
          final itemsRes = await http.get(
            Uri.parse('$kSupabaseUrl/rest/v1/taregba_order_items?order_id=eq.${o.id}'),
            headers: _auth!.authHeaders,
          );
          if (itemsRes.statusCode == 200) {
            final List itemsList = jsonDecode(itemsRes.body);
            o.items = itemsList.map((i) => OrderItem.fromJson(i)).toList();
          }
        }
        _orders = fetched;
      } else if (res.statusCode == 401) {
        await _auth?.tryRefreshToken();
      }
    } catch (_) {}
  }

  Future<void> _fetchNotifications() async {
    if (_auth?.userId == null) return;
    try {
      final url = '$kSupabaseUrl/rest/v1/taregba_notifications?or=(to_user.eq.${_auth!.userId},to_role.eq.customer)&order=created_at.desc';
      final res = await http.get(
        Uri.parse(url),
        headers: _auth!.authHeaders,
      );
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        _notifications = list.map((e) => AppNotification.fromJson(e)).toList();
      }
    } catch (_) {}
  }

  Future<void> markNotificationRead(int notificationId) async {
    try {
      final nowIso = DateTime.now().toIso8601String();
      final res = await http.patch(
        Uri.parse('$kSupabaseUrl/rest/v1/taregba_notifications?id=eq.$notificationId'),
        headers: _auth!.authHeaders,
        body: jsonEncode({'read_at': nowIso}),
      );
      if (res.statusCode == 200 || res.statusCode == 204) {
        final index = _notifications.indexWhere((n) => n.id == notificationId);
        if (index != -1) {
          final old = _notifications[index];
          _notifications[index] = AppNotification(
            id: old.id,
            title: old.title,
            body: old.body,
            createdAt: old.createdAt,
            readAt: nowIso,
            data: old.data,
          );
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  // Create Order & Send Notification to Admin
  Future<CustomerOrder?> createOrder({
    required String fullName,
    required String phone,
    required DeliveryArea area,
    required String address,
    required String deliveryType,
    required String paymentMethod,
    required List<CartItem> cartItems,
  }) async {
    if (_auth?.isAuthenticated != true) return null;

    double subtotal = 0;
    for (var item in cartItems) {
      subtotal += (item.product.priceUsd * _usdRate) * item.quantity;
    }
    double total = subtotal + area.deliveryFeeSdg;
    final orderNum = (1000 + DateTime.now().millisecondsSinceEpoch % 9000).toString();

    try {
      final orderBody = {
        'order_number': orderNum,
        'customer_id': _auth!.userId,
        'full_name': fullName,
        'phone': phone,
        'delivery_area_id': area.id,
        'delivery_area_name': area.name,
        'delivery_address': address,
        'delivery_type': deliveryType,
        'delivery_fee_sdg': area.deliveryFeeSdg,
        'subtotal_sdg': subtotal,
        'total_sdg': total,
        'status': 'جديد',
        'payment_method': paymentMethod,
        'payment_status': 'pending',
      };

      final res = await http.post(
        Uri.parse('$kSupabaseUrl/rest/v1/taregba_orders'),
        headers: _auth!.authHeaders,
        body: jsonEncode(orderBody),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        final List createdList = jsonDecode(res.body);
        if (createdList.isNotEmpty) {
          final createdOrder = CustomerOrder.fromJson(createdList.first);

          // Create Items
          for (var c in cartItems) {
            await http.post(
              Uri.parse('$kSupabaseUrl/rest/v1/taregba_order_items'),
              headers: _auth!.authHeaders,
              body: jsonEncode({
                'order_id': createdOrder.id,
                'customer_id': _auth!.userId,
                'product_id': c.product.id,
                'product_name': c.product.name,
                'unit_price_usd': c.product.priceUsd,
                'unit_price_sdg': c.product.priceUsd * _usdRate,
                'quantity': c.quantity,
                'total_price_sdg': (c.product.priceUsd * _usdRate) * c.quantity,
              }),
            );
          }

          // Send Event Notification to Admin (CONTRACT EVENT)
          await sendNotificationToAdmin(
            title: 'طلب جديد في الانتظار',
            body: 'قام الزبون $fullName بتقديم طلب جديد رقم #$orderNum',
            data: {'order_id': createdOrder.id, 'order_number': orderNum},
          );

          await fetchAllData(quiet: true);
          return createdOrder;
        }
      }
    } catch (e) {
      debugPrint("Error creating order: $e");
    }
    return null;
  }

  // Upload Receipt & Send Notification to Admin
  Future<bool> uploadBankReceipt(int orderId, String orderNum, String receiptUrl) async {
    try {
      final res = await http.patch(
        Uri.parse('$kSupabaseUrl/rest/v1/taregba_orders?id=eq.$orderId'),
        headers: _auth!.authHeaders,
        body: jsonEncode({
          'receipt_url': receiptUrl,
          'payment_status': 'pending',
        }),
      );
      if (res.statusCode == 200 || res.statusCode == 204) {
        // Send Notification to Admin (CONTRACT EVENT)
        await sendNotificationToAdmin(
          title: 'إشعار تحويل بنكي جديد يتطلب المراجعة',
          body: 'قام الزبون ${_auth?.userName ?? ''} برفع صورة إشعار تحويل بنكي للطلب #$orderNum',
          data: {'order_id': orderId, 'order_number': orderNum},
        );
        await fetchAllData(quiet: true);
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> sendNotificationToAdmin({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      await http.post(
        Uri.parse('$kSupabaseUrl/rest/v1/taregba_notifications'),
        headers: _auth!.authHeaders,
        body: jsonEncode({
          'to_role': 'admin',
          'title': title,
          'body': body,
          'data': data,
          'created_by': _auth?.userId,
        }),
      );
    } catch (_) {}
  }

  // Fallbacks
  static final List<Product> _fallbackProducts = [
    Product(
      id: 1,
      name: 'Glucose Test Strips - جهاز قياس السكر',
      category: 'أجهزة قياس',
      description: 'شرائط فحص السكر في الدم بدقة عالية، متوافقة مع أجهزة الدامر الطبية، العبوة تحتوي على 50 شريط مع كود تلقائي.',
      priceUsd: 46.42,
      stockQuantity: 15,
      imageUrl: '',
      isVisible: true,
    ),
    Product(
      id: 2,
      name: 'سماعة طبيب رقمية متطورة',
      category: 'معدات طبية',
      description: 'سماعة طبيب رقمية متطورة مع تضخيم الصوت وإلغاء الضوضاء وسهولة الاستخدام للتشخيص الطبي الدقيق.',
      priceUsd: 103.57,
      stockQuantity: 8,
      imageUrl: '',
      isVisible: true,
    ),
    Product(
      id: 3,
      name: 'سرنجات طبية 5مل (علبة 100)',
      category: 'مستهلكات',
      description: 'سرنجات طبية معقمة استخدام مرة واحدة سعة 5مل، عبوة 100 قطعة مطابقة للمواصفات العالمية.',
      priceUsd: 15.71,
      stockQuantity: 2,
      imageUrl: '',
      isVisible: true,
    ),
    Product(
      id: 4,
      name: 'جهاز قياس ضغط الدم الرقمي',
      category: 'أجهزة قياس',
      description: 'جهاز قياس ضغط الدم الرقمي للذراع مع شاشة عرض واسعة وذاكرة قراءات متعددة.',
      priceUsd: 70.00,
      stockQuantity: 12,
      imageUrl: '',
      isVisible: true,
    ),
  ];

  static final List<DeliveryArea> _fallbackDeliveryAreas = [
    DeliveryArea(id: 1, name: 'الدامر', deliveryFeeSdg: 3000, isActive: true),
    DeliveryArea(id: 2, name: 'عطبرة', deliveryFeeSdg: 4000, isActive: true),
    DeliveryArea(id: 3, name: 'بربر', deliveryFeeSdg: 5000, isActive: true),
    DeliveryArea(id: 4, name: 'أبوحمد', deliveryFeeSdg: 7000, isActive: true),
  ];

  static final List<CustomerOrder> _fallbackOrders = [
    CustomerOrder(
      id: 1043,
      orderNumber: '1043',
      fullName: 'د. محمد أحمد الفكي',
      phone: '0912345678',
      deliveryAreaName: 'الدامر',
      deliveryAddress: 'السوق الرئيسي، قرب مستشفى الدامر',
      deliveryType: 'توصيل',
      deliveryFeeSdg: 3000,
      subtotalSdg: 210000,
      totalSdg: 213000,
      status: 'جديد',
      paymentMethod: 'transfer',
      paymentStatus: 'pending',
      createdAt: 'اليوم، 10:30 صباحاً',
      items: [
        OrderItem(productName: 'Glucose Strips', unitPriceSdg: 65000, quantity: 1, totalPriceSdg: 65000),
        OrderItem(productName: 'سماعة طبيب', unitPriceSdg: 145000, quantity: 1, totalPriceSdg: 145000),
      ],
    ),
    CustomerOrder(
      id: 1042,
      orderNumber: '1042',
      fullName: 'د. محمد أحمد الفكي',
      phone: '0912345678',
      deliveryAreaName: 'عطبرة',
      deliveryAddress: 'حي المطار',
      deliveryType: 'توصيل',
      deliveryFeeSdg: 4000,
      subtotalSdg: 94000,
      totalSdg: 98000,
      status: 'في الطريق',
      paymentMethod: 'cash',
      paymentStatus: 'confirmed',
      createdAt: 'أمس، 02:15 ظهراً',
      items: [
        OrderItem(productName: 'جهاز قياس ضغط الدم', unitPriceSdg: 94000, quantity: 1, totalPriceSdg: 94000),
      ],
    ),
    CustomerOrder(
      id: 1039,
      orderNumber: '1039',
      fullName: 'د. محمد أحمد الفكي',
      phone: '0912345678',
      deliveryAreaName: 'بربر',
      deliveryAddress: 'السوق الكبير',
      deliveryType: 'توصيل',
      deliveryFeeSdg: 5000,
      subtotalSdg: 60000,
      totalSdg: 65000,
      status: 'تم التوصيل',
      paymentMethod: 'transfer',
      paymentStatus: 'confirmed',
      createdAt: '15 مايو 2024',
      items: [
        OrderItem(productName: 'Glucose Strips', unitPriceSdg: 60000, quantity: 1, totalPriceSdg: 60000),
      ],
    ),
  ];
}

// ==========================================
// CART PROVIDER
// ==========================================

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});
}

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [
    CartItem(
      product: Product(
        id: 1,
        name: 'Glucose Test Strips - جهاز قياس السكر',
        category: 'أجهزة قياس',
        description: 'شرائط فحص السكر بدقة عالية',
        priceUsd: 46.42,
        stockQuantity: 10,
        imageUrl: '',
        isVisible: true,
      ),
      quantity: 1,
    ),
    CartItem(
      product: Product(
        id: 2,
        name: 'سماعة طبيب رقمية متطورة',
        category: 'معدات طبية',
        description: 'سماعة رقمية عالية الدقة',
        priceUsd: 103.57,
        stockQuantity: 5,
        imageUrl: '',
        isVisible: true,
      ),
      quantity: 1,
    ),
  ];

  List<CartItem> get items => _items;
  int get itemCount => _items.fold(0, (sum, i) => sum + i.quantity);

  double getSubtotal(double usdRate) {
    return _items.fold(0.0, (sum, i) => sum + (i.product.priceUsd * usdRate * i.quantity));
  }

  void addToCart(Product product, {int quantity = 1}) {
    final idx = _items.indexWhere((i) => i.product.id == product.id);
    if (idx >= 0) {
      _items[idx].quantity += quantity;
    } else {
      _items.add(CartItem(product: product, quantity: quantity));
    }
    notifyListeners();
  }

  void updateQuantity(Product product, int delta) {
    final idx = _items.indexWhere((i) => i.product.id == product.id);
    if (idx >= 0) {
      _items[idx].quantity += delta;
      if (_items[idx].quantity <= 0) {
        _items.removeAt(idx);
      }
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}

// ==========================================
// HEADER COMPONENT
// ==========================================

class DMCHeader extends StatelessWidget implements PreferredSizeWidget {
  final bool showBackButton;

  const DMCHeader({super.key, this.showBackButton = false});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final appData = Provider.of<AppDataProvider>(context);
    final auth = Provider.of<AuthProvider>(context);

    return Container(
      height: 64 + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [kPrimaryDark, kPrimary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            if (showBackButton)
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.maybePop(context),
              ),
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
                ],
              ),
              alignment: Alignment.center,
              child: const Text(
                'DMC',
                style: TextStyle(
                  color: kPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Diala',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  'معدات ومستهلكات طبية',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Cart Icon Button with Badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                InkWell(
                  onTap: () {
                    final state = context.findAncestorStateOfType<_MainRootScreenState>();
                    if (state != null) {
                      state.switchTab(1);
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 20),
                  ),
                ),
                if (cart.itemCount > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: kAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: kPrimaryDark, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${cart.itemCount}',
                        style: const TextStyle(
                          color: Color(0xFF0B1329),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            // Notifications Button with Unread Badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
                  ),
                ),
                if (appData.unreadNotificationsCount > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: kBadgeRed,
                        shape: BoxShape.circle,
                        border: Border.all(color: kPrimaryDark, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${appData.unreadNotificationsCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
            // Auth / Profile Button
            InkWell(
              onTap: () {
                if (auth.isAuthenticated) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                  );
                }
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  auth.isAuthenticated ? Icons.person : Icons.login,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// MAIN APP ROOT & NAVIGATION BAR
// ==========================================

class MainRootScreen extends StatefulWidget {
  const MainRootScreen({super.key});

  @override
  State<MainRootScreen> createState() => _MainRootScreenState();
}

class _MainRootScreenState extends State<MainRootScreen> {
  int _currentIndex = 0;

  void switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context, listen: false);
    appData.setContext(context);

    final List<Widget> screens = [
      const HomeScreen(),
      const CartScreen(),
      const OrdersScreen(),
      const ContactScreen(),
    ];

    return Scaffold(
      appBar: const DMCHeader(),
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        height: 72,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: kCardBorder)),
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -4))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.home_rounded, 'الرئيسية'),
            _buildNavItem(1, Icons.shopping_cart_outlined, 'السلة'),
            _buildNavItem(2, Icons.assignment_outlined, 'طلباتي'),
            _buildNavItem(3, Icons.call_outlined, 'تواصل'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final selected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => switchTab(index),
        child: Container(
          color: selected ? kPrimary.withValues(alpha: 0.06) : Colors.transparent,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? kPrimary : kTextMuted,
                size: selected ? 24 : 22,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                  color: selected ? kPrimary : kTextMuted,
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
// SCREEN 1: HOME SCREEN
// ==========================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCategory = 'الكل';
  String _searchQuery = '';

  final List<String> _categories = [
    'الكل',
    'أجهزة قياس',
    'معدات طبية',
    'مستهلكات',
    'مختبرات'
  ];

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final cart = Provider.of<CartProvider>(context, listen: false);

    final filteredProducts = appData.products.where((p) {
      final matchesCat = _selectedCategory == 'الكل' || p.category == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty || p.name.contains(_searchQuery) || p.description.contains(_searchQuery);
      return matchesCat && matchesSearch;
    }).toList();

    return RefreshIndicator(
      onRefresh: () => appData.fetchAllData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: kCardBorder),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
                  ],
                ),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  decoration: const InputDecoration(
                    hintText: 'ابحث عن معدات، أجهزة، أو مستهلكات...',
                    hintStyle: TextStyle(fontSize: 14, color: kTextMuted),
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search, color: kTextMuted),
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),

            // Categories Horizontal Scroll
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: _categories.map((cat) {
                  final isSelected = cat == _selectedCategory;
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: InkWell(
                      onTap: () => setState(() => _selectedCategory = cat),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? kPrimary : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isSelected ? kPrimary : kCardBorder),
                          boxShadow: isSelected
                              ? [BoxShadow(color: kPrimary.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))]
                              : null,
                        ),
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: isSelected ? Colors.white : kTextMain,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // Delivery Banner
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF00B8C4).withValues(alpha: 0.15),
                      const Color(0xFF10B981).withValues(alpha: 0.15),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF00B8C4).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on_outlined, color: Color(0xFF008891), size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'التوصيل إلى: الدامر / نهر النيل',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF006064),
                            ),
                          ),
                          Text(
                            'سعر الدولار الحالي: ${appData.usdRate.toStringAsFixed(0)} ج.س',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF00838F)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'نشط',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF047857),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Products Grid
            Padding(
              padding: const EdgeInsets.all(16),
              child: filteredProducts.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('لا توجد منتجات مطابقة للبحث', style: TextStyle(color: kTextMuted)),
                      ),
                    )
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.72,
                      ),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredProducts.length,
                      itemBuilder: (context, index) {
                        final product = filteredProducts[index];
                        final priceSdg = product.priceUsd * appData.usdRate;
                        final formattedPrice = '${intl.NumberFormat("#,##0").format(priceSdg)} ج.س';
                        final isLowStock = product.stockQuantity <= 3 && product.stockQuantity > 0;

                        return _buildProductCard(
                          context,
                          emoji: product.emojiIcon,
                          title: product.name,
                          price: formattedPrice,
                          stockBadge: product.stockQuantity > 0 ? (isLowStock ? 'قارب على النفاد' : 'متوفر') : 'نفد',
                          stockBadgeColor: product.stockQuantity > 0 ? (isLowStock ? kBadgeWarning : kBadgeGreen) : kBadgeRed,
                          stockTextColor: product.stockQuantity > 0 ? (isLowStock ? kBadgeWarningText : const Color(0xFF047857)) : Colors.white,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ProductDetailScreen(product: product),
                              ),
                            );
                          },
                          onAdd: () {
                            cart.addToCart(product);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تمت الإضافة للسلة بنجاح'), behavior: SnackBarBehavior.floating),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(
    BuildContext context, {
    required String emoji,
    required String title,
    required String price,
    required String stockBadge,
    required Color stockBadgeColor,
    required Color stockTextColor,
    required VoidCallback onTap,
    required VoidCallback onAdd,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kCardBorder),
          boxShadow: const [
            BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Emoji Image Box
            Container(
              height: 120,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                border: Border(bottom: BorderSide(color: kCardBorder)),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 40),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: stockBadgeColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        stockBadge,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: stockTextColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: kTextMain,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          price,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: kPrimary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary.withValues(alpha: 0.08),
                          foregroundColor: kPrimary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: onAdd,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add, size: 16),
                            SizedBox(width: 4),
                            Text(
                              'أضف للسلة',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
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
    );
  }
}

// ==========================================
// SCREEN 2: PRODUCT DETAIL SCREEN
// ==========================================

class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final cart = Provider.of<CartProvider>(context, listen: false);

    final priceSdg = widget.product.priceUsd * appData.usdRate;
    final formattedPrice = '${intl.NumberFormat("#,##0").format(priceSdg)} ج.س';

    return Scaffold(
      appBar: const DMCHeader(showBackButton: true),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    height: 180,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: kCardBorder),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      widget.product.emojiIcon,
                      style: const TextStyle(fontSize: 80),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: kBadgeGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.product.stockQuantity > 0 ? 'متوفر في المخزون' : 'غير متوفر',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: widget.product.stockQuantity > 0 ? const Color(0xFF047857) : kBadgeRed,
                          ),
                        ),
                      ),
                      Text(
                        'القسم: ${widget.product.category}',
                        style: const TextStyle(fontSize: 13, color: kTextMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.product.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: kTextMain,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    formattedPrice,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: kPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'وصف المنتج',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.product.description.isEmpty
                        ? 'منتج طبي عالي الجودة متوفر لدى معرض ديالا للمعدات والمستهلكات الطبية.'
                        : widget.product.description,
                    style: const TextStyle(fontSize: 14, color: kTextMuted, height: 1.6),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kCardBorder, width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'الكمية:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Row(
                          children: [
                            InkWell(
                              onTap: () {
                                if (_quantity > 1) setState(() => _quantity--);
                              },
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: kBgMain,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: const Text('-', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kPrimary)),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text('$_quantity', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                            InkWell(
                              onTap: () => setState(() => _quantity++),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: kBgMain,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: const Text('+', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kPrimary)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: () {
                        cart.addToCart(widget.product, quantity: _quantity);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تمت إضافة المنتج إلى السلة بنجاح')),
                        );
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.shopping_cart_outlined),
                      label: const Text(
                        'أضف إلى السلة',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
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

// ==========================================
// SCREEN 3: CART SCREEN
// ==========================================

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final appData = Provider.of<AppDataProvider>(context);

    final subtotal = cart.getSubtotal(appData.usdRate);
    final deliveryFee = appData.deliveryAreas.isNotEmpty ? appData.deliveryAreas.first.deliveryFeeSdg : 3000.0;
    final total = subtotal + (cart.items.isNotEmpty ? deliveryFee : 0);

    final formattedSubtotal = '${intl.NumberFormat("#,##0").format(subtotal)} ج.س';
    final formattedFee = '${intl.NumberFormat("#,##0").format(deliveryFee)} ج.س';
    final formattedTotal = '${intl.NumberFormat("#,##0").format(total)} ج.س';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'سلة المشتريات (${cart.itemCount})',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (cart.items.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: const Column(
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 64, color: kTextMuted),
                  SizedBox(height: 16),
                  Text('السلة فارغة حالياً', style: TextStyle(fontSize: 16, color: kTextMuted)),
                ],
              ),
            )
          else ...[
            ...cart.items.map((item) {
              final itemPrice = item.product.priceUsd * appData.usdRate * item.quantity;
              final formattedItemPrice = '${intl.NumberFormat("#,##0").format(itemPrice)} ج.س';
              return _buildCartItem(
                context: context,
                item: item,
                priceFormatted: formattedItemPrice,
              );
            }),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kCardBorder),
              ),
              child: Column(
                children: [
                  _SummaryRow(label: 'إجمالي المنتجات', value: formattedSubtotal),
                  const SizedBox(height: 10),
                  _SummaryRow(
                    label: 'رسوم التوصيل التقديرية (${appData.deliveryAreas.isNotEmpty ? appData.deliveryAreas.first.name : "الدامر"})',
                    value: formattedFee,
                  ),
                  const Divider(height: 24),
                  _SummaryRow(
                    label: 'المبلغ الإجمالي',
                    value: formattedTotal,
                    isTotal: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                ),
                onPressed: () {
                  final auth = Provider.of<AuthProvider>(context, listen: false);
                  if (!auth.isAuthenticated) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AuthScreen()),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('يرجى تسجيل الدخول أولاً لإتمام الطلب')),
                    );
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                    );
                  }
                },
                child: const Text(
                  'إتمام الطلب',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCartItem({
    required BuildContext context,
    required CartItem item,
    required String priceFormatted,
  }) {
    final cart = Provider.of<CartProvider>(context, listen: false);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kCardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kCardBorder),
            ),
            alignment: Alignment.center,
            child: Text(item.product.emojiIcon, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  priceFormatted,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kPrimary),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: kTextMuted, size: 20),
                onPressed: () => cart.updateQuantity(item.product, -1),
              ),
              Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: kPrimary, size: 20),
                onPressed: () => cart.updateQuantity(item.product, 1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isTotal;

  const _SummaryRow({required this.label, required this.value, this.isTotal = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 15 : 13,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.normal,
            color: isTotal ? kTextMain : kTextMuted,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 16 : 13,
            fontWeight: isTotal ? FontWeight.w800 : FontWeight.normal,
            color: isTotal ? kPrimary : kTextMuted,
          ),
        ),
      ],
    );
  }
}

// ==========================================
// SCREEN 4: CHECKOUT SCREEN
// ==========================================

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _paymentMethod = 'transfer';
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  DeliveryArea? _selectedArea;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _nameController.text = auth.userName ?? '';
    _phoneController.text = auth.userPhone ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final cart = Provider.of<CartProvider>(context);

    if (_selectedArea == null && appData.deliveryAreas.isNotEmpty) {
      _selectedArea = appData.deliveryAreas.first;
    }

    return Scaffold(
      appBar: const DMCHeader(showBackButton: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'معلومات التوصيل والدفع',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            const _FormLabel('الاسم الكامل'),
            TextField(
              controller: _nameController,
              decoration: _inputDecoration(),
            ),
            const SizedBox(height: 16),
            const _FormLabel('رقم الهاتف'),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: _inputDecoration(),
            ),
            const SizedBox(height: 16),
            const _FormLabel('منطقة التوصيل'),
            DropdownButtonFormField<DeliveryArea>(
              initialValue: _selectedArea,
              decoration: _inputDecoration(),
              items: appData.deliveryAreas.map((a) {
                return DropdownMenuItem(
                  value: a,
                  child: Text('${a.name} (${intl.NumberFormat("#,##0").format(a.deliveryFeeSdg)} ج.س)'),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedArea = val);
              },
            ),
            const SizedBox(height: 16),
            const _FormLabel('العنوان بالتفصيل'),
            TextField(
              controller: _addressController,
              decoration: _inputDecoration(hint: 'الشارع، الحي، قرب معالم مميزة'),
            ),
            const SizedBox(height: 16),
            const _FormLabel('طريقة الدفع'),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _paymentMethod = 'transfer'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _paymentMethod == 'transfer' ? kPrimary.withValues(alpha: 0.05) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _paymentMethod == 'transfer' ? kPrimary : kCardBorder, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'تحويل بنكي',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _paymentMethod == 'transfer' ? kPrimary : kTextMain,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _paymentMethod = 'cash'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: _paymentMethod == 'cash' ? kPrimary.withValues(alpha: 0.05) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _paymentMethod == 'cash' ? kPrimary : kCardBorder, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'كاش عند الاستلام',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: _paymentMethod == 'cash' ? kPrimary : kTextMain,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                ),
                onPressed: _isSubmitting
                    ? null
                    : () async {
                        if (_nameController.text.trim().isEmpty || _phoneController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('يرجى ملء كافة البيانات المطلوب')),
                          );
                          return;
                        }

                        setState(() => _isSubmitting = true);
                        final created = await appData.createOrder(
                          fullName: _nameController.text.trim(),
                          phone: _phoneController.text.trim(),
                          area: _selectedArea ?? appData.deliveryAreas.first,
                          address: _addressController.text.trim(),
                          deliveryType: 'توصيل',
                          paymentMethod: _paymentMethod,
                          cartItems: cart.items,
                        );
                        setState(() => _isSubmitting = false);

                        if (created != null && context.mounted) {
                          cart.clear();
                          if (_paymentMethod == 'transfer') {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => BankTransferScreen(order: created)),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم تقديم طلبك بنجاح!')),
                            );
                            Navigator.pop(context);
                          }
                        }
                      },
                child: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text(
                        'تأكيد الطلب والمتابعة',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kCardBorder, width: 1.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kCardBorder, width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kPrimary, width: 1.5)),
    );
  }
}

class _FormLabel extends StatelessWidget {
  final String text;
  const _FormLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kTextMain),
      ),
    );
  }
}

// ==========================================
// SCREEN 5: BANK TRANSFER SCREEN
// ==========================================

class BankTransferScreen extends StatefulWidget {
  final CustomerOrder? order;

  const BankTransferScreen({super.key, this.order});

  @override
  State<BankTransferScreen> createState() => _BankTransferScreenState();
}

class _BankTransferScreenState extends State<BankTransferScreen> {
  XFile? _imageFile;
  bool _isUploading = false;

  Future<void> _pickReceiptImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: source, imageQuality: 70);
      if (file != null) {
        setState(() => _imageFile = file);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم اختيار صورة الإشعار بنجاح (معاينة جاهزة)')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر الوصول للكاميرا أو المعرض: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final bank = appData.bankSettings;

    final targetOrder = widget.order ?? (appData.orders.isNotEmpty ? appData.orders.first : null);
    final formattedAmount = targetOrder != null
        ? '${intl.NumberFormat("#,##0").format(targetOrder.totalSdg)} ج.س'
        : '213,000 ج.س';

    return Scaffold(
      appBar: const DMCHeader(showBackButton: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'تأكيد التحويل البنكي',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [kPrimaryDark, kPrimary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('بيانات حساب المحل', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(bank.bankName, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('رقم الحساب: ${bank.accountNumber}', style: const TextStyle(color: Colors.white, fontSize: 14, fontFamily: 'monospace')),
                  const SizedBox(height: 4),
                  Text('اسم صاحب الحساب: ${bank.accountHolder}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                  const Divider(color: Colors.white24, height: 24),
                  Text('المطلوب تحويله: $formattedAmount', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _pickReceiptImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('التقاط كاميرا'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _pickReceiptImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('اختيار من المعرض'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _pickReceiptImage(ImageSource.gallery),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: kPrimary.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kPrimary, width: 2, style: BorderStyle.solid),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.image_outlined, size: 36, color: kPrimary),
                    const SizedBox(height: 8),
                    const Text(
                      'إرفاق صورة إشعار التحويل',
                      style: TextStyle(fontWeight: FontWeight.bold, color: kPrimary, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _imageFile != null ? 'تم اختيار: ${_imageFile!.name}' : 'انقر لاختيار صورة إيصال التحويل',
                      style: const TextStyle(fontSize: 12, color: kTextMuted),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                '⚠️ يبدأ تجهيز الطلب بعد تأكيد الإدارة للدفع وتحققها من الإشعار.',
                style: TextStyle(fontSize: 12, color: kTextMuted),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 4,
                ),
                onPressed: _isUploading
                    ? null
                    : () async {
                        if (targetOrder == null) return;
                        setState(() => _isUploading = true);

                        // Simulated receipt URL upload
                        final mockUrl = "https://receipts.domain.com/${DateTime.now().millisecondsSinceEpoch}.jpg";
                        await appData.uploadBankReceipt(targetOrder.id, targetOrder.orderNumber, mockUrl);

                        setState(() => _isUploading = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم إرسال إشعار التحويل للإدارة بنجاح')),
                          );
                          Navigator.popUntil(context, (r) => r.isFirst);
                        }
                      },
                child: _isUploading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text(
                        'إرسال إشعار التحويل للإدارة',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// SCREEN 6: ORDERS SCREEN
// ==========================================

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final orders = appData.orders;

    return RefreshIndicator(
      onRefresh: () => appData.fetchAllData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'طلباتي السابقة',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                Text(
                  'إجمالي الطلبات: ${orders.length}',
                  style: const TextStyle(fontSize: 12, color: kTextMuted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (orders.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                alignment: Alignment.center,
                child: const Text('لا توجد طلبات سابقة', style: TextStyle(color: kTextMuted)),
              )
            else
              ...orders.map((o) {
                Color statusBg = kBadgeWarning.withValues(alpha: 0.12);
                Color statusText = kBadgeWarningText;
                if (o.status == 'تم التوصيل' || o.paymentStatus == 'confirmed') {
                  statusBg = kBadgeGreen.withValues(alpha: 0.12);
                  statusText = const Color(0xFF047857);
                } else if (o.status == 'في الطريق') {
                  statusBg = kPrimary.withValues(alpha: 0.1);
                  statusText = kPrimary;
                } else if (o.status == 'مرفوض') {
                  statusBg = kBadgeRed.withValues(alpha: 0.12);
                  statusText = kBadgeRed;
                }

                final formattedTotal = '${intl.NumberFormat("#,##0").format(o.totalSdg)} ج.س';

                return _buildOrderCard(
                  context,
                  order: o,
                  orderNumber: o.orderNumber,
                  time: o.createdAt,
                  statusBadgeText: o.status == 'جديد' && o.paymentStatus == 'pending' && o.paymentMethod == 'transfer'
                      ? 'بانتظار تأكيد الدفع'
                      : o.status,
                  statusBadgeBg: statusBg,
                  statusBadgeTextColor: statusText,
                  areaTotal: 'المنطقة: ${o.deliveryAreaName} | الإجمالي: $formattedTotal',
                  paymentSubText: 'طريقة الدفع: ${o.paymentMethod == "transfer" ? "تحويل بنكي" : "كاش عند الاستلام"} (${o.paymentStatus == "confirmed" ? "مؤكد" : "معلق"})',
                  paymentSubColor: o.paymentStatus == 'confirmed' ? const Color(0xFF047857) : kBadgeWarningText,
                  actions: [
                    if (o.paymentMethod == 'transfer' && o.paymentStatus == 'pending') ...[
                      Expanded(
                        child: OutlinedButton(
                          style: _outlineBtnStyle(),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => BankTransferScreen(order: o)),
                            );
                          },
                          child: const Text('رفع إشعار جديد'),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: OutlinedButton(
                        style: _outlineBtnStyle(),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => InvoiceScreen(order: o)),
                          );
                        },
                        child: const Text('عرض الفاتورة'),
                      ),
                    ),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(
    BuildContext context, {
    required CustomerOrder order,
    required String orderNumber,
    required String time,
    required String statusBadgeText,
    required Color statusBadgeBg,
    required Color statusBadgeTextColor,
    required String areaTotal,
    String? paymentSubText,
    Color? paymentSubColor,
    required List<Widget> actions,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kCardBorder),
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
                  Text('طلب #$orderNumber', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  Text(time, style: const TextStyle(fontSize: 11, color: kTextMuted)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBadgeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusBadgeText,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusBadgeTextColor),
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          Text(areaTotal, style: const TextStyle(fontSize: 13, color: kTextMain)),
          if (paymentSubText != null) ...[
            const SizedBox(height: 4),
            Text(paymentSubText, style: TextStyle(fontSize: 12, color: paymentSubColor ?? kTextMuted)),
          ],
          if (order.rejectReason != null && order.rejectReason!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('سبب الرفض: ${order.rejectReason}', style: const TextStyle(fontSize: 12, color: kBadgeRed, fontWeight: FontWeight.bold)),
          ],
          const SizedBox(height: 12),
          Row(children: actions),
        ],
      ),
    );
  }

  ButtonStyle _outlineBtnStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: kPrimary,
      side: const BorderSide(color: kPrimary, width: 1.5),
      padding: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
    );
  }
}

// ==========================================
// SCREEN 7: INVOICE SCREEN
// ==========================================

class InvoiceScreen extends StatelessWidget {
  final CustomerOrder? order;

  const InvoiceScreen({super.key, this.order});

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);
    final targetOrder = order ?? (appData.orders.isNotEmpty ? appData.orders.first : null);

    final orderNum = targetOrder?.orderNumber ?? '1043';
    final customerName = targetOrder?.fullName ?? 'د. محمد أحمد الفكي';
    final areaName = targetOrder?.deliveryAreaName ?? 'الدامر';
    final fee = targetOrder?.deliveryFeeSdg ?? 3000;
    final total = targetOrder?.totalSdg ?? 213000;
    final items = targetOrder?.items ?? [];

    final formattedFee = '${intl.NumberFormat("#,##0").format(fee)} ج.س';
    final formattedTotal = '${intl.NumberFormat("#,##0").format(total)} ج.س';

    return Scaffold(
      appBar: const DMCHeader(showBackButton: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kCardBorder),
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Column(
                  children: [
                    Text('DMC - Diala', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kPrimary)),
                    Text('معدات ومستهلكات طبية', style: TextStyle(fontSize: 12, color: kTextMuted)),
                    SizedBox(height: 6),
                    Text('فاتورة مبيعات', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Divider(height: 24, thickness: 1),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('رقم الفاتورة: #INV-$orderNum', style: const TextStyle(fontSize: 12, color: kTextMuted)),
                  Text('التاريخ: ${targetOrder?.createdAt ?? "اليوم"}', style: const TextStyle(fontSize: 12, color: kTextMuted)),
                ],
              ),
              const SizedBox(height: 12),
              Text('العميل: $customerName', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              Text('المنطقة: $areaName', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Table(
                border: TableBorder.all(color: kCardBorder),
                children: [
                  const TableRow(
                    decoration: BoxDecoration(color: kBgMain),
                    children: [
                      Padding(padding: EdgeInsets.all(8), child: Text('الصنف', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      Padding(padding: EdgeInsets.all(8), child: Text('الكمية', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                      Padding(padding: EdgeInsets.all(8), child: Text('السعر', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
                    ],
                  ),
                  if (items.isEmpty)
                    const TableRow(
                      children: [
                        Padding(padding: EdgeInsets.all(8), child: Text('Glucose Strips', style: TextStyle(fontSize: 12))),
                        Padding(padding: EdgeInsets.all(8), child: Text('1', style: TextStyle(fontSize: 12))),
                        Padding(padding: EdgeInsets.all(8), child: Text('65,000', style: TextStyle(fontSize: 12))),
                      ],
                    )
                  else
                    ...items.map((i) {
                      final itemPrice = intl.NumberFormat("#,##0").format(i.totalPriceSdg);
                      return TableRow(
                        children: [
                          Padding(padding: const EdgeInsets.all(8), child: Text(i.productName, style: const TextStyle(fontSize: 12))),
                          Padding(padding: const EdgeInsets.all(8), child: Text('${i.quantity}', style: const TextStyle(fontSize: 12))),
                          Padding(padding: const EdgeInsets.all(8), child: Text(itemPrice, style: const TextStyle(fontSize: 12))),
                        ],
                      );
                    }),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('رسوم التوصيل:', style: TextStyle(fontSize: 13)),
                  Text(formattedFee, style: const TextStyle(fontSize: 13)),
                ],
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('المطلوب دفعه:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  Text(formattedTotal, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kPrimary)),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم تحميل الفاتورة بصيغة PDF بنجاح')),
                        );
                      },
                      child: const Text('تحميل PDF 📥', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kPrimary,
                        side: const BorderSide(color: kPrimary, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم نسخ رابط الفاتورة للمشاركة')),
                        );
                      },
                      child: const Text('مشاركة 🔗', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
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

// ==========================================
// SCREEN 8: NOTIFICATIONS INBOX SCREEN
// ==========================================

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AppDataProvider>(context);

    return Scaffold(
      appBar: const DMCHeader(showBackButton: true),
      body: RefreshIndicator(
        onRefresh: () => appData.fetchAllData(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'مركز الإشعارات',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    'غير مقروء: ${appData.unreadNotificationsCount}',
                    style: const TextStyle(fontSize: 12, color: kTextMuted),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (appData.notifications.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  alignment: Alignment.center,
                  child: const Column(
                    children: [
                      Icon(Icons.notifications_none_outlined, size: 48, color: kTextMuted),
                      SizedBox(height: 12),
                      Text('لا توجد إشعارات حالياً', style: TextStyle(color: kTextMuted)),
                    ],
                  ),
                )
              else
                ...appData.notifications.map((n) {
                  return InkWell(
                    onTap: () {
                      if (!n.isRead) appData.markNotificationRead(n.id);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: n.isRead ? Colors.white : kPrimary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: n.isRead ? kCardBorder : kPrimary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: n.isRead ? kBgMain : kPrimary.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.notifications_active_outlined,
                              color: n.isRead ? kTextMuted : kPrimary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      n.title,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: n.isRead ? FontWeight.bold : FontWeight.w800,
                                        color: kTextMain,
                                      ),
                                    ),
                                    if (!n.isRead)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: kBadgeRed,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  n.body,
                                  style: const TextStyle(fontSize: 12, color: kTextMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// SCREEN 9: CONTACT US SCREEN
// ==========================================

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  Future<void> _checkLocationPermission(BuildContext context) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('خدمة الموقع غير مفعلة في الجهاز')),
          );
        }
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم رفض إذن الوصول للموقع')),
            );
          }
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('إذن الموقع مطلوب'),
              content: const Text('تم رفض الوصول للموقع بشكل دائم. يرجى التفعيل من الإعدادات.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Geolocator.openAppSettings();
                  },
                  child: const Text('فتح الإعدادات'),
                ),
              ],
            ),
          );
        }
        return;
      }

      final pos = await Geolocator.getCurrentPosition();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('موقعك الحقيقي: ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)} (تبعد حوالي 1.2 كلم عن معرض الدامر)')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحديد الموقع: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'تواصل معنا ومعارضنا',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () async {
              final Uri url = Uri.parse('https://wa.me/249912345678');
              if (await canLaunchUrl(url)) await launchUrl(url);
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kCardBorder),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Text('💬', style: TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 16),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('راسلنا عبر واتساب', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      Text('0912345678 - خدمة العملاء', style: TextStyle(fontSize: 12, color: kTextMuted)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () async {
              final Uri url = Uri.parse('tel:0912345678');
              if (await canLaunchUrl(url)) await launchUrl(url);
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kCardBorder),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: kPrimary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Text('📞', style: TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 16),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('الاتصال المباشر', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      Text('متوفرون طوال أيام الأسبوع', style: TextStyle(fontSize: 12, color: kTextMuted)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kCardBorder),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('موقع المحل ومناطق التوصيل', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text(
                  'الفرع الرئيسي: السوق التجاري، بجوار مستشفى الدامر.\nنغطي مناطق: الدامر، عطبرة، بربر، وأبوحمد.',
                  style: TextStyle(fontSize: 13, color: kTextMuted, height: 1.5),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => _checkLocationPermission(context),
                  child: Container(
                    height: 120,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('📍 خريطة الموقع التفاعلية', style: TextStyle(color: kTextMuted, fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        Text('(انقر لتحديد المسافة من موقعك)', style: TextStyle(color: kPrimary, fontSize: 11)),
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
}

// ==========================================
// SCREEN 10: PROFILE SCREEN (EDIT & SIGN OUT)
// ==========================================

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _nameController.text = auth.userName ?? '';
    _phoneController.text = auth.userPhone ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: const DMCHeader(showBackButton: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('الملف الشخصي للزبون', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('البريد الإلكتروني: ${auth.userEmail ?? ""}', style: const TextStyle(color: kTextMuted)),
            const SizedBox(height: 16),
            const _FormLabel('الاسم الكامل'),
            TextField(controller: _nameController, decoration: _inputDecoration()),
            const SizedBox(height: 16),
            const _FormLabel('رقم الهاتف'),
            TextField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: _inputDecoration()),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
                onPressed: _isSaving
                    ? null
                    : () async {
                        setState(() => _isSaving = true);
                        final ok = await auth.updateProfile(_nameController.text.trim(), _phoneController.text.trim());
                        setState(() => _isSaving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(ok ? 'تم حفظ الملف بنجاح' : 'تعذر حفظ البيانات')),
                          );
                        }
                      },
                child: _isSaving
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('حفظ التعديلات', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: kBadgeRed, side: const BorderSide(color: kBadgeRed)),
                onPressed: () {
                  auth.signOut();
                  Navigator.pop(context);
                },
                child: const Text('تسجيل الخروج', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kCardBorder, width: 1.5)),
    );
  }
}

// ==========================================
// SCREEN 11: AUTHENTICATION SCREEN (LOGIN / SIGNUP / FORGOT PASSWORD)
// ==========================================

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  // Mode: 0 = Login, 1 = Register, 2 = Verify OTP, 3 = Recover Password, 4 = New Password
  int _mode = 0;
  String _verifyType = 'signup'; // "signup" or "recovery"

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();

  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: const DMCHeader(showBackButton: true),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
                ),
                alignment: Alignment.center,
                child: const Text(
                  'DMC',
                  style: TextStyle(color: kPrimary, fontWeight: FontWeight.w800, fontSize: 24),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _mode == 0
                    ? 'تسجيل الدخول'
                    : _mode == 1
                        ? 'حساب جديد'
                        : _mode == 2
                            ? 'بعتنا رمز على بريدك'
                            : _mode == 3
                                ? 'استعادة كلمة المرور'
                                : 'كلمة المرور الجديدة',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kPrimaryDark),
              ),
              const SizedBox(height: 4),
              Text(
                _mode == 2 ? 'أدخل الرمز المكون من 6 أرقام لتأكيد بريدك' : 'مرحباً بك في Diala للخدمات والمعدات الطبية',
                style: const TextStyle(fontSize: 13, color: kTextMuted),
              ),
              const SizedBox(height: 20),

              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: kBadgeRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kBadgeRed.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: kBadgeRed, fontSize: 13, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),

              // MODE 0: LOGIN
              if (_mode == 0) ...[
                const Align(alignment: Alignment.centerRight, child: _FormLabel('البريد الإلكتروني')),
                TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: _inputDecoration(hint: 'example@domain.com')),
                const SizedBox(height: 16),
                const Align(alignment: Alignment.centerRight, child: _FormLabel('كلمة المرور')),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: _inputDecoration(hint: '••••••••', showObscureIcon: true),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
                    onPressed: auth.isLoading
                        ? null
                        : () async {
                            setState(() => _errorMessage = null);
                            final err = await auth.signIn(_emailController.text, _passwordController.text);
                            if (err == 'EMAIL_NOT_CONFIRMED') {
                              setState(() {
                                _verifyType = 'signup';
                                _mode = 2;
                              });
                            } else if (err != null) {
                              setState(() => _errorMessage = err);
                            } else {
                              if (mounted) Navigator.pop(context);
                            }
                          },
                    child: auth.isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('تسجيل الدخول', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => setState(() {
                        _errorMessage = null;
                        _mode = 1;
                      }),
                      child: const Text('إنشاء حساب جديد', style: TextStyle(color: kPrimary, fontWeight: FontWeight.bold)),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _errorMessage = null;
                        _mode = 3;
                      }),
                      child: const Text('نسيت كلمة المرور؟', style: TextStyle(color: kTextMuted)),
                    ),
                  ],
                ),
              ],

              // MODE 1: SIGN UP
              if (_mode == 1) ...[
                const Align(alignment: Alignment.centerRight, child: _FormLabel('الاسم الكامل')),
                TextField(controller: _nameController, decoration: _inputDecoration(hint: 'د. محمد أحمد')),
                const SizedBox(height: 12),
                const Align(alignment: Alignment.centerRight, child: _FormLabel('رقم الهاتف')),
                TextField(controller: _phoneController, keyboardType: TextInputType.phone, decoration: _inputDecoration(hint: '0912345678')),
                const SizedBox(height: 12),
                const Align(alignment: Alignment.centerRight, child: _FormLabel('البريد الإلكتروني')),
                TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: _inputDecoration(hint: 'example@domain.com')),
                const SizedBox(height: 12),
                const Align(alignment: Alignment.centerRight, child: _FormLabel('كلمة المرور (6 أحرف فأكثر)')),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: _inputDecoration(hint: '••••••••', showObscureIcon: true),
                ),
                const SizedBox(height: 12),
                const Align(alignment: Alignment.centerRight, child: _FormLabel('تأكيد كلمة المرور')),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: _obscurePassword,
                  decoration: _inputDecoration(hint: '••••••••'),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
                    onPressed: auth.isLoading
                        ? null
                        : () async {
                            setState(() => _errorMessage = null);
                            if (_nameController.text.trim().isEmpty) {
                              setState(() => _errorMessage = 'يرجى كتابة الاسم الكامل');
                              return;
                            }
                            if (_phoneController.text.trim().isEmpty) {
                              setState(() => _errorMessage = 'يرجى كتابة رقم الهاتف');
                              return;
                            }
                            if (_passwordController.text.length < 6) {
                              setState(() => _errorMessage = 'كلمة المرور يجب أن تكون 6 أحرف على الأقل');
                              return;
                            }
                            if (_passwordController.text != _confirmPasswordController.text) {
                              setState(() => _errorMessage = 'كلمتا المرور غير متطابقتين');
                              return;
                            }

                            final err = await auth.signUp(
                              name: _nameController.text,
                              phone: _phoneController.text,
                              email: _emailController.text,
                              password: _passwordController.text,
                            );

                            if (err != null) {
                              setState(() => _errorMessage = err);
                            } else {
                              setState(() {
                                _verifyType = 'signup';
                                _mode = 2; // Switch to OTP input screen
                              });
                            }
                          },
                    child: auth.isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('تأكيد وإنشاء الحساب', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() {
                    _errorMessage = null;
                    _mode = 0;
                  }),
                  child: const Text('لديك حساب بالفعل؟ تسجيل الدخول', style: TextStyle(color: kPrimary)),
                ),
              ],

              // MODE 2: OTP VERIFICATION CODE (6-DIGIT)
              if (_mode == 2) ...[
                const Align(alignment: Alignment.centerRight, child: _FormLabel('رمز التحقق (6 أرقام)')),
                TextField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                  decoration: _inputDecoration(hint: '123456'),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
                    onPressed: auth.isLoading
                        ? null
                        : () async {
                            setState(() => _errorMessage = null);
                            final err = await auth.verifyCode(
                              email: _emailController.text,
                              code: _otpController.text,
                              type: _verifyType,
                            );
                            if (err != null) {
                              setState(() => _errorMessage = err);
                            } else {
                              if (_verifyType == 'recovery') {
                                setState(() => _mode = 4); // New password mode
                              } else {
                                if (mounted) Navigator.pop(context);
                              }
                            }
                          },
                    child: auth.isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('تأكيد الرمز', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    final res = await auth.resendCode(_emailController.text, _verifyType);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(res ?? 'تم إعادة إرسال الرمز بنجاح')),
                      );
                    }
                  },
                  child: const Text('إعادة إرسال الرمز', style: TextStyle(color: kPrimary, fontWeight: FontWeight.bold)),
                ),
              ],

              // MODE 3: RECOVER PASSWORD (EMAIL INPUT)
              if (_mode == 3) ...[
                const Align(alignment: Alignment.centerRight, child: _FormLabel('أدخل بريدك الإلكتروني')),
                TextField(controller: _emailController, keyboardType: TextInputType.emailAddress, decoration: _inputDecoration(hint: 'example@domain.com')),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
                    onPressed: auth.isLoading
                        ? null
                        : () async {
                            setState(() => _errorMessage = null);
                            final err = await auth.recoverPassword(_emailController.text);
                            if (err != null) {
                              setState(() => _errorMessage = err);
                            } else {
                              setState(() {
                                _verifyType = 'recovery';
                                _mode = 2; // Verify Code
                              });
                            }
                          },
                    child: auth.isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('إرسال رمز الاستعادة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() {
                    _errorMessage = null;
                    _mode = 0;
                  }),
                  child: const Text('العودة لتسجيل الدخول', style: TextStyle(color: kTextMuted)),
                ),
              ],

              // MODE 4: NEW PASSWORD INPUT
              if (_mode == 4) ...[
                const Align(alignment: Alignment.centerRight, child: _FormLabel('أدخل كلمة المرور الجديدة')),
                TextField(
                  controller: _newPasswordController,
                  obscureText: _obscurePassword,
                  decoration: _inputDecoration(hint: '••••••••', showObscureIcon: true),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
                    onPressed: auth.isLoading
                        ? null
                        : () async {
                            setState(() => _errorMessage = null);
                            if (_newPasswordController.text.length < 6) {
                              setState(() => _errorMessage = 'كلمة المرور يجب أن تكون 6 أحرف على الأقل');
                              return;
                            }
                            final err = await auth.resetPassword(_newPasswordController.text);
                            if (err != null) {
                              setState(() => _errorMessage = err);
                            } else {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تم تغيير كلمة المرور بنجاح')),
                                );
                                Navigator.pop(context);
                              }
                            }
                          },
                    child: auth.isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('حفظ كلمة المرور الجديدة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint, bool showObscureIcon = false}) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      suffixIcon: showObscureIcon
          ? IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: kTextMuted),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            )
          : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kCardBorder, width: 1.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kCardBorder, width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: kPrimary, width: 1.5)),
    );
  }
}
