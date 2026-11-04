import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' as intl;

import 'firebase_config.dart';

// ============================================================================
// CONSTANTS & SUPABASE CONFIG
// ============================================================================
const String kSupabaseUrl = "https://jvjtgzewumfecjdpekna.supabase.co";
const String kSupabaseAnonKey =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp2anRnemV3dW1mZWNqZHBla25hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE2NDYzMzcsImV4cCI6MjEwNzIyMjMzN30.1gck73ek8ErBtcF7xAtFM1TdvNim_1NzFVNej_mptBE";

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
    debugPrint("Firebase init skipped: $e");
  }

  runApp(
    ChangeNotifierProvider(
      create: (_) => AdminStateProvider()..initSession(),
      child: const AlMadrarAdminApp(),
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
    return ServiceItem(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      title: json['title'] ?? '',
      category: json['category'] ?? 'عام',
      description: json['description'] ?? '',
      icon: _getIconData(json['title'] ?? ''),
      workflowSteps: json['workflow_steps'] != null
          ? List<String>.from(json['workflow_steps'])
          : [],
    );
  }

  static IconData _getIconData(String title) {
    if (title.contains('خرسان') || title.contains('صب')) return Icons.foundation;
    if (title.contains('تصميم') || title.contains('خرائط')) return Icons.design_services;
    if (title.contains('جمولون') || title.contains('صيوان')) return Icons.warehouse;
    return Icons.hardware;
  }
}

class EngineeringProject {
  final int id;
  final String requestCode;
  final String customerId;
  final String customerName;
  final String serviceType;
  final double approximateArea;
  final String locationDetails;
  final String notes;
  String status; // pending_inspection, cost_assigned, in_progress, completed
  double? estimatedCost;
  String? costNotes;
  String? estimatedDuration;
  DateTime? expectedStartDate;
  bool customerAccepted;
  int progressPercentage;
  String currentStage;
  final DateTime createdAt;

  EngineeringProject({
    required this.id,
    required this.requestCode,
    required this.customerId,
    required this.customerName,
    required this.serviceType,
    required this.approximateArea,
    required this.locationDetails,
    required this.notes,
    required this.status,
    this.estimatedCost,
    this.costNotes,
    this.estimatedDuration,
    this.expectedStartDate,
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
      customerName: json['customer_name'] ?? 'زبون المدرار',
      serviceType: json['service_type'] ?? 'خدمة هندسية',
      approximateArea: (json['approximate_area'] ?? 0).toDouble(),
      locationDetails: json['location_details'] ?? '',
      notes: json['notes'] ?? '',
      status: json['status'] ?? 'pending_inspection',
      estimatedCost: json['estimated_cost'] != null
          ? (json['estimated_cost'] as num).toDouble()
          : null,
      costNotes: json['cost_breakdown_notes'],
      estimatedDuration: json['estimated_duration'],
      expectedStartDate: json['expected_start_date'] != null
          ? DateTime.tryParse(json['expected_start_date'].toString())
          : null,
      customerAccepted: json['customer_accepted'] ?? false,
      progressPercentage: json['progress_percentage'] ?? 0,
      currentStage: json['current_stage'] ?? 'بانتظار المعاينة',
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
  final List<String> images;
  final List<String> videos;

  PortfolioItem({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.location,
    required this.images,
    required this.videos,
  });
}

class CustomerUser {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final bool isVerified;

  CustomerUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.isVerified,
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

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      isRead: json['read_at'] != null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }
}

// ============================================================================
// STATE MANAGEMENT & ADMIN PROVIDER
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

class AdminStateProvider extends ChangeNotifier {
  String? authError; // why sending/checking the code failed (shown to the user)

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  String? _accessToken;
  String? _refreshToken;
  String? _userId;
  String? _userEmail;
  final String _fullName = "م. عبد السلام الفيتوري";
  bool _isAuthenticated = false;
  bool _isAdminClaimed = false;

  bool get isAuthenticated => _isAuthenticated;
  bool get isAdminClaimed => _isAdminClaimed;
  String? get userEmail => _userEmail;
  String get fullName => _fullName;
  String? get userId => _userId;
  String? get accessToken => _accessToken;

  int _selectedNavIndex = 0;
  int get selectedNavIndex => _selectedNavIndex;

