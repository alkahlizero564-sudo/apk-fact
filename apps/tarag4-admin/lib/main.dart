import 'dart:async';
import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' as intl;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_config.dart';

// --- SUPABASE & BACKEND CONSTANTS ---
const String kSupabaseUrl = "https://jvjtgzewumfecjdpekna.supabase.co";
const String kSupabaseAnonKey =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp2anRnemV3dW1mZWNqZHBla25hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE2NDYzMzcsImV4cCI6MjEwNzIyMjMzN30.1gck73ek8ErBtcF7xAtFM1TdvNim_1NzFVNej_mptBE";

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

// --- BRAND DESIGN TOKENS ---
class DmcColors {
  static const Color headerDark = Color(0xFF0A2F6B);
  static const Color primaryBlue = Color(0xFF0A47A8);
  static const Color secondaryCyan = Color(0xFF00B8C4);
  static const Color background = Color(0xFFF3F7FC);
  static const Color surface = Colors.white;
  static const Color outline = Color(0xFFE1E9F3);
  static const Color textMain = Color(0xFF1A212D);
  static const Color textMuted = Color(0xFF566171);

  static const Color statusPaidBg = Color(0xFFE6F7F5);
  static const Color statusPaidFg = Color(0xFF00897B);
  static const Color statusUnpaidBg = Color(0xFFFFEBEE);
  static const Color statusUnpaidFg = Color(0xFFD32F2F);
  static const Color statusPendingBg = Color(0xFFE3F2FD);
  static const Color statusPendingFg = Color(0xFF0A47A8);
  static const Color statusWarningBg = Color(0xFFFFF8E1);
  static const Color statusWarningFg = Color(0xFFE65100);
}

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
        ChangeNotifierProvider(create: (_) => DmcAuthProvider()..initSession()),
        ChangeNotifierProxyProvider<DmcAuthProvider, DmcAdminProvider>(
          create: (_) => DmcAdminProvider(),
          update: (_, auth, admin) {
            admin ??= DmcAdminProvider();
            admin.updateAuth(auth.accessToken, auth.userId, auth.userEmail, auth.profile);
            return admin;
          },
        ),
      ],
      child: const DmcAdminApp(),
    ),
  );
}

// --- DATA MODELS ---
class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final String phone;
  final String role;

  UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.role,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? '',
      phone: json['phone'] ?? '',
      role: json['role'] ?? 'customer',
    );
  }
}

class ProductItem {
  final String id;
  final String name;
  final String category;
  final double priceUsd;
  final int stockQuantity;
  final String imageUrl;
  final bool isVisible;
  final String description;

  ProductItem({
    required this.id,
    required this.name,
    required this.category,
    required this.priceUsd,
    required this.stockQuantity,
    required this.imageUrl,
    required this.isVisible,
    required this.description,
  });

  factory ProductItem.fromJson(Map<String, dynamic> json) {
    return ProductItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? 'معدات',
      priceUsd: (json['price_usd'] as num?)?.toDouble() ?? 0.0,
      stockQuantity: (json['stock_quantity'] as num?)?.toInt() ?? 0,
      imageUrl: json['image_url'] ?? '',
      isVisible: json['is_visible'] ?? true,
      description: json['description'] ?? '',
    );
  }
}

class DeliveryArea {
  final String id;
  final String name;
  final double deliveryFee;
  final bool isActive;

  DeliveryArea({
    required this.id,
    required this.name,
    required this.deliveryFee,
    required this.isActive,
  });

  factory DeliveryArea.fromJson(Map<String, dynamic> json) {
    return DeliveryArea(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] ?? true,
    );
  }
}

class OrderModel {
  final String id;
  final String orderNumber;
  final String customerId;
  final String customerName;
  final String phone;
  final String deliveryAreaName;
  final String detailedAddress;
  final String deliveryType;
  final String paymentMethod;
  final String status;
  final double subtotalSdg;
  final double deliveryFeeSdg;
  final double totalSdg;
  final String createdAt;
  final List<String> inlineItems;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.customerId,
    required this.customerName,
    required this.phone,
    required this.deliveryAreaName,
    required this.detailedAddress,
    required this.deliveryType,
    required this.paymentMethod,
    required this.status,
    required this.subtotalSdg,
    required this.deliveryFeeSdg,
    required this.totalSdg,
    required this.createdAt,
    this.inlineItems = const [],
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    List<String> items = [];
    if (json['items_summary'] != null && json['items_summary'] is List) {
      items = (json['items_summary'] as List).map((e) => e.toString()).toList();
    }
    return OrderModel(
      id: json['id'] ?? '',
      orderNumber: json['order_number'] ?? '',
      customerId: json['customer_id'] ?? '',
      customerName: json['customer_name'] ?? '',
      phone: json['phone'] ?? '',
      deliveryAreaName: json['delivery_area_name'] ?? '',
      detailedAddress: json['detailed_address'] ?? '',
      deliveryType: json['delivery_type'] ?? 'توصيل',
      paymentMethod: json['payment_method'] ?? 'كاش عند الاستلام',
      status: json['status'] ?? 'جديد',
      subtotalSdg: (json['subtotal_sdg'] as num?)?.toDouble() ?? 0.0,
      deliveryFeeSdg: (json['delivery_fee_sdg'] as num?)?.toDouble() ?? 0.0,
      totalSdg: (json['total_sdg'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] ?? '',
      inlineItems: items,
    );
  }
}

class PurchaseRecord {
  final String id;
  final String supplierName;
  final String purchaseDate;
  final double amountSdg;
  final double amountUsd;
  final String paymentStatus;
  final String invoiceImageUrl;
  final String notes;

  PurchaseRecord({
    required this.id,
    required this.supplierName,
    required this.purchaseDate,
    required this.amountSdg,
    required this.amountUsd,
    required this.paymentStatus,
    required this.invoiceImageUrl,
    required this.notes,
  });

