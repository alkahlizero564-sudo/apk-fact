import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
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

const List<String> kMajors = ["ميكانيكا", "تصنيع", "مدنية", "كهربا"];
const List<String> kPostTypes = ["الكل", "جدول", "محاضرات", "فعاليات", "أخبار"];
const List<String> kEmojis = ["👍", "❤️", "😂", "😮", "😢", "🙏"];

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: firebaseOptions);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(options: firebaseOptions);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const ShauagerCustomerApp());
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

  StudentProfile({
    required this.id,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.major,
    required this.role,
  });

  factory StudentProfile.fromJson(Map<String, dynamic> json) {
    return StudentProfile(
      id: json['id'] ?? json['customer_id'] ?? '',
      fullName: json['full_name'] ?? 'طالب جديد',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      major: json['major'] ?? 'ميكانيكا',
      role: json['role'] ?? 'customer',
    );
  }
}

class PostItem {
  final String id;
  final String title;
  final String content;
  final String postType;
  final String targetMajor;
  final String createdAt;
  int countLike;
  int countLove;
  int countLaugh;
  int countWow;
  int countSad;
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
    this.countLaugh = 0,
    this.countWow = 0,
    this.countSad = 0,
    this.countPray = 0,
    this.attachments = const [],
  });

  factory PostItem.fromJson(Map<String, dynamic> json) {
    return PostItem(
      id: json['id'] ?? '',
      title: json['title'] ?? 'بدون عنوان',
      content: json['content'] ?? '',
      postType: json['post_type'] ?? 'أخبار',
      targetMajor: json['target_major'] ?? 'الكل',
      createdAt: json['created_at'] ?? DateTime.now().toIso8601String(),
      countLike: json['count_like'] ?? 0,
      countLove: json['count_love'] ?? 0,
      countLaugh: json['count_laugh'] ?? 0,
      countWow: json['count_wow'] ?? 0,
      countSad: json['count_sad'] ?? 0,
      countPray: json['count_pray'] ?? 0,
    );
  }

  int getCountForEmoji(String emoji) {
    switch (emoji) {
      case '👍': return countLike;
      case '❤️': return countLove;
      case '😂': return countLaugh;
      case '😮': return countWow;
      case '😢': return countSad;
      case '🙏': return countPray;
      default: return 0;
    }
  }

  void updateCount(String emoji, int delta) {
    switch (emoji) {
      case '👍': countLike = (countLike + delta).clamp(0, 99999); break;
      case '❤️': countLove = (countLove + delta).clamp(0, 99999); break;
      case '😂': countLaugh = (countLaugh + delta).clamp(0, 99999); break;
      case '😮': countWow = (countWow + delta).clamp(0, 99999); break;
      case '😢': countSad = (countSad + delta).clamp(0, 99999); break;
      case '🙏': countPray = (countPray + delta).clamp(0, 99999); break;
    }
  }
}

class AttachmentItem {
  final String id;
  final String postId;
  final String fileName;
  final String fileUrl;
  final String fileType;
  final int fileSizeBytes;
  final String? description;

  AttachmentItem({
    required this.id,
    required this.postId,
    required this.fileName,
    required this.fileUrl,
    required this.fileType,
    required this.fileSizeBytes,
    this.description,
  });

  factory AttachmentItem.fromJson(Map<String, dynamic> json) {
    return AttachmentItem(
      id: json['id'] ?? '',
      postId: json['post_id'] ?? '',
      fileName: json['file_name'] ?? 'ملف',
      fileUrl: json['file_url'] ?? '',
      fileType: json['file_type'] ?? 'other',
      fileSizeBytes: json['file_size_bytes'] ?? 0,
      description: json['description'],
    );
  }
}

class DownloadedRecord {
  final String id;
  final String attachmentId;
  final String postId;
  final String fileName;
  final String localPath;
  final String fileType;
  final String createdAt;

  DownloadedRecord({
    required this.id,
    required this.attachmentId,
    required this.postId,
    required this.fileName,
    required this.localPath,
    required this.fileType,
    required this.createdAt,
  });

  factory DownloadedRecord.fromJson(Map<String, dynamic> json) {
    return DownloadedRecord(
      id: json['id'] ?? '',
      attachmentId: json['attachment_id'] ?? '',
      postId: json['post_id'] ?? '',
      fileName: json['file_name'] ?? 'ملف محمل',
      localPath: json['local_path'] ?? '',
      fileType: json['file_type'] ?? 'other',
      createdAt: json['created_at'] ?? DateTime.now().toIso8601String(),
    );
  }
}

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String createdAt;
  final String? readAt;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? '',
      title: json['title'] ?? 'إشعار جديد',
      body: json['body'] ?? '',
      createdAt: json['created_at'] ?? '',
      readAt: json['read_at'],
    );
  }

  bool get isRead => readAt != null;
}

// ==========================================
// PROVIDERS
// ==========================================
class AuthProvider extends ChangeNotifier {
  String? _accessToken;
  String? _refreshToken;
  String? _userId;
  StudentProfile? _profile;
  bool _isLoading = false;
  String? _errorMessage;