  // Catalog of 12 Services Required
  final List<ServiceItem> _services = [
    ServiceItem(
      id: 1,
      title: "تشطيب داخلي وخارجي",
      category: "تشطيبات",
      description: "أعمال الدهانات الحديثة، الجبس بورد، والواجهات الزجاجية.",
      icon: Icons.palette_outlined,
      workflowSteps: ["المعاينة", "اختيار المواد", "التنفيذ", "التسليم"],
    ),
    ServiceItem(
      id: 2,
      title: "صب من الأول",
      category: "صب وخرسانة",
      description: "بدء عملية الصب وتأسيس القواعد والأساسات المسلحة من الصفر.",
      icon: Icons.foundation_outlined,
      workflowSteps: ["الحفر", "حديد التسليح", "صب الخرسانة", "الفحص الإنشائي"],
    ),
    ServiceItem(
      id: 3,
      title: "صب طوابق",
      category: "صب وخرسانة",
      description: "صب الأسقف والخرسانات المسلحة للطوابق المتعددة.",
      icon: Icons.business_outlined,
      workflowSteps: ["الشدة الخشبية", "شبكات الحديد", "الصب بالمضخة", "المتابعة"],
    ),
    ServiceItem(
      id: 4,
      title: "شغل شقة كاملة جاهزة بالتشطيب",
      category: "متكامل",
      description: "تسليم مفتاح متكامل للشقة يشمل الهيكل والتأسيس والتشطيب.",
      icon: Icons.vpn_key_outlined,
      workflowSteps: ["التقسيم المعماري", "التأسيس", "التشطيبات", "التسليم السكني"],
    ),
    ServiceItem(
      id: 5,
      title: "صب عمدان",
      category: "صب وخرسانة",
      description: "تشييد وصب الأعمدة الخرسانية المسلحة ذات الأبعاد الدقيقة.",
      icon: Icons.account_balance_outlined,
      workflowSteps: ["توزين المحاور", "أقفاص الحديد", "الشدة الخشبية", "الصب"],
    ),
    ServiceItem(
      id: 6,
      title: "صب خرسانات",
      category: "صب وخرسانة",
      description: "تجهيز وصب الخرسانة الجاهزة والمخلوطة ميكانيكياً.",
      icon: Icons.view_in_ar_outlined,
      workflowSteps: ["فحص الإجهاد", "تنسيق المضخات", "الصب الميداني", "أخذ العينات"],
    ),
    ServiceItem(
      id: 7,
      title: "تصميم داخلي وخارجي",
      category: "تصاميم",
      description: "تصاميم ثلاثية الأبعاد 3D ومخططات إنشائية ومعمارية.",
      icon: Icons.design_services_outlined,
      workflowSteps: ["العصف الذهني", "مخطط 3D", "التعديلات", "المخطط التنفيذي"],
    ),
    ServiceItem(
      id: 8,
      title: "تشطيب من الأول إلى الآخر",
      category: "تشطيبات",
      description: "إدارة وتنفيذ مشروع التشطيب الشامل من العظم حتى الديكور.",
      icon: Icons.auto_awesome_outlined,
      workflowSteps: ["المحارة", "تأسيس الكهرباء", "الأرضيات", "الدهانات"],
    ),
    ServiceItem(
      id: 9,
      title: "تشطيب نصفي",
      category: "تشطيبات",
      description: "إنجاز المراحل الأساسية من التأسيس والمحارة والسباكة.",
      icon: Icons.handyman_outlined,
      workflowSteps: ["السباكة والكهرباء", "محارة الحوائط", "تركيب العتبات"],
    ),
    ServiceItem(
      id: 10,
      title: "رسم خرائط بالشقة",
      category: "خرائط وتخطيط",
      description: "مسح المساحات ورسم خرائط معمارية وتنفيذية دقيقة.",
      icon: Icons.map_outlined,
      workflowSteps: ["المسح بالليزر", "رسم الخريطة", "تحديد الأعمدة", "تسليم CAD"],
    ),
    ServiceItem(
      id: 11,
      title: "الجمولونات",
      category: "هياكل معدنية",
      description: "تصميم وتصنيع وتركيب الجمولونات والمظلات المعدنية.",
      icon: Icons.warehouse_outlined,
      workflowSteps: ["دروس الأحمال", "التصنيع بالمشغل", "التركيب بالرافعات"],
    ),
    ServiceItem(
      id: 12,
      title: "الصيوانات",
      category: "إنشاءات خفيفة",
      description: "تنفيذ وتجهيز الصيوانات والهياكل الخفيفة المقاومة للطقس.",
      icon: Icons.roofing_outlined,
      workflowSteps: ["المساحة", "تثبيت الركائز", "شد العوازل والغطاء"],
    ),
  ];

  List<ServiceItem> get services => _services;

  // Active Admin Managed Projects
  final List<EngineeringProject> _projects = [];
  List<EngineeringProject> get projects => _projects;

  final Map<int, List<ProjectUpdate>> _projectUpdates = {};
  List<ProjectUpdate> getUpdatesForProject(int projectId) {
    return _projectUpdates[projectId] ?? [];
  }

  // Showcase Portfolio
  final List<PortfolioItem> _portfolio = [
    PortfolioItem(
      id: 201,
      title: "مشروع صب خرسانات وجمولونات لمجمع تجاري",
      category: "خرسانات وهياكل",
      description: "تشييد الهيكل المسلح وتركيب الجمولونات بمساحة 1200 م².",
      location: "زليتن - المنطقة الصناعية",
      images: ["https://picsum.photos/400/300?random=30"],
      videos: ["video_demo_1.mp4"],
    ),
    PortfolioItem(
      id: 202,
      title: "تشطيب فاخر لشقة كاملة من الأول للآخر",
      category: "تشطيبات كاملة",
      description: "تشطيب عصري كامل يشمل السباكة، الكهرباء والجبس بورد.",
      location: "طرابلس - بن عاشور",
      images: ["https://picsum.photos/400/300?random=31"],
      videos: [],
    ),
  ];