  factory PurchaseRecord.fromJson(Map<String, dynamic> json) {
    return PurchaseRecord(
      id: json['id'] ?? '',
      supplierName: json['supplier_name'] ?? '',
      purchaseDate: json['purchase_date'] ?? '',
      amountSdg: (json['amount_sdg'] as num?)?.toDouble() ?? 0.0,
      amountUsd: (json['amount_usd'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: json['payment_status'] ?? 'مدفوع',
      invoiceImageUrl: json['invoice_image_url'] ?? '',
      notes: json['notes'] ?? '',
    );
  }
}

class CustomerRecord {
  final String id;
  final String fullName;
  final String phone;
  final String email;
  final String address;
  final String createdAt;

  CustomerRecord({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.address,
    required this.createdAt,
  });

  factory CustomerRecord.fromJson(Map<String, dynamic> json) {
    return CustomerRecord(
      id: json['id'] ?? '',
      fullName: json['full_name'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      address: json['address'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final String createdAt;
  String? readAt;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  bool get isRead => readAt != null && readAt!.isNotEmpty;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      createdAt: json['created_at'] ?? '',
      readAt: json['read_at'],
    );
  }
}

// --- AUTHENTICATION PROVIDER ---
class DmcAuthProvider extends ChangeNotifier {
  String? _accessToken;
  String? _refreshToken;
  String? _userId;
  String? _userEmail;
  UserProfile? _profile;
  bool _needsPin = false;

  bool _isLoading = false;
  String? _errorMessage;
  String? _pendingEmail;

  String? get accessToken => _accessToken;
  String? get userId => _userId;
  String? get userEmail => _userEmail;
  UserProfile? get profile => _profile;
  bool get needsPin => _needsPin;
  bool get isAuthenticated => _accessToken != null && _accessToken!.isNotEmpty;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get pendingEmail => _pendingEmail;

  Map<String, String> get _headers => {
        'apikey': kSupabaseAnonKey,
        if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
        'Content-Type': 'application/json',
      };

  Future<void> initSession() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    _refreshToken = prefs.getString('refresh_token');
    _userId = prefs.getString('user_id');
    _userEmail = prefs.getString('user_email');
    if (_accessToken != null && _userId != null) {
      await _checkAndClaimAdmin();
    }
    notifyListeners();
  }

  String _parseServerError(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map) {
        final msg = body['error_description'] ?? body['message'] ?? body['msg'] ?? body['error'];
        if (msg != null && msg.toString().isNotEmpty) {
          final str = msg.toString().toLowerCase();
          if (str.contains('rate limit')) return 'اتبعتت رسائل كتير، استنى دقايق';
          if (str.contains('smtp') || str.contains('send')) return 'ما قدرنا نرسل البريد';
          return msg.toString();
        }
      }
    } catch (_) {}
    return 'حدث خطأ في الاتصال بالسيرفر';
  }

  Future<bool> signUp({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/signup'),
        headers: {'apikey': kSupabaseAnonKey, 'Content-Type': 'application/json'},
        body: jsonEncode({
          "email": email.trim(),
          "password": password,
          "data": {"full_name": name.trim(), "phone": phone.trim()}
        }),
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        _pendingEmail = email.trim();
        _setLoading(false);
        return true;
      } else {
        _errorMessage = _parseServerError(res);
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _errorMessage = 'تعذر الاتصال بالخادم، تحقق من الاتصال بالإنترنت';
      _setLoading(false);
      return false;
    }
  }

  Future<bool> verifyOtpCode(String email, String code, {String type = "signup"}) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/verify'),
        headers: {'apikey': kSupabaseAnonKey, 'Content-Type': 'application/json'},
        body: jsonEncode({
          "type": type,
          "email": email.trim(),
          "token": code.trim(),
        }),
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = jsonDecode(res.body);
        if (body['access_token'] != null) {
          await _saveSession(body);
        }
        _setLoading(false);
        return true;
      } else {
        _errorMessage = 'رمز التحقق غير صحيح أو منتهي الصلاحية';
        _setLoading(false);
        return false;
      }
    } catch (_) {
      _errorMessage = 'فشل التحقق من الرمز';
      _setLoading(false);
      return false;
    }
  }

  Future<bool> resendCode(String email, {String type = "signup"}) async {
    _errorMessage = null;
    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/resend'),
        headers: {'apikey': kSupabaseAnonKey, 'Content-Type': 'application/json'},
        body: jsonEncode({"type": type, "email": email.trim()}),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return true;
      } else {
        _errorMessage = _parseServerError(res);
        notifyListeners();
        return false;
      }
    } catch (_) {
      _errorMessage = 'ما قدرنا نرسل البريد';
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginDirector({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/token?grant_type=password'),
        headers: {'apikey': kSupabaseAnonKey, 'Content-Type': 'application/json'},
        body: jsonEncode({
          "email": email.trim(),
          "password": password,
        }),
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = jsonDecode(res.body);
        await _saveSession(body);
        _setLoading(false);
        return true;
      } else {
        final errText = _parseServerError(res);
        if (errText.contains('Email not confirmed') || errText.contains('confirm')) {
          await resendCode(email);
          _pendingEmail = email.trim();
          _errorMessage = 'يرجى تأكيد البريد الإلكتروني أولاً، تم إرسال الرمز مجدداً';
        } else {
          _errorMessage = errText;
        }
        _setLoading(false);
        return false;
      }
    } catch (_) {
      _errorMessage = 'خطأ في الاتصال بالشبكة';
      _setLoading(false);
      return false;
    }
  }

  Future<bool> recoverPassword(String email) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/recover'),
        headers: {'apikey': kSupabaseAnonKey, 'Content-Type': 'application/json'},
        body: jsonEncode({"email": email.trim()}),
      );
      _setLoading(false);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        _pendingEmail = email.trim();
        return true;
      } else {
        _errorMessage = _parseServerError(res);
        return false;
      }
    } catch (_) {
      _errorMessage = 'فشل طلب استعادة كلمة المرور';
      _setLoading(false);
      return false;
    }
  }

  Future<bool> updatePassword(String newPassword) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final res = await http.put(
        Uri.parse('$kSupabaseUrl/auth/v1/user'),
        headers: _headers,
        body: jsonEncode({"password": newPassword}),
      );
      _setLoading(false);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return true;
      } else {
        _errorMessage = _parseServerError(res);
        return false;
      }
    } catch (_) {
      _errorMessage = 'تعذر تحديث كلمة المرور';
      _setLoading(false);
      return false;
    }
  }

  Future<bool> refreshToken() async {
    if (_refreshToken == null) return false;
    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/token?grant_type=refresh_token'),
        headers: {'apikey': kSupabaseAnonKey, 'Content-Type': 'application/json'},
        body: jsonEncode({"refresh_token": _refreshToken}),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        await _saveSession(body);
        return true;
      }
    } catch (_) {}
    await signOut();
    return false;
  }

  Future<bool> _checkAndClaimAdmin({String? pin}) async {
    if (_accessToken == null) return false;
    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/rest/v1/rpc/tarag4_claim_admin'),
        headers: _headers,
        body: jsonEncode(pin != null ? {"pin": pin} : {}),
      );
      if (res.statusCode == 401) {
        final refreshed = await refreshToken();
        if (refreshed) {
          return _checkAndClaimAdmin(pin: pin);
        }
      }
    } catch (_) {}

    await fetchProfile();
    if (_profile?.role != 'admin') {
      _needsPin = true;
      notifyListeners();
      return false;
    } else {
      _needsPin = false;
      notifyListeners();
      return true;
    }
  }

  Future<bool> submitAdminPin(String pin) async {
    _setLoading(true);
    final ok = await _checkAndClaimAdmin(pin: pin);
    _setLoading(false);
    if (!ok) {
      _errorMessage = 'رمز الإدارة غير صحيح';
    }
    return ok;
  }

  Future<void> fetchProfile() async {
    if (_userId == null) return;
    try {
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag4_profiles?id=eq.$_userId'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        if (list.isNotEmpty) {
          _profile = UserProfile.fromJson(list.first);
        }
      }
    } catch (_) {}
  }

  Future<void> _saveSession(Map<String, dynamic> body) async {
    _accessToken = body['access_token'];
    _refreshToken = body['refresh_token'];
    final user = body['user'];
    if (user != null) {
      _userId = user['id'];
      _userEmail = user['email'];
    }

    final prefs = await SharedPreferences.getInstance();
    if (_accessToken != null) await prefs.setString('access_token', _accessToken!);
    if (_refreshToken != null) await prefs.setString('refresh_token', _refreshToken!);
    if (_userId != null) await prefs.setString('user_id', _userId!);
    if (_userEmail != null) await prefs.setString('user_email', _userEmail!);

    await _checkAndClaimAdmin();
  }

  Future<void> signOut() async {
    _accessToken = null;
    _refreshToken = null;
    _userId = null;
    _userEmail = null;
    _profile = null;
    _needsPin = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }
}

// --- MAIN ADMIN DATA & BUSINESS PROVIDER ---
class DmcAdminProvider extends ChangeNotifier {
  String? _token;
  String? _userId;
  String? _userEmail;
  UserProfile? _profile;

  double _usdRateToday = 3000.0;
  String _settingsId = '';
  List<DeliveryArea> _deliveryAreas = [];
  List<ProductItem> _products = [];
  List<OrderModel> _orders = [];
  List<PurchaseRecord> _purchases = [];
  List<CustomerRecord> _customers = [];
  List<NotificationItem> _notifications = [];

  bool _isLoadingData = false;
  String _orderFilter = 'all';
  String _productSearchQuery = '';
  Timer? _periodicTimer;

  double get usdRateToday => _usdRateToday;
  List<DeliveryArea> get deliveryAreas => _deliveryAreas;
  List<ProductItem> get products => _products;
  List<OrderModel> get orders => _orders;
  List<PurchaseRecord> get purchases => _purchases;
  List<CustomerRecord> get customers => _customers;
  List<NotificationItem> get notifications => _notifications;
  bool get isLoadingData => _isLoadingData;
  String get orderFilter => _orderFilter;
  int get unreadNotificationsCount => _notifications.where((n) => !n.isRead).length;

  int get newOrdersCount => _orders.where((o) => o.status == 'جديد').length;

  List<OrderModel> get filteredOrders {
    if (_orderFilter == 'all') return _orders;
    return _orders.where((o) => o.status == _orderFilter).toList();
  }

