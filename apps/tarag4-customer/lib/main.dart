import 'dart:async';
import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' as intl;
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_config.dart';

// --- SUPABASE & BACKEND CONSTANTS ---
const String kSupabaseUrl = "https://jvjtgzewumfecjdpekna.supabase.co";
const String kSupabaseAnonKey =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp2anRnemV3dW1mZWNqZHBla25hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE2NDYzMzcsImV4cCI6MjEwNzIyMjMzN30.1gck73ek8ErBtcF7xAtFM1TdvNim_1NzFVNej_mptBE";

// --- BRAND DESIGN TOKENS ---
class DmcColors {
  static const Color headerDark = Color(0xFF0A2F6B);
  static const Color primaryBlue = Color(0xFF0A47A8);
  static const Color secondaryCyan = Color(0xFF00B8C4);
  static const Color background = Color(0xFFF3F7FC);
  static const Color surface = Colors.white;
  static const Color outline = Color(0xFFE1E9F3);
  static const Color outlineVariant = Color(0xFFC3D0E0);
  static const Color textMain = Color(0xFF1A212D);
  static const Color textMuted = Color(0xFF566171);

  static const Color statusAvailableBg = Color(0xFFE6F7F5);
  static const Color statusAvailableFg = Color(0xFF00897B);
  static const Color statusOutBg = Color(0xFFFFEBEE);
  static const Color statusOutFg = Color(0xFFD32F2F);
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
        ChangeNotifierProxyProvider<DmcAuthProvider, DmcCustomerProvider>(
          create: (_) => DmcCustomerProvider(),
          update: (_, auth, customer) {
            customer ??= DmcCustomerProvider();
            customer.updateAuth(auth.accessToken, auth.userId, auth.userEmail, auth.profile);
            return customer;
          },
        ),
      ],
      child: const DmcCustomerApp(),
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
    this.role = 'customer',
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
      category: json['category'] ?? 'equipment',
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

  DeliveryArea({
    required this.id,
    required this.name,
    required this.deliveryFee,
  });

  factory DeliveryArea.fromJson(Map<String, dynamic> json) {
    return DeliveryArea(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class CartItem {
  final ProductItem product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double totalSdg(double usdRate) => product.priceUsd * usdRate * quantity;
}

class OrderItemModel {
  final String id;
  final String orderId;
  final String productId;
  final String productName;
  final int quantity;
  final double unitPriceUsd;
  final double unitPriceSdg;
  final double totalPriceSdg;

  OrderItemModel({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPriceUsd,
    required this.unitPriceSdg,
    required this.totalPriceSdg,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json['id'] ?? '',
      orderId: json['order_id'] ?? '',
      productId: json['product_id'] ?? '',
      productName: json['product_name'] ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPriceUsd: (json['unit_price_usd'] as num?)?.toDouble() ?? 0.0,
      unitPriceSdg: (json['unit_price_sdg'] as num?)?.toDouble() ?? 0.0,
      totalPriceSdg: (json['total_price_sdg'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class OrderModel {
  final String id;
  final String orderNumber;
  final String customerName;
  final String phone;
  final String deliveryAreaName;
  final String detailedAddress;
  final String deliveryType;
  final String status;
  final double subtotalSdg;
  final double deliveryFeeSdg;
  final double totalSdg;
  final String createdAt;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.customerName,
    required this.phone,
    required this.deliveryAreaName,
    required this.detailedAddress,
    required this.deliveryType,
    required this.status,
    required this.subtotalSdg,
    required this.deliveryFeeSdg,
    required this.totalSdg,
    required this.createdAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] ?? '',
      orderNumber: json['order_number'] ?? '',
      customerName: json['customer_name'] ?? '',
      phone: json['phone'] ?? '',
      deliveryAreaName: json['delivery_area_name'] ?? '',
      detailedAddress: json['detailed_address'] ?? '',
      deliveryType: json['delivery_type'] ?? 'delivery',
      status: json['status'] ?? 'جديد',
      subtotalSdg: (json['subtotal_sdg'] as num?)?.toDouble() ?? 0.0,
      deliveryFeeSdg: (json['delivery_fee_sdg'] as num?)?.toDouble() ?? 0.0,
      totalSdg: (json['total_sdg'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] ?? '',
    );
  }
}

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final String createdAt;
  final String? readAt;

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

  bool _isLoading = false;
  String? _errorMessage;

  String? get accessToken => _accessToken;
  String? get userId => _userId;
  String? get userEmail => _userEmail;
  UserProfile? get profile => _profile;
  bool get isAuthenticated => _accessToken != null && _accessToken!.isNotEmpty;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

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
      await fetchProfile();
    }
    notifyListeners();
  }

  String _extractErrorMessage(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map) {
        final msg = body['error_description'] ?? body['msg'] ?? body['message'] ?? body['error'];
        if (msg != null) {
          final str = msg.toString().toLowerCase();
          if (str.contains('rate limit') || str.contains('too many requests')) {
            return 'اتبعتت رسائل كتير، استنى دقايق';
          }
          if (str.contains('smtp') || str.contains('sending') || str.contains('email provider')) {
            return 'ما قدرنا نرسل البريد';
          }
          return msg.toString();
        }
      }
    } catch (_) {}
    return fallback;
  }

  // 1) SignUp
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
          "data": {"full_name": name, "phone": phone}
        }),
      );

      if (res.statusCode >= 200 && res.statusCode < 300) {
        _userEmail = email.trim();
        _setLoading(false);
        return true;
      } else {
        _errorMessage = _extractErrorMessage(res, 'فشل إنشاء الحساب');
      }
    } catch (e) {
      _errorMessage = 'تعذر الاتصال بالخادم، يرجى المحاولة لاحقاً';
    }
    _setLoading(false);
    return false;
  }

  // Verify OTP (SignUp or Recovery)
  Future<bool> verifyOtp(String email, String code, String type) async {
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
        await _saveSession(body);
        _setLoading(false);
        return true;
      } else {
        _errorMessage = _extractErrorMessage(res, 'رمز التأكيد غير صحيح أو منتهي الصلاحية');
      }
    } catch (_) {
      _errorMessage = 'رمز التأكيد غير صحيح أو منتهي الصلاحية';
    }
    _setLoading(false);
    return false;
  }

  // Resend OTP
  Future<bool> resendOtp(String email, String type) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/resend'),
        headers: {'apikey': kSupabaseAnonKey, 'Content-Type': 'application/json'},
        body: jsonEncode({
          "type": type,
          "email": email.trim(),
        }),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        _setLoading(false);
        return true;
      } else {
        _errorMessage = _extractErrorMessage(res, 'ما قدرنا نرسل البريد');
      }
    } catch (_) {
      _errorMessage = 'ما قدرنا نرسل البريد';
    }
    _setLoading(false);
    return false;
  }

  // 2) SignIn
  Future<bool> signIn(String email, String password) async {
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
        final errText = _extractErrorMessage(res, 'خطأ في تسجيل الدخول');
        if (errText.contains('Email not confirmed') || errText.contains('not_confirmed')) {
          await resendOtp(email, 'signup');
          _userEmail = email.trim();
          _errorMessage = 'البريد غير مؤكد، تم إرسال رمز جديد بريدياً';
          _setLoading(false);
          return false;
        }
        _errorMessage = errText;
      }
    } catch (_) {
      _errorMessage = 'تعذر الاتصال بالشبكة';
    }
    _setLoading(false);
    return false;
  }

  // 3) Forgot Password & Update Password
  Future<bool> recoverPassword(String email) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/recover'),
        headers: {'apikey': kSupabaseAnonKey, 'Content-Type': 'application/json'},
        body: jsonEncode({"email": email.trim()}),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        _userEmail = email.trim();
        _setLoading(false);
        return true;
      } else {
        _errorMessage = _extractErrorMessage(res, 'ما قدرنا نرسل البريد');
      }
    } catch (_) {
      _errorMessage = 'تعذر الإرسال';
    }
    _setLoading(false);
    return false;
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
      if (res.statusCode >= 200 && res.statusCode < 300) {
        _setLoading(false);
        return true;
      } else {
        _errorMessage = _extractErrorMessage(res, 'فشل تحديث كلمة المرور');
      }
    } catch (_) {
      _errorMessage = 'خطأ في الاتصال';
    }
    _setLoading(false);
    return false;
  }

  // Refresh Session on 401
  Future<bool> refreshAccessToken() async {
    if (_refreshToken == null) return false;
    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/token?grant_type=refresh_token'),
        headers: {'apikey': kSupabaseAnonKey, 'Content-Type': 'application/json'},
        body: jsonEncode({"refresh_token": _refreshToken}),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = jsonDecode(res.body);
        await _saveSession(body);
        return true;
      }
    } catch (_) {}
    await signOut();
    return false;
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
      } else if (res.statusCode == 401) {
        if (await refreshAccessToken()) {
          await fetchProfile();
        }
      }
    } catch (_) {}
  }

  Future<bool> updateProfile(String fullName, String phone) async {
    if (_userId == null) return false;
    _setLoading(true);
    try {
      final res = await http.patch(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag4_profiles?id=eq.$_userId'),
        headers: {..._headers, 'Prefer': 'return=representation'},
        body: jsonEncode({"full_name": fullName, "phone": phone}),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        await fetchProfile();
        _setLoading(false);
        return true;
      }
    } catch (_) {}
    _setLoading(false);
    return false;
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

    await fetchProfile();
    notifyListeners();
  }

  Future<void> signOut() async {
    _accessToken = null;
    _refreshToken = null;
    _userId = null;
    _profile = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }
}