  List<PortfolioItem> get portfolio => _portfolio;

  // Customers Accounts list
  final List<CustomerUser> _customers = [];
  List<CustomerUser> get customers => _customers;

  // Admin Notifications Inbox
  List<AppNotification> _notifications = [];
  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void setNavIndex(int index) {
    _selectedNavIndex = index;
    notifyListeners();
  }

  void toggleDarkMode(bool val) async {
    _isDarkMode = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', val);
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // Session Init
  Future<void> initSession() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    _refreshToken = prefs.getString('refresh_token');
    _userId = prefs.getString('user_id');
    _userEmail = prefs.getString('user_email');
    _isDarkMode = prefs.getBool('is_dark_mode') ?? false;

    if (_accessToken != null && _userId != null) {
      _isAuthenticated = true;
      await claimAdminCheck();
      fetchProjects();
      fetchNotifications();
      _setupFCMListener();
    }
    notifyListeners();
  }

  void _setupFCMListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      fetchNotifications();
    });
  }

  // Auth: Send OTP via Supabase API
  Future<bool> sendOtp(String email) async {
    _setLoading(true);
    _userEmail = email;
    try {
      final res = await http.post(
        Uri.parse("$kSupabaseUrl/auth/v1/otp"),
        headers: {
          "apikey": kSupabaseAnonKey,
          "Content-Type": "application/json",
        },
        body: jsonEncode({"email": email, "create_user": true}),
      );
      _setLoading(false);
      final ok = res.statusCode == 200 || res.statusCode == 201;
      authError = ok ? null : authErrorMessage(res);
      return ok;
    } catch (_) {
      _setLoading(false);
      authError = 'تأكد من اتصال الإنترنت وجرّب تاني.';
      return false;
    }
  }

  // Auth: Verify 6-digit Code
  Future<bool> verifyOtp(String email, String code) async {
    _setLoading(true);
    try {
      final res = await http.post(
        Uri.parse("$kSupabaseUrl/auth/v1/verify"),
        headers: {
          "apikey": kSupabaseAnonKey,
          "Content-Type": "application/json",
        },
        body: jsonEncode({"type": "email", "email": email, "token": code}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
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

        await claimAdminCheck();
        await _registerDeviceToken();
        fetchProjects();
        fetchNotifications();
        _setupFCMListener();

        authError = null;
        _setLoading(false);
        return true;
      }
      authError = authErrorMessage(res);
    } catch (_) {
      authError = 'تأكد من اتصال الإنترنت وجرّب تاني.';
    }

    _setLoading(false);
    notifyListeners();
    return false;
  }

  // RPC: Claim Admin Check
  Future<bool> claimAdminCheck([String? pin]) async {
    try {
      final res = await http.post(
        Uri.parse("$kSupabaseUrl/rest/v1/rpc/almadrar_claim_admin"),
        headers: {
          "apikey": kSupabaseAnonKey,
          if (_accessToken != null) "Authorization": "Bearer $_accessToken",
          "Content-Type": "application/json",
        },
        body: jsonEncode(pin != null ? {"pin": pin} : {}),
      );
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        _isAdminClaimed = decoded == true;
        notifyListeners();
        return _isAdminClaimed;
      }
    } catch (_) {}
    _isAdminClaimed = false;
    notifyListeners();
    return false;
  }

  Future<void> signOut() async {
    _isAuthenticated = false;
    _isAdminClaimed = false;
    _accessToken = null;
    _refreshToken = null;
    _userId = null;
    _userEmail = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }

  Future<void> _registerDeviceToken() async {
    try {
      await FirebaseMessaging.instance.requestPermission();
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await http.post(
          Uri.parse("$kSupabaseUrl/rest/v1/rpc/almadrar_register_device"),
          headers: {
            "apikey": kSupabaseAnonKey,
            if (_accessToken != null) "Authorization": "Bearer $_accessToken",
            "Content-Type": "application/json",
          },
          body: jsonEncode({"device_token": token, "app_name": "admin"}),
        );
      }
    } catch (_) {}
  }

  // Fetch Notifications Inbox
  Future<void> fetchNotifications() async {
    if (_userId == null) return;
    try {
      final res = await http.get(
        Uri.parse(
            "$kSupabaseUrl/rest/v1/almadrar_notifications?or=(to_user.eq.$_userId,to_role.eq.admin)&order=created_at.desc"),
        headers: {
          "apikey": kSupabaseAnonKey,
          if (_accessToken != null) "Authorization": "Bearer $_accessToken",
        },
      );
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        _notifications = list.map((e) => AppNotification.fromJson(e)).toList();
        notifyListeners();
      }
    } catch (_) {}
  }

  // Mark Notification Read
  Future<void> markNotificationRead(String id) async {
    try {
      final nowStr = DateTime.now().toIso8601String();
      await http.patch(
        Uri.parse("$kSupabaseUrl/rest/v1/almadrar_notifications?id=eq.$id"),
        headers: {
          "apikey": kSupabaseAnonKey,
          if (_accessToken != null) "Authorization": "Bearer $_accessToken",
          "Content-Type": "application/json",
          "Prefer": "return=representation",
        },
        body: jsonEncode({"read_at": nowStr}),
      );
      await fetchNotifications();
    } catch (_) {}
  }

  // Fetch Projects from Supabase REST
  Future<void> fetchProjects() async {
    try {
      final res = await http.get(
        Uri.parse(
            "$kSupabaseUrl/rest/v1/almadrar_projects?select=*&order=created_at.desc"),
        headers: {
          "apikey": kSupabaseAnonKey,
          if (_accessToken != null) "Authorization": "Bearer $_accessToken",
        },
      );
      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        _projects.clear();
        for (var item in list) {
          _projects.add(EngineeringProject.fromJson(item));
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  // Action: Admin sets inspection cost
  Future<bool> assignCost({
    required int projectId,
    required double cost,
    required String notes,
    required String duration,
    required DateTime startDate,
  }) async {
    _setLoading(true);
    final p = _projects.firstWhere((element) => element.id == projectId);
    p.estimatedCost = cost;
    p.costNotes = notes;
    p.estimatedDuration = duration;
    p.expectedStartDate = startDate;
    p.status = "cost_assigned";
    p.currentStage = "تم تحديد التكلفة بانتظار موافقة الزبون";

    try {
      await http.patch(
        Uri.parse("$kSupabaseUrl/rest/v1/almadrar_projects?id=eq.$projectId"),
        headers: {
          "apikey": kSupabaseAnonKey,
          if (_accessToken != null) "Authorization": "Bearer $_accessToken",
          "Content-Type": "application/json",
          "Prefer": "return=representation"
        },
        body: jsonEncode({
          "estimated_cost": cost,
          "cost_breakdown_notes": notes,
          "estimated_duration": duration,
          "expected_start_date": startDate.toIso8601String().split('T')[0],
          "status": "cost_assigned",
          "current_stage": p.currentStage,
        }),
      );

      // Send Push Notification Event to Customer
      await sendNotification(
        targetUser: p.customerId,
        title: "تحديد تكلفة المعاينة",
        body:
            "تم تحديد التكلفة التقديرية لمشروع '${p.serviceType}' بقيمة $cost د.ل. يرجى المراجعة والموافقة.",
      );
    } catch (_) {}

    _setLoading(false);
    return true;
  }

  // Action: Admin updates project stage & progress photos
  Future<bool> updateProjectProgress({
    required int projectId,
    required int progressPercentage,
    required String stageTitle,
    required String engineerNotes,
    required List<String> photos,
  }) async {
    _setLoading(true);
    final p = _projects.firstWhere((element) => element.id == projectId);
    p.progressPercentage = progressPercentage;
    p.currentStage = stageTitle;
    p.status = progressPercentage == 100 ? "completed" : "in_progress";

    final updateObj = ProjectUpdate(
      id: DateTime.now().millisecondsSinceEpoch,
      projectId: projectId,
      stageTitle: stageTitle,
      progressPercentage: progressPercentage,
      engineerNotes: engineerNotes,
      images: photos,
      createdAt: DateTime.now(),
    );

    if (!_projectUpdates.containsKey(projectId)) {
      _projectUpdates[projectId] = [];
    }
    _projectUpdates[projectId]!.insert(0, updateObj);

    try {
      await http.patch(
        Uri.parse("$kSupabaseUrl/rest/v1/almadrar_projects?id=eq.$projectId"),
        headers: {
          "apikey": kSupabaseAnonKey,
          if (_accessToken != null) "Authorization": "Bearer $_accessToken",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "progress_percentage": progressPercentage,
          "current_stage": stageTitle,
          "status": p.status,
        }),
      );

      await http.post(
        Uri.parse("$kSupabaseUrl/rest/v1/almadrar_project_updates"),
        headers: {
          "apikey": kSupabaseAnonKey,
          if (_accessToken != null) "Authorization": "Bearer $_accessToken",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "project_id": projectId,
          "customer_id": p.customerId,
          "stage_title": stageTitle,
          "progress_percentage": progressPercentage,
          "engineer_notes": engineerNotes,
          "images": photos,
        }),
      );

      // Send Notification to Customer
      await sendNotification(
        targetUser: p.customerId,
        title: "تحديث ميداني جديد",
        body: "قام المهندس بإضافة تقرير جديد ($progressPercentage%): $stageTitle",
      );
    } catch (_) {}

    _setLoading(false);
    return true;
  }

  // Dispatch Notification
  Future<bool> sendNotification({
    String? targetUser,
    required String title,
    required String body,
  }) async {
    try {
      await http.post(
        Uri.parse("$kSupabaseUrl/rest/v1/almadrar_notifications"),
        headers: {
          "apikey": kSupabaseAnonKey,
          if (_accessToken != null) "Authorization": "Bearer $_accessToken",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "to_user": targetUser,
          "to_role": targetUser == null ? "customer" : null,
          "title": title,
          "body": body,
          "created_at": DateTime.now().toIso8601String(),
        }),
      );
    } catch (_) {}
    return true;
  }
}

