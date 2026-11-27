// backend.dart — written by APK Fact, NOT by the AI. Do not edit: it is replaced on every generation.
// Everything the app needs from its Supabase backend: sign-in and session, reading and writing tables, files,
// notifications, push and live sync between the two apps of the pair. main.dart only calls these.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_config.dart';

const String kSupabaseUrl = 'https://jvjtgzewumfecjdpekna.supabase.co';
const String kSupabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp2anRnemV3dW1mZWNqZHBla25hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE2NDYzMzcsImV4cCI6MjEwNzIyMjMzN30.1gck73ek8ErBtcF7xAtFM1TdvNim_1NzFVNej_mptBE';
const String kPrefix = 'dmc';
const String kAppRole = 'customer'; // 'customer' or 'admin'
const String kLoginMode = 'phone_email_code';
const String kAuthFunction = 'dmc-auth';
const String kFilesBucket = 'dmc-files';

/// Table names of this pair. Always use these, never a table name written by hand.
class T {
  T._();
  static const String profiles = 'dmc_profiles';
  static const String notifications = 'dmc_notifications';
  static const String settings = 'dmc_settings';
  static const String products = 'dmc_products';
  static const String cartItems = 'dmc_cart_items';
  static const String orders = 'dmc_orders';
  static const String orderItems = 'dmc_order_items';
  static const String ledgerRecords = 'dmc_ledger_records';
}

/// A failed backend call. [message] is Arabic and can be shown to the user as it is.
class BackendException implements Exception {
  BackendException(this.message, {this.status = 0, this.needsCode = false});
  final String message;
  final int status;

  /// True when sign-in failed because the email is not confirmed yet: resend the code and open the code screen.
  final bool needsCode;
  @override
  String toString() => message;
}

enum SignUpResult { signedIn, needsCode }

class Backend {
  Backend._();

  static String? _access;
  static String? _refresh;
  static String? _userId;
  static String? _email;
  static Map<String, dynamic>? _profile;
  static Timer? _syncTimer;
  static bool _started = false;

  /// Put this in MaterialApp(scaffoldMessengerKey: Backend.messengerKey) so messages can be shown from anywhere.
  static final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

  /// Goes up every time the data may have changed (every 15 s while signed in, on a push, when the app comes back
  /// and after every write this app makes). Screens re-read their data when it changes — LiveQuery does that.
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  /// Number of unread notifications for the badge.
  static final ValueNotifier<int> unread = ValueNotifier<int>(0);

  /// true when signed in, false when signed out. Listen to it to switch between the sign-in and the home screens.
  static final ValueNotifier<bool> session = ValueNotifier<bool>(false);

  /// Goes up whenever the profile (name, role) is read again, e.g. after claimAdmin.
  static final ValueNotifier<int> profileChanged = ValueNotifier<int>(0);

  static bool get signedIn => _access != null && _userId != null;
  static String? get userId => _userId;
  static String? get email => _email;
  static Map<String, dynamic> get profile => _profile ?? const {};
  static bool get isAdmin => _profile?['role'] == 'admin';
  static String get fullName => (_profile?['full_name'] ?? '').toString();
  static String get phone => (_profile?['phone'] ?? '').toString();

  /// Call once in main() before runApp: `WidgetsFlutterBinding.ensureInitialized(); await Backend.init();`
  static Future<void> init() async {
    if (_started) return;
    _started = true;
    // Push is for the phone; the web build (used only for the visual check) skips it so start-up never waits on it.
    if (!kIsWeb) {
      try {
        await Firebase.initializeApp(options: firebaseOptions).timeout(const Duration(seconds: 10));
        FirebaseMessaging.onBackgroundMessage(_backgroundPush);
      } catch (_) {}
    }
    WidgetsBinding.instance.addObserver(_Lifecycle());
    final prefs = await SharedPreferences.getInstance();
    _access = prefs.getString('$kPrefix.access');
    _refresh = prefs.getString('$kPrefix.refresh');
    _userId = prefs.getString('$kPrefix.user');
    _email = prefs.getString('$kPrefix.email');
    if (signedIn) {
      try {
        await _afterSignIn();
      } on BackendException catch (e) {
        if (e.status == 401 || e.status == 403) await _forget();
      } catch (_) {
        // No network at start-up: keep the saved session, the sync retries.
        session.value = true;
        _startSync();
      }
    } else if (kLoginMode == 'none') {
      await _anonymousSession();
    }
  }

