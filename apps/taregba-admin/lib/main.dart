import 'dart:async';
import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_config.dart';

// --- BACKEND & CONSTANTS ---
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
  } catch (e) {
    debugPrint("Firebase init note: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, AdminAppDataProvider>(
          create: (_) => AdminAppDataProvider(null),
          update: (_, auth, previous) => (previous ?? AdminAppDataProvider(auth))..updateAuth(auth),
        ),
      ],
      child: const DmcAdminApp(),
    ),
  );
}

class DmcAdminApp extends StatelessWidget {
  const DmcAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DMC الإدارة - Diala Medical Equipment',
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
      home: const RootGateScreen(),
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
  final int lowStockThreshold;
  final String imageUrl;
  final bool isVisible;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.priceUsd,
    required this.stockQuantity,
    required this.lowStockThreshold,
    required this.imageUrl,
    required this.isVisible,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? '',
      category: json['category'] ?? 'مستلزمات طبية',
      description: json['description'] ?? '',
      priceUsd: (json['price_usd'] ?? 0).toDouble(),
      stockQuantity: json['stock_quantity'] ?? 0,
      lowStockThreshold: json['low_stock_threshold'] ?? 5,
      imageUrl: json['image_url'] ?? '',
      isVisible: json['is_visible'] ?? true,
    );
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

class BankSettingsModel {
  final String bankName;
  final String accountNumber;
  final String accountHolder;
  final String customerNote;

  BankSettingsModel({
    required this.bankName,
    required this.accountNumber,
    required this.accountHolder,
    required this.customerNote,
  });

  factory BankSettingsModel.fromJson(Map<String, dynamic> json) {
    return BankSettingsModel(
      bankName: json['bank_name'] ?? 'بنك الخرطوم',
      accountNumber: json['account_number'] ?? '',
      accountHolder: json['account_holder'] ?? 'شركة ديالا للمعدات الطبية',
      customerNote: json['customer_note'] ?? '',
    );
  }
}

class CustomerOrder {
  final int id;
  final String orderNumber;
  final String customerId;
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

  CustomerOrder({
    required this.id,
    required this.orderNumber,
    required this.customerId,
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
  });

  factory CustomerOrder.fromJson(Map<String, dynamic> json) {
    return CustomerOrder(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      orderNumber: json['order_number']?.toString() ?? '',
      customerId: json['customer_id']?.toString() ?? '',
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

class PurchaseRecord {
  final int id;
  final String supplierName;
  final String purchaseDate;
  final double totalAmountSdg;
  final String paymentStatus;
  final String? invoiceImageUrl;

  PurchaseRecord({
    required this.id,
    required this.supplierName,
    required this.purchaseDate,
    required this.totalAmountSdg,
    required this.paymentStatus,
    this.invoiceImageUrl,
  });

  factory PurchaseRecord.fromJson(Map<String, dynamic> json) {
    return PurchaseRecord(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      supplierName: json['supplier_name'] ?? '',
      purchaseDate: json['purchase_date'] ?? '',
      totalAmountSdg: (json['total_amount_sdg'] ?? 0).toDouble(),
      paymentStatus: json['payment_status'] ?? 'آجل',
      invoiceImageUrl: json['invoice_image_url'],
    );
  }
}

class AppNotification {
  final int id;
  final String? toUser;
  final String? toRole;
  final String title;
  final String body;
  final dynamic data;
  final String? readAt;
  final String createdAt;

  AppNotification({
    required this.id,
    this.toUser,
    this.toRole,
    required this.title,
    required this.body,
    this.data,
    this.readAt,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      toUser: json['to_user']?.toString(),
      toRole: json['to_role']?.toString(),
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      data: json['data'],
      readAt: json['read_at']?.toString(),
      createdAt: json['created_at'] ?? '',
    );
  }

  bool get isRead => readAt != null;
}

// ==========================================
// AUTH PROVIDER
// ==========================================
class AuthProvider extends ChangeNotifier {
  String? _accessToken;
  String? _refreshToken;
  String? _userId;
  String? _userEmail;
  String? _userRole;
  bool _isLoading = false;
  bool _isLoggedIn = false;
  bool _isAdminUnlocked = false;

  bool get isAuthenticated => _isLoggedIn;
  String? get accessToken => _accessToken;
  String? get userId => _userId;
  String? get userEmail => _userEmail;
  String? get userRole => _userRole;
  bool get isLoading => _isLoading;
  bool get isAdminUnlocked => _isAdminUnlocked || _userRole == 'admin';

  AuthProvider() {
    _loadSession();
  }

  Map<String, String> get authHeaders => {
        'apikey': kSupabaseAnonKey,
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      };

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    _refreshToken = prefs.getString('refresh_token');
    _userId = prefs.getString('user_id');
    _userEmail = prefs.getString('user_email');
    _userRole = prefs.getString('user_role');
    _isAdminUnlocked = prefs.getBool('is_admin_unlocked') ?? false;

    if (_accessToken != null && _accessToken!.isNotEmpty) {
      _isLoggedIn = true;
      notifyListeners();
      await _initPostLoginTasks();
    }
    notifyListeners();
  }

  String _handleAuthError(dynamic responseBody, int statusCode, {bool isVerify = false}) {
    try {
      final decoded = jsonDecode(responseBody);
      final msg = decoded['error_description'] ?? decoded['msg'] ?? decoded['message'] ?? decoded['error'];
      if (msg != null) {
        final str = msg.toString().toLowerCase();
        if (str.contains('rate limit') || str.contains('too many requests')) {
          return 'اتبعتت رسائل كتير، استنى دقايق';
        }
        if (str.contains('smtp') || str.contains('email rate limit') || str.contains('error sending') || str.contains('sending')) {
          return 'ما قدرنا نرسل البريد';
        }
        if (isVerify && (str.contains('invalid') || str.contains('expired') || str.contains('token'))) {
          return 'رمز التحقق غير صحيح أو انتهت صلاحيته';
        }
        return msg.toString();
      }
    } catch (_) {}
    if (isVerify) return 'رمز التحقق غير صحيح أو انتهت صلاحيته';
    if (statusCode == 401) return 'انتهت صلاحية الجلسة أو بيانات الدخول غير صحيحة';
    return 'حدث خطأ في الاتصال بالسيرفر ($statusCode)';
  }

  Future<bool> refreshToken() async {
    if (_refreshToken == null) return false;
    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/token?grant_type=refresh_token'),
        headers: {'apikey': kSupabaseAnonKey, 'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': _refreshToken}),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        _accessToken = body['access_token'];
        _refreshToken = body['refresh_token'] ?? _refreshToken;
        final prefs = await SharedPreferences.getInstance();
        if (_accessToken != null) await prefs.setString('access_token', _accessToken!);
        if (_refreshToken != null) await prefs.setString('refresh_token', _refreshToken!);
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<String?> signUp({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/signup'),
        headers: {'apikey': kSupabaseAnonKey, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
          'data': {'full_name': name.trim(), 'phone': phone.trim()}
        }),
      );
      _isLoading = false;
      notifyListeners();
      if (res.statusCode == 200 || res.statusCode == 201) {
        return null;
      }
      return _handleAuthError(res.body, res.statusCode);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'تعذر الاتصال بالخادم: $e';
    }
  }

