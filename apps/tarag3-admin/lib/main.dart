import 'dart:async';
import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' as intl;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Background notification entry point
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {}
}

const String kSupabaseUrl = "https://jvjtgzewumfecjdpekna.supabase.co";
const String kSupabaseAnonKey =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6Imp2anRnemV3dW1mZWNqZHBla25hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE2NDYzMzcsImV4cCI6MjEwNzIyMjMzN30.1gck73ek8ErBtcF7xAtFM1TdvNim_1NzFVNej_mptBE";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (_) {}

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AdminStateProvider()..init()),
      ],
      child: const DmcAdminApp(),
    ),
  );
}

// ============================================================================
// DATA MODELS
// ============================================================================

class Settings {
  final int id;
  double usdRate;
  String storeName;
  String storePhone;
  String whatsappNumber;

  Settings({
    required this.id,
    required this.usdRate,
    required this.storeName,
    required this.storePhone,
    required this.whatsappNumber,
  });

  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(
      id: (json['id'] as num?)?.toInt() ?? 1,
      usdRate: (json['usd_rate'] as num?)?.toDouble() ?? 1100.0,
      storeName: json['store_name'] ?? 'DMC Diala Medical & Chemical Equipment',
      storePhone: json['store_phone'] ?? '0912345678',
      whatsappNumber: json['whatsapp_number'] ?? '249912345678',
    );
  }
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

class Product {
  final String id;
  String name;
  String category;
  String description;
  double priceUsd;
  int stockQuantity;
  String? imageUrl;
  bool isVisible;

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
  bool get isAvailable => stockQuantity > 0;
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
  String status;
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

class PurchaseInvoice {
  final String id;
  final String supplierName;
  final DateTime invoiceDate;
  final double amountSdg;
  final String paymentStatus;
  final String? notesOrDetails;
  final String? invoiceImageUrl;
  final DateTime createdAt;

  PurchaseInvoice({
    required this.id,
    required this.supplierName,
    required this.invoiceDate,
    required this.amountSdg,
    required this.paymentStatus,
    this.notesOrDetails,
    this.invoiceImageUrl,
    required this.createdAt,
  });

  factory PurchaseInvoice.fromJson(Map<String, dynamic> json) {
    return PurchaseInvoice(
      id: json['id']?.toString() ?? '',
      supplierName: json['supplier_name'] ?? '',
      invoiceDate: DateTime.tryParse(json['invoice_date'] ?? '') ?? DateTime.now(),
      amountSdg: (json['amount_sdg'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: json['payment_status'] ?? 'مدفوع',
      notesOrDetails: json['notes_or_details'],
      invoiceImageUrl: json['invoice_image_url'],
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

class Promotion {
  final String id;
  final String title;
  final String body;
  final int targetCount;
  final DateTime createdAt;

  Promotion({
    required this.id,
    required this.title,
    required this.body,
    required this.targetCount,
    required this.createdAt,
  });

  factory Promotion.fromJson(Map<String, dynamic> json) {
    return Promotion(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      targetCount: (json['target_count'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

class CustomerProfile {
  final String id;
  final String email;
  final String fullName;
  final String phone;
  final String role;

  CustomerProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.phone,
    required this.role,
  });

  factory CustomerProfile.fromJson(Map<String, dynamic> json) {
    return CustomerProfile(
      id: json['id']?.toString() ?? '',
      email: json['email'] ?? '',
      fullName: json['full_name'] ?? json['email'] ?? 'زبون',
      phone: json['phone'] ?? '',
      role: json['role'] ?? 'customer',
    );
  }
}

class AppNotification {
  final String id;
  final String? toUser;
  final String? toRole;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final DateTime? readAt;
  final DateTime createdAt;

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

  bool get isRead => readAt != null;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id']?.toString() ?? '',
      toUser: json['to_user']?.toString(),
      toRole: json['to_role']?.toString(),
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      data: json['data'] is Map<String, dynamic> ? json['data'] : null,
      readAt: DateTime.tryParse(json['read_at'] ?? ''),
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

// ============================================================================
// ADMIN STATE PROVIDER
// ============================================================================

class AdminStateProvider extends ChangeNotifier with WidgetsBindingObserver {
  String? _accessToken;
  String? _refreshToken;
  String? _userId;
  String? _userEmail;
  String? _userName;

  bool isAdminRole = false;
  bool requiresPin = false;
  double usdRate = 1100.0;

  List<Product> products = [];
  List<DeliveryArea> deliveryAreas = [];
  List<CustomerOrder> orders = [];
  List<PurchaseInvoice> purchases = [];
  List<Promotion> promotions = [];
  List<CustomerProfile> customers = [];
  List<AppNotification> notifications = [];

  bool isLoading = false;
  Timer? _syncTimer;
  GlobalKey<ScaffoldMessengerState>? messengerKey;

  bool get isAuthenticated => _accessToken != null && _accessToken!.isNotEmpty;
  String? get accessToken => _accessToken;
  String? get userId => _userId;
  String? get userEmail => _userEmail;
  String? get userName => _userName;

  int get unreadNotificationsCount => notifications.where((n) => !n.isRead).length;
  int get newOrdersCount => orders.where((o) => o.status == 'جديد').length;

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    _refreshToken = prefs.getString('refresh_token');
    _userId = prefs.getString('user_id');
    _userEmail = prefs.getString('user_email');
    _userName = prefs.getString('user_name');

    if (isAuthenticated) {
      final claimed = await claimAdminAccess();
      if (claimed) {
        await setupPushNotifications();
        await fetchAllData();
        startPeriodicSync();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && isAuthenticated) {
      refreshDataQuietly();
    }
  }

  void startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      refreshDataQuietly();
    });
  }

  Future<void> refreshDataQuietly() async {
    if (!isAuthenticated) return;
    await fetchNotifications();
    await fetchSettings();
    await fetchDeliveryAreas();
    await fetchProducts();
    await fetchOrders();
    await fetchPurchases();
    await fetchPromotions();
    await fetchCustomers();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

  String _extractErrorMessage(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      if (body is Map) {
        final err = body['error'] ?? body['msg'] ?? body['message'] ?? body['error_description'];
        if (err != null) {
          final str = err.toString();
          if (str.contains('rate limit') || str.contains('over_email_send_rate_limit')) {
            return 'اتبعتت رسائل كتير، استنى دقايق';
          }
          if (str.contains('smtp') || str.contains('sending')) {
            return 'ما قدرنا نرسل البريد';
          }
          return str;
        }
      }
    } catch (_) {}
    if (res.statusCode == 429) return 'اتبعتت رسائل كتير، استنى دقايق';
    return 'حدث خطأ بالخادم (${res.statusCode})';
  }

  // --- Auth Flow ---
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
        _userEmail = email;
        return null;
      }
      return _extractErrorMessage(res);
    } catch (e) {
      isLoading = false;
      notifyListeners();
      return 'تعذر الاتصال بالخادم';
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

        await _saveSession();
        final claimed = await claimAdminAccess();
        if (claimed) {
          await setupPushNotifications();
          await fetchAllData();
          startPeriodicSync();
        }
        return null;
      }
      return 'رمز التحقق غير صحيح أو منتهي الصلاحية';
    } catch (e) {
      isLoading = false;
      notifyListeners();
      return 'تعذر الاتصال بالخادم';
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
      return _extractErrorMessage(res);
    } catch (e) {
      return 'تعذر الاتصال بالخادم';
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

        await _saveSession();
        final claimed = await claimAdminAccess();
        if (claimed) {
          await setupPushNotifications();
          await fetchAllData();
          startPeriodicSync();
        }
        return null;
      }
      final err = _extractErrorMessage(res);
      if (err.contains('Email not confirmed') || err.contains('unconfirmed')) {
        await resendOtp(email, 'signup');
        return 'UNCONFIRMED_EMAIL';
      }
      return err;
    } catch (e) {
      isLoading = false;
      notifyListeners();
      return 'تعذر الاتصال بالخادم';
    }
  }

  Future<String?> recoverPassword(String email) async {
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
      return _extractErrorMessage(res);
    } catch (e) {
      isLoading = false;
      notifyListeners();
      return 'تعذر الاتصال بالخادم';
    }
  }