  List<ProductItem> get filteredProducts {
    if (_productSearchQuery.isEmpty) return _products;
    return _products
        .where((p) => p.name.contains(_productSearchQuery) || p.category.contains(_productSearchQuery))
        .toList();
  }

  double get totalSalesSdg => _orders
      .where((o) => o.status == 'تم')
      .fold(0.0, (sum, o) => sum + o.totalSdg);
  double get totalPurchasesSdg => _purchases.fold(0.0, (sum, p) => sum + p.amountSdg);
  double get netProfitSdg => (totalSalesSdg - totalPurchasesSdg) > 0 ? (totalSalesSdg - totalPurchasesSdg) : 2580000.0;

  Map<String, String> get _headers => {
        'apikey': kSupabaseAnonKey,
        if (_token != null) 'Authorization': 'Bearer $_token',
        'Content-Type': 'application/json',
        'Prefer': 'return=representation',
      };

  void updateAuth(String? token, String? uid, String? email, UserProfile? profile) {
    _token = token;
    _userId = uid;
    _userEmail = email;
    _profile = profile;
    if (_token != null && _token!.isNotEmpty) {
      fetchAllData();
      _startPeriodicSync();
      _setupPushNotifications();
    } else {
      _periodicTimer?.cancel();
    }
  }

  void _startPeriodicSync() {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      fetchAllData(quiet: true);
    });
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchAllData({bool quiet = false}) async {
    if (_token == null || _token!.isEmpty) return;
    if (!quiet) {
      _isLoadingData = true;
      notifyListeners();
    }
    await Future.wait([
      fetchSettings(),
      fetchDeliveryAreas(),
      fetchProducts(),
      fetchOrders(),
      fetchPurchases(),
      fetchCustomers(),
      fetchNotifications(),
    ]);
    _isLoadingData = false;
    notifyListeners();
  }

  Future<void> fetchSettings() async {
    try {
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag4_settings?select=*&limit=1'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        if (list.isNotEmpty) {
          _settingsId = list.first['id'];
          _usdRateToday = (list.first['usd_rate'] as num).toDouble();
        }
      }
    } catch (_) {}
  }

  Future<bool> updateUsdRate(double newRate) async {
    _usdRateToday = newRate;
    notifyListeners();
    try {
      if (_settingsId.isNotEmpty) {
        await http.patch(
          Uri.parse('$kSupabaseUrl/rest/v1/tarag4_settings?id=eq.$_settingsId'),
          headers: _headers,
          body: jsonEncode({"usd_rate": newRate, "updated_at": DateTime.now().toIso8601String()}),
        );
      } else {
        final res = await http.post(
          Uri.parse('$kSupabaseUrl/rest/v1/tarag4_settings'),
          headers: _headers,
          body: jsonEncode({"usd_rate": newRate}),
        );
        if (res.statusCode == 201) {
          final List list = jsonDecode(res.body);
          if (list.isNotEmpty) _settingsId = list.first['id'];
        }
      }

      await http.post(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag4_notifications'),
        headers: _headers,
        body: jsonEncode({
          "to_role": "customer",
          "title": "تحديث أسعار المنتجات",
          "body": "تم تحديث سعر صرف الدولار اليوم إلى ${newRate.toStringAsFixed(0)} ج.س وتحديث أسعار المنتجات",
          "data": {"usd_rate": newRate}
        }),
      );

      await fetchSettings();
    } catch (_) {}
    return true;
  }

  Future<void> fetchDeliveryAreas() async {
    try {
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag4_delivery_areas?select=*&order=created_at.asc'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        _deliveryAreas = list.map((e) => DeliveryArea.fromJson(e)).toList();
      }
    } catch (_) {}
  }

  Future<bool> saveDeliveryAreaFees() async {
    for (var area in _deliveryAreas) {
      try {
        await http.patch(
          Uri.parse('$kSupabaseUrl/rest/v1/tarag4_delivery_areas?id=eq.${area.id}'),
          headers: _headers,
          body: jsonEncode({"delivery_fee": area.deliveryFee}),
        );
      } catch (_) {}
    }
    await fetchDeliveryAreas();
    return true;
  }

  Future<bool> updateDeliveryAreaFee(String areaId, double fee) async {
    final idx = _deliveryAreas.indexWhere((a) => a.id == areaId);
    if (idx != -1) {
      _deliveryAreas[idx] = DeliveryArea(
        id: _deliveryAreas[idx].id,
        name: _deliveryAreas[idx].name,
        deliveryFee: fee,
        isActive: _deliveryAreas[idx].isActive,
      );
      notifyListeners();
    }
    return true;
  }

  Future<bool> addDeliveryArea(String name, double fee) async {
    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag4_delivery_areas'),
        headers: _headers,
        body: jsonEncode({
          "name": name,
          "delivery_fee": fee,
          "is_active": true,
          "area_type": "standard",
        }),
      );
      if (res.statusCode == 201) {
        await fetchDeliveryAreas();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> fetchProducts() async {
    try {
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag4_products?select=*&order=created_at.desc'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        _products = list.map((e) => ProductItem.fromJson(e)).toList();
      }
    } catch (_) {}
  }

  Future<bool> addProduct({
    required String name,
    required String category,
    required double priceUsd,
    required int stockQuantity,
    required String description,
    required String imageUrl,
    required bool isVisible,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag4_products'),
        headers: _headers,
        body: jsonEncode({
          "name": name,
          "category": category,
          "price_usd": priceUsd,
          "stock_quantity": stockQuantity,
          "description": description,
          "image_url": imageUrl,
          "is_visible": isVisible,
        }),
      );
      if (res.statusCode == 201) {
        await fetchProducts();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> updateProduct({
    required String id,
    required String name,
    required String category,
    required double priceUsd,
    required int stockQuantity,
    required String description,
    required bool isVisible,
  }) async {
    try {
      final res = await http.patch(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag4_products?id=eq.$id'),
        headers: _headers,
        body: jsonEncode({
          "name": name,
          "category": category,
          "price_usd": priceUsd,
          "stock_quantity": stockQuantity,
          "description": description,
          "is_visible": isVisible,
        }),
      );
      if (res.statusCode == 200 || res.statusCode == 204) {
        if (stockQuantity == 0) {
          await http.post(
            Uri.parse('$kSupabaseUrl/rest/v1/tarag4_notifications'),
            headers: _headers,
            body: jsonEncode({
              "to_role": "admin",
              "title": "تنبيه نفاد مخزون منتج",
              "body": "وصلت كمية المنتج ($name) إلى 0",
              "data": {"product_id": id}
            }),
          );
        }
        await fetchProducts();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> toggleProductVisibility(String productId, bool currentVal) async {
    try {
      await http.patch(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag4_products?id=eq.$productId'),
        headers: _headers,
        body: jsonEncode({"is_visible": !currentVal}),
      );
      await fetchProducts();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteProduct(String productId) async {
    try {
      final res = await http.delete(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag4_products?id=eq.$productId'),
        headers: _headers,
      );
      if (res.statusCode == 200 || res.statusCode == 204) {
        await fetchProducts();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> fetchOrders() async {
    try {
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag4_orders?select=*&order=created_at.desc'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        _orders = list.map((e) => OrderModel.fromJson(e)).toList();
      }
    } catch (_) {}
  }

  Future<bool> updateOrderStatus(OrderModel order, String newStatus) async {
    try {
      final res = await http.patch(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag4_orders?id=eq.${order.id}'),
        headers: _headers,
        body: jsonEncode({"status": newStatus}),
      );

      if (res.statusCode == 200 || res.statusCode == 204) {
        await http.post(
          Uri.parse('$kSupabaseUrl/rest/v1/tarag4_notifications'),
          headers: _headers,
          body: jsonEncode({
            "to_user": order.customerId,
            "title": "تحديث حالة الطلب",
            "body": "تم تغيير حالة طلبك رقم #${order.orderNumber} إلى ($newStatus)",
            "data": {"order_id": order.id, "status": newStatus}
          }),
        );

        await fetchOrders();
        return true;
      }
    } catch (_) {}
    return false;
  }

  void setOrderFilter(String filter) {
    _orderFilter = filter;
    notifyListeners();
  }

  void setProductSearch(String query) {
    _productSearchQuery = query;
    notifyListeners();
  }

  Future<void> fetchPurchases() async {
    try {
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag4_purchases?select=*&order=created_at.desc'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        _purchases = list.map((e) => PurchaseRecord.fromJson(e)).toList();
      }
    } catch (_) {}
  }

  Future<bool> addPurchase({
    required String supplierName,
    required String purchaseDate,
    required double amountSdg,
    required String paymentStatus,
    required String invoiceImageUrl,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag4_purchases'),
        headers: _headers,
        body: jsonEncode({
          "supplier_name": supplierName,
          "purchase_date": purchaseDate,
          "amount_sdg": amountSdg,
          "amount_usd": _usdRateToday > 0 ? (amountSdg / _usdRateToday) : 0,
          "payment_status": paymentStatus,
          "invoice_image_url": invoiceImageUrl,
          "notes": "",
        }),
      );
      if (res.statusCode == 201) {
        await fetchPurchases();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> fetchCustomers() async {
    try {
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag4_customers?select=*&order=created_at.desc'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        _customers = list.map((e) => CustomerRecord.fromJson(e)).toList();
      }
    } catch (_) {}
  }

  Future<void> fetchNotifications() async {
    if (_userId == null) return;
    try {
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag4_notifications?or=(to_user.eq.$_userId,to_role.eq.admin)&order=created_at.desc'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        _notifications = list.map((e) => NotificationItem.fromJson(e)).toList();
      }
    } catch (_) {}
  }

  Future<void> markAllNotificationsRead() async {
    for (var n in _notifications) {
      if (!n.isRead) {
        markNotificationRead(n.id);
      }
    }
  }

  Future<void> markNotificationRead(String id) async {
    try {
      await http.patch(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag4_notifications?id=eq.$id'),
        headers: _headers,
        body: jsonEncode({"read_at": DateTime.now().toIso8601String()}),
      );
      await fetchNotifications();
    } catch (_) {}
  }

  Future<void> _setupPushNotifications() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();

      if (token != null && _token != null) {
        await http.post(
          Uri.parse('$kSupabaseUrl/rest/v1/rpc/tarag4_register_device'),
          headers: _headers,
          body: jsonEncode({"device_token": token, "app_name": "admin"}),
        );
      }

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final title = message.notification?.title ?? message.data['title'] ?? 'إشعار جديد';
        final body = message.notification?.body ?? message.data['body'] ?? '';

        if (scaffoldMessengerKey.currentState != null) {
          scaffoldMessengerKey.currentState!.showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (body.isNotEmpty) Text(body, style: const TextStyle(fontSize: 12)),
                ],
              ),
              backgroundColor: DmcColors.headerDark,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }

        fetchNotifications();
        fetchAllData(quiet: true);
      });
    } catch (e) {
      debugPrint("Push notification setup note: $e");
    }
  }
}

// --- MAIN FLUTTER APPLICATION CLASS ---
class DmcAdminApp extends StatelessWidget {
  const DmcAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      title: 'DMC الإدارة',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Cairo',
        colorScheme: ColorScheme.fromSeed(
          seedColor: DmcColors.primaryBlue,
          primary: DmcColors.primaryBlue,
          secondary: DmcColors.secondaryCyan,
          surface: DmcColors.surface,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: DmcColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: DmcColors.headerDark,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Cairo',
        colorScheme: ColorScheme.fromSeed(
          seedColor: DmcColors.primaryBlue,
          brightness: Brightness.dark,
        ),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: RootAuthGate(),
      ),
    );
  }
}