  String? get accessToken => _accessToken;
  String? get userId => _userId;
  StudentProfile? get profile => _profile;
  bool get isAuthenticated => _accessToken != null && _userId != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    _loadSession();
  }

  Map<String, String> _getHeaders({bool includeAuth = true}) {
    final headers = <String, String>{
      'apikey': kSupabaseAnonKey,
      'Content-Type': 'application/json',
      'Prefer': 'return=representation',
    };
    if (includeAuth && _accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('access_token');
    _refreshToken = prefs.getString('refresh_token');
    _userId = prefs.getString('user_id');

    if (_accessToken != null && _userId != null) {
      await fetchProfile();
    }
    notifyListeners();
  }

  Future<void> _saveSession(String token, String refreshToken, String uid) async {
    _accessToken = token;
    _refreshToken = refreshToken;
    _userId = uid;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
    await prefs.setString('refresh_token', refreshToken);
    await prefs.setString('user_id', uid);
    notifyListeners();
  }

  Future<bool> _tryRefreshToken() async {
    if (_refreshToken == null) return false;
    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/token?grant_type=refresh_token'),
        headers: _getHeaders(includeAuth: false),
        body: jsonEncode({'refresh_token': _refreshToken}),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final token = body['access_token'];
        final refresh = body['refresh_token'] ?? _refreshToken;
        final uid = body['user']['id'];
        await _saveSession(token, refresh, uid);
        return true;
      }
    } catch (_) {}
    signOut();
    return false;
  }

  Future<http.Response> authenticatedRequest(Future<http.Response> Function(String token) requestFn) async {
    if (_accessToken == null) {
      return http.Response('No session', 401);
    }
    var res = await requestFn(_accessToken!);
    if (res.statusCode == 401) {
      final refreshed = await _tryRefreshToken();
      if (refreshed && _accessToken != null) {
        res = await requestFn(_accessToken!);
      }
    }
    return res;
  }

  Future<bool> signUp({
    required String name,
    required String phone,
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/signup'),
        headers: _getHeaders(includeAuth: false),
        body: jsonEncode({
          'email': email,
          'password': password,
          'data': {'full_name': name, 'phone': phone}
        }),
      );

      final body = jsonDecode(res.body);
      if (res.statusCode >= 400) {
        _handleError(body, isSendRequest: true);
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = "ما قدرنا نرسل البريد: $e";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> resendSignupCode(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/resend'),
        headers: _getHeaders(includeAuth: false),
        body: jsonEncode({'type': 'signup', 'email': email}),
      );

      final body = jsonDecode(res.body);
      if (res.statusCode >= 400) {
        _handleError(body, isSendRequest: true);
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = "ما قدرنا نرسل البريد";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyOtp(String email, String code, String major, String name, String phone) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/verify'),
        headers: _getHeaders(includeAuth: false),
        body: jsonEncode({
          'type': 'signup',
          'email': email,
          'token': code,
        }),
      );

      final body = jsonDecode(res.body);
      if (res.statusCode >= 400) {
        _errorMessage = 'رمز التحقق غير صحيح أو منتهي الصلاحية';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final token = body['access_token'];
      final refresh = body['refresh_token'] ?? '';
      final uid = body['user']['id'];

      await _saveSession(token, refresh, uid);
      await _upsertStudentDetails(uid, name, phone, email, major);
      await fetchProfile();
      await registerDeviceToken();
      await _notifyAdminNewStudent(uid, name);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = "خطأ أثناء تأكيد الرمز: $e";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signIn(String emailOrPhone, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    String email = emailOrPhone.trim();
    if (!email.contains('@')) {
      email = "$email@shauager.com";
    }

    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/token?grant_type=password'),
        headers: _getHeaders(includeAuth: false),
        body: jsonEncode({'email': email, 'password': password}),
      );

      final body = jsonDecode(res.body);
      if (res.statusCode >= 400) {
        final msg = body['msg'] ?? body['message'] ?? body['error_description'] ?? body['error'];
        if (msg != null && msg.toString().toLowerCase().contains('email not confirmed')) {
          await resendSignupCode(email);
          _errorMessage = 'البريد غير مؤكد. تم إعادة إرسال الرمز.';
          _isLoading = false;
          notifyListeners();
          return false;
        }
        _handleError(body, isSendRequest: false);
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final token = body['access_token'];
      final refresh = body['refresh_token'] ?? '';
      final uid = body['user']['id'];

      await _saveSession(token, refresh, uid);
      await fetchProfile();
      await registerDeviceToken();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = "فشل تسجيل الدخول. تأكد من الاتصال.";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> recoverPassword(String email) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/recover'),
        headers: _getHeaders(includeAuth: false),
        body: jsonEncode({'email': email}),
      );

      final body = jsonDecode(res.body);
      if (res.statusCode >= 400) {
        _handleError(body, isSendRequest: true);
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = "ما قدرنا نرسل البريد";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyRecoveryOtp(String email, String code) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await http.post(
        Uri.parse('$kSupabaseUrl/auth/v1/verify'),
        headers: _getHeaders(includeAuth: false),
        body: jsonEncode({
          'type': 'recovery',
          'email': email,
          'token': code,
        }),
      );

      final body = jsonDecode(res.body);
      if (res.statusCode >= 400) {
        _errorMessage = 'رمز التحقق غير صحيح أو منتهي الصلاحية';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final token = body['access_token'];
      final refresh = body['refresh_token'] ?? '';
      final uid = body['user']['id'];
      await _saveSession(token, refresh, uid);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = "رمز التحقق غير صحيح أو منتهي الصلاحية";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updatePassword(String newPassword) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await authenticatedRequest((token) => http.put(
            Uri.parse('$kSupabaseUrl/auth/v1/user'),
            headers: _getHeaders(includeAuth: true),
            body: jsonEncode({'password': newPassword}),
          ));

      if (res.statusCode >= 400) {
        _errorMessage = 'فشل تحديث كلمة المرور';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = "فشل تحديث كلمة المرور";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchProfile() async {
    if (_userId == null) return;
    try {
      final res = await authenticatedRequest((token) => http.get(
            Uri.parse('$kSupabaseUrl/rest/v1/shauager_profiles?id=eq.$_userId'),
            headers: _getHeaders(includeAuth: true),
          ));

      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        if (list.isNotEmpty) {
          _profile = StudentProfile.fromJson(list.first);
        } else {
          await _fetchStudentDetailsFallback();
        }
      }
    } catch (e) {
      debugPrint("Profile fetch error: $e");
    }
    notifyListeners();
  }

  Future<void> _fetchStudentDetailsFallback() async {
    if (_userId == null) return;
    try {
      final res = await authenticatedRequest((token) => http.get(
            Uri.parse('$kSupabaseUrl/rest/v1/shauager_student_details?customer_id=eq.$_userId'),
            headers: _getHeaders(includeAuth: true),
          ));

      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        if (list.isNotEmpty) {
          _profile = StudentProfile.fromJson(list.first);
        }
      }
    } catch (_) {}
  }

  Future<bool> updateProfile(String name, String phone, String major) async {
    if (_userId == null) return false;
    _isLoading = true;
    notifyListeners();

    try {
      await authenticatedRequest((token) => http.patch(
            Uri.parse('$kSupabaseUrl/rest/v1/shauager_profiles?id=eq.$_userId'),
            headers: _getHeaders(includeAuth: true),
            body: jsonEncode({
              'full_name': name,
              'phone': phone,
            }),
          ));

      final res = await authenticatedRequest((token) => http.patch(
            Uri.parse('$kSupabaseUrl/rest/v1/shauager_student_details?customer_id=eq.$_userId'),
            headers: _getHeaders(includeAuth: true),
            body: jsonEncode({
              'full_name': name,
              'phone': phone,
              'major': major,
              'updated_at': DateTime.now().toIso8601String(),
            }),
          ));

      if (res.statusCode < 300) {
        await fetchProfile();
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint("Update error: $e");
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<void> _upsertStudentDetails(String uid, String name, String phone, String email, String major) async {
    try {
      await authenticatedRequest((token) => http.post(
            Uri.parse('$kSupabaseUrl/rest/v1/shauager_student_details'),
            headers: _getHeaders(includeAuth: true),
            body: jsonEncode({
              'customer_id': uid,
              'full_name': name,
              'phone': phone,
              'email': email,
              'major': major,
              'created_at': DateTime.now().toIso8601String(),
            }),
          ));
    } catch (e) {
      debugPrint("Upsert error: $e");
    }
  }

  Future<void> registerDeviceToken() async {
    try {
      await FirebaseMessaging.instance.requestPermission();
      final deviceToken = await FirebaseMessaging.instance.getToken();
      if (deviceToken != null && _accessToken != null) {
        await http.post(
          Uri.parse('$kSupabaseUrl/rest/v1/rpc/shauager_register_device'),
          headers: _getHeaders(includeAuth: true),
          body: jsonEncode({
            'device_token': deviceToken,
            'app_name': 'customer',
          }),
        );
      }
    } catch (e) {
      debugPrint("Register device token error: $e");
    }
  }

  Future<void> _notifyAdminNewStudent(String uid, String name) async {
    try {
      await http.post(
        Uri.parse('$kSupabaseUrl/rest/v1/shauager_notifications'),
        headers: _getHeaders(includeAuth: true),
        body: jsonEncode({
          'to_role': 'admin',
          'title': 'انضمام طالب جديد للتطبيق',
          'body': 'انضم الطالب الجديد $name إلى التطبيق بنجاح.',
          'data': {'customer_id': uid},
        }),
      );
    } catch (_) {}
  }

  void signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _accessToken = null;
    _refreshToken = null;
    _userId = null;
    _profile = null;
    notifyListeners();
  }

  void _handleError(Map<String, dynamic> body, {required bool isSendRequest}) {
    final msg = body['msg'] ?? body['message'] ?? body['error_description'] ?? body['error'];
    final strMsg = msg?.toString().toLowerCase() ?? '';
    if (strMsg.contains('rate limit')) {
      _errorMessage = 'اتبعتت رسائل كتير، استنى دقايق';
    } else if (strMsg.contains('smtp') || strMsg.contains('email') || strMsg.contains('sending') || strMsg.contains('connect')) {
      _errorMessage = 'ما قدرنا نرسل البريد';
    } else if (isSendRequest) {
      _errorMessage = 'ما قدرنا نرسل البريد';
    } else {
      _errorMessage = msg?.toString() ?? 'حدث خطأ، حاول مرة أخرى';
    }
  }
}

class PostsProvider extends ChangeNotifier {
  List<PostItem> _posts = [];
  final Map<String, String> _userReactions = {};
  bool _isLoading = false;
  String _selectedCategory = 'الكل';

  List<PostItem> get posts {
    if (_selectedCategory == 'الكل') return _posts;
    return _posts.where((p) => p.postType == _selectedCategory).toList();
  }

  bool get isLoading => _isLoading;
  String get selectedCategory => _selectedCategory;

  void setCategory(String cat) {
    _selectedCategory = cat;
    notifyListeners();
  }

  Future<void> fetchPosts(AuthProvider auth) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await auth.authenticatedRequest((token) => http.get(
            Uri.parse('$kSupabaseUrl/rest/v1/shauager_posts?order=created_at.desc'),
            headers: {
              'apikey': kSupabaseAnonKey,
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          ));

      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        _posts = list.map((j) => PostItem.fromJson(j)).toList();

        final userMajor = auth.profile?.major;
        if (userMajor != null) {
          _posts = _posts.where((p) => p.targetMajor == 'الكل' || p.targetMajor == userMajor).toList();
        }

        await _fetchAttachments(auth);

        if (auth.userId != null) {
          await _fetchUserReactions(auth);
        }
      }
    } catch (e) {
      debugPrint("Error fetching posts: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _fetchAttachments(AuthProvider auth) async {
    try {
      final res = await auth.authenticatedRequest((token) => http.get(
            Uri.parse('$kSupabaseUrl/rest/v1/shauager_attachments'),
            headers: {
              'apikey': kSupabaseAnonKey,
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          ));

      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        final attachments = list.map((j) => AttachmentItem.fromJson(j)).toList();

        for (var post in _posts) {
          post.attachments = attachments.where((a) => a.postId == post.id).toList();
        }
      }
    } catch (e) {
      debugPrint("Error attachments: $e");
    }
  }

  Future<void> _fetchUserReactions(AuthProvider auth) async {
    if (auth.userId == null) return;
    try {
      final res = await auth.authenticatedRequest((token) => http.get(
            Uri.parse('$kSupabaseUrl/rest/v1/shauager_reactions?customer_id=eq.${auth.userId}'),
            headers: {
              'apikey': kSupabaseAnonKey,
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          ));

      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        _userReactions.clear();
        for (var item in list) {
          _userReactions[item['post_id']] = item['emoji'];
        }
      }
    } catch (e) {
      debugPrint("Error user reactions: $e");
    }
  }

  String? getUserReaction(String postId) => _userReactions[postId];

  Future<void> toggleReaction({
    required String postId,
    required String emoji,
    required AuthProvider auth,
  }) async {
    if (auth.userId == null) return;

    final post = _posts.firstWhere((p) => p.id == postId, orElse: () => PostItem(id: '', title: '', content: '', postType: '', targetMajor: '', createdAt: ''));
    if (post.id.isEmpty) return;

    final currentEmoji = _userReactions[postId];

    if (currentEmoji == emoji) {
      _userReactions.remove(postId);
      post.updateCount(emoji, -1);
      notifyListeners();

      try {
        await auth.authenticatedRequest((token) => http.delete(
              Uri.parse('$kSupabaseUrl/rest/v1/shauager_reactions?post_id=eq.$postId&customer_id=eq.${auth.userId}'),
              headers: {
                'apikey': kSupabaseAnonKey,
                'Authorization': 'Bearer $token',
              },
            ));
      } catch (_) {}
    } else {
      if (currentEmoji != null) {
        post.updateCount(currentEmoji, -1);
      }
      _userReactions[postId] = emoji;
      post.updateCount(emoji, 1);
      notifyListeners();

      try {
        if (currentEmoji != null) {
          await auth.authenticatedRequest((token) => http.patch(
                Uri.parse('$kSupabaseUrl/rest/v1/shauager_reactions?post_id=eq.$postId&customer_id=eq.${auth.userId}'),
                headers: {
                  'apikey': kSupabaseAnonKey,
                  'Authorization': 'Bearer $token',
                  'Content-Type': 'application/json',
                },
                body: jsonEncode({'emoji': emoji}),
              ));
        } else {
          await auth.authenticatedRequest((token) => http.post(
                Uri.parse('$kSupabaseUrl/rest/v1/shauager_reactions'),
                headers: {
                  'apikey': kSupabaseAnonKey,
                  'Authorization': 'Bearer $token',
                  'Content-Type': 'application/json',
                },
                body: jsonEncode({
                  'post_id': postId,
                  'customer_id': auth.userId,
                  'emoji': emoji,
                }),
              ));
        }
      } catch (_) {}
    }
  }
}

class DownloadsProvider extends ChangeNotifier {
  final Map<String, double> _downloadProgress = {};
  final Map<String, bool> _isDownloading = {};
  final Map<String, bool> _cancelFlags = {};
  final List<DownloadedRecord> _downloadedRecords = [];
  bool _isLoading = false;

  Map<String, double> get downloadProgress => _downloadProgress;
  List<DownloadedRecord> get downloadedRecords => _downloadedRecords;
  bool get isLoading => _isLoading;

  bool isDownloading(String attachmentId) => _isDownloading[attachmentId] ?? false;
  double getProgress(String attachmentId) => _downloadProgress[attachmentId] ?? 0.0;
  bool isAttachmentDownloaded(String attachmentId) =>
      _downloadedRecords.any((r) => r.attachmentId == attachmentId);

  Future<void> fetchDownloadedRecords(AuthProvider auth) async {
    if (auth.userId == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      final res = await auth.authenticatedRequest((token) => http.get(
            Uri.parse('$kSupabaseUrl/rest/v1/shauager_downloads?customer_id=eq.${auth.userId}&order=created_at.desc'),
            headers: {
              'apikey': kSupabaseAnonKey,
              'Authorization': 'Bearer $token',
            },
          ));

      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        _downloadedRecords.clear();
        for (var item in list) {
          _downloadedRecords.add(DownloadedRecord.fromJson(item));
        }
      }
    } catch (e) {
      debugPrint("Fetch downloads error: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> downloadAttachment({
    required AttachmentItem attachment,
    required AuthProvider auth,
  }) async {
    if (isAttachmentDownloaded(attachment.id)) return;

    final id = attachment.id;
    _isDownloading[id] = true;
    _downloadProgress[id] = 0.05;
    _cancelFlags[id] = false;
    notifyListeners();

    for (int step = 1; step <= 10; step++) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (_cancelFlags[id] == true) {
        _isDownloading[id] = false;
        _downloadProgress.remove(id);
        _cancelFlags.remove(id);
        notifyListeners();
        return;
      }
      _downloadProgress[id] = step / 10.0;
      notifyListeners();
    }

    Directory targetDir;
    if (Platform.isAndroid && (attachment.fileType == 'image' || attachment.fileType == 'video')) {
      targetDir = await getApplicationDocumentsDirectory();
    } else {
      targetDir = (await getDownloadsDirectory()) ?? (await getApplicationDocumentsDirectory());
    }

    final localPath = "${targetDir.path}/shauager_${attachment.fileName}";

    if (auth.userId != null) {
      try {
        final res = await auth.authenticatedRequest((token) => http.post(
              Uri.parse('$kSupabaseUrl/rest/v1/shauager_downloads'),
              headers: {
                'apikey': kSupabaseAnonKey,
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
                'Prefer': 'return=representation',
              },
              body: jsonEncode({
                'customer_id': auth.userId,
                'attachment_id': attachment.id,
                'post_id': attachment.postId,
                'file_name': attachment.fileName,
                'file_type': attachment.fileType,
                'local_path': localPath,
                'created_at': DateTime.now().toIso8601String(),
              }),
            ));

        if (res.statusCode < 300) {
          final body = jsonDecode(res.body);
          if (body is List && body.isNotEmpty) {
            _downloadedRecords.insert(0, DownloadedRecord.fromJson(body.first));
          }
        }
      } catch (e) {
        debugPrint("Save download DB error: $e");
      }
    }

    _isDownloading[id] = false;
    notifyListeners();
  }

  void cancelDownload(String attachmentId) {
    _cancelFlags[attachmentId] = true;
    notifyListeners();
  }
}

class NotificationsProvider extends ChangeNotifier {
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;
  bool get isLoading => _isLoading;

  Future<void> fetchNotifications(AuthProvider auth) async {
    if (auth.userId == null) return;
    _isLoading = true;
    notifyListeners();

    try {
      final res = await auth.authenticatedRequest((token) => http.get(
            Uri.parse('$kSupabaseUrl/rest/v1/shauager_notifications?or=(to_user.eq.${auth.userId},to_role.eq.customer)&order=created_at.desc'),
            headers: {
              'apikey': kSupabaseAnonKey,
              'Authorization': 'Bearer $token',
            },
          ));

      if (res.statusCode == 200) {
        final List list = jsonDecode(res.body);
        _notifications = list.map((j) => NotificationModel.fromJson(j)).toList();
      }
    } catch (e) {
      debugPrint("Fetch notifications error: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> markAllAsRead(AuthProvider auth) async {
    for (var n in _notifications) {
      if (!n.isRead) {
        try {
          await auth.authenticatedRequest((token) => http.patch(
                Uri.parse('$kSupabaseUrl/rest/v1/shauager_notifications?id=eq.${n.id}'),
                headers: {
                  'apikey': kSupabaseAnonKey,
                  'Authorization': 'Bearer $token',
                  'Content-Type': 'application/json',
                },
                body: jsonEncode({'read_at': DateTime.now().toIso8601String()}),
              ));
        } catch (_) {}
      }
    }
    fetchNotifications(auth);
  }
}

// ==========================================
// MAIN APP ENTRY & THEME
// ==========================================
class ShauagerCustomerApp extends StatelessWidget {
  const ShauagerCustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PostsProvider()),
        ChangeNotifierProvider(create: (_) => DownloadsProvider()),
        ChangeNotifierProvider(create: (_) => NotificationsProvider()),
      ],
      child: MaterialApp(
        title: 'شواغر 22 - Shauager',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF0A1210),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0D3B2E),
            brightness: Brightness.dark,
            primary: const Color(0xFF0D3B2E),
            onPrimary: Colors.white,
            primaryContainer: const Color(0xFF1B4D3E),
            secondary: const Color(0xFFC5A059),
            onSecondary: const Color(0xFF1C1500),
            surface: const Color(0xFF141F1C),
            onSurface: const Color(0xFFE8ECEB),
            onSurfaceVariant: const Color(0xFFA4B2AE),
            outline: const Color(0xFF2D3D37),
          ),
          fontFamily: 'Segoe UI',
        ),
        builder: (context, child) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          );
        },
        home: const AppRootWrapper(),
      ),
    );
  }
}