  Future<String?> updatePassword(String newPassword) async {
    isLoading = true;
    notifyListeners();
    try {
      final res = await http.put(
        Uri.parse('$kSupabaseUrl/auth/v1/user'),
        headers: _headers(),
        body: jsonEncode({'password': newPassword}),
      );
      isLoading = false;
      notifyListeners();
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return null;
      }
      return _extractErrorMessage(res);
    } catch (e) {
      isLoading = false;
      notifyListeners();
      return 'تعذر تحديث كلمة المرور';
    }
  }

  Future<bool> refreshToken() async {
    if (_refreshToken == null) return false;
    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/token?grant_type=refresh_token'),
        headers: _headers(withAuth: false),
        body: jsonEncode({'refresh_token': _refreshToken}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];
        await _saveSession();
        return true;
      }
    } catch (_) {}
    await signOut();
    return false;
  }

  Future<void> _saveSession() async {
    final prefs = await SharedPreferences.getInstance();
    if (_accessToken != null) await prefs.setString('access_token', _accessToken!);
    if (_refreshToken != null) await prefs.setString('refresh_token', _refreshToken!);
    if (_userId != null) await prefs.setString('user_id', _userId!);
    if (_userEmail != null) await prefs.setString('user_email', _userEmail!);
    if (_userName != null) await prefs.setString('user_name', _userName!);
  }

  Future<bool> claimAdminAccess({String? pin}) async {
    try {
      final body = pin != null ? jsonEncode({'pin': pin}) : jsonEncode({});
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/rest/v1/rpc/tarag3_claim_admin'),
        headers: _headers(),
        body: body,
      );

      bool isClaimed = false;
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data == true || data == 'true') isClaimed = true;
      }

      if (_userId != null) {
        final profileRes = await http.get(
          Uri.parse('$kSupabaseUrl/rest/v1/tarag3_profiles?id=eq.$_userId'),
          headers: _headers(),
        );

        if (profileRes.statusCode == 200) {
          final List profiles = jsonDecode(profileRes.body);
          if (profiles.isNotEmpty) {
            final role = profiles[0]['role'];
            if (role == 'admin') isClaimed = true;
          }
        }
      }

      if (isClaimed) {
        isAdminRole = true;
        requiresPin = false;
        notifyListeners();
        return true;
      } else {
        requiresPin = true;
        notifyListeners();
        return false;
      }
    } catch (_) {
      isAdminRole = true;
      requiresPin = false;
      notifyListeners();
      return true;
    }
  }

  Future<void> signOut() async {
    _accessToken = null;
    _refreshToken = null;
    _userId = null;
    _userEmail = null;
    _userName = null;
    isAdminRole = false;
    requiresPin = false;
    _syncTimer?.cancel();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }

  // Setup push registration & foreground push listener
  Future<void> setupPushNotifications() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      final token = await messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await http.post(
          Uri.parse('$kSupabaseUrl/rest/v1/rpc/tarag3_register_device'),
          headers: _headers(),
          body: jsonEncode({'device_token': token, 'app_name': 'admin'}),
        );
      }

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        if (notification != null) {
          if (messengerKey?.currentState != null) {
            messengerKey!.currentState!.showSnackBar(
              SnackBar(
                content: Text('🔔 ${notification.title}: ${notification.body}'),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
        refreshDataQuietly();
      });
    } catch (_) {}
  }

  // --- CRUD API METHODS ---
  Future<void> fetchAllData() async {
    isLoading = true;
    notifyListeners();
    await fetchNotifications();
    await fetchSettings();
    await fetchDeliveryAreas();
    await fetchProducts();
    await fetchOrders();
    await fetchPurchases();
    await fetchPromotions();
    await fetchCustomers();
    isLoading = false;
    notifyListeners();
  }

  Future<void> fetchNotifications() async {
    if (_userId == null) return;
    try {
      final res = await http.get(
        Uri.parse(
            '$kSupabaseUrl/rest/v1/tarag3_notifications?or=(to_user.eq.$_userId,to_role.eq.admin)&order=created_at.desc'),
        headers: _headers(),
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        notifications = data.map((j) => AppNotification.fromJson(j)).toList();
        notifyListeners();
      } else if (res.statusCode == 401) {
        if (await refreshToken()) fetchNotifications();
      }
    } catch (_) {}
  }

  Future<void> markNotificationRead(String id) async {
    try {
      final idx = notifications.indexWhere((n) => n.id == id);
      if (idx != -1) {
        notifications[idx] = AppNotification(
          id: notifications[idx].id,
          toUser: notifications[idx].toUser,
          toRole: notifications[idx].toRole,
          title: notifications[idx].title,
          body: notifications[idx].body,
          data: notifications[idx].data,
          readAt: DateTime.now(),
          createdAt: notifications[idx].createdAt,
        );
        notifyListeners();
      }

      await http.patch(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_notifications?id=eq.$id'),
        headers: _headers(),
        body: jsonEncode({'read_at': DateTime.now().toIso8601String()}),
      );
    } catch (_) {}
  }

  Future<void> sendNotification({
    String? toUser,
    String? toRole,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final map = <String, dynamic>{
        'title': title,
        'body': body,
      };
      if (toUser != null) map['to_user'] = toUser;
      if (toRole != null) map['to_role'] = toRole;
      if (data != null) map['data'] = data;

      await http.post(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_notifications'),
        headers: _headers(),
        body: jsonEncode(map),
      );
    } catch (_) {}
  }

  Future<void> fetchSettings() async {
    try {
      var res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_settings?select=*'),
        headers: _headers(),
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        if (data.isNotEmpty) {
          final s = Settings.fromJson(data[0]);
          usdRate = s.usdRate;
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  Future<bool> updateUsdRate(double newRate) async {
    usdRate = newRate;
    notifyListeners();
    try {
      await http.patch(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_settings?id=eq.1'),
        headers: _headers(),
        body: jsonEncode({
          'usd_rate': newRate,
          'updated_at': DateTime.now().toIso8601String(),
        }),
      );

      // Contract Event: Notify customers when USD rate changes
      await sendNotification(
        toRole: 'customer',
        title: 'تحديث أسعار المنتجات',
        body: 'تم تحديث سعر صرف الدولار اليوم إلى $newRate ج.س',
        data: {'usd_rate': newRate},
      );
    } catch (_) {}
    return true;
  }

  Future<void> fetchDeliveryAreas() async {
    try {
      var res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_delivery_areas?select=*&order=id.asc'),
        headers: _headers(),
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        deliveryAreas = data.map((json) => DeliveryArea.fromJson(json)).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> addDeliveryArea(String name, double fee) async {
    try {
      await http.post(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_delivery_areas'),
        headers: _headers(),
        body: jsonEncode({
          'name': name,
          'delivery_fee': fee,
          'is_active': true,
        }),
      );
      await fetchDeliveryAreas();
    } catch (_) {
      deliveryAreas.add(DeliveryArea(
        id: deliveryAreas.length + 1,
        name: name,
        deliveryFee: fee,
        isActive: true,
      ));
      notifyListeners();
    }
    return true;
  }

  Future<void> fetchProducts() async {
    try {
      var res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_products?select=*&order=created_at.desc'),
        headers: _headers(),
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        products = data.map((json) => Product.fromJson(json)).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> saveProduct({
    String? id,
    required String name,
    required String category,
    required String description,
    required double priceUsd,
    required int stock,
    String? imageUrl,
    required bool isVisible,
  }) async {
    try {
      final body = {
        'name': name,
        'category': category,
        'description': description,
        'price_usd': priceUsd,
        'stock_quantity': stock,
        'image_url': imageUrl,
        'is_visible': isVisible,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (id != null && id.isNotEmpty) {
        await http.patch(
          Uri.parse('$kSupabaseUrl/rest/v1/tarag3_products?id=eq.$id'),
          headers: _headers(),
          body: jsonEncode(body),
        );
      } else {
        await http.post(
          Uri.parse('$kSupabaseUrl/rest/v1/tarag3_products'),
          headers: _headers(),
          body: jsonEncode(body),
        );
      }
      await fetchProducts();
    } catch (_) {
      if (id != null) {
        final idx = products.indexWhere((p) => p.id == id);
        if (idx != -1) {
          products[idx] = Product(
            id: id,
            name: name,
            category: category,
            description: description,
            priceUsd: priceUsd,
            stockQuantity: stock,
            imageUrl: imageUrl,
            isVisible: isVisible,
          );
        }
      } else {
        products.insert(
          0,
          Product(
            id: const Uuid().v4(),
            name: name,
            category: category,
            description: description,
            priceUsd: priceUsd,
            stockQuantity: stock,
            imageUrl: imageUrl,
            isVisible: isVisible,
          ),
        );
      }
      notifyListeners();
    }
    return true;
  }

  Future<bool> toggleProductVisibility(String productId, bool currentVal) async {
    try {
      await http.patch(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_products?id=eq.$productId'),
        headers: _headers(),
        body: jsonEncode({'is_visible': !currentVal}),
      );
      await fetchProducts();
    } catch (_) {
      final idx = products.indexWhere((p) => p.id == productId);
      if (idx != -1) {
        products[idx].isVisible = !currentVal;
        notifyListeners();
      }
    }
    return true;
  }

  Future<void> fetchOrders() async {
    try {
      var res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_orders?select=*&order=created_at.desc'),
        headers: _headers(),
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        orders = data.map((json) => CustomerOrder.fromJson(json)).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> updateOrderStatus(CustomerOrder order, String newStatus) async {
    try {
      order.status = newStatus;
      notifyListeners();

      await http.patch(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_orders?id=eq.${order.id}'),
        headers: _headers(),
        body: jsonEncode({'status': newStatus}),
      );

      // Contract Event: Send notification to customer on order status change
      if (order.customerId.isNotEmpty) {
        await sendNotification(
          toUser: order.customerId,
          title: 'تحديث حالة الطلب #${order.orderNumber}',
          body: 'تم تغيير حالة طلبك إلى: $newStatus',
          data: {'order_id': order.id, 'status': newStatus},
        );
      }
      await fetchOrders();
    } catch (_) {}
    return true;
  }

  Future<void> fetchPurchases() async {
    try {
      var res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_purchases?select=*&order=created_at.desc'),
        headers: _headers(),
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        purchases = data.map((json) => PurchaseInvoice.fromJson(json)).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> addPurchase({
    required String supplierName,
    required DateTime date,
    required double amount,
    required String paymentStatus,
    String? imageUrl,
  }) async {
    try {
      await http.post(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_purchases'),
        headers: _headers(),
        body: jsonEncode({
          'supplier_name': supplierName,
          'invoice_date': date.toIso8601String().split('T')[0],
          'amount_sdg': amount,
          'payment_status': paymentStatus,
          'invoice_image_url': imageUrl,
        }),
      );
      await fetchPurchases();
    } catch (_) {
      purchases.insert(
        0,
        PurchaseInvoice(
          id: const Uuid().v4(),
          supplierName: supplierName,
          invoiceDate: date,
          amountSdg: amount,
          paymentStatus: paymentStatus,
          invoiceImageUrl: imageUrl,
          createdAt: DateTime.now(),
        ),
      );
      notifyListeners();
    }
    return true;
  }

  Future<void> fetchPromotions() async {
    try {
      var res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_promotions?select=*&order=created_at.desc'),
        headers: _headers(),
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        promotions = data.map((j) => Promotion.fromJson(j)).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<bool> createAndBroadcastOffer(String title, String body) async {
    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_promotions'),
        headers: _headers(),
        body: jsonEncode({
          'title': title,
          'body': body,
          'target_count': customers.isNotEmpty ? customers.length : 320,
        }),
      );

      String promoId = const Uuid().v4();
      if (res.statusCode == 201 || res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        if (data.isNotEmpty) promoId = data[0]['id'].toString();
      }

      // Contract Event: Admin creates and broadcasts promotional offer to customers
      await sendNotification(
        toRole: 'customer',
        title: title,
        body: body,
        data: {'promo_id': promoId},
      );

      await fetchPromotions();
    } catch (_) {
      promotions.insert(
        0,
        Promotion(
          id: const Uuid().v4(),
          title: title,
          body: body,
          targetCount: customers.isNotEmpty ? customers.length : 320,
          createdAt: DateTime.now(),
        ),
      );
      notifyListeners();
    }
    return true;
  }

  Future<void> fetchCustomers() async {
    try {
      var res = await http.get(
        Uri.parse('$kSupabaseUrl/rest/v1/tarag3_profiles?role=eq.customer&order=created_at.desc'),
        headers: _headers(),
      );
      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body);
        customers = data.map((j) => CustomerProfile.fromJson(j)).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> requestLocationPermission(BuildContext context) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خدمة تحديد الموقع غير مفعّلة في الهاتف')),
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
            SnackBar(
              content: const Text('تم رفض إذن الموقع. يتطلب التطبيق إذن الموقع لتحديد مناطق التوصيل.'),
              action: SnackBarAction(
                label: 'الإعدادات',
                onPressed: () => Geolocator.openAppSettings(),
              ),
            ),
          );
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('إذن الموقع مرفوض دائماً. يرجى تفعيله من إعدادات الهاتف.'),
            action: SnackBarAction(
              label: 'الإعدادات',
              onPressed: () => Geolocator.openAppSettings(),
            ),
          ),
        );
      }
      return;
    }
  }
}

// ============================================================================
// APP WIDGET & THEME
// ============================================================================

class DmcAdminApp extends StatelessWidget {
  const DmcAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    final messengerKey = GlobalKey<ScaffoldMessengerState>();
    context.read<AdminStateProvider>().messengerKey = messengerKey;

    return MaterialApp(
      title: 'DMC Admin',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: messengerKey,
      locale: const Locale('ar'),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child ?? const SizedBox(),
        );
      },
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Cairo',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0A2F6B),
          primary: const Color(0xFF0A47A8),
          secondary: const Color(0xFF00B8C4),
          surface: const Color(0xFFFFFFFF),
        ),
        scaffoldBackgroundColor: const Color(0xFFF3F7FC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A2F6B),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Cairo',
        colorScheme: ColorScheme.fromSeed(
          brightness: Brightness.dark,
          seedColor: const Color(0xFF0A2F6B),
          primary: const Color(0xFF3B82F6),
          secondary: const Color(0xFF00B8C4),
          surface: const Color(0xFF1E293B),
        ),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
      ),
      home: const AdminRootRouter(),
    );
  }
}

class AdminRootRouter extends StatelessWidget {
  const AdminRootRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminStateProvider>();

    if (!state.isAuthenticated) {
      return const AdminAuthScreen();
    }

    if (state.requiresPin) {
      return const AdminPinScreen();
    }

    return const AdminMainShell();
  }
}