// --- MAIN CUSTOMER DATA PROVIDER ---
class DmcCustomerProvider extends ChangeNotifier {
  String? _token;
  String? _userId;
  String? _userEmail;
  UserProfile? _profile;

  double _usdRateToday = 3000.0;
  List<ProductItem> _products = [];
  List<DeliveryArea> _deliveryAreas = [];
  List<OrderModel> _myOrders = [];
  List<NotificationItem> _notifications = [];
  final List<CartItem> _cart = [];

  DeliveryArea? _selectedArea;
  String _selectedCategory = 'all';
  String _searchQuery = '';
  bool _isLoadingData = false;
  Timer? _periodicTimer;

  double get usdRateToday => _usdRateToday;
  List<ProductItem> get products => _products;
  List<DeliveryArea> get deliveryAreas => _deliveryAreas;
  List<OrderModel> get myOrders => _myOrders;
  List<NotificationItem> get notifications => _notifications;
  List<CartItem> get cart => _cart;
  DeliveryArea? get selectedArea => _selectedArea;
  String get selectedCategory => _selectedCategory;
  bool get isLoadingData => _isLoadingData;
  int get unreadNotificationsCount => _notifications.where((n) => !n.isRead).length;

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
    if (!quiet) {
      _isLoadingData = true;
      notifyListeners();
    }
    await Future.wait([
      fetchSettings(),
      fetchDeliveryAreas(),
      fetchProducts(),
      fetchMyOrders(),
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
        final List data = jsonDecode(res.body);
        if (data.isNotEmpty) {
          _usdRateToday = (data.first['usd_rate'] as num?)?.toDouble() ?? 3000.0;
        }
      }
    } catch (_) {}
  }

  Future<void> fetchDeliveryAreas() async {
    try {
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag4_delivery_areas?select=*&is_active=eq.true'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        _deliveryAreas = data.map((e) => DeliveryArea.fromJson(e)).toList();
        if (_deliveryAreas.isNotEmpty && _selectedArea == null) {
          _selectedArea = _deliveryAreas.first;
        }
      }
    } catch (_) {}
  }

  Future<void> fetchProducts() async {
    try {
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag4_products?select=*&is_visible=eq.true&order=created_at.desc'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        _products = data.map((e) => ProductItem.fromJson(e)).toList();
      }
    } catch (_) {}
  }

  Future<void> fetchMyOrders() async {
    if (_userId == null) return;
    try {
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag4_orders?select=*&customer_id=eq.$_userId&order=created_at.desc'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        _myOrders = data.map((e) => OrderModel.fromJson(e)).toList();
      }
    } catch (_) {}
  }

  Future<List<OrderItemModel>> fetchOrderItems(String orderId) async {
    try {
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag4_order_items?select=*&order_id=eq.$orderId'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        return data.map((e) => OrderItemModel.fromJson(e)).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> fetchNotifications() async {
    if (_userId == null) return;
    try {
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag4_notifications?or=(to_user.eq.$_userId,to_role.eq.customer)&order=created_at.desc'),
        headers: _headers,
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        _notifications = data.map((e) => NotificationItem.fromJson(e)).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> markNotificationAsRead(String id) async {
    try {
      final nowIso = DateTime.now().toIso8601String();
      await http.patch(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag4_notifications?id=eq.$id'),
        headers: _headers,
        body: jsonEncode({"read_at": nowIso}),
      );
    } catch (_) {}
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx != -1) {
      final old = _notifications[idx];
      _notifications[idx] = NotificationItem(
        id: old.id,
        title: old.title,
        body: old.body,
        createdAt: old.createdAt,
        readAt: DateTime.now().toIso8601String(),
      );
      notifyListeners();
    }
  }

  List<ProductItem> get filteredProducts {
    return _products.where((p) {
      final matchesCat = _selectedCategory == 'all' || p.category == _selectedCategory;
      final matchesSearch = p.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCat && matchesSearch;
    }).toList();
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedArea(DeliveryArea area) {
    _selectedArea = area;
    notifyListeners();
  }

  void addToCart(ProductItem product, {int quantity = 1}) {
    final idx = _cart.indexWhere((item) => item.product.id == product.id);
    if (idx != -1) {
      _cart[idx].quantity += quantity;
    } else {
      _cart.add(CartItem(product: product, quantity: quantity));
    }
    notifyListeners();
  }

  void updateCartQuantity(String productId, int delta) {
    final idx = _cart.indexWhere((item) => item.product.id == productId);
    if (idx != -1) {
      _cart[idx].quantity += delta;
      if (_cart[idx].quantity <= 0) {
        _cart.removeAt(idx);
      }
      notifyListeners();
    }
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  Future<bool> reorderPreviousOrder(OrderModel order) async {
    final items = await fetchOrderItems(order.id);
    if (items.isEmpty) return false;

    for (var item in items) {
      final match = _products.firstWhere(
        (p) => p.id == item.productId,
        orElse: () => ProductItem(
          id: item.productId,
          name: item.productName,
          category: 'equipment',
          priceUsd: item.unitPriceUsd,
          stockQuantity: 10,
          imageUrl: '',
          isVisible: true,
          description: '',
        ),
      );
      addToCart(match, quantity: item.quantity);
    }
    return true;
  }

  double get cartSubtotalSdg {
    return _cart.fold(0.0, (sum, item) => sum + item.totalSdg(_usdRateToday));
  }

  double get cartDeliveryFeeSdg => _selectedArea?.deliveryFee ?? 1500.0;
  double get cartGrandTotalSdg => cartSubtotalSdg + cartDeliveryFeeSdg;

  Future<bool> submitOrder({
    required String name,
    required String phone,
    required String address,
    required String deliveryType,
  }) async {
    final orderNum = "DMC-${(8000 + (DateTime.now().millisecondsSinceEpoch % 9999))}";
    final subtotal = cartSubtotalSdg;
    final fee = deliveryType == 'pickup' ? 0.0 : cartDeliveryFeeSdg;
    final grandTotal = subtotal + fee;

    try {
      if (_userId == null) return false;

      // 1. Insert order
      final orderRes = await http.post(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag4_orders'),
        headers: _headers,
        body: jsonEncode({
          "order_number": orderNum,
          "customer_id": _userId,
          "customer_name": name,
          "phone": phone,
          "delivery_area_name": _selectedArea?.name ?? 'عطبرة',
          "detailed_address": address,
          "delivery_type": deliveryType,
          "payment_method": "كاش عند الاستلام",
          "status": "جديد",
          "subtotal_sdg": subtotal,
          "delivery_fee_sdg": fee,
          "total_sdg": grandTotal,
          "usd_rate_at_purchase": _usdRateToday,
        }),
      );

      if (orderRes.statusCode >= 200 && orderRes.statusCode < 300) {
        final List createdList = jsonDecode(orderRes.body);
        final String orderId = createdList.first['id'];

        // 2. Insert order items
        for (var item in _cart) {
          await http.post(
            Uri.parse('$kSupabaseUrl/rest/v1/tarag4_order_items'),
            headers: _headers,
            body: jsonEncode({
              "customer_id": _userId,
              "order_id": orderId,
              "product_id": item.product.id,
              "product_name": item.product.name,
              "quantity": item.quantity,
              "unit_price_usd": item.product.priceUsd,
              "unit_price_sdg": item.product.priceUsd * _usdRateToday,
              "total_price_sdg": item.totalSdg(_usdRateToday),
            }),
          );
        }

        // 3. Send Notification to Admin (Event: A customer submits a new order)
        await http.post(
          Uri.parse('$kSupabaseUrl/rest/v1/tarag4_notifications'),
          headers: _headers,
          body: jsonEncode({
            "to_role": "admin",
            "title": "طلب جديد بانتظار التجهيز",
            "body": "طلب جديد #$orderNum من $name بقيمة ${intl.NumberFormat('#,##0').format(grandTotal)} ج.س",
            "data": {"order_id": orderId, "customer_id": _userId},
          }),
        );

        clearCart();
        await fetchMyOrders();
        return true;
      }
    } catch (e) {
      debugPrint("Submit order error: $e");
    }
    return false;
  }

  void _setupPushNotifications() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();

      if (token != null && _token != null) {
        // Register device token RPC
        await http.post(
          Uri.parse('$kSupabaseUrl/rest/v1/rpc/tarag4_register_device'),
          headers: {
            'apikey': kSupabaseAnonKey,
            'Authorization': 'Bearer $_token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            "device_token": token,
            "app_name": "customer",
          }),
        );
      }

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        fetchNotifications();
        fetchMyOrders();
        fetchProducts();
      });
    } catch (_) {}
  }
}

