import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' as intl;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// ============================================================================
// CONSTANTS & FIREBASE CONFIG
// ============================================================================
const String kSupabaseUrl = "https://jvjtgzewumfecjdpekna.supabase.co";
const String kSupabaseAnonKey =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInRefiI6Imp2anRnemV3dW1mZWNqZHBla25hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE2NDYzMzcsImV4cCI6MjEwNzIyMjMzN30.1gck73ek8ErBtcF7xAtFM1TdvNim_1NzFVNej_mptBE";

const firebaseOptions = FirebaseOptions(
  apiKey: "AIzaSyDummyKeyForInitialization123456",
  appId: "1:1234567890:android:1234567890abcdef",
  messagingSenderId: "1234567890",
  projectId: "almadrar-app",
);

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

// Background Firebase Messaging handler
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
    debugPrint("Firebase init error: $e");
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppStateProvider()..initSession(),
      child: const AlMadrarCustomerApp(),
    ),
  );
}

// ============================================================================
// DATA MODELS
// ============================================================================
class ServiceItem {
  final int id;
  final String title;
  final String category;
  final String description;
  final IconData icon;
  final List<String> workflowSteps;

  ServiceItem({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.icon,
    required this.workflowSteps,
  });

  factory ServiceItem.fromJson(Map<String, dynamic> json) {
    List<String> steps = [];
    if (json['workflow_steps'] is List) {
      steps = (json['workflow_steps'] as List).map((e) => e.toString()).toList();
    }
    return ServiceItem(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      title: json['title'] ?? '',
      category: json['category'] ?? '',
      description: json['description'] ?? '',
      icon: Icons.architecture,
      workflowSteps: steps,
    );
  }
}

class EngineeringProject {
  final int id;
  final String requestCode;
  final String customerId;
  final String serviceType;
  final double approximateArea;
  final String locationDetails;
  final String notes;
  final String status; // pending_inspection, cost_assigned, in_progress, completed
  final double? estimatedCost;
  final String? costNotes;
  final bool customerAccepted;
  final int progressPercentage;
  final String currentStage;
  final DateTime createdAt;

  EngineeringProject({
    required this.id,
    required this.requestCode,
    required this.customerId,
    required this.serviceType,
    required this.approximateArea,
    required this.locationDetails,
    required this.notes,
    required this.status,
    this.estimatedCost,
    this.costNotes,
    required this.customerAccepted,
    required this.progressPercentage,
    required this.currentStage,
    required this.createdAt,
  });