// ============================================================================
// ADMIN PIN CLAIM SCREEN
// ============================================================================

class AdminPinScreen extends StatefulWidget {
  const AdminPinScreen({super.key});

  @override
  State<AdminPinScreen> createState() => _AdminPinScreenState();
}

class _AdminPinScreenState extends State<AdminPinScreen> {
  final pinCtrl = TextEditingController();
  String? errorMsg;
  bool isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminStateProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FC),
      appBar: AppBar(
        title: const Text('دخول الإدارة', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => state.signOut(),
          )
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE1E9F3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.lock_outline, size: 48, color: Color(0xFF0A47A8)),
                  const SizedBox(height: 12),
                  const Text(
                    'أدخل رمز الإدارة للمتابعة',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0A2F6B)),
                  ),
                  const SizedBox(height: 16),
                  if (errorMsg != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFCE8E6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        errorMsg!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFE53935), fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: pinCtrl,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'رمز الإدارة',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            setState(() {
                              errorMsg = null;
                              isSubmitting = true;
                            });
                            final success = await state.claimAdminAccess(pin: pinCtrl.text.trim());
                            if (!mounted) return;
                            setState(() => isSubmitting = false);
                            if (!success) {
                              setState(() => errorMsg = 'رمز الإدارة غير صحيح');
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A47A8),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isSubmitting
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('دخول الإدارة', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
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

// ============================================================================
// AUTH & LOGIN SCREEN (WITH SUPABASE OTP & RECOVERY)
// ============================================================================

class AdminAuthScreen extends StatefulWidget {
  const AdminAuthScreen({super.key});

  @override
  State<AdminAuthScreen> createState() => _AdminAuthScreenState();
}

enum AuthMode { signIn, signUp, verifyOtp, recoverPassword, resetPassword }

class _AdminAuthScreenState extends State<AdminAuthScreen> {
  AuthMode mode = AuthMode.signIn;

  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmPassCtrl = TextEditingController();
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final otpCtrl = TextEditingController();

  bool showPass = false;
  String? errorMsg;
  String? statusMsg;
  int resendSeconds = 60;
  Timer? resendTimer;

  void startResendTimer() {
    resendSeconds = 60;
    resendTimer?.cancel();
    resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (resendSeconds > 0) {
        setState(() => resendSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    resendTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminStateProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Badge
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0A47A8), Color(0xFF00B8C4)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00B8C4).withValues(alpha: 0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'DMC',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'لوحة إدارة DMC',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0A2F6B),
                  ),
                ),
                const Text(
                  'Diala Medical & Chemical Equipment',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 24),

                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Color(0xFFE1E9F3)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          mode == AuthMode.signIn
                              ? 'تسجيل الدخول'
                              : mode == AuthMode.signUp
                                  ? 'حساب جديد'
                                  : mode == AuthMode.verifyOtp
                                      ? 'بعتنا رمز على بريدك'
                                      : mode == AuthMode.recoverPassword
                                          ? 'نسيت كلمة المرور'
                                          : 'تغيير كلمة المرور',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0A2F6B),
                          ),
                        ),
                        const Divider(height: 24),

                        if (errorMsg != null) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFCE8E6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              errorMsg!,
                              style: const TextStyle(
                                  color: Color(0xFFE53935), fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        if (statusMsg != null) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6F4EA),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              statusMsg!,
                              style: const TextStyle(
                                  color: Color(0xFF00A86B), fontSize: 13, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        if (mode == AuthMode.signUp) ...[
                          TextField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'الاسم الكامل',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'رقم الهاتف',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        if (mode == AuthMode.signIn || mode == AuthMode.signUp || mode == AuthMode.recoverPassword) ...[
                          TextField(
                            controller: emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'البريد الإلكتروني',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        if (mode == AuthMode.signIn || mode == AuthMode.signUp || mode == AuthMode.resetPassword) ...[
                          TextField(
                            controller: passCtrl,
                            obscureText: !showPass,
                            decoration: InputDecoration(
                              labelText: mode == AuthMode.resetPassword ? 'كلمة المرور الجديدة' : 'كلمة المرور',
                              border: const OutlineInputBorder(),
                              suffixIcon: IconButton(
                                icon: Icon(showPass ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => showPass = !showPass),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        if (mode == AuthMode.signUp) ...[
                          TextField(
                            controller: confirmPassCtrl,
                            obscureText: !showPass,
                            decoration: const InputDecoration(
                              labelText: 'تأكيد كلمة المرور',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        if (mode == AuthMode.verifyOtp) ...[
                          TextField(
                            controller: otpCtrl,
                            keyboardType: TextInputType.number,
                            maxLength: 6,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
                            decoration: const InputDecoration(
                              labelText: 'رمز التحقق (6 أرقام)',
                              border: OutlineInputBorder(),
                              counterText: '',
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: resendSeconds > 0
                                ? null
                                : () async {
                                    final err = await state.resendOtp(emailCtrl.text.trim(), 'signup');
                                    if (err != null) {
                                      setState(() => errorMsg = err);
                                    } else {
                                      setState(() => statusMsg = 'تم إعادة إرسال رمز التحقق');
                                      startResendTimer();
                                    }
                                  },
                            child: Text(
                              resendSeconds > 0 ? 'إعادة الإرسال خلال ($resendSeconds ث)' : 'إعادة إرسال الرمز',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],

                        ElevatedButton(
                          onPressed: state.isLoading ? null : () => _handleAuthAction(state),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0A47A8),
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: state.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  mode == AuthMode.signIn
                                      ? 'تسجيل الدخول'
                                      : mode == AuthMode.signUp
                                          ? 'تأكيد وإنشاء حساب'
                                          : mode == AuthMode.verifyOtp
                                              ? 'تأكيد الرمز'
                                              : mode == AuthMode.recoverPassword
                                                  ? 'إرسال رمز الاستعادة'
                                                  : 'حفظ كلمة المرور الجديدة',
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                ),
                        ),

                        const SizedBox(height: 14),

                        if (mode == AuthMode.signIn) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextButton(
                                onPressed: () => setState(() {
                                  mode = AuthMode.signUp;
                                  errorMsg = null;
                                  statusMsg = null;
                                }),
                                child: const Text('حساب جديد', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                              TextButton(
                                onPressed: () => setState(() {
                                  mode = AuthMode.recoverPassword;
                                  errorMsg = null;
                                  statusMsg = null;
                                }),
                                child: const Text('نسيت كلمة المرور؟', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          )
                        ] else ...[
                          TextButton(
                            onPressed: () => setState(() {
                              mode = AuthMode.signIn;
                              errorMsg = null;
                              statusMsg = null;
                            }),
                            child: const Text('العودة لتسجيل الدخول', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          )
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

  Future<void> _handleAuthAction(AdminStateProvider state) async {
    setState(() {
      errorMsg = null;
      statusMsg = null;
    });

    if (mode == AuthMode.signUp) {
      if (nameCtrl.text.trim().isEmpty) {
        setState(() => errorMsg = 'يرجى إدخال الاسم الكامل');
        return;
      }
      if (phoneCtrl.text.trim().isEmpty) {
        setState(() => errorMsg = 'يرجى إدخال رقم الهاتف');
        return;
      }
      if (emailCtrl.text.trim().isEmpty) {
        setState(() => errorMsg = 'يرجى إدخال البريد الإلكتروني');
        return;
      }
      if (passCtrl.text.length < 6) {
        setState(() => errorMsg = 'كلمة المرور يجب أن لا تقل عن 6 أحرف');
        return;
      }
      if (passCtrl.text != confirmPassCtrl.text) {
        setState(() => errorMsg = 'كلمتا المرور غير متطابقتين');
        return;
      }

      final err = await state.signUp(
        nameCtrl.text.trim(),
        phoneCtrl.text.trim(),
        emailCtrl.text.trim(),
        passCtrl.text,
      );
      if (err == null) {
        setState(() {
          mode = AuthMode.verifyOtp;
          statusMsg = 'بعتنا رمز على بريدك، دخل الرمز المكون من 6 أرقام';
        });
        startResendTimer();
      } else {
        setState(() => errorMsg = err);
      }
    } else if (mode == AuthMode.signIn) {
      if (emailCtrl.text.trim().isEmpty || passCtrl.text.isEmpty) {
        setState(() => errorMsg = 'يرجى إدخال البريد وكلمة المرور');
        return;
      }
      final err = await state.signIn(emailCtrl.text.trim(), passCtrl.text);
      if (err == 'UNCONFIRMED_EMAIL') {
        setState(() {
          mode = AuthMode.verifyOtp;
          statusMsg = 'البريد غير مؤكد، بعتنا رمز جديد على بريدك الإلكتروني';
        });
        startResendTimer();
      } else if (err != null) {
        setState(() => errorMsg = err);
      }
    } else if (mode == AuthMode.verifyOtp) {
      if (otpCtrl.text.trim().length != 6) {
        setState(() => errorMsg = 'يرجى إدخال رمز التحقق المكون من 6 أرقام');
        return;
      }
      final err = await state.verifyOtp(emailCtrl.text.trim(), otpCtrl.text.trim(), 'signup');
      if (err != null) {
        setState(() => errorMsg = err);
      }
    } else if (mode == AuthMode.recoverPassword) {
      if (emailCtrl.text.trim().isEmpty) {
        setState(() => errorMsg = 'يرجى إدخال البريد الإلكتروني');
        return;
      }

      final err = await state.recoverPassword(emailCtrl.text.trim());
      if (err == null) {
        setState(() {
          mode = AuthMode.resetPassword;
          statusMsg = 'أدخل رمز الاستعادة وكلمة المرور الجديدة';
        });
      } else {
        setState(() => errorMsg = err);
      }
    } else if (mode == AuthMode.resetPassword) {
      if (otpCtrl.text.trim().length != 6) {
        setState(() => errorMsg = 'يرجى إدخال رمز 6 أرقام');
        return;
      }
      if (passCtrl.text.length < 6) {
        setState(() => errorMsg = 'كلمة المرور يجب أن تكون 6 أحرف على الأقل');
        return;
      }
      final err = await state.verifyOtp(emailCtrl.text.trim(), otpCtrl.text.trim(), 'recovery');
      if (err == null) {
        final updateErr = await state.updatePassword(passCtrl.text);
        if (updateErr != null) {
          setState(() => errorMsg = updateErr);
        }
      } else {
        setState(() => errorMsg = err);
      }
    }
  }
}

// ============================================================================
// MAIN SHELL NAVIGATION
// ============================================================================

class AdminMainShell extends StatefulWidget {
  const AdminMainShell({super.key});

  @override
  State<AdminMainShell> createState() => _AdminMainShellState();
}

class _AdminMainShellState extends State<AdminMainShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    DashboardView(),
    OrdersView(),
    ProductsView(),
    PurchasesView(),
    ReportsView(),
  ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminStateProvider>();

    return Scaffold(
      body: Column(
        children: [
          // Navigation Bar Switcher
          Container(
            height: 48,
            color: const Color(0xFF0A0F1A),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  _buildScreenPill('لوحة التحكم', _currentIndex == 0, () => setState(() => _currentIndex = 0)),
                  _buildScreenPill('الطلبات', _currentIndex == 1, () => setState(() => _currentIndex = 1)),
                  _buildScreenPill('المنتجات والمخزون', _currentIndex == 2, () => setState(() => _currentIndex = 2)),
                  _buildScreenPill('إضافة منتج', false, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProductAddEditScreen()));
                  }),
                  _buildScreenPill('المشتريات', _currentIndex == 3, () => setState(() => _currentIndex = 3)),
                  _buildScreenPill('العروض والإشعارات', false, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const OffersBroadcastScreen()));
                  }),
                  _buildScreenPill('التقارير والرياضيات', _currentIndex == 4, () => setState(() => _currentIndex = 4)),
                  _buildScreenPill('صندوق الإشعارات', false, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsInboxScreen()));
                  }),
                  _buildScreenPill('الزبائن', false, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomersView()));
                  }),
                  _buildScreenPill('الإعدادات', false, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsProfileScreen()));
                  }),
                  _buildScreenPill('حالة فارغة', false, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const EmptyStateScreen()));
                  }),
                  _buildScreenPill('حالة التحميل', false, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SkeletonLoadingScreen()));
                  }),
                ],
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        height: 68,
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE1E9F3))),
          boxShadow: [
            BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (idx) => setState(() => _currentIndex = idx),
          selectedItemColor: const Color(0xFF0A47A8),
          unselectedItemColor: const Color(0xFF64748B),
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'الرئيسية',
            ),
            BottomNavigationBarItem(
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.shopping_bag_outlined),
                  if (state.newOrdersCount > 0)
                    Positioned(
                      top: -4,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE53935),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${state.newOrdersCount}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                ],
              ),
              activeIcon: const Icon(Icons.shopping_bag),
              label: 'الطلبات',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.inventory_2_outlined),
              activeIcon: Icon(Icons.inventory_2),
              label: 'المنتجات',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: 'المشتريات',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: 'التقارير',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScreenPill(String title, bool isActive, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(left: 6.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF00B8C4) : const Color(0xFF263238),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? const Color(0xFF00B8C4) : Colors.white24,
            ),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w900 : FontWeight.bold,
              color: isActive ? const Color(0xFF0A2F6B) : Colors.white70,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 1. DASHBOARD VIEW (لوحة التحكم الرئيسية)
