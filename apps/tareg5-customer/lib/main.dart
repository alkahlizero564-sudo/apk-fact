import 'dart:async';
import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart' as intl_pkg;
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_config.dart';

// Top-level background message handler for Firebase Messaging
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: firebaseOptions);
  } catch (e) {
    debugPrint("Firebase background init warning: $e");
  }
}

// Supabase REST Constants
const String kSupabaseUrl = "https://jvjtgzewumfecjdpekna.supabase.co";
const String kSupabaseAnonKey =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp2anRnemV3dW1mZWNqZHBla25hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE2NDYzMzcsImV4cCI6MjEwNzIyMjMzN30.1gck73ek8ErBtcF7xAtFM1TdvNim_1NzFVNej_mptBE";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  try {
    await Firebase.initializeApp(options: firebaseOptions);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint("Firebase init warning: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: const DmcCustomerApp(),
    ),
  );
}

// -----------------------------------------------------------------------------
// MODELS
// -----------------------------------------------------------------------------

class Product {
  final int id;
  final String name;
  final String category;
  final double priceUsd;
  final int stockQuantity;
  final String imageUrl;
  final bool isVisible;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.priceUsd,
    required this.stockQuantity,
    required this.imageUrl,
    required this.isVisible,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      category: json['category'] ?? 'عام',
      priceUsd: (json['price_usd'] as num?)?.toDouble() ?? 0.0,
      stockQuantity: json['stock_quantity'] ?? 0,
      imageUrl: json['image_url'] ?? '',
      isVisible: json['is_visible'] ?? true,
    );
  }

  double calculatePriceSdg(double usdRate) => priceUsd * usdRate;
}

class DeliveryArea {
  final int id;
  final String name;
  final double deliveryFee;

  DeliveryArea({
    required this.id,
    required this.name,
    required this.deliveryFee,
  });

  factory DeliveryArea.fromJson(Map<String, dynamic> json) {
    return DeliveryArea(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class CartItem {
  final Product product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});

  double totalSdg(double usdRate) => product.calculatePriceSdg(usdRate) * quantity;
}

class CustomerOrder {
  final int id;
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String areaName;
  final double deliveryFee;
  final String deliveryType;
  final String detailedAddress;
  final double totalAmount;
  final String status;
  final DateTime createdAt;
  final List<OrderItem> items;

  CustomerOrder({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.areaName,
    required this.deliveryFee,
    required this.deliveryType,
    required this.detailedAddress,
    required this.totalAmount,
    required this.status,
    required this.createdAt,
    this.items = const [],
  });

  factory CustomerOrder.fromJson(Map<String, dynamic> json, [List<OrderItem> items = const []]) {
    return CustomerOrder(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      customerId: json['customer_id'] ?? '',
      customerName: json['customer_name'] ?? 'عميل DMC',
      customerPhone: json['customer_phone'] ?? '',
      areaName: json['area_name'] ?? 'عطبرة',
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0.0,
      deliveryType: json['delivery_type'] ?? 'توصيل للموقع',
      detailedAddress: json['detailed_address'] ?? '',
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] ?? 'جديد',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      items: items,
    );
  }
}

class OrderItem {
  final int id;
  final int orderId;
  final int productId;
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
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      orderId: json['order_id'] is int ? json['order_id'] : int.parse(json['order_id'].toString()),
      productId: json['product_id'] is int ? json['product_id'] : int.parse(json['product_id'].toString()),
      productName: json['product_name'] ?? '',
      quantity: json['quantity'] ?? 1,
      unitPriceSdg: (json['unit_price_sdg'] as num?)?.toDouble() ?? 0.0,
      totalPriceSdg: (json['total_price_sdg'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class AppNotification {
  final int id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      isRead: json['read_at'] != null,
    );
  }
}

// -----------------------------------------------------------------------------
// APP STATE PROVIDER
// -----------------------------------------------------------------------------

class AppState with ChangeNotifier, WidgetsBindingObserver {
  String? accessToken;
  String? refreshToken;
  String? userId;
  String? userEmail;
  String userFullName = "";
  String userPhone = "";

  double usdRate = 600.0;
  List<Product> products = [];
  List<DeliveryArea> deliveryAreas = [];
  List<CustomerOrder> orders = [];
  List<AppNotification> notifications = [];
  List<CartItem> cart = [];

  DeliveryArea? selectedArea;
  String selectedCategory = 'الكل';
  String searchQuery = '';
  bool isLoading = false;
  Timer? _syncTimer;

  AppState() {
    WidgetsBinding.instance.addObserver(this);
    initSession();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && accessToken != null) {
      refreshAllData(quiet: true);
    }
  }

  Future<void> initSession() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('access_token');
    final savedRefresh = prefs.getString('refresh_token');
    final savedUserId = prefs.getString('user_id');
    final savedEmail = prefs.getString('user_email');