// --- HELPER FUNCTIONS FOR CATEGORIES AND EMOJIS ---
String getCategoryEmoji(String cat) {
  switch (cat) {
    case 'equipment':
      return '🩺';
    case 'consumables':
      return '😷';
    case 'lab':
      return '🔬';
    default:
      return '🩺';
  }
}

String getCategoryLocalizedName(String cat) {
  switch (cat) {
    case 'equipment':
      return 'قسم: معدات طبية';
    case 'consumables':
      return 'قسم: مستهلكات';
    case 'lab':
      return 'قسم: أجهزة مختبر';
    default:
      return 'قسم: معدات طبية';
  }
}

// --- MAIN FLUTTER APP WIDGET ---
class DmcCustomerApp extends StatelessWidget {
  const DmcCustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Diala DMC',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'SD'),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: DmcColors.primaryBlue,
          primary: DmcColors.primaryBlue,
          secondary: DmcColors.secondaryCyan,
          surface: DmcColors.surface,
          background: DmcColors.background,
        ),
        scaffoldBackgroundColor: DmcColors.background,
        fontFamily: 'Cairo',
      ),
      home: const AuthWrapperScreen(),
    );
  }
}

class AuthWrapperScreen extends StatelessWidget {
  const AuthWrapperScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<DmcAuthProvider>();
    if (!auth.isAuthenticated) {
      return const AuthFlowScreen();
    }
    return const MainNavigationTabs();
  }
}

// --- AUTHENTICATION FLOW SCREEN (FULL CONTRACT COMPLIANT) ---
enum AuthMode { signIn, signUp, verifyOtp, forgotPassword, newPassword }

class AuthFlowScreen extends StatefulWidget {
  const AuthFlowScreen({super.key});

  @override
  State<AuthFlowScreen> createState() => _AuthFlowScreenState();
}

class _AuthFlowScreenState extends State<AuthFlowScreen> {
  AuthMode _mode = AuthMode.signIn;

  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  int _resendTimerSeconds = 60;
  Timer? _timer;

  String? _nameError;
  String? _phoneError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;

