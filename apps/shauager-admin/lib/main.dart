import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'firebase_config.dart';

// ==========================================
// CONSTANTS & SUPABASE CONFIG
// ==========================================
const String kSupabaseUrl = "https://jvjtgzewumfecjdpekna.supabase.co";
const String kSupabaseAnonKey =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp2anRnemV3dW1mZWNqZHBla25hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE2NDYzMzcsImV4cCI6MjEwNzIyMjMzN30.1gck73ek8ErBtcF7xAtFM1TdvNim_1NzFVNej_mptBE";

const Color kPrimary = Color(0xFF0D3B2E);
const Color kPrimaryContainer = Color(0xFF1B4D3E);
const Color kAccentGold = Color(0xFFC5A059);
const Color kSurface = Color(0xFF0A1210);
const Color kSurfaceContainer = Color(0xFF141F1C);
const Color kSurfaceContainerHigh = Color(0xFF1E2D28);
const Color kSurfaceContainerHighest = Color(0xFF283933);
const Color kOnSurface = Color(0xFFE8ECEB);
const Color kOnSurfaceVariant = Color(0xFFA4B2AE);
const Color kOutline = Color(0xFF2D3D37);
const Color kOutlineVariant = Color(0xFF1B2924);
const Color kSuccess = Color(0xFF4BE09B);
const Color kInfo = Color(0xFF4FC3F7);
const Color kError = Color(0xFFFF5449);

const List<String> kMajors = ["الكل", "ميكانيكا", "تصنيع", "مدنية", "كهربا"];
const List<String> kPostTypes = ["محاضرات", "جدول", "فعاليات", "أخبار"];
const List<String> kEmojis = ["👍", "❤️", "🙏"];

@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: firebaseOptions);
  } catch (_) {}
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: firebaseOptions);
    FirebaseMessaging.onBackgroundMessage(_bgHandler);
  } catch (e) {
    debugPrint("Firebase init ignored or optional: $e");
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const ShauagerAdminApp());
}

// ==========================================
// MODELS
// ==========================================
class StudentProfile {
  final String id;
  final String fullName;
  final String phone;
  final String email;
  final String major;
  final String role;
  final String createdAt;

  StudentProfile({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.major,
    required this.role,
    required this.createdAt,
  });

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    return StudentProfile(
      id: json['id'] ?? json['customer_id'] ?? '',
      fullName: json['full_name'] ?? 'طالب',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      major: json['major'] ?? 'ميكانيكا',
      role: json['role'] ?? 'customer',
      createdAt: json['created_at'] ?? DateTime.now().toIso8601String(),
    );
  }
}

class PostItem {
  final String id;
  String title;
  String content;
  String postType;
  String targetMajor;
  final String createdAt;
  int countLike;
  int countLove;
  int countPray;
  List<AttachmentItem> attachments;

  PostItem({
    required this.id,
    required this.title,
    required this.content,
    required this.postType,
    required this.targetMajor,
    required this.createdAt,
    this.countLike = 0,
    this.countLove = 0,
    this.countPray = 0,
    this.attachments = const [],
  });

  factory PostItem.fromJson(Map<String, dynamic> json) {
    return PostItem(
      id: json['id'] ?? '',
      title: json['title'] ?? 'بدون عنوان',
      content: json['content'] ?? '',
      postType: json['post_type'] ?? 'محاضرات',
      targetMajor: json['target_major'] ?? 'الكل',
      createdAt: json['created_at'] ?? DateTime.now().toIso8601String(),
      countLike: json['count_like'] ?? 0,
      countLove: json['count_love'] ?? 0,
      countPray: json['count_pray'] ?? 0,
    );
  }

  int get totalReactions => countLike + countLove + countPray;
}

class AttachmentItem {
  final String id;
  final String postId;
  final String fileName;
  final String fileUrl;
  final String fileType;
  final int fileSizeBytes;

  AttachmentItem({
    required this.id,
    required this.postId,
    required this.fileName,
    required this.fileUrl,
    required this.fileType,
    required this.fileSizeBytes,
  });

  factory AttachmentItem.fromJson(Map<String, dynamic> json) {
    return AttachmentItem(
      id: json['id'] ?? '',
      postId: json['post_id'] ?? '',
      fileName: json['file_name'] ?? 'ملف',
      fileUrl: json['file_url'] ?? '',
      fileType: json['file_type'] ?? 'pdf',
      fileSizeBytes: json['file_size_bytes'] ?? 4400000,
    );
  }
}

class ReactionItem {
  final String id;
  final String postId;
  final String customerId;
  final String emoji;
  final String studentName;
  final String studentMajor;

  ReactionItem({
    required this.id,
    required this.postId,
    required this.customerId,
    required this.emoji,
    required this.studentName,
    required this.studentMajor,
  });

  factory ReactionItem.fromJson(Map<String, dynamic> json, Map<String, dynamic>? studentProfile) {
    return ReactionItem(
      id: json['id'] ?? '',
      postId: json['post_id'] ?? '',
      customerId: json['customer_id'] ?? '',
      emoji: json['emoji'] ?? '👍',
      studentName: studentProfile?['full_name'] ?? 'طالب',
      studentMajor: studentProfile?['major'] ?? 'ميكانيكا',
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
      id: json['id'] ?? '',
      toUser: json['to_user'],
      toRole: json['to_role'],
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      data: json['data'] is Map ? json['data'] : null,
      readAt: json['read_at'],
      createdAt: json['created_at'] ?? DateTime.now().toIso8601String(),
    );
  }

  bool get isRead => readAt != null;
}

// ==========================================
// API HELPER
// ==========================================
class ApiService {
  static Future<Map<String, String>> _headers(String? token) async {
    final headers = {
      'apikey': kSupabaseAnonKey,
      'Content-Type': 'application/json',
      'Prefer': 'return=representation',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static String _parseError(http.Response res) {
    try {
      final body = jsonDecode(res.body);
      final msg = body['msg'] ?? body['message'] ?? body['error'] ?? body['error_description'];
      if (msg != null) {
        final str = msg.toString().toLowerCase();
        if (str.contains('rate limit') || str.contains('too many requests')) {
          return 'اتبعتت رسائل كتير، استنى دقايق';
        }
        if (str.contains('smtp') || str.contains('email provider') || str.contains('sending')) {
          return 'ما قدرنا نرسل البريد';
        }
        return msg.toString();
      }
    } catch (_) {}
    if (res.statusCode == 401) return 'انتهت صلاحية الجلسة، يرجى تسجيل الدخول مجدداً';
    return 'حدث خطأ غير معروف (${res.statusCode})';
  }

  static Future<Map<String, dynamic>> postAuth(String endpoint, Map<String, dynamic> body) async {
    final uri = Uri.parse('$kSupabaseUrl/auth/v1/$endpoint');
    final res = await http.post(uri, headers: await _headers(null), body: jsonEncode(body));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return {};
      return jsonDecode(res.body);
    }
    throw Exception(_parseError(res));
  }

  static Future<Map<String, dynamic>> putAuth(String endpoint, String token, Map<String, dynamic> body) async {
    final uri = Uri.parse('$kSupabaseUrl/auth/v1/$endpoint');
    final res = await http.put(uri, headers: await _headers(token), body: jsonEncode(body));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return {};
      return jsonDecode(res.body);
    }
    throw Exception(_parseError(res));
  }