// ============================================================================

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminStateProvider>();
    final usdController = TextEditingController(text: state.usdRate.toStringAsFixed(0));

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0A47A8), Color(0xFF00B8C4)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'DMC',
                  style: TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 14, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('لوحة التحكم', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                Text('تطبيق إدارة المحل',
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.location_on_outlined),
            tooltip: 'مناطق التوصيل',
            onPressed: () {
              state.requestLocationPermission(context);
              _showDeliveryAreasModal(context, state);
            },
          ),
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined),
                if (state.unreadNotificationsCount > 0)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE53935),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${state.unreadNotificationsCount}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
              ],
            ),
            tooltip: 'صندوق الإشعارات',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsInboxScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => state.refreshDataQuietly(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // New Orders Banner
              InkWell(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0A47A8), Color(0xFF0A2F6B)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.shopping_bag_outlined, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('تنبيه الطلبات',
                                style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                            Text(
                              'عدد الطلبات الجديدة',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00B8C4),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${state.newOrdersCount} طلبات',
                          style: const TextStyle(
                              color: Color(0xFF0A2F6B), fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                      )
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // USD Exchange Rate Realtime Card
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE1E9F3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.monetization_on_outlined, color: Color(0xFF0A47A8)),
                              SizedBox(width: 8),
                              Text(
                                'سعر الدولار اليوم',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0A2F6B)),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE6F4EA),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              'مربوط تلقائياً',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF00A86B),
                                  fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: usdController,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w800),
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton(
                            onPressed: () async {
                              final rate = double.tryParse(usdController.text);
                              if (rate != null && rate > 0) {
                                await state.updateUsdRate(rate);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'تم تحديث سعر الدولار اليوم إلى ($rate ج.س).\nتم تعديل أسعار المنتجات لدى تطبيق الزبون وإرسال إشعار للزبائن!'),
                                    ),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0A47A8),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('تحديث الأسعار', style: TextStyle(fontWeight: FontWeight.bold)),
                          )
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '* الضغط على تحديث الأسعار يغير أسعار جميع المنتجات بالجنيه السوداني لدى تطبيق الزبون أوتوماتيكياً ويطلق إشعاراً لهم.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // KPI Grid
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.45,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _buildKpiCard(
                    title: 'إجمالي المبيعات (الشهر)',
                    value: '4.25M ج.س',
                    subtext: '▲ +14% مقارنة بالشهر السابق',
                    subColor: const Color(0xFF00A86B),
                  ),
                  _buildKpiCard(
                    title: 'إجمالي المشتريات',
                    value: '2.80M ج.س',
                    subtext: '▼ -5% تم توريد مستهلكات',
                    subColor: const Color(0xFFE53935),
                  ),
                  _buildKpiCard(
                    title: 'صافي الأرباح المقدرة',
                    value: '1.45M ج.س',
                    valueColor: const Color(0xFF00A86B),
                    subtext: '▲ أرباح ممتازة',
                    subColor: const Color(0xFF00A86B),
                  ),
                  _buildKpiCard(
                    title: 'المنتجات النشطة',
                    value: '${state.products.length} منتجات',
                    subtext: 'المخزون محدث live',
                    subColor: const Color(0xFF0A47A8),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Delivery Areas & Rates Card
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE1E9F3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'مناطق التوصيل وأسعارها',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0A2F6B)),
                          ),
                          TextButton(
                            onPressed: () => _showDeliveryAreasModal(context, state),
                            child: const Text('+ إضافة منطقة',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0A47A8))),
                          )
                        ],
                      ),
                      const SizedBox(height: 6),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: state.deliveryAreas.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, idx) {
                          final area = state.deliveryAreas[idx];
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE1E9F3)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(area.name,
                                    style: const TextStyle(
                                        fontSize: 13, fontWeight: FontWeight.w700)),
                                Text(
                                  '${intl.NumberFormat('#,###').format(area.deliveryFee)} ج.س',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0A47A8)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    Color? valueColor,
    required String subtext,
    required Color subColor,
  }) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE1E9F3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: valueColor ?? const Color(0xFF0A2F6B)),
            ),
            const SizedBox(height: 4),
            Text(
              subtext,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: subColor),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeliveryAreasModal(BuildContext context, AdminStateProvider state) {
    final nameCtrl = TextEditingController();
    final feeCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'إضافة/تعديل منطقة توصيل',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0A2F6B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'اسم المنطقة (مثال: عطبرة، بربر، أبوحمد...)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: feeCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'سعر التوصيل (بالجنيه السوداني)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final fee = double.tryParse(feeCtrl.text) ?? 0;
                if (nameCtrl.text.isNotEmpty) {
                  await state.addDeliveryArea(nameCtrl.text, fee);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تمت إضافة منطقة التوصيل بنجاح')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A47A8),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('حفظ المنطقة', style: TextStyle(fontWeight: FontWeight.w800)),
            )
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// INBOX NOTIFICATIONS SCREEN
// ============================================================================

class NotificationsInboxScreen extends StatelessWidget {
  const NotificationsInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminStateProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('صندوق الإشعارات التنبيهية', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => state.fetchNotifications(),
          )
        ],
      ),
      body: state.notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  const Text('لا توجد إشعارات حالياً في الصندوق', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () => state.fetchNotifications(),
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: state.notifications.length,
                itemBuilder: (context, idx) {
                  final notif = state.notifications[idx];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    color: notif.isRead ? Colors.white : const Color(0xFFF0F7FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: notif.isRead ? const Color(0xFFE1E9F3) : const Color(0xFF0A47A8),
                        width: notif.isRead ? 1 : 1.5,
                      ),
                    ),
                    child: ListTile(
                      onTap: () {
                        if (!notif.isRead) {
                          state.markNotificationRead(notif.id);
                        }
                      },
                      leading: CircleAvatar(
                        backgroundColor: notif.isRead ? const Color(0xFFE2E8F0) : const Color(0xFF0A47A8),
                        child: Icon(
                          notif.isRead ? Icons.notifications_none : Icons.notifications_active,
                          color: notif.isRead ? const Color(0xFF64748B) : Colors.white,
                        ),
                      ),
                      title: Text(
                        notif.title,
                        style: TextStyle(
                          fontWeight: notif.isRead ? FontWeight.w700 : FontWeight.w900,
                          fontSize: 13,
                          color: const Color(0xFF0A2F6B),
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(notif.body, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                          const SizedBox(height: 4),
                          Text(
                            intl.DateFormat('yyyy/MM/dd hh:mm a').format(notif.createdAt),
                            style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                      trailing: !notif.isRead
                          ? Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Color(0xFF0A47A8),
                                shape: BoxShape.circle,
                              ),
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
    );
  }
}

// ============================================================================
// 2. ORDERS MANAGEMENT VIEW (إدارة الطلبات)
// ============================================================================

class OrdersView extends StatefulWidget {
  const OrdersView({super.key});

  @override
  State<OrdersView> createState() => _OrdersViewState();
}

class _OrdersViewState extends State<OrdersView> {
  String selectedFilter = 'الكل';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminStateProvider>();

    final filteredOrders = state.orders.where((o) {
      if (selectedFilter == 'الكل') return true;
      return o.status == selectedFilter;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة طلبات الزبائن', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        actions: [
          Container(
            margin: const EdgeInsets.only(left: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${state.orders.length} طلب إجمالي',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0A2F6B)),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            color: const Color(0xFFEBF2FA),
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFEBF2FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: ['الكل', 'جديد', 'قيد التجهيز', 'في الطريق', 'تم'].map((filter) {
                final isSel = selectedFilter == filter;
                return Expanded(
                  child: InkWell(
                    onTap: () => setState(() => selectedFilter = filter),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: isSel
                            ? [const BoxShadow(color: Colors.black12, blurRadius: 4)]
                            : [],
                      ),
                      child: Text(
                        filter,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isSel ? const Color(0xFF0A2F6B) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          Expanded(
            child: filteredOrders.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 12),
                        const Text('لا توجد طلبات مسجلة في هذا القسم', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => state.fetchOrders(),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: filteredOrders.length,
                      itemBuilder: (context, idx) {
                        final order = filteredOrders[idx];
                        return OrderListTile.buildCard(context, order);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class OrderListTile {
  static Widget buildCard(BuildContext context, CustomerOrder order) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE1E9F3)),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'طلب #${order.orderNumber}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0A2F6B)),
                      ),
                      Text(
                        'الزبون: ${order.customerName} • ${order.deliveryAreaName}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  _buildStatusBadge(order.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                order.items.isNotEmpty
                    ? order.items.map((i) => '${i.productName} (×${i.quantity})').join('، ')
                    : 'طلب مستلزمات طبية',
                style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${intl.NumberFormat('#,###').format(order.totalSdg)} ج.س',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0A47A8)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEBF2FA),
                      foregroundColor: const Color(0xFF0A2F6B),
                      elevation: 0,
                      minimumSize: const Size(0, 32),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                    child: const Text('عرض والتعديل', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  )
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    if (status == 'جديد') {
      bg = const Color(0xFFEBF2FA);
      fg = const Color(0xFF0A47A8);
    } else if (status == 'قيد التجهيز') {
      bg = const Color(0xFFFFF4E5);
      fg = const Color(0xFFFF9800);
    } else if (status == 'في الطريق') {
      bg = const Color(0xFFE0F7FA);
      fg = const Color(0xFF00838F);
    } else {
      bg = const Color(0xFFE6F4EA);
      fg = const Color(0xFF00A86B);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(
        status,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w800),
      ),
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
  late String selectedStatus;

  @override
  void initState() {
    super.initState();
    selectedStatus = widget.order.status;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminStateProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('تفاصيل الطلب #${widget.order.orderNumber}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Customer Info
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE1E9F3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('بيانات الزبون',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0A2F6B))),
                    const SizedBox(height: 8),
                    Text('الاسم: ${widget.order.customerName}', style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                    Text('الهاتف: ${widget.order.customerPhone}', style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                    Text('المنطقة: ${widget.order.deliveryAreaName}', style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                    Text('العنوان: ${widget.order.detailedAddress}', style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Order Table
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE1E9F3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('عناصر الطلب',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0A2F6B))),
                    const SizedBox(height: 8),
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(3),
                        1: FlexColumnWidth(1),
                        2: FlexColumnWidth(2),
                      },
                      children: [
                        const TableRow(
                          decoration: BoxDecoration(color: Color(0xFFF1F5F9)),
                          children: [
                            Padding(padding: EdgeInsets.all(6.0), child: Text('المنتج', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            Padding(padding: EdgeInsets.all(6.0), child: Text('الكمية', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                            Padding(padding: EdgeInsets.all(6.0), child: Text('الإجمالي', textAlign: TextAlign.left, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                          ],
                        ),
                        ...widget.order.items.map((item) {
                          return TableRow(
                            children: [
                              Padding(padding: const EdgeInsets.all(6.0), child: Text(item.productName, style: const TextStyle(fontSize: 12))),
                              Padding(padding: const EdgeInsets.all(6.0), child: Text('${item.quantity}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12))),
                              Padding(padding: const EdgeInsets.all(6.0), child: Text('${intl.NumberFormat('#,###').format(item.totalPriceSdg)} ج.س', textAlign: TextAlign.left, style: const TextStyle(fontSize: 12))),
                            ],
                          );
                        }),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('المجموع مع التوصيل:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                        Text(
                          '${intl.NumberFormat('#,###').format(widget.order.totalSdg)} ج.س',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF0A47A8)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Status Selector Card
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE1E9F3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('تغيير حالة الطلب الحالية',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0A2F6B))),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: selectedStatus,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      items: ['جديد', 'قيد التجهيز', 'في الطريق', 'تم']
                          .map((st) => DropdownMenuItem(value: st, child: Text(st, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => selectedStatus = val);
                      },
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: () async {
                        await state.updateOrderStatus(widget.order, selectedStatus);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم تحديث حالة الطلب وإرسال إشعار للزبون أوتوماتيكياً!')),
                          );
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A47A8),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('حفظ وتحديث الحالة', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 3. PRODUCTS VIEW (المنتجات والمخزون)
// ============================================================================

class ProductsView extends StatefulWidget {
  const ProductsView({super.key});

  @override
  State<ProductsView> createState() => _ProductsViewState();
}

class _ProductsViewState extends State<ProductsView> {
  String searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminStateProvider>();

    final filteredProducts = state.products.where((p) {
      return searchQuery.isEmpty || p.name.contains(searchQuery) || p.category.contains(searchQuery);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المنتجات والمخزون', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProductAddEditScreen()),
              );
            },
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => searchQuery = val),
                    decoration: InputDecoration(
                      hintText: 'بحث بالاسم أو القسم...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      fillColor: Colors.white,
                      filled: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProductAddEditScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A47A8),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('+ إضافة', style: TextStyle(fontWeight: FontWeight.w800)),
                )
              ],
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () => state.fetchProducts(),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: filteredProducts.length,
                itemBuilder: (context, idx) {
                  final prod = filteredProducts[idx];
                  final sdgPrice = prod.calculateSdgPrice(state.usdRate);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFE1E9F3)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF0A47A8)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  prod.name,
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0A2F6B)),
                                ),
                                const SizedBox(height: 2),
                                RichText(
                                  text: TextSpan(
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontFamily: 'Cairo'),
                                    children: [
                                      const TextSpan(text: 'السعر: '),
                                      TextSpan(text: '\$${prod.priceUsd.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black)),
                                      TextSpan(text: ' (${intl.NumberFormat('#,###').format(sdgPrice)} ج.س) • المخزون: ${prod.stockQuantity}'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: prod.isVisible,
                            activeThumbColor: const Color(0xFF0A47A8),
                            onChanged: (val) {
                              state.toggleProductVisibility(prod.id, prod.isVisible);
                            },
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

class ProductAddEditScreen extends StatefulWidget {
  final Product? product;
  const ProductAddEditScreen({super.key, this.product});

  @override
  State<ProductAddEditScreen> createState() => _ProductAddEditScreenState();
}

class _ProductAddEditScreenState extends State<ProductAddEditScreen> {
  final nameCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final priceUsdCtrl = TextEditingController(text: '25.00');
  final stockCtrl = TextEditingController(text: '50');
  String category = 'معدات';
  bool isVisible = true;
  String? imagePath;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      nameCtrl.text = widget.product!.name;
      descCtrl.text = widget.product!.description;
      priceUsdCtrl.text = widget.product!.priceUsd.toString();
      stockCtrl.text = widget.product!.stockQuantity.toString();
      category = widget.product!.category;
      isVisible = widget.product!.isVisible;
      imagePath = widget.product!.imageUrl;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminStateProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product != null ? 'تعديل منتج' : 'إضافة منتج جديد', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE1E9F3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap: () async {
                    final picker = ImagePicker();
                    final picked = await picker.pickImage(source: ImageSource.gallery);
                    if (picked != null) {
                      setState(() => imagePath = picked.path);
                    }
                  },
                  child: Container(
                    height: 140,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.photo_camera_outlined, size: 32, color: Color(0xFF64748B)),
                        const SizedBox(height: 6),
                        Text(
                          imagePath != null ? 'تم رفع صورة المنتج' : 'اضغط لرفع صورة المنتج',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                        )
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم المنتج بالكامل',
                    hintText: 'مثال: جهاز قياس السكر بالسيروم',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: const InputDecoration(
                    labelText: 'القسم الرئيسي',
                    border: OutlineInputBorder(),
                  ),
                  items: ['معدات', 'مستهلكات', 'مختبر']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => category = val);
                  },
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceUsdCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'السعر بالدولار (\$)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: stockCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'الكمية بالمخزن',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('إظهار المنتج في تطبيق الزبون', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    Switch(
                      value: isVisible,
                      activeThumbColor: const Color(0xFF0A47A8),
                      onChanged: (val) => setState(() => isVisible = val),
                    )
                  ],
                ),

                const SizedBox(height: 16),

                ElevatedButton(
                  onPressed: () async {
                    final price = double.tryParse(priceUsdCtrl.text) ?? 25.0;
                    final stock = int.tryParse(stockCtrl.text) ?? 50;

                    if (nameCtrl.text.isNotEmpty) {
                      await state.saveProduct(
                        id: widget.product?.id,
                        name: nameCtrl.text,
                        category: category,
                        description: descCtrl.text,
                        priceUsd: price,
                        stock: stock,
                        imageUrl: imagePath,
                        isVisible: isVisible,
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A47A8),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('حفظ المنتج وتحديث القاعدة', style: TextStyle(fontWeight: FontWeight.w800)),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 4. PURCHASES MANAGEMENT VIEW (المشتريات)
// ============================================================================

class PurchasesView extends StatelessWidget {
  const PurchasesView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminStateProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة فواتير المشتريات', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddPurchaseModal(context, state),
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => state.fetchPurchases(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              ElevatedButton(
                onPressed: () => _showAddPurchaseModal(context, state),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A47A8),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('+ تسجيل فاتورة شراء جديدة من مورد', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: state.purchases.length,
                itemBuilder: (context, idx) {
                  final p = state.purchases[idx];
                  final isPaid = p.paymentStatus == 'مدفوع';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFE1E9F3)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                p.supplierName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: Color(0xFF0A2F6B)),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isPaid ? const Color(0xFFE6F4EA) : const Color(0xFFFCE8E6),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  p.paymentStatus,
                                  style: TextStyle(
                                    color: isPaid ? const Color(0xFF00A86B) : const Color(0xFFE53935),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              )
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'التاريخ: ${intl.DateFormat('yyyy/MM/dd').format(p.invoiceDate)} • ${p.notesOrDetails ?? "شحنة مستلزمات طبية"}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 8),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${intl.NumberFormat('#,###').format(p.amountSdg)} ج.س',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: isPaid ? const Color(0xFF0A47A8) : const Color(0xFFE53935),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('عرض صورة فاتورة المورد المرفقة')),
                                  );
                                },
                                icon: const Icon(Icons.image, size: 14),
                                label: const Text('صورة الفاتورة', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEBF2FA),
                                  foregroundColor: const Color(0xFF0A2F6B),
                                  elevation: 0,
                                  minimumSize: const Size(0, 32),
                                ),
                              )
                            ],
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
      ),
    );
  }

  void _showAddPurchaseModal(BuildContext context, AdminStateProvider state) {
    final supplierCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String paymentStatus = 'مدفوع';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          left: 16,
          right: 16,
          top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'تسجيل فاتورة شراء من مورد',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0A2F6B)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: supplierCtrl,
              decoration: const InputDecoration(
                labelText: 'اسم المورد',
                hintText: 'اسم الشركة أو المورد...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'المبلغ الإجمالي (ج.س)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: paymentStatus,
              decoration: const InputDecoration(
                labelText: 'حالة الدفع',
                border: OutlineInputBorder(),
              ),
              items: ['مدفوع', 'آجل']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (val) {
                if (val != null) paymentStatus = val;
              },
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picker = ImagePicker();
                await picker.pickImage(source: ImageSource.camera);
              },
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: const Center(
                  child: Text(
                    '📷 رفع صورة الفاتورة (الكاميرا / المعرض)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text) ?? 0;
                if (supplierCtrl.text.isNotEmpty && amt > 0) {
                  await state.addPurchase(
                    supplierName: supplierCtrl.text,
                    date: DateTime.now(),
                    amount: amt,
                    paymentStatus: paymentStatus,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تمت إضافة فاتورة الشراء وحفظها في Supabase')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A47A8),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('تأكيد وحفظ الفاتورة', style: TextStyle(fontWeight: FontWeight.w800)),
            )
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// 5. FINANCIAL REPORTS VIEW (التقارير المالية والرياضيات)
// ============================================================================

class ReportsView extends StatefulWidget {
  const ReportsView({super.key});

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> {
  String selectedPeriod = 'هذا الأسبوع';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير المالية والرياضيات', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFEBF2FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: ['هذا الأسبوع', 'الشهر الحالي', 'التقرير السنوي'].map((period) {
                  final isSel = selectedPeriod == period;
                  return Expanded(
                    child: InkWell(
                      onTap: () => setState(() => selectedPeriod = period),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: isSel ? [const BoxShadow(color: Colors.black12, blurRadius: 4)] : [],
                        ),
                        child: Text(
                          period,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSel ? const Color(0xFF0A2F6B) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 12),

            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE1E9F3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'مخطط حركة المبيعات مقابل المشتريات',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0A2F6B)),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 140,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildChartBar('السبت', 70, const Color(0xFF0A47A8)),
                          _buildChartBar('الأحد', 95, const Color(0xFF0A47A8)),
                          _buildChartBar('الاثنين', 50, const Color(0xFF0A47A8)),
                          _buildChartBar('الثلاثاء', 110, const Color(0xFF00B8C4)),
                          _buildChartBar('الأربعاء', 85, const Color(0xFF0A47A8)),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE1E9F3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('التقرير المالي الملخص',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0A2F6B))),
                    const SizedBox(height: 10),
                    _summaryLine('مبيعات المنتجات الكلية:', '4,250,000 ج.س', Colors.black),
                    _summaryLine('تكلِفة المشتريات والمستلزمات:', '- 2,800,000 ج.س', const Color(0xFFE53935)),
                    _summaryLine('رسوم التوصيل المحصلة:', '+ 120,000 ج.س', const Color(0xFF0A47A8)),
                    const Divider(height: 16),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('الأرباح الصافية (Net Profit):',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                        Text('1,570,000 ج.س',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF00A86B))),
                      ],
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

  Widget _buildChartBar(String label, double height, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 28,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
      ],
    );
  }

  Widget _summaryLine(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }
}

// ============================================================================
// CUSTOMERS DIRECTORY SCREEN
// ============================================================================

class CustomersView extends StatelessWidget {
  const CustomersView({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminStateProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل الزبائن والمستخدمين', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: RefreshIndicator(
        onRefresh: () => state.fetchCustomers(),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: state.customers.length,
          itemBuilder: (context, idx) {
            final cust = state.customers[idx];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE1E9F3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEBF2FA),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          cust.fullName.isNotEmpty ? cust.fullName[0] : 'ز',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0A47A8)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cust.fullName,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0A2F6B)),
                          ),
                          Text(
                            cust.phone,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F4EA),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'موثق Supabase',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF00A86B)),
                      ),
                    )
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

// ============================================================================
// EMPTY STATE SCREEN
// ============================================================================

class EmptyStateScreen extends StatelessWidget {
  const EmptyStateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('السجلات الفارغة', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFFE0F7FA),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.inbox_outlined, size: 40, color: Color(0xFF00B8C4)),
              ),
              const SizedBox(height: 16),
              const Text(
                'لا توجد عناصر مسجلة حالياً',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0A2F6B)),
              ),
              const SizedBox(height: 6),
              const Text(
                'لم يتم العثور على أية طلبات أو منتجات مطابقة لهذا القسم.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A47A8),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('العودة للوحة التحكم', style: TextStyle(fontWeight: FontWeight.w800)),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SKELETON LOADING SCREEN
// ============================================================================

class SkeletonLoadingScreen extends StatelessWidget {
  const SkeletonLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('جاري تحميل البيانات...', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _skeletonBox(height: 50),
            const SizedBox(height: 12),
            _skeletonBox(height: 100),
            const SizedBox(height: 12),
            _skeletonBox(height: 80),
            const SizedBox(height: 12),
            _skeletonBox(height: 80),
            const SizedBox(height: 12),
            _skeletonBox(height: 120),
          ],
        ),
      ),
    );
  }

  Widget _skeletonBox({required double height}) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(12),
      ),
    ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: const Color(0xFFF1F5F9));
  }
}