  Future<String?> resendCode(String email) async {
    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/resend'),
        headers: {'apikey': kSupabaseAnonKey, 'Content-Type': 'application/json'},
        body: jsonEncode({'type': 'signup', 'email': email.trim()}),
      );
      if (res.statusCode == 200) return null;
      return _handleAuthError(res.body, res.statusCode);
    } catch (e) {
      return 'تعذر إعادة إرسال الرمز: $e';
    }
  }

  Future<String?> verifySignup(String email, String code) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/verify'),
        headers: {'apikey': kSupabaseAnonKey, 'Content-Type': 'application/json'},
        body: jsonEncode({'type': 'signup', 'email': email.trim(), 'token': code.trim()}),
      );
      _isLoading = false;
      notifyListeners();
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        await _saveSessionFromData(body, email);
        return null;
      }
      return _handleAuthError(res.body, res.statusCode, isVerify: true);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'رمز التحقق غير صحيح أو انتهت صلاحيته';
    }
  }

  Future<String?> signIn(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/token?grant_type=password'),
        headers: {'apikey': kSupabaseAnonKey, 'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'password': password}),
      );
      _isLoading = false;
      notifyListeners();

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        await _saveSessionFromData(body, email);
        return null;
      } else {
        final errStr = res.body;
        if (errStr.contains('Email not confirmed') || errStr.contains('not_confirmed')) {
          await resendCode(email);
          return 'EMAIL_NOT_CONFIRMED';
        }
        return _handleAuthError(res.body, res.statusCode);
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'تعذر الاتصال بالخادم: $e';
    }
  }

  Future<String?> recoverPassword(String email) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/recover'),
        headers: {'apikey': kSupabaseAnonKey, 'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim()}),
      );
      _isLoading = false;
      notifyListeners();
      if (res.statusCode == 200) return null;
      return _handleAuthError(res.body, res.statusCode);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'تعذر إرسال طلب استعادة المرور: $e';
    }
  }

  Future<String?> verifyRecovery(String email, String code) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/verify'),
        headers: {'apikey': kSupabaseAnonKey, 'Content-Type': 'application/json'},
        body: jsonEncode({'type': 'recovery', 'email': email.trim(), 'token': code.trim()}),
      );
      _isLoading = false;
      notifyListeners();
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        await _saveSessionFromData(body, email);
        return null;
      }
      return _handleAuthError(res.body, res.statusCode, isVerify: true);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'رمز الاستعادة غير صحيح أو انتهت صلاحيته';
    }
  }

  Future<String?> updatePassword(String newPassword) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await http.put(
        Uri.parse('$kSupabaseUrl/auth/v1/user'),
        headers: authHeaders,
        body: jsonEncode({'password': newPassword}),
      );
      _isLoading = false;
      notifyListeners();
      if (res.statusCode == 200) return null;
      return _handleAuthError(res.body, res.statusCode);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return 'تعذر تحديث كلمة المرور: $e';
    }
  }

  Future<void> _saveSessionFromData(Map<String, dynamic> body, String email) async {
    _accessToken = body['access_token'];
    _refreshToken = body['refresh_token'];
    _userId = body['user']?['id'];
    _userEmail = email;
    _isLoggedIn = true;

    final prefs = await SharedPreferences.getInstance();
    if (_accessToken != null) await prefs.setString('access_token', _accessToken!);
    if (_refreshToken != null) await prefs.setString('refresh_token', _refreshToken!);
    if (_userId != null) await prefs.setString('user_id', _userId!);
    if (_userEmail != null) await prefs.setString('user_email', _userEmail!);

    await _initPostLoginTasks();
    notifyListeners();
  }

  Future<void> _initPostLoginTasks() async {
    // 1. Call taregba_claim_admin {}
    await _claimAdminRpc(null);
    // 2. Read profile again
    await fetchProfile();
    // 3. Register device for push
    await _registerDevicePush();
  }

  Future<void> fetchProfile() async {
    if (_userId == null) return;
    try {
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/taregba_profiles?id=eq.$_userId&select=*'),
        headers: authHeaders,
      );
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        if (list.isNotEmpty) {
          _userRole = list.first['role'];
          final prefs = await SharedPreferences.getInstance();
          if (_userRole != null) await prefs.setString('user_role', _userRole!);
          if (_userRole == 'admin') {
            _isAdminUnlocked = true;
            await prefs.setBool('is_admin_unlocked', true);
          }
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  Future<bool> _claimAdminRpc(String? pin) async {
    if (_accessToken == null) return false;
    try {
      final bodyMap = pin != null ? {'pin': pin} : <String, dynamic>{};
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/rest/v1/rpc/taregba_claim_admin'),
        headers: authHeaders,
        body: jsonEncode(bodyMap),
      );
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        bool success = false;
        if (decoded is bool) {
          success = decoded;
        } else if (decoded.toString().toLowerCase() == 'true') {
          success = true;
        }
        if (success) {
          _isAdminUnlocked = true;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('is_admin_unlocked', true);
          await fetchProfile();
          notifyListeners();
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  Future<bool> tryClaimAdminWithPin(String pin) async {
    final ok = await _claimAdminRpc(pin);
    if (ok) {
      await fetchProfile();
    }
    return ok;
  }

  Future<void> _registerDevicePush() async {
    try {
      await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && _accessToken != null) {
        await http.post(
          Uri.parse('$kSupabaseUrl/rest/v1/rpc/taregba_register_device'),
          headers: authHeaders,
          body: jsonEncode({'device_token': token, 'app_name': 'admin'}),
        );
      }
    } catch (_) {}
  }

  Future<void> signOut() async {
    _accessToken = null;
    _refreshToken = null;
    _userId = null;
    _userEmail = null;
    _userRole = null;
    _isLoggedIn = false;
    _isAdminUnlocked = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}

// ==========================================
// ADMIN APP DATA PROVIDER (LIVE SYNC)
// ==========================================
class AdminAppDataProvider extends ChangeNotifier {
  AuthProvider? _auth;
  bool _isLoading = false;
  Timer? _syncTimer;

  double _usdRate = 2500.0;
  List<DeliveryArea> _deliveryAreas = [];
  List<Product> _products = [];
  List<CustomerOrder> _orders = [];
  List<PurchaseRecord> _purchases = [];
  BankSettingsModel _bankSettings = BankSettingsModel(
    bankName: 'بنك الخرطوم',
    accountNumber: '',
    accountHolder: 'شركة ديالا للمعدات الطبية',
    customerNote: 'يرجى إرفاق صورة إشعار التحويل الواضحة للبدء في تجهيز طلبكم مباشرة.',
  );
  List<AppNotification> _notifications = [];

  AdminAppDataProvider(this._auth) {
    if (_auth != null && _auth!.isAuthenticated) {
      fetchAllData();
      _startSyncTimer();
      _setupFirebaseListeners();
    }
  }

  void updateAuth(AuthProvider auth) {
    _auth = auth;
    if (_auth != null && _auth!.isAuthenticated && _syncTimer == null) {
      fetchAllData();
      _startSyncTimer();
      _setupFirebaseListeners();
    } else if (_auth == null || !_auth!.isAuthenticated) {
      _stopSyncTimer();
    }
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_auth != null && _auth!.isAuthenticated) {
        fetchNotificationsQuiet();
        fetchCurrentScreenDataQuiet();
      }
    });
  }

  void _stopSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  void _setupFirebaseListeners() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      fetchNotificationsQuiet();
      fetchCurrentScreenDataQuiet();
    });
  }

  @override
  void dispose() {
    _stopSyncTimer();
    super.dispose();
  }

  bool get isLoading => _isLoading;
  double get usdRate => _usdRate;
  List<DeliveryArea> get deliveryAreas => _deliveryAreas;
  List<Product> get products => _products;
  List<CustomerOrder> get orders => _orders;
  List<PurchaseRecord> get purchases => _purchases;
  BankSettingsModel get bankSettings => _bankSettings;
  List<AppNotification> get notifications => _notifications;

  int get unreadNotificationsCount => _notifications.where((n) => !n.isRead).length;
  int get newOrdersCount => _orders.where((o) => o.status == 'جديد' || o.paymentStatus == 'pending').length;

  Future<void> fetchAllData() async {
    _isLoading = true;
    notifyListeners();
    await Future.wait([
      fetchSettings(),
      fetchDeliveryAreas(),
      fetchProducts(),
      fetchOrders(),
      fetchPurchases(),
      fetchBankSettings(),
      fetchNotificationsQuiet(),
    ]);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchCurrentScreenDataQuiet() async {
    await Future.wait([
      fetchOrders(),
      fetchProducts(),
      fetchSettings(),
    ]);
  }

  Future<void> fetchSettings() async {
    try {
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/taregba_settings?select=*'),
        headers: _auth?.authHeaders ?? {'apikey': kSupabaseAnonKey},
      );
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        for (var item in list) {
          if (item['setting_key'] == 'usd_rate' || item['setting_key'] == 'dollar_rate') {
            _usdRate = double.tryParse(item['setting_value'].toString()) ?? 2500.0;
          }
        }
      }
    } catch (_) {}
  }

  Future<void> fetchDeliveryAreas() async {
    try {
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/taregba_delivery_areas?select=*&order=created_at.desc'),
        headers: _auth?.authHeaders ?? {'apikey': kSupabaseAnonKey},
      );
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        _deliveryAreas = list.map((e) => DeliveryArea.fromJson(e)).toList();
      }
    } catch (_) {}
  }

  Future<void> fetchProducts() async {
    try {
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/taregba_products?select=*&order=created_at.desc'),
        headers: _auth?.authHeaders ?? {'apikey': kSupabaseAnonKey},
      );
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        _products = list.map((e) => Product.fromJson(e)).toList();
      }
    } catch (_) {}
  }

  Future<void> fetchOrders() async {
    try {
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/taregba_orders?select=*&order=created_at.desc'),
        headers: _auth?.authHeaders ?? {'apikey': kSupabaseAnonKey},
      );
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        _orders = list.map((e) => CustomerOrder.fromJson(e)).toList();
      }
    } catch (_) {}
  }

  Future<void> fetchPurchases() async {
    try {
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/taregba_purchases?select=*&order=created_at.desc'),
        headers: _auth?.authHeaders ?? {'apikey': kSupabaseAnonKey},
      );
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        _purchases = list.map((e) => PurchaseRecord.fromJson(e)).toList();
      }
    } catch (_) {}
  }

  Future<void> fetchBankSettings() async {
    try {
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/taregba_bank_settings?select=*'),
        headers: _auth?.authHeaders ?? {'apikey': kSupabaseAnonKey},
      );
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        if (list.isNotEmpty) {
          _bankSettings = BankSettingsModel.fromJson(list.first);
        }
      }
    } catch (_) {}
  }

  Future<void> fetchNotificationsQuiet() async {
    if (_auth?.userId == null) return;
    try {
      final uid = _auth!.userId;
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/taregba_notifications?or=(to_user.eq.$uid,to_role.eq.admin)&order=created_at.desc'),
        headers: _auth!.authHeaders,
      );
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        _notifications = list.map((e) => AppNotification.fromJson(e)).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> markNotificationRead(int id) async {
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      await http.patch(
        Uri.parse('$kSupabaseUrl/rest/v1/taregba_notifications?id=eq.$id'),
        headers: _auth!.authHeaders,
        body: jsonEncode({'read_at': nowIso}),
      );
      await fetchNotificationsQuiet();
    } catch (_) {}
  }

  Future<void> sendNotificationToCustomer({
    required String customerId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await http.post(
        Uri.parse('$kSupabaseUrl/rest/v1/taregba_notifications'),
        headers: _auth!.authHeaders,
        body: jsonEncode({
          'to_user': customerId,
          'title': title,
          'body': body,
          'data': data ?? {},
        }),
      );
    } catch (_) {}
  }

  Future<void> updateUsdRate(double newRate) async {
    _usdRate = newRate;
    notifyListeners();
    try {
      await http.patch(
        Uri.parse('$kSupabaseUrl/rest/v1/taregba_settings?setting_key=eq.usd_rate'),
        headers: _auth!.authHeaders,
        body: jsonEncode({'setting_value': newRate.toString(), 'updated_at': DateTime.now().toUtc().toIso8601String()}),
      );
    } catch (_) {}
  }

  Future<void> updateDeliveryFee(int id, double fee) async {
    try {
      await http.patch(
        Uri.parse('$kSupabaseUrl/rest/v1/taregba_delivery_areas?id=eq.$id'),
        headers: _auth!.authHeaders,
        body: jsonEncode({'delivery_fee_sdg': fee}),
      );
      await fetchDeliveryAreas();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> addDeliveryArea(String name, double fee) async {
    try {
      await http.post(
        Uri.parse('$kSupabaseUrl/rest/v1/taregba_delivery_areas'),
        headers: _auth!.authHeaders,
        body: jsonEncode({'name': name, 'delivery_fee_sdg': fee, 'is_active': true}),
      );
      await fetchDeliveryAreas();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> saveProduct({
    int? id,
    required String name,
    required String category,
    required String description,
    required double priceUsd,
    required int stockQuantity,
    required int lowStockThreshold,
    required String imageUrl,
  }) async {
    try {
      if (id != null) {
        await http.patch(
          Uri.parse('$kSupabaseUrl/rest/v1/taregba_products?id=eq.$id'),
          headers: _auth!.authHeaders,
          body: jsonEncode({
            'name': name,
            'category': category,
            'description': description,
            'price_usd': priceUsd,
            'stock_quantity': stockQuantity,
            'low_stock_threshold': lowStockThreshold,
            'image_url': imageUrl,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }),
        );
      } else {
        await http.post(
          Uri.parse('$kSupabaseUrl/rest/v1/taregba_products'),
          headers: _auth!.authHeaders,
          body: jsonEncode({
            'name': name,
            'category': category,
            'description': description,
            'price_usd': priceUsd,
            'stock_quantity': stockQuantity,
            'low_stock_threshold': lowStockThreshold,
            'image_url': imageUrl,
            'is_visible': true,
          }),
        );
      }
      await fetchProducts();
    } catch (_) {}
  }

  Future<void> addPurchase({
    required String supplierName,
    required double totalAmountSdg,
    required String paymentStatus,
    String? invoiceImageUrl,
  }) async {
    try {
      await http.post(
        Uri.parse('$kSupabaseUrl/rest/v1/taregba_purchases'),
        headers: _auth!.authHeaders,
        body: jsonEncode({
          'supplier_name': supplierName,
          'purchase_date': DateTime.now().toIso8601String().substring(0, 10),
          'total_amount_sdg': totalAmountSdg,
          'payment_status': paymentStatus,
          'invoice_image_url': invoiceImageUrl,
          'created_by': _auth?.userId,
        }),
      );
      await fetchPurchases();
    } catch (_) {}
  }

  Future<void> reviewPayment(int orderId, bool confirm, String? reason, CustomerOrder order) async {
    try {
      final newStatus = confirm ? 'قيد التجهيز' : 'ملغي';
      final newPaymentStatus = confirm ? 'confirmed' : 'rejected';
      await http.patch(
        Uri.parse('$kSupabaseUrl/rest/v1/taregba_orders?id=eq.$orderId'),
        headers: _auth!.authHeaders,
        body: jsonEncode({
          'status': newStatus,
          'payment_status': newPaymentStatus,
          'reject_reason': reason,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }),
      );

      final notifTitle = confirm ? 'تم تأكيد الدفع وجاري تجهيز طلبك' : 'تم رفض إشعار التحويل البنكي';
      final notifBody = confirm
          ? 'تم تأكيد إشعار التحويل للطلب #${order.orderNumber} وجاري العمل على تجهيز طلبك.'
          : 'عذراً، تم رفض إشعار التحويل. السبب: ${reason ?? "غير متطابق"}';

      await sendNotificationToCustomer(
        customerId: order.customerId,
        title: notifTitle,
        body: notifBody,
        data: {'order_id': orderId, 'order_number': order.orderNumber},
      );

      await fetchOrders();
    } catch (_) {}
  }

  Future<void> updateOrderStatus(int orderId, String newStatus, CustomerOrder order) async {
    try {
      await http.patch(
        Uri.parse('$kSupabaseUrl/rest/v1/taregba_orders?id=eq.$orderId'),
        headers: _auth!.authHeaders,
        body: jsonEncode({
          'status': newStatus,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }),
      );

      await sendNotificationToCustomer(
        customerId: order.customerId,
        title: 'تحديث جديد على حالة طلبك',
        body: 'تم تغيير حالة طلبك #${order.orderNumber} إلى: $newStatus',
        data: {'order_id': orderId, 'order_number': order.orderNumber, 'status': newStatus},
      );

      await fetchOrders();
    } catch (_) {}
  }

  Future<void> sendBroadcastPromo(String title, String message) async {
    try {
      await http.post(
        Uri.parse('$kSupabaseUrl/rest/v1/taregba_promotions'),
        headers: _auth!.authHeaders,
        body: jsonEncode({
          'title': title,
          'message': message,
          'created_by': _auth?.userId,
        }),
      );

      await http.post(
        Uri.parse('$kSupabaseUrl/rest/v1/taregba_notifications'),
        headers: _auth!.authHeaders,
        body: jsonEncode({
          'to_role': 'customer',
          'title': title,
          'body': message,
          'data': {'type': 'broadcast'},
        }),
      );
    } catch (_) {}
  }
}

// ==========================================
// ROOT GATE & AUTH SCREENS
// ==========================================
class RootGateScreen extends StatelessWidget {
  const RootGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (!auth.isAuthenticated) {
          return const AuthWelcomeScreen();
        }
        if (!auth.isAdminUnlocked) {
          return const AdminPinEntryScreen();
        }
        return const MainAdminNavigation();
      },
    );
  }
}