class AppRootWrapper extends StatefulWidget {
  const AppRootWrapper({super.key});

  @override
  State<AppRootWrapper> createState() => _AppRootWrapperState();
}

class _AppRootWrapperState extends State<AppRootWrapper> with WidgetsBindingObserver {
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPeriodicSync();
    _setupPushNotifications();
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
      _triggerDataRefresh();
    }
  }

  void _startPeriodicSync() {
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _triggerDataRefresh();
    });
  }

  void _triggerDataRefresh() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isAuthenticated) {
      final posts = Provider.of<PostsProvider>(context, listen: false);
      final downloads = Provider.of<DownloadsProvider>(context, listen: false);
      final notifs = Provider.of<NotificationsProvider>(context, listen: false);
      posts.fetchPosts(auth);
      downloads.fetchDownloadedRecords(auth);
      notifs.fetchNotifications(auth);
    }
  }

  void _setupPushNotifications() async {
    try {
      final messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم رفض إذن الإشعارات. يرجى تفعيلها لتلقي التنبيهات الفورية.'),
              backgroundColor: Color(0xFFC5A059),
            ),
          );
        }
        return;
      }
      final token = await messaging.getToken();
      debugPrint("FCM Token: $token");

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _triggerDataRefresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message.notification?.title ?? "إشعار جديد وصل"),
              backgroundColor: const Color(0xFFC5A059),
            ),
          );
        }
      });
    } catch (e) {
      debugPrint("Notification setup warning: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    if (!auth.isAuthenticated) {
      return const LoginScreen();
    }

    return const MainNavigationScreen();
  }
}