  // ---------------------------------------------------------------- sign-in

  /// Creates an account. Returns [SignUpResult.needsCode] when a 6-digit code was emailed: then call
  /// [verifySignUpCode]. Uses the fields this app's sign-in mode needs (see the generation rules).
  static Future<SignUpResult> signUp({
    required String fullName,
    String? email,
    String? phone,
    required String password,
  }) async {
    final name = fullName.trim();
    if (kLoginMode == 'phone_password' || kLoginMode == 'email_password') {
      await _call('POST', '/functions/v1/$kAuthFunction', body: {
        'action': 'signup',
        'full_name': name,
        if (phone != null) 'phone': phone.trim(),
        if (email != null) 'email': email.trim().toLowerCase(),
        'password': password,
      }, auth: false);
      await signIn(email: email, phone: phone, password: password);
      return SignUpResult.signedIn;
    }
    final r = await _call('POST', '/auth/v1/signup', body: {
      'email': (email ?? '').trim().toLowerCase(),
      'password': password,
      'data': {'full_name': name, if (phone != null) 'phone': phone.trim()},
    }, auth: false);
    if (r is Map && r['access_token'] != null) {
      await _saveSession(r);
      return SignUpResult.signedIn;
    }
    if (kLoginMode == 'password') {
      await signIn(email: email, password: password);
      return SignUpResult.signedIn;
    }
    return SignUpResult.needsCode;
  }

  /// Confirms the email of a new account with the 6-digit code; signs in.
  static Future<void> verifySignUpCode(String email, String code) async {
    final r = await _call('POST', '/auth/v1/verify',
        body: {'type': 'signup', 'email': email.trim().toLowerCase(), 'token': code.trim()}, auth: false, verify: true);
    await _saveSession(r);
  }

  /// Sends the sign-up code again (wait 60 s between two sends).
  static Future<void> resendSignUpCode(String email) async {
    await _call('POST', '/auth/v1/resend', body: {'type': 'signup', 'email': email.trim().toLowerCase()}, auth: false);
  }

  /// Signs in with a password (email, or phone in the phone_password mode).
  static Future<void> signIn({String? email, String? phone, required String password}) async {
    if (kLoginMode == 'phone_password') {
      final r = await _call('POST', '/functions/v1/$kAuthFunction',
          body: {'action': 'login', 'phone': (phone ?? '').trim(), 'password': password}, auth: false);
      await _saveSession(r);
      return;
    }
    final r = await _call('POST', '/auth/v1/token?grant_type=password',
        body: {'email': (email ?? '').trim().toLowerCase(), 'password': password}, auth: false);
    await _saveSession(r);
  }

  /// Code sign-in (no password): emails a 6-digit code, then call [verifyLoginCode].
  static Future<void> sendLoginCode(String email) async {
    await _call('POST', '/auth/v1/otp', body: {'email': email.trim().toLowerCase(), 'create_user': true}, auth: false);
  }

  static Future<void> verifyLoginCode(String email, String code) async {
    final r = await _call('POST', '/auth/v1/verify',
        body: {'type': 'email', 'email': email.trim().toLowerCase(), 'token': code.trim()}, auth: false, verify: true);
    await _saveSession(r);
  }

  /// Forgotten password: emails a 6-digit code, then call [resetPassword].
  static Future<void> sendPasswordReset(String email) async {
    await _call('POST', '/auth/v1/recover', body: {'email': email.trim().toLowerCase()}, auth: false);
  }

  static Future<void> resetPassword(String email, String code, String newPassword) async {
    final r = await _call('POST', '/auth/v1/verify',
        body: {'type': 'recovery', 'email': email.trim().toLowerCase(), 'token': code.trim()}, auth: false, verify: true);
    await _saveSession(r);
    await _call('PUT', '/auth/v1/user', body: {'password': newPassword});
  }