  static Future<dynamic> restGet(String tableQuery, String? token) async {
    final uri = Uri.parse('$kSupabaseUrl/rest/v1/$tableQuery');
    final res = await http.get(uri, headers: await _headers(token));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return jsonDecode(res.body);
    }
    throw Exception(_parseError(res));
  }

  static Future<dynamic> restPost(String table, String? token, Map<String, dynamic> data) async {
    final uri = Uri.parse('$kSupabaseUrl/rest/v1/$table');
    final res = await http.post(uri, headers: await _headers(token), body: jsonEncode(data));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return {};
      return jsonDecode(res.body);
    }
    throw Exception(_parseError(res));
  }

  static Future<dynamic> restPatch(String tableQuery, String? token, Map<String, dynamic> data) async {
    final uri = Uri.parse('$kSupabaseUrl/rest/v1/$tableQuery');
    final res = await http.patch(uri, headers: await _headers(token), body: jsonEncode(data));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return {};
      return jsonDecode(res.body);
    }
    throw Exception(_parseError(res));
  }

  static Future<dynamic> restDelete(String tableQuery, String? token) async {
    final uri = Uri.parse('$kSupabaseUrl/rest/v1/$tableQuery');
    final res = await http.delete(uri, headers: await _headers(token));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.body.isNotEmpty ? jsonDecode(res.body) : {};
    }
    throw Exception(_parseError(res));
  }

  static Future<dynamic> rpc(String fn, String? token, [Map<String, dynamic>? body]) async {
    final uri = Uri.parse('$kSupabaseUrl/rest/v1/rpc/$fn');
    final res = await http.post(uri, headers: await _headers(token), body: body != null ? jsonEncode(body) : null);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return res.body.isNotEmpty ? jsonDecode(res.body) : null;
    }
    throw Exception(_parseError(res));
  }
}

// ==========================================
// PROVIDERS
// ==========================================
class AuthProvider extends ChangeNotifier {
  String? _accessToken;
  String? _refreshToken;
  String? _userId;
  String? _userEmail;
  bool _isAdminVerified = false;
  bool _needsPin = false;
  bool _isLoading = false;
  String? _errorMessage;

  String? get accessToken => _accessToken;
  String? get userId => _userId;
  String? get userEmail => _userEmail;
  bool get isAuthenticated => _accessToken != null && _userId != null;
  bool get isAdminVerified => _isAdminVerified;
  bool get needsPin => _needsPin;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    _loadSession();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    _refreshToken = prefs.getString('refresh_token');
    _userId = prefs.getString('user_id');
    _userEmail = prefs.getString('user_email');
    _isAdminVerified = prefs.getBool('is_admin_verified') ?? false;

