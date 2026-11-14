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

// Top-level background notification entry point for Firebase Messaging
@pragma('vm:entry-point')
Future<void> _bg(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: firebaseOptions);
  } catch (_) {}
}

const String kSupabaseUrl = "https://jvjtgzewumfecjdpekna.supabase.co";
const String kSupabaseAnonKey =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInRefiI6Imp2anRnemV3dW1mZWNqZHBla25hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE2NDYzMzcsImV4cCI6MjEwNzIyMjMzN30.1gck73ek8ErBtcF7xAtFM1TdvNim_1NzFVNej_mptBE";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: firebaseOptions);
    FirebaseMessaging.onBackgroundMessage(_bg);
  } catch (_) {}

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppStateProvider()..init()),
      ],
      child: const DmcCustomerApp(),
    ),
  );
}

// ============================================================================
// DATA MODELS
// ============================================================================

class Product {
  final String id;
  final String name;
  final String category;
  final String description;
  final double priceUsd;
  final int stockQuantity;
  final String? imageUrl;
  final bool isVisible;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.priceUsd,
    required this.stockQuantity,
    this.imageUrl,
    required this.isVisible,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      category: json['category'] ?? 'مستهلكات',
      description: json['description'] ?? '',
      priceUsd: (json['price_usd'] as num?)?.toDouble() ?? 0.0,
      stockQuantity: (json['stock_quantity'] as num?)?.toInt() ?? 0,
      imageUrl: json['image_url'],
      isVisible: json['is_visible'] ?? true,
    );
  }

  double calculateSdgPrice(double usdRate) => priceUsd * usdRate;
}

class DeliveryArea {
  final int id;
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
      id: (json['id'] as num).toInt(),
      name: json['name'] ?? '',
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] ?? true,
    );
  }
}

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double totalSdg(double usdRate) => product.calculateSdgPrice(usdRate) * quantity;
}

class OrderItem {
  final String id;
  final String orderId;
  final String productId;
  final String productName;
  final int quantity;
  final double unitPriceSdg;
  final double totalPriceSdg;

  OrderItem({
    required this.id,
    required this.orderId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPriceSdg,
    required this.totalPriceSdg,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name'] ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPriceSdg: (json['unit_price_sdg'] as num?)?.toDouble() ?? 0.0,
      totalPriceSdg: (json['total_price_sdg'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class CustomerOrder {
  final String id;
  final String orderNumber;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final int? deliveryAreaId;
  final String deliveryAreaName;
  final double deliveryFee;
  final String detailedAddress;
  final String deliveryType;
  final String paymentMethod;
  final String status;
  final double subtotalSdg;
  final double totalSdg;
  final DateTime createdAt;
  List<OrderItem> items;

  CustomerOrder({
    required this.id,
    required this.orderNumber,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    this.deliveryAreaId,
    required this.deliveryAreaName,
    required this.deliveryFee,
    required this.detailedAddress,
    required this.deliveryType,
    required this.paymentMethod,
    required this.status,
    required this.subtotalSdg,
    required this.totalSdg,
    required this.createdAt,
    this.items = const [],
  });

  factory CustomerOrder.fromJson(Map<String, dynamic> json) {
    return CustomerOrder(
      id: json['id']?.toString() ?? '',
      orderNumber: json['order_number'] ?? '',
      customerId: json['customer_id']?.toString() ?? '',
      customerName: json['customer_name'] ?? '',
      customerPhone: json['customer_phone'] ?? '',
      deliveryAreaId: (json['delivery_area_id'] as num?)?.toInt(),
      deliveryAreaName: json['delivery_area_name'] ?? '',
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      detailedAddress: json['detailed_address'] ?? '',
      deliveryType: json['delivery_type'] ?? 'توصيل للموقع',
      paymentMethod: json['payment_method'] ?? 'كاش عند الاستلام',
      status: json['status'] ?? 'جديد',
      subtotalSdg: (json['subtotal_sdg'] as num?)?.toDouble() ?? 0.0,
      totalSdg: (json['total_sdg'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
      items: [],
    );
  }
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime? readAt;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    this.readAt,
    required this.createdAt,
  });

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      readAt: json['read_at'] != null ? DateTime.tryParse(json['read_at']) : null,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

// ============================================================================
// APP STATE & API SERVICE PROVIDER
// ============================================================================

class AppStateProvider extends ChangeNotifier {
  String? _accessToken;
  String? _refreshToken;
  String? _userId;
  String? _userEmail;
  String? _userName;
  String? _userPhone;

  double usdRate = 1100.0;
  List<Product> products = [];
  List<DeliveryArea> deliveryAreas = [];
  List<CustomerOrder> orders = [];
  List<AppNotification> notifications = [];

  final List<CartItem> cart = [];
  DeliveryArea? selectedDeliveryArea;
  String selectedCategory = 'الكل';
  String searchQuery = '';
  bool isLoading = false;
  Timer? _syncTimer;

  bool get isAuthenticated => _accessToken != null && _accessToken!.isNotEmpty;
  String? get accessToken => _accessToken;
  String? get userId => _userId;
  String? get userEmail => _userEmail;
  String? get userName => _userName;
  String? get userPhone => _userPhone;

  int get unreadNotificationsCount => notifications.where((n) => !n.isRead).length;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    _refreshToken = prefs.getString('refresh_token');
    _userId = prefs.getString('user_id');
    _userEmail = prefs.getString('user_email');
    _userName = prefs.getString('user_name');
    _userPhone = prefs.getString('user_phone');

    await fetchSettings();
    await fetchDeliveryAreas();
    await fetchProducts();

    if (isAuthenticated) {
      await fetchProfile();
      await fetchOrders();
      await fetchNotifications();
      startPeriodicSync();
      setupFirebasePush();
    }
  }

  void startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      refreshDataQuietly();
    });
  }

  Future<void> refreshDataQuietly() async {
    await fetchSettings();
    await fetchDeliveryAreas();
    await fetchProducts();
    if (isAuthenticated) {
      await fetchProfile();
      await fetchOrders();
      await fetchNotifications();
    }
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  Map<String, String> _headers({bool withAuth = true}) {
    final map = <String, String>{
      'apikey': kSupabaseAnonKey,
      'Content-Type': 'application/json',
      'Prefer': 'return=representation',
    };
    if (withAuth && _accessToken != null && _accessToken!.isNotEmpty) {
      map['Authorization'] = 'Bearer $_accessToken';
    }
    return map;
  }

  String _parseServerError(http.Response res, {bool isVerify = false}) {
    try {
      final body = jsonDecode(res.body);
      final String errStr = (body['error_description'] ?? body['msg'] ?? body['message'] ?? body['error'] ?? '').toString();
      final lower = errStr.toLowerCase();

      if (res.statusCode == 429 || lower.contains('rate limit') || lower.contains('too many requests')) {
        return 'اتبعتت رسائل كتير، استنى دقايق';
      }
      if (lower.contains('sending') || lower.contains('smtp') || lower.contains('mail')) {
        return 'ما قدرنا نرسل البريد';
      }
      if (isVerify) {
        return 'رمز التحقق غير صحيح أو منتهي الصلاحية';
      }
      if (errStr.isNotEmpty) {
        if (errStr.contains('Invalid login credentials')) return 'بيانات الدخول غير صحيحة';
        if (errStr.contains('User already registered')) return 'البريد الإلكتروني مسجل بالفعل';
        return errStr;
      }
    } catch (_) {}
    if (isVerify) return 'رمز التحقق غير صحيح أو منتهي الصلاحية';
    return 'حدث خطأ في الاتصال بالخادم (${res.statusCode})';
  }

  Future<bool> _refreshSession() async {
    if (_refreshToken == null || _refreshToken!.isEmpty) return false;
    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/token?grant_type=refresh_token'),
        headers: {
          'apikey': kSupabaseAnonKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'refresh_token': _refreshToken}),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'] ?? _refreshToken;
        final prefs = await SharedPreferences.getInstance();
        if (_accessToken != null) await prefs.setString('access_token', _accessToken!);
        if (_refreshToken != null) await prefs.setString('refresh_token', _refreshToken!);
        return true;
      }
    } catch (_) {}
    return false;
  }