  void _startResendTimer() {
    _resendTimerSeconds = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimerSeconds > 0) {
        setState(() => _resendTimerSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  bool _validateSignUpFields() {
    setState(() {
      _nameError = _fullNameController.text.trim().isEmpty ? 'الاسم الكامل مطلوب' : null;
      _phoneError = _phoneController.text.trim().isEmpty ? 'رقم الهاتف مطلوب' : null;
      _emailError = _emailController.text.trim().isEmpty ? 'البريد الإلكتروني مطلوب' : null;
      _passwordError = _passwordController.text.length < 6 ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل' : null;
      _confirmPasswordError = _confirmPasswordController.text != _passwordController.text
          ? 'كلمتا المرور غير متطابقتين'
          : null;
    });
    return _nameError == null &&
        _phoneError == null &&
        _emailError == null &&
        _passwordError == null &&
        _confirmPasswordError == null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<DmcAuthProvider>();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Header Logo
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [DmcColors.headerDark, DmcColors.primaryBlue],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'DMC',
                      style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Diala Medical Equipment',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: DmcColors.headerDark),
                ),
                const SizedBox(height: 4),
                const Text(
                  'معدات ومستهلكات طبية - حساب الزبون',
                  style: TextStyle(fontSize: 13, color: DmcColors.textMuted),
                ),
                const SizedBox(height: 24),

                // Form Container
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: DmcColors.outline),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Global Error Alert Box
                      if (auth.errorMessage != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFFCDD2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Color(0xFFD32F2F), size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  auth.errorMessage!,
                                  style: const TextStyle(color: Color(0xFFD32F2F), fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Form Body depends on _mode
                      if (_mode == AuthMode.signIn) ...[
                        const Text('تسجيل الدخول',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: DmcColors.headerDark)),
                        const SizedBox(height: 14),

                        const Text('البريد الإلكتروني', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'name@domain.com',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 14),

                        const Text('كلمة المرور', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: '••••••••',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () {
                              auth.clearError();
                              setState(() => _mode = AuthMode.forgotPassword);
                            },
                            child: const Text('نسيت كلمة المرور؟', style: TextStyle(color: DmcColors.primaryBlue, fontSize: 13)),
                          ),
                        ),
                        const SizedBox(height: 10),

                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: DmcColors.primaryBlue,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: auth.isLoading
                                ? null
                                : () async {
                                    final success = await auth.signIn(
                                      _emailController.text,
                                      _passwordController.text,
                                    );
                                    if (!success && auth.errorMessage?.contains('رمز جديد') == true) {
                                      _startResendTimer();
                                      setState(() => _mode = AuthMode.verifyOtp);
                                    }
                                  },
                            child: auth.isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text('تسجيل الدخول',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                        ),
                        const SizedBox(height: 14),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('ليس لديك حساب؟', style: TextStyle(fontSize: 13, color: DmcColors.textMuted)),
                            TextButton(
                              onPressed: () {
                                auth.clearError();
                                setState(() => _mode = AuthMode.signUp);
                              },
                              child: const Text('حساب جديد',
                                  style: TextStyle(color: DmcColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ],
                        ),
                      ] else if (_mode == AuthMode.signUp) ...[
                        const Text('حساب جديد',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: DmcColors.headerDark)),
                        const SizedBox(height: 14),

                        const Text('الاسم الكامل', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _fullNameController,
                          decoration: InputDecoration(
                            hintText: 'د. أحمد مصطفى',
                            errorText: _nameError,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 10),

                        const Text('رقم الهاتف', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            hintText: '0912345678',
                            errorText: _phoneError,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 10),

                        const Text('البريد الإلكتروني', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'name@domain.com',
                            errorText: _emailError,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 10),

                        const Text('كلمة المرور', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: '6 أحرف على الأقل',
                            errorText: _passwordError,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        const Text('تأكيد كلمة المرور', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          decoration: InputDecoration(
                            hintText: 'أعد كتابة كلمة المرور',
                            errorText: _confirmPasswordError,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: DmcColors.primaryBlue,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: auth.isLoading
                                ? null
                                : () async {
                                    if (_validateSignUpFields()) {
                                      final success = await auth.signUp(
                                        name: _fullNameController.text,
                                        phone: _phoneController.text,
                                        email: _emailController.text,
                                        password: _passwordController.text,
                                      );
                                      if (success) {
                                        _startResendTimer();
                                        setState(() => _mode = AuthMode.verifyOtp);
                                      }
                                    }
                                  },
                            child: auth.isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text('إنشاء حساب جديد',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('لديك حساب بالفعل؟', style: TextStyle(fontSize: 13, color: DmcColors.textMuted)),
                            TextButton(
                              onPressed: () {
                                auth.clearError();
                                setState(() => _mode = AuthMode.signIn);
                              },
                              child: const Text('تسجيل الدخول',
                                  style: TextStyle(color: DmcColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 13)),
                            ),
                          ],
                        ),
                      ] else if (_mode == AuthMode.verifyOtp) ...[
                        const Text('بعتنا رمز على بريدك',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: DmcColors.headerDark)),
                        const SizedBox(height: 6),
                        Text(
                          'أدخل رمز التأكيد المكون من 6 أرقام المرسل إلى ${_emailController.text}',
                          style: const TextStyle(fontSize: 12, color: DmcColors.textMuted),
                        ),
                        const SizedBox(height: 16),

                        TextField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 6,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 8),
                          decoration: InputDecoration(
                            counterText: '',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: DmcColors.primaryBlue,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: auth.isLoading
                                ? null
                                : () async {
                                    await auth.verifyOtp(
                                      _emailController.text,
                                      _otpController.text,
                                      'signup',
                                    );
                                  },
                            child: auth.isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text('تأكيد الرمز والدخول',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                        ),
                        const SizedBox(height: 12),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: _resendTimerSeconds > 0 || auth.isLoading
                                  ? null
                                  : () async {
                                      final res = await auth.resendOtp(_emailController.text, 'signup');
                                      if (res) _startResendTimer();
                                    },
                              child: Text(
                                _resendTimerSeconds > 0
                                    ? 'إعادة الإرسال خلال ($_resendTimerSeconds ثانية)'
                                    : 'إعادة إرسال الرمز',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                auth.clearError();
                                setState(() => _mode = AuthMode.signUp);
                              },
                              child: const Text('تغيير البريد', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        )
                      ] else if (_mode == AuthMode.forgotPassword) ...[
                        const Text('نسيت كلمة المرور',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: DmcColors.headerDark)),
                        const SizedBox(height: 6),
                        const Text('أدخل بريدك الإلكتروني لإرسال رمز استعادة كلمة المرور',
                            style: TextStyle(fontSize: 12, color: DmcColors.textMuted)),
                        const SizedBox(height: 14),

                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: 'name@domain.com',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: DmcColors.primaryBlue,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: auth.isLoading
                                ? null
                                : () async {
                                    final res = await auth.recoverPassword(_emailController.text);
                                    if (res) {
                                      _startResendTimer();
                                      setState(() => _mode = AuthMode.newPassword);
                                    }
                                  },
                            child: auth.isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text('إرسال رمز الاستعادة',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                        ),
                        const SizedBox(height: 12),

                        TextButton(
                          onPressed: () {
                            auth.clearError();
                            setState(() => _mode = AuthMode.signIn);
                          },
                          child: const Text('الرجوع لصفحة تسجيل الدخول', style: TextStyle(fontSize: 13)),
                        ),
                      ] else if (_mode == AuthMode.newPassword) ...[
                        const Text('تنسيق كلمة المرور الجديدة',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: DmcColors.headerDark)),
                        const SizedBox(height: 14),

                        const Text('رمز التأكيد (6 أرقام)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _otpController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 6,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 6),
                          decoration: InputDecoration(
                            counterText: '',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 10),

                        const Text('كلمة المرور الجديدة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            hintText: '6 أحرف على الأقل',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: DmcColors.primaryBlue,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: auth.isLoading
                                ? null
                                : () async {
                                    final verified = await auth.verifyOtp(
                                      _emailController.text,
                                      _otpController.text,
                                      'recovery',
                                    );
                                    if (verified) {
                                      final updated = await auth.updatePassword(_passwordController.text);
                                      if (updated) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('تم تحديث كلمة المرور بنجاح!')),
                                        );
                                      }
                                    }
                                  },
                            child: auth.isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text('تحديث كلمة المرور والدخول',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                        ),
                      ],
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

// --- MAIN NAVIGATION TABS ---
class MainNavigationTabs extends StatefulWidget {
  const MainNavigationTabs({super.key});

