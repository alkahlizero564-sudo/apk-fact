import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart' as intl_pkg;
import 'package:image_picker/image_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:fl_chart/fl_chart.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase background init warning: $e");
  }
}

const String kSupabaseUrl = "https://jvjtgzewumfecjdpekna.supabase.co";
const String kSupabaseAnonKey =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp2anRnemV3dW1mZWNqZHBla25hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE2NDYzMzcsImV4cCI6MjEwNzIyMjMzN30.1gck73ek8ErBtcF7xAtFM1TdvNim_1NzFVNej_mptBE";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint("Firebase init warning: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
      child: const DmcAdminApp(),
    ),
  );
}

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
      category: json['category'] ?? 'معدات',
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
  double deliveryFee;

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

class PurchaseRecord {
  final int id;
  final String supplierName;
  final DateTime purchaseDate;
  final double amountUsd;
  final String paymentStatus;
  final String invoiceImageUrl;

  PurchaseRecord({
    required this.id,
    required this.supplierName,
    required this.purchaseDate,
    required this.amountUsd,
    required this.paymentStatus,
    required this.invoiceImageUrl,
  });

  factory PurchaseRecord.fromJson(Map<String, dynamic> json) {
    return PurchaseRecord(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      supplierName: json['supplier_name'] ?? '',
      purchaseDate: json['purchase_date'] != null ? DateTime.parse(json['purchase_date']) : DateTime.now(),
      amountUsd: (json['amount_usd'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: json['payment_status'] ?? 'مدفوع كاش',
      invoiceImageUrl: json['invoice_image_url'] ?? '',
    );
  }
}

class RegisteredCustomer {
  final String id;
  final String fullName;
  final String phone;
  final String email;
  final DateTime createdAt;

  RegisteredCustomer({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.createdAt,
  });

  factory RegisteredCustomer.fromJson(Map<String, dynamic> json) {
    return RegisteredCustomer(
      id: json['id'] ?? '',
      fullName: json['full_name'] ?? 'عميل',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
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

class AppState with ChangeNotifier, WidgetsBindingObserver {
  String? accessToken;
  String? refreshToken;
  String? userId;
  String? userEmail;
  String userFullName = "";
  String userPhone = "";
  bool isAdmin = false;
  bool requiresPin = false;

  int settingsId = 1;
  double usdRate = 600.0;
  List<Product> products = [];
  List<DeliveryArea> deliveryAreas = [];
  List<CustomerOrder> orders = [];
  List<PurchaseRecord> purchases = [];
  List<RegisteredCustomer> customers = [];
  List<AppNotification> notifications = [];

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

      await checkAdminAccess();
      _startSyncTimer();
      await setupPushNotifications();
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

  Future<void> checkAdminAccess() async {
    try {
      final res = await authenticatedRequest(
        'POST',
        "$kSupabaseUrl/rest/v1/rpc/tareg5_claim_admin",
        body: json.encode({}),
      );
      if (res.statusCode == 200) {
        final val = json.decode(res.body);
        if (val == true) {
          isAdmin = true;
          requiresPin = false;
        } else {
          requiresPin = true;
        }
      } else {
        requiresPin = true;
      }
    } catch (e) {
      requiresPin = true;
    }
    notifyListeners();
  }

  Future<bool> verifyAdminPin(String pin) async {
    try {
      final res = await authenticatedRequest(
        'POST',
        "$kSupabaseUrl/rest/v1/rpc/tareg5_claim_admin",
        body: json.encode({"pin": pin}),
      );
      if (res.statusCode == 200) {
        final val = json.decode(res.body);
        if (val == true) {
          isAdmin = true;
          requiresPin = false;
          notifyListeners();
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    accessToken = null;
    refreshToken = null;
    userId = null;
    userEmail = null;
    isAdmin = false;
    requiresPin = false;
    _syncTimer?.cancel();
    notifyListeners();
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
        fetchOrders(),
        fetchPurchases(),
        fetchCustomers(),
        fetchNotifications(),
      ]);
    } catch (e) {
      debugPrint("Data sync error: $e");
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchSettings() async {
    try {
      final res = await authenticatedRequest('GET', "$kSupabaseUrl/rest/v1/tareg5_settings?select=*&limit=1");
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        if (data.isNotEmpty) {
          settingsId = data.first['id'] is int ? data.first['id'] : int.parse(data.first['id'].toString());
          usdRate = (data.first['usd_rate'] as num).toDouble();
        }
      }
    } catch (_) {}
  }

  Future<bool> updateUsdRate(double newRate) async {
    try {
      final nowStr = DateTime.now().toIso8601String();
      final res = await authenticatedRequest(
        'PATCH',
        "$kSupabaseUrl/rest/v1/tareg5_settings?id=eq.$settingsId",
        body: json.encode({"usd_rate": newRate, "updated_at": nowStr}),
      );
      if (res.statusCode == 200 || res.statusCode == 204) {
        usdRate = newRate;
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> fetchDeliveryAreas() async {
    try {
      final res = await authenticatedRequest('GET', "$kSupabaseUrl/rest/v1/tareg5_delivery_areas?select=*&order=id.asc");
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        deliveryAreas = data.map((e) => DeliveryArea.fromJson(e)).toList();
      }
    } catch (_) {}
  }

  Future<bool> updateDeliveryAreaFee(int areaId, double newFee) async {
    try {
      final res = await authenticatedRequest(
        'PATCH',
        "$kSupabaseUrl/rest/v1/tareg5_delivery_areas?id=eq.$areaId",
        body: json.encode({"delivery_fee": newFee}),
      );
      if (res.statusCode == 200 || res.statusCode == 204) {
        await fetchDeliveryAreas();
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<bool> addDeliveryArea(String name, double fee) async {
    try {
      final res = await authenticatedRequest(
        'POST',
        "$kSupabaseUrl/rest/v1/tareg5_delivery_areas",
        body: json.encode({"name": name, "delivery_fee": fee}),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        await fetchDeliveryAreas();
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> fetchProducts() async {
    try {
      final res = await authenticatedRequest('GET', "$kSupabaseUrl/rest/v1/tareg5_products?select=*&order=created_at.desc");
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        products = data.map((e) => Product.fromJson(e)).toList();
      }
    } catch (_) {}
  }

  Future<bool> saveProduct({
    int? id,
    required String name,
    required String category,
    required double priceUsd,
    required int stockQuantity,
    required bool isVisible,
    String imageUrl = '',
  }) async {
    try {
      final payload = {
        "name": name,
        "category": category,
        "price_usd": priceUsd,
        "stock_quantity": stockQuantity,
        "is_visible": isVisible,
        "image_url": imageUrl,
      };

      http.Response res;
      if (id != null) {
        res = await authenticatedRequest(
          'PATCH',
          "$kSupabaseUrl/rest/v1/tareg5_products?id=eq.$id",
          body: json.encode(payload),
        );
      } else {
        res = await authenticatedRequest(
          'POST',
          "$kSupabaseUrl/rest/v1/tareg5_products",
          body: json.encode(payload),
        );
      }

      if (res.statusCode == 200 || res.statusCode == 201 || res.statusCode == 204) {
        await fetchProducts();
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> fetchOrders() async {
    try {
      final res = await authenticatedRequest(
        'GET',
        "$kSupabaseUrl/rest/v1/tareg5_orders?select=*,tareg5_order_items(*)&order=created_at.desc",
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

  Future<bool> updateOrderStatus(CustomerOrder order, String newStatus) async {
    try {
      final res = await authenticatedRequest(
        'PATCH',
        "$kSupabaseUrl/rest/v1/tareg5_orders?id=eq.${order.id}",
        body: json.encode({"status": newStatus}),
      );

      if (res.statusCode == 200 || res.statusCode == 204) {
        await authenticatedRequest(
          'POST',
          "$kSupabaseUrl/rest/v1/tareg5_notifications",
          body: json.encode({
            "to_user": order.customerId,
            "title": "تحديث حالة الطلب #${order.id}",
            "body": "تمت تغيير حالة طلبك إلى ($newStatus). شكرًا لتسوقك من DMC!",
            "data": {"order_id": order.id, "status": newStatus}
          }),
        );

        await fetchOrders();
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> fetchPurchases() async {
    try {
      final res = await authenticatedRequest('GET', "$kSupabaseUrl/rest/v1/tareg5_purchases?select=*&order=created_at.desc");
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        purchases = data.map((e) => PurchaseRecord.fromJson(e)).toList();
      }
    } catch (_) {}
  }

  Future<bool> addPurchase({
    required String supplierName,
    required double amountUsd,
    required String paymentStatus,
    required DateTime purchaseDate,
    String imageUrl = '',
  }) async {
    try {
      final res = await authenticatedRequest(
        'POST',
        "$kSupabaseUrl/rest/v1/tareg5_purchases",
        body: json.encode({
          "supplier_name": supplierName,
          "amount_usd": amountUsd,
          "payment_status": paymentStatus,
          "purchase_date": intl_pkg.DateFormat('yyyy-MM-dd').format(purchaseDate),
          "invoice_image_url": imageUrl,
        }),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        await fetchPurchases();
        notifyListeners();
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> fetchCustomers() async {
    try {
      final res = await authenticatedRequest('GET', "$kSupabaseUrl/rest/v1/tareg5_customers?select=*&order=created_at.desc");
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        customers = data.map((e) => RegisteredCustomer.fromJson(e)).toList();
      }
    } catch (_) {}
  }

  Future<void> fetchNotifications() async {
    if (userId == null) return;
    try {
      final res = await authenticatedRequest(
        'GET',
        "$kSupabaseUrl/rest/v1/tareg5_notifications?or=(to_user.eq.$userId,to_role.eq.admin)&order=created_at.desc",
      );
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        notifications = data.map((e) => AppNotification.fromJson(e)).toList();
      }
    } catch (_) {}
  }

  Future<bool> broadcastPromo(String title, String body) async {
    try {
      final res = await authenticatedRequest(
        'POST',
        "$kSupabaseUrl/rest/v1/tareg5_notifications",
        body: json.encode({
          "to_role": "customer",
          "title": title,
          "body": body,
          "created_by": userId,
        }),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> setupPushNotifications() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token != null && accessToken != null) {
        await authenticatedRequest(
          'POST',
          "$kSupabaseUrl/rest/v1/rpc/tareg5_register_device",
          body: json.encode({"device_token": token, "app_name": "admin"}),
        );
      }
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        refreshAllData(quiet: true);
      });
    } catch (e) {
      debugPrint("Push notification warning: $e");
    }
  }
}

class DmcAdminApp extends StatelessWidget {
  const DmcAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DMC Diala - الإدارة',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar', 'SD'),
      supportedLocales: const [Locale('ar', 'SD'), Locale('en', 'US')],
      themeMode: ThemeMode.system,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A2F6B),
          primary: const Color(0xFF0A47A8),
          secondary: const Color(0xFF00B8C4),
          surface: const Color(0xFFFFFFFF),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF3F7FC),
        fontFamily: 'Cairo',
        fontFamilyFallback: const ['Segoe UI', 'Tahoma', 'sans-serif'],
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A2F6B),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A2F6B),
          primary: const Color(0xFF0A47A8),
          secondary: const Color(0xFF00B8C4),
          brightness: Brightness.dark,
        ),
        fontFamily: 'Cairo',
        fontFamilyFallback: const ['Segoe UI', 'Tahoma', 'sans-serif'],
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox(),
        );
      },
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (state.accessToken == null) {
      return const AuthScreen();
    }

    if (state.requiresPin && !state.isAdmin) {
      return const PinUnlockScreen();
    }

    return const AdminMainShell();
  }
}

enum AuthFlowState { signIn, signUp, otp, forgotPassword, resetPassword }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  AuthFlowState flowState = AuthFlowState.signIn;

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  
  final List<TextEditingController> _otpControllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(4, (_) => FocusNode());

  bool showPassword = false;
  bool showConfirmPassword = false;
  bool loading = false;
  String? errorMsg;

  Timer? _resendTimer;
  int _resendSeconds = 60;
  bool _canResend = false;

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (var c in _otpControllers) {
      c.dispose();
    }
    for (var f in _otpFocusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _resendSeconds = 60;
      _canResend = false;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendSeconds > 0) {
        setState(() => _resendSeconds--);
      } else {
        timer.cancel();
        setState(() => _canResend = true);
      }
    });
  }

  Future<void> submitAuth() async {
    setState(() {
      loading = true;
      errorMsg = null;
    });

    final state = context.read<AppState>();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (flowState == AuthFlowState.signUp) {
      if (_nameCtrl.text.trim().isEmpty) {
        setState(() {
          errorMsg = "يرجى كتابة الاسم الكامل";
          loading = false;
        });
        return;
      }
      if (_phoneCtrl.text.trim().isEmpty) {
        setState(() {
          errorMsg = "يرجى كتابة رقم الهاتف";
          loading = false;
        });
        return;
      }
      if (pass.length < 6) {
        setState(() {
          errorMsg = "كلمة المرور يجب أن تكون 6 أحرف على الأقل";
          loading = false;
        });
        return;
      }
      if (pass != _confirmPassCtrl.text.trim()) {
        setState(() {
          errorMsg = "كلمتا المرور غير متطابقتين";
          loading = false;
        });
        return;
      }
    }

    try {
      if (flowState == AuthFlowState.signUp) {
        final res = await http.post(
          Uri.parse("$kSupabaseUrl/auth/v1/signup"),
          headers: {'apikey': kSupabaseAnonKey, 'Content-Type': 'application/json'},
          body: json.encode({
            "email": email,
            "password": pass,
            "data": {"full_name": _nameCtrl.text.trim(), "phone": _phoneCtrl.text.trim()}
          }),
        );

        if (res.statusCode == 200 || res.statusCode == 201) {
          setState(() {
            flowState = AuthFlowState.otp;
            loading = false;
          });
          _startResendTimer();
          return;
        } else {
          setState(() => errorMsg = state.parseErrorMessage(res, 'signup'));
        }
      } else if (flowState == AuthFlowState.signIn) {
        final res = await http.post(
          Uri.parse("$kSupabaseUrl/auth/v1/token?grant_type=password"),
          headers: {'apikey': kSupabaseAnonKey, 'Content-Type': 'application/json'},
          body: json.encode({"email": email, "password": pass}),
        );

        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('access_token', data['access_token']);
          if (data['refresh_token'] != null) {
            await prefs.setString('refresh_token', data['refresh_token']);
          }
          await prefs.setString('user_id', data['user']['id']);
          await prefs.setString('user_email', data['user']['email']);

          await state.initSession();
        } else {
          final errMsg = state.parseErrorMessage(res, 'login');
          if (errMsg.contains('not confirmed') || res.statusCode == 400) {
            await resendOtp();
            setState(() => flowState = AuthFlowState.otp);
            _startResendTimer();
          } else {
            setState(() => errorMsg = errMsg);
          }
        }
      }
    } catch (e) {
      setState(() => errorMsg = "حدث خطأ في الاتصال بالشبكة");
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> resendOtp() async {
    final state = context.read<AppState>();
    setState(() => errorMsg = null);
    try {
      final res = await http.post(
        Uri.parse("$kSupabaseUrl/auth/v1/resend"),
        headers: {'apikey': kSupabaseAnonKey, 'Content-Type': 'application/json'},
        body: json.encode({"type": "signup", "email": _emailCtrl.text.trim()}),
      );
      if (res.statusCode == 200) {
        _startResendTimer();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إعادة إرسال رمز التأكيد لبريدك')));
      } else {
        setState(() => errorMsg = state.parseErrorMessage(res, 'resend'));
      }
    } catch (_) {
      setState(() => errorMsg = "تعذر إرسال الرمز، يرجى المحاولة لاحقاً");
    }
  }

  Future<void> verifyOtp() async {
    final otpCode = _otpControllers.map((c) => c.text).join();
    if (otpCode.length < 4) {
      setState(() => errorMsg = "يرجى إكمال رمز التأكيد المكون من 4 أرقام");
      return;
    }

    setState(() {
      loading = true;
      errorMsg = null;
    });

    final state = context.read<AppState>();
    final type = flowState == AuthFlowState.resetPassword ? "recovery" : "signup";

    try {
      final res = await http.post(
        Uri.parse("$kSupabaseUrl/auth/v1/verify"),
        headers: {'apikey': kSupabaseAnonKey, 'Content-Type': 'application/json'},
        body: json.encode({
          "type": type,
          "email": _emailCtrl.text.trim(),
          "token": otpCode,
        }),
      );

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (type == "recovery") {
          state.accessToken = data['access_token'];
          setState(() {
            flowState = AuthFlowState.resetPassword;
            loading = false;
          });
          return;
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', data['access_token']);
        if (data['refresh_token'] != null) {
          await prefs.setString('refresh_token', data['refresh_token']);
        }
        await prefs.setString('user_id', data['user']['id']);
        await prefs.setString('user_email', data['user']['email']);

        await state.initSession();
      } else {
        setState(() => errorMsg = state.parseErrorMessage(res, 'verify'));
      }
    } catch (_) {
      setState(() => errorMsg = "فشل التحقق، يرجى إعادة المحاولة");
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> requestRecovery() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => errorMsg = "يرجى كتابة البريد الإلكتروني");
      return;
    }
    setState(() {
      loading = true;
      errorMsg = null;
    });

    final state = context.read<AppState>();
    try {
      final res = await http.post(
        Uri.parse("$kSupabaseUrl/auth/v1/recover"),
        headers: {'apikey': kSupabaseAnonKey, 'Content-Type': 'application/json'},
        body: json.encode({"email": email}),
      );

      if (res.statusCode == 200) {
        setState(() {
          flowState = AuthFlowState.resetPassword;
          loading = false;
        });
        _startResendTimer();
      } else {
        setState(() => errorMsg = state.parseErrorMessage(res, 'recover'));
      }
    } catch (_) {
      setState(() => errorMsg = "فشل طلب استعادة كلمة المرور");
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> updateNewPassword() async {
    final pass = _passCtrl.text.trim();
    if (pass.length < 6) {
      setState(() => errorMsg = "كلمة المرور يجب أن تكون 6 أحرف على الأقل");
      return;
    }
    if (pass != _confirmPassCtrl.text.trim()) {
      setState(() => errorMsg = "كلمتا المرور غير متطابقتين");
      return;
    }

    setState(() {
      loading = true;
      errorMsg = null;
    });

    final state = context.read<AppState>();
    try {
      final res = await state.authenticatedRequest(
        'PUT',
        "$kSupabaseUrl/auth/v1/user",
        body: json.encode({"password": pass}),
      );

      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث كلمة المرور بنجاح!')));
        await state.initSession();
      } else {
        setState(() => errorMsg = state.parseErrorMessage(res, 'update'));
      }
    } catch (_) {
      setState(() => errorMsg = "فشل تغيير كلمة المرور");
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOtp = flowState == AuthFlowState.otp;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 412),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFE1E9F3)),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 16)],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF0A47A8), Color(0xFF00B8C4)]),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3))],
                    ),
                    alignment: Alignment.center,
                    child: const Text('DMC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isOtp ? 'رمز تأكيد الدخول (OTP)' : (flowState == AuthFlowState.signUp ? 'إنشاء حساب مسؤول جديد' : 'تسجيل دخول الإدارة'),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0A2F6B)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isOtp ? 'أدخل الرمز المكون من 4 أرقام الذي تم إرساله لبريدك' : 'نظام إدارة DMC Diala Medical Equipment',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  if (errorMsg != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      width: double.infinity,
                      decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8)),
                      child: Text(errorMsg!, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13), textAlign: TextAlign.center),
                    ),

                  if (isOtp) ...[
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (index) {
                          return Container(
                            width: 48,
                            height: 50,
                            margin: const EdgeInsets.symmetric(horizontal: 5),
                            child: TextField(
                              controller: _otpControllers[index],
                              focusNode: _otpFocusNodes[index],
                              maxLength: 1,
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                              decoration: const InputDecoration(
                                counterText: '',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (value) {
                                if (value.isNotEmpty && index < 3) {
                                  _otpFocusNodes[index + 1].requestFocus();
                                } else if (value.isEmpty && index > 0) {
                                  _otpFocusNodes[index - 1].requestFocus();
                                }
                              },
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: loading ? null : verifyOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A47A8),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 4,
                        ),
                        child: loading ? const CircularProgressIndicator(color: Colors.white) : const Text('تأكيد والدخول للوحة التحكم', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_canResend ? 'لم يصلك الرمز؟' : 'إعادة الإرسال بعد $_resendSeconds ثانية', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        if (_canResend)
                          TextButton(
                            onPressed: resendOtp,
                            child: const Text('إعادة إرسال'),
                          ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => setState(() => flowState = AuthFlowState.signIn),
                      child: const Text('العودة لتسجيل الدخول'),
                    )
                  ]
                  else if (flowState == AuthFlowState.forgotPassword) ...[
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'البريد الإلكتروني', border: OutlineInputBorder(), prefixIcon: Icon(Icons.email)),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: loading ? null : requestRecovery,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A47A8), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        child: loading ? const CircularProgressIndicator(color: Colors.white) : const Text('إرسال رمز الاستعادة'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => setState(() => flowState = AuthFlowState.signIn),
                      child: const Text('إلغاء والعودة'),
                    )
                  ]
                  else if (flowState == AuthFlowState.resetPassword) ...[
                    TextField(
                      controller: _passCtrl,
                      obscureText: !showPassword,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور الجديدة',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => showPassword = !showPassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmPassCtrl,
                      obscureText: !showConfirmPassword,
                      decoration: InputDecoration(
                        labelText: 'تأكيد كلمة المرور',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(showConfirmPassword ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => showConfirmPassword = !showConfirmPassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: loading ? null : updateNewPassword,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A47A8), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                        child: loading ? const CircularProgressIndicator(color: Colors.white) : const Text('حفظ كلمة المرور'),
                      ),
                    ),
                  ]
                  else ...[
                    if (flowState == AuthFlowState.signUp) ...[
                      TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(labelText: 'الاسم الكامل', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'اسم المستخدم / البريد الإلكتروني', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passCtrl,
                      obscureText: !showPassword,
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور الخاصة بالمدير',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => showPassword = !showPassword),
                        ),
                      ),
                    ),
                    if (flowState == AuthFlowState.signUp) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _confirmPassCtrl,
                        obscureText: !showConfirmPassword,
                        decoration: InputDecoration(
                          labelText: 'تأكيد كلمة المرور',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(showConfirmPassword ? Icons.visibility_off : Icons.visibility),
                            onPressed: () => setState(() => showConfirmPassword = !showConfirmPassword),
                          ),
                        ),
                      ),
                    ],
                    if (flowState == AuthFlowState.signIn)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => setState(() => flowState = AuthFlowState.forgotPassword),
                          child: const Text('نسيت كلمة المرور؟', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton(
                        onPressed: loading ? null : submitAuth,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A47A8),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 4,
                        ),
                        child: loading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : Text(flowState == AuthFlowState.signUp ? 'إنشاء حساب مسؤول جديد' : 'المتابعة ورسالة التنشيط', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => setState(() {
                        flowState = flowState == AuthFlowState.signUp ? AuthFlowState.signIn : AuthFlowState.signUp;
                        errorMsg = null;
                      }),
                      child: Text(flowState == AuthFlowState.signUp ? 'لديك حساب بالفعل؟ سجل دخول' : 'ليس لديك حساب؟ التسجيل كمسؤول'),
                    )
                  ]
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PinUnlockScreen extends StatefulWidget {
  const PinUnlockScreen({super.key});

  @override
  State<PinUnlockScreen> createState() => _PinUnlockScreenState();
}

