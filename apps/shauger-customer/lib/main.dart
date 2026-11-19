import 'package:material_ui/material_ui.dart';

void main() {
  runApp(const ShaugerApp());
}

// ============================================================================
// APP & THEME CONFIGURATION
// ============================================================================
class ShaugerApp extends StatefulWidget {
  const ShaugerApp({super.key});

  static _ShaugerAppState of(BuildContext context) =>
      context.findAncestorStateOfType<_ShaugerAppState>()!;

  @override
  State<ShaugerApp> createState() => _ShaugerAppState();
}

class _ShaugerAppState extends State<ShaugerApp> {
  bool isDarkMode = true;
  String studentName = 'أحمد محمد علي';
  String studentPhone = '0912345678';
  String studentMajor = 'ميكانيكا';
  String studentEmail = 'ahmed@shauger.sd';

  void toggleTheme(bool dark) {
    setState(() => isDarkMode = dark);
  }

  void updateProfile({required String name, required String major, required String email}) {
    setState(() {
      studentName = name;
      studentMajor = major;
      studentEmail = email;
    });
  }

  @override
  Widget build(BuildContext context) {
    const goldPrimary = Color(0xFFD4AF37);
    const darkBg = Color(0xFF0C0F17);
    const darkSurface = Color(0xFF141A29);

    final lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: goldPrimary,
        primary: const Color(0xFFB89728),
        surface: const Color(0xFFFFFFFF),
        brightness: Brightness.light,
      ),
      fontFamily: 'Tajawal',
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    );

    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: goldPrimary,
        primary: goldPrimary,
        surface: darkSurface,
        brightness: Brightness.dark,
      ),
      fontFamily: 'Tajawal',
      scaffoldBackgroundColor: darkBg,
    );

    return MaterialApp(
      title: 'شواغر 22 - تطبيق الطالب',
      debugShowCheckedModeBanner: false,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: lightTheme,
      darkTheme: darkTheme,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: AppContainer(
          isDarkMode: isDarkMode,
          studentName: studentName,
          studentPhone: studentPhone,
          studentMajor: studentMajor,
          studentEmail: studentEmail,
        ),
      ),
    );
  }
}

// ============================================================================
// MAIN APP CONTAINER (Top Switcher, Phone Frame, Drawer, Toast, Modal)
// ============================================================================
class AppContainer extends StatefulWidget {
  final bool isDarkMode;
  final String studentName;
  final String studentPhone;
  final String studentMajor;
  final String studentEmail;

  const AppContainer({
    super.key,
    required this.isDarkMode,
    required this.studentName,
    required this.studentPhone,
    required this.studentMajor,
    required this.studentEmail,
  });

  @override
  State<AppContainer> createState() => _AppContainerState();
}

class _AppContainerState extends State<AppContainer> {
  String currentScreen = 'screen-signin';
  bool isDrawerOpen = false;
  String? toastMessage;
  bool isImageModalOpen = false;

  final Set<String> downloadedFiles = {'جدول_الميكانيكا.png', 'Midterm_Schedule.pdf'};
  final Map<String, String> userPostReactions = {'post_1': '', 'post_2': '❤️'};
  final Map<String, Map<String, int>> postReactionCounts = {
    'post_1': {'👍': 38, '❤️': 14, '🙏': 5},
    'post_2': {'👍': 22, '❤️': 19},
  };