  /// Admin app only: a new password for a customer who signs in with the phone (there is no SMS).
  static Future<void> setCustomerPassword(String customerPhone, String newPassword) async {
    await _call('POST', '/functions/v1/$kAuthFunction',
        body: {'action': 'set_password', 'phone': customerPhone.trim(), 'password': newPassword});
  }

  /// Admin app: becomes admin (open mode) or proves the admin PIN. Returns true when this user is now an admin.
  static Future<bool> claimAdmin([String? pin]) async {
    final ok = await rpc('${kPrefix}_claim_admin', pin == null ? {} : {'pin': pin.trim()});
    await loadProfile();
    return ok == true || isAdmin;
  }

  static Future<void> signOut() async {
    try {
      if (_access != null) await _call('POST', '/auth/v1/logout', body: {});
    } catch (_) {}
    await _forget();
    if (kLoginMode == 'none') await _anonymousSession();
  }

  /// Re-reads this user's profile (name, phone, role).
  static Future<Map<String, dynamic>> loadProfile() async {
    final rows = await list(T.profiles, filters: {'id': 'eq.$_userId'}, order: null);
    _profile = rows.isEmpty ? {'id': _userId, 'role': 'customer'} : rows.first;
    profileChanged.value++;
    return profile;
  }

  /// Saves the user's own name / phone / other profile fields.
  static Future<void> updateProfile(Map<String, dynamic> changes) async {
    await update(T.profiles, _userId, changes);
    await loadProfile();
  }

  // ---------------------------------------------------------------- data