class _PinUnlockScreenState extends State<PinUnlockScreen> {
  final _pinCtrl = TextEditingController();
  bool error = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_person, size: 60, color: Color(0xFF0A2F6B)),
              const SizedBox(height: 16),
              const Text('رمز الإدارة المطلوب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0A2F6B))),
              const SizedBox(height: 8),
              const Text('أدخل رمز الصلاحية الخاص بالإدارة للمتابعة', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 20),
              SizedBox(
                width: 250,
                child: TextField(
                  controller: _pinCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(letterSpacing: 10, fontSize: 24, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    errorText: error ? 'رمز الإدارة غير صحيح' : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  final state = context.read<AppState>();
                  final ok = await state.verifyAdminPin(_pinCtrl.text.trim());
                  if (!ok) {
                    setState(() => error = true);
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A47A8), foregroundColor: Colors.white),
                child: const Text('تأكيد الصلاحية'),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class AdminMainShell extends StatefulWidget {
  const AdminMainShell({super.key});

  @override
  State<AdminMainShell> createState() => _AdminMainShellState();
}

class _AdminMainShellState extends State<AdminMainShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    DashboardScreen(),
    OrdersScreen(),
    ProductsScreen(),
    PurchasesScreen(),
    ReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (state.isLoading && state.orders.isEmpty && state.products.isEmpty) {
      return const LoadingScreen();
    }
    if (!state.isLoading && state.products.isEmpty && state.orders.isEmpty) {
      return const EmptyStateScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: const Color(0xFF0A47A8), borderRadius: BorderRadius.circular(12)),
              child: const Text('DMC', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.white)),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DMC Diala - الإدارة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                Text('لوحة التحكم والمراقبة', style: TextStyle(fontSize: 11, color: Color(0xFF93C5FD), fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_alt_outlined),
            tooltip: 'قائمة الزبائن',
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomersScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.campaign),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PromosScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsInboxScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        indicatorColor: const Color(0xFFDCE3F9),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.shopping_bag), label: 'الطلبات'),
          NavigationDestination(icon: Icon(Icons.inventory_2), label: 'المنتجات'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'المشتريات'),
          NavigationDestination(icon: Icon(Icons.analytics), label: 'التقارير'),
        ],
      ),
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('جاري تحميل البيانات...')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(height: 80, decoration: BoxDecoration(color: const Color(0xFFE1E9F3), borderRadius: BorderRadius.circular(8))),
            const SizedBox(height: 12),
            Container(height: 120, decoration: BoxDecoration(color: const Color(0xFFE1E9F3), borderRadius: BorderRadius.circular(8))),
            const SizedBox(height: 12),
            Container(height: 60, decoration: BoxDecoration(color: const Color(0xFFE1E9F3), borderRadius: BorderRadius.circular(8))),
            const SizedBox(height: 12),
            Expanded(child: Container(decoration: BoxDecoration(color: const Color(0xFFE1E9F3), borderRadius: BorderRadius.circular(8)))),
          ],
        ),
      ),
    );
  }
}