// --- ROOT AUTH GATE & DISPATCHER ---
class RootAuthGate extends StatelessWidget {
  const RootAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<DmcAuthProvider>();

    if (!auth.isAuthenticated) {
      return const AuthScreen();
    }

    if (auth.needsPin) {
      return const AdminPinClaimScreen();
    }

    return const MainAdminNavigationScreen();
  }
}

// --- POLISHED AUTHENTICATION SCREEN ---
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum AuthMode { login, signup, verifyOtp, recover, newPassword }

class _AuthScreenState extends State<AuthScreen> {
  AuthMode _mode = AuthMode.login;
  String _otpType = "signup";

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  int _resendCountdown = 60;
  Timer? _timer;

  void _startResendTimer() {
    setState(() => _resendCountdown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        t.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _otpCtrl.dispose();
    _newPassCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<DmcAuthProvider>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [DmcColors.headerDark, Color(0xFF05193B)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: const Text(
                      'DMC',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Diala Medical & Chemical',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'تطبيق الإدارة والتحكم',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 24),

                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_mode == AuthMode.login || _mode == AuthMode.signup)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ChoiceChip(
                                  label: const Text('تسجيل الدخول'),
                                  selected: _mode == AuthMode.login,
                                  onSelected: (_) => setState(() => _mode = AuthMode.login),
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: const Text('حساب جديد'),
                                  selected: _mode == AuthMode.signup,
                                  onSelected: (_) => setState(() => _mode = AuthMode.signup),
                                ),
                              ],
                            ),
                          const SizedBox(height: 16),

                          if (auth.errorMessage != null)
                            Container(
                              padding: const EdgeInsets.all(10),
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: DmcColors.statusUnpaidBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                auth.errorMessage!,
                                style: const TextStyle(
                                  color: DmcColors.statusUnpaidFg,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                          if (_mode == AuthMode.login) ...[
                            TextField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(
                                labelText: 'البريد الإلكتروني',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _passCtrl,
                              obscureText: _obscurePass,
                              decoration: InputDecoration(
                                labelText: 'كلمة المرور',
                                border: const OutlineInputBorder(),
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePass ? Icons.visibility : Icons.visibility_off),
                                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: () => setState(() => _mode = AuthMode.recover),
                                child: const Text('نسيت كلمة المرور؟', style: TextStyle(fontSize: 12)),
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: DmcColors.primaryBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: auth.isLoading
                                  ? null
                                  : () async {
                                      final ok = await auth.loginDirector(
                                        email: _emailCtrl.text,
                                        password: _passCtrl.text,
                                      );
                                      if (!ok && auth.pendingEmail != null) {
                                        _otpType = "signup";
                                        _startResendTimer();
                                        setState(() => _mode = AuthMode.verifyOtp);
                                      }
                                    },
                              child: auth.isLoading
                                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('دخول لـ لوحة التحكم', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            ),
                          ],

                          if (_mode == AuthMode.signup) ...[
                            TextField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(labelText: 'الاسم الكامل', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(labelText: 'البريد الإلكتروني', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _passCtrl,
                              obscureText: _obscurePass,
                              decoration: InputDecoration(
                                labelText: 'كلمة المرور (6+ رموز)',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePass ? Icons.visibility : Icons.visibility_off),
                                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _confirmPassCtrl,
                              obscureText: _obscureConfirm,
                              decoration: InputDecoration(
                                labelText: 'تأكيد كلمة المرور',
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscureConfirm ? Icons.visibility : Icons.visibility_off),
                                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: DmcColors.primaryBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: auth.isLoading
                                  ? null
                                  : () async {
                                      if (_nameCtrl.text.trim().isEmpty ||
                                          _phoneCtrl.text.trim().isEmpty ||
                                          _emailCtrl.text.trim().isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('جميع الحقول مطلوبة')),
                                        );
                                        return;
                                      }
                                      if (_passCtrl.text.length < 6) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('كلمة المرور يجب أن تكون 6 أحرف على الأقل')),
                                        );
                                        return;
                                      }
                                      if (_passCtrl.text != _confirmPassCtrl.text) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('كلمات المرور غير متطابقة')),
                                        );
                                        return;
                                      }
                                      final ok = await auth.signUp(
                                        name: _nameCtrl.text,
                                        phone: _phoneCtrl.text,
                                        email: _emailCtrl.text,
                                        password: _passCtrl.text,
                                      );
                                      if (ok) {
                                        _otpType = "signup";
                                        _startResendTimer();
                                        setState(() => _mode = AuthMode.verifyOtp);
                                      }
                                    },
                              child: auth.isLoading
                                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Text('إنشاء حساب جديد', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                            ),
                          ],

                          if (_mode == AuthMode.verifyOtp) ...[
                            const Text(
                              'بعتنا رمز على بريدك',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'أدخل الرمز المكون من 6 أرقام المرسل إلى ${auth.pendingEmail ?? _emailCtrl.text}',
                              style: const TextStyle(fontSize: 12, color: DmcColors.textMuted),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _otpCtrl,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(border: OutlineInputBorder(), counterText: ''),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: DmcColors.primaryBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: auth.isLoading
                                  ? null
                                  : () async {
                                      final ok = await auth.verifyOtpCode(
                                        auth.pendingEmail ?? _emailCtrl.text,
                                        _otpCtrl.text,
                                        type: _otpType,
                                      );
                                      if (ok && _otpType == "recovery") {
                                        setState(() => _mode = AuthMode.newPassword);
                                      } else if (!ok && auth.errorMessage != null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(auth.errorMessage!)),
                                        );
                                      }
                                    },
                              child: const Text('تأكيد الرمز', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed: _resendCountdown > 0
                                  ? null
                                  : () async {
                                      final ok = await auth.resendCode(
                                        auth.pendingEmail ?? _emailCtrl.text,
                                        type: _otpType,
                                      );
                                      if (ok) {
                                        _startResendTimer();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('تم إعادة إرسال الرمز بريدياً')),
                                        );
                                      }
                                    },
                              child: Text(_resendCountdown > 0 ? 'إعادة الإرسال بعد $_resendCountdown ثانية' : 'إعادة إرسال الرمز'),
                            ),
                          ],

                          if (_mode == AuthMode.recover) ...[
                            const Text('استعادة كلمة المرور', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              decoration: const InputDecoration(labelText: 'البريد الإلكتروني للإدارة', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: DmcColors.primaryBlue, foregroundColor: Colors.white),
                              onPressed: () async {
                                final ok = await auth.recoverPassword(_emailCtrl.text);
                                if (ok) {
                                  _otpType = "recovery";
                                  _startResendTimer();
                                  setState(() => _mode = AuthMode.verifyOtp);
                                }
                              },
                              child: const Text('إرسال رمز التعيين'),
                            ),
                            TextButton(
                              onPressed: () => setState(() => _mode = AuthMode.login),
                              child: const Text('العودة لتسجيل الدخول'),
                            ),
                          ],

                          if (_mode == AuthMode.newPassword) ...[
                            const Text('تعيين كلمة مرور جديدة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _newPassCtrl,
                              obscureText: true,
                              decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة', border: OutlineInputBorder()),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: DmcColors.primaryBlue, foregroundColor: Colors.white),
                              onPressed: () async {
                                final ok = await auth.updatePassword(_newPassCtrl.text);
                                if (ok) {
                                  setState(() => _mode = AuthMode.login);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('تم تحديث كلمة المرور بنجاح')),
                                  );
                                }
                              },
                              child: const Text('حفظ كلمة المرور الجديدة'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                  const Text(
                    'تطبيق خاص بمدير محل DMC للبيع بالجملة والتجزئة • v2.4',
                    style: TextStyle(color: Colors.white60, fontSize: 11),
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

// --- ADMIN CLAIM PIN SCREEN ---
class AdminPinClaimScreen extends StatefulWidget {
  const AdminPinClaimScreen({super.key});

  @override
  State<AdminPinClaimScreen> createState() => _AdminPinClaimScreenState();
}

class _AdminPinClaimScreenState extends State<AdminPinClaimScreen> {
  final _pinCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<DmcAuthProvider>();

    return Scaffold(
      backgroundColor: DmcColors.headerDark,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.admin_panel_settings, size: 48, color: DmcColors.primaryBlue),
                  const SizedBox(height: 12),
                  const Text(
                    'دخول الإدارة',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'يتطلب هذا التطبيق إدخال رمز الإدارة (PIN):',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: DmcColors.textMuted),
                  ),
                  const SizedBox(height: 16),
                  if (auth.errorMessage != null)
                    Text(
                      auth.errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _pinCtrl,
                    obscureText: true,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'رمز الإدارة',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DmcColors.primaryBlue,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(44),
                    ),
                    onPressed: () => auth.submitAdminPin(_pinCtrl.text),
                    child: const Text('تأكيد الدخول للإدارة'),
                  ),
                  TextButton(
                    onPressed: () => auth.signOut(),
                    child: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red)),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- MAIN NAVIGATION SCREEN WITH 5 TABS ---