  // --- Auth & Profile API ---
  Future<String?> signUp(String name, String phone, String email, String password) async {
    isLoading = true;
    notifyListeners();
    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/signup'),
        headers: _headers(withAuth: false),
        body: jsonEncode({
          'email': email,
          'password': password,
          'data': {'full_name': name, 'phone': phone}
        }),
      );
      isLoading = false;
      notifyListeners();
      if (res.statusCode >= 200 && res.statusCode < 300) {
        _userName = name;
        _userPhone = phone;
        _userEmail = email;
        return null;
      }
      return _parseServerError(res);
    } catch (e) {
      isLoading = false;
      notifyListeners();
      return 'تعذر الاتصال بالخادم، تحسس الاتصال بالإنترنت';
    }
  }

  Future<String?> resendOtp(String email, String type) async {
    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/resend'),
        headers: _headers(withAuth: false),
        body: jsonEncode({'type': type, 'email': email}),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return null;
      }
      return _parseServerError(res);
    } catch (e) {
      return 'خطأ بالشبكة عند إرسال الرمز';
    }
  }

  Future<String?> verifyOtp(String email, String code, String type) async {
    isLoading = true;
    notifyListeners();
    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/verify'),
        headers: _headers(withAuth: false),
        body: jsonEncode({'type': type, 'email': email, 'token': code}),
      );
      isLoading = false;
      notifyListeners();

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];
        _userId = data['user']?['id'];
        _userEmail = email;

        final prefs = await SharedPreferences.getInstance();
        if (_accessToken != null) await prefs.setString('access_token', _accessToken!);
        if (_refreshToken != null) await prefs.setString('refresh_token', _refreshToken!);
        if (_userId != null) await prefs.setString('user_id', _userId!);
        await prefs.setString('user_email', email);

        if (_userName != null && _userName!.isNotEmpty && _userId != null) {
          await _upsertProfile(_userId!, _userName!, _userPhone ?? '');
        }

        await fetchProfile();
        await fetchOrders();
        await fetchNotifications();
        startPeriodicSync();
        setupFirebasePush();
        return null;
      }

      return _parseServerError(res, isVerify: true);
    } catch (e) {
      isLoading = false;
      notifyListeners();
      return 'خطأ بالشبكة: $e';
    }
  }

  Future<String?> signIn(String email, String password) async {
    isLoading = true;
    notifyListeners();
    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/token?grant_type=password'),
        headers: _headers(withAuth: false),
        body: jsonEncode({'email': email, 'password': password}),
      );
      isLoading = false;
      notifyListeners();

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = jsonDecode(res.body);
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];
        _userId = data['user']?['id'];
        _userEmail = email;

        final prefs = await SharedPreferences.getInstance();
        if (_accessToken != null) await prefs.setString('access_token', _accessToken!);
        if (_refreshToken != null) await prefs.setString('refresh_token', _refreshToken!);
        if (_userId != null) await prefs.setString('user_id', _userId!);
        await prefs.setString('user_email', email);

        await fetchProfile();
        await fetchOrders();
        await fetchNotifications();
        startPeriodicSync();
        setupFirebasePush();
        return null;
      }

      final data = jsonDecode(res.body);
      final msg = (data['error_description'] ?? data['msg'] ?? '').toString();
      if (msg.contains('Email not confirmed') || msg.contains('email_not_confirmed')) {
        await resendOtp(email, 'signup');
        return 'EMAIL_NOT_CONFIRMED';
      }
      return _parseServerError(res);
    } catch (e) {
      isLoading = false;
      notifyListeners();
      return 'خطأ بالاتصال: $e';
    }
  }

  Future<String?> requestPasswordRecovery(String email) async {
    isLoading = true;
    notifyListeners();
    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/recover'),
        headers: _headers(withAuth: false),
        body: jsonEncode({'email': email}),
      );
      isLoading = false;
      notifyListeners();
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return null;
      }
      return _parseServerError(res);
    } catch (e) {
      isLoading = false;
      notifyListeners();
      return 'خطأ بالشبكة: $e';
    }
  }

  Future<String?> resetPassword(String newPassword) async {
    isLoading = true;
    notifyListeners();
    try {
      var res = await http.put(
        Uri.parse('$kSupabaseUrl/auth/v1/user'),
        headers: _headers(withAuth: true),
        body: jsonEncode({'password': newPassword}),
      );
      if (res.statusCode == 401 && await _refreshSession()) {
        res = await http.put(
          Uri.parse('$kSupabaseUrl/auth/v1/user'),
          headers: _headers(withAuth: true),
          body: jsonEncode({'password': newPassword}),
        );
      }
      isLoading = false;
      notifyListeners();
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return null;
      }
      return _parseServerError(res);
    } catch (e) {
      isLoading = false;
      notifyListeners();
      return 'خطأ بالشبكة: $e';
    }
  }

  Future<void> fetchProfile() async {
    if (_userId == null) return;
    try {
      var res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_profiles?id=eq.$_userId'),
        headers: _headers(),
      );
      if (res.statusCode == 401 && await _refreshSession()) {
        res = await http.get(
          Uri.parse('$kSupabaseUrl/rest/v1/tarag3_profiles?id=eq.$_userId'),
          headers: _headers(),
        );
      }
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        if (data.isNotEmpty) {
          _userName = data[0]['full_name'] ?? _userName;
          _userPhone = data[0]['phone'] ?? _userPhone;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_name', _userName ?? '');
          await prefs.setString('user_phone', _userPhone ?? '');
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  Future<String?> updateProfile(String name, String phone) async {
    if (_userId == null) return 'غير مسجل';
    isLoading = true;
    notifyListeners();
    try {
      var res = await http.patch(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_profiles?id=eq.$_userId'),
        headers: _headers(),
        body: jsonEncode({
          'full_name': name,
          'phone': phone,
        }),
      );
      if (res.statusCode == 401 && await _refreshSession()) {
        res = await http.patch(
          Uri.parse('$kSupabaseUrl/rest/v1/tarag3_profiles?id=eq.$_userId'),
          headers: _headers(),
          body: jsonEncode({
            'full_name': name,
            'phone': phone,
          }),
        );
      }
      isLoading = false;
      if (res.statusCode >= 200 && res.statusCode < 300) {
        _userName = name;
        _userPhone = phone;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', name);
        await prefs.setString('user_phone', phone);
        notifyListeners();
        return null;
      }
      return 'فشل تحديث بيانات الملف الشخصي';
    } catch (e) {
      isLoading = false;
      notifyListeners();
      return 'خطأ في الشبكة: $e';
    }
  }

  Future<void> _upsertProfile(String uid, String name, String phone) async {
    try {
      await http.post(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_profiles'),
        headers: _headers(),
        body: jsonEncode({
          'id': uid,
          'email': _userEmail,
          'full_name': name,
          'phone': phone,
          'role': 'customer'
        }),
      );
    } catch (_) {}
  }

  Future<void> signOut() async {
    _syncTimer?.cancel();
    _accessToken = null;
    _refreshToken = null;
    _userId = null;
    _userEmail = null;
    _userName = null;
    _userPhone = null;
    cart.clear();
    orders.clear();
    notifications.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }

  // --- Fetch Catalog ---
  Future<void> fetchSettings() async {
    try {
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_settings?select=*&limit=1'),
        headers: _headers(withAuth: false),
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        if (data.isNotEmpty) {
          usdRate = (data[0]['usd_rate'] as num?)?.toDouble() ?? 1100.0;
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  Future<void> fetchDeliveryAreas() async {
    try {
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_delivery_areas?select=*&order=id.asc'),
        headers: _headers(withAuth: false),
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        deliveryAreas = data.map((e) => DeliveryArea.fromJson(e)).where((a) => a.isActive).toList();
        if (deliveryAreas.isNotEmpty && selectedDeliveryArea == null) {
          selectedDeliveryArea = deliveryAreas.first;
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> fetchProducts() async {
    try {
      final res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_products?select=*&is_visible=eq.true&order=created_at.desc'),
        headers: _headers(withAuth: false),
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        products = data.map((e) => Product.fromJson(e)).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  // --- Orders API ---
  Future<void> fetchOrders() async {
    if (!isAuthenticated) return;
    try {
      var res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_orders?select=*,tarag3_order_items(*)&customer_id=eq.$_userId&order=created_at.desc'),
        headers: _headers(),
      );
      if (res.statusCode == 401 && await _refreshSession()) {
        res = await http.get(
          Uri.parse('$kSupabaseUrl/rest/v1/tarag3_orders?select=*,tarag3_order_items(*)&customer_id=eq.$_userId&order=created_at.desc'),
          headers: _headers(),
        );
      }
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        orders = data.map((e) {
          final o = CustomerOrder.fromJson(e);
          if (e['tarag3_order_items'] != null) {
            final List itemsJson = e['tarag3_order_items'];
            o.items = itemsJson.map((i) => OrderItem.fromJson(i)).toList();
          }
          return o;
        }).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<String?> placeOrder({
    required String name,
    required String phone,
    required String address,
    required String deliveryType,
  }) async {
    if (cart.isEmpty) return 'السلة فارغة';
    if (!isAuthenticated) return 'يرجى تسجيل الدخول أولاً';

    isLoading = true;
    notifyListeners();

    try {
      final subtotal = cartSubtotalSdg;
      final deliveryFee = deliveryType == 'استلام من المحل' ? 0.0 : (selectedDeliveryArea?.deliveryFee ?? 0.0);
      final grandTotal = subtotal + deliveryFee;
      final orderNo = 'DMC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

      final body = {
        'order_number': orderNo,
        'customer_id': _userId,
        'customer_name': name,
        'customer_phone': phone,
        'delivery_area_id': selectedDeliveryArea?.id,
        'delivery_area_name': selectedDeliveryArea?.name ?? 'عطبرة',
        'delivery_fee': deliveryFee,
        'detailed_address': address,
        'delivery_type': deliveryType,
        'payment_method': 'كاش عند الاستلام',
        'status': 'جديد',
        'subtotal_sdg': subtotal,
        'total_sdg': grandTotal,
      };

      var res = await http.post(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_orders'),
        headers: _headers(),
        body: jsonEncode(body),
      );

      if (res.statusCode == 401 && await _refreshSession()) {
        res = await http.post(
          Uri.parse('$kSupabaseUrl/rest/v1/tarag3_orders'),
          headers: _headers(),
          body: jsonEncode(body),
        );
      }

      if (res.statusCode >= 200 && res.statusCode < 300) {
        final List createdOrder = jsonDecode(res.body);
        final orderId = createdOrder[0]['id'];

        final itemsPayload = cart.map((item) => {
          'order_id': orderId,
          'product_id': item.product.id,
          'product_name': item.product.name,
          'quantity': item.quantity,
          'unit_price_sdg': item.product.calculateSdgPrice(usdRate),
          'total_price_sdg': item.totalSdg(usdRate),
        }).toList();

        await http.post(
          Uri.parse('$kSupabaseUrl/rest/v1/tarag3_order_items'),
          headers: _headers(),
          body: jsonEncode(itemsPayload),
        );

        // Notify Admin
        await http.post(
          Uri.parse('$kSupabaseUrl/rest/v1/tarag3_notifications'),
          headers: _headers(),
          body: jsonEncode({
            'to_role': 'admin',
            'title': 'طلب جديد #$orderNo',
            'body': 'قام الزبون $name بطلب جديد بقيمة ${grandTotal.toStringAsFixed(0)} ج.س',
            'data': {'order_id': orderId}
          }),
        );

        cart.clear();
        await fetchOrders();
        isLoading = false;
        notifyListeners();
        return null;
      }
      isLoading = false;
      notifyListeners();
      return _parseServerError(res);
    } catch (e) {
      isLoading = false;
      notifyListeners();
      return 'خطأ في الشبكة: $e';
    }
  }

  void reorderItems(CustomerOrder order) {
    if (order.items.isEmpty) return;
    for (final orderItem in order.items) {
      final existingProduct = products.firstWhere(
        (p) => p.id == orderItem.productId,
        orElse: () => Product(
          id: orderItem.productId,
          name: orderItem.productName,
          category: 'مستهلكات',
          description: '',
          priceUsd: orderItem.unitPriceSdg / (usdRate > 0 ? usdRate : 1100.0),
          stockQuantity: 100,
          isVisible: true,
        ),
      );
      addToCart(existingProduct, qty: orderItem.quantity);
    }
  }

  // --- Notifications API ---
  Future<void> fetchNotifications() async {
    if (!isAuthenticated) return;
    try {
      var res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_notifications?or=(to_user.eq.$_userId,to_role.eq.customer)&order=created_at.desc'),
        headers: _headers(),
      );
      if (res.statusCode == 401 && await _refreshSession()) {
        res = await http.get(
          Uri.parse('$kSupabaseUrl/rest/v1/tarag3_notifications?or=(to_user.eq.$_userId,to_role.eq.customer)&order=created_at.desc'),
          headers: _headers(),
        );
      }
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        notifications = data.map((e) => AppNotification.fromJson(e)).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> markNotificationRead(String id) async {
    try {
      var res = await http.patch(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_notifications?id=eq.$id'),
        headers: _headers(),
        body: jsonEncode({'read_at': DateTime.now().toIso8601String()}),
      );
      if (res.statusCode == 401 && await _refreshSession()) {
        await http.patch(
          Uri.parse('$kSupabaseUrl/rest/v1/tarag3_notifications?id=eq.$id'),
          headers: _headers(),
          body: jsonEncode({'read_at': DateTime.now().toIso8601String()}),
        );
      }
      fetchNotifications();
    } catch (_) {}
  }

  void setupFirebasePush() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token != null && isAuthenticated) {
        await http.post(
          Uri.parse('$kSupabaseUrl/rest/v1/rpc/tarag3_register_device'),
          headers: _headers(),
          body: jsonEncode({'device_token': token, 'app_name': 'customer'}),
        );
      }
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        fetchNotifications();
        fetchOrders();
        fetchProducts();
        fetchSettings();
      });
    } catch (_) {}
  }

  // --- Cart Helpers ---
  void addToCart(Product p, {int qty = 1}) {
    final idx = cart.indexWhere((item) => item.product.id == p.id);
    if (idx >= 0) {
      cart[idx].quantity += qty;
    } else {
      cart.add(CartItem(product: p, quantity: qty));
    }
    notifyListeners();
  }

  void updateCartQty(Product p, int delta) {
    final idx = cart.indexWhere((item) => item.product.id == p.id);
    if (idx >= 0) {
      cart[idx].quantity += delta;
      if (cart[idx].quantity <= 0) {
        cart.removeAt(idx);
      }
      notifyListeners();
    }
  }

  double get cartSubtotalSdg {
    return cart.fold(0.0, (sum, item) => sum + item.totalSdg(usdRate));
  }

  void setDeliveryArea(DeliveryArea area) {
    selectedDeliveryArea = area;
    notifyListeners();
  }

  void setCategory(String cat) {
    selectedCategory = cat;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    searchQuery = query;
    notifyListeners();
  }

  List<Product> get filteredProducts {
    return products.where((p) {
      final matchesCat = (selectedCategory == 'الكل') || (p.category == selectedCategory);
      final matchesSearch = p.name.contains(searchQuery) || p.description.contains(searchQuery);
      return matchesCat && matchesSearch;
    }).toList();
  }
}

// ============================================================================
// MAIN FLUTTER APP
// ============================================================================

class DmcCustomerApp extends StatelessWidget {
  const DmcCustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DMC Customer',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'SD'),
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Cairo',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A47A8),
          brightness: Brightness.light,
          primary: const Color(0xFF0A47A8),
          secondary: const Color(0xFF0A2F6B),
          tertiary: const Color(0xFF00B8C4),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF3F7FC),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE1E9F3)),
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Cairo',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A47A8),
          brightness: Brightness.dark,
          primary: const Color(0xFF3B82F6),
          secondary: const Color(0xFF1E3A8A),
          tertiary: const Color(0xFF00E5FF),
          surface: const Color(0xFF1E293B),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardTheme: CardThemeData(
          color: const Color(0xFF1E293B),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF334155)),
          ),
        ),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl,
        child: RootNavigationScreen(),
      ),
    );
  }
}