// ============================================================================
// MAIN APP WIDGET
// ============================================================================
class AlMadrarAdminApp extends StatelessWidget {
  const AlMadrarAdminApp({super.key});

  @override
  Widget build(BuildContext meContext) {
    final provider = Provider.of<AdminStateProvider>(meContext);

    return MaterialApp(
      title: 'إدارة المدرار للمقاولات',
      debugShowCheckedModeBanner: false,
      themeMode: provider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F4C81),
          primary: const Color(0xFF0F4C81),
          secondary: const Color(0xFFE38B29),
          tertiary: const Color(0xFF2D6A4F),
          surface: const Color(0xFFF8F9FE),
        ),
        fontFamily: 'Tahoma',
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F4C81),
          brightness: Brightness.dark,
        ),
        fontFamily: 'Tahoma',
      ),
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      home: _buildHomeView(provider),
    );
  }

  Widget _buildHomeView(AdminStateProvider provider) {
    if (!provider.isAuthenticated) {
      return const AdminAuthScreen();
    }
    if (!provider.isAdminClaimed) {
      return const AdminClaimScreen();
    }
    return const AdminMainNavigationScreen();
  }
}

// ============================================================================
// AUTHENTICATION & CLAIM SCREENS
// ============================================================================
class AdminAuthScreen extends StatefulWidget {
  const AdminAuthScreen({super.key});

