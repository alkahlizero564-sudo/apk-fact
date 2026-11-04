import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' as intl;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_config.dart';

// ============================================================================
// CONSTANTS & SUPABASE CONFIG
// ============================================================================
const String kSupabaseUrl = "https://jvjtgzewumfecjdpekna.supabase.co";
const String kSupabaseAnonKey =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp2anRnemV3dW1mZWNqZHBla25hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE2NDYzMzcsImV4cCI6MjEwNzIyMjMzN30.1gck73ek8ErBtcF7xAtFM1TdvNim_1NzFVNej_mptBE";

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
    debugPrint("Firebase init deferred or skipped: $e");
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
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
    required this.createdAt,
  });
}

// ============================================================================
// APP STATE & SUPABASE PROVIDER
// ============================================================================

/// The server's reason, in Arabic, when sending or checking the sign-in code fails.
String authErrorMessage(http.Response r) {
  try {
    final d = jsonDecode(r.body);
    final m = (d['msg'] ?? d['error_description'] ?? d['message'] ?? d['error'] ?? '').toString();
    final low = m.toLowerCase();
    if (low.contains('rate limit') || r.statusCode == 429) {
      return 'اتبعتت رسائل كتير للبريد ده. استنى دقايق وجرّب تاني.';
    }
    if (low.contains('expired') || low.contains('invalid') || low.contains('token')) {
      return 'الرمز غلط أو انتهت صلاحيته. اطلب رمز جديد.';
    }
    return m.isEmpty ? 'حصل خطأ من السيرفر (${r.statusCode})' : m;
  } catch (_) {
    return 'حصل خطأ من السيرفر (${r.statusCode})';
  }
}

class AppStateProvider extends ChangeNotifier {
  String? authError; // why sending/checking the code failed (shown to the user)

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  String? _accessToken;
  String? _refreshToken;
  String? _userId;
  String? _userEmail;
  String _fullName = "محمد علي المهدي";
  String _phone = "0912345678";
  bool _isAuthenticated = false;

  bool get isAuthenticated => _isAuthenticated;
  String? get userEmail => _userEmail;
  String get fullName => _fullName;
  String get phone => _phone;

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
        " تركيب الأرضيات والأبواب والنوافذ",
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