  factory EngineeringProject.fromJson(Map<String, dynamic> json) {
    return EngineeringProject(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      requestCode: json['request_code'] ?? 'REQ-${json['id']}',
      customerId: json['customer_id'] ?? '',
      serviceType: json['service_type'] ?? 'خدمة هندسية',
      approximateArea: (json['approximate_area'] ?? 0).toDouble(),
      locationDetails: json['location_details'] ?? '',
      notes: json['notes'] ?? '',
      status: json['status'] ?? 'pending_inspection',
      estimatedCost: json['estimated_cost'] != null
          ? (json['estimated_cost'] as num).toDouble()
          : null,
      costNotes: json['cost_breakdown_notes'],
      customerAccepted: json['customer_accepted'] ?? false,
      progressPercentage: json['progress_percentage'] ?? 0,
      currentStage: json['current_stage'] ?? 'قيد الدراسة الفنية',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}

class ProjectUpdate {
  final int id;
  final int projectId;
  final String stageTitle;
  final int progressPercentage;
  final String engineerNotes;
  final List<String> images;
  final DateTime createdAt;

  ProjectUpdate({
    required this.id,
    required this.projectId,
    required this.stageTitle,
    required this.progressPercentage,
    required this.engineerNotes,
    required this.images,
    required this.createdAt,
  });

  factory ProjectUpdate.fromJson(Map<String, dynamic> json) {
    List<String> imgList = [];
    if (json['images'] is List) {
      imgList = (json['images'] as List).map((e) => e.toString()).toList();
    }
    return ProjectUpdate(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      projectId: json['project_id'] is int
          ? json['project_id']
          : int.parse(json['project_id'].toString()),
      stageTitle: json['stage_title'] ?? 'تحديث جديد',
      progressPercentage: json['progress_percentage'] ?? 0,
      engineerNotes: json['engineer_notes'] ?? '',
      images: imgList,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}

class PortfolioItem {
  final int id;
  final String title;
  final String category;
  final String description;
  final String location;

  PortfolioItem({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.location,
  });

  factory PortfolioItem.fromJson(Map<String, dynamic> json) {
    return PortfolioItem(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      title: json['title'] ?? '',
      category: json['category'] ?? '',
      description: json['description'] ?? '',
      location: json['location'] ?? '',
    );
  }
}

class AppNotification {
  final int id;
  final String? toUser;
  final String? toRole;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final String? readAt;
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

  bool get isRead => readAt != null && readAt!.isNotEmpty;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      toUser: json['to_user']?.toString(),
      toRole: json['to_role']?.toString(),
      title: json['title'] ?? 'إشعار جديد',
      body: json['body'] ?? '',
      data: json['data'] is Map<String, dynamic> ? json['data'] : null,
      readAt: json['read_at']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}

// ============================================================================
// APP STATE & SUPABASE PROVIDER
// ============================================================================

String authErrorMessage(http.Response r) {
  try {
    final d = jsonDecode(r.body);
    final m = (d['msg'] ??
            d['error_description'] ??
            d['message'] ??
            d['error'] ??
            '')
        .toString();
    final low = m.toLowerCase();
    if (low.contains('rate limit') || r.statusCode == 429) {
      return 'تم إرسال عدة رسائل لهذا البريد. يرجى الانتظار بضع دقائق ثم المحاولة.';
    }
    if (low.contains('expired') ||
        low.contains('invalid') ||
        low.contains('token')) {
      return 'رمز التأكيد غير صحيح أو انتهت صلاحيته. يرجى طلب رمز جديد.';
    }
    return m.isEmpty ? 'حدث خطأ من السيرفر (${r.statusCode})' : m;
  } catch (_) {
    return 'حدث خطأ من السيرفر (${r.statusCode})';
  }
}

class AppStateProvider extends ChangeNotifier {
  String? authError;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  String? _accessToken;
  String? _refreshToken;
  String? _userId;
  String? _userEmail;
  String _fullName = "زبون المدرار";
  String _phone = "";
  bool _isAuthenticated = false;

  bool get isAuthenticated => _isAuthenticated;
  String? get userEmail => _userEmail;
  String get fullName => _fullName;
  String get phone => _phone;
  String? get userId => _userId;

  int _selectedNavIndex = 0;
  int get selectedNavIndex => _selectedNavIndex;

  // Catalog of 12 Exact Required Services
  final List<ServiceItem> _services = [
    ServiceItem(
      id: 1,
      title: "تشطيب داخلي وخارجي",
      category: "تشطيبات",
      description:
          "أعمال الدهانات الحديثة، الجبس بورد، الواجهات الخارجية والواجهات الزجاجية والديكورات العصرية.",
      icon: Icons.palette_outlined,
      workflowSteps: [
        "معاينة الموقع وأخذ المقاسات",
        "اختيار المواد والتأكد من المواصفات",
        "تنفيذ أعمال المعجون والدهان والتشطيب",
        "تسليم الموقع بالنظافة التامة"
      ],
    ),
    ServiceItem(
      id: 2,
      title: "صب من الأول",
      category: "صب وخرسانة",
      description:
          "بدء عملية الصب وتأسيس القواعد والأساسات المسلحة للفيلا أو العمارة من الصفر وفق خرائط متكاملة.",
      icon: Icons.foundation_outlined,
      workflowSteps: [
        "حفر الأرض وتجهيز الخرسانة العادية",
        "تركيب حديد التسليح للقواعد",
        "صب خرسانة القواعد والسملات",
        "فحص الصلابة والجفاف الهيكلي"
      ],
    ),
    ServiceItem(
      id: 3,
      title: "صب طوابق",
      category: "صب وخرسانة",
      description:
          "صب الأسقف والخرسانات المسلحة للطوابق المتعددة مع التجهيز الهيكلي ومراعاة أحمال المبنى.",
      icon: Icons.business_outlined,
      workflowSteps: [
        "تركيب الشدات الخشبية أو المعدنية",
        "توزيع شبكات الحديد المزدوجة",
        "صب خرسانة السقف بالمضخة الفائقة",
        "الرش والمتابعة الفنية الجافة"
      ],
    ),
    ServiceItem(
      id: 4,
      title: "شغل شقة كاملة جاهزة بالتشطيب",
      category: "متكامل",
      description:
          "تسليم مفتاح متكامل للشقة يشمل العظم والخرسانة والتعديلات ورسم الخرائط والتشطيب الداخلي النهائي.",
      icon: Icons.vpn_key_outlined,
      workflowSteps: [
        "الدراسة المعمارية وإعادة التقسيم",
        "أعمال التأسيس للكهرباء والسباكة",
        "التشطيبات والأرضيات والسيراميك",
        "تسليم الشقة جاهزة للسكن مباشرة"
      ],
    ),
    ServiceItem(
      id: 5,
      title: "صب عمدان",
      category: "صب وخرسانة",
      description:
          "تشييد وصب الأعمدة الخرسانية المسلحة ذات المترية الدقيقة والأبعاد الهندسية المتينة.",
      icon: Icons.account_balance_outlined,
      workflowSteps: [
        "توزين محاور الأعمدة ميكانيكياً",
        "تثبيت أقفاص حديد التسليح",
        "إغلاق الشدة الخشبية الموزونة",
        "الصب والرجاز الميكانيكي"
      ],
    ),
    ServiceItem(
      id: 6,
      title: "صب خرسانات",
      category: "صب وخرسانة",
      description:
          "تجهيز وتقديم كافة أنواع الخرسانة الجاهزة والمخلوطة ميكانيكياً لجميع المنشآت الهندسية.",
      icon: Icons.view_in_ar_outlined,
      workflowSteps: [
        "معاينة نوع الخرسانة والإجهاد المطلوب",
        "تنسيق وصول السيارات والمضخات",
        "إشراف هندسي على عملية الصب",
        "أخذ عينات المكعبات للاختبار"
      ],
    ),
    ServiceItem(
      id: 7,
      title: "تصميم داخلي وخارجي",
      category: "تصاميم",
      description:
          "تصاميم ثلاثية الأبعاد (3D) فريدة ومخططات إنشائية والمعمارية وتوزيع للمساحات بدقة عالية.",
      icon: Icons.design_services_outlined,
      workflowSteps: [
        "جلسة العصف الذهني مع المالك",
        "تقديم المخطط المبدئي و 3D Rendering",
        "تعديل الملاحظات والتفاصيل",
        "تسليم المخططات التنفيذية والجدول"
      ],
    ),
    ServiceItem(
      id: 8,
      title: "تشطيب من الأول إلى الآخر",
      category: "تشطيبات",
      description:
          "إدارة وتنفيد مشروع التشطيب الشامل من المباني الخرسانية السوداء وحتى أرقى الديكورات.",
      icon: Icons.auto_awesome_outlined,
      workflowSteps: [
        "أعمال المحارة والطرطشة",
        "تمديدات السباكة والكهرباء الذكية",
        "تركيب الأرضيات والأبواب والنوافذ",
        "الدهانات والديكورات النهائية"
      ],
    ),
    ServiceItem(
      id: 9,
      title: "تشطيب نصفي",
      category: "تشطيبات",
      description:
          "إنجاز المراحل الأساسية من التأسيس والمحارة والسباكة والكهرباء وترك العزل والديكور للعميل.",
      icon: Icons.handyman_outlined,
      workflowSteps: [
        "تأسيس شبكات السباكة والكهرباء",
        "محارة وتلييس الحوائط والأسقف",
        "تركيب عتبات الأبواب والنوافذ",
        "تسليم المرحلة نصف التشطيب"
      ],
    ),
    ServiceItem(
      id: 10,
      title: "رسم خرائط بالشقة",
      category: "خرائط وتخطيط",
      description:
          "رفع المساحات الميدانية ورسم خرائط معمارية وتنفيذية دقيقة للشقق السكنية والمقرات.",
      icon: Icons.map_outlined,
      workflowSteps: [
        "مسح موقع الشقة بالليزر والمتر",
        "رسم الخرائط الأفقية وتحديد الأعمدة",
        "تحديد المسارات الإنشائية والتعديلات",
        "تسليم ملف CAD و PDF معتمد"
      ],
    ),
    ServiceItem(
      id: 11,
      title: "الجمولونات",
      category: "هياكل معدنية",
      description:
          "تصميم وتصنيع وتركيب الجمولونات والمظلات والهياكل المعدنية الثقيلة للمخازن والمصانع.",
      icon: Icons.warehouse_outlined,
      workflowSteps: [
        "دراسة أحمال الرياح والتغطية",
        "تصنيع القطاعات الحديدية بالمشغل",
        "التركيب الميداني بالرافعات",
        "التغطية بالشينكو والعزل الحراري"
      ],
    ),
    ServiceItem(
      id: 12,
      title: "الصيوانات",
      category: "إنشاءات خفيفة",
      description:
          "تنفيذ وتجهيز الصيوانات والهياكل الخفيفة المغطاة والمظلات المقاومة للعوامل الجوية.",
      icon: Icons.roofing_outlined,
      workflowSteps: [
        "تحديد أبعاد وموقع الصيوان",
        "تثبيت القواعد والركائز القوية",
        "شد القماش والعوازل المخصصة",
        "المعاينة النهائية والاختبار"
      ],
    ),
  ];

  List<ServiceItem> get services => _services;

  List<EngineeringProject> _projects = [];
  List<EngineeringProject> get projects => _projects;

  final Map<int, List<ProjectUpdate>> _projectUpdates = {};

  List<ProjectUpdate> getUpdatesForProject(int projectId) {
    return _projectUpdates[projectId] ?? [];
  }

  List<PortfolioItem> _portfolio = [
    PortfolioItem(
      id: 101,
      title: "مشروع صب خرسانات وجمولونات لمجمع تجاري",
      category: "خرسانات وهياكل",
      description:
          "تنفيذ الصب المسلح للهيكل وتشييد الجمولونات المعدنية بمساحة 1200 م² في مدينة زليتن.",
      location: "زليتن - المنطقة الصناعية",
    ),
    PortfolioItem(
      id: 102,
      title: "تشطيب فاخر لشقة كاملة من الأول للآخر",
      category: "تشطيبات كاملة",
      description:
          "تشطيب عصري شامل السباكة، الكهرباء، الجبس بورد، الإضاءات المخفية والرخام.",
      location: "طرابلس - بن عاشور",
    ),
    PortfolioItem(
      id: 103,
      title: "رسم خرائط وتصميم 3D لفيلا طابقين",
      category: "تصاميم وخرائط",
      description:
          "إعداد المخططات الإنشائية والمعمارية ودراسة الأحمال وإظهار التصميم الخارجي.",
      location: "مصراتة - حي الأفكار",
    ),
  ];
  List<PortfolioItem> get portfolio => _portfolio;

  List<AppNotification> _notifications = [];
  List<AppNotification> get notifications => _notifications;
  int get unreadNotificationsCount =>
      _notifications.where((n) => !n.isRead).length;

  Map<String, String> _getHeaders() {
    final headers = <String, String>{
      "apikey": kSupabaseAnonKey,
      "Content-Type": "application/json",
    };
    if (_accessToken != null && _accessToken!.isNotEmpty) {
      headers["Authorization"] = "Bearer $_accessToken";
    }
    return headers;
  }

  Future<http.Response> _authenticatedRequest(
    Future<http.Response> Function(Map<String, String> headers) requestFn,
  ) async {
    var headers = _getHeaders();
    var res = await requestFn(headers);
    if (res.statusCode == 401 && _refreshToken != null) {
      final refreshed = await _refreshSession();
      if (refreshed) {
        headers = _getHeaders();
        res = await requestFn(headers);
      } else {
        await signOut();
      }
    }
    return res;
  }

  Future<bool> _refreshSession() async {
    if (_refreshToken == null) return false;
    try {
      final response = await http.post(
        Uri.parse("$kSupabaseUrl/auth/v1/token?grant_type=refresh_token"),
        headers: {
          "apikey": kSupabaseAnonKey,
          "Content-Type": "application/json",
        },
        body: jsonEncode({"refresh_token": _refreshToken}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];
        if (data['user'] != null && data['user']['id'] != null) {
          _userId = data['user']['id'];
        }
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', _accessToken!);
        if (_refreshToken != null) {
          await prefs.setString('refresh_token', _refreshToken!);
        }
        if (_userId != null) await prefs.setString('user_id', _userId!);
        return true;
      }
    } catch (_) {}
    return false;
  }

  Future<void> initSession() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    _refreshToken = prefs.getString('refresh_token');
    _userId = prefs.getString('user_id');
    _userEmail = prefs.getString('user_email');
    _isDarkMode = prefs.getBool('is_dark_mode') ?? false;

    if (_accessToken != null && _userId != null) {
      _isAuthenticated = true;
      await fetchUserProfile();
      await fetchProjectsFromSupabase();
      await fetchPortfolioFromSupabase();
      await fetchNotifications();
      _setupForegroundMessaging();
      _registerDeviceToken();
    }
    notifyListeners();
  }

  void _setupForegroundMessaging() {
    try {
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        final notification = message.notification;
        final title =
            notification?.title ?? message.data['title'] ?? 'إشعار جديد';
        final body = notification?.body ?? message.data['body'] ?? '';

        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.white)),
                if (body.isNotEmpty)
                  Text(body,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.white70)),
              ],
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            backgroundColor: const Color(0xFF0F4C81),
            action: SnackBarAction(
              label: 'فتح الحافظة',
              textColor: const Color(0xFFE38B29),
              onPressed: () {},
            ),
          ),
        );

        fetchNotifications();
      });
    } catch (_) {}
  }

  void toggleDarkMode(bool value) async {
    _isDarkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', value);
    notifyListeners();
  }

  void setNavIndex(int index) {
    _selectedNavIndex = index;
    notifyListeners();
  }

  Future<bool> sendOtp(String email) async {
    _setLoading(true);
    _userEmail = email;
    try {
      final response = await http.post(
        Uri.parse("$kSupabaseUrl/auth/v1/otp"),
        headers: {
          "apikey": kSupabaseAnonKey,
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "email": email,
          "create_user": true,
        }),
      );
      _setLoading(false);
      final ok = response.statusCode == 200 || response.statusCode == 201;
      authError = ok ? null : authErrorMessage(response);
      return ok;
    } catch (e) {
      _setLoading(false);
      authError = 'تأكد من اتصال الإنترنت وحاول مجدداً.';
      return false;
    }
  }

  Future<bool> verifyOtp(String email, String code) async {
    _setLoading(true);
    try {
      final response = await http.post(
        Uri.parse("$kSupabaseUrl/auth/v1/verify"),
        headers: {
          "apikey": kSupabaseAnonKey,
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "type": "email",
          "email": email,
          "token": code,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];
        _userId = data['user']?['id'];
        _userEmail = email;

        if (_userId != null) {
          _isAuthenticated = true;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('access_token', _accessToken!);
          if (_refreshToken != null) {
            await prefs.setString('refresh_token', _refreshToken!);
          }
          await prefs.setString('user_id', _userId!);
          await prefs.setString('user_email', _userEmail!);

          await fetchUserProfile();
          await fetchProjectsFromSupabase();
          await fetchPortfolioFromSupabase();
          await fetchNotifications();
          _setupForegroundMessaging();
          _registerDeviceToken();

          authError = null;
          _setLoading(false);
          return true;
        }
      }
      authError = authErrorMessage(response);
    } catch (_) {
      authError = 'تأكد من اتصال الإنترنت وحاول مجدداً.';
    }

    _setLoading(false);
    notifyListeners();
    return false;
  }

  Future<void> signOut() async {
    _isAuthenticated = false;
    _accessToken = null;
    _refreshToken = null;
    _userId = null;
    _userEmail = null;
    _projects.clear();
    _notifications.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_id');
    await prefs.remove('user_email');
    notifyListeners();
  }

  Future<void> fetchProjectsFromSupabase() async {
    if (_userId == null) return;
    try {
      final url =
          "$kSupabaseUrl/rest/v1/almadrar_projects?customer_id=eq.$_userId&order=created_at.desc";
      final response = await _authenticatedRequest(
          (headers) => http.get(Uri.parse(url), headers: headers));

      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        _projects = list.map((item) => EngineeringProject.fromJson(item)).toList();
        for (var p in _projects) {
          await fetchProjectUpdates(p.id);
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> fetchProjectUpdates(int projectId) async {
    try {
      final url =
          "$kSupabaseUrl/rest/v1/almadrar_project_updates?project_id=eq.$projectId&order=created_at.desc";
      final res = await _authenticatedRequest(
          (headers) => http.get(Uri.parse(url), headers: headers));
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        _projectUpdates[projectId] =
            list.map((item) => ProjectUpdate.fromJson(item)).toList();
      }
    } catch (_) {}
  }

  Future<void> fetchPortfolioFromSupabase() async {
    try {
      final url =
          "$kSupabaseUrl/rest/v1/almadrar_portfolio?order=created_at.desc";
      final res = await _authenticatedRequest(
          (headers) => http.get(Uri.parse(url), headers: headers));
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        if (list.isNotEmpty) {
          _portfolio =
              list.map((item) => PortfolioItem.fromJson(item)).toList();
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  Future<bool> createProjectRequest({
    required String serviceType,
    required double area,
    required String location,
    required String notes,
  }) async {
    _setLoading(true);
    try {
      final res = await _authenticatedRequest((headers) => http.post(
            Uri.parse("$kSupabaseUrl/rest/v1/almadrar_projects"),
            headers: headers..["Prefer"] = "return=representation",
            body: jsonEncode({
              if (_userId != null) "customer_id": _userId,
              "service_type": serviceType,
              "approximate_area": area,
              "location_details": location,
              "notes": notes,
              "status": "pending_inspection",
            }),
          ));

      if (res.statusCode == 200 || res.statusCode == 201) {
        final List list = jsonDecode(res.body);
        if (list.isNotEmpty) {
          final createdProject = EngineeringProject.fromJson(list[0]);
          _projects.insert(0, createdProject);

          await _authenticatedRequest((headers) => http.post(
                Uri.parse("$kSupabaseUrl/rest/v1/almadrar_notifications"),
                headers: headers,
                body: jsonEncode({
                  "to_role": "admin",
                  "title": "طلب معاينة جديد",
                  "body": "طلب جديد لخدمة $serviceType في $location",
                  "data": {"project_id": createdProject.id},
                }),
              ));

          _setLoading(false);
          notifyListeners();
          return true;
        }
      }
    } catch (_) {}

    _setLoading(false);
    notifyListeners();
    return false;
  }

  Future<void> acceptProjectCost(int projectId) async {
    final idx = _projects.indexWhere((p) => p.id == projectId);
    if (idx != -1) {
      final old = _projects[idx];
      try {
        final res = await _authenticatedRequest((headers) => http.patch(
              Uri.parse(
                  "$kSupabaseUrl/rest/v1/almadrar_projects?id=eq.$projectId"),
              headers: headers..["Prefer"] = "return=representation",
              body: jsonEncode({
                "customer_accepted": true,
                "status": "in_progress",
              }),
            ));

        if (res.statusCode == 200) {
          final List list = jsonDecode(res.body);
          if (list.isNotEmpty) {
            _projects[idx] = EngineeringProject.fromJson(list[0]);
          } else {
            _projects[idx] = EngineeringProject(
              id: old.id,
              requestCode: old.requestCode,
              customerId: old.customerId,
              serviceType: old.serviceType,
              approximateArea: old.approximateArea,
              locationDetails: old.locationDetails,
              notes: old.notes,
              status: "in_progress",
              estimatedCost: old.estimatedCost,
              costNotes: old.costNotes,
              customerAccepted: true,
              progressPercentage: old.progressPercentage,
              currentStage: "تمت الموافقة وجاري التجهيز",
              createdAt: old.createdAt,
            );
          }
          notifyListeners();

          await _authenticatedRequest((headers) => http.post(
                Uri.parse("$kSupabaseUrl/rest/v1/almadrar_notifications"),
                headers: headers,
                body: jsonEncode({
                  "to_role": "admin",
                  "title": "الموافقة على بدء التنفيذ",
                  "body": "وافق الزبون على تكلفة المشروع #${old.requestCode}",
                  "data": {"project_id": projectId},
                }),
              ));
        }
      } catch (_) {}
    }
  }

  Future<void> fetchNotifications() async {
    if (_userId == null) return;
    try {
      final url =
          "$kSupabaseUrl/rest/v1/almadrar_notifications?or=(to_user.eq.$_userId,to_role.eq.customer)&order=created_at.desc";
      final response = await _authenticatedRequest(
          (headers) => http.get(Uri.parse(url), headers: headers));

      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        _notifications =
            list.map((item) => AppNotification.fromJson(item)).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> markNotificationsAsRead([int? notificationId]) async {
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      if (notificationId != null) {
        final url =
            "$kSupabaseUrl/rest/v1/almadrar_notifications?id=eq.$notificationId";
        await _authenticatedRequest((headers) => http.patch(
              Uri.parse(url),
              headers: headers,
              body: jsonEncode({"read_at": nowIso}),
            ));
      } else {
        final url =
            "$kSupabaseUrl/rest/v1/almadrar_notifications?or=(to_user.eq.$_userId,to_role.eq.customer)&read_at=is.null";
        await _authenticatedRequest((headers) => http.patch(
              Uri.parse(url),
              headers: headers,
              body: jsonEncode({"read_at": nowIso}),
            ));
      }
      await fetchNotifications();
    } catch (_) {}
  }

  Future<void> fetchUserProfile() async {
    if (_userId == null) return;
    try {
      final response = await _authenticatedRequest((headers) => http.get(
            Uri.parse(
                "$kSupabaseUrl/rest/v1/almadrar_profiles?id=eq.$_userId"),
            headers: headers,
          ));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          _fullName = data[0]['full_name'] ?? _fullName;
          _phone = data[0]['phone'] ?? _phone;
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  Future<void> updateProfile(String name, String phone) async {
    _fullName = name;
    _phone = phone;
    notifyListeners();
    if (_userId == null) return;
    try {
      await _authenticatedRequest((headers) => http.patch(
            Uri.parse(
                "$kSupabaseUrl/rest/v1/almadrar_profiles?id=eq.$_userId"),
            headers: headers,
            body: jsonEncode({
              "full_name": name,
              "phone": phone,
            }),
          ));
    } catch (_) {}
  }

  Future<void> _registerDeviceToken() async {
    try {
      await FirebaseMessaging.instance.requestPermission();
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await _authenticatedRequest((headers) => http.post(
              Uri.parse("$kSupabaseUrl/rest/v1/rpc/almadrar_register_device"),
              headers: headers,
              body: jsonEncode({
                "device_token": token,
                "app_name": "customer",
              }),
            ));
      }
    } catch (_) {}
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}

// ============================================================================
// MAIN APP ENTRY & THEME
// ============================================================================
class AlMadrarCustomerApp extends StatelessWidget {
  const AlMadrarCustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppStateProvider>(context);

    final lightScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F4C81),
      primary: const Color(0xFF0F4C81),
      secondary: const Color(0xFFE38B29),
      tertiary: const Color(0xFF2D6A4F),
      surface: const Color(0xFFF8F9FE),
    );

    final darkScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F4C81),
      brightness: Brightness.dark,
      primary: const Color(0xFFA2C8FF),
      secondary: const Color(0xFFFFB77C),
      tertiary: const Color(0xFFB7F0CE),
      surface: const Color(0xFF111318),
    );

    return MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      title: 'المدرار للمقاولات الهندسية',
      debugShowCheckedModeBanner: false,
      useInheritedMediaQuery: true,
      themeMode: state.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightScheme,
        scaffoldBackgroundColor: lightScheme.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: lightScheme.surface,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: lightScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkScheme,
        scaffoldBackgroundColor: darkScheme.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: darkScheme.surface,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: darkScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: state.isAuthenticated
            ? const MainShellScreen()
            : const AuthScreen(),
      ),
    );
  }
}