class RootNavigationScreen extends StatefulWidget {
  const RootNavigationScreen({super.key});

  @override
  State<RootNavigationScreen> createState() => _RootNavigationScreenState();
}

class _RootNavigationScreenState extends State<RootNavigationScreen> with WidgetsBindingObserver {
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
      final provider = Provider.of<AppStateProvider>(context, listen: false);
      provider.refreshDataQuietly();
    }
  }

  void _switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);

    if (!provider.isAuthenticated) {
      return const AuthScreen();
    }

    if (provider.isLoading && provider.products.isEmpty) {
      return const Scaffold(
        body: SafeArea(child: LoadingSkeletonScreen()),
      );
    }

    final pages = [
      const HomeScreen(),
      CartScreen(onBrowseProducts: () => _switchTab(0)),
      const MyOrdersScreen(),
      const ContactScreen(),
    ];

    return Scaffold(
      body: SafeArea(child: pages[_currentIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _switchTab,
        indicatorColor: const Color(0xFFE8F0FE),
        backgroundColor: Theme.of(context).cardTheme.color ?? Colors.white,
        elevation: 8,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: Color(0xFF0A47A8)),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Badge(
              label: Text('${provider.cart.length}'),
              isLabelVisible: provider.cart.isNotEmpty,
              child: const Icon(Icons.shopping_bag_outlined),
            ),
            selectedIcon: Badge(
              label: Text('${provider.cart.length}'),
              isLabelVisible: provider.cart.isNotEmpty,
              child: const Icon(Icons.shopping_bag, color: Color(0xFF0A47A8)),
            ),
            label: 'السلة',
          ),
          const NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment, color: Color(0xFF0A47A8)),
            label: 'طلباتي',
          ),
          const NavigationDestination(
            icon: Icon(Icons.phone_in_talk_outlined),
            selectedIcon: Icon(Icons.phone_in_talk, color: Color(0xFF0A47A8)),
            label: 'تواصل',
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SKELETON LOADING STATE SCREEN
// ============================================================================

class LoadingSkeletonScreen extends StatelessWidget {
  const LoadingSkeletonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 44,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 36,
            width: MediaQuery.of(context).size.width * 0.7,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: List.generate(
                4,
                (index) => Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 1. AUTH SCREEN (Sign-in, Sign-up, OTP verification & Forgot Password)
// ============================================================================

enum AuthMode { signIn, signUp, verifyOtp, forgotPassword, newPassword }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  AuthMode _authMode = AuthMode.signIn;

  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  final _regNameController = TextEditingController();
  final _regPhoneController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regConfirmPasswordController = TextEditingController();

  final _forgotEmailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();

  String? _errorMessage;
  String _pendingEmail = '';
  int _resendCountdown = 60;
  Timer? _resendTimer;
  bool _showPassword = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() => _resendCountdown = 60);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        t.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // DMC Brand Hero Header
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0A2F6B), Color(0xFF0A47A8)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4))
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'DMC',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Diala Medical',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0A2F6B)),
                ),
                const Text(
                  'معدات ومستهلكات طبية',
                  style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 24),

                // Dynamic Auth Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_authMode == AuthMode.signIn || _authMode == AuthMode.signUp) ...[
                          TabBar(
                            controller: _tabController,
                            labelColor: const Color(0xFF0A47A8),
                            unselectedLabelColor: Colors.grey,
                            indicatorColor: const Color(0xFF0A47A8),
                            onTap: (idx) {
                              setState(() {
                                _errorMessage = null;
                                _authMode = idx == 0 ? AuthMode.signIn : AuthMode.signUp;
                              });
                            },
                            tabs: const [
                              Tab(text: 'تسجيل الدخول'),
                              Tab(text: 'حساب جديد'),
                            ],
                          ),
                          const SizedBox(height: 20),

                          if (_authMode == AuthMode.signIn) _buildSignInView(provider),
                          if (_authMode == AuthMode.signUp) _buildSignUpView(provider),
                        ] else if (_authMode == AuthMode.forgotPassword) ...[
                          _buildForgotPasswordView(provider),
                        ] else if (_authMode == AuthMode.verifyOtp) ...[
                          _buildVerifyOtpView(provider),
                        ] else if (_authMode == AuthMode.newPassword) ...[
                          _buildNewPasswordView(provider),
                        ],

                        if (_errorMessage != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignInView(AppStateProvider provider) {
    return Column(
      children: [
        TextField(
          controller: _loginEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'البريد الإلكتروني',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _loginPasswordController,
          obscureText: !_showPassword,
          decoration: InputDecoration(
            labelText: 'كلمة المرور',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () {
              setState(() {
                _errorMessage = null;
                _authMode = AuthMode.forgotPassword;
              });
            },
            child: const Text('نسيت كلمة المرور؟', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0A47A8),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: provider.isLoading
              ? null
              : () async {
                  setState(() => _errorMessage = null);
                  final email = _loginEmailController.text.trim();
                  final pass = _loginPasswordController.text.trim();
                  if (email.isEmpty || pass.isEmpty) {
                    setState(() => _errorMessage = 'يرجى إدخال البريد الإلكتروني وكلمة المرور');
                    return;
                  }
                  final err = await provider.signIn(email, pass);
                  if (err == 'EMAIL_NOT_CONFIRMED') {
                    _pendingEmail = email;
                    _startResendTimer();
                    setState(() {
                      _authMode = AuthMode.verifyOtp;
                      _errorMessage = 'البريد الإلكتروني غير مؤكد. تم إرسال رمز جديد على بريدك.';
                    });
                  } else if (err != null) {
                    setState(() => _errorMessage = err);
                  }
                },
          child: provider.isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('تسجيل الدخول', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildSignUpView(AppStateProvider provider) {
    return Column(
      children: [
        TextField(
          controller: _regNameController,
          decoration: const InputDecoration(labelText: 'الاسم الكامل', prefixIcon: Icon(Icons.person_outline)),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _regPhoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'رقم الهاتف', prefixIcon: Icon(Icons.phone_outlined)),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _regEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email_outlined)),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _regPasswordController,
          obscureText: !_showPassword,
          decoration: InputDecoration(
            labelText: 'كلمة المرور (6 خانات أو أكثر)',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _regConfirmPasswordController,
          obscureText: !_showPassword,
          decoration: const InputDecoration(
            labelText: 'تأكيد كلمة المرور',
            prefixIcon: Icon(Icons.lock_reset),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0A47A8),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: provider.isLoading
              ? null
              : () async {
                  setState(() => _errorMessage = null);
                  final name = _regNameController.text.trim();
                  final phone = _regPhoneController.text.trim();
                  final email = _regEmailController.text.trim();
                  final pass = _regPasswordController.text.trim();
                  final confirmPass = _regConfirmPasswordController.text.trim();

                  if (name.isEmpty || phone.isEmpty || email.isEmpty || pass.isEmpty) {
                    setState(() => _errorMessage = 'جميع الحقول مطلوبة');
                    return;
                  }
                  if (pass.length < 6) {
                    setState(() => _errorMessage = 'كلمة المرور يجب أن تكون 6 أحرف على الأقل');
                    return;
                  }
                  if (pass != confirmPass) {
                    setState(() => _errorMessage = 'كلمة المرور وتأكيدها غير متطابقين');
                    return;
                  }

                  _pendingEmail = email;
                  final err = await provider.signUp(name, phone, email, pass);
                  if (err == null) {
                    _startResendTimer();
                    setState(() {
                      _authMode = AuthMode.verifyOtp;
                    });
                  } else {
                    setState(() => _errorMessage = err);
                  }
                },
          child: provider.isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('إنشاء حساب جديد', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildForgotPasswordView(AppStateProvider provider) {
    return Column(
      children: [
        const Text(
          'إعادة تعيين كلمة المرور',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0A2F6B)),
        ),
        const SizedBox(height: 6),
        const Text(
          'أدخل بريدك الإلكتروني ليصلك رمز الاستعادة 6 أرقام',
          style: TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _forgotEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email_outlined)),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0A47A8),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: provider.isLoading
              ? null
              : () async {
                  setState(() => _errorMessage = null);
                  final email = _forgotEmailController.text.trim();
                  if (email.isEmpty) {
                    setState(() => _errorMessage = 'يرجى إدخال البريد الإلكتروني');
                    return;
                  }
                  _pendingEmail = email;
                  final err = await provider.requestPasswordRecovery(email);
                  if (err == null) {
                    _startResendTimer();
                    setState(() => _authMode = AuthMode.verifyOtp);
                  } else {
                    setState(() => _errorMessage = err);
                  }
                },
          child: provider.isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('إرسال رمز الاستعادة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        TextButton(
          onPressed: () => setState(() => _authMode = AuthMode.signIn),
          child: const Text('العودة لتسجيل الدخول'),
        ),
      ],
    );
  }

  Widget _buildVerifyOtpView(AppStateProvider provider) {
    return Column(
      children: [
        const Text(
          'تأكيد رمز التحقق',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0A2F6B)),
        ),
        const SizedBox(height: 6),
        Text(
          'بعتنا رمز على بريدك الإلكتروني:\n$_pendingEmail',
          style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, letterSpacing: 6, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(hintText: '000000'),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00B8C4),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: provider.isLoading
              ? null
              : () async {
                  setState(() => _errorMessage = null);
                  final code = _otpController.text.trim();
                  if (code.isEmpty) {
                    setState(() => _errorMessage = 'يرجى إدخال رمز التحقق');
                    return;
                  }

                  if (_forgotEmailController.text.isNotEmpty) {
                    final err = await provider.verifyOtp(_pendingEmail, code, 'recovery');
                    if (err == null) {
                      setState(() => _authMode = AuthMode.newPassword);
                    } else {
                      setState(() => _errorMessage = err);
                    }
                  } else {
                    final err = await provider.verifyOtp(_pendingEmail, code, 'signup');
                    if (err != null) {
                      setState(() => _errorMessage = err);
                    }
                  }
                },
          child: provider.isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('تأكيد الرمز', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: _resendCountdown > 0
                  ? null
                  : () async {
                      final type = _forgotEmailController.text.isNotEmpty ? 'recovery' : 'signup';
                      final resErr = await provider.resendOtp(_pendingEmail, type);
                      if (resErr == null) {
                        _startResendTimer();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إعادة إرسال الرمز')));
                      } else {
                        setState(() => _errorMessage = resErr);
                      }
                    },
              child: Text(
                _resendCountdown > 0 ? 'إعادة الإرسال بعد ($_resendCountdown ث)' : 'إعادة إرسال الرمز الآن',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: () => setState(() => _authMode = AuthMode.signIn),
          child: const Text('إلغاء والعودة'),
        ),
      ],
    );
  }

  Widget _buildNewPasswordView(AppStateProvider provider) {
    return Column(
      children: [
        const Text(
          'تعيين كلمة مرور جديدة',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0A2F6B)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _newPasswordController,
          obscureText: !_showPassword,
          decoration: const InputDecoration(
            labelText: 'كلمة المرور الجديدة',
            prefixIcon: Icon(Icons.lock_outline),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0A47A8),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: provider.isLoading
              ? null
              : () async {
                  setState(() => _errorMessage = null);
                  final newPass = _newPasswordController.text.trim();
                  if (newPass.length < 6) {
                    setState(() => _errorMessage = 'كلمة المرور يجب أن تكون 6 خانات على الأقل');
                    return;
                  }
                  final err = await provider.resetPassword(newPass);
                  if (err == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم تحديث كلمة المرور بنجاح! يمكنك الآن تسجيل الدخول')),
                    );
                    setState(() => _authMode = AuthMode.signIn);
                  } else {
                    setState(() => _errorMessage = err);
                  }
                },
          child: provider.isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('حفظ كلمة المرور الجديدة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

// ============================================================================
// PROFILE SCREEN
// ============================================================================

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<AppStateProvider>(context, listen: false);
    _nameController.text = provider.userName ?? '';
    _phoneController.text = provider.userPhone ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0A2F6B))),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: const Color(0xFF0A47A8),
                child: Text(
                  provider.userName != null && provider.userName!.isNotEmpty ? provider.userName![0].toUpperCase() : 'Z',
                  style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                provider.userName ?? 'زبون DMC',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0A2F6B)),
              ),
              Text(
                provider.userEmail ?? '',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('تعديل البيانات الشخصية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0A2F6B))),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'الاسم الكامل', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A47A8),
                          minimumSize: const Size.fromHeight(46),
                        ),
                        onPressed: provider.isLoading
                            ? null
                            : () async {
                                final err = await provider.updateProfile(
                                  _nameController.text.trim(),
                                  _phoneController.text.trim(),
                                );
                                if (err == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ البيانات بنجاح')));
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
                                }
                              },
                        child: const Text('حفظ التعديلات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  side: const BorderSide(color: Colors.red),
                ),
                onPressed: () {
                  provider.signOut();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 2. HOME SCREEN
// ============================================================================

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);

    return Column(
      children: [
        // Header
        Container(
          color: Theme.of(context).cardTheme.color ?? Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF0A2F6B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('DMC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('DMC Diala', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0A2F6B))),
                  Text('معدات ومستهلكات طبية', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.person_outline, color: Color(0xFF0A2F6B)),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                },
              ),
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_outlined, color: Color(0xFF0A2F6B)),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
                    },
                  ),
                  if (provider.unreadNotificationsCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Color(0xFF00B8C4), shape: BoxShape.circle),
                        child: Text(
                          '${provider.unreadNotificationsCount}',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: TextField(
            onChanged: provider.setSearchQuery,
            decoration: InputDecoration(
              hintText: 'ابحث عن جهاز، مستهلك، شاش، جلوكوز...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Theme.of(context).cardTheme.color ?? Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
        ),

        // Categories Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: ['الكل', 'معدات', 'مستهلكات', 'مختبر'].map((cat) {
              final isSelected = provider.selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: FilterChip(
                  selected: isSelected,
                  label: Text(cat),
                  selectedColor: const Color(0xFF0A47A8),
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  backgroundColor: Theme.of(context).cardTheme.color ?? Colors.white,
                  shape: const StadiumBorder(),
                  onSelected: (_) => provider.setCategory(cat),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 8),

        // Delivery Area Banner
        if (provider.deliveryAreas.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F7FA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFB2EBF2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on_outlined, color: Color(0xFF006064), size: 20),
                const SizedBox(width: 8),
                Text(
                  'التوصيل إلى: ${provider.selectedDeliveryArea?.name ?? "اختر المنطقة"}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF006064), fontSize: 13),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00838F),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${intl.NumberFormat('#,###').format(provider.selectedDeliveryArea?.deliveryFee ?? 0)} ج.س',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 8),

        // Product Grid
        Expanded(
          child: provider.filteredProducts.isEmpty
              ? _buildEmptyState('لا توجد منتجات متاحة حالياً')
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.72,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: provider.filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = provider.filteredProducts[index];
                    return ProductCard(product: product);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(msg, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final Product product;
  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final sdgPrice = product.calculateSdgPrice(provider.usdRate);

    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsScreen(product: product)));
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    product.category == 'معدات'
                        ? Icons.monitor_heart_outlined
                        : product.category == 'مختبر'
                            ? Icons.science_outlined
                            : Icons.medication_liquid_outlined,
                    size: 48,
                    color: const Color(0xFF0A47A8),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                product.category,
                style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold),
              ),
              Text(
                product.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0A2F6B)),
              ),
              const Spacer(),
              Text(
                '${intl.NumberFormat('#,###').format(sdgPrice)} ج.س',
                style: const TextStyle(color: Color(0xFF0A47A8), fontWeight: FontWeight.w900, fontSize: 13),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 34,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF0A47A8)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: () {
                    provider.addToCart(product);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تمت إضافة المنتج للسلة'), duration: Duration(seconds: 1)),
                    );
                  },
                  icon: const Icon(Icons.add_shopping_cart, size: 14, color: Color(0xFF0A47A8)),
                  label: const Text('أضف للسلة', style: TextStyle(fontSize: 11, color: Color(0xFF0A47A8), fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 3. PRODUCT DETAILS SCREEN
// ============================================================================

class ProductDetailsScreen extends StatefulWidget {
  final Product product;
  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  int quantity = 1;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);
    final sdgPrice = widget.product.calculateSdgPrice(provider.usdRate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل المنتج', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0A2F6B))),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 220,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color ?? Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE1E9F3)),
                      ),
                      child: Center(
                        child: Icon(
                          widget.product.category == 'معدات'
                              ? Icons.monitor_heart_outlined
                              : widget.product.category == 'مختبر'
                                  ? Icons.science_outlined
                                  : Icons.medication_liquid_outlined,
                          size: 96,
                          color: const Color(0xFF0A47A8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20)),
                                  child: Text(
                                    widget.product.stockQuantity > 0 ? 'متوفر (${widget.product.stockQuantity})' : 'غير متوفر',
                                    style: TextStyle(color: widget.product.stockQuantity > 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                ),
                                Text('قسم ${widget.product.category}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(widget.product.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0A2F6B))),
                            const SizedBox(height: 8),
                            Text(
                              '${intl.NumberFormat('#,###').format(sdgPrice)} جنيه سوداني',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF0A47A8)),
                            ),
                            const Divider(height: 24),
                            Text(widget.product.description, style: const TextStyle(fontSize: 14, height: 1.5)),
                            const SizedBox(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('الكمية المطلوبة:', style: TextStyle(fontWeight: FontWeight.bold)),
                                Container(
                                  decoration: BoxDecoration(color: const Color(0xFFF0F4F9), borderRadius: BorderRadius.circular(12)),
                                  child: Row(
                                    children: [
                                      IconButton(
                                        onPressed: () {
                                          if (quantity > 1) setState(() => quantity--);
                                        },
                                        icon: const Icon(Icons.remove, size: 18, color: Colors.black87),
                                      ),
                                      Text('$quantity', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                                      IconButton(
                                        onPressed: () => setState(() => quantity++),
                                        icon: const Icon(Icons.add, size: 18, color: Colors.black87),
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
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).cardTheme.color ?? Colors.white,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A47A8),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () {
                  provider.addToCart(widget.product, qty: quantity);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تمت إضافة المنتج إلى السلة بنجاح')),
                  );
                },
                icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
                label: Text(
                  'أضف للسلة (${intl.NumberFormat('#,###').format(sdgPrice * quantity)} ج.س)',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 4. CART SCREEN
// ============================================================================

class CartScreen extends StatelessWidget {
  final VoidCallback? onBrowseProducts;
  const CartScreen({super.key, this.onBrowseProducts});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);

    if (provider.cart.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: const BoxDecoration(color: Color(0xFFE0F7FA), shape: BoxShape.circle),
                    child: const Icon(Icons.shopping_bag_outlined, size: 48, color: Color(0xFF00B8C4)),
                  ),
                  const SizedBox(height: 16),
                  const Text('السلة فارغة حالياً', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0A2F6B))),
                  const SizedBox(height: 6),
                  const Text(
                    'لم تقم بإضافة أي معدات أو مستهلكات طبية إلى سلتك بعد.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A47A8),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: onBrowseProducts,
                    child: const Text('تصفح المنتجات الآن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final subtotal = provider.cartSubtotalSdg;
    final deliveryFee = provider.selectedDeliveryArea?.deliveryFee ?? 0.0;
    final grandTotal = subtotal + deliveryFee;

    return Column(
      children: [
        Container(
          color: Theme.of(context).cardTheme.color ?? Colors.white,
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('سلة التسوق', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0A2F6B))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFEBF2FA), borderRadius: BorderRadius.circular(12)),
                child: Text('${provider.cart.length} عناصر', style: const TextStyle(color: Color(0xFF0A47A8), fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.cart.length,
            itemBuilder: (context, index) {
              final item = provider.cart[index];
              final price = item.product.calculateSdgPrice(provider.usdRate);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.medical_services_outlined, color: Color(0xFF0A47A8)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0A2F6B))),
                            const SizedBox(height: 4),
                            Text('${intl.NumberFormat('#,###').format(price)} ج.س', style: const TextStyle(color: Color(0xFF0A47A8), fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, size: 20),
                            onPressed: () => provider.updateCartQty(item.product, -1),
                          ),
                          Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline, size: 20),
                            onPressed: () => provider.updateCartQty(item.product, 1),
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

        // Summary Card
        Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('مجموع المنتجات:'),
                    Text('${intl.NumberFormat('#,###').format(subtotal)} ج.س', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('رسوم التوصيل (${provider.selectedDeliveryArea?.name ?? "-"}):'),
                    Text('${intl.NumberFormat('#,###').format(deliveryFee)} ج.س', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('الإجمالي الكلي:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(
                      '${intl.NumberFormat('#,###').format(grandTotal)} ج.س',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF0A47A8)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A47A8),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckoutScreen()));
                  },
                  child: const Text('إتمام الطلب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// 5. CHECKOUT SCREEN
// ============================================================================

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  String deliveryType = 'توصيل للموقع';

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<AppStateProvider>(context, listen: false);
    _nameController.text = provider.userName ?? '';
    _phoneController.text = provider.userPhone ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إتمام الطلب', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0A2F6B))),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('بيانات الاستلام والتوصيل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0A2F6B))),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'الاسم بالكامل', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<DeliveryArea>(
                        initialValue: provider.selectedDeliveryArea,
                        decoration: const InputDecoration(labelText: 'منطقة التوصيل', border: OutlineInputBorder()),
                        items: provider.deliveryAreas.map((area) {
                          return DropdownMenuItem(
                            value: area,
                            child: Text('${area.name} (${intl.NumberFormat('#,###').format(area.deliveryFee)} ج.س)'),
                          );
                        }).toList(),
                        onChanged: (area) {
                          if (area != null) provider.setDeliveryArea(area);
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _addressController,
                        decoration: const InputDecoration(
                          labelText: 'العنوان التفصيلي',
                          hintText: 'اسم الحي، الشارع، أو اسم المركز الطبي...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('طريقة الاستلام', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0A2F6B))),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('توصيل للموقع')),
                              selected: deliveryType == 'توصيل للموقع',
                              onSelected: (_) => setState(() => deliveryType = 'توصيل للموقع'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ChoiceChip(
                              label: const Center(child: Text('استلام من المحل')),
                              selected: deliveryType == 'استلام من المحل',
                              onSelected: (_) => setState(() => deliveryType = 'استلام من المحل'),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      const Text('طريقة الدفع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0A2F6B))),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: const [
                            Icon(Icons.payments_outlined, color: Color(0xFF0A47A8)),
                            SizedBox(width: 8),
                            Text('الدفع كاش عند الاستلام', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A47A8),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: provider.isLoading
                    ? null
                    : () async {
                        final err = await provider.placeOrder(
                          name: _nameController.text.trim(),
                          phone: _phoneController.text.trim(),
                          address: _addressController.text.trim(),
                          deliveryType: deliveryType,
                        );
                        if (err == null) {
                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم تأكيد طلبك بنجاح!')),
                            );
                          }
                        } else {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(err), backgroundColor: Colors.red),
                            );
                          }
                        }
                      },
                child: provider.isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('تأكيد الطلب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 6. MY ORDERS SCREEN
// ============================================================================

class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({super.key});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'تم':
        return Colors.green;
      case 'قيد التجهيز':
        return Colors.orange;
      case 'في الطريق':
        return const Color(0xFF00838F);
      case 'جديد':
      default:
        return const Color(0xFF0A47A8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);

    return Column(
      children: [
        Container(
          color: Theme.of(context).cardTheme.color ?? Colors.white,
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: const Text('قائمة طلباتي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0A2F6B))),
        ),
        Expanded(
          child: provider.orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text('لا توجد طلبات سابقة', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.orders.length,
                  itemBuilder: (context, index) {
                    final order = provider.orders[index];
                    final statusColor = _getStatusColor(order.status);
                    final itemsSummaryText = order.items.isNotEmpty
                        ? order.items.map((i) => '${i.productName} (×${i.quantity})').join('، ')
                        : 'عناصر الطلب غير متوفرة التفاصيل';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('طلب #${order.orderNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0A2F6B))),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                                  child: Text(order.status, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              intl.DateFormat('yyyy/MM/dd - hh:mm a').format(order.createdAt),
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              itemsSummaryText,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${intl.NumberFormat('#,###').format(order.totalSdg)} ج.س',
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Color(0xFF0A47A8)),
                                ),
                                Row(
                                  children: [
                                    OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: () {
                                        Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceScreen(order: order)));
                                      },
                                      child: const Text('عرض الفاتورة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 6),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF0A47A8),
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: () {
                                        provider.reorderItems(order);
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('تمت إعادة إضافـة عناصر الطلب إلى السلة بنجاح')),
                                        );
                                      },
                                      child: const Text('إعادة الطلب', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
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
      ],
    );
  }
}

// ============================================================================
// 7. INVOICE SCREEN
// ============================================================================

class InvoiceScreen extends StatelessWidget {
  final CustomerOrder order;
  const InvoiceScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('فاتورة مبيعات', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0A2F6B))),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color ?? Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF0A2F6B), width: 2),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(color: const Color(0xFF0A2F6B), borderRadius: BorderRadius.circular(12)),
                        child: const Center(child: Text('DMC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))),
                      ),
                      const SizedBox(height: 8),
                      const Text('Diala Medical & Chemical', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0A2F6B))),
                      const Text('فاتورة مبيعات رسمية', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const Divider(height: 24, thickness: 1.5),

                      Align(
                        alignment: Alignment.centerRight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('اسم العميل: ${order.customerName}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            Text('رقم الفاتورة: #${order.orderNumber}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            Text('التاريخ: ${intl.DateFormat('yyyy/MM/dd').format(order.createdAt)}', style: const TextStyle(fontSize: 12)),
                            Text('منطقة التوصيل: ${order.deliveryAreaName}', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      Table(
                        border: TableBorder.all(color: Colors.grey.shade300),
                        columnWidths: const {
                          0: FlexColumnWidth(3),
                          1: FlexColumnWidth(1),
                          2: FlexColumnWidth(2),
                          3: FlexColumnWidth(2),
                        },
                        children: [
                          TableRow(
                            decoration: BoxDecoration(color: Colors.grey.shade100),
                            children: const [
                              Padding(padding: EdgeInsets.all(6), child: Text('الصنف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87), textAlign: TextAlign.center)),
                              Padding(padding: EdgeInsets.all(6), child: Text('الكمية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87), textAlign: TextAlign.center)),
                              Padding(padding: EdgeInsets.all(6), child: Text('السعر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87), textAlign: TextAlign.center)),
                              Padding(padding: EdgeInsets.all(6), child: Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.black87), textAlign: TextAlign.center)),
                            ],
                          ),
                          ...order.items.map((item) {
                            return TableRow(
                              children: [
                                Padding(padding: const EdgeInsets.all(6), child: Text(item.productName, style: const TextStyle(fontSize: 11))),
                                Padding(padding: const EdgeInsets.all(6), child: Text('${item.quantity}', style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                                Padding(padding: const EdgeInsets.all(6), child: Text(intl.NumberFormat('#,###').format(item.unitPriceSdg), style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                                Padding(padding: const EdgeInsets.all(6), child: Text(intl.NumberFormat('#,###').format(item.totalPriceSdg), style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)),
                              ],
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('رسوم التوصيل: ${intl.NumberFormat('#,###').format(order.deliveryFee)} ج.س', style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 4),
                            Text(
                              'المطلوب: ${intl.NumberFormat('#,###').format(order.totalSdg)} ج.س',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0A47A8)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A47A8),
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('جاري تحميل الفاتورة بصيغة PDF...')),
                        );
                      },
                      icon: const Icon(Icons.download, color: Colors.white),
                      label: const Text('تحميل PDF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم نسخ رابط الفاتورة للمشاركة')),
                        );
                      },
                      child: const Text('مشاركة', style: TextStyle(fontWeight: FontWeight.bold)),
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

// ============================================================================
// 8. CONTACT US SCREEN
// ============================================================================

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(color: const Color(0xFF0A2F6B), borderRadius: BorderRadius.circular(16)),
                    child: const Center(child: Text('DMC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                  ),
                  const SizedBox(height: 12),
                  const Text('Diala Medical & Chemical', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0A2F6B))),
                  const Text('نحن هنا لخدمتكم وتوفير جميع احتياجاتكم الطبية', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _launchUrl('https://wa.me/249912345678'),
                    icon: const Icon(Icons.chat, color: Colors.white),
                    label: const Text('تواصل عبر الواتساب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A47A8),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _launchUrl('tel:0912345678'),
                    icon: const Icon(Icons.phone, color: Colors.white),
                    label: const Text('اتصال هاتفي مباشر', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                      if (!serviceEnabled) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('خدمة الموقع مغلقة في الهاتف')));
                        }
                        return;
                      }
                      LocationPermission permission = await Geolocator.checkPermission();
                      if (permission == LocationPermission.denied) {
                        permission = await Geolocator.requestPermission();
                      }
                      if (permission == LocationPermission.deniedForever) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('تم رفض صلاحيات الموقع بشكل دائم. يرجى التفعيل من إعدادات الهاتف.'),
                              action: SnackBarAction(
                                label: 'الإعدادات',
                                onPressed: () => Geolocator.openAppSettings(),
                              ),
                            ),
                          );
                        }
                        return;
                      }
                      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
                        _launchUrl('https://maps.google.com/?q=17.7011,33.9855');
                      } else {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('نحتاج صلاحية الموقع لعرض المحل على الخريطة')));
                        }
                      }
                    },
                    icon: const Icon(Icons.map_outlined),
                    label: const Text('موقع المحل على الخريطة', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (provider.deliveryAreas.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('مناطق التوصيل المتاحة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0A2F6B))),
                    const SizedBox(height: 12),
                    ...provider.deliveryAreas.map((area) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('• ${area.name}', style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text('${intl.NumberFormat('#,###').format(area.deliveryFee)} ج.س', style: const TextStyle(color: Color(0xFF0A47A8), fontWeight: FontWeight.bold)),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================================
// 9. NOTIFICATIONS SCREEN
// ============================================================================

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0A2F6B))),
        centerTitle: true,
      ),
      body: SafeArea(
        child: provider.notifications.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 12),
                    Text('لا توجد إشعارات حالياً', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: provider.notifications.length,
                itemBuilder: (context, index) {
                  final notif = provider.notifications[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: Color(0xFFE0F7FA), shape: BoxShape.circle),
                        child: const Icon(Icons.notifications, color: Color(0xFF00B8C4)),
                      ),
                      title: Text(notif.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text(notif.body, style: const TextStyle(fontSize: 12)),
                      trailing: Text(
                        intl.DateFormat('hh:mm a').format(notif.createdAt),
                        style: const TextStyle(fontSize: 10, color: Colors.grey),
                      ),
                      onTap: () {
                        provider.markNotificationRead(notif.id);
                      },
                    ),
                  );
                },
              ),
      ),
    );
  }
}