  @override
  State<MainNavigationTabs> createState() => _MainNavigationTabsState();
}

class _MainNavigationTabsState extends State<MainNavigationTabs> with WidgetsBindingObserver {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    CartScreen(),
    MyOrdersScreen(),
    ContactUsScreen(),
  ];

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
      context.read<DmcCustomerProvider>().fetchAllData(quiet: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: _screens),
        bottomNavigationBar: Container(
          height: 72,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: DmcColors.outline)),
          ),
          child: Row(
            children: [
              _buildNavItem(0, Icons.home_outlined, Icons.home, 'الرئيسية'),
              _buildNavItem(1, Icons.shopping_cart_outlined, Icons.shopping_cart, 'السلة'),
              _buildNavItem(2, Icons.receipt_long_outlined, Icons.receipt_long, 'طلباتي'),
              _buildNavItem(3, Icons.phone_outlined, Icons.phone, 'تواصل'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 56,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFD9E2FF) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isSelected ? activeIcon : icon,
                color: isSelected ? DmcColors.primaryBlue : DmcColors.textMuted,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? DmcColors.primaryBlue : DmcColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 1) HOME SCREEN ---
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DmcCustomerProvider>();
    final auth = context.watch<DmcAuthProvider>();
    final products = provider.filteredProducts;
    final unreadCount = provider.unreadNotificationsCount;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: DmcColors.outline)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 2,
                offset: Offset(0, 1),
              )
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [DmcColors.headerDark, DmcColors.primaryBlue],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(
                          child: Text(
                            'DMC',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Diala Medical',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: DmcColors.headerDark,
                              height: 1.2,
                            ),
                          ),
                          Text(
                            auth.profile?.fullName.isNotEmpty == true
                                ? 'أهلاً، ${auth.profile!.fullName}'
                                : 'معدات ومستهلكات طبية',
                            style: const TextStyle(
                              fontSize: 11,
                              color: DmcColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ProfileScreen()),
                          );
                        },
                        icon: const Icon(Icons.person_outline, color: DmcColors.textMain, size: 24),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                          );
                        },
                        icon: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.notifications_none, color: DmcColors.textMain, size: 24),
                            if (unreadCount > 0)
                              Positioned(
                                top: 2,
                                right: 2,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFD32F2F),
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(minWidth: 10, minHeight: 10),
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
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.fetchAllData(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: DmcColors.outline),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Color(0xFF64748B), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          onChanged: (val) => provider.setSearchQuery(val),
                          decoration: const InputDecoration(
                            hintText: 'بحث عن جهاز، كمامات، قفازات...',
                            hintStyle: TextStyle(fontSize: 14, color: DmcColors.textMuted),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildFilterChip(context, 'الكل', 'all'),
                    _buildFilterChip(context, 'معدات طبية', 'equipment'),
                    _buildFilterChip(context, 'مستهلكات', 'consumables'),
                    _buildFilterChip(context, 'أجهزة مختبر', 'lab'),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Delivery Strip Banner
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE6F8F9), Color(0xFFD4F4F6)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFB2ECF0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.local_shipping_outlined, color: Color(0xFF004D53), size: 18),
                          const SizedBox(width: 8),
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 13, color: Color(0xFF004D53), fontFamily: 'Cairo'),
                              children: [
                                const TextSpan(text: 'التوصيل إلى: '),
                                TextSpan(
                                  text: provider.selectedArea?.name ?? 'عطبرة',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: DmcColors.primaryBlue),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${intl.NumberFormat("#,##0").format(provider.cartDeliveryFeeSdg)} ج.س',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF004D53)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Product Grid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: provider.isLoadingData
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : products.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: Text('لا توجد منتجات متطابقة حالياً'),
                            ),
                          )
                        : GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.65,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: products.length,
                            itemBuilder: (context, index) {
                              final product = products[index];
                              final priceSdg = product.priceUsd * provider.usdRateToday;
                              final isAvailable = product.stockQuantity > 0;

                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ProductDetailScreen(product: product),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: DmcColors.outline),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 3,
                                        offset: Offset(0, 1),
                                      )
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        height: 110,
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Stack(
                                          children: [
                                            Center(
                                              child: Text(
                                                getCategoryEmoji(product.category),
                                                style: const TextStyle(fontSize: 38),
                                              ),
                                            ),
                                            Positioned(
                                              top: 6,
                                              right: 6,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: isAvailable
                                                      ? DmcColors.statusAvailableBg
                                                      : DmcColors.statusOutBg,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  isAvailable ? 'متوفر' : 'نفاد',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: isAvailable
                                                        ? DmcColors.statusAvailableFg
                                                        : DmcColors.statusOutFg,
                                                  ),
                                                ),
                                              ),
                                            )
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      SizedBox(
                                        height: 34,
                                        child: Text(
                                          product.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: DmcColors.textMain,
                                            height: 1.3,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),

                                      Text(
                                        '${intl.NumberFormat("#,##0").format(priceSdg)} ج.س',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: DmcColors.primaryBlue,
                                        ),
                                      ),
                                      Text(
                                        '(\$${product.priceUsd.toStringAsFixed(2)})',
                                        style: const TextStyle(fontSize: 10, color: DmcColors.textMuted),
                                      ),
                                      const Spacer(),

                                      SizedBox(
                                        width: double.infinity,
                                        height: 38,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: DmcColors.primaryBlue,
                                            padding: EdgeInsets.zero,
                                            elevation: 0,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                          onPressed: !isAvailable
                                              ? null
                                              : () {
                                                  provider.addToCart(product);
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(
                                                      content: Text('تمت إضافة المنتج للسلة'),
                                                      duration: Duration(seconds: 1),
                                                    ),
                                                  );
                                                },
                                          child: const Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.shopping_cart_outlined, size: 14, color: Colors.white),
                                              SizedBox(width: 6),
                                              Text(
                                                'أضف للسلة',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
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
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, String key) {
    final provider = context.watch<DmcCustomerProvider>();
    final isSelected = provider.selectedCategory == key;

    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: GestureDetector(
        onTap: () => provider.setCategory(key),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? DmcColors.primaryBlue : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? DmcColors.primaryBlue : DmcColors.outline,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : DmcColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- 2) PRODUCT DETAILS SCREEN ---
class ProductDetailScreen extends StatefulWidget {
  final ProductItem product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int quantity = 1;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DmcCustomerProvider>();
    final priceSdg = widget.product.priceUsd * provider.usdRateToday;
    final isAvailable = widget.product.stockQuantity > 0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: DmcColors.textMain),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'تفاصيل المنتج',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: DmcColors.textMain),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.shopping_cart_outlined, color: DmcColors.textMain),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CartScreen()),
                );
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 210,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: DmcColors.outline),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    )
                  ],
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Text(
                        getCategoryEmoji(widget.product.category),
                        style: const TextStyle(fontSize: 80),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: isAvailable ? DmcColors.statusAvailableBg : DmcColors.statusOutBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isAvailable ? 'متوفر (${widget.product.stockQuantity})' : 'نفاد من المخزن',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isAvailable ? DmcColors.statusAvailableFg : DmcColors.statusOutFg,
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Text(
                widget.product.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: DmcColors.headerDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                getCategoryLocalizedName(widget.product.category),
                style: const TextStyle(fontSize: 12, color: DmcColors.textMuted),
              ),
              const SizedBox(height: 12),

              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${intl.NumberFormat("#,##0").format(priceSdg)} ج.س',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: DmcColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(\$${widget.product.priceUsd.toStringAsFixed(2)})',
                    style: const TextStyle(fontSize: 13, color: DmcColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: DmcColors.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('وصف المنتج والمواصفات:',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(
                      widget.product.description.isEmpty
                          ? 'معدات ومستلزمات طبية معتمدة من شركة DMC عالية الجودة.'
                          : widget.product.description,
                      style: const TextStyle(fontSize: 13, color: DmcColors.textMuted, height: 1.6),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('الكمية المطلوبة:',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  Container(
                    decoration: BoxDecoration(
                      color: DmcColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: DmcColors.outline),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () {
                            if (quantity > 1) setState(() => quantity--);
                          },
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Text('-', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: DmcColors.primaryBlue)),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 36,
                          child: Text(
                            '$quantity',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                        InkWell(
                          onTap: () => setState(() => quantity++),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Text('+', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: DmcColors.primaryBlue)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DmcColors.primaryBlue,
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: !isAvailable
                      ? null
                      : () {
                          provider.addToCart(widget.product, quantity: quantity);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تمت إضافة المنتج للسلة')),
                          );
                          Navigator.pop(context);
                        },
                  icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 20),
                  label: const Text('أضف للسلة',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// --- 3) CART SCREEN ---
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DmcCustomerProvider>();
    final cart = provider.cart;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          automaticallyImplyLeading: false,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'سلة المشتريات',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: DmcColors.headerDark),
              ),
              Text(
                '${cart.length} عناصر',
                style: const TextStyle(fontSize: 12, color: DmcColors.textMuted),
              ),
            ],
          ),
        ),
        body: cart.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE2E8F0),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text('🛒', style: TextStyle(fontSize: 40)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text('السلة فارغة حالياً',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: DmcColors.headerDark)),
                    const SizedBox(height: 6),
                    const Text('لم تقم بإضافة أي معدات أو مستهلكات طبية إلى سلتك بعد.',
                        style: TextStyle(fontSize: 13, color: DmcColors.textMuted)),
                  ],
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: cart.length,
                      itemBuilder: (context, index) {
                        final item = cart[index];
                        final itemTotal = item.totalSdg(provider.usdRateToday);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: DmcColors.outline),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    getCategoryEmoji(item.product.category),
                                    style: const TextStyle(fontSize: 32),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.product.name,
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${intl.NumberFormat("#,##0").format(itemTotal)} ج.س',
                                      style: const TextStyle(
                                          color: DmcColors.primaryBlue,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),

                              Container(
                                decoration: BoxDecoration(
                                  color: DmcColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: DmcColors.outline),
                                ),
                                padding: const EdgeInsets.all(2),
                                child: Row(
                                  children: [
                                    InkWell(
                                      onTap: () => provider.updateCartQuantity(item.product.id, -1),
                                      child: Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Center(
                                          child: Text('-', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: DmcColors.primaryBlue)),
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 36,
                                      child: Text(
                                        '${item.quantity}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => provider.updateCartQuantity(item.product.id, 1),
                                      child: Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Center(
                                          child: Text('+', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: DmcColors.primaryBlue)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: DmcColors.outline)),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('مجموع المنتجات:', style: TextStyle(fontSize: 13, color: DmcColors.textMuted)),
                            Text(
                              '${intl.NumberFormat("#,##0").format(provider.cartSubtotalSdg)} ج.س',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('رسوم التوصيل المقدرة:', style: TextStyle(fontSize: 13, color: DmcColors.textMuted)),
                            Text(
                              '${intl.NumberFormat("#,##0").format(provider.cartDeliveryFeeSdg)} ج.س',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(height: 1, color: DmcColors.outline),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('الإجمالي الكلي:',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: DmcColors.headerDark)),
                            Text(
                              '${intl.NumberFormat("#,##0").format(provider.cartGrandTotalSdg)} ج.س',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: DmcColors.primaryBlue),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: DmcColors.primaryBlue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                              );
                            },
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('إتمام الطلب',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_back, color: Colors.white, size: 20),
                              ],
                            ),
                          ),
                        )
                      ],
                    ),
                  )
                ],
              ),
      ),
    );
  }
}