    if (isAuthenticated) {
      await _checkAdminStatusAndClaim();
    }
    notifyListeners();
  }

  Future<bool> _refreshTokenCall() async {
    if (_refreshToken == null) return false;
    try {
      final res = await ApiService.postAuth('token?grant_type=refresh_token', {"refresh_token": _refreshToken});
      _accessToken = res['access_token'];
      _refreshToken = res['refresh_token'] ?? _refreshToken;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', _accessToken!);
      await prefs.setString('refresh_token', _refreshToken!);
      return true;
    } catch (_) {
      await signOut();
      return false;
    }
  }

  Future<void> _checkAdminStatusAndClaim() async {
    try {
      var res = await ApiService.rpc('shauager_claim_admin', _accessToken, {});
      if (res == true) {
        _isAdminVerified = true;
        _needsPin = false;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_admin_verified', true);
      } else {
        _needsPin = true;
      }
    } catch (e) {
      if (e.toString().contains('401')) {
        if (await _refreshTokenCall()) {
          await _checkAdminStatusAndClaim();
        }
      } else {
        _needsPin = true;
      }
    }
  }

  Future<bool> submitPin(String pin) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final res = await ApiService.rpc('shauager_claim_admin', _accessToken, {"pin": pin});
      if (res == true) {
        _isAdminVerified = true;
        _needsPin = false;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_admin_verified', true);
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = 'رمز الإدارة غير صحيح';
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _errorMessage = 'رمز الإدارة غير صحيح';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signIn(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      // 1. Contract requirement: check shauager_is_admin_email BEFORE sending any code or signing in
      final isAdminEmailRes = await ApiService.rpc('shauager_is_admin_email', null, {"email": email});
      if (isAdminEmailRes != true) {
        _isLoading = false;
        _errorMessage = 'عذراً، هذا البريد غير مسموح له بالدخول كمسؤول';
        notifyListeners();
        throw Exception(_errorMessage);
      }

      final res = await ApiService.postAuth('token?grant_type=password', {"email": email, "password": password});
      _accessToken = res['access_token'];
      _refreshToken = res['refresh_token'];
      final user = res['user'];
      _userId = user['id'];
      _userEmail = user['email'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', _accessToken!);
      await prefs.setString('refresh_token', _refreshToken!);
      await prefs.setString('user_id', _userId!);
      await prefs.setString('user_email', _userEmail!);

      await _checkAdminStatusAndClaim();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      final err = e.toString().replaceAll('Exception: ', '');
      if (err.contains('Email not confirmed') || err.contains('not confirmed')) {
        try {
          await ApiService.postAuth('resend', {"type": "signup", "email": email});
        } catch (_) {}
        _errorMessage = 'البريد غير مؤكد، تم إرسال رمز جديد';
      } else {
        _errorMessage = err;
      }
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signUp(String name, String phone, String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      // Contract requirement: check shauager_is_admin_email BEFORE sending any code or signing in
      final isAdminEmailRes = await ApiService.rpc('shauager_is_admin_email', null, {"email": email});
      if (isAdminEmailRes != true) {
        _isLoading = false;
        _errorMessage = 'عذراً، هذا البريد غير مسموح له بالدخول كمسؤول';
        notifyListeners();
        throw Exception(_errorMessage);
      }

      await ApiService.postAuth('signup', {
        "email": email,
        "password": password,
        "data": {"full_name": name, "phone": phone}
      });
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> verifySignup(String email, String code) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      // Contract requirement: POST /auth/v1/verify with type "signup"
      final res = await ApiService.postAuth('verify', {"type": "signup", "email": email, "token": code});
      _accessToken = res['access_token'];
      _refreshToken = res['refresh_token'];
      final user = res['user'];
      _userId = user['id'];
      _userEmail = user['email'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', _accessToken!);
      await prefs.setString('refresh_token', _refreshToken!);
      await prefs.setString('user_id', _userId!);
      await prefs.setString('user_email', _userEmail!);

      await _checkAdminStatusAndClaim();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> resendSignupCode(String email) async {
    try {
      await ApiService.postAuth('resend', {"type": "signup", "email": email});
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  Future<void> recoverPassword(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await ApiService.postAuth('recover', {"email": email});
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> verifyRecovery(String email, String code) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final res = await ApiService.postAuth('verify', {"type": "recovery", "email": email, "token": code});
      _accessToken = res['access_token'];
      _refreshToken = res['refresh_token'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', _accessToken!);
      await prefs.setString('refresh_token', _refreshToken!);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateNewPassword(String newPassword) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await ApiService.putAuth('user', _accessToken!, {"password": newPassword});
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    _accessToken = null;
    _refreshToken = null;
    _userId = null;
    _userEmail = null;
    _isAdminVerified = false;
    _needsPin = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}

class AdminDataProvider extends ChangeNotifier {
  List<StudentProfile> students = [];
  List<PostItem> posts = [];
  List<ReactionItem> reactions = [];
  List<AppNotification> notifications = [];
  bool isLoadingData = false;
  String? selectedPostForReactionsId;

  int get unreadNotificationsCount => notifications.where((n) => !n.isRead).length;

  PostItem? get activeReactionPost {
    if (posts.isEmpty) return null;
    if (selectedPostForReactionsId == null) return posts.first;
    return posts.firstWhere((p) => p.id == selectedPostForReactionsId, orElse: () => posts.first);
  }

  void selectPostForReactions(String postId) {
    selectedPostForReactionsId = postId;
    notifyListeners();
  }

  int get totalStudents => students.length;
  int countMajor(String m) {
    if (m == 'الكل') return students.length;
    return students.where((s) => s.major == m).length;
  }

  Future<void> fetchData(String? token, {bool silent = false}) async {
    if (!silent) {
      isLoadingData = true;
      notifyListeners();
    }
    try {
      if (token == null) return;

      // 1. Students
      final sData = await ApiService.restGet('shauager_student_details?select=*&order=created_at.desc', token);
      if (sData is List) {
        students = sData.map((e) => StudentProfile.fromJson(e)).toList();
      }

      // 2. Posts & Attachments
      final pData = await ApiService.restGet('shauager_posts?select=*&order=created_at.desc', token);
      if (pData is List) {
        List<PostItem> loadedPosts = [];
        for (var pJson in pData) {
          final post = PostItem.fromJson(pJson);
          try {
            final attData = await ApiService.restGet('shauager_attachments?select=*&post_id=eq.${post.id}', token);
            if (attData is List) {
              post.attachments = attData.map((a) => AttachmentItem.fromJson(a)).toList();
            }
          } catch (_) {}
          loadedPosts.add(post);
        }
        posts = loadedPosts;
      }

      // 3. Reactions
      final rData = await ApiService.restGet('shauager_reactions?select=*&order=created_at.desc', token);
      if (rData is List) {
        List<ReactionItem> loadedReactions = [];
        for (var rJson in rData) {
          final customerId = rJson['customer_id'];
          StudentProfile? st;
          try {
            final stData = await ApiService.restGet('shauager_student_details?select=*&customer_id=eq.$customerId', token);
            if (stData is List && stData.isNotEmpty) {
              st = StudentProfile.fromJson(stData.first);
            }
          } catch (_) {}
          loadedReactions.add(ReactionItem.fromJson(rJson, st != null ? {'full_name': st.fullName, 'major': st.major} : null));
        }
        reactions = loadedReactions;
      }

      // Update post counts
      for (var p in posts) {
        p.countLike = reactions.where((r) => r.postId == p.id && r.emoji == '👍').length;
        p.countLove = reactions.where((r) => r.postId == p.id && r.emoji == '❤️').length;
        p.countPray = reactions.where((r) => r.postId == p.id && r.emoji == '🙏').length;
      }

      // 4. Notifications
      await fetchNotifications(token, silent: true);
    } catch (_) {} finally {
      if (!silent) {
        isLoadingData = false;
        notifyListeners();
      }
    }
  }

  Future<void> fetchNotifications(String? token, {bool silent = false}) async {
    if (token == null) return;
    try {
      final nData = await ApiService.restGet('shauager_notifications?or=(to_user.eq.<uid>,to_role.eq.admin)&order=created_at.desc'.replaceAll('<uid>', ''), token);
      if (nData is List) {
        notifications = nData.map((e) => AppNotification.fromJson(e)).toList();
        if (!silent) notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> markNotificationRead(String? token, String id) async {
    if (token == null) return;
    try {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      await ApiService.restPatch('shauager_notifications?id=eq.$id', token, {"read_at": nowIso});
      final idx = notifications.indexWhere((n) => n.id == id);
      if (idx != -1) {
        notifications[idx] = AppNotification(
          id: notifications[idx].id,
          toUser: notifications[idx].toUser,
          toRole: notifications[idx].toRole,
          title: notifications[idx].title,
          body: notifications[idx].body,
          data: notifications[idx].data,
          readAt: nowIso,
          createdAt: notifications[idx].createdAt,
        );
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> sendNotification(String? token, {String? toUser, String? toRole, required String title, required String body, Map<String, dynamic>? data}) async {
    if (token == null) return;
    try {
      final payload = <String, dynamic>{
        "title": title,
        "body": body,
      };
      if (toUser != null) payload["to_user"] = toUser;
      if (toRole != null) payload["to_role"] = toRole;
      if (data != null) payload["data"] = data;

      await ApiService.restPost('shauager_notifications', token, payload);
    } catch (_) {}
  }

  Future<void> deletePost(String? token, String id) async {
    if (token == null) return;
    try {
      await ApiService.restDelete('shauager_posts?id=eq.$id', token);
      posts.removeWhere((p) => p.id == id);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> addPost(String? token, PostItem post, List<String> attachmentPaths) async {
    if (token == null) return;
    try {
      final pRes = await ApiService.restPost('shauager_posts', token, {
        "title": post.title,
        "content": post.content,
        "post_type": post.postType,
        "target_major": post.targetMajor,
      });

      if (pRes is List && pRes.isNotEmpty) {
        final newPostId = pRes.first['id'];
        for (var path in attachmentPaths) {
          await ApiService.restPost('shauager_attachments', token, {
            "post_id": newPostId,
            "file_name": path.split('/').last,
            "file_url": path,
            "file_type": "image",
            "file_size_bytes": 102400,
          });
        }
      }

      // Send Notification event
      String title = "منشور جديد لمجال ${post.targetMajor}";
      if (post.postType == 'جدول') title = "تحديث جداول لجميع التخصصات";
      if (post.postType == 'فعاليات') title = "دعوة فعالية جديدة";

      await sendNotification(token, toRole: 'customer', title: title, body: post.title, data: {"post_type": post.postType});

      await fetchData(token, silent: true);
    } catch (_) {}
  }

  Future<void> updatePost(String? token, PostItem post) async {
    if (token == null) return;
    try {
      await ApiService.restPatch('shauager_posts?id=eq.${post.id}', token, {
        "title": post.title,
        "content": post.content,
      });
      final idx = posts.indexWhere((p) => p.id == post.id);
      if (idx != -1) {
        posts[idx] = post;
        notifyListeners();
      }
    } catch (_) {}
  }
}

// ==========================================
// APP THEME & MAIN SHELL
// ==========================================
class ShauagerAdminApp extends StatelessWidget {
  const ShauagerAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AdminDataProvider()),
      ],
      child: MaterialApp(
        title: 'Leader22 Admin',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: kPrimary,
            brightness: Brightness.light,
            primary: kPrimary,
            secondary: kAccentGold,
          ),
          fontFamily: 'Noto Sans Arabic',
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: kPrimary,
            brightness: Brightness.dark,
            primary: kPrimaryContainer,
            secondary: kAccentGold,
            surface: kSurface,
          ),
          scaffoldBackgroundColor: kSurface,
          fontFamily: 'Noto Sans Arabic',
        ),
        builder: (context, child) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> with WidgetsBindingObserver {
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initFCM();
    _startSyncTimer();
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _triggerSync();
    }
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _triggerSync();
    });
  }

  void _triggerSync() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final dataProvider = Provider.of<AdminDataProvider>(context, listen: false);
    if (auth.isAuthenticated && auth.isAdminVerified) {
      dataProvider.fetchData(auth.accessToken, silent: true);
    }
  }

  Future<void> _initFCM() async {
    try {
      NotificationSettings settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        final token = await FirebaseMessaging.instance.getToken();
        if (token != null) {
          final auth = Provider.of<AuthProvider>(context, listen: false);
          if (auth.isAuthenticated) {
            try {
              await ApiService.rpc('shauager_register_device', auth.accessToken, {"device_token": token, "app_name": "admin"});
            } catch (_) {}
          }
        }
      }

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (message.notification != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("${message.notification?.title}: ${message.notification?.body}"),
              backgroundColor: const Color(0xF21E2D28),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999), side: const BorderSide(color: kAccentGold)),
            ),
          );
        }
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final dataProvider = Provider.of<AdminDataProvider>(context, listen: false);
        if (auth.isAuthenticated) {
          dataProvider.fetchData(auth.accessToken, silent: true);
        }
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    if (!auth.isAuthenticated) {
      return const AuthScreen();
    }
    if (auth.needsPin) {
      return const PinVerificationScreen();
    }
    return const AdminMainShell();
  }
}

// ==========================================
// AUTH SCREENS (Login, Signup, Recovery, PIN)
// ==========================================
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  int tabIndex = 0; // 0: Login, 1: Signup

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF1B4D3E), Color(0xFF0D3B2E)]),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: kAccentGold, width: 2),
                  boxShadow: const [BoxShadow(color: Color(0x33C5A059), blurRadius: 20, offset: Offset(0, 8))],
                ),
                child: const Icon(Icons.admin_panel_settings_rounded, color: kAccentGold, size: 38),
              ),
              const SizedBox(height: 12),
              const Text("Leader22 Admin", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 4),
              const Text("لوحة تحكم ليدر الدفعة (الإدارة)", style: TextStyle(fontSize: 12, color: kAccentGold, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => tabIndex = 0),
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: tabIndex == 0 ? kPrimaryContainer : kSurfaceContainerHigh,
                          borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                          border: Border.all(color: tabIndex == 0 ? kAccentGold : kOutlineVariant),
                        ),
                        alignment: Alignment.center,
                        child: Text("تسجيل الدخول", style: TextStyle(color: tabIndex == 0 ? kAccentGold : kOnSurfaceVariant, fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => tabIndex = 1),
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: tabIndex == 1 ? kPrimaryContainer : kSurfaceContainerHigh,
                          borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                          border: Border.all(color: tabIndex == 1 ? kAccentGold : kOutlineVariant),
                        ),
                        alignment: Alignment.center,
                        child: Text("حساب جديد", style: TextStyle(color: tabIndex == 1 ? kAccentGold : kOnSurfaceVariant, fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              tabIndex == 0 ? const LoginForm() : const SignupForm(),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  bool obscure = true;

  void _submit() async {
    final email = emailCtrl.text.trim();
    final pass = passCtrl.text.trim();
    if (email.isEmpty || pass.isEmpty) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await auth.signIn(email, pass);
    } catch (e) {
      if (!mounted) return;
      if (auth.errorMessage?.contains('البريد غير مؤكد') == true) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => OtpVerifyScreen(email: email)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.errorMessage ?? e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xCC1E2D28), Color(0xF2101916)]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kOutlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("تسجيل الدخول", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 14),
          _buildInput("البريد الإلكتروني", emailCtrl, Icons.email_outlined, TextInputType.emailAddress),
          const SizedBox(height: 12),
          _buildInput("كلمة المرور", passCtrl, Icons.lock_outline, TextInputType.text, obscure: obscure, onToggle: () => setState(() => obscure = !obscure)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
              child: const Text("نسيت كلمة المرور؟", style: TextStyle(color: kAccentGold, fontSize: 12)),
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: auth.isLoading ? null : _submit,
            borderRadius: BorderRadius.circular(9999),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFDFBE7A), Color(0xFFC5A059), Color(0xFF9A7736)]),
                borderRadius: BorderRadius.circular(9999),
              ),
              alignment: Alignment.center,
              child: auth.isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : const Text("دخول", style: TextStyle(color: Color(0xFF0A1210), fontWeight: FontWeight.w800, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, IconData icon, TextInputType type, {bool obscure = false, VoidCallback? onToggle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kOnSurfaceVariant)),
        const SizedBox(height: 6),
        Container(
          height: 48,
          decoration: BoxDecoration(color: kSurfaceContainerHigh, borderRadius: BorderRadius.circular(12), border: Border.all(color: kOutlineVariant)),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(icon, size: 18, color: kOnSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: ctrl,
                  obscureText: obscure,
                  keyboardType: type,
                  style: const TextStyle(color: kOnSurface, fontSize: 13),
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                ),
              ),
              if (onToggle != null)
                GestureDetector(onTap: onToggle, child: Icon(obscure ? Icons.visibility_off : Icons.visibility, size: 18, color: kOnSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}

class SignupForm extends StatefulWidget {
  const SignupForm({super.key});

  @override
  State<SignupForm> createState() => _SignupFormState();
}

class _SignupFormState extends State<SignupForm> {
  final nameCtrl = TextEditingController();
  final phoneCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmPassCtrl = TextEditingController();
  bool obscure = true;

  void _submit() async {
    final name = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    final email = emailCtrl.text.trim();
    final pass = passCtrl.text.trim();
    final confirm = confirmPassCtrl.text.trim();

    if (name.isEmpty || phone.isEmpty || email.isEmpty || pass.length < 6 || pass != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("الرجاء التأكد من صحة المدخلات (كلمة المرور 6+ وتطابق التأكيد)")));
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await auth.signUp(name, phone, email, pass);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => OtpVerifyScreen(email: email)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.errorMessage ?? e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xCC1E2D28), Color(0xF2101916)]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kOutlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("حساب جديد", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 14),
          _buildInput("الاسم الكامل", nameCtrl, Icons.person_outline, TextInputType.text),
          const SizedBox(height: 10),
          _buildInput("رقم الهاتف", phoneCtrl, Icons.phone_outlined, TextInputType.phone),
          const SizedBox(height: 10),
          _buildInput("البريد الإلكتروني", emailCtrl, Icons.email_outlined, TextInputType.emailAddress),
          const SizedBox(height: 10),
          _buildInput("كلمة المرور (6+ أحرف)", passCtrl, Icons.lock_outline, TextInputType.text, obscure: obscure),
          const SizedBox(height: 10),
          _buildInput("تأكيد كلمة المرور", confirmPassCtrl, Icons.lock_outline, TextInputType.text, obscure: obscure),
          const SizedBox(height: 18),
          InkWell(
            onTap: auth.isLoading ? null : _submit,
            borderRadius: BorderRadius.circular(9999),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFDFBE7A), Color(0xFFC5A059), Color(0xFF9A7736)]),
                borderRadius: BorderRadius.circular(9999),
              ),
              alignment: Alignment.center,
              child: auth.isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : const Text("إنشاء الحساب", style: TextStyle(color: Color(0xFF0A1210), fontWeight: FontWeight.w800, fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController ctrl, IconData icon, TextInputType type, {bool obscure = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kOnSurfaceVariant)),
        const SizedBox(height: 4),
        Container(
          height: 44,
          decoration: BoxDecoration(color: kSurfaceContainerHigh, borderRadius: BorderRadius.circular(12), border: Border.all(color: kOutlineVariant)),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(icon, size: 18, color: kOnSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: ctrl,
                  obscureText: obscure,
                  keyboardType: type,
                  style: const TextStyle(color: kOnSurface, fontSize: 13),
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                ),
              ),
            ],
          ),
        ),
      ],
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
  final codeCtrl = TextEditingController();
  int timerSeconds = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    setState(() => timerSeconds = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (timerSeconds == 0) {
        t.cancel();
      } else {
        setState(() => timerSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _verify() async {
    final code = codeCtrl.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("الرجاء إدخال الرمز المكون من 6 أرقام")));
      return;
    }
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await auth.verifySignup(widget.email, code);
      if (!mounted) return;
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.errorMessage ?? e.toString())));
    }
  }

  void _resend() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await auth.resendSignupCode(widget.email);
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم إعادة إرسال الرمز")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, title: const Text("تأكيد البريد الإلكتروني")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text("بعتنا رمز على بريدك", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            Text(widget.email, style: const TextStyle(color: kAccentGold)),
            const SizedBox(height: 20),
            TextField(
              controller: codeCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: const TextStyle(fontSize: 24, letterSpacing: 8, color: Colors.white),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                counterText: "",
                filled: true,
                fillColor: kSurfaceContainerHigh,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kOutlineVariant)),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kAccentGold, foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 48)),
              onPressed: _verify,
              child: const Text("تأكيد الرمز", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: timerSeconds == 0 ? _resend : null,
              child: Text(timerSeconds > 0 ? "إعادة الإرسال بعد $timerSeconds ثانية" : "إعادة إرسال الرمز", style: TextStyle(color: timerSeconds == 0 ? kAccentGold : kOnSurfaceVariant)),
            ),
          ],
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
  final emailCtrl = TextEditingController();
  final codeCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  int step = 1; // 1: Email, 2: Code & New Password

  void _recover() async {
    final email = emailCtrl.text.trim();
    if (email.isEmpty) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await auth.recoverPassword(email);
      setState(() => step = 2);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.errorMessage ?? e.toString())));
    }
  }

  void _resetPass() async {
    final email = emailCtrl.text.trim();
    final code = codeCtrl.text.trim();
    final pass = passCtrl.text.trim();
    if (code.length != 6 || pass.length < 6) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      await auth.verifyRecovery(email, code);
      await auth.updateNewPassword(pass);
      if (!mounted) return;
      Navigator.popUntil(context, (route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("تم تغيير كلمة المرور بنجاح")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.errorMessage ?? e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, title: const Text("استعادة كلمة المرور")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: step == 1
            ? Column(
                children: [
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: "البريد الإلكتروني", labelStyle: TextStyle(color: kOnSurfaceVariant)),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: kAccentGold, foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 48)),
                    onPressed: _recover,
                    child: const Text("إرسال رمز الاستعادة"),
                  ),
                ],
              )
            : Column(
                children: [
                  TextField(
                    controller: codeCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: const TextStyle(color: Colors.white, letterSpacing: 8),
                    decoration: const InputDecoration(labelText: "رمز الاستعادة (6 أرقام)", labelStyle: TextStyle(color: kOnSurfaceVariant)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(labelText: "كلمة المرور الجديدة", labelStyle: TextStyle(color: kOnSurfaceVariant)),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: kAccentGold, foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 48)),
                    onPressed: _resetPass,
                    child: const Text("تعيين كلمة المرور"),
                  ),
                ],
              ),
      ),
    );
  }
}