class AdminPinEntryScreen extends StatefulWidget {
  const AdminPinEntryScreen({super.key});

  @override
  State<AdminPinEntryScreen> createState() => _AdminPinEntryScreenState();
}

class _AdminPinEntryScreenState extends State<AdminPinEntryScreen> {
  final _pinCtrl = TextEditingController();
  String? _errorMsg;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    return Scaffold(
      backgroundColor: kBgMain,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: kCardBorder)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('دخول الإدارة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kPrimaryDark)),
                    const SizedBox(height: 6),
                    const Text('أدخل رمز الإدارة للمتابعة', style: TextStyle(fontSize: 12, color: kTextMuted)),
                    const SizedBox(height: 20),
                    if (_errorMsg != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(color: kBadgeRed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text(_errorMsg!, style: const TextStyle(color: kBadgeRed, fontSize: 12)),
                      ),
                    TextField(
                      controller: _pinCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'رمز الإدارة',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
                        onPressed: _isLoading
                            ? null
                            : () async {
                                setState(() {
                                  _isLoading = true;
                                  _errorMsg = null;
                                });
                                final success = await auth.tryClaimAdminWithPin(_pinCtrl.text.trim());
                                setState(() => _isLoading = false);
                                if (!success && mounted) {
                                  setState(() => _errorMsg = 'رمز الإدارة غير صحيح');
                                }
                              },
                        child: _isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('دخول', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => auth.signOut(),
                      child: const Text('تسجيل الخروج بحساب آخر', style: TextStyle(fontSize: 12, color: kTextMuted)),
                    ),
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

class AuthWelcomeScreen extends StatelessWidget {
  const AuthWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBgMain,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: kCardBorder)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(12)),
                      alignment: Alignment.center,
                      child: const Text('DMC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22)),
                    ),
                    const SizedBox(height: 16),
                    const Text('تطبيق إدارة DMC', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kPrimaryDark)),
                    const SizedBox(height: 6),
                    const Text('ديالا للمعدات الطبية والكيماوية', style: TextStyle(fontSize: 13, color: kTextMuted)),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DedicatedLoginScreen())),
                        child: const Text('تسجيل الدخول', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: kPrimary,
                          side: const BorderSide(color: kPrimary, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUpScreen())),
                        child: const Text('حساب جديد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                      child: const Text('نسيت كلمة المرور؟', style: TextStyle(color: kTextMuted, fontSize: 13)),
                    ),
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