  @override
  State<AdminAuthScreen> createState() => _AdminAuthScreenState();
}

class _AdminAuthScreenState extends State<AdminAuthScreen> {
  final _emailController = TextEditingController(text: "admin@almedrar.ly");
  final _codeControllers = List.generate(6, (_) => TextEditingController());
  bool _codeSent = false;
  int _cooldown = 60;
  Timer? _timer;

  void _startCooldown() {
    setState(() => _cooldown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_cooldown > 0) {
        setState(() => _cooldown--);
      } else {
        t.cancel();
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
    final provider = Provider.of<AdminStateProvider>(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.engineering,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ).animate().scale(duration: 300.ms),
              const SizedBox(height: 16),
              const Text(
                "إدارة المدرار للمقاولات",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const Text(
                "تسجيل دخول كادر المهندسين والإدارة",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 36),
              if (!_codeSent) ...[
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: "البريد الإلكتروني المعتمد للإدارة",
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: provider.isLoading
                      ? null
                      : () async {
                          final ok = await provider.sendOtp(_emailController.text.trim());
                          if (ok) {
                            setState(() => _codeSent = true);
                            _startCooldown();
                          } else if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(provider.authError ?? "ما قدرنا نرسل الرمز")),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: provider.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text("استلام رمز التأكيد (6 أرقام)",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ] else ...[
                const Text(
                  "أدخل رمز تأكيد الدخول المكون من 6 أرقام:",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    6,
                    (index) => SizedBox(
                      width: 44,
                      height: 52,
                      child: TextField(
                        controller: _codeControllers[index],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          counterText: "",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
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
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: provider.isLoading
                      ? null
                      : () async {
                          final code =
                              _codeControllers.map((c) => c.text).join();
                          if (code.length < 6) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("اكتب الرمز كامل (6 أرقام) اللي وصلك على البريد")),
                            );
                            return;
                          }
                          final ok = await provider.verifyOtp(_emailController.text.trim(), code);
                          if (!ok && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(provider.authError ?? "الرمز غلط")),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: provider.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text("تأكيد ومتابعة للدخول",
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _cooldown == 0
                      ? () {
                          provider.sendOtp(_emailController.text);
                          _startCooldown();
                        }
                      : null,
                  child: Text(_cooldown > 0
                      ? "إعادة الإرسال بعد $_cooldown ثانية"
                      : "إعادة إرسال الرمز الآن"),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AdminClaimScreen extends StatefulWidget {
  const AdminClaimScreen({super.key});

  @override
  State<AdminClaimScreen> createState() => _AdminClaimScreenState();
}

class _AdminClaimScreenState extends State<AdminClaimScreen> {
  final _pinController = TextEditingController();
  String? _error;

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AdminStateProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("رمز اعتماد الإدارة"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => provider.signOut(),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.security, size: 60, color: Colors.amber),
            const SizedBox(height: 16),
            const Text(
              "تأكيد صلاحية حساب الإدارة",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "أدخل رمز الإدارة السري المخصص للوصول إلى لوحة المقاولات",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "رمز الإدارة (PIN)",
                errorText: _error,
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final ok = await provider.claimAdminCheck(_pinController.text);
                if (!ok) {
                  setState(() => _error = "رمز الإدارة غير صحيح");
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text("دخول الإدارة",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// MAIN NAVIGATION & SCREENS
// ============================================================================
class AdminMainNavigationScreen extends StatelessWidget {
  const AdminMainNavigationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AdminStateProvider>(context);

    final pages = const [
      AdminDashboardTab(),
      AdminProjectsTab(),
      AdminServicesAndPortfolioTab(),
      AdminNotificationsTab(),
      AdminSettingsTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.apartment, color: Color(0xFFE38B29)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text("إدارة المدرار",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text("المدرار للمقاولات الهندسية",
                    style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
          ],
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => provider.setNavIndex(3),
              ),
              if (provider.unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${provider.unreadCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: provider.selectedNavIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: provider.selectedNavIndex,
        onDestinationSelected: (i) => provider.setNavIndex(i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: "الرئيسية"),
          NavigationDestination(
              icon: Icon(Icons.assignment_outlined),
              selectedIcon: Icon(Icons.assignment),
              label: "الطلبات"),
          NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view),
              label: "الخدمات والمعرض"),
          NavigationDestination(
              icon: Icon(Icons.notifications_outlined),
              selectedIcon: Icon(Icons.notifications),
              label: "الإشعارات"),
          NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: "الإعدادات"),
        ],
      ),
    );
  }
}

// ============================================================================
// TAB 1: DASHBOARD
// ============================================================================
class AdminDashboardTab extends StatelessWidget {
  const AdminDashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AdminStateProvider>(context);

    final pendingCount =
        provider.projects.where((p) => p.status == 'pending_inspection').length;
    final activeCount =
        provider.projects.where((p) => p.status == 'in_progress').length;

    return RefreshIndicator(
      onRefresh: () async {
        await provider.fetchProjects();
        await provider.fetchNotifications();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F4C81), Color(0xFF1B3B6F)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("مرحباً بك، المهندس المشرف",
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(height: 4),
                        Text(provider.fullName,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => provider.setNavIndex(1),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE38B29),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("متابعة الطلبات"),
                  ),
                ],
              ),
            ).animate().fade().slideY(),

            const SizedBox(height: 16),

            // KPI Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.5,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildKpiCard(
                  context,
                  title: "طلبات المعاينة",
                  value: "$pendingCount طلبات",
                  subtext: "بانتظار تحديد التكلفة",
                  color: Colors.amber,
                  icon: Icons.search_outlined,
                  onTap: () => provider.setNavIndex(1),
                ),
                _buildKpiCard(
                  context,
                  title: "مشاريع جارية",
                  value: "$activeCount مشروع",
                  subtext: "قيد الصب والتشطيب",
                  color: const Color(0xFF0F4C81),
                  icon: Icons.engineering_outlined,
                  onTap: () => provider.setNavIndex(1),
                ),
                _buildKpiCard(
                  context,
                  title: "إجمالي الإيرادات",
                  value: "345,000 د.ل",
                  subtext: "هذا الشهر",
                  color: const Color(0xFF2D6A4F),
                  icon: Icons.payments_outlined,
                ),
                _buildKpiCard(
                  context,
                  title: "سجل العملاء",
                  value: "${provider.customers.length} عميل",
                  subtext: "حسابات نشطة",
                  color: Colors.indigo,
                  icon: Icons.people_outline,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Chart Section
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("إحصائيات تنفيذ المشاريع والصب",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 120,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: 10,
                          barTouchData: BarTouchData(enabled: false),
                          titlesData: FlTitlesData(
                            leftTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (val, meta) {
                                  const days = ['أحد', 'إثنين', 'ثلاثاء', 'أربعاء', 'خميس'];
                                  if (val.toInt() < days.length) {
                                    return Text(days[val.toInt()],
                                        style: const TextStyle(fontSize: 10));
                                  }
                                  return const Text('');
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: [
                            BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: 4, color: const Color(0xFF0F4C81))]),
                            BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: 7, color: const Color(0xFF0F4C81))]),
                            BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: 3, color: const Color(0xFFE38B29))]),
                            BarChartGroupData(x: 3, barRods: [BarChartRodData(toY: 9, color: const Color(0xFF0F4C81))]),
                            BarChartGroupData(x: 4, barRods: [BarChartRodData(toY: 6, color: const Color(0xFF2D6A4F))]),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Quick Actions Title
            const Text("أحدث الطلبات الواردة",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),

            if (provider.projects.isEmpty)
              _buildEmptyState(context, "لا توجد طلبات واردة حالياً")
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: provider.projects.length,
                itemBuilder: (ctx, idx) {
                  final proj = provider.projects[idx];
                  return _buildProjectListTile(context, proj, provider);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiCard(
    BuildContext context, {
    required String title,
    required String value,
    required String subtext,
    required Color color,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 22),
                Text(subtext,
                    style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TAB 2: PROJECTS & REQUESTS MANAGEMENT
// ============================================================================
class AdminProjectsTab extends StatefulWidget {
  const AdminProjectsTab({super.key});

  @override
  State<AdminProjectsTab> createState() => _AdminProjectsTabState();
}

class _AdminProjectsTabState extends State<AdminProjectsTab> {
  String _filter = "all";

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AdminStateProvider>(context);

    var filtered = provider.projects;
    if (_filter == "pending") {
      filtered = provider.projects
          .where((p) => p.status == 'pending_inspection')
          .toList();
    } else if (_filter == "active") {
      filtered =
          provider.projects.where((p) => p.status == 'in_progress').toList();
    }

    return Column(
      children: [
        // Filter Chips Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              FilterChip(
                label: const Text("الكل"),
                selected: _filter == "all",
                onSelected: (_) => setState(() => _filter = "all"),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text("بانتظار المعاينة والتكلفة"),
                selected: _filter == "pending",
                onSelected: (_) => setState(() => _filter = "pending"),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text("جاري التنفيذ"),
                selected: _filter == "active",
                onSelected: (_) => setState(() => _filter = "active"),
              ),
            ],
          ),
        ),

        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyState(context, "لا توجد مشاريع تطابق هذا الفلتر")
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, idx) {
                    final proj = filtered[idx];
                    return _buildProjectCard(context, proj, provider);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildProjectCard(
      BuildContext context, EngineeringProject proj, AdminStateProvider provider) {
    final isPending = proj.status == 'pending_inspection';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isPending ? Colors.amber : Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPending
                        ? Colors.amber.withValues(alpha: 0.15)
                        : Colors.blue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isPending ? "بانتظار تحديد التكلفة" : "جاري التنفيذ (${proj.progressPercentage}%)",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isPending ? Colors.amber.shade900 : Colors.blue.shade900,
                    ),
                  ),
                ),
                Text(proj.requestCode,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            Text(proj.serviceType,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text("الزبون: ${proj.customerName}",
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(width: 12),
                const Icon(Icons.location_on_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(proj.locationDetails,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (proj.estimatedCost != null)
              Text("التكلفة المقرة: ${proj.estimatedCost} د.ل",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Color(0xFF2D6A4F))),
            const SizedBox(height: 12),
            Row(
              children: [
                if (isPending)
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.attach_money, size: 16),
                      label: const Text("تحديد التكلفة والإرسال"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE38B29),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(24)),
                          ),
                          builder: (_) => AssignCostSheet(project: proj),
                        );
                      },
                    ),
                  )
                else
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.camera_alt_outlined, size: 16),
                      label: const Text("رفع تحديث وصور للميدان"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2D6A4F),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(24)),
                          ),
                          builder: (_) => UpdateProgressSheet(project: proj),
                        );
                      },
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