    if (savedToken != null && savedToken.isNotEmpty && savedUserId != null) {
      accessToken = savedToken;
      refreshToken = savedRefresh;
      userId = savedUserId;
      userEmail = savedEmail;
      userFullName = prefs.getString('user_name') ?? '';
      userPhone = prefs.getString('user_phone') ?? '';

      _startSyncTimer();
      await setupPushNotifications();
      await fetchProfile();
      await refreshAllData();
    }
    notifyListeners();
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (accessToken != null) {
        refreshAllData(quiet: true);
      }
    });
  }

  Future<http.Response> authenticatedRequest(
    String method,
    String url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    headers ??= {};
    headers['apikey'] = kSupabaseAnonKey;
    headers['Content-Type'] = 'application/json';
    headers['Prefer'] = 'return=representation';

    if (accessToken != null && accessToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    final uri = Uri.parse(url);
    http.Response res;
    if (method == 'GET') {
      res = await http.get(uri, headers: headers);
    } else if (method == 'POST') {
      res = await http.post(uri, headers: headers, body: body);
    } else if (method == 'PATCH') {
      res = await http.patch(uri, headers: headers, body: body);
    } else if (method == 'PUT') {
      res = await http.put(uri, headers: headers, body: body);
    } else if (method == 'DELETE') {
      res = await http.delete(uri, headers: headers, body: body);
    } else {
      throw Exception('Unsupported method');
    }

    if (res.statusCode == 401 && refreshToken != null && refreshToken!.isNotEmpty) {
      final refreshed = await _tryRefreshToken();
      if (refreshed) {
        headers['Authorization'] = 'Bearer $accessToken';
        if (method == 'GET') {
          res = await http.get(uri, headers: headers);
        } else if (method == 'POST') {
          res = await http.post(uri, headers: headers, body: body);
        } else if (method == 'PATCH') {
          res = await http.patch(uri, headers: headers, body: body);
        } else if (method == 'PUT') {
          res = await http.put(uri, headers: headers, body: body);
        } else if (method == 'DELETE') {
          res = await http.delete(uri, headers: headers, body: body);
        }
      } else {
        await signOut();
      }
    }
    return res;
  }

  Future<bool> _tryRefreshToken() async {
    if (refreshToken == null || refreshToken!.isEmpty) return false;
    try {
      final res = await http.post(
        Uri.parse("$kSupabaseUrl/auth/v1/token?grant_type=refresh_token"),
        headers: {
          'apikey': kSupabaseAnonKey,
          'Content-Type': 'application/json',
        },
        body: json.encode({"refresh_token": refreshToken}),
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        accessToken = data['access_token'];
        refreshToken = data['refresh_token'] ?? refreshToken;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', accessToken!);
        if (refreshToken != null) {
          await prefs.setString('refresh_token', refreshToken!);
        }
        return true;
      }
    } catch (e) {
      debugPrint("Refresh token error: $e");
    }
    return false;
  }

  String parseErrorMessage(http.Response response, String requestType) {
    try {
      final data = json.decode(response.body);
      if (data is Map) {
        final err = (data['error_description'] ?? data['msg'] ?? data['message'] ?? data['error'] ?? '').toString();
        final errLower = err.toLowerCase();

        if (errLower.contains('rate limit') || errLower.contains('over_email_send_rate_limit')) {
          return 'اتبعتت رسائل كتير، استنى دقايق';
        }
        if (errLower.contains('sending') || errLower.contains('smtp') || errLower.contains('email_provider_disabled')) {
          return 'ما قدرنا نرسل البريد';
        }

        if (requestType == 'verify') {
          if (errLower.contains('invalid') || errLower.contains('expired') || errLower.contains('token') || response.statusCode == 400 || response.statusCode == 422) {
            return 'رمز التأكيد غير صحيح أو انتهت صلاحيته';
          }
        }

        if (err.isNotEmpty) return err;
      }
    } catch (_) {}

    if (requestType == 'verify') {
      return 'رمز التأكيد غير صحيح أو انتهت صلاحيته';
    } else if (requestType == 'signup' || requestType == 'resend' || requestType == 'recover') {
      return 'تعذر إرسال رمز التأكيد، يرجى المحاولة لاحقاً';
    }
    return 'حدث خطأ في الاتصال بالسيرفر (${response.statusCode})';
  }

  Future<void> refreshAllData({bool quiet = false}) async {
    if (accessToken == null) return;
    if (!quiet) {
      isLoading = true;
      notifyListeners();
    }
    try {
      await Future.wait([
        fetchSettings(),
        fetchDeliveryAreas(),
        fetchProducts(),
        if (userId != null) fetchOrders(),
        if (userId != null) fetchNotifications(),
      ]);
    } catch (e) {
      debugPrint("Data sync error: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  // REST API Methods
  Future<void> fetchSettings() async {
    try {
      final res = await authenticatedRequest('GET', "$kSupabaseUrl/rest/v1/tareg5_settings?select=*&limit=1");
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        if (data.isNotEmpty) {
          usdRate = (data.first['usd_rate'] as num).toDouble();
        }
      }
    } catch (_) {}
  }

  Future<void> fetchDeliveryAreas() async {
    try {
      final res = await authenticatedRequest('GET', "$kSupabaseUrl/rest/v1/tareg5_delivery_areas?select=*&order=id.asc");
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        deliveryAreas = data.map((e) => DeliveryArea.fromJson(e)).toList();
        if (selectedArea == null && deliveryAreas.isNotEmpty) {
          selectedArea = deliveryAreas.first;
        }
      }
    } catch (_) {}
  }

  Future<void> fetchProducts() async {
    try {
      final res = await authenticatedRequest('GET', "$kSupabaseUrl/rest/v1/tareg5_products?select=*&is_visible=eq.true&order=created_at.desc");
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        products = data.map((e) => Product.fromJson(e)).toList();
      }
    } catch (_) {}
  }

  Future<void> fetchOrders() async {
    if (userId == null) return;
    try {
      final res = await authenticatedRequest(
        'GET',
        "$kSupabaseUrl/rest/v1/tareg5_orders?select=*,tareg5_order_items(*)&customer_id=eq.$userId&order=created_at.desc",
      );
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        orders = data.map((e) {
          final itemsRaw = e['tareg5_order_items'] as List? ?? [];
          final items = itemsRaw.map((i) => OrderItem.fromJson(i)).toList();
          return CustomerOrder.fromJson(e, items);
        }).toList();
      }
    } catch (_) {}
  }

  Future<void> fetchNotifications() async {
    if (userId == null) return;
    try {
      final res = await authenticatedRequest(
        'GET',
        "$kSupabaseUrl/rest/v1/tareg5_notifications?or=(to_user.eq.$userId,to_role.eq.customer)&order=created_at.desc",
      );
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        notifications = data.map((e) => AppNotification.fromJson(e)).toList();
      }
    } catch (_) {}
  }

  Future<void> markNotificationRead(int notifId) async {
    try {
      final nowStr = DateTime.now().toIso8601String();
      await authenticatedRequest(
        'PATCH',
        "$kSupabaseUrl/rest/v1/tareg5_notifications?id=eq.$notifId",
        body: json.encode({"read_at": nowStr}),
      );
      await fetchNotifications();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> fetchProfile() async {
    if (userId == null) return;
    try {
      final res = await authenticatedRequest('GET', "$kSupabaseUrl/rest/v1/tareg5_profiles?id=eq.$userId");
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        if (data.isNotEmpty) {
          final p = data.first;
          userFullName = p['full_name'] ?? userFullName;
          userPhone = p['phone'] ?? userPhone;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('user_name', userFullName);
          await prefs.setString('user_phone', userPhone);
        }
      }
    } catch (_) {}
  }

  Future<String?> updateProfile(String name, String phone) async {
    if (userId == null) return "غير مسجل دخول";
    isLoading = true;
    notifyListeners();

    try {
      final res = await authenticatedRequest(
        'PATCH',
        "$kSupabaseUrl/rest/v1/tareg5_profiles?id=eq.$userId",
        body: json.encode({"full_name": name, "phone": phone}),
      );

      await authenticatedRequest(
        'PATCH',
        "$kSupabaseUrl/rest/v1/tareg5_customers?id=eq.$userId",
        body: json.encode({"full_name": name, "phone": phone}),
      );

      if (res.statusCode == 200 || res.statusCode == 204) {
        userFullName = name;
        userPhone = phone;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_name', name);
        await prefs.setString('user_phone', phone);
        isLoading = false;
        notifyListeners();
        return null;
      } else {
        isLoading = false;
        notifyListeners();
        return parseErrorMessage(res, 'update');
      }
    } catch (e) {
      isLoading = false;
      notifyListeners();
      return "فشل تحديث البيانات، يرجى الاتصال بالشبكة";
    }
  }

  // Push Notifications Setup
  Future<void> setupPushNotifications() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token != null && accessToken != null) {
        await authenticatedRequest(
          'POST',
          "$kSupabaseUrl/rest/v1/rpc/tareg5_register_device",
          body: json.encode({"device_token": token, "app_name": "customer"}),
        );
      }
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        refreshAllData(quiet: true);
      });
    } catch (e) {
      debugPrint("Push register warning: $e");
    }
  }

  // Cart Management
  void addToCart(Product p, [int qty = 1]) {
    final index = cart.indexWhere((item) => item.product.id == p.id);
    if (index >= 0) {
      cart[index].quantity += qty;
    } else {
      cart.add(CartItem(product: p, quantity: qty));
    }
    notifyListeners();
  }

  void updateCartQty(int productId, int delta) {
    final index = cart.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      cart[index].quantity += delta;
      if (cart[index].quantity <= 0) {
        cart.removeAt(index);
      }
      notifyListeners();
    }
  }

  void clearCart() {
    cart.clear();
    notifyListeners();
  }

  void reorderOrder(CustomerOrder order) {
    for (final item in order.items) {
      final matchingProduct = products.firstWhere(
        (p) => p.id == item.productId,
        orElse: () => Product(
          id: item.productId,
          name: item.productName,
          category: 'عام',
          priceUsd: item.unitPriceSdg / usdRate,
          stockQuantity: 10,
          imageUrl: '',
          isVisible: true,
        ),
      );
      addToCart(matchingProduct, item.quantity);
    }
  }

  double get cartSubtotalSdg => cart.fold(0.0, (sum, i) => sum + i.totalSdg(usdRate));
  double get cartTotalSdg => cartSubtotalSdg + (selectedArea?.deliveryFee ?? 0.0);

  // AUTH FUNCTIONS (STRICT SUPABASE REST WITHOUT DEMO/MOCK FALLBACKS)

  Future<String?> login(String email, String password) async {
    isLoading = true;
    notifyListeners();
    try {
      final res = await http.post(
        Uri.parse("$kSupabaseUrl/auth/v1/token?grant_type=password"),
        headers: {'apikey': kSupabaseAnonKey, 'Content-Type': 'application/json'},
        body: json.encode({"email": email, "password": password}),
      );
      final body = json.decode(res.body);

      if (res.statusCode == 200) {
        accessToken = body['access_token'];
        refreshToken = body['refresh_token'];
        userId = body['user']['id'];
        userEmail = body['user']['email'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', accessToken!);
        if (refreshToken != null) await prefs.setString('refresh_token', refreshToken!);
        await prefs.setString('user_id', userId!);
        await prefs.setString('user_email', userEmail!);

        _startSyncTimer();
        await setupPushNotifications();
        await fetchProfile();
        await refreshAllData();
        isLoading = false;
        notifyListeners();
        return null;
      } else {
        isLoading = false;
        notifyListeners();
        final errStr = (body['error_description'] ?? body['msg'] ?? body['error'] ?? body['message'] ?? '').toString();
        if (errStr.contains('Email not confirmed') || errStr.contains('email_not_confirmed')) {
          await resendOtp(email, 'signup');
          return 'EMAIL_NOT_CONFIRMED';
        }
        return parseErrorMessage(res, 'login');
      }
    } catch (e) {
      isLoading = false;
      notifyListeners();
      return 'فشل الاتصال بالخادم، يرجى التأكد من الإنترنت';
    }
  }

  Future<String?> signUp(String name, String phone, String email, String password) async {
    isLoading = true;
    notifyListeners();
    try {
      final res = await http.post(
        Uri.parse("$kSupabaseUrl/auth/v1/signup"),
        headers: {'apikey': kSupabaseAnonKey, 'Content-Type': 'application/json'},
        body: json.encode({
          "email": email,
          "password": password,
          "data": {
            "full_name": name,
            "phone": phone,
          }
        }),
      );

      if (res.statusCode == 200 || res.statusCode == 201) {
        userFullName = name;
        userPhone = phone;
        userEmail = email;
        isLoading = false;
        notifyListeners();
        return null;
      } else {
        isLoading = false;
        notifyListeners();
        return parseErrorMessage(res, 'signup');
      }
    } catch (e) {
      isLoading = false;
      notifyListeners();
      return 'تعذر الاتصال بالخادم لإتمام التسجيل';
    }
  }

  Future<String?> resendOtp(String email, [String type = "signup"]) async {
    try {
      final res = await http.post(
        Uri.parse("$kSupabaseUrl/auth/v1/resend"),
        headers: {'apikey': kSupabaseAnonKey, 'Content-Type': 'application/json'},
        body: json.encode({"type": type, "email": email}),
      );
      if (res.statusCode == 200) {
        return null;
      } else {
        return parseErrorMessage(res, 'resend');
      }
    } catch (e) {
      return 'ما قدرنا نرسل البريد';
    }
  }

  Future<String?> verifyOtp(String email, String code, [String type = "signup"]) async {
    isLoading = true;
    notifyListeners();
    try {
      final res = await http.post(
        Uri.parse("$kSupabaseUrl/auth/v1/verify"),
        headers: {'apikey': kSupabaseAnonKey, 'Content-Type': 'application/json'},
        body: json.encode({
          "type": type,
          "email": email,
          "token": code,
        }),
      );
      final body = json.decode(res.body);

      if (res.statusCode == 200) {
        accessToken = body['access_token'];
        refreshToken = body['refresh_token'];
        if (body['user'] != null) {
          userId = body['user']['id'];
          userEmail = body['user']['email'];
        }

        if (accessToken != null && userId != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('access_token', accessToken!);
          if (refreshToken != null) await prefs.setString('refresh_token', refreshToken!);
          await prefs.setString('user_id', userId!);
          await prefs.setString('user_email', userEmail ?? email);

          // Insert or update profile details
          await authenticatedRequest(
            'PATCH',
            "$kSupabaseUrl/rest/v1/tareg5_profiles?id=eq.$userId",
            body: json.encode({"full_name": userFullName, "phone": userPhone}),
          );

          _startSyncTimer();
          await setupPushNotifications();
          await fetchProfile();
          await refreshAllData();
        }

        isLoading = false;
        notifyListeners();
        return null;
      } else {
        isLoading = false;
        notifyListeners();
        return parseErrorMessage(res, 'verify');
      }
    } catch (e) {
      isLoading = false;
      notifyListeners();
      return 'رمز التأكيد غير صحيح أو انتهت صلاحيته';
    }
  }

  Future<String?> recoverPassword(String email) async {
    isLoading = true;
    notifyListeners();
    try {
      final res = await http.post(
        Uri.parse("$kSupabaseUrl/auth/v1/recover"),
        headers: {'apikey': kSupabaseAnonKey, 'Content-Type': 'application/json'},
        body: json.encode({"email": email}),
      );
      isLoading = false;
      notifyListeners();
      if (res.statusCode == 200) {
        return null;
      } else {
        return parseErrorMessage(res, 'recover');
      }
    } catch (e) {
      isLoading = false;
      notifyListeners();
      return 'تعذر إرسال طلب استعادة كلمة المرور';
    }
  }

  Future<String?> updatePasswordWithSession(String newPassword) async {
    isLoading = true;
    notifyListeners();
    try {
      final res = await authenticatedRequest(
        'PUT',
        "$kSupabaseUrl/auth/v1/user",
        body: json.encode({"password": newPassword}),
      );
      isLoading = false;
      notifyListeners();
      if (res.statusCode == 200) {
        return null;
      } else {
        return parseErrorMessage(res, 'update');
      }
    } catch (e) {
      isLoading = false;
      notifyListeners();
      return 'فشل تحديث كلمة المرور';
    }
  }

  Future<void> signOut() async {
    accessToken = null;
    refreshToken = null;
    userId = null;
    userEmail = null;
    _syncTimer?.cancel();
    orders.clear();
    notifications.clear();
    cart.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }

  // Create Order API
  Future<bool> createOrder({
    required String name,
    required String phone,
    required String address,
    required String deliveryType,
  }) async {
    if (cart.isEmpty || userId == null) return false;
    isLoading = true;
    notifyListeners();

    try {
      // 1. Insert order into tareg5_orders
      final orderRes = await authenticatedRequest(
        'POST',
        "$kSupabaseUrl/rest/v1/tareg5_orders",
        body: json.encode({
          "customer_id": userId,
          "customer_name": name,
          "customer_phone": phone,
          "area_name": selectedArea?.name ?? "عطبرة",
          "delivery_fee": selectedArea?.deliveryFee ?? 0,
          "delivery_type": deliveryType,
          "detailed_address": address,
          "total_amount": cartTotalSdg,
          "status": "جديد",
        }),
      );

      if (orderRes.statusCode == 200 || orderRes.statusCode == 201) {
        final List createdOrders = json.decode(orderRes.body);
        final createdOrder = createdOrders.first;
        final orderId = createdOrder['id'];

        // 2. Insert items into tareg5_order_items
        for (final item in cart) {
          await authenticatedRequest(
            'POST',
            "$kSupabaseUrl/rest/v1/tareg5_order_items",
            body: json.encode({
              "order_id": orderId,
              "product_id": item.product.id,
              "product_name": item.product.name,
              "quantity": item.quantity,
              "unit_price_sdg": item.product.calculatePriceSdg(usdRate),
              "total_price_sdg": item.totalSdg(usdRate),
            }),
          );
        }

        // 3. Send Notification to Admin
        await authenticatedRequest(
          'POST',
          "$kSupabaseUrl/rest/v1/tareg5_notifications",
          body: json.encode({
            "to_role": "admin",
            "title": "طلب جديد من $name",
            "body": "تم تقديم طلب جديد بقيمة ${cartTotalSdg.toStringAsFixed(0)} ج.س (#$orderId)",
            "data": {"order_id": orderId},
          }),
        );

        clearCart();
        await fetchOrders();
        isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint("Create order error: $e");
    }

    isLoading = false;
    notifyListeners();
    return false;
  }
}

// -----------------------------------------------------------------------------
// APP CONTAINER & THEME
// -----------------------------------------------------------------------------

class DmcCustomerApp extends StatelessWidget {
  const DmcCustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0A47A8);
    const darkBlueHeader = Color(0xFF0A2F6B);
    const cyanTeal = Color(0xFF00B8C4);
    const bgMain = Color(0xFFF3F7FC);

    final lightTheme = ThemeData(
      useMaterial3: true,
      fontFamily: 'Cairo',
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: cyanTeal,
        surface: Colors.white,
      ),
      scaffoldBackgroundColor: bgMain,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: darkBlueHeader,
        elevation: 0,
        centerTitle: false,
      ),
    );

    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Cairo',
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: Brightness.dark,
        primary: primaryColor,
        secondary: cyanTeal,
        surface: const Color(0xFF1E293B),
      ),
      scaffoldBackgroundColor: const Color(0xFF0F172A),
    );

    return MaterialApp(
      title: 'DMC Diala Customer',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.light,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: const MainTabScreen(),
    );
  }
}