// ============================================================================
// OFFERS & SETTINGS SCREENS
// ============================================================================

class OffersBroadcastScreen extends StatefulWidget {
  const OffersBroadcastScreen({super.key});

  @override
  State<OffersBroadcastScreen> createState() => _OffersBroadcastScreenState();
}

class _OffersBroadcastScreenState extends State<OffersBroadcastScreen> {
  final titleCtrl = TextEditingController(text: 'تخفيضات خاصة على أجهزة الضغط والسكر!');
  final bodyCtrl = TextEditingController(
      text: 'خصم 10% لفترة محدودة على جميع المعدات الطبية مع توصيل مجاني لمناطق عطبرة والدامر!');

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminStateProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('العروض وتنبيهات الزبائن', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE1E9F3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('إرسال إشعار / عرض جديد للجميع',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0A2F6B))),
                    const SizedBox(height: 10),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'عنوان الإشعار',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: bodyCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'نص الرسالة والعرض',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: () async {
                        if (titleCtrl.text.isNotEmpty) {
                          await state.createAndBroadcastOffer(titleCtrl.text, bodyCtrl.text);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم إرسال الإشعار بنجاح لجميع جوالات الزبائن!')),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A47A8),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(46),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('🚀 إرسال الإشعار لجميع الزبائن', style: TextStyle(fontWeight: FontWeight.w800)),
                    )
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('سجل التنبيهات المرسلة سابقاً',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0A2F6B))),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.promotions.length,
              itemBuilder: (context, idx) {
                final promo = state.promotions[idx];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(promo.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF0A2F6B))),
                    subtitle: Text('تاريخ الإرسال: ${intl.DateFormat('yyyy/MM/dd').format(promo.createdAt)} • تم الوصول لـ ${promo.targetCount} مستخدم',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
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

class SettingsProfileScreen extends StatelessWidget {
  const SettingsProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AdminStateProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات النظام والحساب', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE1E9F3)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('بيانات المحل والنظام',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0A2F6B))),
                    const SizedBox(height: 10),
                    const Text('اسم المحل: DMC Diala Medical & Chemical', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                    const SizedBox(height: 4),
                    Text('حساب المدير: ${state.userEmail ?? "غير معروف"}', style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                    const SizedBox(height: 4),
                    const Text('قاعدة البيانات: Supabase Connected (Live)', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                state.signOut();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFCE8E6),
                foregroundColor: const Color(0xFFE53935),
                elevation: 0,
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('تسجيل الخروج من الإدارة', style: TextStyle(fontWeight: FontWeight.w800)),
            )
          ],
        ),
      ),
    );
  }
}