  // Active User Projects
  final List<EngineeringProject> _projects = [
    EngineeringProject(
      id: 1084,
      requestCode: "REQ-1084",
      customerId: "user-1",
      serviceType: "شغل شقة كاملة جاهزة بالتشطيب",
      approximateArea: 165.0,
      locationDetails: "طرابلس - عين زارة بالقرب من النوفليين",
      notes: "يرجى اختيار ألوان دافئة واستخدام السيراميك الإسباني",
      status: "cost_assigned",
      estimatedCost: 42500.0,
      costNotes: "يشمل توريد السباكة والكهرباء والدهان الإيطالي والأرضيات",
      customerAccepted: false,
      progressPercentage: 20,
      currentStage: "تم تحديد التكلفة بانتظار موافقة الزبون",
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    EngineeringProject(
      id: 1012,
      requestCode: "REQ-1012",
      customerId: "user-1",
      serviceType: "صب خرسانات وصب عمدان",
      approximateArea: 220.0,
      locationDetails: "بنغازي - حي الهواري",
      notes: "الفيلا طابقين، البدء بالطابق الأرضي والأعمدة",
      status: "in_progress",
      estimatedCost: 68000.0,
      costNotes: "الخرسانة الجاهزة إجهاد 350 كجم/سم² مع حديد 16 ملم",
      customerAccepted: true,
      progressPercentage: 65,
      currentStage: "جاري صب الأعمدة واختبار الخرسانة",
      createdAt: DateTime.now().subtract(const Duration(days: 14)),
    ),
  ];

  List<EngineeringProject> get projects => _projects;

  // Project Stage Updates mock data
  final Map<int, List<ProjectUpdate>> _projectUpdates = {
    1012: [
      ProjectUpdate(
        id: 1,
        projectId: 1012,
        stageTitle: "الانتهاء من صب الأعمدة وتغليفها",
        progressPercentage: 65,
        engineerNotes:
            "تم صب جميع أعمدة الطابق الأرضي بنجاح، والرش بالماء مستمر لضمان أقصى صلابة.",
        images: ["https://picsum.photos/400/300?random=1"],
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      ProjectUpdate(
        id: 2,
        projectId: 1012,
        stageTitle: "تثبيت أقفاص حديد التسليح",
        progressPercentage: 40,
        engineerNotes:
            "قام المهندس الفني بمسح المحاور وتثبيت أقفاص الحديد وفق المخطط الإنشائي.",
        images: ["https://picsum.photos/400/300?random=2"],
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
    ],
  };

  List<ProjectUpdate> getUpdatesForProject(int projectId) {
    return _projectUpdates[projectId] ?? [];
  }

  // Portfolio items mock catalog
  final List<PortfolioItem> _portfolio = [
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

  // Notifications List
  final List<AppNotification> _notifications = [
    AppNotification(
      id: "n1",
      title: "تحديد تكلفة المعاينة",
      body:
          "تم تحديد تكلفة مشروع 'شغل شقة كاملة جاهزة بالتشطيب' بقيمة 42,500 د.ل. يمكنك المراجعة والموافقة الآن.",
      isRead: false,
      createdAt: DateTime.now().subtract(const Duration(minutes: 25)),
    ),
    AppNotification(
      id: "n2",
      title: "تحديث ميداني جديد",
      body:
          "قام المهندس المشرف بإضافة تقرير مصور جديد لمرحلة صب الأعمدة بالموقع.",
      isRead: true,
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
  ];

  List<AppNotification> get notifications => _notifications;
  int get unreadNotificationsCount =>
      _notifications.where((n) => !n.isRead).length;

  // Initialize stored session
  Future<void> initSession() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    _refreshToken = prefs.getString('refresh_token');
    _userId = prefs.getString('user_id');
    _userEmail = prefs.getString('user_email');
    _isDarkMode = prefs.getBool('is_dark_mode') ?? false;

    if (_accessToken != null && _userId != null) {
      _isAuthenticated = true;
      fetchUserProfile();
      fetchProjectsFromSupabase();
    }
    notifyListeners();
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

  // Auth: Send OTP via Supabase API
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
      authError = 'تأكد من اتصال الإنترنت وجرّب تاني.';
      return false;
    }
  }

  // Auth: Verify 6-digit OTP code
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
        _userId = data['user']?['id'] ?? const Uuid().v4();
        _userEmail = email;
        _isAuthenticated = true;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', _accessToken!);
        await prefs.setString('refresh_token', _refreshToken!);
        await prefs.setString('user_id', _userId!);
        await prefs.setString('user_email', _userEmail!);

        _registerDeviceToken();
        authError = null;
        _setLoading(false);
        return true;
      }
      authError = authErrorMessage(response);
    } catch (_) {
      authError = 'تأكد من اتصال الإنترنت وجرّب تاني.';
    }

    // Never signed in without a real session from the server.
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_id');
    await prefs.remove('user_email');
    notifyListeners();
  }