  /// Reads rows. filters use PostgREST operators: {'status': 'eq.pending', 'price': 'gte.10', 'name': 'ilike.*abc*'}.
  static Future<List<Map<String, dynamic>>> list(
    String table, {
    Map<String, String> filters = const {},
    String select = '*',
    String? order = 'created_at.desc',
    int? limit,
    int? offset,
  }) async {
    final q = <String, String>{'select': select, ...filters};
    if (order != null) q['order'] = order;
    if (limit != null) q['limit'] = '$limit';
    if (offset != null) q['offset'] = '$offset';
    final r = await _call('GET', '/rest/v1/$table', query: q);
    return (r as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// One row by id, or null.
  static Future<Map<String, dynamic>?> byId(String table, Object? id) async {
    final rows = await list(table, filters: {'id': 'eq.$id'}, order: null, limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  /// Number of rows matching [filters].
  static Future<int> count(String table, {Map<String, String> filters = const {}}) async {
    final rows = await list(table, filters: filters, select: 'id', order: null);
    return rows.length;
  }

  /// Adds a row and returns it as saved (with its id). customer_id / created_at are filled by the database.
  static Future<Map<String, dynamic>> insert(String table, Map<String, dynamic> row) async {
    final r = await _call('POST', '/rest/v1/$table', body: row, prefer: 'return=representation');
    _changed();
    return Map<String, dynamic>.from((r as List).first as Map);
  }

  /// Adds several rows at once (e.g. the items of an order).
  static Future<List<Map<String, dynamic>>> insertMany(String table, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return [];
    final r = await _call('POST', '/rest/v1/$table', body: rows, prefer: 'return=representation');
    _changed();
    return (r as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Changes some columns of one row.
  static Future<Map<String, dynamic>?> update(String table, Object? id, Map<String, dynamic> changes) async {
    final r = await _call('PATCH', '/rest/v1/$table', query: {'id': 'eq.$id'}, body: changes, prefer: 'return=representation');
    _changed();
    final rows = r as List;
    return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first as Map);
  }

  static Future<void> delete(String table, Object? id) async {
    await _call('DELETE', '/rest/v1/$table', query: {'id': 'eq.$id'});
    _changed();
  }

  /// Calls a database function with named arguments.
  static Future<dynamic> rpc(String function, [Map<String, dynamic> args = const {}]) {
    return _call('POST', '/rest/v1/rpc/$function', body: args);
  }

  /// Uploads a picture or a file (e.g. from image_picker: `await file.readAsBytes()`) and returns its public URL,
  /// to save in a column such as image_url / receipt_url.
  static Future<String> uploadFile(Uint8List bytes, {String extension = 'jpg', String folder = 'uploads'}) async {
    final ext = extension.replaceAll('.', '').toLowerCase();
    final path = '$folder/${_userId ?? 'anon'}/${DateTime.now().millisecondsSinceEpoch}.$ext';
    final type = const {
          'jpg': 'image/jpeg', 'jpeg': 'image/jpeg', 'png': 'image/png', 'webp': 'image/webp', 'gif': 'image/gif',
          'pdf': 'application/pdf', 'mp4': 'video/mp4', 'mp3': 'audio/mpeg',
        }[ext] ??
        'application/octet-stream';
    await _send('POST', '/storage/v1/object/$kFilesBucket/$path', raw: bytes, contentType: type);
    return '$kSupabaseUrl/storage/v1/object/public/$kFilesBucket/$path';
  }

  // ---------------------------------------------------------------- notifications

  /// This user's notifications, newest first.
  static Future<List<Map<String, dynamic>>> inbox() async {
    if (!signedIn) return [];
    final rows = await list(T.notifications,
        filters: {'or': '(to_user.eq.$_userId,to_role.eq.$kAppRole)'}, limit: 100);
    unread.value = rows.where((n) => n['read_at'] == null).length;
    return rows;
  }

  static Future<void> markRead(Object? id) async {
    await update(T.notifications, id, {'read_at': DateTime.now().toUtc().toIso8601String()});
    await inbox();
  }

  static Future<void> markAllRead() async {
    await _call('PATCH', '/rest/v1/${T.notifications}', query: {
      'or': '(to_user.eq.$_userId,to_role.eq.$kAppRole)',
      'read_at': 'is.null',
    }, body: {'read_at': DateTime.now().toUtc().toIso8601String()});
    await inbox();
  }

  /// Sends a notification (and a push to the phone): to all admins with toRole: 'admin', or to one customer with
  /// toUser: <their user id>. Call it whenever something happens that the other app must know about.
  static Future<void> notify({String? toRole, String? toUser, required String title, String body = '', Map<String, dynamic> data = const {}}) async {
    await _call('POST', '/rest/v1/${T.notifications}', body: {
      if (toRole != null) 'to_role': toRole,
      if (toUser != null) 'to_user': toUser,
      'title': title,
      'body': body,
      'data': data,
    });
  }

  /// Shows a short message at the bottom of the screen.
  static void toast(String text) {
    messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  // ---------------------------------------------------------------- internals

  static void _changed() => changes.value++;

  static Future<void> _anonymousSession() async {
    try {
      final r = await _call('POST', '/auth/v1/signup', body: {}, auth: false);
      await _saveSession(r);
    } catch (_) {}
  }

  static Future<void> _saveSession(dynamic r) async {
    if (r is! Map || r['access_token'] == null) {
      throw BackendException('ما قدرنا نكمّل الدخول، حاول مرة ثانية.');
    }
    _access = r['access_token'] as String;
    _refresh = r['refresh_token'] as String?;
    final user = (r['user'] as Map?) ?? const {};
    _userId = user['id'] as String?;
    _email = user['email'] as String?;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$kPrefix.access', _access!);
    if (_refresh != null) await prefs.setString('$kPrefix.refresh', _refresh!);
    if (_userId != null) await prefs.setString('$kPrefix.user', _userId!);
    if (_email != null) await prefs.setString('$kPrefix.email', _email!);
    await _afterSignIn();
  }

  static Future<void> _afterSignIn() async {
    await loadProfile();
    if (kAppRole == 'admin' && !isAdmin) {
      try {
        await rpc('${kPrefix}_claim_admin', {});
        await loadProfile();
      } catch (_) {}
    }
    session.value = true;
    _startSync();
    unawaited(inbox().catchError((_) => <Map<String, dynamic>>[]));
    if (!kIsWeb) unawaited(_setupPush());
  }

  static Future<void> _forget() async {
    _syncTimer?.cancel();
    _syncTimer = null;
    _access = _refresh = _userId = _email = null;
    _profile = null;
    unread.value = 0;
    session.value = false;
    final prefs = await SharedPreferences.getInstance();
    for (final k in ['access', 'refresh', 'user', 'email']) {
      await prefs.remove('$kPrefix.$k');
    }
  }

  static void _startSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!signedIn) return;
      _changed();
      unawaited(inbox().catchError((_) => <Map<String, dynamic>>[]));
    });
  }

  static Future<bool> _refreshSession() async {
    if (_refresh == null) return false;
    try {
      final res = await http
          .post(Uri.parse('$kSupabaseUrl/auth/v1/token?grant_type=refresh_token'),
              headers: {'apikey': kSupabaseKey, 'Content-Type': 'application/json'},
              body: jsonEncode({'refresh_token': _refresh}))
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return false;
      final r = jsonDecode(res.body) as Map;
      _access = r['access_token'] as String;
      _refresh = r['refresh_token'] as String? ?? _refresh;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$kPrefix.access', _access!);
      if (_refresh != null) await prefs.setString('$kPrefix.refresh', _refresh!);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<dynamic> _call(String method, String path,
      {Map<String, String>? query, Object? body, bool auth = true, String? prefer, bool verify = false}) {
    return _send(method, path, query: query, body: body, auth: auth, prefer: prefer, verify: verify);
  }

  static Future<dynamic> _send(String method, String path,
      {Map<String, String>? query,
      Object? body,
      Uint8List? raw,
      String? contentType,
      bool auth = true,
      String? prefer,
      bool verify = false,
      bool retried = false}) async {
    final uri = Uri.parse('$kSupabaseUrl$path').replace(queryParameters: query == null || query.isEmpty ? null : query);
    final headers = <String, String>{
      'apikey': kSupabaseKey,
      'Content-Type': contentType ?? 'application/json',
      if (auth && _access != null) 'Authorization': 'Bearer $_access',
      if (prefer != null) 'Prefer': prefer,
    };
    final req = http.Request(method, uri)..headers.addAll(headers);
    if (raw != null) {
      req.bodyBytes = raw;
    } else if (body != null) {
      req.body = jsonEncode(body);
    }
    http.Response res;
    try {
      res = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 30)));
    } on TimeoutException {
      throw BackendException('الاتصال بطيء جداً، حاول مرة ثانية.');
    } catch (_) {
      throw BackendException('ما في اتصال بالإنترنت، تأكد من الشبكة وحاول مرة ثانية.');
    }
    if (res.statusCode == 401 && auth && !retried && await _refreshSession()) {
      return _send(method, path,
          query: query, body: body, raw: raw, contentType: contentType, auth: auth, prefer: prefer, verify: verify, retried: true);
    }
    final text = utf8.decode(res.bodyBytes);
    dynamic data;
    try {
      data = text.isEmpty ? null : jsonDecode(text);
    } catch (_) {
      data = text;
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    if (res.statusCode == 401 && auth && _access != null && path.startsWith('/rest/')) {
      await _forget();
      throw BackendException('انتهت الجلسة، سجّل الدخول مرة ثانية.', status: 401);
    }
    throw _error(res.statusCode, data, verify);
  }

  static BackendException _error(int status, dynamic data, bool verify) {
    String raw = '';
    if (data is Map) {
      raw = (data['error_description'] ?? data['msg'] ?? data['message'] ?? data['error'] ?? '').toString();
    } else if (data is String) {
      raw = data;
    }
    final m = raw.toLowerCase();
    String text;
    var needsCode = false;
    if (m.contains('invalid login credentials')) {
      text = 'البيانات غير صحيحة: تأكد من البريد أو الهاتف وكلمة المرور.';
    } else if (m.contains('email not confirmed')) {
      text = 'البريد لسه ما اتأكد. أرسلنا لك رمز التحقق.';
      needsCode = true;
    } else if (m.contains('already registered') || m.contains('already been registered') || m.contains('user_already_exists')) {
      text = 'الحساب ده موجود من قبل، سجّل الدخول.';
    } else if (verify && (m.contains('expired') || m.contains('invalid') || m.contains('otp'))) {
      text = 'الرمز غير صحيح أو انتهت صلاحيته.';
    } else if (m.contains('rate limit') || status == 429) {
      text = 'محاولات كتيرة، استنى دقايق وحاول تاني.';
    } else if (m.contains('smtp') || m.contains('sending')) {
      text = 'ما قدرنا نرسل البريد، حاول بعد شوية.';
    } else if (m.contains('password') && (m.contains('at least') || m.contains('short') || m.contains('weak'))) {
      text = 'كلمة المرور ضعيفة: 6 أحرف على الأقل.';
    } else if (m.contains('row-level security') || status == 403) {
      text = 'ما عندك صلاحية لهذه العملية.';
    } else if (m.contains('duplicate key')) {
      text = 'العنصر ده موجود من قبل.';
    } else if (raw.isNotEmpty && RegExp(r'[؀-ۿ]').hasMatch(raw)) {
      text = raw; // already Arabic (our auth function)
    } else {
      text = 'حصل خطأ ($status)، حاول مرة ثانية.';
    }
    return BackendException(text, status: status, needsCode: needsCode);
  }

  static Future<void> _setupPush() async {
    try {
      final fm = FirebaseMessaging.instance;
      await fm.requestPermission(); // Android 13+ shows pushes only after this
      final token = await fm.getToken();
      if (token != null) {
        await rpc('${kPrefix}_register_device', {'device_token': token, 'app_name': kAppRole});
      }
      fm.onTokenRefresh.listen((t) {
        if (signedIn) rpc('${kPrefix}_register_device', {'device_token': t, 'app_name': kAppRole});
      });
      FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        if (n != null) toast([n.title, n.body].where((s) => s != null && s.isNotEmpty).join(' — '));
        _changed();
        unawaited(inbox().catchError((_) => <Map<String, dynamic>>[]));
      });
      FirebaseMessaging.onMessageOpenedApp.listen((_) => _changed());
    } catch (_) {}
  }
}