class PinVerificationScreen extends StatefulWidget {
  const PinVerificationScreen({super.key});

  @override
  State<PinVerificationScreen> createState() => _PinVerificationScreenState();
}

class _PinVerificationScreenState extends State<PinVerificationScreen> {
  final pinCtrl = TextEditingController();

  void _submit() async {
    final pin = pinCtrl.text.trim();
    if (pin.isEmpty) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.submitPin(pin);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    return Scaffold(
      backgroundColor: kSurface,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.security, size: 64, color: kAccentGold),
            const SizedBox(height: 16),
            const Text("دخول الإدارة", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            const Text("الرجاء إدخال رمز الإدارة السري للمتابعة", style: TextStyle(color: kOnSurfaceVariant, fontSize: 13)),
            const SizedBox(height: 24),
            TextField(
              controller: pinCtrl,
              obscureText: true,
              style: const TextStyle(color: Colors.white, letterSpacing: 6),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: "رمز الإدارة",
                hintStyle: const TextStyle(color: kOnSurfaceVariant),
                filled: true,
                fillColor: kSurfaceContainerHigh,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kOutlineVariant)),
              ),
            ),
            if (auth.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(auth.errorMessage!, style: const TextStyle(color: kError, fontSize: 12, fontWeight: FontWeight.bold)),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kAccentGold, foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 48)),
              onPressed: auth.isLoading ? null : _submit,
              child: auth.isLoading ? const CircularProgressIndicator(color: Colors.black) : const Text("تحقق ودخول", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => auth.signOut(),
              child: const Text("تسجيل الخروج", style: TextStyle(color: kOnSurfaceVariant)),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// ADMIN MAIN SHELL & TABS
// ==========================================
class AdminMainShell extends StatefulWidget {
  const AdminMainShell({super.key});

  @override
  State<AdminMainShell> createState() => _AdminMainShellState();
}

class _AdminMainShellState extends State<AdminMainShell> {
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
    });
  }

  void _loadInitialData() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final data = Provider.of<AdminDataProvider>(context, listen: false);
    data.fetchData(auth.accessToken);
  }

  void navigateToTab(int index) {
    setState(() => currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      body: Stack(
        children: [
          IndexedStack(
            index: currentIndex,
            children: [
              DashboardTab(onNavigate: navigateToTab),
              const StudentsTab(),
              CreatePostTab(onPostCreated: () => navigateToTab(3)),
              ManagePostsTab(onViewReactions: (postId) {
                Provider.of<AdminDataProvider>(context, listen: false).selectPostForReactions(postId);
                navigateToTab(4);
              }),
              const ReactionsTab(),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xF20E1714),
                    border: Border(top: BorderSide(color: kAccentGold.withValues(alpha: 0.15), width: 1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavItem(0, "اللوحة", Icons.grid_view_rounded),
                      _buildNavItem(1, "الطلاب", Icons.people_outline_rounded),
                      _buildNavItem(2, "نشر", Icons.add_circle_outline_rounded),
                      _buildNavItem(3, "المنشورات", Icons.article_outlined),
                      _buildNavItem(4, "التفاعلات", Icons.thumb_up_alt_outlined),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String label, IconData icon) {
    final bool active = currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 68,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 28,
              decoration: BoxDecoration(
                color: active ? kPrimaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(9999),
                boxShadow: active ? [BoxShadow(color: kAccentGold.withValues(alpha: 0.2), blurRadius: 12)] : null,
              ),
              child: Icon(icon, size: 20, color: active ? kAccentGold : kOnSurfaceVariant),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? kAccentGold : kOnSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomTopAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? badgeText;
  final Widget? trailing;

  const CustomTopAppBar({super.key, required this.title, this.badgeText, this.trailing});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final adminData = Provider.of<AdminDataProvider>(context);
    final unread = adminData.unreadNotificationsCount;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          height: 64 + MediaQuery.of(context).padding.top,
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, left: 16, right: 16),
          decoration: BoxDecoration(
            color: const Color(0xD9101916),
            border: Border(bottom: BorderSide(color: kAccentGold.withValues(alpha: 0.1))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kOnSurface)),
                  if (badgeText != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: kAccentGold.withValues(alpha: 0.15),
                        border: Border.all(color: kAccentGold.withValues(alpha: 0.3)),
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Text(badgeText!, style: const TextStyle(fontSize: 11, color: kAccentGold, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ],
              ),
              Row(
                children: [
                  Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined, color: kOnSurface),
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsInboxScreen())),
                      ),
                      if (unread > 0)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(color: kError, shape: BoxShape.circle),
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                          ),
                        ),
                    ],
                  ),
                  ?trailing,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// NOTIFICATIONS INBOX SCREEN
// ==========================================
class NotificationsInboxScreen extends StatelessWidget {
  const NotificationsInboxScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final adminData = Provider.of<AdminDataProvider>(context);

    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("سجل الإشعارات"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => adminData.fetchNotifications(auth.accessToken),
          )
        ],
      ),
      body: adminData.notifications.isEmpty
          ? const Center(child: Text("لا توجد إشعارات حالياً", style: TextStyle(color: kOnSurfaceVariant)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: adminData.notifications.length,
              itemBuilder: (context, index) {
                final n = adminData.notifications[index];
                if (!n.isRead) {
                  adminData.markNotificationRead(auth.accessToken, n.id);
                }
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: n.isRead ? kSurfaceContainerHigh : kPrimaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: n.isRead ? kOutlineVariant : kAccentGold.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white)),
                          Text(n.createdAt.substring(0, 10), style: const TextStyle(fontSize: 10, color: kOnSurfaceVariant)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(n.body, style: const TextStyle(fontSize: 12, color: kOnSurfaceVariant)),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// ==========================================
// 1. DASHBOARD TAB
// ==========================================
class DashboardTab extends StatelessWidget {
  final Function(int) onNavigate;
  const DashboardTab({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final adminData = Provider.of<AdminDataProvider>(context);

    return Scaffold(
      backgroundColor: kSurface,
      appBar: CustomTopAppBar(
        title: "لوحة الإحصائيات",
        badgeText: "مشرف / ليدر",
        trailing: IconButton(
          icon: const Icon(Icons.logout, color: kError, size: 20),
          onPressed: () => auth.signOut(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 84),
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xCC1E2D28), Color(0xF2101916)]),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kOutlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("إجمالي الطلاب", style: TextStyle(fontSize: 11, color: kOnSurfaceVariant, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text("${adminData.totalStudents}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xCC1E2D28), Color(0xF2101916)]),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kOutlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("المنشورات النشطة", style: TextStyle(fontSize: 11, color: kOnSurfaceVariant, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text("${adminData.posts.length}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white)),
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
              gradient: const LinearGradient(colors: [Color(0xCC1E2D28), Color(0xF2101916)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kOutlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("توزيع الطلاب حسب التخصصات", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                const SizedBox(height: 12),
                _buildDeptProgress("ميكانيكا", "${adminData.countMajor('ميكانيكا')} طالب", 0.70, const Color(0xFFC5A059)),
                const SizedBox(height: 10),
                _buildDeptProgress("تصنيع", "${adminData.countMajor('تصنيع')} طالب", 0.50, kInfo),
                const SizedBox(height: 10),
                _buildDeptProgress("مدنية", "${adminData.countMajor('مدنية')} طالب", 0.65, kSuccess),
                const SizedBox(height: 10),
                _buildDeptProgress("كهربا", "${adminData.countMajor('كهربا')} طالب", 0.55, const Color(0xFFFFB74D)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildDeptProgress(String name, String countStr, double pct, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name, style: const TextStyle(fontSize: 13, color: kOnSurface)),
            Text(countStr, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 6,
          decoration: BoxDecoration(color: kSurfaceContainerHighest, borderRadius: BorderRadius.circular(9)),
          child: FractionallySizedBox(
            alignment: Alignment.centerRight,
            widthFactor: pct,
            child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(9))),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 2. STUDENTS TAB & SEARCH
// ==========================================
class StudentsTab extends StatefulWidget {
  const StudentsTab({super.key});

  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab> {
  String selectedMajor = 'الكل';
  String query = '';

  @override
  Widget build(BuildContext context) {
    final adminData = Provider.of<AdminDataProvider>(context);

    final filtered = adminData.students.where((s) {
      final matchDept = selectedMajor == 'الكل' || s.major == selectedMajor;
      final matchQ = s.fullName.contains(query) || s.phone.contains(query);
      return matchDept && matchQ;
    }).toList();

    return Scaffold(
      backgroundColor: kSurface,
      appBar: CustomTopAppBar(
        title: "قائمة الطلاب",
        badgeText: "${adminData.totalStudents} طالب",
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xE60A1210),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Container(
              height: 42,
              decoration: BoxDecoration(color: kSurfaceContainerHigh, borderRadius: BorderRadius.circular(12), border: Border.all(color: kOutlineVariant)),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 18, color: kOnSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      onChanged: (v) => setState(() => query = v),
                      style: const TextStyle(fontSize: 13, color: Colors.white),
                      decoration: const InputDecoration(border: InputBorder.none, hintText: "بحث بالاسم أو رقم الهاتف...", hintStyle: TextStyle(color: kOnSurfaceVariant, fontSize: 13), isDense: true, contentPadding: EdgeInsets.zero),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 48,
            color: const Color(0xE60A1210),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _buildFilterChip("الكل", 'الكل'),
                const SizedBox(width: 8),
                _buildFilterChip("ميكانيكا", 'ميكانيكا'),
                const SizedBox(width: 8),
                _buildFilterChip("تصنيع", 'تصنيع'),
                const SizedBox(width: 8),
                _buildFilterChip("مدنية", 'مدنية'),
                const SizedBox(width: 8),
                _buildFilterChip("كهربا", 'كهربا'),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 84),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final s = filtered[index];
                final initial = s.fullName.isNotEmpty ? s.fullName.substring(0, 1) : 'ط';

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xCC1E2D28), Color(0xF2101916)]),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kOutlineVariant),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(color: kPrimaryContainer, shape: BoxShape.circle, border: Border.all(color: kAccentGold.withValues(alpha: 0.3))),
                            alignment: Alignment.center,
                            child: Text(initial, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kAccentGold)),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.fullName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white)),
                              const SizedBox(height: 2),
                              Text("${s.phone} • ${s.major}", style: const TextStyle(fontSize: 11, color: kOnSurfaceVariant)),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => launchUrl(Uri.parse("https://wa.me/${s.phone}"), mode: LaunchMode.externalApplication),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(color: kSurfaceContainerHigh, shape: BoxShape.circle, border: Border.all(color: kOutline)),
                              child: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: kSuccess),
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => launchUrl(Uri.parse("tel:${s.phone}")),
                            child: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(color: kSurfaceContainerHigh, shape: BoxShape.circle, border: Border.all(color: kOutline)),
                              child: const Icon(Icons.phone_outlined, size: 16, color: kAccentGold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final bool active = selectedMajor == value;
    return GestureDetector(
      onTap: () => setState(() => selectedMajor = value),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? kPrimaryContainer : kSurfaceContainerHigh,
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: active ? kAccentGold.withValues(alpha: 0.4) : kOutlineVariant),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? kAccentGold : kOnSurfaceVariant)),
      ),
    );
  }
}

// ==========================================
// 3. CREATE POST TAB
// ==========================================
class CreatePostTab extends StatefulWidget {
  final VoidCallback onPostCreated;
  const CreatePostTab({super.key, required this.onPostCreated});

  @override
  State<CreatePostTab> createState() => _CreatePostTabState();
}

class _CreatePostTabState extends State<CreatePostTab> {
  String postType = "محاضرات";
  String targetAudience = "الكل";
  final titleController = TextEditingController();
  final contentController = TextEditingController();
  List<String> attachedFiles = [];

  void _pickFiles() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isNotEmpty) {
      setState(() {
        for (var f in picked) {
          attachedFiles.add(f.path);
        }
      });
    }
  }

  void _publish() async {
    if (titleController.text.trim().isEmpty) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final adminData = Provider.of<AdminDataProvider>(context, listen: false);

    final newPost = PostItem(
      id: '',
      title: titleController.text.trim(),
      content: contentController.text.trim(),
      postType: postType,
      targetMajor: targetAudience,
      createdAt: DateTime.now().toIso8601String(),
    );

    await adminData.addPost(auth.accessToken, newPost, attachedFiles);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("تم نشر المنشور بنجاح وإرسال الإشعارات!"),
        backgroundColor: const Color(0xF21E2D28),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9999), side: const BorderSide(color: kAccentGold)),
      ),
    );
    widget.onPostCreated();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: CustomTopAppBar(
        title: "إنشاء منشور جديد",
        trailing: IconButton(icon: const Icon(Icons.close_rounded, color: kOnSurface), onPressed: widget.onPostCreated),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 84),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDropdown("نوع المنشور", postType, const ["محاضرات", "جدول", "فعاليات", "أخبار"], (v) => setState(() => postType = v!)),
            const SizedBox(height: 14),
            const Text("العنوان", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kOnSurfaceVariant)),
            const SizedBox(height: 6),
            Container(
              height: 48,
              decoration: BoxDecoration(color: kSurfaceContainerHigh, borderRadius: BorderRadius.circular(12), border: Border.all(color: kOutlineVariant)),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const Icon(Icons.edit_note_rounded, size: 20, color: kOnSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: titleController, style: const TextStyle(fontSize: 13, color: Colors.white), decoration: const InputDecoration(border: InputBorder.none, hintText: "عنوان المنشور هنا..."))),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const Text("النص أو التفاصيل", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kOnSurfaceVariant)),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(color: kSurfaceContainerHigh, borderRadius: BorderRadius.circular(12), border: Border.all(color: kOutlineVariant)),
              padding: const EdgeInsets.all(12),
              child: TextField(controller: contentController, maxLines: 4, style: const TextStyle(fontSize: 13, color: Colors.white), decoration: const InputDecoration(border: InputBorder.none, hintText: "اكتب التفاصيل هنا...")),
            ),
            const SizedBox(height: 14),
            _buildDropdown("الجهة المستهدفة", targetAudience, const ["الكل", "ميكانيكا", "تصنيع", "مدنية", "كهربا"], (v) => setState(() => targetAudience = v!)),
            const SizedBox(height: 16),
            const Text("المرفقات المتعددة", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kOnSurfaceVariant)),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _pickFiles,
              child: CustomPaint(
                painter: DashedBorderPainter(color: kOutline, strokeWidth: 2, gap: 5, radius: 16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  decoration: BoxDecoration(color: kSurfaceContainer, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: const [
                      Icon(Icons.cloud_upload_outlined, size: 32, color: kAccentGold),
                      SizedBox(height: 6),
                      Text("اضغط لاختيار صور أو ملفات", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ),
            if (attachedFiles.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...attachedFiles.map((fname) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: kSurfaceContainerHigh, borderRadius: BorderRadius.circular(8)),
                    child: Text(fname.split('/').last, style: const TextStyle(color: kAccentGold, fontSize: 12)),
                  )),
            ],
            const SizedBox(height: 20),
            InkWell(
              onTap: _publish,
              borderRadius: BorderRadius.circular(9999),
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFDFBE7A), Color(0xFFC5A059), Color(0xFF9A7736)]),
                  borderRadius: BorderRadius.circular(9999),
                ),
                alignment: Alignment.center,
                child: const Text("نشر وإرسال إشعار فوري للطلاب", style: TextStyle(color: Color(0xFF0A1210), fontWeight: FontWeight.w700, fontSize: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kOnSurfaceVariant)),
        const SizedBox(height: 6),
        Container(
          height: 48,
          decoration: BoxDecoration(color: kSurfaceContainerHigh, borderRadius: BorderRadius.circular(12), border: Border.all(color: kOutlineVariant)),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: kSurfaceContainerHigh,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: kOnSurfaceVariant),
              style: const TextStyle(fontSize: 13, color: Colors.white, fontFamily: 'Noto Sans Arabic'),
              items: items.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 4. MANAGE POSTS TAB