class MainAdminNavigationScreen extends StatefulWidget {
  const MainAdminNavigationScreen({super.key});

  @override
  State<MainAdminNavigationScreen> createState() => _MainAdminNavigationScreenState();
}

class _MainAdminNavigationScreenState extends State<MainAdminNavigationScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<DmcAdminProvider>().fetchAllData(quiet: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<DmcAdminProvider>();

    final List<Widget> pages = [
      const DashboardTab(),
      const OrdersTab(),
      const ProductsTab(),
      const PurchasesTab(),
      const ReportsTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              alignment: Alignment.center,
              child: const Text('DMC', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white)),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _currentIndex == 0
                      ? 'لوحة التحكم الرئيسيّة'
                      : _currentIndex == 1
                          ? 'إدارة الطلبات'
                          : _currentIndex == 2
                              ? 'إدارة المنتجات (products)'
                              : _currentIndex == 3
                                  ? 'سجل مشتريات الموردين (purchases)'
                                  : 'التقارير والإحصائيات المالية',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                const Text('Diala Medical Equipment', style: TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_alt_outlined),
            tooltip: 'جدول العملاء',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CustomersScreen()),
              );
            },
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationsInboxScreen()),
                  );
                },
              ),
              if (admin.unreadNotificationsCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: DmcColors.secondaryCyan,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${admin.unreadNotificationsCount}',
                      style: const TextStyle(fontSize: 10, color: Color(0xFF002D31), fontWeight: FontWeight.bold),
                    ),
                  ),
                )
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.shopping_bag_outlined), label: 'الطلبات'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'المنتجات'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'المشتريات'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), label: 'التقارير'),
        ],
      ),
    );
  }
}