  // Fetch Projects from Supabase REST
  Future<void> fetchProjectsFromSupabase() async {
    if (_userId == null) return;
    try {
      final url =
          "$kSupabaseUrl/rest/v1/almadrar_projects?customer_id=eq.$_userId&order=created_at.desc";
      final response = await http.get(
        Uri.parse(url),
        headers: {
          "apikey": kSupabaseAnonKey,
          if (_accessToken != null) "Authorization": "Bearer $_accessToken",
        },
      );

      if (response.statusCode == 200) {
        final List list = jsonDecode(response.body);
        if (list.isNotEmpty) {
          _projects.clear();
          for (var item in list) {
            _projects.add(EngineeringProject.fromJson(item));
          }
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  // Submit New Engineering Project Request
  Future<bool> createProjectRequest({
    required String serviceType,
    required double area,
    required String location,
    required String notes,
  }) async {
    _setLoading(true);
    final newId = 1000 + _projects.length + 1;
    final newProject = EngineeringProject(
      id: newId,
      requestCode: "REQ-$newId",
      customerId: _userId ?? "user-demo",
      serviceType: serviceType,
      approximateArea: area,
      locationDetails: location,
      notes: notes,
      status: "pending_inspection",
      customerAccepted: false,
      progressPercentage: 0,
      currentStage: "قيد المراجعة وحجز موعد المعاينة الميدانية",
      createdAt: DateTime.now(),
    );

    _projects.insert(0, newProject);

    // Try posting to Supabase REST
    try {
      await http.post(
        Uri.parse("$kSupabaseUrl/rest/v1/almadrar_projects"),
        headers: {
          "apikey": kSupabaseAnonKey,
          if (_accessToken != null) "Authorization": "Bearer $_accessToken",
          "Content-Type": "application/json",
          "Prefer": "return=representation",
        },
        body: jsonEncode({
          "request_code": newProject.requestCode,
          if (_userId != null) "customer_id": _userId,
          "service_type": serviceType,
          "approximate_area": area,
          "location_details": location,
          "notes": notes,
          "status": "pending_inspection",
        }),
      );

      // Send Notification to Admin
      await http.post(
        Uri.parse("$kSupabaseUrl/rest/v1/almadrar_notifications"),
        headers: {
          "apikey": kSupabaseAnonKey,
          if (_accessToken != null) "Authorization": "Bearer $_accessToken",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "to_role": "admin",
          "title": "طلب معاينة جديد",
          "body": "طلب جديد لخدمة $serviceType في $location",
          "data": {"project_id": newId},
        }),
      );
    } catch (_) {}

    _setLoading(false);
    notifyListeners();
    return true;
  }

  // Accept Project Cost by Customer
  Future<void> acceptProjectCost(int projectId) async {
    final idx = _projects.indexWhere((p) => p.id == projectId);
    if (idx != -1) {
      final old = _projects[idx];
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
        progressPercentage: 10,
        currentStage: "تمت الموافقة وجاري توريد المواد وتجهيز الموقع",
        createdAt: old.createdAt,
      );
      notifyListeners();

      // Update Supabase REST
      try {
        await http.patch(
          Uri.parse("$kSupabaseUrl/rest/v1/almadrar_projects?id=eq.$projectId"),
          headers: {
            "apikey": kSupabaseAnonKey,
            if (_accessToken != null) "Authorization": "Bearer $_accessToken",
            "Content-Type": "application/json",
          },
          body: jsonEncode({
            "customer_accepted": true,
            "status": "in_progress",
          }),
        );

        // Notify Admin
        await http.post(
          Uri.parse("$kSupabaseUrl/rest/v1/almadrar_notifications"),
          headers: {
            "apikey": kSupabaseAnonKey,
            if (_accessToken != null) "Authorization": "Bearer $_accessToken",
            "Content-Type": "application/json",
          },
          body: jsonEncode({
            "to_role": "admin",
            "title": "الموافقة على بدء التنفيذ",
            "body": "وافق الزبون على تكلفة المشروع #${old.requestCode}",
            "data": {"project_id": projectId},
          }),
        );
      } catch (_) {}
    }
  }

  void markNotificationsAsRead() {
    for (int i = 0; i < _notifications.length; i++) {
      _notifications[i] = AppNotification(
        id: _notifications[i].id,
        title: _notifications[i].title,
        body: _notifications[i].body,
        isRead: true,
        createdAt: _notifications[i].createdAt,
      );
    }
    notifyListeners();
  }

  Future<void> fetchUserProfile() async {
    if (_userId == null) return;
    try {
      final response = await http.get(
        Uri.parse("$kSupabaseUrl/rest/v1/almadrar_profiles?id=eq.$_userId"),
        headers: {
          "apikey": kSupabaseAnonKey,
          if (_accessToken != null) "Authorization": "Bearer $_accessToken",
        },
      );
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
      await http.patch(
        Uri.parse("$kSupabaseUrl/rest/v1/almadrar_profiles?id=eq.$_userId"),
        headers: {
          "apikey": kSupabaseAnonKey,
          if (_accessToken != null) "Authorization": "Bearer $_accessToken",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "full_name": name,
          "phone": phone,
        }),
      );
    } catch (_) {}
  }

  Future<void> _registerDeviceToken() async {
    try {
      await FirebaseMessaging.instance.requestPermission(); // Android 13+ shows pushes only after this
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await http.post(
          Uri.parse("$kSupabaseUrl/rest/v1/rpc/almadrar_register_device"),
          headers: {
            "apikey": kSupabaseAnonKey,
            if (_accessToken != null) "Authorization": "Bearer $_accessToken",
            "Content-Type": "application/json",
          },
          body: jsonEncode({
            "device_token": token,
            "app_name": "customer",
          }),
        );
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

    // M3 Professional Palette (Engineering Trust & Warm Construction Gold)
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
      title: 'المدرار للمقاولات الهندسية',
      debugShowCheckedModeBanner: false,
      useInheritedMediaQuery: true,
      themeMode: state.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightScheme,
        fontFamily: 'Segoe UI',
        scaffoldBackgroundColor: lightScheme.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: lightScheme.surface,
          elevation: 0,
          titleTextStyle: TextStyle(color: lightScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkScheme,
        fontFamily: 'Segoe UI',
        scaffoldBackgroundColor: darkScheme.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: darkScheme.surface,
          elevation: 0,
          titleTextStyle: TextStyle(color: darkScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold),
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
  bool isSignUp = false;
  bool otpSent = false;

  final emailCtrl = TextEditingController(text: "client@almidrar.ly");
  final nameCtrl = TextEditingController(text: "محمد علي المهدي");
  final passCtrl = TextEditingController(text: "12345678");

  final List<TextEditingController> otpCtrls =
      List.generate(6, (_) => TextEditingController());

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
                // Header Branding
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
                  isSignUp
                      ? "إنشاء حساب جديد لتتابع مشروعاتك المعمارية"
                      : "تسجيل الدخول عبر البريد الإلكتروني ورمز OTP",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),

                // Form Container
                AnimatedCrossFade(
                  duration: 300.ms,
                  crossFadeState: !otpSent
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  firstChild: Column(
                    children: [
                      if (isSignUp) ...[
                        TextField(
                          controller: nameCtrl,
                          decoration: InputDecoration(
                            labelText: "الاسم الكامل",
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
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
                      const SizedBox(height: 16),
                      if (isSignUp) ...[
                        TextField(
                          controller: passCtrl,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: "كلمة المرور",
                            prefixIcon: const Icon(Icons.lock_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: provider.isLoading
                              ? null
                              : () async {
                                  final success = await provider
                                      .sendOtp(emailCtrl.text.trim());
                                  if (success) {
                                    setState(() => otpSent = true);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              "تم إرسال رمز التأكيد (6 أرقام) إلى بريدك الإلكتروني"),
                                        ),
                                      );
                                    }
                                  } else if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(provider.authError ?? "ما قدرنا نرسل الرمز")),
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
                          label: Text(
                            isSignUp
                                ? "استلام رمز التأكيد والتسجيل"
                                : "إرسال رمز التأكيد (6 أرقام)",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  secondChild: Column(
                    children: [
                      Text(
                        "أدخل رمز التأكيد المكون من 6 أرقام المرسل إلى:\n${emailCtrl.text}",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      // 6 Digit OTP input boxes
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
                      const SizedBox(height: 24),
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
                                      const SnackBar(content: Text("اكتب الرمز كامل (6 أرقام) اللي وصلك على البريد")),
                                    );
                                    return;
                                  }
                                  final verified = await provider.verifyOtp(
                                    emailCtrl.text.trim(),
                                    code,
                                  );
                                  if (!verified && mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(provider.authError ?? "الرمز غلط")),
                                    );
                                  }
                                  if (verified && isSignUp) {
                                    provider.updateProfile(
                                        nameCtrl.text, "0912345678");
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: const Text(
                            "تأكيد وفتح الحساب",
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() => otpSent = false),
                        child: const Text("تعديل البريد الإلكتروني"),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(isSignUp
                        ? "لديك حساب بالفعل؟"
                        : "ليس لديك حساب زبون؟"),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          isSignUp = !isSignUp;
                          otpSent = false;
                        });
                      },
                      child: Text(
                        isSignUp ? "تسجيل الدخول" : "إنشاء حساب جديد",
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
// 1. HOME SCREEN (خدمات شركة المدرار الـ 12 ومعرض سريع)
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
          // Hero Banner Card
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

          // Active Project Shortcut Bar if available
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

          // Title & Count
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

          // Grid of 12 Services
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

          // Portfolio Shortcut Banner
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
// 2. SERVICE DETAIL SCREEN (عرض كامل لتفاصيل الخدمة ومراحلها)
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
            // Header Card with Icon
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
// 3. NEW PROJECT REQUEST SCREEN (تقديم طلب مشروع وموقع ومرفقات)
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
  int attachedCount = 0;

  @override
  void initState() {
    super.initState();
    selectedService = widget.preselectedService ?? "شغل شقة كاملة جاهزة بالتشطيب";
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
              "تفاصيل الخدمة والعقار المطلوب معاينته",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "حدد نوع الخدمة والمساحة وسيتم حجز معاينة ميدانية لتحديد التكلفة النهائية.",
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 20),

            // Service Type Selector
            DropdownButtonFormField<String>(
              initialValue: provider.services
                      .any((s) => s.title == selectedService)
                  ? selectedService
                  : provider.services.first.title,
              decoration: InputDecoration(
                labelText: "نوع الخدمة الهندسية",
                prefixIcon: const Icon(Icons.build_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: provider.services.map((s) {
                return DropdownMenuItem(
                  value: s.title,
                  child: Text(s.title, style: const TextStyle(fontSize: 13)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => selectedService = val);
              },
            ),
            const SizedBox(height: 16),

            // Area Input
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

            // Location Input
            TextField(
              controller: locationCtrl,
              decoration: InputDecoration(
                labelText: "موقع العقار / المدينة والحاي",
                prefixIcon: const Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Attachments Upload Box
            InkWell(
              onTap: () {
                setState(() => attachedCount++);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text("تم اختيار ملف/صورة رقم $attachedCount"),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 40,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      attachedCount == 0
                          ? "إرفاق خرائط أو صور الموقع الحالية"
                          : "تمت إضافة $attachedCount ملفات/صور مرفقة",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "اضغط لرفع الخرائط المعمارية أو الصور (PNG, JPG, PDF)",
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Notes Textfield
            TextField(
              controller: notesCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: "ملاحظات أو مواصفات خاصة ترغب بها",
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: provider.isLoading
                    ? null
                    : () async {
                        final area =
                            double.tryParse(areaCtrl.text.trim()) ?? 100.0;
                        final success = await provider.createProjectRequest(
                          serviceType: selectedService,
                          area: area,
                          location: locationCtrl.text.trim(),
                          notes: notesCtrl.text.trim(),
                        );
                        if (success && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  "تم إرسال طلب المشروع بنجاح! سيتم التواصل معكم وتحديد موعد المعاينة."),
                            ),
                          );
                          Navigator.pop(context);
                          provider.setNavIndex(1); // Go to projects tab
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                icon: const Icon(Icons.send),
                label: const Text(
                  "إرسال الطلب وحجز المعاينة",
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
// 4. MY PROJECTS SCREEN (متابعة الطلبات، التكلفة، الإنجاز والتحديثات المصورة)
// ============================================================================
class MyProjectsScreen extends StatefulWidget {
  const MyProjectsScreen({super.key});

  @override
  State<MyProjectsScreen> createState() => _MyProjectsScreenState();
}

class _MyProjectsScreenState extends State<MyProjectsScreen> {
  String selectedFilter = "الكل";

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<AppStateProvider>(context);

    final filteredProjects = provider.projects.where((p) {
      if (selectedFilter == "قيد المعاينة") return p.status == "pending_inspection";
      if (selectedFilter == "بانتظار الموافقة") {
        return p.status == "cost_assigned" && !p.customerAccepted;
      }
      if (selectedFilter == "جاري التنفيذ") return p.status == "in_progress";
      return true;
    }).toList();

    return Column(
      children: [
        // Filter Chips Bar
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              "الكل",
              "قيد المعاينة",
              "بانتظار الموافقة",
              "جاري التنفيذ"
            ].map((filter) {
              final isSelected = selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(left: 8.0),
                child: ChoiceChip(
                  label: Text(filter),
                  selected: isSelected,
                  onSelected: (_) => setState(() => selectedFilter = filter),
                ),
              );
            }).toList(),
          ),
        ),

        // List of Projects
        Expanded(
          child: filteredProjects.isEmpty
              ? _buildEmptyState(context)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredProjects.length,
                  itemBuilder: (context, idx) {
                    final proj = filteredProjects[idx];
                    return ProjectCardItem(project: proj);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.article_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 12),
          const Text(
            "لا توجد طلبات أو مشاريع تحت هذا التصنيف",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            "قم بطلب خدمة جديدة لمعاينتها وبدء تنفيذها.",
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class ProjectCardItem extends StatelessWidget {
  final EngineeringProject project;

  const ProjectCardItem({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<AppStateProvider>(context, listen: false);

    // Dynamic Status Badge
    Widget statusBadge;
    if (project.status == "pending_inspection") {
      statusBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.amber.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          "قيد المعاينة الفنية",
          style: TextStyle(
              color: Colors.amber.shade900,
              fontSize: 11,
              fontWeight: FontWeight.bold),
        ),
      );
    } else if (project.status == "cost_assigned" && !project.customerAccepted) {
      statusBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          "تم تحديد التكلفة (مطلوب الموافقة)",
          style: TextStyle(
              color: Colors.orange.shade900,
              fontSize: 11,
              fontWeight: FontWeight.bold),
        ),
      );
    } else {
      statusBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          "جاري التنفيذ (${project.progressPercentage}%)",
          style: TextStyle(
              color: Colors.green.shade900,
              fontSize: 11,
              fontWeight: FontWeight.bold),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: project.status == "cost_assigned" && !project.customerAccepted
              ? theme.colorScheme.secondary
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: project.status == "cost_assigned" && !project.customerAccepted
              ? 2
              : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                statusBadge,
                Text(
                  project.requestCode,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Text(
              project.serviceType,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    "${project.locationDetails} • ${project.approximateArea.toInt()} م²",
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Cost Box section if estimated
            if (project.estimatedCost != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "التكلفة المحددة بعد المعاينة:",
                          style: TextStyle(fontSize: 12),
                        ),
                        Text(
                          "${intl.NumberFormat('#,###').format(project.estimatedCost)} د.ل",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    if (project.costNotes != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        project.costNotes!,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Customer acceptance CTA button if cost is ready
            if (project.status == "cost_assigned" &&
                !project.customerAccepted) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    provider.acceptProjectCost(project.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            "تمت الموافقة على التكلفة! سيتم بدء الأعمال وتوفير المواد فوراً."),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.secondary,
                    foregroundColor: theme.colorScheme.onSecondary,
                  ),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text(
                    "الموافقة على التكلفة لبدء التنفيذ",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Execution Progress bar if in progress
            if (project.status == "in_progress") ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "نسبة الإنجاز الميداني:",
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        "${project.progressPercentage}%",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.tertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                    value: project.progressPercentage / 100.0,
                    borderRadius: BorderRadius.circular(4),
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.surfaceContainerHigh,
                    color: theme.colorScheme.tertiary,
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

            // Action row to view stage field reports
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  project.currentStage,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      builder: (_) =>
                          ProjectUpdatesBottomSheet(projectId: project.id),
                    );
                  },
                  icon: const Icon(Icons.insert_chart_outlined, size: 16),
                  label: const Text("التقرير الميداني",
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Bottom sheet showing site photo updates uploaded by admins
class ProjectUpdatesBottomSheet extends StatelessWidget {
  final int projectId;

  const ProjectUpdatesBottomSheet({super.key, required this.projectId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<AppStateProvider>(context);
    final updates = provider.getUpdatesForProject(projectId);

    return Container(
      padding: const EdgeInsets.all(20),
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "تقارير الإنجاز والمتابعة الميدانية",
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "تحديثات حية ومصورة يرفعها مهندس الشركة المباشر من موقع المشروع.",
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: updates.isEmpty
                ? const Center(
                    child: Text("لا توجد تحديثات مصورة جديدة بعد."),
                  )
                : ListView.builder(
                    itemCount: updates.length,
                    itemBuilder: (context, idx) {
                      final item = updates[idx];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    item.stageTitle,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14),
                                  ),
                                  Text(
                                    "${item.progressPercentage}%",
                                    style: TextStyle(
                                      color: theme.colorScheme.tertiary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.engineerNotes,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                height: 80,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: item.images.length + 1,
                                  itemBuilder: (_, i) {
                                    return Container(
                                      width: 100,
                                      margin: const EdgeInsets.only(left: 8),
                                      decoration: BoxDecoration(
                                        color: theme
                                            .colorScheme.surfaceContainerHigh,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.photo_camera,
                                        color: theme.colorScheme.primary,
                                      ),
                                    );
                                  },
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
    );
  }
}

// ============================================================================
// 5. PORTFOLIO SCREEN (معرض صور وفيديوهات المشاريع المنفذة)
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
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      const Color(0xFF1B2A47),
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.play_circle_outline,
                        size: 48,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          "معاينة فيديو وفوتوغرافيا",
                          style: TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Chip(
                      label: Text(item.category,
                          style: const TextStyle(fontSize: 10)),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          item.location,
                          style:
                              const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
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
// 6. NOTIFICATIONS SCREEN (صندوق الإشعارات الفورية)
// ============================================================================
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<AppStateProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("الإشعارات والتحديثات"),
        actions: [
          TextButton(
            onPressed: () => provider.markNotificationsAsRead(),
            child: const Text("تعليم الكل كمعلوم"),
          ),
        ],
      ),
      body: provider.notifications.isEmpty
          ? const Center(child: Text("لا توجد إشعارات حالية"))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.notifications.length,
              itemBuilder: (context, idx) {
                final item = provider.notifications[idx];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: item.isRead
                      ? theme.colorScheme.surface
                      : theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: item.isRead
                          ? Colors.grey.shade300
                          : theme.colorScheme.primary,
                      child: Icon(
                        Icons.notifications,
                        color: item.isRead
                            ? Colors.grey.shade700
                            : theme.colorScheme.onPrimary,
                      ),
                    ),
                    title: Text(
                      item.title,
                      style: TextStyle(
                        fontWeight:
                            item.isRead ? FontWeight.normal : FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      item.body,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ============================================================================
// 7. PROFILE & SETTINGS SCREEN (تعديل الحساب والإعدادات)
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = Provider.of<AppStateProvider>(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          // Avatar & User Header
          CircleAvatar(
            radius: 40,
            backgroundColor: theme.colorScheme.primary,
            child: Text(
              provider.fullName.isNotEmpty ? provider.fullName[0] : "م",
              style: const TextStyle(
                fontSize: 28,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            provider.fullName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          Text(
            provider.userEmail ?? "زبون معتمد",
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 24),

          // Profile Form Card
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "معلومات الحساب",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: "الاسم الكامل",
                      prefixIcon: const Icon(Icons.person_outline),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: "رقم الهاتف / التواصل",
                      prefixIcon: const Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        provider.updateProfile(
                            nameCtrl.text.trim(), phoneCtrl.text.trim());
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("تم حفظ بيانات الملف الشخصي"),
                          ),
                        );
                      },
                      child: const Text("حفظ التغييرات"),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Settings Options Card
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text("المظهر الداكن (Dark Mode)"),
                  value: provider.isDarkMode,
                  onChanged: (val) => provider.toggleDarkMode(val),
                  secondary: const Icon(Icons.dark_mode_outlined),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.security_outlined),
                  title: const Text("تأكيد الحساب برمز OTP"),
                  trailing: const Icon(Icons.check_circle, color: Colors.green),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Logout Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => provider.signOut(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.logout),
              label: const Text(
                "تسجيل الخروج",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