// ==========================================
// SCREEN 1: LOGIN SCREEN
// ==========================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailPhoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 30),
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1B4D3E), Color(0xFF0D3B2E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: const Color(0xFFC5A059), width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 16,
                          offset: Offset(0, 8),
                        )
                      ],
                    ),
                    child: const Icon(Icons.school_outlined, size: 44, color: Color(0xFFC5A059)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'شواغر 22',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const Text(
                  'تطبيق الطلاب • دفعة الهندسة',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFFC5A059), fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 36),

                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141F1C),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF2D3D37)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'تسجيل الدخول',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _emailPhoneController,
                        decoration: InputDecoration(
                          labelText: 'البريد الإلكتروني',
                          prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFFA4B2AE)),
                          filled: true,
                          fillColor: const Color(0xFF1E2D28),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور',
                          prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFA4B2AE)),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: const Color(0xFFA4B2AE)),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF1E2D28),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()));
                          },
                          child: const Text('نسيت كلمة المرور؟', style: TextStyle(color: Color(0xFFC5A059))),
                        ),
                      ),
                      if (auth.errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          auth.errorMessage!,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 52,
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFC5A059),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            elevation: 4,
                          ),
                          onPressed: auth.isLoading
                              ? null
                              : () async {
                                  final ok = await auth.signIn(
                                    _emailPhoneController.text,
                                    _passwordController.text,
                                  );
                                  if (!ok && mounted && auth.errorMessage != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(auth.errorMessage!)),
                                    );
                                  }
                                },
                          child: auth.isLoading
                              ? const CircularProgressIndicator(color: Colors.black)
                              : const Text('دخول للحساب', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('ليس لديك حساب طالب؟ ', style: TextStyle(color: Color(0xFFA4B2AE))),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
                      },
                      child: const Text(
                        'حساب جديد',
                        style: TextStyle(color: Color(0xFFC5A059), fontWeight: FontWeight.bold),
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

// ==========================================
// SCREEN 2: REGISTER SCREEN
// ==========================================
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String _selectedMajor = "ميكانيكا";

  String? _nameError;
  String? _phoneError;
  String? _emailError;
  String? _passwordError;
  String? _confirmError;

  bool _validateFields() {
    setState(() {
      _nameError = _nameController.text.trim().isEmpty ? 'الاسم الكامل مطلوب' : null;
      _phoneError = _phoneController.text.trim().isEmpty ? 'رقم الهاتف مطلوب' : null;
      _emailError = _emailController.text.trim().isEmpty ? 'البريد الإلكتروني مطلوب' : null;
      _passwordError = _passwordController.text.length < 6 ? 'كلمة المرور يجب أن تكون 6 خانات أو أكثر' : null;
      _confirmError = _confirmPasswordController.text != _passwordController.text ? 'كلمتا المرور غير متطابقتين' : null;
    });
    return _nameError == null && _phoneError == null && _emailError == null && _passwordError == null && _confirmError == null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('حساب جديد'),
        backgroundColor: const Color(0xFF141F1C),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'الاسم الكامل',
                  prefixIcon: const Icon(Icons.person_outline),
                  errorText: _nameError,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'رقم الهاتف',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  errorText: _phoneError,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'البريد الإلكتروني',
                  prefixIcon: const Icon(Icons.email_outlined),
                  errorText: _emailError,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'كلمة المرور',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  errorText: _passwordError,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'تأكيد كلمة المرور',
                  prefixIcon: const Icon(Icons.lock_reset),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                  errorText: _confirmError,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedMajor,
                items: kMajors.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedMajor = val);
                },
                decoration: const InputDecoration(
                  labelText: 'التخصص',
                  prefixIcon: Icon(Icons.engineering_outlined),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFC5A059),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: auth.isLoading
                      ? null
                      : () async {
                          if (!_validateFields()) return;

                          final ok = await auth.signUp(
                            name: _nameController.text.trim(),
                            phone: _phoneController.text.trim(),
                            email: _emailController.text.trim(),
                            password: _passwordController.text.trim(),
                          );

                          if (ok && mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => OtpVerificationScreen(
                                  email: _emailController.text.trim(),
                                  major: _selectedMajor,
                                  name: _nameController.text.trim(),
                                  phone: _phoneController.text.trim(),
                                ),
                              ),
                            );
                          } else if (mounted && auth.errorMessage != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(auth.errorMessage!)),
                            );
                          }
                        },
                  child: auth.isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text('تسجيل حساب جديد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// SCREEN 3: OTP VERIFICATION
// ==========================================
class OtpVerificationScreen extends StatefulWidget {
  final String email;
  final String major;
  final String name;
  final String phone;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    required this.major,
    required this.name,
    required this.phone,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  int _resendCountdown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    setState(() => _resendCountdown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
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
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('تأكيد البريد الإلكتروني')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.mark_email_read_outlined, size: 64, color: Color(0xFFC5A059)),
            const SizedBox(height: 16),
            Text(
              'بعتنا رمز على بريدك',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'تم إرسال رمز التحقق إلى ${widget.email}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFA4B2AE)),
            ),
            const SizedBox(height: 32),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(6, (i) {
                  return SizedBox(
                    width: 44,
                    height: 52,
                    child: TextField(
                      controller: _controllers[i],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 1,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFC5A059)),
                      decoration: InputDecoration(
                        counterText: '',
                        filled: true,
                        fillColor: const Color(0xFF1E2D28),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (val) {
                        if (val.isNotEmpty && i < 5) {
                          FocusScope.of(context).nextFocus();
                        }
                      },
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC5A059),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: auth.isLoading
                    ? null
                    : () async {
                        final code = _controllers.map((c) => c.text).join();
                        if (code.length < 6) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('الرجاء إدخال الرمز كاملاً')),
                          );
                          return;
                        }

                        final ok = await auth.verifyOtp(
                          widget.email,
                          code,
                          widget.major,
                          widget.name,
                          widget.phone,
                        );

                        if (ok && mounted) {
                          Navigator.popUntil(context, (route) => route.isFirst);
                        } else if (mounted && auth.errorMessage != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(auth.errorMessage!)),
                          );
                        }
                      },
                child: auth.isLoading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text('تأكيد الحساب والدخول', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _resendCountdown > 0
                  ? null
                  : () async {
                      final ok = await auth.resendSignupCode(widget.email);
                      if (ok) {
                        _startTimer();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم إعادة إرسال الرمز بنجاح')),
                          );
                        }
                      } else if (mounted && auth.errorMessage != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(auth.errorMessage!)),
                        );
                      }
                    },
              child: Text(
                _resendCountdown > 0 ? 'إعادة إرسال الرمز بعد $_resendCountdown ثانية' : 'إعادة إرسال الرمز',
                style: TextStyle(color: _resendCountdown > 0 ? Colors.grey : const Color(0xFFC5A059)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// SCREEN 3.1: FORGOT PASSWORD SCREEN
// ==========================================
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(6, (_) => TextEditingController());
  final _newPasswordController = TextEditingController();
  int _step = 1; // 1: Email, 2: Code, 3: New Password

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('نسيت كلمة المرور')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              if (_step == 1) ...[
                const Icon(Icons.lock_reset, size: 64, color: Color(0xFFC5A059)),
                const SizedBox(height: 16),
                const Text('أدخل بريدك الإلكتروني لاستلام رمز استعادة كلمة المرور', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'البريد الإلكتروني', prefixIcon: Icon(Icons.email_outlined)),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC5A059), foregroundColor: Colors.black),
                    onPressed: auth.isLoading
                        ? null
                        : () async {
                            final ok = await auth.recoverPassword(_emailController.text.trim());
                            if (ok) {
                              setState(() => _step = 2);
                            } else if (mounted && auth.errorMessage != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(auth.errorMessage!)),
                              );
                            }
                          },
                    child: auth.isLoading ? const CircularProgressIndicator(color: Colors.black) : const Text('إرسال الرمز'),
                  ),
                ),
              ] else if (_step == 2) ...[
                const Icon(Icons.mark_email_read_outlined, size: 64, color: Color(0xFFC5A059)),
                const SizedBox(height: 16),
                const Text('أدخل رمز التحقق المرسل لبريدك', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(6, (i) {
                      return SizedBox(
                        width: 44,
                        height: 52,
                        child: TextField(
                          controller: _otpControllers[i],
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          maxLength: 1,
                          decoration: const InputDecoration(counterText: '', filled: true, fillColor: Color(0xFF1E2D28)),
                          onChanged: (val) {
                            if (val.isNotEmpty && i < 5) FocusScope.of(context).nextFocus();
                          },
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC5A059), foregroundColor: Colors.black),
                    onPressed: auth.isLoading
                        ? null
                        : () async {
                            final code = _otpControllers.map((c) => c.text).join();
                            final ok = await auth.verifyRecoveryOtp(_emailController.text.trim(), code);
                            if (ok) {
                              setState(() => _step = 3);
                            } else if (mounted && auth.errorMessage != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(auth.errorMessage!)),
                              );
                            }
                          },
                    child: auth.isLoading ? const CircularProgressIndicator(color: Colors.black) : const Text('تحقق من الرمز'),
                  ),
                ),
              ] else if (_step == 3) ...[
                const Icon(Icons.lock_outline, size: 64, color: Color(0xFFC5A059)),
                const SizedBox(height: 16),
                const Text('أدخل كلمة المرور الجديدة', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                TextField(
                  controller: _newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة', prefixIcon: Icon(Icons.lock)),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC5A059), foregroundColor: Colors.black),
                    onPressed: auth.isLoading
                        ? null
                        : () async {
                            final ok = await auth.updatePassword(_newPasswordController.text.trim());
                            if (ok && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('تم تغيير كلمة المرور بنجاح')),
                              );
                              Navigator.pop(context);
                            } else if (mounted && auth.errorMessage != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(auth.errorMessage!)),
                              );
                            }
                          },
                    child: auth.isLoading ? const CircularProgressIndicator(color: Colors.black) : const Text('حفظ كلمة المرور'),
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// SCREEN 4: MAIN NAVIGATION CONTAINER
// ==========================================
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomeScreen(),
    DownloadsScreen(),
    NotificationsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final posts = Provider.of<PostsProvider>(context, listen: false);
      final downloads = Provider.of<DownloadsProvider>(context, listen: false);
      final notifs = Provider.of<NotificationsProvider>(context, listen: false);

      posts.fetchPosts(auth);
      downloads.fetchDownloadedRecords(auth);
      notifs.fetchNotifications(auth);
    });
  }

  @override
  Widget build(BuildContext context) {
    final notifs = Provider.of<NotificationsProvider>(context);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        height: 72,
        decoration: BoxDecoration(
          color: const Color(0xFF0E1714).withValues(alpha: 0.95),
          border: const Border(top: BorderSide(color: Color(0x26C5A059), width: 1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, 'الرئيسة', Icons.home_outlined),
            _buildNavItem(1, 'التحميلات', Icons.download_outlined),
            _buildNavItem(2, 'الإشعارات', Icons.notifications_outlined, badgeCount: notifs.unreadCount),
            _buildNavItem(3, 'حسابي', Icons.person_outline),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String label, IconData icon, {int badgeCount = 0}) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      child: Container(
        width: 64,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 56,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF1B4D3E) : Colors.transparent,
                borderRadius: BorderRadius.circular(9999),
                boxShadow: isSelected ? [const BoxShadow(color: Color(0x33C5A059), blurRadius: 12)] : [],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    icon,
                    size: 22,
                    color: isSelected ? const Color(0xFFC5A059) : const Color(0xFFA4B2AE),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      top: 4,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        constraints: const BoxConstraints(minWidth: 12, minHeight: 12),
                        child: Text('$badgeCount', style: const TextStyle(color: Colors.white, fontSize: 8), textAlign: TextAlign.center),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFFC5A059) : const Color(0xFFA4B2AE),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// TAB 1: HOME FEED SCREEN
// ==========================================
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final postsProv = Provider.of<PostsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF101916),
        title: Row(
          children: [
            const Text('شواغر 22', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1B4D3E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFC5A059), width: 0.8),
              ),
              child: Text(
                auth.profile?.major ?? 'ميكانيكا',
                style: const TextStyle(fontSize: 12, color: Color(0xFFC5A059), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: kPostTypes.map((type) {
                final selected = postsProv.selectedCategory == type;
                return Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: FilterChip(
                    label: Text(type),
                    selected: selected,
                    selectedColor: const Color(0xFF1B4D3E),
                    checkmarkColor: const Color(0xFFC5A059),
                    labelStyle: TextStyle(
                      color: selected ? const Color(0xFFC5A059) : const Color(0xFFA4B2AE),
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (_) => postsProv.setCategory(type),
                  ),
                );
              }).toList(),
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await postsProv.fetchPosts(auth);
              },
              child: postsProv.isLoading
                  ? const SkeletonFeedLoader()
                  : postsProv.posts.isEmpty
                      ? const EmptyStateWidget()
                      : ListView.builder(
                          itemCount: postsProv.posts.length,
                          padding: const EdgeInsets.only(bottom: 24),
                          itemBuilder: (context, index) {
                            final post = postsProv.posts[index];
                            return PostCardWidget(post: post);
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// POST CARD WIDGET WITH ATTACHMENT DOWNLOADS
// ==========================================
class PostCardWidget extends StatelessWidget {
  final PostItem post;

  const PostCardWidget({super.key, required this.post});

  Color _getTagColor(String type) {
    switch (type) {
      case 'جدول': return const Color(0xFF4FC3F7);
      case 'محاضرات': return const Color(0xFF4BE09B);
      case 'فعاليات': return const Color(0xFFC5A059);
      default: return const Color(0xFFFF5449);
    }
  }

  void _showEmojiPopover(BuildContext context, PostItem post, AuthProvider auth, PostsProvider postsProv) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0x141F1CE6),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: 90,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: kEmojis.map((e) {
              return InkWell(
                onTap: () {
                  Navigator.pop(ctx);
                  postsProv.toggleReaction(
                    postId: post.id,
                    emoji: e,
                    auth: auth,
                  );
                },
                child: Text(e, style: const TextStyle(fontSize: 28)),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final postsProv = Provider.of<PostsProvider>(context);
    final downloadsProv = Provider.of<DownloadsProvider>(context);
    final myReaction = postsProv.getUserReaction(post.id);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141F1C),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF2D3D37)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))
        ],
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
                  color: _getTagColor(post.postType).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _getTagColor(post.postType).withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${post.postType} • ${post.targetMajor}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _getTagColor(post.postType)),
                ),
              ),
              Text(
                post.createdAt.length >= 10 ? post.createdAt.substring(0, 10) : post.createdAt,
                style: const TextStyle(fontSize: 12, color: Color(0xFFA4B2AE)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            post.title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Text(
            post.content,
            style: const TextStyle(fontSize: 14, color: Color(0xFFA4B2AE), height: 1.5),
          ),

          if (post.attachments.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2D28),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF2D3D37)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'المرفقات (${post.attachments.length})',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFA4B2AE)),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: const Color(0xFFC5A059),
                        ),
                        onPressed: () {
                          for (var att in post.attachments) {
                            downloadsProv.downloadAttachment(
                              attachment: att,
                              auth: auth,
                            );
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('جاري تحميل كافة مرفقات المنشور...')),
                          );
                        },
                        icon: const Icon(Icons.download_for_offline_outlined, size: 16),
                        label: const Text('تحميل الكل', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Column(
                    children: post.attachments.map((att) {
                      final downloaded = downloadsProv.isAttachmentDownloaded(att.id);
                      final downloading = downloadsProv.isDownloading(att.id);
                      final progress = downloadsProv.getProgress(att.id);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF141F1C),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF2D3D37)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => AttachmentViewerScreen(attachment: att),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1B4D3E),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Center(
                                      child: Text(
                                        att.fileType.toUpperCase().substring(0, att.fileType.length > 3 ? 3 : att.fileType.length),
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFC5A059)),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => AttachmentViewerScreen(attachment: att),
                                        ),
                                      );
                                    },
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          att.fileName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                        ),
                                        Text(
                                          downloaded
                                              ? 'محمل مسبقاً ✓'
                                              : downloading
                                                  ? 'جاري التحميل... ${(progress * 100).toInt()}%'
                                                  : 'انقر للمعاينة والتحميل',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: downloaded ? const Color(0xFF4BE09B) : const Color(0xFFA4B2AE),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                if (downloaded) ...[
                                  const Icon(Icons.check_circle, color: Color(0xFF4BE09B), size: 22),
                                ] else if (downloading) ...[
                                  IconButton(
                                    icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 20),
                                    onPressed: () => downloadsProv.cancelDownload(att.id),
                                  )
                                ] else ...[
                                  IconButton(
                                    icon: const Icon(Icons.download, color: Color(0xFFC5A059), size: 20),
                                    onPressed: () {
                                      downloadsProv.downloadAttachment(
                                        attachment: att,
                                        auth: auth,
                                      );
                                    },
                                  )
                                ]
                              ],
                            ),
                            if (downloading) ...[
                              const SizedBox(height: 6),
                              LinearProgressIndicator(
                                value: progress,
                                backgroundColor: const Color(0xFF1E2D28),
                                color: const Color(0xFFC5A059),
                              ),
                            ]
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),
          const Divider(color: Color(0xFF2D3D37)),

          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  children: kEmojis.map((emoji) {
                    final count = post.getCountForEmoji(emoji);
                    final isMine = myReaction == emoji;
                    if (count == 0 && !isMine) return const SizedBox.shrink();

                    return InkWell(
                      onTap: () {
                        postsProv.toggleReaction(
                          postId: post.id,
                          emoji: emoji,
                          auth: auth,
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isMine ? const Color(0xFF1B4D3E) : const Color(0xFF1E2D28),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isMine ? const Color(0xFFC5A059) : const Color(0xFF2D3D37),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(emoji, style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 4),
                            Text(
                              '$count',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isMine ? const Color(0xFFC5A059) : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_reaction_outlined, color: Color(0xFFC5A059)),
                onPressed: () => _showEmojiPopover(context, post, auth, postsProv),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==========================================
// SCREEN 6: ATTACHMENT DETAIL & MEDIA VIEWER
// ==========================================
class AttachmentViewerScreen extends StatelessWidget {
  final AttachmentItem attachment;

  const AttachmentViewerScreen({super.key, required this.attachment});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final downloadsProv = Provider.of<DownloadsProvider>(context);
    final isDownloaded = downloadsProv.isAttachmentDownloaded(attachment.id);
    final isDownloading = downloadsProv.isDownloading(attachment.id);
    final progress = downloadsProv.getProgress(attachment.id);

    return Scaffold(
      appBar: AppBar(
        title: Text(attachment.fileName),
        backgroundColor: const Color(0xFF141F1C),
        actions: [
          if (isDownloaded)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Icon(Icons.check_circle, color: Color(0xFF4BE09B)),
            )
          else
            IconButton(
              icon: const Icon(Icons.download, color: Color(0xFFC5A059)),
              onPressed: () {
                downloadsProv.downloadAttachment(
                  attachment: attachment,
                  auth: auth,
                );
              },
            )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF141F1C),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF2D3D37)),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        attachment.fileType == 'image'
                            ? Icons.image_outlined
                            : attachment.fileType == 'video'
                                ? Icons.video_library_outlined
                                : Icons.insert_drive_file_outlined,
                        size: 80,
                        color: const Color(0xFFC5A059),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        attachment.fileName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'نوع المرفق: ${attachment.fileType.toUpperCase()}',
                        style: const TextStyle(color: Color(0xFFA4B2AE)),
                      ),
                      if (attachment.fileSizeBytes > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          'الحجم: ${(attachment.fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB',
                          style: const TextStyle(color: Color(0xFFA4B2AE), fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (isDownloading) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('نسبة التحميل: ${(progress * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () => downloadsProv.cancelDownload(attachment.id),
                    child: const Text('إلغاء التحميل', style: TextStyle(color: Colors.redAccent)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xFF1E2D28),
                color: const Color(0xFFC5A059),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDownloaded ? const Color(0xFF1B4D3E) : const Color(0xFFC5A059),
                  foregroundColor: isDownloaded ? Colors.white : Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: isDownloaded
                    ? () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('المرفق محمل مسبقاً ومتاح للأوفلاين ✓')),
                        );
                      }
                    : () {
                        downloadsProv.downloadAttachment(
                          attachment: attachment,
                          auth: auth,
                        );
                      },
                icon: Icon(isDownloaded ? Icons.check : Icons.download),
                label: Text(
                  isDownloaded
                      ? (attachment.fileType == 'image' || attachment.fileType == 'video'
                          ? 'محفوظ في المعرض ✓'
                          : 'محفوظ في التنزيلات ✓')
                      : 'تحميل وسطي للجهاز',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// TAB 2: DOWNLOADS & OFFLINE SCREEN
// ==========================================
class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final downloadsProv = Provider.of<DownloadsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('التنزيلات (Offline)'),
        backgroundColor: const Color(0xFF101916),
      ),
      body: RefreshIndicator(
        onRefresh: () => downloadsProv.fetchDownloadedRecords(auth),
        child: downloadsProv.downloadedRecords.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.download_done_outlined, size: 64, color: Color(0xFFC5A059)),
                    SizedBox(height: 12),
                    Text('لا توجد تنزيلات حالياً', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    SizedBox(height: 6),
                    Text('يمكنك تحميل المرفقات من المنشورات لقراءتها بدون إنترنت', style: TextStyle(color: Color(0xFFA4B2AE), fontSize: 13)),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: downloadsProv.downloadedRecords.length,
                itemBuilder: (ctx, i) {
                  final record = downloadsProv.downloadedRecords[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141F1C),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF2D3D37)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B4D3E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.file_present_outlined, color: Color(0xFFC5A059)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(record.fileName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 2),
                              Text('متاح للأوفلاين • ${record.createdAt.substring(0, 10)}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFFA4B2AE))),
                            ],
                          ),
                        ),
                        const Icon(Icons.check_circle, color: Color(0xFF4BE09B)),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

// ==========================================
// TAB 3: NOTIFICATIONS SCREEN
// ==========================================
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final notifProv = Provider.of<NotificationsProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        backgroundColor: const Color(0xFF101916),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all, color: Color(0xFFC5A059)),
            onPressed: () => notifProv.markAllAsRead(auth),
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => notifProv.fetchNotifications(auth),
        child: notifProv.notifications.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.notifications_none, size: 64, color: Color(0xFFC5A059)),
                    SizedBox(height: 12),
                    Text('لا توجد إشعارات حالياً', style: TextStyle(color: Color(0xFFA4B2AE))),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: notifProv.notifications.length,
                itemBuilder: (ctx, i) {
                  final item = notifProv.notifications[i];
                  return Container(
                    color: item.isRead ? Colors.transparent : const Color(0xFF141F1C),
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor: const Color(0xFF1B4D3E),
                          child: const Icon(Icons.notifications, color: Color(0xFFC5A059), size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text(item.body, style: const TextStyle(color: Color(0xFFA4B2AE), fontSize: 13)),
                            ],
                          ),
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

// ==========================================
// TAB 4: PROFILE & EDIT ACCOUNT
// ==========================================
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String _major = "ميكانيكا";

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _nameController.text = auth.profile?.fullName ?? '';
    _phoneController.text = auth.profile?.phone ?? '';
    _major = auth.profile?.major ?? 'ميكانيكا';
  }

  void _saveChanges() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final ok = await auth.updateProfile(_nameController.text.trim(), _phoneController.text.trim(), _major);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ البيانات بنجاح')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي'),
        backgroundColor: const Color(0xFF101916),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Color(0xFFC5A059)),
            onPressed: _saveChanges,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Center(
              child: CircleAvatar(
                radius: 44,
                backgroundColor: const Color(0xFF1B4D3E),
                child: Text(
                  auth.profile?.fullName.isNotEmpty == true ? auth.profile!.fullName.substring(0, 1) : 'ط',
                  style: const TextStyle(fontSize: 32, color: Color(0xFFC5A059), fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              auth.profile?.fullName ?? '',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              'طالب مسجل • ${auth.profile?.email ?? ''}',
              style: const TextStyle(color: Color(0xFFC5A059), fontSize: 13),
            ),
            const SizedBox(height: 32),

            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'الاسم الكامل',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: kMajors.contains(_major) ? _major : kMajors.first,
              items: kMajors.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _major = val);
              },
              decoration: const InputDecoration(
                labelText: 'تعديل التخصص',
                prefixIcon: Icon(Icons.engineering_outlined),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: () {
                auth.signOut();
              },
              icon: const Icon(Icons.logout),
              label: const Text('تسجيل الخروج', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// SKELETON & EMPTY STATES
// ==========================================
class SkeletonFeedLoader extends StatelessWidget {
  const SkeletonFeedLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 3,
      padding: const EdgeInsets.all(16),
      itemBuilder: (_, _) {
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF141F1C),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 100, height: 20, color: Colors.white10),
              const SizedBox(height: 12),
              Container(width: 200, height: 16, color: Colors.white10),
              const SizedBox(height: 8),
              Container(width: double.infinity, height: 40, color: Colors.white10),
            ],
          ),
        );
      },
    );
  }
}

class EmptyStateWidget extends StatelessWidget {
  const EmptyStateWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.folder_open_outlined, size: 72, color: Color(0xFFC5A059)),
          SizedBox(height: 16),
          Text(
            'لا توجد منشورات حالياً',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          SizedBox(height: 6),
          Text(
            'لم يقم ليدر الدفعة بنشر منشورات لتخصصك بعد',
            style: TextStyle(color: Color(0xFFA4B2AE), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