// ============================================================================
// ASSIGN COST BOTTOM SHEET
// ============================================================================
class AssignCostSheet extends StatefulWidget {
  final EngineeringProject project;
  const AssignCostSheet({super.key, required this.project});

  @override
  State<AssignCostSheet> createState() => _AssignCostSheetState();
}

class _AssignCostSheetState extends State<AssignCostSheet> {
  final _costController = TextEditingController(text: "38500");
  final _notesController = TextEditingController(
      text: "تشمل التكلفة: توريد خرسانة عيار 350، حديد التسليح والإشراف الهندسي.");
  final _durationController = TextEditingController(text: "21 يوماً عمل");
  final DateTime _startDate = DateTime.now().add(const Duration(days: 3));

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AdminStateProvider>(context);

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
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "تحديد تكلفة موقع - ${widget.project.serviceType}",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text("العميل: ${widget.project.customerName}",
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: _costController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "التكلفة المادية (دينار ليبي)",
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: "ملاحظات وتفاصيل المواد والخرسانة",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _durationController,
              decoration: const InputDecoration(
                labelText: "المدة الزمنية التقديرية",
                prefixIcon: Icon(Icons.timer_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: provider.isLoading
                  ? null
                  : () async {
                      final cost = double.tryParse(_costController.text) ?? 0.0;
                      await provider.assignCost(
                        projectId: widget.project.id,
                        cost: cost,
                        notes: _notesController.text,
                        duration: _durationController.text,
                        startDate: _startDate,
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text("إرسال التكلفة للزبون عبر التطبيق",
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// UPDATE PROGRESS BOTTOM SHEET
// ============================================================================
class UpdateProgressSheet extends StatefulWidget {
  final EngineeringProject project;
  const UpdateProgressSheet({super.key, required this.project});

  @override
  State<UpdateProgressSheet> createState() => _UpdateProgressSheetState();
}

class _UpdateProgressSheetState extends State<UpdateProgressSheet> {
  late double _progress;
  final _stageController =
      TextEditingController(text: "مرحلة التمديدات والصب المسلح");
  final _notesController =
      TextEditingController(text: "تم صب كافة الأعمدة بنجاح والجفاف مستمر.");

  @override
  void initState() {
    super.initState();
    _progress = widget.project.progressPercentage.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AdminStateProvider>(context);

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
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "تحديث تقدم العمل الميداني - #${widget.project.requestCode}",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("نسبة الإنجاز الحالية:"),
                Text("${_progress.toInt()}%",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary)),
              ],
            ),
            Slider(
              value: _progress,
              min: 0,
              max: 100,
              divisions: 20,
              label: "${_progress.toInt()}%",
              onChanged: (val) => setState(() => _progress = val),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _stageController,
              decoration: const InputDecoration(
                labelText: "عنوان المرحلة الإنشائية",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: "ملاحظات المهندس المشرف للزبون",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("تم التحديد 3 صور ميدانية من الموقع")),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).colorScheme.primary),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.add_a_photo_outlined),
                    SizedBox(width: 8),
                    Text("التقاط / اختيار صور موقع الصب والتشطيب",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: provider.isLoading
                  ? null
                  : () async {
                      await provider.updateProjectProgress(
                        projectId: widget.project.id,
                        progressPercentage: _progress.toInt(),
                        stageTitle: _stageController.text,
                        engineerNotes: _notesController.text,
                        photos: ["https://picsum.photos/400/300?random=88"],
                      );
                      if (context.mounted) Navigator.pop(context);
                    },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: const Color(0xFF2D6A4F),
                foregroundColor: Colors.white,
              ),
              child: const Text("رفع التحديث وإرسال التنبيه",
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// TAB 3: SERVICES CATALOG & PORTFOLIO MANAGEMENT
// ============================================================================
class AdminServicesAndPortfolioTab extends StatelessWidget {
  const AdminServicesAndPortfolioTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AdminStateProvider>(context);

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: "الخدمات المعروضة (12)"),
              Tab(text: "معرض الأعمال السابقة"),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // Catalog List of 12 Exact Services
                ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.services.length,
                  itemBuilder: (ctx, idx) {
                    final item = provider.services[idx];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(item.icon,
                              color: Theme.of(context).colorScheme.primary),
                        ),
                        title: Text(item.title,
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(item.description,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text("تعديل خدمة ${item.title}")),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),

                // Portfolio Showcase List
                ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.portfolio.length,
                  itemBuilder: (ctx, idx) {
                    final item = provider.portfolio[idx];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.shade800,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(12)),
                            ),
                            child: const Center(
                              child: Icon(Icons.photo_library,
                                  color: Colors.white, size: 40),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15)),
                                const SizedBox(height: 4),
                                Text(item.location,
                                    style: const TextStyle(
                                        fontSize: 11, color: Colors.grey)),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      icon: const Icon(Icons.delete_outline,
                                          color: Colors.red, size: 16),
                                      label: const Text("حذف",
                                          style: TextStyle(color: Colors.red)),
                                      onPressed: () {},
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
// TAB 4: IN-APP NOTIFICATIONS INBOX
// ============================================================================
class AdminNotificationsTab extends StatefulWidget {
  const AdminNotificationsTab({super.key});

  @override
  State<AdminNotificationsTab> createState() => _AdminNotificationsTabState();
}

class _AdminNotificationsTabState extends State<AdminNotificationsTab> {
  final _titleController = TextEditingController(text: "تحديث بشأن طلب المقاولة");
  final _bodyController = TextEditingController(
      text: "يرجى العلم بضرورة الاطلاع على التكلفة والموافقة لبدء الصب.");

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AdminStateProvider>(context);

    return RefreshIndicator(
      onRefresh: () => provider.fetchNotifications(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("إرسال إشعار فوري للعملاء",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: "عنوان التنبيه",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "نص الإشعار الفوري",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.send_outlined),
              label: const Text("بث الإشعار لجميع التطبيقات"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                await provider.sendNotification(
                  title: _titleController.text,
                  body: _bodyController.text,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("تم إرسال التنبيه بنجاح")),
                  );
                }
              },
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("صندوق الإشعارات الواردة",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                if (provider.unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${provider.unreadCount} غير مقروء',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (provider.notifications.isEmpty)
              _buildEmptyState(context, "لا توجد إشعارات واردة")
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: provider.notifications.length,
                itemBuilder: (ctx, idx) {
                  final n = provider.notifications[idx];
                  return Card(
                    color: n.isRead ? null : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.2),
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold)),
                      subtitle: Text(n.body),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(intl.DateFormat.jm().format(n.createdAt),
                              style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          if (!n.isRead)
                            const Icon(Icons.circle, size: 8, color: Colors.red),
                        ],
                      ),
                      onTap: () {
                        if (!n.isRead) {
                          provider.markNotificationRead(n.id);
                        }
                      },
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
// TAB 5: SETTINGS & PROFILE
// ============================================================================
class AdminSettingsTab extends StatelessWidget {
  const AdminSettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AdminStateProvider>(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  child: const Text("م",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(provider.fullName,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(provider.userEmail ?? "admin@almedrar.ly",
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 4),
                    const Chip(
                      label: Text("إدارة عليا", style: TextStyle(fontSize: 10)),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    )
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text("الوضع الداكن (Dark Theme)"),
          value: provider.isDarkMode,
          onChanged: (val) => provider.toggleDarkMode(val),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text("عن تطبيق إدارة المدرار"),
          subtitle: const Text("الإصدار 2.4.0 • نظام المقاولات الهندسية"),
        ),
        const Divider(),
        ElevatedButton.icon(
          icon: const Icon(Icons.logout),
          label: const Text("تسجيل الخروج من الإدارة"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          onPressed: () => provider.signOut(),
        ),
      ],
    );
  }
}

// ============================================================================
// SHARED WIDGET HELPERS
// ============================================================================
Widget _buildProjectListTile(
    BuildContext context, EngineeringProject proj, AdminStateProvider provider) {
  return Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      title: Text(proj.serviceType,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text("${proj.customerName} • ${proj.locationDetails}"),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: proj.status == 'pending_inspection'
              ? Colors.amber.withValues(alpha: 0.2)
              : Colors.green.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          proj.status == 'pending_inspection' ? "معاينة" : "تنفيذ",
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: proj.status == 'pending_inspection'
                ? Colors.amber.shade900
                : Colors.green.shade900,
          ),
        ),
      ),
      onTap: () => provider.setNavIndex(1),
    ),
  );
}

Widget _buildEmptyState(BuildContext context, String message) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(color: Colors.grey, fontSize: 14)),
        ],
      ),
    ),
  );
}