  void showToast(String msg) {
    setState(() => toastMessage = msg);
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && toastMessage == msg) {
        setState(() => toastMessage = null);
      }
    });
  }

  void switchScreen(String screenId) {
    setState(() {
      currentScreen = screenId;
      isDrawerOpen = false;
    });
  }

  void toggleDrawer() {
    setState(() => isDrawerOpen = !isDrawerOpen);
  }

  void reactToPost(String postId, String emoji) {
    setState(() {
      final existing = userPostReactions[postId];
      final counts = postReactionCounts[postId] ?? {};

      if (existing == emoji) {
        // Toggle off
        userPostReactions[postId] = '';
        counts[emoji] = (counts[emoji] ?? 1) - 1;
        if (counts[emoji]! <= 0) counts.remove(emoji);
      } else {
        if (existing != null && existing.isNotEmpty) {
          counts[existing] = (counts[existing] ?? 1) - 1;
          if (counts[existing]! <= 0) counts.remove(existing);
        }
        userPostReactions[postId] = emoji;
        counts[emoji] = (counts[emoji] ?? 0) + 1;
      }
      postReactionCounts[postId] = counts;
    });
    showToast('تم تسجيل تفاعلك بـ $emoji');
  }

  void triggerDownload(String filename) {
    Future.delayed(const Duration(milliseconds: 600), () {
      setState(() {
        downloadedFiles.add(filename);
      });
      showToast('تم تحميل "$filename" بنجاح');
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primary = isDark ? const Color(0xFFD4AF37) : const Color(0xFFB89728);
    final bgApp = isDark ? const Color(0xFF0C0F17) : const Color(0xFFF8FAFC);
    final surface = isDark ? const Color(0xFF141A29) : const Color(0xFFFFFFFF);
    final border = isDark ? const Color(0xFF2A3450) : const Color(0xFFE2E8F0);

    final showBottomNav = currentScreen != 'screen-signin' && currentScreen != 'screen-signup';

    final screens = [
      {'id': 'screen-signin', 'title': 'تسجيل الدخول'},
      {'id': 'screen-signup', 'title': 'إنشاء حساب'},
      {'id': 'screen-home', 'title': 'الرئيسية'},
      {'id': 'screen-tables', 'title': 'الجداول'},
      {'id': 'screen-lectures', 'title': 'المحاضرات'},
      {'id': 'screen-events', 'title': 'الفعاليات والأخبار'},
      {'id': 'screen-downloads', 'title': 'التحميلات'},
      {'id': 'screen-notifications', 'title': 'الإشعارات'},
      {'id': 'screen-profile', 'title': 'الملف الشخصي'},
      {'id': 'screen-settings', 'title': 'الإعدادات'},
      {'id': 'screen-empty', 'title': 'حالة فارغة'},
      {'id': 'screen-skeleton', 'title': 'تحميل (Skeleton)'},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF06090F),
      body: SafeArea(
        child: Column(
          children: [
            // Top Preview switcher bar
            Container(
              height: 48,
              decoration: const BoxDecoration(
                color: Color(0xF20C0F17),
                border: Border(bottom: BorderSide(color: Color(0xFF2A3450))),
              ),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                scrollDirection: Axis.horizontal,
                itemCount: screens.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final s = screens[idx];
                  final isActive = currentScreen == s['id'];
                  return InkWell(
                    onTap: () => switchScreen(s['id']!),
                    borderRadius: BorderRadius.circular(9999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive ? primary : const Color(0xFF141A29),
                        borderRadius: BorderRadius.circular(9999),
                        border: Border.all(
                          color: isActive ? primary : const Color(0xFF2A3450),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        s['title']!,
                        style: TextStyle(
                          color: isActive ? const Color(0xFF0C0F17) : const Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // Phone Frame
            Expanded(
              child: Center(
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 410),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: bgApp,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: border),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 30,
                        offset: Offset(0, 15),
                      )
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      // Active Screen View
                      Positioned.fill(
                        bottom: showBottomNav ? 60 : 0,
                        child: _buildCurrentScreen(isDark, primary, surface, border),
                      ),

                      // Bottom Nav
                      if (showBottomNav)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: 60,
                          child: CustomBottomNavBar(
                            activeScreen: currentScreen,
                            onSelect: switchScreen,
                            primaryColor: primary,
                            surfaceColor: surface,
                            borderColor: border,
                          ),
                        ),

                      // Side Drawer
                      if (isDrawerOpen) ...[
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: toggleDrawer,
                            child: Container(color: Colors.black.withValues(alpha: 0.6)),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          bottom: 0,
                          right: 0,
                          width: 280,
                          child: CustomSideDrawer(
                            studentName: widget.studentName,
                            studentMajor: widget.studentMajor,
                            primaryColor: primary,
                            surfaceColor: surface,
                            borderColor: border,
                            onClose: toggleDrawer,
                            onNavigate: switchScreen,
                            onToast: showToast,
                          ),
                        ),
                      ],

                      // Toast Message
                      if (toastMessage != null)
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: 80,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E263C) : const Color(0xFFF1F5F9),
                              border: Border.all(color: primary),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: const [
                                BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 4))
                              ],
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, size: 18, color: Color(0xFFD4AF37)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    toastMessage!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Image Viewer Modal
                      if (isImageModalOpen)
                        Positioned.fill(
                          child: GestureDetector(
                            onTap: () => setState(() => isImageModalOpen = false),
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.92),
                              padding: const EdgeInsets.all(24),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(36),
                                      decoration: BoxDecoration(
                                        color: primary.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(22),
                                        border: Border.all(color: primary, width: 2),
                                      ),
                                      child: const Text('🖼️', style: TextStyle(fontSize: 64)),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'جدول_الميكانيكا.png',
                                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 6),
                                    const Text(
                                      'اضغط في أي مكان للإغلاق',
                                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentScreen(bool isDark, Color primary, Color surface, Color border) {
    switch (currentScreen) {
      case 'screen-signin':
        return SignInScreen(
          primary: primary,
          onSignInSuccess: () => switchScreen('screen-home'),
          onGoSignUp: () => switchScreen('screen-signup'),
        );
      case 'screen-signup':
        return SignUpScreen(
          primary: primary,
          onSignUpSuccess: (name, phone, major, email) {
            ShaugerApp.of(context).updateProfile(name: name, major: major, email: email);
            showToast('تم إنشاء الحساب وتسجيل الدخول بنجاح!');
            switchScreen('screen-home');
          },
          onBack: () => switchScreen('screen-signin'),
          onToast: showToast,
        );
      case 'screen-home':
        return HomeScreen(
          studentName: widget.studentName,
          studentMajor: widget.studentMajor,
          primary: primary,
          surface: surface,
          border: border,
          onToggleDrawer: toggleDrawer,
          onGoNotifications: () => switchScreen('screen-notifications'),
          onOpenImage: () => setState(() => isImageModalOpen = true),
          onToast: showToast,
          userReactions: userPostReactions,
          reactionCounts: postReactionCounts,
          onReact: reactToPost,
          downloadedFiles: downloadedFiles,
          onDownload: triggerDownload,
        );
      case 'screen-tables':
        return TablesScreen(
          primary: primary,
          surface: surface,
          border: border,
          onToggleDrawer: toggleDrawer,
        );
      case 'screen-lectures':
        return LecturesScreen(
          primary: primary,
          surface: surface,
          border: border,
          onToggleDrawer: toggleDrawer,
          downloadedFiles: downloadedFiles,
          onDownload: triggerDownload,
        );
      case 'screen-events':
        return EventsScreen(
          primary: primary,
          surface: surface,
          border: border,
          onToggleDrawer: toggleDrawer,
        );
      case 'screen-downloads':
        return DownloadsScreen(
          primary: primary,
          surface: surface,
          border: border,
          onToggleDrawer: toggleDrawer,
          downloadedFiles: downloadedFiles,
          onOpenImage: () => setState(() => isImageModalOpen = true),
          onToast: showToast,
        );
      case 'screen-notifications':
        return NotificationsScreen(
          primary: primary,
          surface: surface,
          border: border,
          onBack: () => switchScreen('screen-home'),
        );
      case 'screen-profile':
        return ProfileScreen(
          studentName: widget.studentName,
          studentPhone: widget.studentPhone,
          studentMajor: widget.studentMajor,
          studentEmail: widget.studentEmail,
          primary: primary,
          surface: surface,
          border: border,
          onBack: () => switchScreen('screen-home'),
          onSave: (name, major, email) {
            ShaugerApp.of(context).updateProfile(name: name, major: major, email: email);
            showToast('تم تحديث الملف الشخصي بنجاح');
          },
        );
      case 'screen-settings':
        return SettingsScreen(
          isDark: widget.isDarkMode,
          primary: primary,
          surface: surface,
          border: border,
          onBack: () => switchScreen('screen-home'),
          onToggleTheme: (val) {
            ShaugerApp.of(context).toggleTheme(val);
            showToast(val ? 'تم تفعيل الوضع الليلي الفاخر' : 'تم تفعيل الوضع الفاتح');
          },
          onToast: showToast,
        );
      case 'screen-empty':
        return EmptyStateScreen(
          primary: primary,
          onBack: () => switchScreen('screen-home'),
        );
      case 'screen-skeleton':
        return SkeletonScreen(
          onBack: () => switchScreen('screen-home'),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ============================================================================
// SCREENS
// ============================================================================

// --- 1. SIGN IN SCREEN ---
class SignInScreen extends StatelessWidget {
  final Color primary;
  final VoidCallback onSignInSuccess;
  final VoidCallback onGoSignUp;

  const SignInScreen({
    super.key,
    required this.primary,
    required this.onSignInSuccess,
    required this.onGoSignUp,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          Center(
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: primary, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(
                'ش',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'شواغر 22',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 6),
          const Center(
            child: Text(
              'تسجيل الدخول لتطبيق الطلاب',
              style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
            ),
          ),
          const SizedBox(height: 32),

          const Text(
            'البريد الإلكتروني أو رقم الهاتف',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 6),
          _CustomTextInput(hint: 'name@example.com أو 0912345678', initialValue: '0912345678'),
          const SizedBox(height: 16),

          const Text(
            'كلمة السر',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 6),
          _CustomTextInput(hint: '••••••••', initialValue: 'password123', isPassword: true),
          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: onSignInSuccess,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: const Color(0xFF0C0F17),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
            ),
            child: const Text('دخول', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 24),

          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('ليس لديك حساب؟ ', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                GestureDetector(
                  onTap: onGoSignUp,
                  child: Text(
                    'إنشاء حساب جديد',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: primary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- 2. SIGN UP SCREEN (WITH DIRECT RETURN BUTTON) ---
class SignUpScreen extends StatefulWidget {
  final Color primary;
  final void Function(String name, String phone, String major, String email) onSignUpSuccess;
  final VoidCallback onBack;
  final void Function(String msg) onToast;

  const SignUpScreen({
    super.key,
    required this.primary,
    required this.onSignUpSuccess,
    required this.onBack,
    required this.onToast,
  });

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController(text: 'student@shauger.sd');
  final _passController = TextEditingController(text: '12345678');
  String _selectedMajor = 'ميكانيكا';

  void _submit() {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      widget.onToast('يرجى إدخال الاسم الكامل');
      return;
    }

    final regex = RegExp(r'^(09|01)\d{8}$|^(\+249)\d{9}$');
    if (!regex.hasMatch(phone)) {
      widget.onToast('رقم الهاتف غير صحيح (يجب أن يبدأ بـ 09 أو 01 أو +249)');
      return;
    }

    widget.onSignUpSuccess(name, phone, _selectedMajor, _emailController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CustomAppHeader(
          title: 'حساب جديد',
          leadingIcon: Icons.arrow_back,
          onLeadingPressed: widget.onBack,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: Text('حساب طالب جديد', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 4),
                const Center(
                  child: Text('أنشئ حسابك وتصلك منشورات تخصصك فوراً', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                ),
                const SizedBox(height: 20),

                const Text('الاسم الكامل (إجباري)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
                const SizedBox(height: 6),
                _CustomTextInput(hint: 'مثال: أحمد محمد علي', controller: _nameController),
                const SizedBox(height: 14),

                const Text('رقم الهاتف السوداني (إجباري)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
                const SizedBox(height: 6),
                _CustomTextInput(hint: '09xxxxxxxx أو +249xxxxxxxxx', controller: _phoneController),
                const SizedBox(height: 14),

                const Text('البريد الإلكتروني', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
                const SizedBox(height: 6),
                _CustomTextInput(hint: 'student@shauger.sd', controller: _emailController),
                const SizedBox(height: 14),

                const Text('التخصص', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
                const SizedBox(height: 6),
                _CustomSelectInput(
                  value: _selectedMajor,
                  items: const ['ميكانيكا', 'تصنيع', 'مدنية', 'كهربا'],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedMajor = val);
                  },
                ),
                const SizedBox(height: 14),

                const Text('كلمة السر', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
                const SizedBox(height: 6),
                _CustomTextInput(hint: '••••••••', isPassword: true, controller: _passController),
                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.primary,
                    foregroundColor: const Color(0xFF0C0F17),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('إتمام التسجيل والدخول', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// --- 3. HOME SCREEN ---
class HomeScreen extends StatelessWidget {
  final String studentName;
  final String studentMajor;
  final Color primary;
  final Color surface;
  final Color border;
  final VoidCallback onToggleDrawer;
  final VoidCallback onGoNotifications;
  final VoidCallback onOpenImage;
  final void Function(String msg) onToast;
  final Map<String, String> userReactions;
  final Map<String, Map<String, int>> reactionCounts;
  final void Function(String postId, String emoji) onReact;
  final Set<String> downloadedFiles;
  final void Function(String filename) onDownload;

  const HomeScreen({
    super.key,
    required this.studentName,
    required this.studentMajor,
    required this.primary,
    required this.surface,
    required this.border,
    required this.onToggleDrawer,
    required this.onGoNotifications,
    required this.onOpenImage,
    required this.onToast,
    required this.userReactions,
    required this.reactionCounts,
    required this.onReact,
    required this.downloadedFiles,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CustomAppHeader(
          title: 'شواغر 22',
          leadingIcon: Icons.menu,
          onLeadingPressed: onToggleDrawer,
          actionIcon: Icons.notifications_none,
          onActionPressed: onGoNotifications,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              // Welcome card
              Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF141A29), Color(0xFF1E263C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _BadgeWidget(text: 'تخصص: $studentMajor', primary: primary),
                        const SizedBox(height: 6),
                        Text('أهلاً بك، $studentName', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        const Text('آخر تحديثات الدفعة متوفرة الآن', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                      ],
                    ),
                    const Text('🎓', style: TextStyle(fontSize: 32)),
                  ],
                ),
              ),

              // Post Item 1
              _PostCard(
                badgeText: 'جدول',
                dateText: 'اليوم، 10:30 صباحاً',
                title: 'جدول محاضرات الأسبوع الحالي - ميكانيكا',
                body: 'تم اعتماد جدول المحاضرات والسكاشن العملية للأسبوع الحالي، يرجى الالتزام بالمواعيد المحددة في القاعات الرئيسية.',
                primary: primary,
                surface: surface,
                border: border,
                attachments: [
                  _AttachmentItem(
                    icon: '🖼️',
                    name: 'جدول_الميكانيكا.png',
                    isDownloaded: downloadedFiles.contains('جدول_الميكانيكا.png'),
                    onTap: onOpenImage,
                    onDownload: () => onDownload('جدول_الميكانيكا.png'),
                  ),
                  _AttachmentItem(
                    icon: '📄',
                    name: 'التفاصيل_الكاملة.pdf',
                    isDownloaded: downloadedFiles.contains('التفاصيل_الكاملة.pdf'),
                    onTap: () => onToast('تم فتح ملف PDF داخل التطبيق'),
                    onDownload: () => onDownload('التفاصيل_الكاملة.pdf'),
                  ),
                ],
                postId: 'post_1',
                reactionCounts: reactionCounts['post_1'] ?? {},
                userReaction: userReactions['post_1'] ?? '',
                onReact: onReact,
                onToast: onToast,
              ),

              // Post Item 2
              _PostCard(
                badgeText: 'محاضرة',
                badgeColor: const Color(0xFF3B82F6),
                dateText: 'أمس، 02:00 م',
                title: 'ملخص محاضرة الديناميكا الحرارية (د. خالد)',
                body: 'مرفق أدناه تسجيل الفيديو وملخص المحاضرة الخاصة بالدورات الحرارية وتحليل الأنظمة المفتوحة.',
                primary: primary,
                surface: surface,
                border: border,
                attachments: [
                  _AttachmentItem(
                    icon: '🎬',
                    name: 'محاضرة_3_ديناميكا.mp4',
                    isDownloaded: downloadedFiles.contains('محاضرة_3_ديناميكا.mp4'),
                    onTap: () => onToast('جاري تشغيل الفيديو داخل التطبيق...'),
                    onDownload: () => onDownload('محاضرة_3_ديناميكا.mp4'),
                  ),
                ],
                postId: 'post_2',
                reactionCounts: reactionCounts['post_2'] ?? {},
                userReaction: userReactions['post_2'] ?? '',
                onReact: onReact,
                onToast: onToast,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- 4. TABLES SCREEN ---
class TablesScreen extends StatelessWidget {
  final Color primary;
  final Color surface;
  final Color border;
  final VoidCallback onToggleDrawer;

  const TablesScreen({
    super.key,
    required this.primary,
    required this.surface,
    required this.border,
    required this.onToggleDrawer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CustomAppHeader(
          title: 'الجداول الدراسية',
          leadingIcon: Icons.menu,
          onLeadingPressed: onToggleDrawer,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _PostCard(
                badgeText: 'جدول الامتحانات',
                dateText: 'منذ يومين',
                title: 'جدول الامتحانات النصفي لفصل الخريف',
                body: 'الجدول النهائي لامتحانات الميدترم لجميع تخصصات الدفعة. الرجاء الحضور قبل القاعة بـ 15 دقيقة.',
                primary: primary,
                surface: surface,
                border: border,
                attachments: [
                  _AttachmentItem(
                    icon: '📄',
                    name: 'Midterm_Schedule.pdf',
                    isDownloaded: true,
                    onTap: () {},
                    onDownload: () {},
                  )
                ],
                postId: 'tables_post_1',
                reactionCounts: const {},
                userReaction: '',
                onReact: (_, _) {},
                onToast: (_) {},
                showReactions: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- 5. LECTURES SCREEN ---
class LecturesScreen extends StatelessWidget {
  final Color primary;
  final Color surface;
  final Color border;
  final VoidCallback onToggleDrawer;
  final Set<String> downloadedFiles;
  final void Function(String filename) onDownload;

  const LecturesScreen({
    super.key,
    required this.primary,
    required this.surface,
    required this.border,
    required this.onToggleDrawer,
    required this.downloadedFiles,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CustomAppHeader(
          title: 'المحاضرات',
          leadingIcon: Icons.menu,
          onLeadingPressed: onToggleDrawer,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _PostCard(
                badgeText: 'محاضرة',
                badgeColor: const Color(0xFF3B82F6),
                dateText: 'قبل 3 أيام',
                title: 'مقاومة المواد - المحاضرة الخامسة',
                body: 'شرح تفصيلي لإجهادات الانحناء والقص مع الأمثلة التطبيقية.',
                primary: primary,
                surface: surface,
                border: border,
                attachments: [
                  _AttachmentItem(
                    icon: '🎬',
                    name: 'Strength_Lecture5.mp4',
                    isDownloaded: downloadedFiles.contains('Strength_Lecture5.mp4'),
                    onTap: () {},
                    onDownload: () => onDownload('Strength_Lecture5.mp4'),
                  )
                ],
                postId: 'lecture_post_1',
                reactionCounts: const {},
                userReaction: '',
                onReact: (_, _) {},
                onToast: (_) {},
                showReactions: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- 6. EVENTS SCREEN ---
class EventsScreen extends StatelessWidget {
  final Color primary;
  final Color surface;
  final Color border;
  final VoidCallback onToggleDrawer;

  const EventsScreen({
    super.key,
    required this.primary,
    required this.surface,
    required this.border,
    required this.onToggleDrawer,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CustomAppHeader(
          title: 'الفعاليات والأخبار',
          leadingIcon: Icons.menu,
          onLeadingPressed: onToggleDrawer,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _PostCard(
                badgeText: 'فعالية',
                badgeColor: const Color(0xFF10B981),
                dateText: 'اليوم',
                title: 'زيارة ميدانية لمصنع التجميع والإنتاج',
                body: 'تنظم إدارة الدفعة زيارة ميدانية هندسية لطلاب ميكانيكا وتصنيع يوم الخميس القادم. التسجيل عبر ليدر الدفعة.',
                primary: primary,
                surface: surface,
                border: border,
                attachments: const [],
                postId: 'events_post_1',
                reactionCounts: const {},
                userReaction: '',
                onReact: (_, _) {},
                onToast: (_) {},
                showReactions: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- 7. DOWNLOADS SCREEN ---
class DownloadsScreen extends StatelessWidget {
  final Color primary;
  final Color surface;
  final Color border;
  final VoidCallback onToggleDrawer;
  final Set<String> downloadedFiles;
  final VoidCallback onOpenImage;
  final void Function(String msg) onToast;

  const DownloadsScreen({
    super.key,
    required this.primary,
    required this.surface,
    required this.border,
    required this.onToggleDrawer,
    required this.downloadedFiles,
    required this.onOpenImage,
    required this.onToast,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CustomAppHeader(
          title: 'التحميلات المحلية',
          leadingIcon: Icons.menu,
          onLeadingPressed: onToggleDrawer,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'المرفقات المحفوظة في جهازك ويمكن تصفحها بدون إنترنت:',
                style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 12),

              _DownloadedCard(
                icon: '🖼️',
                title: 'جدول_الميكانيكا.png',
                subtitle: 'معرض الجهاز / شواغر 22 • 2.4 MB',
                buttonText: 'عرض',
                onPressed: onOpenImage,
                primary: primary,
                surface: surface,
                border: border,
              ),
              const SizedBox(height: 10),

              _DownloadedCard(
                icon: '📄',
                title: 'Midterm_Schedule.pdf',
                subtitle: 'التنزيلات / Downloads • 1.1 MB',
                buttonText: 'فتح',
                onPressed: () => onToast('تم فتح الملف بنجاح'),
                primary: primary,
                surface: surface,
                border: border,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- 8. NOTIFICATIONS SCREEN ---
class NotificationsScreen extends StatelessWidget {
  final Color primary;
  final Color surface;
  final Color border;
  final VoidCallback onBack;

  const NotificationsScreen({
    super.key,
    required this.primary,
    required this.surface,
    required this.border,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CustomAppHeader(
          title: 'الإشعارات',
          leadingIcon: Icons.arrow_back,
          onLeadingPressed: onBack,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              _NotificationCard(
                icon: '📢',
                iconBg: primary.withValues(alpha: 0.15),
                title: 'منشور جديد في تخصص ميكانيكا',
                body: 'نشر ليدر الدفعة: جدول محاضرات الأسبوع الحالي - ميكانيكا.',
                time: 'قبل ساعتين',
                surface: surface,
                border: border,
              ),
              const SizedBox(height: 10),
              _NotificationCard(
                icon: '🎓',
                iconBg: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                title: 'إعلان عام لكل التخصصات',
                body: 'تم تحديث موعد المحاضرة التمهيدية الكبرى بقاعة المؤتمرات.',
                time: 'أمس',
                surface: surface,
                border: border,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- 9. PROFILE SCREEN ---
class ProfileScreen extends StatefulWidget {
  final String studentName;
  final String studentPhone;
  final String studentMajor;
  final String studentEmail;
  final Color primary;
  final Color surface;
  final Color border;
  final VoidCallback onBack;
  final void Function(String name, String major, String email) onSave;

  const ProfileScreen({
    super.key,
    required this.studentName,
    required this.studentPhone,
    required this.studentMajor,
    required this.studentEmail,
    required this.primary,
    required this.surface,
    required this.border,
    required this.onBack,
    required this.onSave,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late String _selectedMajor;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.studentName);
    _emailController = TextEditingController(text: widget.studentEmail);
    _selectedMajor = widget.studentMajor;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CustomAppHeader(
          title: 'الملف الشخصي',
          leadingIcon: Icons.arrow_back,
          onLeadingPressed: widget.onBack,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: widget.primary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: widget.primary, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          widget.studentName.length >= 2 ? widget.studentName.substring(0, 2) : 'أح',
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: widget.primary),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(widget.studentName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(widget.studentPhone, style: TextStyle(fontSize: 13, color: widget.primary)),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                const Text('الاسم الكامل', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
                const SizedBox(height: 6),
                _CustomTextInput(hint: 'الاسم الكامل', controller: _nameController),
                const SizedBox(height: 14),

                const Text('رقم الهاتف (غير قابل للتعديل)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
                const SizedBox(height: 6),
                _CustomTextInput(hint: widget.studentPhone, initialValue: widget.studentPhone, isEnabled: false),
                const SizedBox(height: 14),

                const Text('البريد الإلكتروني', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
                const SizedBox(height: 6),
                _CustomTextInput(hint: 'البريد', controller: _emailController),
                const SizedBox(height: 14),

                const Text('التخصص', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
                const SizedBox(height: 6),
                _CustomSelectInput(
                  value: _selectedMajor,
                  items: const ['ميكانيكا', 'تصنيع', 'مدنية', 'كهربا'],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedMajor = val);
                  },
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: () {
                    widget.onSave(_nameController.text.trim(), _selectedMajor, _emailController.text.trim());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.primary,
                    foregroundColor: const Color(0xFF0C0F17),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('حفظ التعديلات', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// --- 10. SETTINGS SCREEN ---
class SettingsScreen extends StatelessWidget {
  final bool isDark;
  final Color primary;
  final Color surface;
  final Color border;
  final VoidCallback onBack;
  final void Function(bool val) onToggleTheme;
  final void Function(String msg) onToast;

  const SettingsScreen({
    super.key,
    required this.isDark,
    required this.primary,
    required this.surface,
    required this.border,
    required this.onBack,
    required this.onToggleTheme,
    required this.onToast,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CustomAppHeader(
          title: 'الإعدادات',
          leadingIcon: Icons.arrow_back,
          onLeadingPressed: onBack,
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _SettingCard(
                title: 'الوضع الليلي (Dark Mode)',
                subtitle: 'تفعيل المظهر الداكن الفاخر',
                value: isDark,
                onChanged: onToggleTheme,
                surface: surface,
                border: border,
                primary: primary,
              ),
              const SizedBox(height: 12),
              _SettingCard(
                title: 'الإشعارات الفورية',
                subtitle: 'تنبيهات فورية عند نشر منشورات تخصصك',
                value: true,
                onChanged: (_) => onToast('تم تحديث حالة الإشعارات'),
                surface: surface,
                border: border,
                primary: primary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// --- 11. EMPTY STATE SCREEN ---
class EmptyStateScreen extends StatelessWidget {
  final Color primary;
  final VoidCallback onBack;

  const EmptyStateScreen({
    super.key,
    required this.primary,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CustomAppHeader(
          title: 'التحميلات',
          leadingIcon: Icons.arrow_back,
          onLeadingPressed: onBack,
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: primary.withValues(alpha: 0.2)),
                    ),
                    alignment: Alignment.center,
                    child: const Text('📂', style: TextStyle(fontSize: 32)),
                  ),
                  const SizedBox(height: 16),
                  const Text('لا توجد تحميلات حالياً', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  const Text(
                    'لم تقم بتحميل أي صور أو ملفات حتى الآن. يمكنك استعراض المنشورات والتحميل وقتما تشاء.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: onBack,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: const Color(0xFF0C0F17),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('تصفح المنشورات', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// --- 12. SKELETON SCREEN ---
class SkeletonScreen extends StatelessWidget {
  final VoidCallback onBack;

  const SkeletonScreen({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CustomAppHeader(
          title: 'جارِ التحميل...',
          leadingIcon: Icons.arrow_back,
          onLeadingPressed: onBack,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSkeletonCard([
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _skeletonLine(width: 60, height: 20),
                    _skeletonLine(width: 90, height: 16),
                  ],
                ),
                const SizedBox(height: 12),
                _skeletonLine(width: 240, height: 20),
                const SizedBox(height: 8),
                _skeletonLine(width: double.infinity, height: 14),
                const SizedBox(height: 6),
                _skeletonLine(width: 180, height: 14),
                const SizedBox(height: 16),
                _skeletonLine(width: double.infinity, height: 50),
              ]),
              const SizedBox(height: 12),
              _buildSkeletonCard([
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _skeletonLine(width: 60, height: 20),
                    _skeletonLine(width: 90, height: 16),
                  ],
                ),
                const SizedBox(height: 12),
                _skeletonLine(width: 270, height: 20),
                const SizedBox(height: 8),
                _skeletonLine(width: double.infinity, height: 14),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141A29),
        border: Border.all(color: const Color(0xFF2A3450)),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _skeletonLine({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF1E263C),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

// ============================================================================
// REUSABLE COMPONENTS & WIDGETS
// ============================================================================

// Header
class _CustomAppHeader extends StatelessWidget {
  final String title;
  final IconData leadingIcon;
  final VoidCallback onLeadingPressed;
  final IconData? actionIcon;
  final VoidCallback? onActionPressed;

  const _CustomAppHeader({
    required this.title,
    required this.leadingIcon,
    required this.onLeadingPressed,
    this.actionIcon,
    this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xD9141A29) : const Color(0xE6FFFFFF),
        border: Border(bottom: BorderSide(color: isDark ? const Color(0x14FFFFFF) : const Color(0x0F000000))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _IconButton(icon: leadingIcon, onPressed: onLeadingPressed),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          if (actionIcon != null)
            _IconButton(icon: actionIcon!, onPressed: onActionPressed!)
          else
            const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _IconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(9999),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E263C) : const Color(0xFFF1F5F9),
          shape: BoxShape.circle,
          border: Border.all(color: isDark ? const Color(0xFF2A3450) : const Color(0xFFE2E8F0)),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 20),
      ),
    );
  }
}

// Side Drawer
class CustomSideDrawer extends StatelessWidget {
  final String studentName;
  final String studentMajor;
  final Color primaryColor;
  final Color surfaceColor;
  final Color borderColor;
  final VoidCallback onClose;
  final void Function(String screenId) onNavigate;
  final void Function(String msg) onToast;

  const CustomSideDrawer({
    super.key,
    required this.studentName,
    required this.studentMajor,
    required this.primaryColor,
    required this.surfaceColor,
    required this.borderColor,
    required this.onClose,
    required this.onNavigate,
    required this.onToast,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(left: BorderSide(color: borderColor)),
      ),
      child: Column(
        children: [
          // Drawer Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E263C),
              border: Border(bottom: BorderSide(color: borderColor)),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: primaryColor, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    studentName.length >= 2 ? studentName.substring(0, 2) : 'أح',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor),
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(studentName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('تخصص: $studentMajor', style: TextStyle(fontSize: 12, color: primaryColor)),
                  ],
                ),
              ],
            ),
          ),

          // Drawer Links
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _DrawerLinkItem(
                  icon: Icons.person_outline,
                  label: 'الملف الشخصي',
                  onTap: () {
                    onClose();
                    onNavigate('screen-profile');
                  },
                ),
                _DrawerLinkItem(
                  icon: Icons.notifications_none,
                  label: 'الإشعارات',
                  onTap: () {
                    onClose();
                    onNavigate('screen-notifications');
                  },
                ),
                _DrawerLinkItem(
                  icon: Icons.file_download_outlined,
                  label: 'التحميلات',
                  onTap: () {
                    onClose();
                    onNavigate('screen-downloads');
                  },
                ),
                _DrawerLinkItem(
                  icon: Icons.settings_outlined,
                  label: 'الإعدادات',
                  onTap: () {
                    onClose();
                    onNavigate('screen-settings');
                  },
                ),
                _DrawerLinkItem(
                  icon: Icons.info_outline,
                  label: 'عن التطبيق',
                  onTap: () {
                    onClose();
                    onToast('شواغر 22 - الإصدار 1.0.0 (تطوير الطلاب والليدر)');
                  },
                ),
                _DrawerLinkItem(
                  icon: Icons.logout,
                  label: 'تسجيل الخروج',
                  color: const Color(0xFFEF4444),
                  onTap: () {
                    onClose();
                    onNavigate('screen-signin');
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

class _DrawerLinkItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _DrawerLinkItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color, size: 20),
      title: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color)),
      onTap: onTap,
    );
  }
}

// Bottom Nav Bar
class CustomBottomNavBar extends StatelessWidget {
  final String activeScreen;
  final void Function(String screenId) onSelect;
  final Color primaryColor;
  final Color surfaceColor;
  final Color borderColor;

  const CustomBottomNavBar({
    super.key,
    required this.activeScreen,
    required this.onSelect,
    required this.primaryColor,
    required this.surfaceColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final items = [
      {'id': 'screen-home', 'label': 'الرئيسية', 'icon': Icons.home_outlined},
      {'id': 'screen-tables', 'label': 'الجداول', 'icon': Icons.calendar_today_outlined},
      {'id': 'screen-lectures', 'label': 'المحاضرات', 'icon': Icons.menu_book_outlined},
      {'id': 'screen-events', 'label': 'الفعاليات', 'icon': Icons.campaign_outlined},
      {'id': 'screen-downloads', 'label': 'التحميلات', 'icon': Icons.file_download_outlined},
    ];

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: items.map((item) {
          final isActive = activeScreen == item['id'];
          return Expanded(
            child: InkWell(
              onTap: () => onSelect(item['id'] as String),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    item['icon'] as IconData,
                    size: 22,
                    color: isActive ? primaryColor : const Color(0xFF64748B),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item['label'] as String,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isActive ? primaryColor : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// Post Card
class _PostCard extends StatefulWidget {
  final String badgeText;
  final Color? badgeColor;
  final String dateText;
  final String title;
  final String body;
  final Color primary;
  final Color surface;
  final Color border;
  final List<_AttachmentItem> attachments;
  final String postId;
  final Map<String, int> reactionCounts;
  final String userReaction;
  final void Function(String postId, String emoji) onReact;
  final void Function(String msg) onToast;
  final bool showReactions;

  const _PostCard({
    required this.badgeText,
    this.badgeColor,
    required this.dateText,
    required this.title,
    required this.body,
    required this.primary,
    required this.surface,
    required this.border,
    required this.attachments,
    required this.postId,
    required this.reactionCounts,
    required this.userReaction,
    required this.onReact,
    required this.onToast,
    this.showReactions = true,
  });

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool isEmojiPopupOpen = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: widget.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: widget.border),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _BadgeWidget(
                text: widget.badgeText,
                primary: widget.badgeColor ?? widget.primary,
              ),
              Text(widget.dateText, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
          const SizedBox(height: 10),

          // Title & Body
          Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(widget.body, style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF94A3B8))),
          const SizedBox(height: 12),

          // Attachments
          if (widget.attachments.isNotEmpty) ...[
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 2.3,
              children: widget.attachments.map((att) => _buildAttachmentCard(att)).toList(),
            ),
            const SizedBox(height: 12),
          ],

          // Reactions
          if (widget.showReactions) ...[
            const Divider(color: Color(0x14FFFFFF)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Wrap(
                  spacing: 6,
                  children: widget.reactionCounts.entries.map((e) {
                    final isUserEmoji = widget.userReaction == e.key;
                    return InkWell(
                      onTap: () => widget.onToast('التفاعلات: ${e.value} طالب تفاعلوا بـ ${e.key}'),
                      borderRadius: BorderRadius.circular(9999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isUserEmoji ? widget.primary.withValues(alpha: 0.15) : const Color(0xFF1E263C),
                          borderRadius: BorderRadius.circular(9999),
                          border: Border.all(color: isUserEmoji ? widget.primary : widget.border),
                        ),
                        child: Text('${e.key} ${e.value}', style: const TextStyle(fontSize: 12)),
                      ),
                    );
                  }).toList(),
                ),

                // Reaction trigger & Popup
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    InkWell(
                      onTap: () => setState(() => isEmojiPopupOpen = !isEmojiPopupOpen),
                      borderRadius: BorderRadius.circular(9999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E263C),
                          borderRadius: BorderRadius.circular(9999),
                          border: Border.all(color: widget.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(widget.userReaction.isNotEmpty ? widget.userReaction : '👍', style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 4),
                            const Text('تفاعل', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                    if (isEmojiPopupOpen)
                      Positioned(
                        bottom: 40,
                        left: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E263C),
                            borderRadius: BorderRadius.circular(9999),
                            border: Border.all(color: widget.border),
                            boxShadow: const [
                              BoxShadow(color: Colors.black45, blurRadius: 10, offset: Offset(0, 4))
                            ],
                          ),
                          child: Row(
                            children: ['👍', '❤️', '😂', '😮', '😢', '🙏'].map((emoji) {
                              return GestureDetector(
                                onTap: () {
                                  setState(() => isEmojiPopupOpen = false);
                                  widget.onReact(widget.postId, emoji);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(emoji, style: const TextStyle(fontSize: 20)),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttachmentCard(_AttachmentItem att) {
    return InkWell(
      onTap: att.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF1E263C),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: widget.border),
        ),
        child: Row(
          children: [
            Text(att.icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                att.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
            InkWell(
              onTap: att.onDownload,
              borderRadius: BorderRadius.circular(9999),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: att.isDownloaded ? const Color(0x2610B981) : widget.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: att.isDownloaded ? const Color(0x4D10B981) : widget.primary.withValues(alpha: 0.3),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  att.isDownloaded ? '✓' : '⬇',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: att.isDownloaded ? const Color(0xFF10B981) : widget.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentItem {
  final String icon;
  final String name;
  final bool isDownloaded;
  final VoidCallback onTap;
  final VoidCallback onDownload;

  const _AttachmentItem({
    required this.icon,
    required this.name,
    required this.isDownloaded,
    required this.onTap,
    required this.onDownload,
  });
}

// Download Card
class _DownloadedCard extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onPressed;
  final Color primary;
  final Color surface;
  final Color border;

  const _DownloadedCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onPressed,
    required this.primary,
    required this.surface,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E263C),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: const Color(0xFF0C0F17),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(buttonText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// Notification Card
class _NotificationCard extends StatelessWidget {
  final String icon;
  final Color iconBg;
  final String title;
  final String body;
  final String time;
  final Color surface;
  final Color border;

  const _NotificationCard({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.body,
    required this.time,
    required this.surface,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(icon, style: const TextStyle(fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(body, style: const TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF94A3B8))),
                const SizedBox(height: 6),
                Text(time, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Setting Card
class _SettingCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final void Function(bool) onChanged;
  final Color surface;
  final Color border;
  final Color primary;

  const _SettingCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.surface,
    required this.border,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
            ],
          ),
          Switch(
            value: value,
            activeThumbColor: primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// Custom Inputs
class _CustomTextInput extends StatelessWidget {
  final String hint;
  final String? initialValue;
  final bool isPassword;
  final bool isEnabled;
  final TextEditingController? controller;

  const _CustomTextInput({
    required this.hint,
    this.initialValue,
    this.isPassword = false,
    this.isEnabled = true,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextFormField(
      controller: controller,
      initialValue: controller == null ? initialValue : null,
      obscureText: isPassword,
      enabled: isEnabled,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: isDark ? const Color(0xFF141A29) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? const Color(0xFF2A3450) : const Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? const Color(0xFF2A3450) : const Color(0xFFE2E8F0)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Color(0xFFD4AF37)),
        ),
      ),
    );
  }
}

class _CustomSelectInput extends StatelessWidget {
  final String value;
  final List<String> items;
  final void Function(String?) onChanged;

  const _CustomSelectInput({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141A29) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF2A3450) : const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// Badge
class _BadgeWidget extends StatelessWidget {
  final String text;
  final Color primary;

  const _BadgeWidget({required this.text, required this.primary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: primary.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: primary),
      ),
    );
  }
}