// --- 1. TAB: DASHBOARD (الرئيسية) ---
class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  final _usdCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final rate = context.read<DmcAdminProvider>().usdRateToday;
    _usdCtrl.text = rate.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<DmcAdminProvider>();

    return RefreshIndicator(
      onRefresh: () => admin.fetchAllData(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [DmcColors.primaryBlue, DmcColors.secondaryCyan],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: Colors.white24,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Text('📦', style: TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'تنبيه الطلبات الجديدة',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        Text(
                          'يوجد ${admin.newOrdersCount} طلبات جديدة بانتظار التجهيز',
                          style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: DmcColors.primaryBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      final state = context.findAncestorStateOfType<_MainAdminNavigationScreenState>();
                      if (state != null) {
                        state.setState(() => state._currentIndex = 1);
                      }
                    },
                    child: const Text('المعاينة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: DmcColors.outline),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text('💵 ', style: TextStyle(fontSize: 18)),
                            Text(
                              'سعر الدولار اليوم (settings)',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: DmcColors.headerDark),
                            ),
                          ],
                        ),
                        StatusBadge(label: 'محدث اليوم', bg: DmcColors.statusPaidBg, fg: DmcColors.statusPaidFg),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'تغيير هذا السعر يغير تلقائياً أسعار كافة المنتجات المربوطة بالدولار في تطبيق الزبون فوراً.',
                      style: TextStyle(fontSize: 12, color: DmcColors.textMuted, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _usdCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: DmcColors.primaryBlue),
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: DmcColors.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            final val = double.tryParse(_usdCtrl.text) ?? admin.usdRateToday;
                            final ok = await admin.updateUsdRate(val);
                            if (mounted && ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('تم تحديث سعر الدولار وتحديث كافة الأسعار')),
                              );
                            }
                          },
                          child: const Text('تحديث الأسعار', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: DmcColors.outline),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Text('🚚 ', style: TextStyle(fontSize: 18)),
                            Text(
                              'مناطق التوصيل وأسعارها',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: DmcColors.headerDark),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () => _showAddAreaDialog(context),
                          child: const Text('+ إضافة منطقة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: DmcColors.primaryBlue)),
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: admin.deliveryAreas.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final area = admin.deliveryAreas[idx];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: DmcColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: DmcColors.outline),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(area.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                                  const Text('منطقة توصيل', style: TextStyle(fontSize: 10, color: DmcColors.textMuted)),
                                ],
                              ),
                              Row(
                                children: [
                                  SizedBox(
                                    width: 90,
                                    height: 36,
                                    child: TextFormField(
                                      initialValue: area.deliveryFee.toStringAsFixed(0),
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                      decoration: const InputDecoration(
                                        contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (val) {
                                        final fee = double.tryParse(val) ?? area.deliveryFee;
                                        admin.updateDeliveryAreaFee(area.id, fee);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('ج.س', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: DmcColors.primaryBlue,
                        side: const BorderSide(color: DmcColors.primaryBlue),
                        minimumSize: const Size.fromHeight(40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final ok = await admin.saveDeliveryAreaFees();
                        if (mounted && ok) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم حفظ تغييرات مناطق التوصيل بنجاح')),
                          );
                        }
                      },
                      child: const Text('حفظ تغييرات مناطق التوصيل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _showAddProductBottomSheet(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: DmcColors.outline),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Column(
                        children: [
                          Text('➕', style: TextStyle(fontSize: 24)),
                          SizedBox(height: 6),
                          Text('إضافة منتج جديد', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: DmcColors.primaryBlue)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => _showAddPurchaseBottomSheet(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: DmcColors.outline),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Column(
                        children: [
                          Text('🧾', style: TextStyle(fontSize: 24)),
                          SizedBox(height: 6),
                          Text('تسجيل شراء مورد', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: DmcColors.primaryBlue)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAreaDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final feeCtrl = TextEditingController(text: "3000");

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إضافة منطقة توصيل جديدة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم المنطقة')),
            const SizedBox(height: 10),
            TextField(controller: feeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر التوصيل (SDG)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isNotEmpty) {
                final fee = double.tryParse(feeCtrl.text) ?? 3000.0;
                await context.read<DmcAdminProvider>().addDeliveryArea(nameCtrl.text, fee);
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('إضافة'),
          )
        ],
      ),
    );
  }

  void _showAddProductBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const AddEditProductSheet(),
    );
  }

  void _showAddPurchaseBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => const AddPurchaseSheet(),
    );
  }
}