// ============================================================================
// AUTHENTICATION SCREEN (LOGIN & SIGNUP WITH 6-DIGIT OTP)
// ============================================================================
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool otpSent = false;
  int cooldownSeconds = 0;
  Timer? cooldownTimer;

  final emailCtrl = TextEditingController(text: "client@almidrar.ly");
  final nameCtrl = TextEditingController(text: "محمد علي المهدي");

  final List<TextEditingController> otpCtrls =
      List.generate(6, (_) => TextEditingController());

  @override
  void dispose() {
    cooldownTimer?.cancel();
    for (var c in otpCtrls) {
      c.dispose();
    }
    emailCtrl.dispose();
    nameCtrl.dispose();
    super.dispose();
  }

  void startCooldownTimer() {
    setState(() => cooldownSeconds = 60);
    cooldownTimer?.cancel();
    cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (cooldownSeconds > 0) {
        setState(() => cooldownSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<AppStateProvider>(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.architecture_outlined,
                    size: 44,
                    color: theme.colorScheme.primary,
                  ),
                ).animate().scale(duration: 400.ms),
                const SizedBox(height: 16),
                Text(
                  "المدرار للمقاولات الهندسية",
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "تسجيل الدخول عبر البريد الإلكتروني ورمز OTP",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),

                AnimatedCrossFade(
                  duration: 300.ms,
                  crossFadeState: !otpSent
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  firstChild: Column(
                    children: [
                      TextField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: "البريد الإلكتروني",
                          prefixIcon: const Icon(Icons.email_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: provider.isLoading
                              ? null
                              : () async {
                                  final email = emailCtrl.text.trim();
                                  if (email.isEmpty || !email.contains('@')) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            "يرجى إدخال بريد إلكتروني صحيح"),
                                      ),
                                    );
                                    return;
                                  }
                                  final success =
                                      await provider.sendOtp(email);
                                  if (success) {
                                    setState(() => otpSent = true);
                                    startCooldownTimer();
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              "تم إرسال رمز التأكيد. تحقق من صندوق الوارد في بريدك."),
                                        ),
                                      );
                                    }
                                  } else if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(provider.authError ??
                                            "عذراً، فشل إرسال الرمز"),
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          icon: provider.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_outlined),
                          label: const Text(
                            "إرسال رمز التأكيد (6 أرقام)",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  secondChild: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer
                              .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.mark_email_read_outlined,
                                color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "تحقق من صندوق الوارد في بريدك الإلكتروني:\n${emailCtrl.text}",
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(
                            6,
                            (index) => SizedBox(
                              width: 44,
                              height: 56,
                              child: TextField(
                                controller: otpCtrls[index],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                maxLength: 1,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                                decoration: InputDecoration(
                                  counterText: "",
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: theme.colorScheme.primary,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                onChanged: (val) {
                                  if (val.isNotEmpty && index < 5) {
                                    FocusScope.of(context).nextFocus();
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: provider.isLoading
                              ? null
                              : () async {
                                  final code =
                                      otpCtrls.map((c) => c.text).join();
                                  if (code.length < 6) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            "يرجى إدخال رمز التأكيد كاملاً (6 أرقام)"),
                                      ),
                                    );
                                    return;
                                  }
                                  final verified = await provider.verifyOtp(
                                    emailCtrl.text.trim(),
                                    code,
                                  );
                                  if (!verified && mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(provider.authError ??
                                            "رمز التأكيد غير صحيح"),
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: provider.isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : const Text(
                                  "تأكيد وفتح الحساب",
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () => setState(() => otpSent = false),
                            child: const Text("تعديل البريد"),
                          ),
                          TextButton(
                            onPressed: (cooldownSeconds > 0 || provider.isLoading)
                                ? null
                                : () async {
                                    final success = await provider
                                        .sendOtp(emailCtrl.text.trim());
                                    if (success) {
                                      startCooldownTimer();
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                "تمت إعادة إرسال الرمز. تحقق من صندوق الوارد"),
                                          ),
                                        );
                                      }
                                    }
                                  },
                            child: Text(
                              cooldownSeconds > 0
                                  ? "إعادة الإرسال بعد ($cooldownSeconds)"
                                  : "إعادة إرسال الرمز",
                              style: TextStyle(
                                fontWeight: cooldownSeconds == 0
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
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

// ============================================================================
// MAIN APPLICATION SHELL & NAVIGATION
// ============================================================================
class MainShellScreen extends StatelessWidget {
  const MainShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppStateProvider>(context);

    final List<Widget> screens = [
      const HomeScreen(),
      const MyProjectsScreen(),
      const PortfolioScreen(),
      const ProfileScreen(),
    ];

    final List<String> titles = [
      "المدرار للمقاولات الهندسية",
      "مشاريعي وطلباتي",
      "معرض الأعمال السابقة",
      "الملف الشخصي والإعدادات",
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.engineering_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              titles[provider.selectedNavIndex],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  );
                },
              ),
              if (provider.unreadNotificationsCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '${provider.unreadNotificationsCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: screens[provider.selectedNavIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: provider.selectedNavIndex,
        onDestinationSelected: (idx) => provider.setNavIndex(idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: "الرئيسية",
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            selectedIcon: Icon(Icons.assignment),
            label: "مشاريعي",
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_library_outlined),
            selectedIcon: Icon(Icons.photo_library),
            label: "المعرض",
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: "حسابي",
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 1. HOME SCREEN
// ============================================================================
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<AppStateProvider>(context);

    final activeProjects =
        provider.projects.where((p) => p.status != 'completed').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withValues(alpha: 0.85),
                  ],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          "شركة المقاولات المعتمدة",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.construction,
                        color: theme.colorScheme.secondary,
                        size: 32,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "المدرار للمقاولات الهندسية",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "تصميم، صب خرسانات، تشطيبات متكاملة، ورسم خرائط بأعلى دقة هندسية.",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NewProjectRequestScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.secondary,
                      foregroundColor: theme.colorScheme.onSecondary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text(
                      "اطلب معاينة مشروعك الآن",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fadeIn(duration: 400.ms),

          const SizedBox(height: 20),

          if (activeProjects.isNotEmpty) ...[
            GestureDetector(
              onTap: () => provider.setNavIndex(1),
              child: Card(
                color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: theme.colorScheme.secondary,
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.engineering,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "مشروع نشط: ${activeProjects.first.serviceType}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              "حالة الإنجاز: ${activeProjects.first.progressPercentage}% - ${activeProjects.first.currentStage}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "خدماتنا الهندسية والتنفيذية",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Chip(
                label: Text(
                  "${provider.services.length} خدمات",
                  style: const TextStyle(fontSize: 11),
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 12),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.25,
            ),
            itemCount: provider.services.length,
            itemBuilder: (context, idx) {
              final service = provider.services[idx];
              return Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ServiceDetailScreen(service: service),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            service.icon,
                            color: theme.colorScheme.primary,
                            size: 24,
                          ),
                        ),
                        Text(
                          service.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              service.category,
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => provider.setNavIndex(2),
              child: Container(
                height: 120,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1D5D9B),
                      theme.colorScheme.primary,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            "معرض المشاريع والأعمال السابقة",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "استعرض نماذج لصب الخرسانات والتشطيبات التي نفذتها الشركة",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.collections_outlined,
                      color: Colors.white,
                      size: 40,
                    ),
                  ],
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
// 2. SERVICE DETAIL SCREEN
// ============================================================================
class ServiceDetailScreen extends StatelessWidget {
  final ServiceItem service;

  const ServiceDetailScreen({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(service.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Icon(service.icon, size: 56, color: theme.colorScheme.primary),
                  const SizedBox(height: 12),
                  Text(
                    service.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Chip(
                    label: Text(service.category),
                    backgroundColor: theme.colorScheme.surface,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text(
              "نبذة عن الخدمة:",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              service.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.6,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            Text(
              "خطوات ومراحل تنفيذ العمل:",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: service.workflowSteps.length,
              itemBuilder: (context, idx) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.secondaryContainer,
                      child: Text(
                        "${idx + 1}",
                        style: TextStyle(
                          color: theme.colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      service.workflowSteps[idx],
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NewProjectRequestScreen(
                        preselectedService: service.title,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                icon: const Icon(Icons.edit_note_outlined),
                label: const Text(
                  "طلب هذه الخدمة وتحديد موعد معاينة",
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

// ============================================================================
// 3. NEW PROJECT REQUEST SCREEN
// ============================================================================
class NewProjectRequestScreen extends StatefulWidget {
  final String? preselectedService;

  const NewProjectRequestScreen({super.key, this.preselectedService});

  @override
  State<NewProjectRequestScreen> createState() =>
      _NewProjectRequestScreenState();
}

class _NewProjectRequestScreenState extends State<NewProjectRequestScreen> {
  late String selectedService;
  final areaCtrl = TextEditingController(text: "150");
  final locationCtrl = TextEditingController(text: "طرابلس - عين زارة");
  final notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    selectedService =
        widget.preselectedService ?? "شغل شقة كاملة جاهزة بالتشطيب";
  }

  @override
  void dispose() {
    areaCtrl.dispose();
    locationCtrl.dispose();
    notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<AppStateProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("تقديم طلب مشروع جديد"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "حدد تفاصيل الخدمة المطلوبة للمعاينة الميدانية:",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),

            DropdownButtonFormField<String>(
              initialValue: selectedService,
              decoration: InputDecoration(
                labelText: "نوع الخدمة الهندسية",
                prefixIcon: const Icon(Icons.build_circle_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: provider.services.map((s) {
                return DropdownMenuItem<String>(
                  value: s.title,
                  child: Text(s.title, style: const TextStyle(fontSize: 14)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => selectedService = val);
                }
              },
            ),
            const SizedBox(height: 16),

            TextField(
              controller: areaCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "المساحة التقريبية (متر مربع)",
                prefixIcon: const Icon(Icons.square_foot_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: locationCtrl,
              decoration: InputDecoration(
                labelText: "عنوان وموقع المشروع التفصيلي",
                prefixIcon: const Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: notesCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: "ملاحظات وتفاصيل إضافية للعميل (اختياري)",
                alignLabelWithHint: true,
                prefixIcon: const Icon(Icons.description_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: provider.isLoading
                    ? null
                    : () async {
                        final area = double.tryParse(areaCtrl.text) ?? 0.0;
                        final loc = locationCtrl.text.trim();
                        if (loc.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("يرجى كتابة عنوان المشروع"),
                            ),
                          );
                          return;
                        }

                        final success = await provider.createProjectRequest(
                          serviceType: selectedService,
                          area: area,
                          location: loc,
                          notes: notesCtrl.text.trim(),
                        );

                        if (mounted) {
                          if (success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    "تم تقديم طلب المعاينة بنجاح. سيتم التواصل معكم عبر مهندسينا."),
                              ),
                            );
                            Navigator.pop(context);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("عذراً، تعذر تقديم الطلب حالياً"),
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                icon: provider.isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Icon(Icons.check_circle_outline),
                label: const Text(
                  "تأكيد إرسال الطلب للمعاينة",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
// 4. MY PROJECTS SCREEN
// ============================================================================
class MyProjectsScreen extends StatefulWidget {
  const MyProjectsScreen({super.key});

  @override
  State<MyProjectsScreen> createState() => _MyProjectsScreenState();
}

class _MyProjectsScreenState extends State<MyProjectsScreen> {
  String selectedFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<AppStateProvider>(context);

    final filteredProjects = provider.projects.where((p) {
      if (selectedFilter == 'pending') return p.status == 'pending_inspection';
      if (selectedFilter == 'cost') return p.status == 'cost_assigned';
      if (selectedFilter == 'progress') return p.status == 'in_progress';
      if (selectedFilter == 'completed') return p.status == 'completed';
      return true;
    }).toList();

    return Column(
      children: [
        // Filter Chips Bar
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              FilterChip(
                label: const Text("الكل"),
                selected: selectedFilter == 'all',
                onSelected: (_) => setState(() => selectedFilter = 'all'),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text("قيد المعاينة"),
                selected: selectedFilter == 'pending',
                onSelected: (_) => setState(() => selectedFilter = 'pending'),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text("بانتظار موافقتك"),
                selected: selectedFilter == 'cost',
                onSelected: (_) => setState(() => selectedFilter = 'cost'),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text("جاري التنفيذ"),
                selected: selectedFilter == 'progress',
                onSelected: (_) => setState(() => selectedFilter = 'progress'),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text("مكتملة"),
                selected: selectedFilter == 'completed',
                onSelected: (_) => setState(() => selectedFilter = 'completed'),
              ),
            ],
          ),
        ),

        Expanded(
          child: RefreshIndicator(
            onRefresh: () => provider.fetchProjectsFromSupabase(),
            child: filteredProjects.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_late_outlined,
                            size: 64, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(height: 12),
                        const Text(
                          "لا توجد مشاريع أو طلبات في هذه القائمة",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredProjects.length,
                    itemBuilder: (context, idx) {
                      final project = filteredProjects[idx];
                      return _buildProjectCard(context, theme, provider, project);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildProjectCard(
    BuildContext context,
    ThemeData theme,
    AppStateProvider provider,
    EngineeringProject project,
  ) {
    Color statusColor;
    String statusText;

    switch (project.status) {
      case 'cost_assigned':
        statusColor = Colors.orange;
        statusText = "تم تحديد التكلفة - بانتظار موافقتك";
        break;
      case 'in_progress':
        statusColor = theme.colorScheme.primary;
        statusText = "جاري التنفيذ";
        break;
      case 'completed':
        statusColor = Colors.green;
        statusText = "مكتمل ومسلم";
        break;
      case 'pending_inspection':
      default:
        statusColor = Colors.blue;
        statusText = "قيد المعاينة الفنية";
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProjectDetailScreen(project: project),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    project.requestCode,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                      fontSize: 13,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                project.serviceType,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.location_on_outlined,
                      size: 14, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    project.locationDetails,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    "${project.approximateArea} م²",
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (project.status == 'in_progress' ||
                  project.status == 'completed') ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "المرحلة الحالية: ${project.currentStage}",
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "${project.progressPercentage}%",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: project.progressPercentage / 100.0,
                  borderRadius: BorderRadius.circular(4),
                  minHeight: 6,
                ),
              ],

              if (project.status == 'cost_assigned' &&
                  !project.customerAccepted) ...[
                const Divider(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "التكلفة التقديرية المحددة:",
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "${intl.NumberFormat('#,###').format(project.estimatedCost ?? 0)} د.ل",
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      if (project.costNotes != null &&
                          project.costNotes!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          "تفاصيل: ${project.costNotes}",
                          style: const TextStyle(fontSize: 11),
                        ),
                      ],
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton(
                          onPressed: () {
                            provider.acceptProjectCost(project.id);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.secondary,
                            foregroundColor: theme.colorScheme.onSecondary,
                          ),
                          child: const Text(
                            "الموافقة على بدء التنفيذ والبدء بالمشروع",
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 5. PROJECT DETAIL & TIMELINE SCREEN
// ============================================================================
class ProjectDetailScreen extends StatelessWidget {
  final EngineeringProject project;

  const ProjectDetailScreen({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<AppStateProvider>(context);
    final updates = provider.getUpdatesForProject(project.id);

    return Scaffold(
      appBar: AppBar(
        title: Text("تفاصيل مشروع ${project.requestCode}"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info Card
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.serviceType,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            project.locationDetails,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.square_foot_outlined, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          "المساحة: ${project.approximateArea} م²",
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                    if (project.estimatedCost != null) ...[
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("التكلفة المعتمدة:"),
                          Text(
                            "${intl.NumberFormat('#,###').format(project.estimatedCost)} د.ل",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              "جدول التحديثات الميدانية من المهندس المشرف:",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            updates.isEmpty
                ? Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Center(
                        child: Text(
                          "لم تدرج تحديثات جديدة بعد من المهندس المسؤول",
                          style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: updates.length,
                    itemBuilder: (context, idx) {
                      final update = updates[idx];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    update.stageTitle,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Chip(
                                    label: Text("${update.progressPercentage}%"),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ],
                              ),
                              if (update.engineerNotes.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  update.engineerNotes,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 6),
                              Text(
                                intl.DateFormat('yyyy/MM/dd - hh:mm a')
                                    .format(update.createdAt),
                                style: const TextStyle(
                                    fontSize: 10, color: Colors.grey),
                              ),
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

// ============================================================================
// 6. PORTFOLIO SCREEN
// ============================================================================
class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<AppStateProvider>(context);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.portfolio.length,
      itemBuilder: (context, idx) {
        final item = provider.portfolio[idx];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 140,
                width: double.infinity,
                color: theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.architecture,
                  size: 64,
                  color: theme.colorScheme.primary,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Chip(
                          label: Text(item.category),
                          visualDensity: VisualDensity.compact,
                        ),
                        Row(
                          children: [
                            Icon(Icons.location_on,
                                size: 14,
                                color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              item.location,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// 7. PROFILE & SETTINGS SCREEN
// ============================================================================
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController nameCtrl;
  late TextEditingController phoneCtrl;

  @override
  void initState() {
    super.initState();
    final p = Provider.of<AppStateProvider>(context, listen: false);
    nameCtrl = TextEditingController(text: p.fullName);
    phoneCtrl = TextEditingController(text: p.phone);
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<AppStateProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(Icons.person, size: 48, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: 12),
          Text(
            provider.fullName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            provider.userEmail ?? "",
            style: TextStyle(
                fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),

          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "تعديل المعلومات الشخصية:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: "الاسم الكامل",
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: "رقم الهاتف للتواصل",
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        await provider.updateProfile(
                          nameCtrl.text.trim(),
                          phoneCtrl.text.trim(),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("تم حفظ البيانات الشخصية بنجاح"),
                            ),
                          );
                        }
                      },
                      child: const Text("حفظ البيانات"),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text("الوضع الداكن (Dark Mode)"),
                  value: provider.isDarkMode,
                  onChanged: (val) => provider.toggleDarkMode(val),
                  secondary: const Icon(Icons.dark_mode_outlined),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text(
                    "تسجيل الخروج",
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                  onTap: () => provider.signOut(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 8. NOTIFICATIONS SCREEN
// ============================================================================
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<AppStateProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("الإشعارات والتنبيهات"),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: "تحديد الكل كمقروء",
            onPressed: () => provider.markNotificationsAsRead(),
          ),
        ],
      ),
      body: provider.notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined,
                      size: 64, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  const Text("لا توجد إشعارات حالية في الحافظة"),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.notifications.length,
              itemBuilder: (context, idx) {
                final notif = provider.notifications[idx];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  color: notif.isRead
                      ? theme.colorScheme.surface
                      : theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  child: ListTile(
                    leading: Icon(
                      notif.isRead
                          ? Icons.notifications_none
                          : Icons.notifications_active,
                      color: theme.colorScheme.primary,
                    ),
                    title: Text(
                      notif.title,
                      style: TextStyle(
                        fontWeight:
                            notif.isRead ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(notif.body),
                        const SizedBox(height: 4),
                        Text(
                          intl.DateFormat('yyyy/MM/dd - hh:mm a')
                              .format(notif.createdAt),
                          style: const TextStyle(
                              fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ),
                    onTap: () => provider.markNotificationsAsRead(notif.id),
                  ),
                );
              },
            ),
    );
  }
}