// ==========================================
// AUTH SCREENS (SIGN IN, SIGN UP, OTP, RECOVER)
// ==========================================
class DedicatedLoginScreen extends StatefulWidget {
  const DedicatedLoginScreen({super.key});

  @override
  State<DedicatedLoginScreen> createState() => _DedicatedLoginScreenState();
}

class _DedicatedLoginScreenState extends State<DedicatedLoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;
  String? _errorMsg;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل الدخول')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: kCardBorder)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('تسجيل الدخول', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kPrimaryDark)),
                    const SizedBox(height: 16),
                    if (_errorMsg != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(color: kBadgeRed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text(_errorMsg!, style: const TextStyle(color: kBadgeRed, fontSize: 12)),
                      ),
                    const Text('البريد الإلكتروني', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kTextMain)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('كلمة المرور', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: kTextMain)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _passCtrl,
                      obscureText: _obscurePass,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility, size: 20),
                          onPressed: () => setState(() => _obscurePass = !_obscurePass),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
                        onPressed: auth.isLoading
                            ? null
                            : () async {
                                final email = _emailCtrl.text.trim();
                                if (email.isEmpty) {
                                  setState(() => _errorMsg = 'يرجى إدخال البريد الإلكتروني');
                                  return;
                                }
                                setState(() => _errorMsg = null);

                                final err = await auth.signIn(email, _passCtrl.text);
                                if (err == 'EMAIL_NOT_CONFIRMED' && mounted) {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => OtpVerifyScreen(email: email)));
                                } else if (err != null && mounted) {
                                  setState(() => _errorMsg = err);
                                } else if (mounted) {
                                  Navigator.pop(context);
                                }
                              },
                        child: auth.isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('دخول', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
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

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscurePass = true;
  String? _nameErr, _phoneErr, _emailErr, _passErr, _generalErr;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('حساب جديد')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: kCardBorder)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('إنشاء حساب جديد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kPrimaryDark)),
                    const SizedBox(height: 14),
                    if (_generalErr != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(color: kBadgeRed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text(_generalErr!, style: const TextStyle(color: kBadgeRed, fontSize: 12)),
                      ),
                    const Text('الاسم الكامل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        errorText: _nameErr,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('رقم الهاتف', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        errorText: _phoneErr,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('البريد الإلكتروني', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        errorText: _emailErr,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('كلمة المرور (6+ أحرف)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _passCtrl,
                      obscureText: _obscurePass,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        errorText: _passErr,
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility, size: 20),
                          onPressed: () => setState(() => _obscurePass = !_obscurePass),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('تأكيد كلمة المرور', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _confirmPassCtrl,
                      obscureText: _obscurePass,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
                        onPressed: auth.isLoading
                            ? null
                            : () async {
                                setState(() {
                                  _nameErr = _nameCtrl.text.trim().isEmpty ? 'حقل مطلوب' : null;
                                  _phoneErr = _phoneCtrl.text.trim().isEmpty ? 'حقل مطلوب' : null;
                                  _emailErr = _emailCtrl.text.trim().isEmpty ? 'حقل مطلوب' : null;
                                  _passErr = _passCtrl.text.length < 6 ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل' : null;
                                  _generalErr = null;
                                });
                                if (_passCtrl.text != _confirmPassCtrl.text) {
                                  setState(() => _generalErr = 'كلمتا المرور غير متطابقتين');
                                  return;
                                }
                                if (_nameErr == null && _phoneErr == null && _emailErr == null && _passErr == null) {
                                  final err = await auth.signUp(
                                    name: _nameCtrl.text,
                                    phone: _phoneCtrl.text,
                                    email: _emailCtrl.text,
                                    password: _passCtrl.text,
                                  );
                                  if (err == null && mounted) {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(builder: (_) => OtpVerifyScreen(email: _emailCtrl.text.trim())),
                                    );
                                  } else if (err != null && mounted) {
                                    setState(() => _generalErr = err);
                                  }
                                }
                              },
                        child: auth.isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('تسجيل وحفظ', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
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

class OtpVerifyScreen extends StatefulWidget {
  final String email;
  const OtpVerifyScreen({super.key, required this.email});

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final _codeCtrl = TextEditingController();
  String? _errorMsg;
  int _resendCountdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    setState(() => _resendCountdown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
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

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('تأكيد البريد الإلكتروني')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: kCardBorder)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('بعتنا رمز على بريدك', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kPrimaryDark)),
                    const SizedBox(height: 6),
                    Text('أدخل الرمز المكون من 6 أرقام المرسل إلى\n${widget.email}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: kTextMuted)),
                    const SizedBox(height: 20),
                    if (_errorMsg != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(color: kBadgeRed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text(_errorMsg!, style: const TextStyle(color: kBadgeRed, fontSize: 12)),
                      ),
                    TextField(
                      controller: _codeCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 8),
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
                        onPressed: auth.isLoading
                            ? null
                            : () async {
                                setState(() => _errorMsg = null);
                                final err = await auth.verifySignup(widget.email, _codeCtrl.text);
                                if (err != null && mounted) {
                                  setState(() => _errorMsg = err);
                                } else if (mounted) {
                                  Navigator.of(context).popUntil((route) => route.isFirst);
                                }
                              },
                        child: auth.isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('تأكيد الرمز', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextButton(
                      onPressed: _resendCountdown > 0
                          ? null
                          : () async {
                              final err = await auth.resendCode(widget.email);
                              if (err == null) {
                                _startCountdown();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إعادة إرسال الرمز بنجاح')));
                                }
                              } else {
                                setState(() => _errorMsg = err);
                              }
                            },
                      child: Text(
                        _resendCountdown > 0 ? 'إعادة الإرسال بعد $_resendCountdown ثانية' : 'إعادة إرسال الرمز',
                        style: TextStyle(color: _resendCountdown > 0 ? kTextMuted : kPrimary, fontWeight: FontWeight.bold),
                      ),
                    ),
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

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  int _step = 1;
  String? _errorMsg;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('استعادة كلمة المرور')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: kCardBorder)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_errorMsg != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(color: kBadgeRed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text(_errorMsg!, style: const TextStyle(color: kBadgeRed, fontSize: 12)),
                      ),
                    if (_step == 1) ...[
                      const Text('استعادة كلمة المرور', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kPrimaryDark)),
                      const SizedBox(height: 6),
                      const Text('أدخل بريدك الإلكتروني لتلقي رمز الاستعادة', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: kTextMuted)),
                      const SizedBox(height: 16),
                      TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'البريد الإلكتروني')),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
                          onPressed: auth.isLoading
                              ? null
                              : () async {
                                  setState(() => _errorMsg = null);
                                  final err = await auth.recoverPassword(_emailCtrl.text);
                                  if (err == null) {
                                    setState(() => _step = 2);
                                  } else {
                                    setState(() => _errorMsg = err);
                                  }
                                },
                          child: const Text('إرسال الرمز'),
                        ),
                      ),
                    ] else if (_step == 2) ...[
                      const Text('أدخل رمز التحقق', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kPrimaryDark)),
                      const SizedBox(height: 16),
                      TextField(controller: _codeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الرمز (6 أرقام)')),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
                          onPressed: auth.isLoading
                              ? null
                              : () async {
                                  setState(() => _errorMsg = null);
                                  final err = await auth.verifyRecovery(_emailCtrl.text, _codeCtrl.text);
                                  if (err == null) {
                                    setState(() => _step = 3);
                                  } else {
                                    setState(() => _errorMsg = err);
                                  }
                                },
                          child: const Text('تحقق من الرمز'),
                        ),
                      ),
                    ] else ...[
                      const Text('كلمة المرور الجديدة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kPrimaryDark)),
                      const SizedBox(height: 16),
                      TextField(controller: _newPassCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة')),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
                          onPressed: auth.isLoading
                              ? null
                              : () async {
                                  setState(() => _errorMsg = null);
                                  final err = await auth.updatePassword(_newPassCtrl.text);
                                  if (err == null && mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث كلمة المرور بنجاح')));
                                    Navigator.pop(context);
                                  } else if (err != null && mounted) {
                                    setState(() => _errorMsg = err);
                                  }
                                },
                          child: const Text('حفظ وتغيير'),
                        ),
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

// ==========================================
// MAIN ADMIN NAVIGATION & APP BAR
// ==========================================
class MainAdminNavigation extends StatefulWidget {
  const MainAdminNavigation({super.key});

  @override
  State<MainAdminNavigation> createState() => _MainAdminNavigationState();
}

class _MainAdminNavigationState extends State<MainAdminNavigation> with WidgetsBindingObserver {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final appData = Provider.of<AdminAppDataProvider>(context, listen: false);
      appData.fetchNotificationsQuiet();
      appData.fetchCurrentScreenDataQuiet();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  final List<Widget> _screens = const [
    AdminDashboardScreen(),
    AdminOrdersScreen(),
    AdminProductsScreen(),
    AdminPurchasesScreen(),
    AdminReportsScreen(),
  ];

  void _openSubScreen(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final appData = Provider.of<AdminAppDataProvider>(context);
    final unreadCount = appData.unreadNotificationsCount;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kPrimaryDark,
        foregroundColor: Colors.white,
        elevation: 2,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              alignment: Alignment.center,
              child: const Text('DMC', style: TextStyle(color: kPrimaryDark, fontWeight: FontWeight.w900, fontSize: 15)),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text('تطبيق الإدارة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, height: 1.2)),
                Text('Diala Medical Equipment', style: TextStyle(fontSize: 11, color: kAccent, fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_none),
                tooltip: 'الإشعارات الواردة',
                onPressed: () => _openSubScreen(const AdminNotificationsInboxScreen()),
              ),
              if (unreadCount > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: kBadgeRed, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Text(
                      unreadCount.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.campaign_outlined),
            tooltip: 'إرسال إشعار للزبائن',
            onPressed: () => _openSubScreen(const AdminPromosScreen()),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'تسجيل الخروج',
            onPressed: () => Provider.of<AuthProvider>(context, listen: false).signOut(),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: kCardBorder)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (idx) => setState(() => _currentIndex = idx),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: kPrimary,
          unselectedItemColor: kTextMuted,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'الرئيسية'),
            BottomNavigationBarItem(icon: Icon(Icons.assignment_outlined), activeIcon: Icon(Icons.assignment), label: 'الطلبات'),
            BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), activeIcon: Icon(Icons.inventory_2), label: 'المنتجات'),
            BottomNavigationBarItem(icon: Icon(Icons.shopping_cart_outlined), activeIcon: Icon(Icons.shopping_cart), label: 'المشتريات'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), activeIcon: Icon(Icons.bar_chart), label: 'التقارير'),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// NOTIFICATIONS INBOX SCREEN
// ==========================================
class AdminNotificationsInboxScreen extends StatelessWidget {
  const AdminNotificationsInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = Provider.of<AdminAppDataProvider>(context);
    final notifications = data.notifications;

    return Scaffold(
      appBar: AppBar(title: const Text('صندوق الإشعارات')),
      body: notifications.isEmpty
          ? const Center(child: Text('لا توجد إشعارات حالياً', style: TextStyle(color: kTextMuted)))
          : ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: notifications.length,
              itemBuilder: (_, idx) {
                final n = notifications[idx];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  color: n.isRead ? Colors.white : kPrimary.withValues(alpha: 0.05),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: n.isRead ? kCardBorder : kPrimary.withValues(alpha: 0.3)),
                  ),
                  child: ListTile(
                    title: Text(n.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: n.isRead ? kTextMain : kPrimaryDark)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(n.body, style: const TextStyle(fontSize: 12, color: kTextMuted)),
                        const SizedBox(height: 4),
                        Text(n.createdAt.length >= 16 ? n.createdAt.substring(0, 16).replaceAll('T', ' ') : n.createdAt, style: const TextStyle(fontSize: 10, color: kTextMuted)),
                      ],
                    ),
                    trailing: !n.isRead
                        ? IconButton(
                            icon: const Icon(Icons.check_circle_outline, color: kPrimary),
                            onPressed: () => data.markNotificationRead(n.id),
                            tooltip: 'تحديد مقروء',
                          )
                        : const Icon(Icons.check_circle, color: kBadgeGreen, size: 18),
                    onTap: () {
                      if (!n.isRead) {
                        data.markNotificationRead(n.id);
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}

// ==========================================
// 1. DASHBOARD SCREEN
// ==========================================
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = Provider.of<AdminAppDataProvider>(context);
    final usdController = TextEditingController(text: data.usdRate.toStringAsFixed(0));
    final newOrders = data.newOrdersCount;

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [kPrimaryDark, kPrimary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('طلبات بانتظار المراجعة', style: TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text('$newOrders طلبات جديدة', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
                child: const Text('نشط ومتصل', style: TextStyle(color: kBadgeGreen, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        Card(
          elevation: 0.5,
          color: kCardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: kCardBorder)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('سعر صرف الدولار اليوم (ج.س)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextMain)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: kPrimary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                      child: const Text('تلقائي للزبائن', style: TextStyle(color: kPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: TextField(
                          controller: usdController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kPrimaryDark),
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kCardBorder)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('ج.س', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: () {
                        final val = double.tryParse(usdController.text) ?? 2500.0;
                        data.updateUsdRate(val);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم تحديث سعر الدولار لكل المنتجات عند الزبائن تلقائياً')),
                        );
                      },
                      child: const Text('تحديث الأسعار', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        Card(
          elevation: 0.5,
          color: kCardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: kCardBorder)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('مناطق التوصيل وأسعارها', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextMain)),
                    TextButton(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      onPressed: () => _showAddAreaDialog(context, data),
                      child: const Text('+ إضافة منطقة جديدة', style: TextStyle(color: kPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...data.deliveryAreas.map((area) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(color: kBgMain, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(area.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Row(
                            children: [
                              SizedBox(
                                width: 80,
                                height: 32,
                                child: TextField(
                                  controller: TextEditingController(text: area.deliveryFeeSdg.toStringAsFixed(0)),
                                  textAlign: TextAlign.center,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kCardBorder)),
                                    fillColor: Colors.white,
                                    filled: true,
                                  ),
                                  onSubmitted: (val) {
                                    final f = double.tryParse(val) ?? 0;
                                    data.updateDeliveryFee(area.id, f);
                                  },
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text('ج.س', style: TextStyle(fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showAddAreaDialog(BuildContext context, AdminAppDataProvider data) {
    final nameCtrl = TextEditingController();
    final feeCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إضافة منطقة جديدة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم المنطقة')),
            TextField(controller: feeCtrl, decoration: const InputDecoration(labelText: 'رسوم التوصيل (ج.س)'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isNotEmpty) {
                data.addDeliveryArea(nameCtrl.text, double.tryParse(feeCtrl.text) ?? 0);
                Navigator.pop(context);
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 2. ORDERS SCREEN
// ==========================================
class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  int _selectedChip = 0;

  @override
  Widget build(BuildContext context) {
    final data = Provider.of<AdminAppDataProvider>(context);

    final allOrders = data.orders;
    final newCount = allOrders.where((o) => o.status == 'جديد').length;
    final pendingCount = allOrders.where((o) => o.paymentStatus == 'pending' || o.status == 'بانتظار الدفع').length;
    final doneCount = allOrders.where((o) => o.status.contains('تم') || o.paymentStatus == 'confirmed').length;

    final filterChips = [
      {'title': 'الكل', 'count': allOrders.length},
      {'title': 'جديد', 'count': newCount},
      {'title': 'بانتظار الدفع', 'count': pendingCount},
      {'title': 'تم', 'count': doneCount},
    ];

    final filtered = allOrders.where((o) {
      if (_selectedChip == 1) return o.status == 'جديد';
      if (_selectedChip == 2) return o.paymentStatus == 'pending' || o.status == 'بانتظار الدفع';
      if (_selectedChip == 3) return o.status.contains('تم') || o.paymentStatus == 'confirmed';
      return true;
    }).toList();

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: List.generate(filterChips.length, (index) {
              final item = filterChips[index];
              final isSelected = _selectedChip == index;
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: ChoiceChip(
                  label: Text('${item['title']} (${item['count']})'),
                  selected: isSelected,
                  selectedColor: kPrimary,
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : kTextMuted,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                    side: BorderSide(color: isSelected ? kPrimary : kCardBorder),
                  ),
                  onSelected: (_) => setState(() => _selectedChip = index),
                ),
              );
            }),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(color: kPrimary.withValues(alpha: 0.08), shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: const Text('📋', style: TextStyle(fontSize: 36)),
                      ),
                      const SizedBox(height: 16),
                      const Text('لا توجد طلبات مطابقة حالياً', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kTextMain)),
                      const SizedBox(height: 6),
                      const Text('عند وصول أي طلب جديد من الزبائن سيظهر هنا فوراً.', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: kTextMuted)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: filtered.length,
                  itemBuilder: (_, idx) => OrderCardItem(order: filtered[idx]),
                ),
        ),
      ],
    );
  }
}

class OrderCardItem extends StatelessWidget {
  final CustomerOrder order;
  const OrderCardItem({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final data = Provider.of<AdminAppDataProvider>(context, listen: false);

    String badgeLabel = order.status;
    Color badgeBg = kBadgeRed.withValues(alpha: 0.14);
    Color badgeTextColor = const Color(0xFFB91C1C);

    if (order.status == 'جديد') {
      badgeLabel = 'جديد';
      badgeBg = kPrimary.withValues(alpha: 0.12);
      badgeTextColor = kPrimary;
    } else if (order.status.contains('تم') || order.paymentStatus == 'confirmed') {
      badgeLabel = 'تم التسليم والتدقيق';
      badgeBg = kBadgeGreen.withValues(alpha: 0.14);
      badgeTextColor = const Color(0xFF047857);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: kCardBorder)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('طلب #${order.orderNumber}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: kTextMain)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(999)),
                  child: Text(badgeLabel, style: TextStyle(color: badgeTextColor, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('الزبون: ${order.fullName} (${order.deliveryAreaName})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kTextMain)),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'طريقة الدفع: ${order.paymentMethod == "transfer" ? "تحويل بنكي" : "كاش عند الاستلام"}',
                  style: const TextStyle(fontSize: 12, color: kTextMuted),
                ),
                Text('${order.totalSdg.toStringAsFixed(0)} ج.س', style: const TextStyle(fontWeight: FontWeight.w800, color: kPrimary, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 10),
            if (order.paymentStatus == 'pending' && order.paymentMethod == 'transfer')
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => AdminConfirmPaymentScreen(order: order)));
                  },
                  child: const Text('مراجعة الدفع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                ),
              )
            else if (order.status == 'جديد')
              SizedBox(
                width: double.infinity,
                height: 40,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kPrimary,
                    side: const BorderSide(color: kPrimary, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    data.updateOrderStatus(order.id, 'قيد التجهيز', order);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تغيير حالة الطلب إلى: قيد التجهيز')));
                  },
                  child: const Text('تغيير الحالة (قيد التجهيز)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                height: 40,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kPrimary,
                    side: const BorderSide(color: kPrimary, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () {
                    data.updateOrderStatus(order.id, 'تم التوصيل', order);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تغيير الحالة إلى تم التوصيل')));
                  },
                  child: const Text('تحديث إلى تم التوصيل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. PAYMENT REVIEW SCREEN
// ==========================================
class AdminConfirmPaymentScreen extends StatefulWidget {
  final CustomerOrder order;
  const AdminConfirmPaymentScreen({super.key, required this.order});

  @override
  State<AdminConfirmPaymentScreen> createState() => _AdminConfirmPaymentScreenState();
}

class _AdminConfirmPaymentScreenState extends State<AdminConfirmPaymentScreen> {
  final _reasonCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final data = Provider.of<AdminAppDataProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text('تأكيد الدفع')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Card(
          elevation: 0.5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: kCardBorder)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('مراجعة إشعار التحويل البنكي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextMain)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: kBadgeRed.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
                      child: Text('طلب #${widget.order.orderNumber}', style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('الزبون: ${widget.order.fullName}', style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 4),
                Text('المبلغ المطلوب: ${widget.order.totalSdg.toStringAsFixed(0)} ج.س', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 14),
                if (widget.order.receiptUrl != null && widget.order.receiptUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      widget.order.receiptUrl!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        height: 140,
                        color: Colors.grey.shade200,
                        alignment: Alignment.center,
                        child: const Text('تعذر تحميل صورة الإشعار'),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 140,
                    width: double.infinity,
                    decoration: BoxDecoration(color: kPrimaryDark, borderRadius: BorderRadius.circular(8)),
                    alignment: Alignment.center,
                    child: const Text('لا توجد صورة مرفقة للإشعار', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ),
                const SizedBox(height: 14),
                const Text('سبب الرفض (في حال الرفض):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                TextField(
                  controller: _reasonCtrl,
                  decoration: InputDecoration(
                    hintText: 'مثال: المبلغ المحول غير مكتمل أو الصورة غير واضحة',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
                          onPressed: () {
                            data.reviewPayment(widget.order.id, true, null, widget.order);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تأكيد الدفع بنجاح وإرسال إشعار للزبون')));
                            Navigator.pop(context);
                          },
                          child: const Text('تأكيد الدفع', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: kBadgeRed, foregroundColor: Colors.white),
                          onPressed: () {
                            data.reviewPayment(widget.order.id, false, _reasonCtrl.text, widget.order);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم رفض الإشعار وإرسال السبب للزبون')));
                            Navigator.pop(context);
                          },
                          child: const Text('رفض', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
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
// 4. PRODUCTS & INVENTORY
// ==========================================
class AdminProductsScreen extends StatelessWidget {
  const AdminProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = Provider.of<AdminAppDataProvider>(context);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kAccent, foregroundColor: const Color(0xFF04383C), elevation: 0),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminAddEditProductScreen())),
            child: const Text('+ إضافة منتج جديد', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          ),
        ),
        const SizedBox(height: 12),
        ...data.products.map((p) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0.5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: kCardBorder)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: kTextMain)),
                          const SizedBox(height: 2),
                          Text('السعر بالدولار: \$${p.priceUsd.toStringAsFixed(2)} | المخزون: ${p.stockQuantity}', style: const TextStyle(fontSize: 12, color: kTextMuted)),
                          const SizedBox(height: 2),
                          Text('${(p.priceUsd * data.usdRate).toStringAsFixed(0)} ج.س', style: const TextStyle(fontWeight: FontWeight.w800, color: kPrimary, fontSize: 13)),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(foregroundColor: kPrimary, side: const BorderSide(color: kPrimary, width: 1.5)),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AdminAddEditProductScreen(product: p))),
                      child: const Text('تعديل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            )),
      ],
    );
  }
}

class AdminAddEditProductScreen extends StatefulWidget {
  final Product? product;
  const AdminAddEditProductScreen({super.key, this.product});

  @override
  State<AdminAddEditProductScreen> createState() => _AdminAddEditProductScreenState();
}

class _AdminAddEditProductScreenState extends State<AdminAddEditProductScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _usdPriceCtrl;
  late TextEditingController _stockCtrl;
  String _selectedCategory = 'مستلزمات طبية';

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.product?.name ?? '');
    _usdPriceCtrl = TextEditingController(text: widget.product?.priceUsd.toStringAsFixed(2) ?? '10.00');
    _stockCtrl = TextEditingController(text: widget.product?.stockQuantity.toString() ?? '10');
    if (widget.product != null) _selectedCategory = widget.product!.category;
  }

  @override
  Widget build(BuildContext context) {
    final data = Provider.of<AdminAppDataProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text(widget.product == null ? 'إضافة منتج جديد' : 'تعديل المنتج')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Card(
          elevation: 0.5,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'اسم المنتج')),
                const SizedBox(height: 12),
                TextField(controller: _usdPriceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر بالدولار (\$)')),
                const SizedBox(height: 12),
                TextField(controller: _stockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية في المخزن')),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
                    onPressed: () async {
                      await data.saveProduct(
                        id: widget.product?.id,
                        name: _nameCtrl.text,
                        category: _selectedCategory,
                        description: widget.product?.description ?? '',
                        priceUsd: double.tryParse(_usdPriceCtrl.text) ?? 0,
                        stockQuantity: int.tryParse(_stockCtrl.text) ?? 0,
                        lowStockThreshold: 5,
                        imageUrl: widget.product?.imageUrl ?? '',
                      );
                      if (mounted) Navigator.pop(context);
                    },
                    child: const Text('حفظ المنتج', style: TextStyle(fontWeight: FontWeight.bold)),
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
// 5. PURCHASES SCREEN
// ==========================================
class AdminPurchasesScreen extends StatefulWidget {
  const AdminPurchasesScreen({super.key});

  @override
  State<AdminPurchasesScreen> createState() => _AdminPurchasesScreenState();
}

class _AdminPurchasesScreenState extends State<AdminPurchasesScreen> {
  final _supplierCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String _paymentStatus = 'آجل';

  @override
  Widget build(BuildContext context) {
    final data = Provider.of<AdminAppDataProvider>(context);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kAccent, foregroundColor: const Color(0xFF04383C), elevation: 0),
            onPressed: () async {
              final picker = ImagePicker();
              await picker.pickImage(source: ImageSource.camera);
            },
            child: const Text('📷 تصوير فاتورة جديدة (الكاميرا)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0.5,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('تسجيل فاتورة مورد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextMain)),
                const SizedBox(height: 12),
                TextField(controller: _supplierCtrl, decoration: const InputDecoration(labelText: 'اسم المورد')),
                const SizedBox(height: 12),
                TextField(controller: _amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ الإجمالي (ج.س)')),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _paymentStatus,
                  items: ['مدفوعة', 'آجل'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _paymentStatus = v);
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
                    onPressed: () async {
                      if (_supplierCtrl.text.isNotEmpty) {
                        await data.addPurchase(
                          supplierName: _supplierCtrl.text,
                          totalAmountSdg: double.tryParse(_amountCtrl.text) ?? 0,
                          paymentStatus: _paymentStatus,
                        );
                        _supplierCtrl.clear();
                        _amountCtrl.clear();
                      }
                    },
                    child: const Text('حفظ الفاتورة'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        ...data.purchases.map((p) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('مورد: ${p.supplierName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('${p.totalAmountSdg.toStringAsFixed(0)} ج.س', style: const TextStyle(fontWeight: FontWeight.w800, color: kPrimary)),
                  ],
                ),
              ),
            )),
      ],
    );
  }
}

// ==========================================
// 6. REPORTS SCREEN
// ==========================================
class AdminReportsScreen extends StatelessWidget {
  const AdminReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: const [
        Text('تقارير المبيعات والأرباح', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        SizedBox(height: 14),
        Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('التقارير متزامنة لحظياً مع إشعارات وتحديثات الطلبات في Supabase.'),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 7. PROMOS & NOTIFICATIONS SCREEN
// ==========================================
class AdminPromosScreen extends StatefulWidget {
  const AdminPromosScreen({super.key});

  @override
  State<AdminPromosScreen> createState() => _AdminPromosScreenState();
}

class _AdminPromosScreenState extends State<AdminPromosScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final data = Provider.of<AdminAppDataProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(title: const Text('العروض والإشعارات للزبائن')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Card(
          elevation: 0.5,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('إرسال عرض أو إشعار لجميع الزبائن (Firebase)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: kTextMain)),
                const SizedBox(height: 12),
                TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'عنوان العرض / الإشعار')),
                const SizedBox(height: 12),
                TextField(controller: _bodyCtrl, maxLines: 4, decoration: const InputDecoration(labelText: 'نص الإشعار')),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white),
                    onPressed: () async {
                      if (_titleCtrl.text.isNotEmpty && _bodyCtrl.text.isNotEmpty) {
                        await data.sendBroadcastPromo(_titleCtrl.text, _bodyCtrl.text);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال الإشعار لجميع الزبائن بنجاح')));
                          Navigator.pop(context);
                        }
                      }
                    },
                    child: const Text('🚀 إرسال لكل الزبائن', style: TextStyle(fontWeight: FontWeight.bold)),
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