// --- 4) CHECKOUT SCREEN ---
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late TextEditingController nameController;
  late TextEditingController phoneController;
  final addressController = TextEditingController(text: 'عطبرة - السوق الكبير');
  String deliveryType = 'delivery';
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<DmcAuthProvider>();
    nameController = TextEditingController(text: auth.profile?.fullName ?? '');
    phoneController = TextEditingController(text: auth.profile?.phone ?? '');
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DmcCustomerProvider>();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: DmcColors.textMain),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('إتمام الطلب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: DmcColors.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('بيانات المستلم والتوصيل',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: DmcColors.headerDark)),
                    const SizedBox(height: 12),
                    const Text('الاسم بالكامل', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text('رقم الهاتف للاتصال', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text('منطقة التوصيل', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<DeliveryArea>(
                      initialValue: provider.selectedArea,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      items: provider.deliveryAreas.map((area) {
                        return DropdownMenuItem(
                          value: area,
                          child: Text('${area.name} (${intl.NumberFormat("#,##0").format(area.deliveryFee)} ج.س)'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) provider.setSelectedArea(val);
                      },
                    ),
                    const SizedBox(height: 10),
                    const Text('العنوان التفصيلي / اسم العيادة أو المستشفى',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: addressController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: DmcColors.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('طريقة الاستلام',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: DmcColors.headerDark)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => deliveryType = 'delivery'),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: deliveryType == 'delivery'
                                    ? DmcColors.primaryBlue.withValues(alpha: 0.04)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: deliveryType == 'delivery'
                                      ? DmcColors.primaryBlue
                                      : DmcColors.outline,
                                  width: deliveryType == 'delivery' ? 2 : 1,
                                ),
                              ),
                              child: const Center(
                                child: Text('توصيل للعنوان', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => deliveryType = 'pickup'),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: deliveryType == 'pickup'
                                    ? DmcColors.primaryBlue.withValues(alpha: 0.04)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: deliveryType == 'pickup'
                                      ? DmcColors.primaryBlue
                                      : DmcColors.outline,
                                  width: deliveryType == 'pickup' ? 2 : 1,
                                ),
                              ),
                              child: const Center(
                                child: Text('استلام من المحل', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: DmcColors.outlineVariant, style: BorderStyle.solid),
                      ),
                      child: const Row(
                        children: [
                          Text('💵', style: TextStyle(fontSize: 22)),
                          SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'طريقة الدفع: كاش عند الاستلام',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: DmcColors.headerDark,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'يتم الدفع نقداً عند استلام الشحنة والفاتورة',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: DmcColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: DmcColors.outline),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('المجموع الأصلي للمنتجات:', style: TextStyle(fontSize: 13)),
                        Text(
                          '${intl.NumberFormat("#,##0").format(provider.cartSubtotalSdg)} ج.س',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'رسوم توصيل (منطقة ${provider.selectedArea?.name ?? "عطبرة"}):',
                          style: const TextStyle(fontSize: 13),
                        ),
                        Text(
                          '${intl.NumberFormat("#,##0").format(deliveryType == 'pickup' ? 0.0 : provider.cartDeliveryFeeSdg)} ج.س',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Divider(height: 1, color: DmcColors.outline),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('المبلغ الإجمالي المطلوب:',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: DmcColors.primaryBlue)),
                        Text(
                          '${intl.NumberFormat("#,##0").format(provider.cartSubtotalSdg + (deliveryType == 'pickup' ? 0.0 : provider.cartDeliveryFeeSdg))} ج.س',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: DmcColors.primaryBlue),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: DmcColors.primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (nameController.text.trim().isEmpty || phoneController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('الرجاء إدخال الاسم ورقم الهاتف')),
                            );
                            return;
                          }

                          setState(() => isSubmitting = true);
                          final ok = await provider.submitOrder(
                            name: nameController.text.trim(),
                            phone: phoneController.text.trim(),
                            address: addressController.text.trim(),
                            deliveryType: deliveryType,
                          );
                          setState(() => isSubmitting = false);

                          if (mounted) {
                            if (ok) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('تم تأكيد الطلب بنجاح وإرساله للمشرف!')),
                              );
                              Navigator.pop(context);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('حدث خطأ أثناء تنفيذ الطلب')),
                              );
                            }
                          }
                        },
                  child: isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('تأكيد الطلب',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// --- 5) MY ORDERS SCREEN ---
class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DmcCustomerProvider>();
    final orders = provider.myOrders;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        automaticallyImplyLeading: false,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('قائمة طلباتي',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: DmcColors.headerDark)),
            Text('سجل المشتريات والطلبات الحالية', style: TextStyle(fontSize: 12, color: DmcColors.textMuted)),
          ],
        ),
      ),
      body: orders.isEmpty
          ? const Center(child: Text('لا توجد طلبات سابقة حتى الآن'))
          : RefreshIndicator(
              onRefresh: () => provider.fetchMyOrders(),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: orders.length,
                itemBuilder: (context, index) {
                  final order = orders[index];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: DmcColors.outline),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 2,
                          offset: Offset(0, 1),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'طلب #${order.orderNumber}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: DmcColors.headerDark,
                              ),
                            ),
                            _buildStatusChip(order.status),
                          ],
                        ),
                        const SizedBox(height: 6),

                        Text(
                          'المنطقة: ${order.deliveryAreaName} • العنوان: ${order.detailedAddress}',
                          style: const TextStyle(fontSize: 12, color: DmcColors.textMuted),
                        ),
                        const SizedBox(height: 12),
                        Container(height: 1, color: DmcColors.outline),
                        const SizedBox(height: 10),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${intl.NumberFormat("#,##0").format(order.totalSdg)} ج.س',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: DmcColors.primaryBlue,
                              ),
                            ),
                            Row(
                              children: [
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: DmcColors.primaryBlue,
                                    side: const BorderSide(color: DmcColors.primaryBlue),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => InvoiceScreen(order: order),
                                      ),
                                    );
                                  },
                                  child: const Text('عرض الفاتورة',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: DmcColors.primaryBlue,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  onPressed: () async {
                                    await provider.reorderPreviousOrder(order);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('تمت إضافة منتجات الطلب للسلة بنجاح')),
                                      );
                                    }
                                  },
                                  child: const Text('إعادة الطلب',
                                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            )
                          ],
                        )
                      ],
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg = const Color(0xFFFFF3E0);
    Color fg = const Color(0xFFE65100);

    if (status == 'تم التسليم' || status == 'تم' || status == 'مكتمل') {
      bg = const Color(0xFFE8F5E9);
      fg = const Color(0xFF2E7D32);
    } else if (status == 'جديد') {
      bg = const Color(0xFFE3F2FD);
      fg = const Color(0xFF1565C0);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Text(status, style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }
}