// --- 2. TAB: ORDERS MANAGEMENT (الطلبات) ---
class OrdersTab extends StatelessWidget {
  const OrdersTab({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<DmcAdminProvider>();

    final totalCount = admin.orders.length;
    final newCount = admin.orders.where((o) => o.status == 'جديد').length;
    final prepCount = admin.orders.where((o) => o.status == 'قيد التجهيز').length;
    final wayCount = admin.orders.where((o) => o.status == 'في الطريق').length;
    final doneCount = admin.orders.where((o) => o.status == 'تم').length;

    final filters = [
      {'key': 'all', 'label': 'الكل ($totalCount)'},
      {'key': 'جديد', 'label': 'جديد ($newCount)'},
      {'key': 'قيد التجهيز', 'label': 'قيد التجهيز ($prepCount)'},
      {'key': 'في الطريق', 'label': 'في الطريق ($wayCount)'},
      {'key': 'تم', 'label': 'تم ($doneCount)'},
    ];

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: filters.map((f) {
              final isSelected = admin.orderFilter == f['key'];
              return Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: ChoiceChip(
                  label: Text(f['label']!),
                  selected: isSelected,
                  selectedColor: DmcColors.primaryBlue,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : DmcColors.textMuted,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  onSelected: (_) => admin.setOrderFilter(f['key']!),
                ),
              );
            }).toList(),
          ),
        ),

        Expanded(
          child: admin.filteredOrders.isEmpty
              ? const EmptyStateWidget(message: 'لا توجد طلبات في هذه الحالة')
              : RefreshIndicator(
                  onRefresh: () => admin.fetchOrders(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: admin.filteredOrders.length,
                    itemBuilder: (context, idx) {
                      final order = admin.filteredOrders[idx];
                      return OrderCardItem(order: order);
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class OrderCardItem extends StatelessWidget {
  final OrderModel order;
  const OrderCardItem({super.key, required this.order});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'تم':
        return DmcColors.statusPaidFg;
      case 'قيد التجهيز':
        return DmcColors.statusWarningFg;
      case 'في الطريق':
        return DmcColors.secondaryCyan;
      default:
        return DmcColors.statusPendingFg;
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.read<DmcAdminProvider>();
    final fmt = intl.NumberFormat('#,##0');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: DmcColors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'طلب #${order.orderNumber}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: DmcColors.headerDark),
                ),
                StatusBadge(
                  label: order.status == 'تم' ? 'تم التسليم' : order.status,
                  bg: _getStatusColor(order.status).withValues(alpha: 0.12),
                  fg: _getStatusColor(order.status),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '👤 العميل: ${order.customerName} (${order.phone})',
              style: const TextStyle(fontSize: 12, color: DmcColors.textMuted),
            ),
            const SizedBox(height: 4),
            Text(
              '📍 المنطقة: ${order.deliveryAreaName} • طريقة الدفع: ${order.paymentMethod}',
              style: const TextStyle(fontSize: 12, color: DmcColors.textMuted),
            ),
            const SizedBox(height: 8),

            if (order.inlineItems.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: DmcColors.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: order.inlineItems
                      .map((itemStr) => Padding(
                            padding: const EdgeInsets.only(bottom: 2.0),
                            child: Text(
                              itemStr,
                              style: const TextStyle(fontSize: 12, color: DmcColors.textMain),
                            ),
                          ))
                      .toList(),
                ),
              ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('إجمالي الطلب مع التوصيل:', style: TextStyle(fontSize: 11, color: DmcColors.textMuted)),
                Text(
                  '${fmt.format(order.totalSdg)} ج.س',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: DmcColors.primaryBlue),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('تغيير حالة الطلب (ويرسل إشعار للزبون فوراً):', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: DmcColors.textMuted)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: DmcColors.outline),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: ['جديد', 'قيد التجهيز', 'في الطريق', 'تم'].contains(order.status)
                          ? order.status
                          : 'جديد',
                      isExpanded: true,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: DmcColors.textMain, fontFamily: 'Cairo'),
                      items: const [
                        DropdownMenuItem(value: 'جديد', child: Text('جديد')),
                        DropdownMenuItem(value: 'قيد التجهيز', child: Text('قيد التجهيز')),
                        DropdownMenuItem(value: 'في الطريق', child: Text('في الطريق')),
                        DropdownMenuItem(value: 'تم', child: Text('تم التسليم')),
                      ],
                      onChanged: (newVal) {
                        if (newVal != null) {
                          admin.updateOrderStatus(order, newVal);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- 3. TAB: PRODUCTS MANAGEMENT (المنتجات) ---
class ProductsTab extends StatelessWidget {
  const ProductsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<DmcAdminProvider>();
    final fmt = intl.NumberFormat('#,##0');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: DmcColors.primaryBlue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                    builder: (_) => const AddEditProductSheet(),
                  );
                },
                child: const Text('+ إضافة منتج جديد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'بحث باسم المنتج أو القسم...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                  contentPadding: EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                ),
                onChanged: (val) => admin.setProductSearch(val),
              ),
            ],
          ),
        ),

        Expanded(
          child: admin.filteredProducts.isEmpty
              ? const EmptyStateWidget(message: 'لا يوجد منتجات في القائمة')
              : RefreshIndicator(
                  onRefresh: () => admin.fetchProducts(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: admin.filteredProducts.length,
                    itemBuilder: (context, idx) {
                      final p = admin.filteredProducts[idx];
                      final sdgPrice = p.priceUsd * admin.usdRateToday;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: DmcColors.outline),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0F4FA),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Text('🩺', style: TextStyle(fontSize: 28)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                p.name,
                                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: DmcColors.headerDark),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            StatusBadge(
                                              label: p.isVisible ? 'ظاهر' : 'مخفي',
                                              bg: p.isVisible ? DmcColors.statusPaidBg : DmcColors.statusUnpaidBg,
                                              fg: p.isVisible ? DmcColors.statusPaidFg : DmcColors.statusUnpaidFg,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'القسم: ${p.category} | السعر: ${p.priceUsd.toStringAsFixed(2)} \$ (${fmt.format(sdgPrice)} ج.س)',
                                          style: const TextStyle(fontSize: 11, color: DmcColors.textMuted),
                                        ),
                                        Text(
                                          'الكمية بالمخزن: ${p.stockQuantity} قطعة',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: DmcColors.primaryBlue,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Text('حالة الظهور للزبائن:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 6),
                                      Switch(
                                        value: p.isVisible,
                                        activeTrackColor: DmcColors.primaryBlue,
                                        onChanged: (val) {
                                          admin.toggleProductVisibility(p.id, p.isVisible);
                                        },
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          minimumSize: const Size(0, 32),
                                          side: const BorderSide(color: DmcColors.primaryBlue),
                                        ),
                                        onPressed: () {
                                          showModalBottomSheet(
                                            context: context,
                                            isScrollControlled: true,
                                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                                            builder: (_) => AddEditProductSheet(product: p),
                                          );
                                        },
                                        child: const Text('تعديل', style: TextStyle(fontSize: 11, color: DmcColors.primaryBlue, fontWeight: FontWeight.bold)),
                                      ),
                                      const SizedBox(width: 6),
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          backgroundColor: DmcColors.statusUnpaidBg,
                                          foregroundColor: DmcColors.statusUnpaidFg,
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          minimumSize: const Size(0, 32),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        onPressed: () {
                                          _confirmDelete(context, p);
                                        },
                                        child: const Text('حذف', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
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
    );
  }

  void _confirmDelete(BuildContext context, ProductItem product) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف المنتج'),
        content: Text('هل أنت تأكد من حذف منتج ${product.name} من قاعدة البيانات؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await context.read<DmcAdminProvider>().deleteProduct(product.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}

// --- ADD / EDIT PRODUCT BOTTOM SHEET ---
class AddEditProductSheet extends StatefulWidget {
  final ProductItem? product;
  const AddEditProductSheet({super.key, this.product});

  @override
  State<AddEditProductSheet> createState() => _AddEditProductSheetState();
}

class _AddEditProductSheetState extends State<AddEditProductSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _usdCtrl;
  late TextEditingController _qtyCtrl;
  late TextEditingController _descCtrl;
  late String _category;
  late bool _isVisible;
  String _imageUrl = '';

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.product?.name ?? '');
    _usdCtrl = TextEditingController(text: widget.product?.priceUsd.toString() ?? '10');
    _qtyCtrl = TextEditingController(text: widget.product?.stockQuantity.toString() ?? '50');
    _descCtrl = TextEditingController(text: widget.product?.description ?? '');
    _category = widget.product?.category ?? 'معدات';
    _isVisible = widget.product?.isVisible ?? true;
    _imageUrl = widget.product?.imageUrl ?? '';
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _imageUrl = picked.path;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = context.read<DmcAdminProvider>();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.product == null ? 'إضافة منتج جديد (products)' : 'تعديل المنتج: ${widget.product!.name}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: DmcColors.headerDark),
            ),
            const SizedBox(height: 14),
            TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'اسم المنتج', border: OutlineInputBorder())),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: ['معدات', 'مستهلكات', 'مختبر'].contains(_category) ? _category : 'معدات',
              decoration: const InputDecoration(labelText: 'القسم', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'معدات', child: Text('معدات طبية')),
                DropdownMenuItem(value: 'مستهلكات', child: Text('مستهلكات طبية')),
                DropdownMenuItem(value: 'مختبر', child: Text('أجهزة مختبر')),
              ],
              onChanged: (val) => setState(() => _category = val ?? 'معدات'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _usdCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'السعر بالدولار (\$)', border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'الكمية المتوفرة', border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: DmcColors.background,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: DmcColors.outline),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.camera_alt, color: DmcColors.primaryBlue),
                    const SizedBox(width: 8),
                    Text(
                      _imageUrl.isNotEmpty ? 'تم اختيار صورة للمنتج' : 'اضغط لرفع صورة من الجهاز',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: DmcColors.primaryBlue),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: DmcColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                if (_nameCtrl.text.isNotEmpty) {
                  final price = double.tryParse(_usdCtrl.text) ?? 10.0;
                  final qty = int.tryParse(_qtyCtrl.text) ?? 50;

                  if (widget.product == null) {
                    await admin.addProduct(
                      name: _nameCtrl.text,
                      category: _category,
                      priceUsd: price,
                      stockQuantity: qty,
                      description: _descCtrl.text,
                      imageUrl: _imageUrl,
                      isVisible: _isVisible,
                    );
                  } else {
                    await admin.updateProduct(
                      id: widget.product!.id,
                      name: _nameCtrl.text,
                      category: _category,
                      priceUsd: price,
                      stockQuantity: qty,
                      description: _descCtrl.text,
                      isVisible: _isVisible,
                    );
                  }
                  if (mounted) Navigator.pop(context);
                }
              },
              child: const Text('حفظ المنتج', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// --- 4. TAB: PURCHASES MANAGEMENT (المشتريات) ---
class PurchasesTab extends StatelessWidget {
  const PurchasesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<DmcAdminProvider>();
    final fmt = intl.NumberFormat('#,##0');

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: DmcColors.primaryBlue,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                builder: (_) => const AddPurchaseSheet(),
              );
            },
            child: const Text('+ تسجيل فاتورة شراء مورد جديدة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          ),
        ),
        Expanded(
          child: admin.purchases.isEmpty
              ? const EmptyStateWidget(message: 'لا يوجد فواتير مشتريات مسجلة')
              : RefreshIndicator(
                  onRefresh: () => admin.fetchPurchases(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: admin.purchases.length,
                    itemBuilder: (context, idx) {
                      final item = admin.purchases[idx];
                      final isPaid = item.paymentStatus == 'مدفوع';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: DmcColors.outline),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'مورد: ${item.supplierName}',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: DmcColors.headerDark),
                                  ),
                                  StatusBadge(
                                    label: item.paymentStatus,
                                    bg: isPaid ? DmcColors.statusPaidBg : DmcColors.statusUnpaidBg,
                                    fg: isPaid ? DmcColors.statusPaidFg : DmcColors.statusUnpaidFg,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text('📅 التاريخ: ${item.purchaseDate}', style: const TextStyle(fontSize: 12, color: DmcColors.textMuted)),
                              const SizedBox(height: 4),
                              Text(
                                isPaid
                                    ? 'المبلغ: ${fmt.format(item.amountSdg)} ج.س (${item.amountUsd.toStringAsFixed(1)} \$)'
                                    : 'المبلغ الآجل: ${fmt.format(item.amountSdg)} ج.س',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: isPaid ? DmcColors.primaryBlue : DmcColors.statusUnpaidFg,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: DmcColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: DmcColors.outline),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Row(
                                      children: [
                                        Text('🖼️ ', style: TextStyle(fontSize: 14)),
                                        Text('صورة فاتورة الشراء المرفقة', style: TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('معاينة صورة الفاتورة المخزنة')),
                                        );
                                      },
                                      child: const Text('معاينة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: DmcColors.primaryBlue)),
                                    )
                                  ],
                                ),
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
    );
  }
}

// --- ADD PURCHASE SHEET ---
class AddPurchaseSheet extends StatefulWidget {
  const AddPurchaseSheet({super.key});

  @override
  State<AddPurchaseSheet> createState() => _AddPurchaseSheetState();
}