// ==========================================
class ManagePostsTab extends StatelessWidget {
  final Function(String postId) onViewReactions;
  const ManagePostsTab({super.key, required this.onViewReactions});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final adminData = Provider.of<AdminDataProvider>(context);

    return Scaffold(
      backgroundColor: kSurface,
      appBar: const CustomTopAppBar(
        title: "إدارة المنشورات",
        badgeText: "جميع التخصصات",
      ),
      body: adminData.posts.isEmpty
          ? const Center(child: Text("لا توجد منشورات حالياً", style: TextStyle(color: kOnSurfaceVariant)))
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 84),
              itemCount: adminData.posts.length,
              itemBuilder: (context, index) {
                final p = adminData.posts[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xCC1E2D28), Color(0xF2101916)]),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kOutlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("${p.postType} • ${p.targetMajor}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kSuccess)),
                          Text(p.createdAt.substring(0, 10), style: const TextStyle(fontSize: 11, color: kOnSurfaceVariant)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(p.title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white)),
                      const SizedBox(height: 4),
                      Text(p.content, style: const TextStyle(fontSize: 12, color: kOnSurfaceVariant, height: 1.5), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => onViewReactions(p.id),
                            child: Text("👍 ${p.countLike} | ❤️ ${p.countLove} | 🙏 ${p.countPray}", style: const TextStyle(fontSize: 12, color: kAccentGold, fontWeight: FontWeight.w600)),
                          ),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => _showEditDialog(context, auth.accessToken, p),
                                child: Container(
                                  height: 32,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(border: Border.all(color: kOutline), borderRadius: BorderRadius.circular(9999)),
                                  alignment: Alignment.center,
                                  child: const Text("تعديل", style: TextStyle(fontSize: 12, color: kOnSurface, fontWeight: FontWeight.w600)),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => adminData.deletePost(auth.accessToken, p.id),
                                child: Container(
                                  height: 32,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(color: kError.withValues(alpha: 0.15), border: Border.all(color: kError.withValues(alpha: 0.3)), borderRadius: BorderRadius.circular(9999)),
                                  alignment: Alignment.center,
                                  child: const Text("حذف", style: TextStyle(fontSize: 12, color: kError, fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  static void _showEditDialog(BuildContext context, String? token, PostItem post) {
    final titleCtrl = TextEditingController(text: post.title);
    final contentCtrl = TextEditingController(text: post.content);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kSurfaceContainerHigh,
        title: const Text("تعديل المنشور", style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 10),
            TextField(controller: contentCtrl, maxLines: 3, style: const TextStyle(color: Colors.white)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("إلغاء", style: TextStyle(color: kOnSurfaceVariant))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kAccentGold, foregroundColor: Colors.black),
            onPressed: () {
              post.title = titleCtrl.text.trim();
              post.content = contentCtrl.text.trim();
              Provider.of<AdminDataProvider>(context, listen: false).updatePost(token, post);
              Navigator.pop(ctx);
            },
            child: const Text("حفظ"),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 5. MONITOR REACTIONS TAB
// ==========================================
class ReactionsTab extends StatefulWidget {
  const ReactionsTab({super.key});

  @override
  State<ReactionsTab> createState() => _ReactionsTabState();
}

class _ReactionsTabState extends State<ReactionsTab> {
  String selectedFilter = 'الكل';

  @override
  Widget build(BuildContext context) {
    final adminData = Provider.of<AdminDataProvider>(context);
    final activePost = adminData.activeReactionPost;

    final filtered = adminData.reactions.where((r) {
      if (activePost != null && r.postId != activePost.id) return false;
      if (selectedFilter == 'الكل') return true;
      return r.emoji == selectedFilter;
    }).toList();

    return Scaffold(
      backgroundColor: kSurface,
      appBar: const CustomTopAppBar(
        title: "متابعة التفاعلات",
        badgeText: "إيموجي فقط",
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 48,
            color: const Color(0xE60A1210),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _buildFilterChip("الكل", 'الكل'),
                const SizedBox(width: 8),
                _buildFilterChip("👍", '👍'),
                const SizedBox(width: 8),
                _buildFilterChip("❤️", '❤️'),
                const SizedBox(width: 8),
                _buildFilterChip("🙏", '🙏'),
              ],
            ),
          ),
          if (activePost != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text("المنشور: ${activePost.title}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kAccentGold)),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 84),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final r = filtered[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xCC1E2D28), Color(0xF2101916)]),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kOutlineVariant),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(color: kPrimaryContainer, shape: BoxShape.circle, border: Border.all(color: kAccentGold.withValues(alpha: 0.3))),
                            alignment: Alignment.center,
                            child: Text(r.studentName.isNotEmpty ? r.studentName.substring(0, 1) : 'ط', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kAccentGold)),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.studentName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)),
                              Text("تخصص ${r.studentMajor}", style: const TextStyle(fontSize: 11, color: kOnSurfaceVariant)),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(color: kAccentGold.withValues(alpha: 0.15), shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text(r.emoji, style: const TextStyle(fontSize: 20)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final bool active = selectedFilter == value;
    return GestureDetector(
      onTap: () => setState(() => selectedFilter = value),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? kPrimaryContainer : kSurfaceContainerHigh,
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: active ? kAccentGold.withValues(alpha: 0.4) : kOutlineVariant),
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: active ? kAccentGold : kOnSurfaceVariant)),
      ),
    );
  }
}

// ==========================================
// CUSTOM DASHED BORDER PAINTER
// ==========================================
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double radius;

  DashedBorderPainter({required this.color, this.strokeWidth = 2.0, this.gap = 5.0, this.radius = 16.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2, size.width - strokeWidth, size.height - strokeWidth),
      Radius.circular(radius),
    );

    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics().first;
    final totalLength = metrics.length;
    double distance = 0;

    final dashLength = gap * 1.5;
    while (distance < totalLength) {
      final extractLength = (distance + dashLength < totalLength) ? dashLength : totalLength - distance;
      canvas.drawPath(metrics.extractPath(distance, distance + extractLength), paint);
      distance += dashLength + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