// --- 6) INVOICE SCREEN ---
class InvoiceScreen extends StatelessWidget {
  final OrderModel order;

  const InvoiceScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DmcCustomerProvider>();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: DmcColors.textMain),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('الفاتورة الالكترونية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.file_download_outlined, color: DmcColors.textMain),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('جاري تجهيز ملف PDF...')),
                );
              },
            ),
          ],
        ),
        body: FutureBuilder<List<OrderItemModel>>(
          future: provider.fetchOrderItems(order.id),
          builder: (context, snapshot) {
            final orderItems = snapshot.data ?? [];

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: DmcColors.outlineVariant, style: BorderStyle.solid),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('DMC',
                                    style: TextStyle(
                                        fontSize: 18, fontWeight: FontWeight.w800, color: DmcColors.headerDark)),
                                Text('Diala Medical & Chemical Equipment',
                                    style: TextStyle(fontSize: 10, color: DmcColors.textMuted)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text('فاتورة مبيعات',
                                    style: TextStyle(
                                        fontSize: 16, fontWeight: FontWeight.w800, color: DmcColors.primaryBlue)),
                                Text('#${order.orderNumber}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            )
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(height: 2, color: DmcColors.headerDark),
                        const SizedBox(height: 12),

                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('اسم العميل: ${order.customerName}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  Text('حالة الطلب: ${order.status}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('رقم الهاتف: ${order.phone}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  Text('المنطقة: ${order.deliveryAreaName}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        Container(
                          color: DmcColors.background,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          child: const Row(
                            children: [
                              Expanded(flex: 4, child: Text('الصنف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: DmcColors.textMuted))),
                              Expanded(flex: 2, child: Text('الكمية', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: DmcColors.textMuted))),
                              Expanded(flex: 3, child: Text('السعر', textAlign: TextAlign.left, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: DmcColors.textMuted))),
                              Expanded(flex: 3, child: Text('الإجمالي', textAlign: TextAlign.left, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: DmcColors.textMuted))),
                            ],
                          ),
                        ),
                        Container(height: 1, color: DmcColors.outline),

                        if (orderItems.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Center(child: Text('جاري تحميل تفاصيل الأصناف...')),
                          )
                        else
                          ...orderItems.map(
                            (item) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              decoration: const BoxDecoration(
                                border: Border(bottom: BorderSide(color: Color(0xFFF0F4F8))),
                              ),
                              child: Row(
                                children: [
                                  Expanded(flex: 4, child: Text(item.productName, style: const TextStyle(fontSize: 12))),
                                  Expanded(flex: 2, child: Text('${item.quantity}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
                                  Expanded(flex: 3, child: Text(intl.NumberFormat("#,##0").format(item.unitPriceSdg), textAlign: TextAlign.left, style: const TextStyle(fontSize: 12))),
                                  Expanded(flex: 3, child: Text(intl.NumberFormat("#,##0").format(item.totalPriceSdg), textAlign: TextAlign.left, style: const TextStyle(fontSize: 12))),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('مجموع الأصناف:', style: TextStyle(fontSize: 12, color: DmcColors.textMuted)),
                            Text('${intl.NumberFormat("#,##0").format(order.subtotalSdg)} ج.س', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('رسوم التوصيل (${order.deliveryAreaName}):', style: const TextStyle(fontSize: 12, color: DmcColors.textMuted)),
                            Text('${intl.NumberFormat("#,##0").format(order.deliveryFeeSdg)} ج.س', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(height: 1, color: Colors.black),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('المطلوب (كاش):',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: DmcColors.headerDark)),
                            Text(
                              '${intl.NumberFormat("#,##0").format(order.totalSdg)} ج.س',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: DmcColors.primaryBlue),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Center(
                          child: Text(
                            'شكراً لتعاملكم مع المحل الطبي DMC - نتمنى لكم دوام الصحة',
                            style: TextStyle(fontSize: 10, color: DmcColors.textMuted),
                          ),
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: DmcColors.primaryBlue,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم تحميل الفاتورة بنجاح PDF')),
                            );
                          },
                          icon: const Icon(Icons.download, color: Colors.white, size: 18),
                          label: const Text('تحميل PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            side: const BorderSide(color: DmcColors.primaryBlue),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم فتح رابط مشاركة الفاتورة')),
                            );
                          },
                          icon: const Icon(Icons.share, color: DmcColors.primaryBlue, size: 18),
                          label: const Text('مشاركة', style: TextStyle(color: DmcColors.primaryBlue, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// --- 7) CONTACT US SCREEN ---
class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({super.key});

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  Future<void> _checkLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الرجاء تفعيل خدمة الموقع GPS في الهاتف')),
        );
      }
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم رفض إذن الوصول للموقع')),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: const Text('إذن الموقع مطلوب'),
              content: const Text(
                  'تطبيق DMC يحتاج إذن الموقع لتحديد أسرع مسار توصيل. يرجى التفعيل من إعدادات الهاتف.'),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Geolocator.openAppSettings();
                  },
                  child: const Text('فتح الإعدادات'),
                )
              ],
            ),
          ),
        );
      }
      return;
    }

    final pos = await Geolocator.getCurrentPosition();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تحديد موقعك: ${pos.latitude.toStringAsFixed(3)}, ${pos.longitude.toStringAsFixed(3)}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DmcCustomerProvider>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        automaticallyImplyLeading: false,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('تواصل معنا', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: DmcColors.headerDark)),
            Text('خدمة العملاء DMC', style: TextStyle(fontSize: 12, color: DmcColors.textMuted)),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DmcColors.primaryBlue,
                      minimumSize: const Size.fromHeight(48),
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () async {
                      final url = Uri.parse('https://wa.me/249912345678');
                      if (await canLaunchUrl(url)) await launchUrl(url);
                    },
                    icon: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 20),
                    label: const Text('واتساب DMC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      side: const BorderSide(color: DmcColors.primaryBlue),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () async {
                      final url = Uri.parse('tel:0912345678');
                      if (await canLaunchUrl(url)) await launchUrl(url);
                    },
                    icon: const Icon(Icons.phone_outlined, color: DmcColors.primaryBlue, size: 20),
                    label: const Text('اتصال مباشر', style: TextStyle(color: DmcColors.primaryBlue, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: DmcColors.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('موقع المحل الرئيسي',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: DmcColors.headerDark)),
                  const SizedBox(height: 4),
                  const Text(
                    'السودان - ولاية نهر النيل - عطبرة - السوق الكبير بالقرب من مجمع العيادات',
                    style: TextStyle(fontSize: 12, color: DmcColors.textMuted),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _checkLocationPermission,
                    child: Container(
                      height: 140,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                          ),
                          child: const Text(
                            '📍 اضغط لتحديد الموقع الجغرافي',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: DmcColors.primaryBlue),
                          ),
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: DmcColors.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('مناطق التوصيل المتاحة ورسومها',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: DmcColors.headerDark)),
                  const SizedBox(height: 10),
                  ...provider.deliveryAreas.map((area) {
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: DmcColors.outline)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(area.name, style: const TextStyle(fontSize: 13)),
                          Text(
                            '${intl.NumberFormat("#,##0").format(area.deliveryFee)} ج.س',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: DmcColors.primaryBlue),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

// --- 8) NOTIFICATIONS SCREEN ---
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DmcCustomerProvider>();
    final notifs = provider.notifications;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: DmcColors.textMain),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('مركز الإشعارات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          centerTitle: true,
        ),
        body: notifs.isEmpty
            ? const Center(child: Text('لا توجد إشعارات جديدة حالياً'))
            : RefreshIndicator(
                onRefresh: () => provider.fetchNotifications(),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifs.length,
                  itemBuilder: (context, index) {
                    final item = notifs[index];

                    return GestureDetector(
                      onTap: () {
                        if (!item.isRead) {
                          provider.markNotificationAsRead(item.id);
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: item.isRead ? Colors.white : const Color(0xFFF0F7FF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: DmcColors.outline),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 6),
                              decoration: BoxDecoration(
                                color: item.isRead ? Colors.transparent : DmcColors.primaryBlue,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: item.isRead ? FontWeight.w700 : FontWeight.w800,
                                      color: DmcColors.headerDark,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.body,
                                    style: const TextStyle(fontSize: 12, color: DmcColors.textMuted, height: 1.4),
                                  ),
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
    );
  }
}

// --- 9) PROFILE SCREEN ---
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController nameController;
  late TextEditingController phoneController;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<DmcAuthProvider>();
    nameController = TextEditingController(text: auth.profile?.fullName ?? '');
    phoneController = TextEditingController(text: auth.profile?.phone ?? '');
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<DmcAuthProvider>();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 1,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: DmcColors.textMain),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('الملف الشخصي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: DmcColors.primaryBlue.withValues(alpha: 0.1),
                  child: const Text('👤', style: TextStyle(fontSize: 40)),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  auth.userEmail ?? '',
                  style: const TextStyle(fontSize: 14, color: DmcColors.textMuted),
                ),
              ),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: DmcColors.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('الاسم الكامل', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    const Text('رقم الهاتف', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: DmcColors.primaryBlue,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: isSaving
                            ? null
                            : () async {
                                setState(() => isSaving = true);
                                final ok = await auth.updateProfile(
                                  nameController.text.trim(),
                                  phoneController.text.trim(),
                                );
                                setState(() => isSaving = false);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(ok ? 'تم حفظ البيانات بنجاح' : 'حدث خطأ أثناء حفظ البيانات'),
                                    ),
                                  );
                                }
                              },
                        child: isSaving
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('حفظ التغييرات',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () async {
                    await auth.signOut();
                    if (mounted) Navigator.pop(context);
                  },
                  icon: const Icon(Icons.logout, color: Colors.red, size: 20),
                  label: const Text('تسجيل الخروج', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