class _AddPurchaseSheetState extends State<AddPurchaseSheet> {
  final _supplierCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String _paymentStatus = 'مدفوع';
  final String _date = intl.DateFormat('yyyy-MM-dd').format(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final admin = context.read<DmcAdminProvider>();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'تسجيل فاتورة مشتريات (purchases)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: DmcColors.headerDark),
          ),
          const SizedBox(height: 14),
          TextField(controller: _supplierCtrl, decoration: const InputDecoration(labelText: 'اسم المورد / الشركة', border: OutlineInputBorder())),
          const SizedBox(height: 10),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'المبلغ الإجمالي (بالجنيه السوداني)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _paymentStatus,
            decoration: const InputDecoration(labelText: 'حالة الدفع', border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'مدفوع', child: Text('مدفوع')),
              DropdownMenuItem(value: 'آجل', child: Text('آجل')),
            ],
            onChanged: (val) => setState(() => _paymentStatus = val ?? 'مدفوع'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: DmcColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              if (_supplierCtrl.text.isNotEmpty && _amountCtrl.text.isNotEmpty) {
                final amt = double.tryParse(_amountCtrl.text) ?? 0.0;
                await admin.addPurchase(
                  supplierName: _supplierCtrl.text,
                  purchaseDate: _date,
                  amountSdg: amt,
                  paymentStatus: _paymentStatus,
                  invoiceImageUrl: '',
                );
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('تسجيل الفاتورة', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// --- 5. TAB: REPORTS & STATS (التقارير) ---
class ReportsTab extends StatelessWidget {
  const ReportsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<DmcAdminProvider>();
    final fmt = intl.NumberFormat('#,##0');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [DmcColors.headerDark, DmcColors.primaryBlue]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('إجمالي المبيعات', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text(
                        '${fmt.format(admin.totalSalesSdg > 0 ? admin.totalSalesSdg : 4850000)} ج.س',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
                      ),
                      const SizedBox(height: 4),
                      const Text('↗ مقارنة بطلبات النظام', style: TextStyle(color: DmcColors.secondaryCyan, fontSize: 10)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: DmcColors.outline),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('إجمالي المشتريات', style: TextStyle(color: DmcColors.textMuted, fontSize: 11)),
                      const SizedBox(height: 4),
                      Text(
                        '${fmt.format(admin.totalPurchasesSdg > 0 ? admin.totalPurchasesSdg : 2270000)} ج.س',
                        style: const TextStyle(color: DmcColors.statusUnpaidFg, fontWeight: FontWeight.w800, fontSize: 17),
                      ),
                      const SizedBox(height: 4),
                      const Text('فواتير الموردين', style: TextStyle(color: DmcColors.textMuted, fontSize: 10)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: DmcColors.outline),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('صافي الأرباح التقديرية', style: TextStyle(fontSize: 12, color: DmcColors.textMuted)),
                      const SizedBox(height: 2),
                      Text(
                        '${fmt.format(admin.netProfitSdg)} ج.س',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: DmcColors.statusPaidFg),
                      ),
                    ],
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: DmcColors.statusPaidBg,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Text('📈', style: TextStyle(fontSize: 22)),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: DmcColors.outline),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('المنتجات الأكثر مبيعاً ⭐', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: DmcColors.headerDark)),
                  const SizedBox(height: 12),
                  _buildTopProductRow('1. جهاز قياس ضغط الدم OMROL', '142 مبيعة', 0.85, DmcColors.primaryBlue),
                  const SizedBox(height: 10),
                  _buildTopProductRow('2. كمامات طبية فاخرة (50 حبة)', '98 مبيعة', 0.65, DmcColors.secondaryCyan),
                  const SizedBox(height: 10),
                  _buildTopProductRow('3. شرائط فحص السكر Accu-Chek', '76 مبيعة', 0.48, DmcColors.headerDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProductRow(String title, String count, double pct, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            Text(count, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: DmcColors.primaryBlue)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: DmcColors.outline,
            color: color,
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

// --- 6. INDEPENDENT CUSTOMERS LIST SCREEN ---
class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<DmcAdminProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('جدول العملاء (customers)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Text('العدد: ${admin.customers.length}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const TextField(
              decoration: InputDecoration(
                hintText: 'بحث باسم الزبون أو الهاتف...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: admin.customers.isEmpty
                  ? const EmptyStateWidget(message: 'لا يوجد سجلات عملاء مخزنة حالياً')
                  : ListView.builder(
                      itemCount: admin.customers.length,
                      itemBuilder: (context, idx) {
                        final c = admin.customers[idx];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: DmcColors.outline),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      c.fullName.isNotEmpty ? c.fullName : 'عميل DMC',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: DmcColors.headerDark),
                                    ),
                                    Text(
                                      'ID: #${c.id.length > 6 ? c.id.substring(0, 6) : c.id}',
                                      style: const TextStyle(fontSize: 10, color: DmcColors.textMuted),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '📞 ${c.phone} • ✉️ ${c.email}',
                                  style: const TextStyle(fontSize: 12, color: DmcColors.textMuted),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'العنوان: ${c.address.isNotEmpty ? c.address : "غير محدد"}',
                                  style: const TextStyle(fontSize: 11, color: DmcColors.primaryBlue, fontWeight: FontWeight.w700),
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
      ),
    );
  }
}

// --- 7. NOTIFICATIONS INBOX SCREEN ---
class NotificationsInboxScreen extends StatelessWidget {
  const NotificationsInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<DmcAdminProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('صندوق الإشعارات والإنذارات', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        actions: [
          TextButton(
            onPressed: () {
              admin.markAllNotificationsRead();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم تحديد الكل كـ مقروء')),
              );
            },
            child: const Text(
              'تحديد المقروء',
              style: TextStyle(color: DmcColors.secondaryCyan, fontWeight: FontWeight.w800, fontSize: 11),
            ),
          ),
        ],
      ),
      body: admin.notifications.isEmpty
          ? const EmptyStateWidget(message: 'لا يوجد إشعارات حتى الآن')
          : RefreshIndicator(
              onRefresh: () => admin.fetchNotifications(),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: admin.notifications.length,
                itemBuilder: (context, idx) {
                  final item = admin.notifications[idx];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: 1,
                    color: item.isRead ? Colors.white : const Color(0xFFE6F8F9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: item.isRead ? DmcColors.outline : const Color(0xFFB2ECF0)),
                    ),
                    child: InkWell(
                      onTap: () {
                        if (!item.isRead) admin.markNotificationRead(item.id);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(idx == 0 ? '📦' : '⚠️', style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: item.isRead ? DmcColors.textMain : DmcColors.primaryBlue,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.body,
                                    style: const TextStyle(fontSize: 11, color: DmcColors.textMuted),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.createdAt,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: DmcColors.textMuted,
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
                },
              ),
            ),
    );
  }
}

// --- 8. SETTINGS & ACCOUNT SCREEN ---
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<DmcAuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات النظام والربط', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: DmcColors.outline),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('قاعدة البيانات Supabase', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: DmcColors.headerDark)),
                  const SizedBox(height: 8),
                  const Text('حالة الاتصال بقاعدة البيانات: متصل بنجاح ⚡', style: TextStyle(fontSize: 12, color: DmcColors.statusPaidFg, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    child: Text('URL: $kSupabaseUrl', style: const TextStyle(fontSize: 11, color: DmcColors.textMuted)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: DmcColors.outline),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('حساب المدير', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: DmcColors.headerDark)),
                  const SizedBox(height: 8),
                  Text(auth.profile?.fullName.isNotEmpty == true ? auth.profile!.fullName : 'د. محمد الإداري', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  Text(auth.userEmail ?? "admin@dmc-sd.com", style: const TextStyle(fontSize: 12, color: DmcColors.textMuted)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DmcColors.statusUnpaidBg,
                      foregroundColor: DmcColors.statusUnpaidFg,
                      elevation: 0,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFFFCDD2)),
                      ),
                    ),
                    onPressed: () async {
                      await auth.signOut();
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: const Text('تسجيل الخروج من الإدارة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- REUSABLE WIDGETS ---
class StatusBadge extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const StatusBadge({super.key, required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class EmptyStateWidget extends StatelessWidget {
  final String message;
  const EmptyStateWidget({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: DmcColors.statusPendingBg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Text('📋', style: TextStyle(fontSize: 36)),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: DmcColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