@pragma('vm:entry-point')
Future<void> _backgroundPush(RemoteMessage message) async {
  await Firebase.initializeApp(options: firebaseOptions);
}

class _Lifecycle with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && Backend.signedIn) {
      Backend._changed();
      unawaited(Backend.inbox().catchError((_) => <Map<String, dynamic>>[]));
    }
  }
}

/// Shows data from the backend and keeps it fresh: loads it, shows a spinner the first time, an error with a retry
/// button when it fails, [empty] when there is nothing, and re-loads quietly whenever Backend.changes ticks
/// (15-second sync, pushes, writes). Use it for EVERY list or record a screen shows.
///
///   LiveQuery<List<Map<String, dynamic>>>(
///     load: () => Backend.list(T.orders),
///     empty: (rows) => rows.isEmpty,
///     emptyText: 'لا توجد طلبات بعد',
///     builder: (context, rows) => ListView(...),
///   )
class LiveQuery<V> extends StatefulWidget {
  const LiveQuery({
    super.key,
    required this.load,
    required this.builder,
    this.empty,
    this.emptyText = 'لا توجد بيانات بعد',
    this.emptyIcon = Icons.inbox_outlined,
  });

  final Future<V> Function() load;
  final Widget Function(BuildContext context, V data) builder;
  final bool Function(V data)? empty;
  final String emptyText;
  final IconData emptyIcon;

  @override
  State<LiveQuery<V>> createState() => _LiveQueryState<V>();
}

class _LiveQueryState<V> extends State<LiveQuery<V>> {
  V? _data;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Backend.changes.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    Backend.changes.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final d = await widget.load();
      if (!mounted) return;
      setState(() {
        _data = d;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null) {
      if (_loading) return const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
      return _Message(
        icon: Icons.wifi_off_rounded,
        text: _error?.toString() ?? 'حصل خطأ',
        action: TextButton.icon(
          onPressed: () {
            setState(() => _loading = true);
            _reload();
          },
          icon: const Icon(Icons.refresh),
          label: const Text('إعادة المحاولة'),
        ),
      );
    }
    if (widget.empty?.call(data) ?? false) {
      return RefreshIndicator(
        onRefresh: _reload,
        child: ListView(children: [_Message(icon: widget.emptyIcon, text: widget.emptyText)]),
      );
    }
    return RefreshIndicator(onRefresh: _reload, child: widget.builder(context, data));
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 48, color: muted),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center, style: TextStyle(color: muted)),
        if (action != null) ...[const SizedBox(height: 8), action!],
      ]),
    );
  }
}