// -----------------------------------------------------------------------------
// MAIN TAB SWITCHER SCREEN
// -----------------------------------------------------------------------------

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  State<MainTabScreen> createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _currentIndex = 0;

  void switchToTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (state.accessToken == null || state.accessToken!.isEmpty) {
      return const AuthScreen();
    }

    final pages = [
      const HomeScreen(),
      CartScreen(onContinueShopping: () => switchToTab(0)),
      MyOrdersScreen(onNavigateToCart: () => switchToTab(1)),
      const ContactScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE1E9F3))),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: switchToTab,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF0A47A8),
          unselectedItemColor: const Color(0xFF64748B),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'الرئيسية',
            ),
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: state.cart.isNotEmpty,
                label: Text('${state.cart.length}'),
                backgroundColor: const Color(0xFF00B8C4),
                child: const Icon(Icons.shopping_cart_outlined),
              ),
              activeIcon: Badge(
                isLabelVisible: state.cart.isNotEmpty,
                label: Text('${state.cart.length}'),
                backgroundColor: const Color(0xFF00B8C4),
                child: const Icon(Icons.shopping_cart),
              ),
              label: 'السلة',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.assignment_outlined),
              activeIcon: Icon(Icons.assignment),
              label: 'طلباتي',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.contact_support_outlined),
              activeIcon: Icon(Icons.contact_support),
              label: 'تواصل',
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 1) HOME SCREEN
// -----------------------------------------------------------------------------

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _requestLocationPermission(BuildContext context) async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('إذن الموقع مطلوب'),
            content: const Text('تم رفض إذن تحديد الموقع. يرجى تفعيل الإذن من إعدادات الهاتف لتحديد موقع التوصيل.'),
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
    if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
      try {
        final pos = await Geolocator.getCurrentPosition();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم تحديد موقعك: ${pos.latitude.toStringAsFixed(2)}, ${pos.longitude.toStringAsFixed(2)}')),
          );
        }
      } catch (e) {
        debugPrint("Location error: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    final filteredProducts = state.products.where((p) {
      final matchesCat = state.selectedCategory == 'الكل' || p.category == state.selectedCategory;
      final matchesSearch = p.name.contains(state.searchQuery);
      return matchesCat && matchesSearch;
    }).toList();

    final unreadCount = state.notifications.where((n) => !n.isRead).length;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0A2F6B), Color(0xFF0A47A8)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: const Center(
                child: Text(
                  'DMC',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'DMC Diala',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0A2F6B)),
                ),
                Text(
                  'معدات ومستهلكات طبية',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text('$unreadCount'),
              backgroundColor: const Color(0xFF00B8C4),
              child: const Icon(Icons.notifications_outlined, color: Color(0xFF0A2F6B)),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline, color: Color(0xFF0A2F6B)),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => state.refreshAllData(),
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // Search Bar
            TextField(
              onChanged: (val) {
                state.searchQuery = val;
                state.notifyListeners();
              },
              decoration: InputDecoration(
                hintText: 'ابحث عن جهاز، مستهلكات، أجهزة مختبر...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B)),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE1E9F3)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE1E9F3)),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Delivery Banner
            GestureDetector(
              onTap: () => _requestLocationPermission(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F7F9),
                  border: Border.all(color: const Color(0xFF00B8C4).withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, color: Color(0xFF00B8C4), size: 20),
                        const SizedBox(width: 6),
                        Text(
                          'التوصيل إلى: ${state.selectedArea?.name ?? "عطبرة"}',
                          style: const TextStyle(
                            color: Color(0xFF005B60),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00B8C4).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${state.selectedArea?.deliveryFee.toStringAsFixed(0) ?? 3000} ج.س',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Color(0xFF005B60),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Categories Row
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: ['الكل', 'معدات طبية', 'مستهلكات', 'مختبرات', 'أجهزة قياس'].map((cat) {
                  final isSelected = state.selectedCategory == cat;
                  return GestureDetector(
                    onTap: () {
                      state.selectedCategory = cat;
                      state.notifyListeners();
                    },
                    child: Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF0A47A8) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF0A47A8) : const Color(0xFFE1E9F3),
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF64748B),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Products Grid
            if (filteredProducts.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                alignment: Alignment.center,
                child: Column(
                  children: const [
                    Icon(Icons.inventory_2_outlined, size: 60, color: Color(0xFF94A3B8)),
                    SizedBox(height: 12),
                    Text('لا توجد منتجات مطابقة في المعرض حالياً', style: TextStyle(color: Color(0xFF64748B))),
                  ],
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredProducts.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.68,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemBuilder: (context, index) {
                  final p = filteredProducts[index];
                  final sdgPrice = p.calculatePriceSdg(state.usdRate);
                  final isAvailable = p.stockQuantity > 0;

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ProductDetailScreen(product: p)),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE1E9F3)),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  const Icon(Icons.medical_services_outlined, size: 48, color: Color(0xFF0A47A8)),
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isAvailable ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        isAvailable ? 'متوفر' : 'نفذت الكمية',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isAvailable ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                                        ),
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 36,
                            child: Text(
                              p.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 1.3),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${sdgPrice.toStringAsFixed(0)} ج.س',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0A2F6B)),
                          ),
                          Text(
                            '\$${p.priceUsd.toStringAsFixed(2)} (\$1 = ${state.usdRate.toStringAsFixed(0)})',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 38,
                            child: ElevatedButton(
                              onPressed: isAvailable
                                  ? () {
                                      state.addToCart(p);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('تمت الإضافة للسلة'),
                                          duration: Duration(seconds: 1),
                                        ),
                                      );
                                    }
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isAvailable ? const Color(0xFF0A47A8) : const Color(0xFF94A3B8),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: EdgeInsets.zero,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (isAvailable) const Icon(Icons.add, size: 16),
                                  if (isAvailable) const SizedBox(width: 4),
                                  Text(
                                    isAvailable ? 'أضف للسلة' : 'غير متوفر',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 2) PRODUCT DETAIL SCREEN
// -----------------------------------------------------------------------------

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _qty = 1;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final p = widget.product;
    final sdgPrice = p.calculatePriceSdg(state.usdRate);
    final totalPrice = sdgPrice * _qty;
    final isAvailable = p.stockQuantity > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل المنتج', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              height: 220,
              width: double.infinity,
              color: Colors.white,
              child: const Center(
                child: Icon(Icons.medical_services_outlined, size: 100, color: Color(0xFF0A47A8)),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -20),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE1E9F3)),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isAvailable ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isAvailable ? 'متوفر في المخزن' : 'نفذت الكمية',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isAvailable ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                            ),
                          ),
                        ),
                        Text('قسم: ${p.category}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      p.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0A2F6B), height: 1.3),
                    ),
                    const SizedBox(height: 16),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F7FC),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${totalPrice.toStringAsFixed(0)} ج.س',
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0A2F6B)),
                              ),
                              Text(
                                'سعر بالدولار: \$${p.priceUsd.toStringAsFixed(2)} (\$1 = ${state.usdRate.toStringAsFixed(0)})',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: const Color(0xFFE1E9F3)),
                            ),
                            child: Row(
                              children: [
                                InkWell(
                                  onTap: _qty > 1 ? () => setState(() => _qty--) : null,
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFFE1E9F3)),
                                    ),
                                    child: const Center(child: Text('-', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text('$_qty', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 12),
                                InkWell(
                                  onTap: () => setState(() => _qty++),
                                  child: Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFFE1E9F3)),
                                    ),
                                    child: const Center(child: Text('+', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                                  ),
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Text('الوصف واللمحة الطبية:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                    const SizedBox(height: 6),
                    const Text(
                      'منتج طبي عالي الجودة معتمد للاستخدام في العيادات والمستشفيات، مطابق للمواصفات الطبية والمعايير الصيدلانية القياسية.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.6),
                    ),
                    const SizedBox(height: 24),

                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: isAvailable
                            ? () {
                                state.addToCart(p, _qty);
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تمت إضافة المنتج إلى السلة بنجاح')),
                                );
                              }
                            : null,
                        icon: const Icon(Icons.shopping_cart_outlined),
                        label: Text('أضف للسلة (${totalPrice.toStringAsFixed(0)} ج.س)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A47A8),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

// -----------------------------------------------------------------------------
// 3) CART SCREEN
// -----------------------------------------------------------------------------

class CartScreen extends StatelessWidget {
  final VoidCallback? onContinueShopping;
  const CartScreen({super.key, this.onContinueShopping});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: Text('سلة المشتريات (${state.cart.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: state.cart.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE0F7F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shopping_cart_outlined, size: 40, color: Color(0xFF00B8C4)),
                  ),
                  const SizedBox(height: 16),
                  const Text('لا توجد منتجات في سلتك حالياً', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0A2F6B))),
                  const SizedBox(height: 6),
                  const Text('تصفح قائمة المعدات والمستهلكات الطبية وأضف احتياجاتك بسهولة.', style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: onContinueShopping,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A47A8),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('تصفح المنتجات الآن'),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ...state.cart.map((item) {
                  final sdgPrice = item.totalSdg(state.usdRate);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE1E9F3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.medical_services_outlined, color: Color(0xFF0A47A8), size: 32),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                              const SizedBox(height: 4),
                              Text(
                                '${sdgPrice.toStringAsFixed(0)} ج.س',
                                style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0A47A8), fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F7FC),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFFE1E9F3)),
                          ),
                          child: Row(
                            children: [
                              InkWell(
                                onTap: () => state.updateCartQty(item.product.id, -1),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFE1E9F3)),
                                  ),
                                  child: const Center(child: Text('-', style: TextStyle(fontWeight: FontWeight.bold))),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ),
                              InkWell(
                                onTap: () => state.updateCartQty(item.product.id, 1),
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFE1E9F3)),
                                  ),
                                  child: const Center(child: Text('+', style: TextStyle(fontWeight: FontWeight.bold))),
                                ),
                              ),
                            ],
                          ),
                        )
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 10),
                // Summary Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE1E9F3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('ملخص الحساب', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0A2F6B))),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('إجمالي المنتجات (\$${(state.cartSubtotalSdg / state.usdRate).toStringAsFixed(2)})', style: const TextStyle(color: Color(0xFF64748B), fontSize: 14)),
                          Text('${state.cartSubtotalSdg.toStringAsFixed(0)} ج.س', style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('رسوم التوصيل (${state.selectedArea?.name ?? "عطبرة"})', style: const TextStyle(color: Color(0xFF64748B), fontSize: 14)),
                          Text('${state.selectedArea?.deliveryFee.toStringAsFixed(0) ?? 3000} ج.س', style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                      const Divider(height: 24, thickness: 1),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('الإجمالي الكلي المطلوب', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0A2F6B))),
                          Text(
                            '${state.cartTotalSdg.toStringAsFixed(0)} ج.س',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0A47A8)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0A47A8),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text('إتمام الطلب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      )
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// -----------------------------------------------------------------------------
// 4) CHECKOUT SCREEN
// -----------------------------------------------------------------------------

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  String _deliveryType = 'توصيل للموقع';

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _nameController = TextEditingController(text: state.userFullName);
    _phoneController = TextEditingController(text: state.userPhone);
    _addressController = TextEditingController(text: 'حي المطار - بالقرب من المستشفى');
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('إتمام الطلب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE1E9F3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('الاسم بالكامل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),

              const Text('رقم الهاتف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),

              const Text('منطقة التوصيل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<DeliveryArea>(
                initialValue: state.selectedArea,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                items: state.deliveryAreas.map((area) {
                  return DropdownMenuItem(
                    value: area,
                    child: Text('${area.name} - ${area.deliveryFee.toStringAsFixed(0)} ج.س'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    state.selectedArea = val;
                    state.notifyListeners();
                  }
                },
              ),
              const SizedBox(height: 14),

              const Text('العنوان التفصيلي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _addressController,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),

              const Text('طريقة الاستلام والطلب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _deliveryType = 'توصيل للموقع'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        decoration: BoxDecoration(
                          color: _deliveryType == 'توصيل للموقع' ? const Color(0xFFDCE3F9) : Colors.white,
                          border: Border.all(
                            color: _deliveryType == 'توصيل للموقع' ? const Color(0xFF0A47A8) : const Color(0xFFE1E9F3),
                            width: _deliveryType == 'توصيل للموقع' ? 1.5 : 1.0,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Radio<String>(
                              value: 'توصيل للموقع',
                              groupValue: _deliveryType,
                              onChanged: (v) => setState(() => _deliveryType = v!),
                              activeColor: const Color(0xFF0A47A8),
                            ),
                            const Text('توصيل للموقع', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0A2F6B))),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _deliveryType = 'استلام من المحل'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        decoration: BoxDecoration(
                          color: _deliveryType == 'استلام من المحل' ? const Color(0xFFDCE3F9) : Colors.white,
                          border: Border.all(
                            color: _deliveryType == 'استلام من المحل' ? const Color(0xFF0A47A8) : const Color(0xFFE1E9F3),
                            width: _deliveryType == 'استلام من المحل' ? 1.5 : 1.0,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Radio<String>(
                              value: 'استلام من المحل',
                              groupValue: _deliveryType,
                              onChanged: (v) => setState(() => _deliveryType = v!),
                              activeColor: const Color(0xFF0A47A8),
                            ),
                            const Text('استلام من المحل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              const Text('طريقة الدفع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  border: Border.all(color: const Color(0xFF10B981)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF047857)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'الدفع كاش عند الاستلام (أو تطبيق بنكك عند الوصول)',
                        style: TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: state.isLoading
                      ? null
                      : () async {
                          final ok = await state.createOrder(
                            name: _nameController.text,
                            phone: _phoneController.text,
                            address: _addressController.text,
                            deliveryType: _deliveryType,
                          );
                          if (ok && mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم إرسال طلبك بنجاح! شكراً لثقتكم بـ DMC')),
                            );
                          } else if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('فشل إرسال الطلب، يرجى المحاولة مرة أخرى')),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A47A8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: state.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'تأكيد الطلب (${state.cartTotalSdg.toStringAsFixed(0)} ج.س)',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 5) MY ORDERS SCREEN (Interactive Database Connected)
// -----------------------------------------------------------------------------

class MyOrdersScreen extends StatelessWidget {
  final VoidCallback? onNavigateToCart;
  const MyOrdersScreen({super.key, this.onNavigateToCart});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0A2F6B), Color(0xFF0A47A8)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text('DMC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('قائمة طلباتي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0A2F6B))),
                Text('سجل الطلبات والمتابعة', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            )
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => state.fetchOrders(),
        child: state.orders.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.assignment_outlined, size: 60, color: Color(0xFF94A3B8)),
                    SizedBox(height: 12),
                    Text('لا توجد طلبات مسجلة باسمك حتى الآن', style: TextStyle(color: Color(0xFF64748B))),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: state.orders.length,
                itemBuilder: (context, index) {
                  final order = state.orders[index];
                  final itemsSummary = order.items.isNotEmpty
                      ? order.items.map((i) => "${i.productName} (${i.quantity})").join(' + ')
                      : 'طلب معدات طبية';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE1E9F3)),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
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
                                Text('طلب #DMC-${order.id}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0A2F6B))),
                                const SizedBox(height: 2),
                                Text(
                                  intl_pkg.DateFormat('yyyy/MM/dd - hh:mm a').format(order.createdAt),
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: order.status == 'تم التسليم' ? const Color(0xFFDCFCE7) : const Color(0xFFE0F2FE),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                order.status,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: order.status == 'تم التسليم' ? const Color(0xFF15803D) : const Color(0xFF0369A1),
                                ),
                              ),
                            )
                          ],
                        ),
                        const Divider(height: 20),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontFamily: 'Cairo'),
                            children: [
                              const TextSpan(text: 'الأصناف: ', style: TextStyle(fontWeight: FontWeight.bold)),
                              TextSpan(text: itemsSummary),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('الإجمالي: ${order.totalAmount.toStringAsFixed(0)} ج.س', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                            Text('التوصيل: ${order.areaName}', style: const TextStyle(color: Color(0xFF00B8C4), fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => OfficialInvoiceScreen(order: order)),
                                  );
                                },
                                icon: const Icon(Icons.receipt_long, size: 16),
                                label: const Text('عرض الفاتورة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0A47A8),
                                  side: const BorderSide(color: Color(0xFF0A47A8)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  state.reorderOrder(order);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('تم إعادة إضافة المنتجات إلى السلة')),
                                  );
                                  if (onNavigateToCart != null) {
                                    onNavigateToCart!();
                                  }
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF0F172A),
                                  side: const BorderSide(color: Color(0xFFE1E9F3)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                ),
                                child: const Text('إعادة الطلب', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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

// -----------------------------------------------------------------------------
// 6) OFFICIAL INVOICE SCREEN
// -----------------------------------------------------------------------------

class OfficialInvoiceScreen extends StatelessWidget {
  final CustomerOrder order;
  const OfficialInvoiceScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الفاتورة الرسمية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('جاري مشاركة الفاتورة...')),
              );
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE1E9F3)),
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF0A2F6B), Color(0xFF0A47A8)]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text('DMC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Diala Medical & Chemical Equipment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0A2F6B))),
                    const Text('فاتورة مبيعات رقمية رسمية', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              const Divider(height: 24, thickness: 2, color: Color(0xFF0A2F6B)),

              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F7FC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('اسم العميل: ${order.customerName}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('رقم الفاتورة: #DMC-${order.id}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('التاريخ: ${intl_pkg.DateFormat('yyyy/MM/dd').format(order.createdAt)}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        Text('منطقة التوصيل: ${order.areaName}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Table(
                border: TableBorder.all(color: const Color(0xFFE1E9F3), width: 1),
                children: [
                  TableRow(
                    decoration: const BoxDecoration(color: Color(0xFFF3F7FC)),
                    children: const [
                      Padding(padding: EdgeInsets.all(8), child: Text('الصنف', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Padding(padding: EdgeInsets.all(8), child: Text('العدد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Padding(padding: EdgeInsets.all(8), child: Text('السعر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      Padding(padding: EdgeInsets.all(8), child: Text('الإجمالي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    ],
                  ),
                  ...order.items.map((item) => TableRow(
                        children: [
                          Padding(padding: const EdgeInsets.all(8), child: Text(item.productName, style: const TextStyle(fontSize: 12))),
                          Padding(padding: const EdgeInsets.all(8), child: Text('${item.quantity}', style: const TextStyle(fontSize: 12))),
                          Padding(padding: const EdgeInsets.all(8), child: Text(item.unitPriceSdg.toStringAsFixed(0), style: const TextStyle(fontSize: 12))),
                          Padding(padding: const EdgeInsets.all(8), child: Text(item.totalPriceSdg.toStringAsFixed(0), style: const TextStyle(fontSize: 12))),
                        ],
                      )),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('مجموع المنتجات:', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                  Text('${(order.totalAmount - order.deliveryFee).toStringAsFixed(0)} ج.س', style: const TextStyle(fontSize: 13)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('رسوم التوصيل:', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                  Text('${order.deliveryFee.toStringAsFixed(0)} ج.س', style: const TextStyle(fontSize: 13)),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCE3F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('المبلغ الكلي المطلوب:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0A2F6B), fontSize: 14)),
                    Text(
                      '${order.totalAmount.toStringAsFixed(0)} ج.س',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF0A2F6B)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('جاري تحميل الفاتورة...')),
                        );
                      },
                      icon: const Icon(Icons.picture_as_pdf, size: 18),
                      label: const Text('تحميل الفاتورة', style: TextStyle(fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A47A8),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('مشاركة الفاتورة...')),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0A47A8),
                        side: const BorderSide(color: Color(0xFF0A47A8)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('مشاركة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
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

// -----------------------------------------------------------------------------
// 7) CONTACT US SCREEN (Active URLs launcher)
// -----------------------------------------------------------------------------

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0A2F6B), Color(0xFF0A47A8)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text('DMC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('تواصل معنا', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0A2F6B))),
                Text('خدمة العملاء والدعم', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            )
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // WhatsApp Card
          GestureDetector(
            onTap: () => _launchUrl('https://wa.me/249912345678'),
            child: Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE1E9F3)),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(color: Color(0xFF25D366), shape: BoxShape.circle),
                    child: const Icon(Icons.chat, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('واتساب المبيعات Direct', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                      SizedBox(height: 2),
                      Text('تحدث مباشرة مع مسئول الطلبات', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Phone Card
          GestureDetector(
            onTap: () => _launchUrl('tel:0912345678'),
            child: Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE1E9F3)),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(color: Color(0xFF0A47A8), shape: BoxShape.circle),
                    child: const Icon(Icons.phone_in_talk, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('اتصال هاتفي مباشر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                      SizedBox(height: 2),
                      Text('0912345678 - 0123456789', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Location Card
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE1E9F3)),
              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(color: Color(0xFF00B8C4), shape: BoxShape.circle),
                  child: const Icon(Icons.location_on, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('موقع المحل الرئيسي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))),
                    SizedBox(height: 2),
                    Text('عطبرة - السوق الكبير - شارع المستشفى', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ],
                ),
              ],
            ),
          ),

          // Delivery Areas List
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE1E9F3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('مناطق التوصيل المعتمدة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0A2F6B))),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: state.deliveryAreas.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 2.5,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemBuilder: (context, index) {
                    final area = state.deliveryAreas[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F7FC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(area.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          Text('${area.deliveryFee.toStringAsFixed(0)} ج.س', style: const TextStyle(fontSize: 12, color: Color(0xFF0A47A8), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  },
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 8) NOTIFICATIONS INBOX SCREEN
// -----------------------------------------------------------------------------

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: state.notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.notifications_none, size: 60, color: Color(0xFF94A3B8)),
                  SizedBox(height: 12),
                  Text('لا توجد إشعارات حالية', style: TextStyle(color: Color(0xFF64748B))),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.notifications.length,
              itemBuilder: (context, index) {
                final notif = state.notifications[index];
                return GestureDetector(
                  onTap: () {
                    if (!notif.isRead) {
                      state.markNotificationRead(notif.id);
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: notif.isRead ? Colors.white : const Color(0xFFF0F7FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border(
                        right: BorderSide(color: notif.isRead ? const Color(0xFFCBD5E1) : const Color(0xFF00B8C4), width: 4),
                        top: const BorderSide(color: Color(0xFFE1E9F3)),
                        left: const BorderSide(color: Color(0xFFE1E9F3)),
                        bottom: const BorderSide(color: Color(0xFFE1E9F3)),
                      ),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(notif.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0A2F6B))),
                            Text(
                              intl_pkg.DateFormat('MM/dd hh:mm a').format(notif.createdAt),
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(notif.body, style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), height: 1.4)),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// -----------------------------------------------------------------------------
// 9) PROFILE SCREEN
// -----------------------------------------------------------------------------

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _nameController = TextEditingController(text: state.userFullName);
    _phoneController = TextEditingController(text: state.userPhone);
  }

  Future<void> _pickAvatarImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم اختيار الصورة الشخصية بنجاح')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE1E9F3)),
          ),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 44,
                    backgroundColor: const Color(0xFFDCE3F9),
                    child: Text(
                      state.userFullName.isNotEmpty ? state.userFullName[0] : 'U',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF0A47A8)),
                    ),
                  ),
                  InkWell(
                    onTap: _pickAvatarImage,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0A47A8),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 12),

              Text(
                state.userEmail ?? '',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),

              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'الاسم بالكامل',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'رقم الهاتف',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: state.isLoading
                      ? null
                      : () async {
                          final err = await state.updateProfile(
                            _nameController.text.trim(),
                            _phoneController.text.trim(),
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(err ?? 'تم حفظ البيانات بنجاح')),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A47A8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: state.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('حفظ البيانات', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const Divider(height: 32),

              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(context);
                  state.signOut();
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 10) POLISHED AUTHENTICATION SCREEN
// -----------------------------------------------------------------------------

enum AuthMode { login, signUp, otp, forgotPassword, newPassword }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  AuthMode authMode = AuthMode.login;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();

  String? _nameError;
  String? _phoneError;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  Timer? _resendTimer;
  int _resendSeconds = 60;
  bool _canResend = false;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    setState(() {
      _resendSeconds = 60;
      _canResend = false;
    });
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds > 1) {
        setState(() => _resendSeconds--);
      } else {
        timer.cancel();
        setState(() => _canResend = true);
      }
    });
  }

  void _clearErrors() {
    setState(() {
      _nameError = null;
      _phoneError = null;
      _emailError = null;
      _passwordError = null;
      _confirmPasswordError = null;
    });
  }

  bool _validateSignUp() {
    _clearErrors();
    bool valid = true;
    if (_nameController.text.trim().isEmpty) {
      setState(() => _nameError = 'الاسم الكامل مطلوب');
      valid = false;
    }
    if (_phoneController.text.trim().isEmpty) {
      setState(() => _phoneError = 'رقم الهاتف مطلوب');
      valid = false;
    }
    if (_emailController.text.trim().isEmpty || !_emailController.text.contains('@')) {
      setState(() => _emailError = 'يرجى إدخال بريد إلكتروني صحيح');
      valid = false;
    }
    if (_passwordController.text.length < 6) {
      setState(() => _passwordError = 'كلمة المرور يجب أن تكون 6 أحرف على الأقل');
      valid = false;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _confirmPasswordError = 'كلمتا المرور غير متطابقتين');
      valid = false;
    }
    return valid;
  }

  bool _validateLogin() {
    _clearErrors();
    bool valid = true;
    if (_emailController.text.trim().isEmpty || !_emailController.text.contains('@')) {
      setState(() => _emailError = 'يرجى إدخال بريد إلكتروني صحيح');
      valid = false;
    }
    if (_passwordController.text.isEmpty) {
      setState(() => _passwordError = 'كلمة المرور مطلوبة');
      valid = false;
    }
    return valid;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF0A2F6B), Color(0xFF0A47A8)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text('DMC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  authMode == AuthMode.login
                      ? 'تسجيل الدخول'
                      : authMode == AuthMode.signUp
                          ? 'حساب جديد'
                          : authMode == AuthMode.otp
                              ? 'بعتنا رمز على بريدك'
                              : authMode == AuthMode.newPassword
                                  ? 'كلمة المرور الجديدة'
                                  : 'نسيت كلمة المرور',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0A2F6B)),
                ),
                const SizedBox(height: 4),
                Text(
                  authMode == AuthMode.otp
                      ? 'أدخل الرمز المكون من 6 أرقام المرسل إلى ${_emailController.text}'
                      : 'مرحباً بك في تطبيق DMC Diala للمعدات والمستهلكات الطبية',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // OTP MODE
                if (authMode == AuthMode.otp) ...[
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24, letterSpacing: 8, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: '000000',
                      counterText: '',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _canResend ? 'يمكنك إعادة إرسال الرمز الآن' : 'إعادة الإرسال بعد $_resendSeconds ثانية',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      if (_canResend) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () async {
                            final err = await state.resendOtp(_emailController.text.trim());
                            if (err != null) {
                              _showSnackBar(err);
                            } else {
                              _startResendTimer();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('تم إرسال رمز جديد إلى بريدك')),
                              );
                            }
                          },
                          child: const Text('إعادة إرسال الرمز', style: TextStyle(color: Color(0xFF0A47A8), fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: state.isLoading
                          ? null
                          : () async {
                              final code = _otpController.text.trim();
                              if (code.length < 6) {
                                _showSnackBar('يرجى إدخال الرمز المكون من 6 أرقام');
                                return;
                              }
                              final err = await state.verifyOtp(_emailController.text.trim(), code, "signup");
                              if (err != null) {
                                _showSnackBar(err);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A47A8),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: state.isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('تأكيد والدخول', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ]

                // FORGOT PASSWORD RECOVERY STEP
                else if (authMode == AuthMode.forgotPassword) ...[
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'البريد الإلكتروني',
                      errorText: _emailError,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: state.isLoading
                          ? null
                          : () async {
                              if (_emailController.text.trim().isEmpty) {
                                setState(() => _emailError = 'البريد الإلكتروني مطلوب');
                                return;
                              }
                              final err = await state.recoverPassword(_emailController.text.trim());
                              if (err != null) {
                                _showSnackBar(err);
                              } else {
                                _startResendTimer();
                                setState(() => authMode = AuthMode.newPassword);
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A47A8),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: state.isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('إرسال رمز استعادة كلمة المرور', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => setState(() => authMode = AuthMode.login),
                    child: const Text('العودة لتسجيل الدخول', style: TextStyle(color: Color(0xFF0A47A8), fontWeight: FontWeight.bold)),
                  ),
                ]

                // NEW PASSWORD VERIFY RECOVERY STEP
                else if (authMode == AuthMode.newPassword) ...[
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, letterSpacing: 6, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: 'رمز الـ 6 أرقام',
                      counterText: '',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _newPasswordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور الجديدة',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: state.isLoading
                          ? null
                          : () async {
                              final code = _otpController.text.trim();
                              final newPass = _newPasswordController.text.trim();
                              if (code.length < 6 || newPass.length < 6) {
                                _showSnackBar('يرجى إدخال الرمز المكون من 6 أرقام وكلمة مرور 6+ أحرف');
                                return;
                              }
                              final verifyErr = await state.verifyOtp(_emailController.text.trim(), code, "recovery");
                              if (verifyErr != null) {
                                _showSnackBar(verifyErr);
                                return;
                              }
                              final updateErr = await state.updatePasswordWithSession(newPass);
                              if (updateErr != null) {
                                _showSnackBar(updateErr);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تم تحديث كلمة المرور بنجاح')),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A47A8),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: state.isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('حفظ كلمة المرور والدخول', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                ]

                // LOGIN / SIGNUP MODE
                else ...[
                  if (authMode == AuthMode.signUp) ...[
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'الاسم الكامل',
                        errorText: _nameError,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'رقم الهاتف',
                        errorText: _phoneError,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        prefixIcon: const Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'البريد الإلكتروني',
                      errorText: _emailError,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      errorText: _passwordError,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                  ),

                  if (authMode == AuthMode.signUp) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'تأكيد كلمة المرور',
                        errorText: _confirmPasswordError,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        ),
                      ),
                    ),
                  ],

                  if (authMode == AuthMode.login) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => setState(() => authMode = AuthMode.forgotPassword),
                        child: const Text('نسيت كلمة المرور؟', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      ),
                    ),
                  ] else
                    const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: state.isLoading
                          ? null
                          : () async {
                              if (authMode == AuthMode.signUp) {
                                if (!_validateSignUp()) return;
                                final err = await state.signUp(
                                  _nameController.text.trim(),
                                  _phoneController.text.trim(),
                                  _emailController.text.trim(),
                                  _passwordController.text.trim(),
                                );
                                if (err != null) {
                                  _showSnackBar(err);
                                } else {
                                  _startResendTimer();
                                  setState(() => authMode = AuthMode.otp);
                                }
                              } else {
                                if (!_validateLogin()) return;
                                final err = await state.login(
                                  _emailController.text.trim(),
                                  _passwordController.text.trim(),
                                );
                                if (err == 'EMAIL_NOT_CONFIRMED') {
                                  _startResendTimer();
                                  setState(() => authMode = AuthMode.otp);
                                } else if (err != null) {
                                  _showSnackBar(err);
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A47A8),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: state.isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              authMode == AuthMode.signUp ? 'إنشاء حساب جديد' : 'تسجيل الدخول',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  TextButton(
                    onPressed: () {
                      _clearErrors();
                      setState(() {
                        authMode = authMode == AuthMode.login ? AuthMode.signUp : AuthMode.login;
                      });
                    },
                    child: Text(
                      authMode == AuthMode.signUp ? 'لديك حساب بالفعل؟ سجل الدخول' : 'ليس لديك حساب؟ إنشاء حساب جديد',
                      style: const TextStyle(color: Color(0xFF0A47A8), fontWeight: FontWeight.bold),
                    ),
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}
