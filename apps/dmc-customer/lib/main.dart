import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'backend.dart';
import 'auth_screens.dart';
import 'ui_kit.dart';
import 'screens/home_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/profile_screen.dart';
import 'firebase_config.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: firebaseOptions);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp(options: firebaseOptions);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  
  // Initialize Backend (Supabase, Session, Live Sync)
  await Backend.init();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Professional Medical/Chemical Blue
    const primaryColor = Color(0xFF0052CC);
    
    return MaterialApp(
      title: 'DMC - ديالا للمعدات الطبية',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: Backend.messengerKey,
      // Material 3 Theme with Modern Luxe style
      theme: appTheme(
        seed: primaryColor,
        style: KitStyle.modern,
        brightness: Brightness.light,
      ),
      darkTheme: appTheme(
        seed: primaryColor,
        style: KitStyle.modern,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      // AuthGate handles sign-in/sign-up flow automatically
      home: AuthGate(
        brand: const AuthBrand(
          name: 'DMC ديالا',
          tagline: 'DIALA MEDICAL & CHEMICAL EQUIPMENT',
          icon: Icons.biotech_rounded,
        ),
        home: const MainShell(),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupNotifications();
    _startLiveSync();
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
      Backend.refresh();
    }
  }

  void _startLiveSync() {
    // 15-second live sync as per contract
    _syncTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (Backend.userId.isNotEmpty) {
        Backend.refresh();
      }
    });
  }

  Future<void> _setupNotifications() async {
    final messaging = FirebaseMessaging.instance;
    
    // Request permissions at runtime
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      final token = await messaging.getToken();
      if (token != null) {
        try {
          // Register device for push notifications
          await Backend.rpc('dmc_register_device', {
            'device_token': token,
            'app_name': 'customer',
          });
        } catch (e) {
          debugPrint('Push registration error: $e');
        }
      }
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        Backend.toast(message.notification!.title ?? 'تنبيه جديد');
        Backend.refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppNavShell(
      tabs: [
        const NavTab(
          label: 'الرئيسية',
          icon: Icons.home_rounded,
          page: HomeScreen(),
        ),
        const NavTab(
          label: 'السلة',
          icon: Icons.shopping_basket_rounded,
          page: CartScreen(),
        ),
        const NavTab(
          label: 'طلباتي',
          icon: Icons.assignment_rounded,
          page: OrdersScreen(),
        ),
        NavTab(
          label: 'الإشعارات',
          icon: Icons.notifications_rounded,
          page: const NotificationsScreen(),
          badge: Backend.unread,
        ),
        const NavTab(
          label: 'حسابي',
          icon: Icons.person_rounded,
          page: ProfileScreen(),
        ),
      ],
    );
  }
}