class EmptyStateScreen extends StatelessWidget {
  const EmptyStateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('حالة فارغة')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: const BoxDecoration(
                  color: Color(0xFFE0F7F9),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.inbox, size: 36, color: Color(0xFF00B8C4)),
              ),
              const SizedBox(height: 12),
              const Text('لا توجد سجلات حالياً', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0A2F6B))),
              const SizedBox(height: 6),
              const Text('لم يتم العثور على أي معلومات في هذا القسم بعد.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B)), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => context.read<AppState>().refreshAllData(),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A47A8), foregroundColor: Colors.white),
                child: const Text('تحديث البيانات'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _usdRateCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final state = context.read<AppState>();
    _usdRateCtrl.text = state.usdRate.toStringAsFixed(0);
  }

  void _showAddAreaDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final feeCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إضافة منطقة توصيل جديدة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم المنطقة')),
            TextField(controller: feeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر التوصيل (ج.س)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final fee = double.tryParse(feeCtrl.text) ?? 0.0;
              if (nameCtrl.text.isNotEmpty) {
                await context.read<AppState>().addDeliveryArea(nameCtrl.text.trim(), fee);
                if (mounted) Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A47A8), foregroundColor: Colors.white),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final newOrdersCount = state.orders.where((o) => o.status == 'جديد').length;
    double totalSales = state.orders.fold(0.0, (sum, o) => sum + o.totalAmount);

    return RefreshIndicator(
      onRefresh: () => state.refreshAllData(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF7DD3FC)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFF0A2F6B),
                    foregroundColor: Colors.white,
                    child: Text('$newOrdersCount', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('طلبات جديدة بانتظار التجهيز', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0A2F6B))),
                        Text('تستوجب المراجعة والتأكيد', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () {
                      final shell = context.findAncestorStateOfType<_AdminMainShellState>();
                      if (shell != null) {
                        shell.setState(() {
                          shell._currentIndex = 1;
                        });
                      }
                    },
                    child: const Text('عرض الكل'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE1E9F3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('مبيعات النظام (ج.س)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(intl_pkg.NumberFormat("#,##0").format(totalSales), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0A2F6B))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE1E9F3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('المنتجات في المخزن', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text('${state.products.length} صنف', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0A2F6B))),
                      ],
                    ),
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
                border: Border.all(color: const Color(0xFFE1E9F3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.attach_money, color: Color(0xFF0A47A8)),
                          SizedBox(width: 6),
                          Text('سعر الدولار اليوم (\$1 USD)', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0A2F6B))),
                        ],
                      ),
                      Chip(label: const Text('تأثير مباشر', style: TextStyle(fontSize: 10)), backgroundColor: const Color(0xFFFEF3C7)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('تغيير هذا السعر يؤدي لتحديث أسعار كافة المنتجات بالجنيه السوداني فوراً عند الزبائن.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _usdRateCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            suffixText: 'ج.س',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          final rate = double.tryParse(_usdRateCtrl.text) ?? 600.0;
                          final ok = await state.updateUsdRate(rate);
                          if (ok && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث سعر الدولار والأسعار تلقائياً!')));
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A47A8), foregroundColor: Colors.white),
                        child: const Text('تحديث الأسعار'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE1E9F3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.local_shipping_outlined, color: Color(0xFF0A47A8)),
                          SizedBox(width: 6),
                          Text('مناطق التوصيل وأسعارها', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0A2F6B))),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, color: Color(0xFF0A47A8)),
                        onPressed: () => _showAddAreaDialog(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: state.deliveryAreas.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final area = state.deliveryAreas[index];
                      final ctrl = TextEditingController(text: area.deliveryFee.toStringAsFixed(0));
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFFF3F7FC), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(area.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Row(
                              children: [
                                SizedBox(
                                  width: 90,
                                  height: 36,
                                  child: TextField(
                                    controller: ctrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                                    onSubmitted: (val) {
                                      final newFee = double.tryParse(val) ?? area.deliveryFee;
                                      state.updateDeliveryAreaFee(area.id, newFee);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text('ج.س', style: TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
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

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String selectedFilter = 'الكل';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    final filteredOrders = state.orders.where((o) {
      if (selectedFilter == 'الكل') return true;
      return o.status == selectedFilter;
    }).toList();

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: ['الكل', 'جديد', 'قيد التجهيز', 'في الطريق', 'تم'].map((filter) {
              final isSelected = selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: FilterChip(
                  label: Text(filter),
                  selected: isSelected,
                  selectedColor: const Color(0xFF0A2F6B),
                  labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
                  onSelected: (_) => setState(() => selectedFilter = filter),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => state.fetchOrders(),
            child: filteredOrders.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.grey),
                        SizedBox(height: 8),
                        Text('لا توجد طلبات في هذه الحالة', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredOrders.length,
                    itemBuilder: (context, index) {
                      final order = filteredOrders[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE1E9F3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('طلب #${order.id}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0A2F6B))),
                                _buildStatusBadge(order.status),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('العميل: ${order.customerName} (${order.customerPhone})', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            Text('المنطقة والعنوان: ${order.areaName} - ${order.detailedAddress}', style: const TextStyle(fontSize: 12)),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${intl_pkg.NumberFormat("#,##0").format(order.totalAmount)} ج.س', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0A47A8))),
                                OutlinedButton(
                                  onPressed: () {
                                    Navigator.push(context, MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)));
                                  },
                                  child: const Text('التفاصيل والتجهيز'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFFE0F2FE);
    Color fg = const Color(0xFF0369A1);
    if (status == 'تم') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
    } else if (status == 'جديد') {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFB45309);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(status, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

class OrderDetailScreen extends StatefulWidget {
  final CustomerOrder order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late String currentStatus;

  @override
  void initState() {
    super.initState();
    currentStatus = widget.order.status;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: Text('تفاصيل الطلب #${widget.order.id}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE1E9F3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('العميل: ${widget.order.customerName}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('الهاتف: ${widget.order.customerPhone}', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Text('المنطقة: ${widget.order.areaName}'),
                  Text('العنوان المفصل: ${widget.order.detailedAddress}'),
                  Text('طريقة الدفع: ${widget.order.deliveryType}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE1E9F3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('الأصناف المطلوبة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const Divider(),
                  ...widget.order.items.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${item.productName} (x${item.quantity})'),
                            Text('${intl_pkg.NumberFormat("#,##0").format(item.totalPriceSdg)} ج.س'),
                          ],
                        ),
                      )),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('أجور التوصيل:'),
                      Text('${intl_pkg.NumberFormat("#,##0").format(widget.order.deliveryFee)} ج.س'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('الإجمالي الكلي:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('${intl_pkg.NumberFormat("#,##0").format(widget.order.totalAmount)} ج.س', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0A47A8), fontSize: 16)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE1E9F3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('تغيير حالة الطلب في قاعدة البيانات', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: currentStatus,
                    items: ['جديد', 'قيد التجهيز', 'في الطريق', 'تم'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setState(() => currentStatus = v!),
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: () async {
                        final ok = await state.updateOrderStatus(widget.order, currentStatus);
                        if (ok && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحديث حالة الطلب وإرسال إشعار للزبون!')));
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A47A8), foregroundColor: Colors.white),
                      child: const Text('تحديث الحالة وتنبيه العميل'),
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

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String selectedCat = 'الكل';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    final filteredProducts = state.products.where((p) {
      if (selectedCat == 'الكل') return true;
      if (selectedCat == 'مخفي') return !p.isVisible;
      return p.category == selectedCat;
    }).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductFormScreen()));
        },
        backgroundColor: const Color(0xFF00B8C4),
        foregroundColor: const Color(0xFF002D32),
        icon: const Icon(Icons.add),
        label: const Text('صنف جديد'),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: ['الكل', 'معدات', 'مستهلكات', 'مختبر', 'مخفي'].map((cat) {
                final isSel = selectedCat == cat;
                return Padding(
                  padding: const EdgeInsets.only(left: 6.0),
                  child: ChoiceChip(
                    label: Text(cat),
                    selected: isSel,
                    onSelected: (_) => setState(() => selectedCat = cat),
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => state.fetchProducts(),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredProducts.length,
                itemBuilder: (context, index) {
                  final p = filteredProducts[index];
                  final priceSdg = p.calculatePriceSdg(state.usdRate);
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
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(color: const Color(0xFFF3F7FC), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.medication, color: Color(0xFF0A47A8)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0A2F6B))),
                              Text('\$${p.priceUsd.toStringAsFixed(2)} • الكمية: ${p.stockQuantity}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              Text('${intl_pkg.NumberFormat("#,##0").format(priceSdg)} ج.س', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0A47A8))),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Chip(
                              label: Text(p.isVisible ? 'ظاهر' : 'مخفي', style: TextStyle(fontSize: 10, color: p.isVisible ? Colors.green : Colors.red)),
                              backgroundColor: p.isVisible ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => ProductFormScreen(product: p)));
                              },
                            ),
                          ],
                        ),
                      ],
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

class ProductFormScreen extends StatefulWidget {
  final Product? product;
  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _nameCtrl = TextEditingController();
  final _priceUsdCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  String category = 'معدات';
  bool isVisible = true;
  String imageUrl = '';

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _nameCtrl.text = widget.product!.name;
      _priceUsdCtrl.text = widget.product!.priceUsd.toString();
      _stockCtrl.text = widget.product!.stockQuantity.toString();
      category = widget.product!.category;
      isVisible = widget.product!.isVisible;
      imageUrl = widget.product!.imageUrl;
    }
  }

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => imageUrl = picked.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: Text(widget.product != null ? 'تعديل منتج' : 'إضافة منتج جديد')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE1E9F3))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'اسم المنتج الأصلي', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                items: ['معدات', 'مستهلكات', 'مختبر'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => category = v!),
                decoration: const InputDecoration(labelText: 'القسم الرئيسي', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextField(controller: _priceUsdCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر بالدولار (\$)', border: OutlineInputBorder()))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: _stockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية المتوفرة', border: OutlineInputBorder()))),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('حالة الظهور في متجر الزبائن'),
                value: isVisible,
                onChanged: (v) => setState(() => isVisible = v),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: pickImage,
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                  child: imageUrl.isNotEmpty
                      ? Image.file(File(imageUrl), fit: BoxFit.cover)
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [Icon(Icons.add_a_photo, color: Colors.grey, size: 32), SizedBox(height: 6), Text('اضغط لرفع صورة المنتج', style: TextStyle(fontSize: 12, color: Colors.grey))],
                        ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    final name = _nameCtrl.text.trim();
                    final price = double.tryParse(_priceUsdCtrl.text) ?? 0.0;
                    final stock = int.tryParse(_stockCtrl.text) ?? 0;

                    if (name.isNotEmpty) {
                      await state.saveProduct(
                        id: widget.product?.id,
                        name: name,
                        category: category,
                        priceUsd: price,
                        stockQuantity: stock,
                        isVisible: isVisible,
                        imageUrl: imageUrl,
                      );
                      if (mounted) Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A47A8), foregroundColor: Colors.white),
                  child: const Text('حفظ المنتج في Supabase'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PurchasesScreen extends StatelessWidget {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const AddPurchaseScreen()));
        },
        backgroundColor: const Color(0xFF00B8C4),
        foregroundColor: const Color(0xFF002D32),
        icon: const Icon(Icons.note_add),
        label: const Text('فاتورة مورد'),
      ),
      body: RefreshIndicator(
        onRefresh: () => state.fetchPurchases(),
        child: state.purchases.isEmpty
            ? const Center(child: Text('لا توجد فواتير مشتريات مسجلة'))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.purchases.length,
                itemBuilder: (context, index) {
                  final p = state.purchases[index];
                  final isPaid = p.paymentStatus == 'مدفوع كاش';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE1E9F3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(p.supplierName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0A2F6B))),
                            Chip(
                              label: Text(p.paymentStatus, style: TextStyle(fontSize: 10, color: isPaid ? Colors.green : Colors.red)),
                              backgroundColor: isPaid ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                            ),
                          ],
                        ),
                        Text('التاريخ: ${intl_pkg.DateFormat('yyyy-MM-dd').format(p.purchaseDate)} • المبلغ: \$${p.amountUsd.toStringAsFixed(2)} USD', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        if (p.invoiceImageUrl.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          const Row(
                            children: [
                              Icon(Icons.image, size: 14, color: Color(0xFF00B8C4)),
                              SizedBox(width: 4),
                              Text('مرفق صورة الفاتورة', style: TextStyle(fontSize: 11, color: Color(0xFF00B8C4), fontWeight: FontWeight.bold)),
                            ],
                          )
                        ]
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class AddPurchaseScreen extends StatefulWidget {
  const AddPurchaseScreen({super.key});

  @override
  State<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends State<AddPurchaseScreen> {
  final _supplierCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String paymentStatus = 'مدفوع كاش';
  DateTime selectedDate = DateTime.now();
  String invoiceImageUrl = '';

  Future<void> pickInvoiceImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => invoiceImageUrl = picked.path);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != selectedDate) {
      setState(() => selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('إضافة فاتورة مشتريات مورد')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE1E9F3))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: _supplierCtrl, decoration: const InputDecoration(labelText: 'اسم المورد / الشركة *', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(controller: _amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ (\$ USD) *', border: OutlineInputBorder())),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'تاريخ الفاتورة', border: OutlineInputBorder()),
                        child: Text(intl_pkg.DateFormat('yyyy-MM-dd').format(selectedDate), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: paymentStatus,
                items: ['مدفوع كاش', 'آجل (متبقي)'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => paymentStatus = v!),
                decoration: const InputDecoration(labelText: 'حالة الدفع', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              const Text('صورة فاتورة المورد (اختياري)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: pickInvoiceImage,
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF9F6),
                    border: Border.all(color: const Color(0xFFE1E9F3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: invoiceImageUrl.isNotEmpty
                      ? Image.file(File(invoiceImageUrl), fit: BoxFit.cover)
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt, color: Color(0xFF0A47A8), size: 32),
                            SizedBox(height: 6),
                            Text('التقاط أو رفع صورة الفاتورة', style: TextStyle(fontSize: 12, color: Color(0xFF0A2F6B), fontWeight: FontWeight.bold)),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    final sup = _supplierCtrl.text.trim();
                    final amt = double.tryParse(_amountCtrl.text) ?? 0.0;
                    if (sup.isNotEmpty) {
                      await state.addPurchase(
                        supplierName: sup,
                        amountUsd: amt,
                        paymentStatus: paymentStatus,
                        purchaseDate: selectedDate,
                        imageUrl: invoiceImageUrl,
                      );
                      if (mounted) Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A47A8), foregroundColor: Colors.white),
                  child: const Text('تأكيد وحفظ الفاتورة'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    final totalSales = state.orders.fold(0.0, (sum, o) => sum + o.totalAmount);
    final totalDeliveryFees = state.orders.fold(0.0, (sum, o) => sum + o.deliveryFee);
    final totalPurchasesUsd = state.purchases.fold(0.0, (sum, p) => sum + p.amountUsd);
    final totalPurchasesSdg = totalPurchasesUsd * state.usdRate;
    final netProfit = totalSales - totalPurchasesSdg - totalDeliveryFees;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE1E9F3))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('مبيعات النظام (ج.س)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0A2F6B))),
                    Chip(label: const Text('حسابات حية', style: TextStyle(fontSize: 10, color: Colors.blue)), backgroundColor: const Color(0xFFE0F2FE)),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 160,
                  child: BarChart(
                    BarChartData(
                      borderData: FlBorderData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      barGroups: [
                        BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: (totalSales * 0.2) / 1000, color: const Color(0xFFDCE3F9))]),
                        BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: (totalSales * 0.3) / 1000, color: const Color(0xFFDCE3F9))]),
                        BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: (totalSales * 0.25) / 1000, color: const Color(0xFFDCE3F9))]),
                        BarChartGroupData(x: 4, barRods: [BarChartRodData(toY: (totalSales * 0.4) / 1000, color: const Color(0xFF0A47A8))]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE1E9F3))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ملخص الأرباح والمصروفات التلقائي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0A2F6B))),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('إجمالي المبيعات المحصلة:'),
                    Text('+ ${intl_pkg.NumberFormat("#,##0").format(totalSales)} ج.س', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('مشتريات الموردين (بالجنيه):'),
                    Text('- ${intl_pkg.NumberFormat("#,##0").format(totalPurchasesSdg)} ج.س', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('رسوم المناديب والتوصيل:'),
                    Text('- ${intl_pkg.NumberFormat("#,##0").format(totalDeliveryFees)} ج.س', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('صافي الأرباح التقديري:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('${intl_pkg.NumberFormat("#,##0").format(netProfit)} ج.س', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0A2F6B))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('قائمة الزبائن المسجلين'),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Chip(
                label: Text('${state.customers.length} عميل', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                backgroundColor: const Color(0xFFDCE3F9),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => state.fetchCustomers(),
        child: state.customers.isEmpty
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people_outline, size: 64, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('لا توجد سجلات لزبائن حالياً', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: state.customers.length,
                itemBuilder: (context, index) {
                  final cust = state.customers[index];
                  final initial = cust.fullName.isNotEmpty ? cust.fullName[0] : 'أ';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE1E9F3)),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFFDCE3F9),
                          foregroundColor: const Color(0xFF0A2F6B),
                          child: Text(initial, style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(cust.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0A2F6B))),
                              Text('${cust.phone} • ${cust.email}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                        const Chip(
                          label: Text('نشط', style: TextStyle(fontSize: 10, color: Colors.green)),
                          backgroundColor: Color(0xFFDCFCE7),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class PromosScreen extends StatefulWidget {
  const PromosScreen({super.key});

  @override
  State<PromosScreen> createState() => _PromosScreenState();
}

class _PromosScreenState extends State<PromosScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('العروض والأسعار والإعلانات')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE1E9F3))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('إرسال عرض أو تنبيه جديد لكافة الزبائن', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 12),
              TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'عنوان الإعلان', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: _bodyCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'تفاصيل العرض والرسالة', border: OutlineInputBorder())),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (_titleCtrl.text.isNotEmpty && _bodyCtrl.text.isNotEmpty) {
                      final ok = await state.broadcastPromo(_titleCtrl.text.trim(), _bodyCtrl.text.trim());
                      if (ok && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إرسال العرض لجميع الزبائن بنجاح!')));
                        Navigator.pop(context);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00B8C4), foregroundColor: const Color(0xFF002D32)),
                  icon: const Icon(Icons.send),
                  label: const Text('إرسال العرض كـ Notification'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NotificationsInboxScreen extends StatelessWidget {
  const NotificationsInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('صندوق إشعارات الإدارة')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: state.notifications.length,
        itemBuilder: (context, index) {
          final n = state.notifications[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE1E9F3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0A2F6B))),
                const SizedBox(height: 2),
                Text(n.body, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('إعدادات نظام DMC')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE1E9F3))),
          child: Column(
            children: [
              const ListTile(
                leading: CircleAvatar(backgroundColor: Color(0xFF0A47A8), child: Text('DMC', style: TextStyle(color: Colors.white, fontSize: 12))),
                title: Text('Diala Medical & Chemical'),
                subtitle: Text('معدات ومستهلكات طبية - عطبرة'),
              ),
              const Divider(),
              const ListTile(
                leading: Icon(Icons.cloud_done, color: Colors.green),
                title: Text('ربط قاعدة البيانات Supabase'),
                trailing: Text('متصل', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => state.signOut(),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                  child: const Text('تسجيل الخروج من الإدارة'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
